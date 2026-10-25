import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/providers.dart';
import '../domain/hub.dart';
import 'hub_setup.dart';
import 'look.dart';

/// A hub time (ISO, UTC) in the device's time zone, or null.
DateTime? localTime(String? iso) => iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

/// A local time as the hub takes it: ISO in UTC.
String hubTime(DateTime local) => local.toUtc().toIso8601String();

/// "now", "5m", "3h", "2d", or the date for older times.
String ago(String iso, {DateTime? now}) {
  final t = localTime(iso);
  if (t == null) return '';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return DateFormat('d MMM').format(t);
}

/// "Today 18:30", "Tomorrow 09:00", "Fri 12 Nov, 18:30".
String whenLabel(String? iso, {DateTime? now}) {
  final t = localTime(iso);
  if (t == null) return 'Not scheduled';
  final n = now ?? DateTime.now();
  final days = DateUtils.dateOnly(t).difference(DateUtils.dateOnly(n)).inDays;
  final time = DateFormat.Hm().format(t);
  return switch (days) {
    0 => 'Today $time',
    1 => 'Tomorrow $time',
    -1 => 'Yesterday $time',
    _ => '${DateFormat('EEE d MMM').format(t)}, $time',
  };
}

const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Comma or newline separated text as a trimmed list without blanks.
List<String> splitList(String text) =>
    text.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

extension IfEmpty on String {
  String ifEmpty(String other) => trim().isEmpty ? other : this;
}

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return showMessage(context, 'Not a web address: $url');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showMessage(context, 'Nothing on this device can open $url.');
}

Future<void> copyText(BuildContext context, String text, {String what = 'Copied.'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, what);
}

/// A form in a dialog with Cancel and a save button; returns whether saved.
/// [onSave] returns an error message to show, or null when done.
Future<bool> showFormDialog(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setState) fields,
  required Future<String?> Function() onSave,
  String action = 'Save',
  double width = 520,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      String? error;
      var busy = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...fields(setState),
                if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      String? e;
                      try {
                        e = await onSave();
                      } catch (x) {
                        e = describeError(x);
                      }
                      if (!context.mounted) return;
                      if (e == null) {
                        Navigator.pop(context, true);
                      } else {
                        setState(() {
                          error = e;
                          busy = false;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(action),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}

/// A text field with a label, spaced for forms.
class Field extends StatelessWidget {
  const Field(
    this.controller,
    this.label, {
    super.key,
    this.hint,
    this.helper,
    this.lines = 1,
    this.obscure = false,
    this.number = false,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String label;
  final String? hint, helper;
  final int lines;
  final bool obscure, number, autofocus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      minLines: lines > 1 ? 2 : 1,
      maxLines: obscure ? 1 : lines,
      keyboardType: number ? TextInputType.number : (lines > 1 ? TextInputType.multiline : null),
      decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 3),
    ),
  );
}

/// A labelled dropdown for small fixed choices.
class Choice<T> extends StatelessWidget {
  const Choice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: options.containsKey(value) ? value : options.keys.first,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// Loading, error and data states of a hub read. Without a hub it offers to
/// connect one; while loading it shows shimmering cards.
class HubView<T> extends ConsumerWidget {
  const HubView(this.value, {super.key, required this.builder, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (stage, child) = value.when(
      skipLoadingOnReload: true,
      data: (data) => (#data, builder(data)),
      error: (error, _) => error is NoHubException
          ? (#nohub, const ConnectHub())
          : (
              #error,
              Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorPanel(
                  describeError(error),
                  onRetry: () => ref.read(hubRevisionProvider.notifier).bump(),
                ),
              ),
            ),
      loading: () => (#loading, loading ?? const LoadingCards()),
    );
    return AnimatedSwitcher(
      duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.topCenter, fit: StackFit.passthrough, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(stage), child: child),
    );
  }
}

/// The first-run state: no hub yet.
class ConnectHub extends ConsumerWidget {
  const ConnectHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Big(
          icon: Icons.hub_rounded,
          title: 'Connect your social hub',
          message:
              'Vani works through your own hub: a small program on your free Cloudflare account that keeps '
              'your accounts signed in, posts on schedule and collects replies while this device is off. '
              'Set one up (about 15 minutes, once, on a computer), or connect the one you have.',
          action: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => setUpHub(context, ref),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Set up a hub'),
              ),
              OutlinedButton.icon(
                onPressed: () => editHub(context, ref),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect hub'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A large, friendly empty state on a card.
class Big extends StatelessWidget {
  const Big({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: signal.withValues(alpha: 0.14),
              border: Border.all(color: signal.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: signal, size: 34),
          ),
          const SizedBox(height: 20),
          Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            message,
            style: t.bodyMedium?.copyWith(color: Tone.of(context).muted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Asks for the hub's address and token, checks them with a real call, then
/// saves them as a synced pref so the user's other devices get them too.
Future<void> editHub(BuildContext context, WidgetRef ref) async {
  final now = await ref.read(hubLinkProvider.future);
  final url = TextEditingController(text: now.url);
  final token = TextEditingController(text: now.token);
  if (!context.mounted) return;
  final saved = await showFormDialog(
    context,
    title: 'Social hub',
    action: 'Connect',
    fields: (_) => [
      const Text(
        'Your hub\'s address and API token, or paste the phone link (vani://hub…) that its setup showed. '
        'They are stored encrypted and synced to your other devices.',
      ),
      const SizedBox(height: 16),
      Field(url, 'Hub address', hint: 'https://vani-hub.you.workers.dev'),
      Field(token, 'API token', obscure: true),
    ],
    onSave: () async {
      var link = HubLink.fromPairingLink(url.text);
      if (link == null) {
        final problem = HubLink.checkUrl(url.text);
        if (problem != null) return problem;
        if (token.text.trim().isEmpty) return 'Enter the API token.';
        link = HubLink(url: url.text.trim().replaceAll(RegExp(r'/+$'), ''), token: token.text.trim());
      }
      // A real call, so a typo shows here and not on every page.
      await saveHubLink(ref, link);
      return null;
    },
  );
  if (saved && context.mounted) showMessage(context, 'Hub connected.');
}

/// A button for an AI feature. Greyed out, with a hint saying where to add
/// the key, while no AI is set up.
class AiButton extends ConsumerWidget {
  const AiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool filled, busy;

  static const _noKey = 'Set up AI in Settings > AI (an API key, or your own plan on a computer) to use the AI features.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Unknown (still loading) counts as ready; the hub answers 412 if not.
    final ready = ref.watch(metaProvider).value?.ai ?? true;
    final icon = busy
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : signal),
          )
        : Icon(Icons.auto_awesome_rounded, size: 18, color: ready && !filled ? signal : null);
    final press = busy ? null : (ready ? onPressed : () => showMessage(context, _noKey));
    final button = filled
        ? FilledButton.icon(
            onPressed: press,
            style: ready
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Tone.of(context).cardHigh,
                    foregroundColor: Tone.of(context).muted,
                  ),
            icon: icon,
            label: Text(label),
          )
        : TextButton.icon(
            onPressed: press,
            style: ready ? null : TextButton.styleFrom(foregroundColor: Tone.of(context).muted),
            icon: icon,
            label: Text(label),
          );
    return ready ? button : Tooltip(message: _noKey, child: button);
  }
}

/// A labelled value to paste somewhere else, with a Copy button.
class Copyable extends StatelessWidget {
  const Copyable(this.label, this.value, {super.key, this.hint});
  final String label, value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(color: tone.cardHigh, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone.muted)),
                SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            onPressed: () => copyText(context, value, what: '$label copied.'),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
    return hint == null ? row : Hint(hint!, child: row);
  }
}
