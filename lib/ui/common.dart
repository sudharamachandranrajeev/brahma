import 'package:brahma_core/brahma_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/ai.dart';
import '../domain/json.dart';

/// "2026-10-24T11:00" as "24 Oct 2026, 11:00".
String niceDateTime(String at) =>
    at.length > 10 ? '${niceDate(at.substring(0, 10))}, ${at.substring(11, 16)}' : niceDate(at);

/// Now as local yyyy-MM-ddTHH:mm.
String nowLocal() => DateTime.now().toIso8601String().substring(0, 16);

/// "in 3 days", "today", "2 days ago".
String relativeDay(String date, String today) {
  // In UTC, so a daylight-saving change cannot shorten a day.
  final days = DateTime.parse('${date}T00:00Z').difference(DateTime.parse('${today}T00:00Z')).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    > 0 => 'in $days days',
    _ => '${-days} days ago',
  };
}

extension IfEmpty on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Opens [uri] in the platform's app for it (browser, mail, dialler).
Future<bool> openUri(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showMessage(context, 'Nothing on this device can open $uri.');
  return ok;
}

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return showMessage(context, 'Not a web address: $url');
  await openUri(context, uri);
}

Future<void> copyText(BuildContext context, String text, {String what = 'Copied.'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMessage(context, what);
}

/// Saves [bytes] where the user chooses; returns whether it was saved.
Future<bool> saveBytes(BuildContext context, String fileName, Uint8List bytes, {String mime = ''}) async {
  try {
    final where = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
      dialogTitle: 'Save $fileName',
    );
    if (where != null && context.mounted) showMessage(context, 'Saved $fileName.');
    return where != null;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Runs an AI task (or an update) in a dialog that shows what it is doing
/// ("Searching: ..."). Returns the result, or null when it failed (the error is shown).
Future<T?> runAi<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(void Function(String status) progress) task,
  String status = 'Asking the AI…',
}) async {
  final notifier = ValueNotifier(status);
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Row(
            children: [
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: notifier,
                  builder: (_, s, _) => Text(s, maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final r = await task((s) => notifier.value = s);
    nav.pop();
    return r;
  } catch (e) {
    nav.pop();
    if (context.mounted) showError(context, e);
    return null;
  } finally {
    notifier.dispose();
  }
}

/// A plain text field with a label.
class Field extends StatelessWidget {
  const Field(
    this.controller,
    this.label, {
    super.key,
    this.number = false,
    this.lines = 1,
    this.hint,
    this.helper,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String label;
  final bool number;
  final int lines;
  final String? hint, helper, prefix, suffix;
  final bool autofocus, obscure;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 6,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        prefixText: prefix,
        suffixText: suffix,
      ),
    ),
  );
}

/// The number in a field, or null when empty or not a number.
num? numberIn(TextEditingController c) => num.tryParse(c.text.replaceAll(RegExp(r'[£$€,%\s]'), ''));
int? intIn(TextEditingController c) => numberIn(c)?.round();

/// Items of a field with one per line (or comma-separated on one line).
List<String> linesIn(TextEditingController c) {
  final t = c.text.trim();
  final parts = t.contains('\n') ? t.split('\n') : t.split(',');
  return parts
      .map((s) => s.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
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
              child: Text(action),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
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
      items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// The status a 0-100 fit score reads as.
Status fitStatus(int fit) => switch (fit) {
  >= 75 => Status.good,
  >= 55 => Status.info,
  >= 35 => Status.warning,
  _ => Status.serious,
};

/// A fit score as a small labelled chip, with an icon so it is not colour alone.
class FitBadge extends StatelessWidget {
  const FitBadge(this.fit, {super.key, this.ai = false});
  final int? fit;

  /// Scored by the AI rather than the local match.
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final f = fit;
    if (f == null) return const SizedBox.shrink();
    final s = fitStatus(f);
    return Tooltip(
      message: ai ? 'Fit assessed by the AI' : 'Quick match from your profile',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: s.color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ai ? Icons.auto_awesome : s.icon, size: 14, color: s.color),
            const SizedBox(width: 4),
            Text('$f%', style: tabular.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Lines with a leading icon, for strengths, gaps, tips.
class Bullets extends StatelessWidget {
  const Bullets(this.items, {super.key, this.icon = Icons.chevron_right, this.color});
  final List<String> items;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: color ?? Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: SelectableText(t)),
            ],
          ),
        ),
    ],
  );
}

/// A small heading inside a card.
class Subhead extends StatelessWidget {
  const Subhead(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// The web pages an AI answer relied on, as links.
class SourcesList extends StatelessWidget {
  const SourcesList(this.sources, {super.key});
  final List<Source> sources;

  static List<Source> of(Object? list) => [
    for (final o in objs(list))
      if (str(o['url']).isNotEmpty) (title: str(o['title']), url: str(o['url'])),
  ];

  static List<Source> fromJson(String json) => of(decodeList(json));

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Sources (${sources.length})'),
      children: [
        for (final s in sources)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link, size: 18),
            title: Text(s.title.isEmpty ? Uri.tryParse(s.url)?.host ?? s.url : s.title),
            subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => openLink(context, s.url),
          ),
      ],
    );
  }
}

/// Shown where an AI feature needs the key: says so, with no dead button.
class NeedsKey extends StatelessWidget {
  const NeedsKey({super.key, this.what = 'This'});
  final String what;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Status.info.icon, size: 18, color: Status.info.color),
        const SizedBox(width: 8),
        Expanded(child: Text('$what uses the AI. Add a free Gemini key or a Claude API key in Settings.')),
      ],
    ),
  );
}
