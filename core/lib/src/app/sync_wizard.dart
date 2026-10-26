import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity.dart';
import '../security/crypto.dart' show minPasswordLength;
import '../sync/account_api.dart';
import '../sync/account_service.dart';
import '../sync/pairing.dart';
import '../sync/server_check.dart';
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

enum _Step { welcome, where, guide, server, account, done }

/// The Brahma repository people get the server from.
const serverRepository = 'https://github.com/sudharamachandranrajeev/brahma';

/// Guided first setup: keep data on this device, or sync through the user's
/// own server, at home or in the cloud, with step-by-step help for setting
/// that server up. Every step can be skipped and redone later from Settings.
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
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.welcome;
  ServerPlace _place = ServerPlace.unknown;
  ServerInfo? _info;
  ServerCheck? _problem;
  List<FoundServer>? _found;
  StreamSubscription<FoundServer>? _search;
  bool _checking = false, _busy = false, _create = true, _show = false;
  String? _error;

  @override
  void dispose() {
    _search?.cancel();
    for (final c in [_server, _email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  void _pick(ServerPlace place) {
    _place = place;
    _info = null;
    _problem = null;
    _go(place == ServerPlace.unknown ? _Step.server : _Step.guide);
  }

  /// The address field also takes a pasted setup or pairing link.
  void _serverChanged(String text) {
    if (_info != null || _problem != null) {
      setState(() {
        _info = null;
        _problem = null;
      });
    }
    final scheme = RegExp(r'^([a-z0-9]+)://').firstMatch(text.trim())?.group(1);
    if (scheme == null || !isBrahmaScheme(scheme)) return;
    try {
      switch (BrahmaLink.parse(text)) {
        case SetupLink() && final link:
          _server.text = '${link.server}';
          _code.text = link.invite;
          _check();
        case PairingLink() && final link:
          _server.clear();
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
      _problem = null;
    });
    final result = await checkServer(_server.text, place: _place);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (result.ok) {
        _server.text = '${result.url}';
        _info = result.info;
        _create = result.info!.needsSetup || _code.text.isNotEmpty;
      } else {
        _problem = result;
      }
    });
  }

  void _findServers() {
    _search?.cancel();
    setState(() => _found = []);
    _search = findHomeServers().listen(
      (s) => setState(() => _found = [...?_found, s]),
      onDone: () => setState(() => _search = null),
    );
  }

  void _useFound(FoundServer s) {
    _search?.cancel();
    setState(() {
      _search = null;
      _server.text = '${s.url}';
      _info = s.info;
      _problem = null;
      _create = s.info.needsSetup || _code.text.isNotEmpty;
    });
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Dots(_step.index, _Step.values.length),
                  const SizedBox(height: 24),
                  ...switch (_step) {
                    _Step.welcome => _welcome(name),
                    _Step.where => _whereStep(name),
                    _Step.guide => _place == ServerPlace.home ? _homeGuide(name) : _cloudGuide(name),
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

  Widget _title(String text) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center);

  Widget _back(_Step to) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(onPressed: () => _go(to), child: const Text('Back')),
  );

  List<Widget> _welcome(String name) => [
    Icon(Icons.waving_hand_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 16),
    _title('Welcome to $name'),
    const SizedBox(height: 8),
    const Text(
      'First, where should your data live? You can change this later in Settings.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 20),
    _Choice(
      icon: Icons.smartphone_outlined,
      title: 'Keep everything on this device',
      body:
          'Nothing leaves this device and there is no account. Works offline. Best if you use $name on '
          'one device only.',
      tip: 'If this device is lost or reset, its data goes with it, unless you export a backup.',
      onTap: () => widget.onFinished(false),
    ),
    const SizedBox(height: 12),
    _Choice(
      icon: Icons.devices_outlined,
      title: 'Sync across my devices',
      body:
          'Use $name on your phone and computers, all kept in step through a server that you own. '
          'Every Brahma app shares the same account.',
      tip: 'Your data is locked (encrypted) on this device before it is sent, so the server cannot read it.',
      onTap: () => _go(_Step.where),
    ),
  ];

  List<Widget> _whereStep(String name) => [
    _title('Where will your server run?'),
    const SizedBox(height: 8),
    const Text(
      'A server is a small program that passes your locked data between your devices. Pick what suits you.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 20),
    _Choice(
      icon: Icons.home_outlined,
      title: 'Home server',
      body:
          'A computer at home that stays switched on, like an old laptop or a mini PC with Linux. Free, '
          'and your data never leaves your home.',
      tip: 'Away from home too? Add Tailscale (free); the guide shows how.',
      onTap: () => _pick(ServerPlace.home),
    ),
    const SizedBox(height: 12),
    _Choice(
      icon: Icons.cloud_outlined,
      title: 'Cloud server',
      body:
          "Runs on Cloudflare's free plan, so there is no computer to leave on and it works anywhere. "
          'You need a free Cloudflare account and about 10 minutes.',
      tip: 'Cloudflare only ever holds locked data it cannot read.',
      onTap: () => _pick(ServerPlace.cloud),
    ),
    const SizedBox(height: 12),
    _Choice(
      icon: Icons.link,
      title: 'I already have a server',
      body: 'You have its address or a setup link, or someone invited you to theirs.',
      onTap: () => _pick(ServerPlace.unknown),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: () => _joinWith(null),
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Join from a device I already use'),
    ),
    _back(_Step.welcome),
  ];

  List<Widget> _homeGuide(String name) => [
    _title('Set up your home server'),
    const SizedBox(height: 8),
    const Text('Do these steps on the computer that will be the server. It takes about 5 minutes.'),
    const SizedBox(height: 16),
    const _Steps([
      (
        'Pick the computer',
        'Any computer running Linux (Ubuntu, Fedora, Debian, Arch...) that can stay on. An old laptop is '
            'perfect. Keep it plugged in and set it never to sleep, also with the lid closed.',
        null,
      ),
      (
        'Install the two tools it needs',
        'Git (to download the server) and Node.js version 24 or newer (to run it). On Ubuntu or Debian, '
            'get Node from nodejs.org, because their own is too old. Check with "node --version".',
        'sudo apt install git        # Ubuntu, Debian\nsudo dnf install git nodejs # Fedora\nsudo pacman -S git nodejs   # Arch',
      ),
      (
        'Download and install the server',
        'Open a terminal on that computer and paste these lines. The installer explains each step and '
            'asks before it changes anything, such as the firewall.',
        'git clone $serverRepository.git\ncd brahma/server/home\n./install.sh',
      ),
      (
        'Copy the setup link',
        'At the end it prints a setup link starting with brahma://setup and a QR code. Paste the link on '
            'the next screen, or scan the code with your phone camera.',
        null,
      ),
    ]),
    const SizedBox(height: 8),
    const _Tips([
      'Same Wi-Fi: your devices reach a home server when they are on your home network.',
      'Away from home: install Tailscale (tailscale.com/download, free) on the server and on each device, '
          'then run "./install.sh --link" again for an address that works anywhere.',
      'Fixed address: in your router, give the server computer a fixed address (called "DHCP reservation"), '
          'so the address in your apps keeps working.',
      'Lost the link? Run "./install.sh --link" on the server. "./install.sh --status" shows if all is well.',
    ]),
    const SizedBox(height: 16),
    FilledButton(onPressed: () => _go(_Step.server), child: const Text("I've done this, connect")),
    _back(_Step.where),
  ];

  List<Widget> _cloudGuide(String name) => [
    _title('Set up your cloud server'),
    const SizedBox(height: 8),
    const Text('Do these steps once, on any computer. It takes about 10 minutes and costs nothing.'),
    const SizedBox(height: 16),
    const _Steps([
      (
        'Make a free Cloudflare account',
        'Go to dash.cloudflare.com/sign-up. The free plan is plenty for a household.',
        null,
      ),
      (
        'Install the two tools it needs',
        'Git (to download the server) and Node.js version 24 or newer, from nodejs.org. Windows, Mac and '
            'Linux all work.',
        null,
      ),
      (
        'Download and deploy the server',
        'Open a terminal (on Windows: PowerShell) and paste these lines. "wrangler login" opens your '
            'browser once so you can allow it to use your Cloudflare account.',
        'git clone $serverRepository.git\ncd brahma/server\nnpm install\nnpx wrangler login\nnpm run setup',
      ),
      (
        'Copy the setup link',
        'It prints your server address, like https://brahma-sync.your-name.workers.dev, and a setup '
            'link starting with brahma://setup. Paste the link on the next screen.',
        null,
      ),
    ]),
    const SizedBox(height: 8),
    const _Tips([
      'The setup link is shown once and works once: it makes you the owner of the server.',
      'Later, invite family from Settings, Sync, Invite someone. Each person gets their own private account.',
      'Running "npm run setup" again updates the server and keeps everyone\'s data.',
    ]),
    const SizedBox(height: 16),
    FilledButton(onPressed: () => _go(_Step.server), child: const Text("I've done this, connect")),
    _back(_Step.where),
  ];

  List<Widget> _serverStep(String name) {
    final info = _info, problem = _problem, found = _found;
    final home = _place != ServerPlace.cloud;
    return [
      _title('Connect to your server'),
      const SizedBox(height: 8),
      const Text('Paste the setup link, or type the server address.'),
      const SizedBox(height: 16),
      Form(
        key: _serverForm,
        child: TextFormField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: _serverChanged,
          onFieldSubmitted: (_) => _check(),
          decoration: InputDecoration(
            labelText: 'Setup link or server address',
            hintText: switch (_place) {
              ServerPlace.home => 'http://192.168.1.20:8090',
              ServerPlace.cloud => 'https://brahma-sync.your-name.workers.dev',
              ServerPlace.unknown => 'brahma://setup?... or https://...',
            },
            helperText: home
                ? 'For a home server, the number address alone is enough, like 192.168.1.20'
                : null,
          ),
          validator: (v) => (v ?? '').trim().length < 4 ? 'Paste the link or type the address' : null,
        ),
      ),
      if (home) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _search != null ? null : _findServers,
            icon: _search != null
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find_outlined),
            label: Text(_search != null ? 'Looking on your Wi-Fi…' : 'Find my home server'),
          ),
        ),
        if (found != null && found.isEmpty && _search == null)
          const _Problem(
            problem: 'No home server found on this Wi-Fi.',
            fix:
                'Check the server computer is on and this device is on the same Wi-Fi. Servers on another '
                'port, or reached through Tailscale, need their address typed in.',
          ),
        if (found != null && found.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Only pick a server you recognise: anyone on this Wi-Fi can run one. Away from your own home '
              'network, use the setup link or the Tailscale address instead.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        for (final s in found ?? const <FoundServer>[])
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(s.info.describe),
              subtitle: Text('${s.url}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _useFound(s),
            ),
          ),
      ],
      const SizedBox(height: 12),
      if (_error != null) _Problem(problem: _error!, fix: 'Copy the whole link again and paste it.'),
      if (problem != null) _Problem(problem: problem.problem!, fix: problem.fix!),
      if (info != null)
        StatusLabel(
          Status.good,
          info.needsSetup
              ? 'Found: ${info.describe}. You will create its owner account.'
              : 'Found: ${info.describe}. Sign in, or join with an invite code.',
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
      _back(_place == ServerPlace.unknown ? _Step.where : _Step.guide),
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

/// A big tappable option: what it is, why pick it, and a hint.
class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.body, this.tip, required this.onTap});
  final IconData icon;
  final String title, body;
  final String? tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body),
                    if (tip != null) ...[
                      const SizedBox(height: 6),
                      Text(tip!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered how-to steps: a title, plain words, and lines to copy.
class _Steps extends StatelessWidget {
  const _Steps(this.steps);
  final List<(String, String, String?)> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (title, body, command)) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: scheme.primaryContainer,
                  child: Text('${i + 1}', style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(body),
                      if (command != null) ...[const SizedBox(height: 8), _Command(command)],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Good-to-know hints under a guide.
class _Tips extends StatelessWidget {
  const _Tips(this.tips);
  final List<String> tips;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 18),
            const SizedBox(width: 6),
            Text('Good to know', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        for (final t in tips) Padding(padding: const EdgeInsets.only(top: 8), child: Text('• $t')),
      ],
    ),
  );
}

/// What went wrong, in everyday words, and what to try.
class _Problem extends StatelessWidget {
  const _Problem({required this.problem, required this.fix});
  final String problem, fix;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Status.critical.color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Status.critical.icon, size: 20, color: Status.critical.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(problem, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(fix),
            ],
          ),
        ),
      ],
    ),
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
