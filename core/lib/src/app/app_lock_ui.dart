import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock.dart';
import '../ui/widgets.dart';
import 'providers.dart';

/// What the device's own unlock is called here.
String get deviceUnlockName => Platform.isWindows ? 'Windows Hello' : 'fingerprint, face or device PIN';

/// Covers the app while it is locked; put it in MaterialApp.builder so every
/// page is under it. The app stays built underneath, where it was, but
/// hidden, silent and out of focus.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    // Until the lock is read, nothing shows: the app may be locked.
    final covered = lock.value?.locked ?? true;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: covered,
          child: ExcludeSemantics(
            excluding: covered,
            child: TickerMode(
              enabled: !covered,
              child: Offstage(offstage: covered, child: child),
            ),
          ),
        ),
        if (lock.hasError && !lock.hasValue)
          Material(
            child: Center(
              child: ErrorPanel(describeError(lock.error!), onRetry: () => ref.invalidate(appLockProvider)),
            ),
          )
        else if (covered)
          lock.hasValue
              // Its own navigator: text fields and dialogs need an overlay,
              // and the app's navigator is under the cover. Heroes stay with
              // the app's navigator: two cannot share the app's controller.
              ? HeroControllerScope.none(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _LockScreen()),
                  ),
                )
              : ColoredBox(color: Theme.of(context).colorScheme.surface),
      ],
    );
  }
}

enum _Step { pin, forgot, newPin }

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final _pin = TextEditingController(), _again = TextEditingController(), _password = TextEditingController();
  var _step = _Step.pin;
  var _busy = false;
  String? _error;
  bool? _signedIn;

  AppLock get _lock => ref.read(appLockProvider.notifier);

  @override
  void initState() {
    super.initState();
    ref.read(keyVaultProvider).session().then((s) {
      if (mounted) setState(() => _signedIn = s != null);
    });
    // Offer the device's own unlock straight away, when allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ref.read(appLockProvider).value?.device == true &&
          await ref.read(deviceAuthAvailableProvider.future)) {
        await _run(_lock.unlockWithDevice);
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_pin, _again, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
    _pin.clear();
    _again.clear();
    _password.clear();
  });

  Future<void> _unlock() => _run(() async {
    try {
      await _lock.unlockWithPin(_pin.text);
    } finally {
      _pin.clear();
    }
  });

  Future<void> _replace() => _run(() async {
    if (_pin.text != _again.text) throw LockException('The PINs do not match');
    await _lock.replacePin(_pin.text);
  });

  Future<void> _proveWithDevice() => _run(() async {
    if (await _lock.proveWithDevice()) _go(_Step.newPin);
  });

  Future<void> _proveWithPassword() => _run(() async {
    await _lock.proveWithPassword(_password.text);
    _go(_Step.newPin);
  });

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appIdentityProvider);
    final lock = ref.watch(appLockProvider).value ?? const AppLockState();
    final device = ref.watch(deviceAuthAvailableProvider).value ?? false;
    final type = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (title, body) = switch (_step) {
      _Step.pin => (
        '${app.name} is locked',
        <Widget>[
          _PinField(_pin, label: 'PIN', autofocus: true, onSubmitted: (_) => _unlock()),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _unlock, child: const Text('Unlock')),
          if (lock.device && device) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_lock.unlockWithDevice),
              icon: const Icon(Icons.fingerprint),
              label: Text('Use $deviceUnlockName'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : () => _go(_Step.forgot), child: const Text('Forgot PIN?')),
        ],
      ),
      _Step.forgot => (
        'Forgot your PIN?',
        <Widget>[
          Text(
            'Show it is you, then set a new PIN. Nothing in ${app.name} is lost.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (device) ...[
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _proveWithDevice,
              icon: const Icon(Icons.fingerprint),
              label: Text('Use $deviceUnlockName'),
            ),
            const SizedBox(height: 16),
          ],
          if (_signedIn == true) ...[
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Sync password', border: OutlineInputBorder()),
              onSubmitted: (_) => _proveWithPassword(),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : _proveWithPassword,
              child: const Text('Check password'),
            ),
          ] else if (_signedIn == false && !device)
            Text(
              'This device has no sync account and no device lock to check, so the PIN cannot be '
              'reset here. Removing the "${app.id}.lock" entry from the system keychain turns the '
              'app lock off.',
              textAlign: TextAlign.center,
              style: type.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : () => _go(_Step.pin), child: const Text('Back')),
        ],
      ),
      _Step.newPin => (
        'Set a new PIN',
        <Widget>[
          _PinField(_pin, label: 'New PIN', autofocus: true),
          const SizedBox(height: 12),
          _PinField(_again, label: 'Repeat PIN', onSubmitted: (_) => _replace()),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _replace, child: const Text('Set PIN and unlock')),
        ],
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: type.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ...body,
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField(this.controller, {required this.label, this.autofocus = false, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    onSubmitted: onSubmitted,
  );
}

/// Asks for PINs in a dialog and hands them to [submit]; a failure shows in
/// the dialog. Returns whether [submit] succeeded.
Future<bool> _pinDialog(
  BuildContext context, {
  required String title,
  required List<String> labels,
  required String action,
  required Future<void> Function(List<String> pins, bool device) submit,
  String? deviceLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PinDialog(title: title, labels: labels, action: action, submit: submit, deviceLabel: deviceLabel),
    ) ??
    false;

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.labels,
    required this.action,
    required this.submit,
    this.deviceLabel,
  });
  final String title;
  final List<String> labels;
  final String action;
  final Future<void> Function(List<String> pins, bool device) submit;
  final String? deviceLabel;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  // Owned here, so they outlive the dialog's closing animation.
  late final _fields = [for (final _ in widget.labels) TextEditingController()];
  var _device = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit([for (final f in _fields) f.text], _device);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, label) in widget.labels.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PinField(
                _fields[i],
                label: label,
                autofocus: i == 0,
                onSubmitted: i == widget.labels.length - 1 ? (_) => _go() : null,
              ),
            ),
          if (widget.deviceLabel case final label?)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _device,
              onChanged: (v) => setState(() => _device = v ?? false),
              title: Text(label),
            ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _go, child: Text(widget.action)),
    ],
  );
}

/// Turns the app lock on: asks for a new PIN twice and, where the device
/// has its own unlock, whether that may open the app too.
Future<bool> showSetPin(BuildContext context, WidgetRef ref) async {
  final device = await ref.read(deviceAuthAvailableProvider.future);
  if (!context.mounted) return false;
  return _pinDialog(
    context,
    title: 'Turn on app lock',
    labels: ['New PIN (at least $minPinLength digits)', 'Repeat PIN'],
    action: 'Turn on',
    deviceLabel: device ? 'Also unlock with $deviceUnlockName' : null,
    submit: (pins, device) {
      if (pins[0] != pins[1]) throw LockException('The PINs do not match');
      return ref.read(appLockProvider.notifier).enable(pins[0], device: device);
    },
  );
}

/// The app lock in Settings: on or off, the device's own unlock, a new PIN
/// and locking now.
class AppLockCard extends ConsumerWidget {
  const AppLockCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appIdentityProvider);
    final lock = ref.watch(appLockProvider).value ?? const AppLockState();
    final device = ref.watch(deviceAuthAvailableProvider).value ?? false;
    final notifier = ref.read(appLockProvider.notifier);
    return SectionCard(
      title: 'App lock',
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Lock ${app.name}'),
            subtitle: const Text('Ask for a PIN at start and after a minute away.'),
            value: lock.enabled,
            onChanged: (on) async {
              final done = on
                  ? await showSetPin(context, ref)
                  : await _pinDialog(
                      context,
                      title: 'Turn off app lock',
                      labels: const ['PIN'],
                      action: 'Turn off',
                      submit: (pins, _) => notifier.disable(pins[0]),
                    );
              if (done && context.mounted) showMessage(context, on ? 'App lock is on.' : 'App lock is off.');
            },
          ),
          if (lock.enabled) ...[
            if (device)
              SwitchListTile(
                title: Text('Unlock with $deviceUnlockName'),
                value: lock.device,
                onChanged: notifier.setDevice,
              ),
            ListTile(
              title: const Text('PIN'),
              trailing: OutlinedButton(
                onPressed: () async {
                  final done = await _pinDialog(
                    context,
                    title: 'Change PIN',
                    labels: const ['Current PIN', 'New PIN', 'Repeat new PIN'],
                    action: 'Change',
                    submit: (pins, _) {
                      if (pins[1] != pins[2]) throw LockException('The new PINs do not match');
                      return notifier.changePin(pins[0], pins[1]);
                    },
                  );
                  if (done && context.mounted) showMessage(context, 'PIN changed.');
                },
                child: const Text('Change'),
              ),
            ),
            ListTile(
              title: const Text('Lock now'),
              trailing: OutlinedButton(onPressed: notifier.lock, child: const Text('Lock')),
            ),
          ],
        ],
      ),
    );
  }
}
