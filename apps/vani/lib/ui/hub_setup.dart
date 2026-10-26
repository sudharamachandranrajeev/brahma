import 'dart:io';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/cloudflare.dart';
import '../domain/hub.dart';
import 'common.dart';
import 'look.dart';

/// Setting up needs a computer once; a phone then connects by scanning.
bool get canDeployHub => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// True when [hub] is older than [bundled] (null: a hub from before versions).
bool hubIsOlder(String? hub, String bundled) {
  if (hub == null) return true;
  List<int> parts(String v) => [for (final p in v.split('.')) int.tryParse(p) ?? 0];
  final a = parts(hub), b = parts(bundled);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}

/// Opens the guided setup (or update) of the user's own hub on their
/// Cloudflare account. On a phone it explains the one-time computer step.
Future<void> setUpHub(BuildContext context, WidgetRef ref) async {
  if (!canDeployHub) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up on a computer'),
        content: const Text(
          'Making your hub takes about 15 minutes on a computer, once. Install Vani on a Windows or '
          'Linux PC, open Settings > Social hub > Set up a hub, and follow the steps.\n\n'
          'At the end it shows a QR code: scan it with this phone\'s camera and Vani connects.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const HubSetupPage()));
}

/// Asks before connecting this device to the hub in a scanned or pasted
/// `vani://hub` link. False when [text] is not such a link.
Future<bool> openHubLink(BuildContext context, WidgetRef ref, String text) async {
  final link = HubLink.fromPairingLink(text);
  if (link == null) return false;
  final ok = await confirm(
    context,
    title: 'Connect to this hub?',
    message: 'Vani on this device will use the hub at ${Uri.parse(link.url).host}.',
    action: 'Connect',
  );
  if (ok && context.mounted) {
    if (await guarded(context, () => saveHubLink(ref, link)) && context.mounted) {
      showMessage(context, 'Hub connected.');
    }
  }
  return true;
}

/// Shows [link] as a QR code to scan with another device (and to copy).
Future<void> showPhoneLink(BuildContext context, HubLink link) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Connect another device'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Scan this with the other device\'s camera (Vani opens and connects), or copy the link into its '
          'Connect hub. Keep it private: it is the key to your hub.',
        ),
        const SizedBox(height: 16),
        QrCodeView(link.toPairingLink(), size: 220),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () =>
            copyText(context, link.toPairingLink(), what: 'Link copied. Send it only to yourself.'),
        child: const Text('Copy link'),
      ),
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
    ],
  ),
);

/// Checks [link] with a real call, then saves it as the synced hub link.
Future<void> saveHubLink(WidgetRef ref, HubLink link) async {
  await HubClient(link.url, link.token, client: ref.read(httpClientProvider)).meta();
  await ref.mutate((s) => s.prefs.saveHub(link));
  ref.read(hubRevisionProvider.notifier).bump();
}

enum _Stage { account, r2, key, deploy, done }

enum _Mark { waiting, running, done, failed }

/// The steps: a Cloudflare account, R2 switched on, an API token for Vani,
/// then Vani deploys (or updates) the hub and shows how to connect the
/// phone. With a key saved from an earlier setup it starts at the deploy.
class HubSetupPage extends ConsumerStatefulWidget {
  const HubSetupPage({super.key});

  @override
  ConsumerState<HubSetupPage> createState() => _HubSetupPageState();
}

class _HubSetupPageState extends ConsumerState<HubSetupPage> {
  var _stage = _Stage.account;
  final _key = TextEditingController();
  final _subdomain = TextEditingController();
  List<CloudflareAccount> _accounts = const [];
  String? _accountId;
  String? _existingSubdomain;
  bool _checking = false;
  String? _keyError;

  final _marks = {for (final s in DeployStep.values) s: _Mark.waiting};
  bool _deploying = false;
  String? _deployError;
  bool _r2Off = false;
  Deployed? _result;

  @override
  void initState() {
    super.initState();
    ref.read(hubDeploymentProvider.future).then((d) {
      if (d == null || !mounted) return;
      _key.text = d.cloudflareToken;
      _checkKey();
    });
  }

  CloudflareClient get _cf => CloudflareClient(_key.text.trim(), client: ref.read(httpClientProvider));

  Future<void> _checkKey() async {
    if (_key.text.trim().isEmpty) {
      setState(() => _keyError = 'Paste the key Cloudflare showed you.');
      return;
    }
    setState(() {
      _checking = true;
      _keyError = null;
    });
    try {
      final accounts = await _cf.accounts();
      if (accounts.isEmpty) throw CloudflareException('That key does not reach any Cloudflare account.');
      final previous = ref.read(hubDeploymentProvider).value?.accountId;
      final id = accounts.any((a) => a.id == previous) ? previous! : accounts.first.id;
      final sub = await _cf.subdomain(id);
      setState(() {
        _accounts = accounts;
        _accountId = id;
        _existingSubdomain = sub;
        _stage = _Stage.deploy;
      });
    } catch (e) {
      setState(() => _keyError = describeError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickAccount(String id) async {
    setState(() {
      _accountId = id;
      _existingSubdomain = null;
    });
    try {
      final sub = await _cf.subdomain(id);
      if (mounted) setState(() => _existingSubdomain = sub);
    } catch (e) {
      if (mounted) setState(() => _deployError = describeError(e));
    }
  }

  /// What this device knows of the hub: its own deploy record, or else the
  /// connected hub link (another computer made the hub; the link was synced
  /// or scanned) when it is the hub at this address.
  Future<HubDeployment?> _previous(String account, String subdomain) async {
    final mine = ref.read(hubDeploymentProvider).value;
    if (mine != null && mine.accountId == account) return mine;
    final link = await ref.read(hubLinkProvider.future);
    final name = (await ref.read(hubBundleProvider.future)).name;
    if (!link.ready || link.url != 'https://$name.$subdomain.workers.dev') return mine;
    return HubDeployment(
      cloudflareToken: _key.text.trim(),
      accountId: account,
      url: link.url,
      apiToken: link.token,
    );
  }

  Future<void> _deploy() async {
    final account = _accountId!;
    var sub = _existingSubdomain;
    if (sub == null) {
      final name = _subdomain.text.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(name)) {
        setState(() => _deployError = 'Pick a name of letters, digits and dashes, like rajeev-hub.');
        return;
      }
      sub = name;
    }
    setState(() {
      _deploying = true;
      _deployError = null;
      _r2Off = false;
      for (final s in DeployStep.values) {
        _marks[s] = _Mark.waiting;
      }
    });
    DeployStep? current;
    try {
      final cf = _cf;
      if (_existingSubdomain == null) {
        _existingSubdomain = await cf.createSubdomain(account, sub);
        sub = _existingSubdomain!;
      }
      final result = await deployHub(
        cf: cf,
        accountId: account,
        subdomain: sub,
        bundle: await ref.read(hubBundleProvider.future),
        previous: await _previous(account, sub),
        client: ref.read(httpClientProvider),
        onStep: (s) => setState(() {
          if (current != null) _marks[current!] = _Mark.done;
          _marks[current = s] = _Mark.running;
        }),
      );
      await ref.read(hubDeploymentProvider.notifier).save(result.deployment);
      if (result.link.ready) await saveHubLink(ref, result.link);
      ref.invalidate(hubVersionProvider);
      setState(() {
        if (current != null) _marks[current!] = _Mark.done;
        _result = result;
        _stage = _Stage.done;
      });
    } catch (e) {
      setState(() {
        if (current != null) _marks[current!] = _Mark.failed;
        _r2Off = e is CloudflareException && e.r2Disabled;
        _deployError = _r2Off
            ? 'R2 is not switched on yet. Do step 2, then tap Set up again.'
            : describeError(e);
      });
    } finally {
      if (mounted) setState(() => _deploying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updating = ref.watch(hubDeploymentProvider).value != null;
    return Scaffold(
      appBar: AppBar(title: Text(updating ? 'Update your hub' : 'Set up your hub')),
      body: PageBody(
        maxWidth: 760,
        children: [
          Text(
            'Your hub is a small program on your own free Cloudflare account. It keeps your accounts '
            'signed in, posts on schedule and collects replies while your phone and computer are off. '
            'Only you can reach it.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Stepper(
            physics: const NeverScrollableScrollPhysics(),
            currentStep: _stage.index,
            onStepTapped: _deploying || _stage == _Stage.done
                ? null
                : (i) => setState(() => _stage = _Stage.values[i]),
            controlsBuilder: (_, _) => const SizedBox.shrink(),
            steps: [
              _step(_Stage.account, 'Make a free Cloudflare account', [
                const Text(
                  'Cloudflare runs your hub. The free plan is enough for a few accounts. Sign up with your '
                  'email, confirm it, then come back here. Already have an account? Skip ahead.',
                ),
                _buttons([
                  FilledButton.icon(
                    onPressed: () => openLink(context, 'https://dash.cloudflare.com/sign-up'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Cloudflare sign-up'),
                  ),
                  TextButton(onPressed: () => setState(() => _stage = _Stage.r2), child: const Text('Next')),
                ]),
              ]),
              _step(_Stage.r2, 'Switch on R2 storage', [
                const Text(
                  'R2 keeps the photos and videos you schedule. In the Cloudflare dashboard, open '
                  'R2 Object Storage in the menu on the left and tap Enable (or Purchase R2). The free '
                  'tier costs nothing, but Cloudflare may ask for a card to turn it on.',
                ),
                _buttons([
                  FilledButton.icon(
                    onPressed: () =>
                        openLink(context, 'https://dash.cloudflare.com/?to=/:account/r2/overview'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open R2'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _stage = _Stage.key),
                    child: const Text('Done, next'),
                  ),
                ]),
              ]),
              _step(_Stage.key, 'Make a key for Vani', [
                const Text(
                  'The key lets Vani build the hub on your account. The button opens Cloudflare\'s key page '
                  'with the right permissions filled in: scroll down, tap Continue to summary, then '
                  'Create Token, and copy the key it shows.',
                ),
                const SizedBox(height: 8),
                Text(
                  'If the page opens empty: Create Token > "Edit Cloudflare Workers" template > Use template, '
                  'then Add more: Account / D1 / Edit. It needs Workers Scripts, Workers KV Storage, '
                  'Workers R2 Storage and D1 set to Edit, and Account Settings to Read.',
                  style: TextStyle(color: Tone.of(context).muted),
                ),
                _buttons([
                  OutlinedButton.icon(
                    onPressed: () => openLink(context, '${CloudflareClient.tokenPageUrl}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open the key page'),
                  ),
                ]),
                TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Paste the key here', errorText: _keyError),
                  onSubmitted: (_) => _checkKey(),
                ),
                const SizedBox(height: 8),
                Text(
                  'The key stays on this computer, encrypted, so it can update the hub later. You can '
                  'delete it in Cloudflare any time; the hub keeps running.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Tone.of(context).muted),
                ),
                _buttons([
                  FilledButton(
                    onPressed: _checking ? null : _checkKey,
                    child: Text(_checking ? 'Checking…' : 'Check the key'),
                  ),
                ]),
              ]),
              _step(_Stage.deploy, updating ? 'Update the hub' : 'Build the hub', _deployBody(context)),
              _step(_Stage.done, 'Connect your phone', _doneBody(context)),
            ],
          ),
        ],
      ),
    );
  }

  Step _step(_Stage stage, String title, List<Widget> body) => Step(
    title: Text(title),
    isActive: _stage.index >= stage.index,
    state: _stage.index > stage.index ? StepState.complete : StepState.indexed,
    content: Align(
      alignment: Alignment.centerLeft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
    ),
  );

  Widget _buttons(List<Widget> buttons) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
  );

  List<Widget> _deployBody(BuildContext context) {
    final tone = Tone.of(context);
    return [
      if (_accounts.length > 1)
        DropdownButton<String>(
          value: _accountId,
          onChanged: _deploying ? null : (id) => id == null ? null : _pickAccount(id),
          items: [for (final a in _accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
        ),
      if (_accountId != null && _existingSubdomain == null) ...[
        const Text(
          'Your account has no workers.dev name yet. Pick one: your hub\'s address will be '
          'vani-hub.<name>.workers.dev. It cannot easily be changed later.',
        ),
        TextField(
          controller: _subdomain,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. rajeev-hub'),
        ),
      ] else if (_existingSubdomain != null)
        Text('Address: https://vani-hub.$_existingSubdomain.workers.dev'),
      const SizedBox(height: 12),
      for (final s in DeployStep.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: switch (_marks[s]!) {
                  _Mark.waiting => Icon(Icons.radio_button_unchecked_rounded, size: 18, color: tone.muted),
                  _Mark.running => const CircularProgressIndicator(strokeWidth: 2),
                  _Mark.done => const Icon(Icons.check_circle_rounded, size: 18, color: growth),
                  _Mark.failed => const Icon(Icons.error_rounded, size: 18, color: signal),
                },
              ),
              const SizedBox(width: 10),
              Text(s.label),
            ],
          ),
        ),
      if (_deployError != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_deployError!, style: const TextStyle(color: signal)),
        ),
      _buttons([
        FilledButton.icon(
          onPressed: _deploying || _accountId == null ? null : _deploy,
          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
          label: Text(_deploying ? 'Working… (a minute or two)' : 'Set up'),
        ),
        if (_r2Off)
          TextButton(
            onPressed: () => setState(() => _stage = _Stage.r2),
            child: const Text('Back to step 2'),
          ),
      ]),
    ];
  }

  List<Widget> _doneBody(BuildContext context) {
    final r = _result;
    if (r == null) return const [];
    final t = Theme.of(context).textTheme;
    if (!r.link.ready) {
      return [
        const Text(
          'Your hub is updated. Another device set it up, so this computer does not have its key yet. '
          'On a device where Vani is connected, open Settings > Social hub > Phone link, then scan it '
          'here or copy it into Connect hub.',
        ),
        _buttons([
          FilledButton(
            onPressed: () async {
              await editHub(context, ref);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Connect hub'),
          ),
        ]),
      ];
    }
    final topic = r.deployment.ntfyTopic;
    return [
      Text(r.updated ? 'Your hub is up to date.' : 'Your hub is live and this computer is connected.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _qr(
            context,
            '1. Vani on your phone',
            'Install Vani, then scan this with the phone\'s camera. Keep it private: it is the key to your hub.',
            r.link.toPairingLink(),
          ),
          if (topic.isNotEmpty)
            _qr(
              context,
              '2. Alerts on your phone',
              'Install the free ntfy app, tap +, and subscribe to $topic (or scan this).',
              r.deployment.ntfyUrl,
            ),
        ],
      ),
      _buttons([
        OutlinedButton.icon(
          onPressed: () =>
              copyText(context, r.link.toPairingLink(), what: 'Phone link copied. Send it only to yourself.'),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy phone link'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            if (await guarded(context, () => ref.hub((h) => h.testNotify(), refresh: false)) &&
                context.mounted) {
              showMessage(context, 'Test alert sent.');
            }
          },
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: const Text('Send a test alert'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Finish')),
      ]),
      Text(
        'Next: connect your accounts in Accounts.',
        style: t.bodySmall?.copyWith(color: Tone.of(context).muted),
      ),
    ];
  }

  Widget _qr(BuildContext context, String title, String text, String data) => SizedBox(
    width: 260,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        QrCodeView(data, size: 200),
      ],
    ),
  );
}
