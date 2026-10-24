import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "in 3 days", "today", "2 days ago".
String relativeDay(String date, String today) {
  final days = DateTime.parse('${date}T00:00Z').difference(DateTime.parse('${today}T00:00Z')).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    > 0 => 'in $days days',
    _ => '${-days} days ago',
  };
}

String minutesText(int m) => m < 60 ? '$m min' : '${(m / 60).toStringAsFixed(m % 60 == 0 ? 0 : 1)} h';

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return showMessage(context, 'Not a web address: $url');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showMessage(context, 'Nothing on this device can open $uri.');
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
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String label;
  final bool number;
  final int lines;
  final String? hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 8,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

num? numberIn(TextEditingController c) => num.tryParse(c.text.replaceAll(RegExp(r'[,%\s]'), ''));

/// A form in a dialog with Cancel and a save button; returns whether saved.
/// [onSave] returns an error message to show, or null when done.
Future<bool> showFormDialog(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setState) fields,
  required Future<String?> Function() onSave,
  String action = 'Save',
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
            width: 480,
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

Future<bool> askSure(BuildContext context, String title, String message, {String action = 'Delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// A date field that opens the date picker.
class DatePick extends StatelessWidget {
  const DatePick({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final now = DateTime.parse('${today()}T00:00:00');
        final d = await showDatePicker(
          context: context,
          initialDate: value == null ? now : DateTime.parse('${value}T00:00:00'),
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 10),
        );
        if (d != null) onChanged(isoDate(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event)
              : IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
        ),
        child: Text(value == null ? 'Not set' : niceDate(value!)),
      ),
    ),
  );
}
