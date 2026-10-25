import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity.dart';
import '../security/crypto.dart' show minPasswordLength;
import '../sync/account_api.dart';
import '../sync/account_service.dart';
import '../sync/pairing.dart';
import '../ui/widgets.dart';
import 'pairing_dialogs.dart';
import 'providers.dart';
import 'sync_dialogs.dart';

/// Local setting that records the first-run sync setup was answered
/// (finished or skipped), so a fresh install asks once.
const _onboardedKey = 'onboarding.sync';

/// Shows [SyncSetupWizard] on a fresh install, then [child]. An install that
/// already syncs, or whose user answered before, goes straight to [child].
class FirstRunSetup extends ConsumerStatefulWidget {
  const FirstRunSetup({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FirstRunSetup> createState() => _FirstRunSetupState();
}

class _FirstRunSetupState extends ConsumerState<FirstRunSetup> {
  bool? _needed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final s = ref.read(coreSessionProvider);
    final answered = await s.db.localSetting(_onboardedKey) != null;
    final signedIn = await s.keys.session() != null;
    if (mounted) setState(() => _needed = !answered && !signedIn);
  }

  Future<void> _finished() async {
    await ref
        .read(coreSessionProvider)
        .db
        .setLocalSetting(_onboardedKey, DateTime.now().toUtc().toIso8601String());
    if (mounted) setState(() => _needed = false);
  }

  @override
  Widget build(BuildContext context) => switch (_needed) {
    null => const Scaffold(body: SizedBox.shrink()),
    true => SyncSetupWizard(onFinished: (_) => _finished()),
    false => widget.child,
  };
}

enum _Step { welcome, server, account, done }

/// Guided sync setup: what sync is, which server, an account (or joining from
/// a device already set up), the recovery key. Every step can be skipped and
/// redone later from Settings.
class SyncSetupWizard extends ConsumerStatefulWidget {
  const SyncSetupWizard({super.key, required this.onFinished});

  /// Called when the user finishes or skips; [signedIn] says whether sync is on.
  final void Function(bool signedIn) onFinished;

  @override
  ConsumerState<SyncSetupWizard> createState() => _SyncSetupWizardState();
}

class _SyncSetupWizardState extends ConsumerState<SyncSetupWizard> {
  final _serverForm = GlobalKey<FormState>();
  final _accountForm = GlobalKey<FormState>();
  final _server = TextEditingController(text: 'https://');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.welcome;
  ServerInfo? _info;
  bool _checking = false, _busy = false, _create = true, _show = false, _showSteps = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  /// The address field also takes a pasted setup or pairing link.
  void _serverChanged(String text) {
    final scheme = RegExp(r'^([a-z0-9]+)://').firstMatch(text.trim())?.group(1);
    if (scheme == null || !isBrahmaScheme(scheme)) {
      if (_info != null) setState(() => _info = null);
      return;
    }
    try {
      switch (BrahmaLink.parse(text)) {
        case SetupLink() && final link:
          _server.text = '${link.server}';
          _code.text = link.invite;
          _check();
        case PairingLink() && final link:
          _server.text = 'https://';
          _joinWith(link);
      }
    } catch (e) {
      setState(() => _error = describeError(e));
    }
  }

  Future<void> _check() async {
    if (!_serverForm.currentState!.validate()) return;
    setState(() {
      _checking = true;
      _error = null;
      _info = null;
    });
    try {
      final api = await AccountApi.connect(_server.text.trim());
      if (!mounted) return;
      setState(() {
        _info = api.info;
        _checking = false;
        _create = api.info.needsSetup || _code.text.isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = describeError(e);
        });
      }
    }
  }

  Future<void> _joinWith(PairingLink? link) async {
    if (await showJoinDialog(context, link: link) && mounted) {
      await ref.read(syncProvider.notifier).run();
      _go(_Step.done);
    }
  }

  Future<void> _submit() async {
    if (!_accountForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = ref.read(coreSessionProvider).account;
    final server = _server.text.trim(), email = _email.text.trim();
    try {
      if (_create) {
        final key = await account.signUp(
          server: server,
          email: email,
          password: _password.text,
          invite: _code.text.trim(),
        );
        if (mounted) await showRecoveryKey(context, key);
      } else {
        try {
          await account.signIn(server: server, email: email, password: _password.text);
        } on RecoveryKeyNeeded {
          if (!mounted) return;
          final key = await askRecoveryKey(context);
          if (key == null) {
            setState(() => _busy = false);
            return;
          }
          await account.unlockWithRecoveryKey(key);
        }
      }
      await ref.read(syncProvider.notifier).run();
      if (mounted) {
        setState(() => _busy = false);
        _go(_Step.done);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(appIdentityProvider).name;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Dots(_step.index, _Step.values.length),
                  const SizedBox(height: 24),
                  ...switch (_step) {
                    _Step.welcome => _welcome(name, scheme),
                    _Step.server => _serverStep(name),
                    _Step.account => _accountStep(name),
                    _Step.done => _done(name),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _welcome(String name, ColorScheme scheme) {
    final type = Theme.of(context).textTheme;
    return [
      Icon(Icons.devices_outlined, size: 48, color: scheme.primary),
      const SizedBox(height: 16),
      Text('Welcome to $name', style: type.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(
        'Everything is stored encrypted on this device and works without an account. '
        'To use $name on your phone, computer and the web too, connect it to your own sync server.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      for (final (icon, text) in [
        (Icons.dns_outlined, 'Your server: one you deploy yourself, so your data never sits with us.'),
        (Icons.enhanced_encryption_outlined, 'End-to-end encrypted: the server only ever holds ciphertext.'),
        (Icons.key_outlined, 'A recovery key, shown once, is the only way back if you forget your password.'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      const SizedBox(height: 24),
      FilledButton(onPressed: () => _go(_Step.server), child: const Text('Set up sync')),
      TextButton(
        onPressed: () => widget.onFinished(false),
        child: const Text('Not now, use this device only'),
      ),
      const Text(
        'You can set this up later in Settings.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12),
      ),
    ];
  }

  List<Widget> _serverStep(String name) {
    final info = _info;
    return [
      Text('Your sync server', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Enter the address of your server, or paste the setup link it printed when you deployed it.',
      ),
      const SizedBox(height: 16),
      Form(
        key: _serverForm,
        child: TextFormField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: _serverChanged,
          onFieldSubmitted: (_) => _check(),
          decoration: const InputDecoration(
            labelText: 'Server address or setup link',
            hintText: 'https://bhojana.your-name.workers.dev',
          ),
          validator: (v) => (v ?? '').trim().length < 10 ? 'Enter the server address' : null,
        ),
      ),
      const SizedBox(height: 12),
      if (_error != null) StatusLabel(Status.critical, _error!),
      if (info != null)
        StatusLabel(
          Status.good,
          info.needsSetup
              ? 'Server found. No one has signed up yet: you will create the owner account.'
              : 'Server found. Sign in, or create an account with an invite code from the owner.',
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _checking
            ? null
            : info == null
            ? _check
            : () => _go(_Step.account),
        child: _checking
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(info == null ? 'Check server' : 'Continue'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _joinWith(null),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Join from a device I already use'),
      ),
      const SizedBox(height: 8),
      ExpansionTile(
        title: const Text("I don't have a server yet"),
        initiallyExpanded: _showSteps,
        onExpansionChanged: (v) => _showSteps = v,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your server is a small Cloudflare Worker (free plan is enough). From the server folder of the '
            '$name repository, with Node installed:',
          ),
          const SizedBox(height: 8),
          const _Command('npx wrangler login\nnpm install\nnpm run setup'),
          const SizedBox(height: 8),
          const Text(
            'It prints a server address and a setup link. Paste the link above to create your account.',
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => _go(_Step.welcome), child: const Text('Back')),
      ),
    ];
  }

  List<Widget> _accountStep(String name) {
    final info = _info;
    final first = info?.needsSetup ?? false;
    return [
      Text(
        first
            ? 'Create the owner account'
            : _create
            ? 'Create your account'
            : 'Sign in',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        first
            ? 'You deployed this server, so this account is its owner: it can invite everyone else.'
            : _create
            ? 'The owner of the server gives you an invite code.'
            : 'Use the e-mail and password of your sync account.',
      ),
      if (!first) ...[
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Create account')),
            ButtonSegment(value: false, label: Text('I have an account')),
          ],
          selected: {_create},
          onSelectionChanged: (v) => setState(() {
            _create = v.first;
            _error = null;
          }),
        ),
      ],
      const SizedBox(height: 16),
      Form(
        key: _accountForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter your e-mail',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_show,
              autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _create ? 'At least $minPasswordLength characters; a passphrase is best.' : null,
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              validator: (v) {
                if (!_create) return (v ?? '').isEmpty ? 'Enter your password' : null;
                return (v ?? '').length < minPasswordLength
                    ? 'Use at least $minPasswordLength characters'
                    : null;
              },
            ),
            if (_create) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: !_show,
                decoration: const InputDecoration(labelText: 'Repeat password'),
                validator: (v) => v == _password.text ? null : 'Passwords differ',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: first ? 'Setup code' : 'Invite code',
                  helperText: first
                      ? 'Printed when you deployed the server; part of the setup link.'
                      : 'From the server owner.',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the code' : null,
              ),
            ],
          ],
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 12), StatusLabel(Status.critical, _error!)],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(_create ? 'Create account' : 'Sign in'),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: _busy ? null : () => _go(_Step.server), child: const Text('Back')),
      ),
    ];
  }

  List<Widget> _done(String name) => [
    Icon(Icons.check_circle_outline, size: 48, color: Status.good.color),
    const SizedBox(height: 16),
    Text("You're set", style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    Text(
      '$name now keeps this device in step with your server. To add another phone or computer, open '
      'Settings, Sync, Add a device and scan the code there.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 24),
    FilledButton(onPressed: () => widget.onFinished(true), child: Text('Open $name')),
  ];
}

class _Dots extends StatelessWidget {
  const _Dots(this.index, this.count);
  final int index, count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: i == index ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

class _Command extends StatelessWidget {
  const _Command(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      ],
    ),
  );
}

/// The wizard as a page above the current screen, for Settings. Returns
/// true when sync ended up on.
Future<bool> showSyncWizard(BuildContext context) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SyncSetupWizard(onFinished: (signedIn) => Navigator.of(context).pop(signedIn)),
      ),
    ) ??
    false;
