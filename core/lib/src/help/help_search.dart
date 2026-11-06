import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/modules.dart';
import '../app/providers.dart';
import 'ask_ai_ui.dart';

/// Help that works with no AI and no network: a search over the app's own
/// guide (its hint texts), each answer tied to the screen it is about.

/// One answer: the guide text, and the screen it belongs to when known.
typedef HelpHit = ({String id, String text, Destination? screen});

/// Hint ids name their screen first (`hunt.add`, `page.hunt`, `nav.hunt`).
Destination? _screenOf(String id, List<Destination> screens) {
  final parts = id.split('.');
  final key = (parts.first == 'page' || parts.first == 'nav') && parts.length > 1 ? parts[1] : parts.first;
  for (final d in screens) {
    if (d.id == key) return d;
  }
  return null;
}

final _word = RegExp(r"[a-z0-9£']+");

/// Small, plain stemming so "searches", "searching" and "search" match.
String _stem(String w) {
  for (final end in const ['ing', 'ies', 'es', 'ed', 's']) {
    if (w.length > end.length + 2 && w.endsWith(end)) {
      return end == 'ies' ? '${w.substring(0, w.length - 3)}y' : w.substring(0, w.length - end.length);
    }
  }
  return w;
}

const _stop = {
  'a',
  'an',
  'the',
  'to',
  'of',
  'in',
  'on',
  'for',
  'and',
  'or',
  'is',
  'it',
  'i',
  'my',
  'me',
  'do',
  'how',
  'can',
  'what',
  'where',
  'which',
  'with',
  'this',
  'that',
  'be',
  'are',
  'you',
  'your',
  'from',
  'at',
  'by',
};

Set<String> _terms(String text) => {
  for (final m in _word.allMatches(text.toLowerCase()))
    if (!_stop.contains(m[0])) _stem(m[0]!),
};

/// The guide entries that best answer [query], best first. A term in the
/// screen's name counts as well as one in the text; a word that starts a
/// longer one ("rent" in "rental") counts for less.
List<HelpHit> searchHelp(
  String query,
  Map<String, String> hints,
  List<Destination> screens, {
  int limit = 8,
}) {
  final asked = _terms(query);
  if (asked.isEmpty) return const [];
  final scored = <(double, HelpHit)>[];
  hints.forEach((id, text) {
    final screen = _screenOf(id, screens);
    final words = _terms('$text ${screen?.label ?? ''} ${id.replaceAll('.', ' ')}');
    var score = 0.0;
    for (final t in asked) {
      if (words.contains(t)) {
        score += 1;
      } else if (t.length >= 3 && words.any((w) => w.startsWith(t) || t.startsWith(w) && w.length >= 3)) {
        score += 0.5;
      }
    }
    if (score == 0) return;
    // A screen's own banner is the best start for a general question.
    if (id.startsWith('page.')) score += 0.25;
    scored.add((score, (id: id, text: text, screen: screen)));
  });
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final s in scored.take(limit)) s.$2];
}

/// The Help dialog: search the app's features offline, go to the screen an
/// answer is about, or pass the question on to Ask AI.
Future<void> showHelp(
  BuildContext context, {
  required List<Destination> screens,
  required Destination current,
  required void Function(Destination) onGo,
}) => showDialog<void>(
  context: context,
  builder: (_) => _HelpDialog(screens: screens, current: current, onGo: onGo),
);

class _HelpDialog extends ConsumerStatefulWidget {
  const _HelpDialog({required this.screens, required this.current, required this.onGo});
  final List<Destination> screens;
  final Destination current;
  final void Function(Destination) onGo;

  @override
  ConsumerState<_HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends ConsumerState<_HelpDialog> {
  final _query = TextEditingController();
  var _hits = <HelpHit>[];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String q) =>
      setState(() => _hits = searchHelp(q, ref.read(hintTextsProvider), widget.screens));

  void _ask() {
    final hints = ref.read(hintTextsProvider);
    final question = _query.text.trim();
    Navigator.of(context).pop();
    showAskAi(
      context,
      screen: widget.current.label,
      topic: hints['page.${widget.current.id}'],
      question: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asked = _query.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Help'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'What do you want to do? e.g. "merge duplicates"',
              ),
              onChanged: _search,
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: !asked
                  ? Text(
                      'Search works offline, from this app\'s own guide. Ask AI answers questions it cannot.',
                      style: theme.textTheme.bodySmall,
                    )
                  : _hits.isEmpty
                  ? Text(
                      'Nothing in the guide matches. Try other words, or ask AI.',
                      style: theme.textTheme.bodySmall,
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final h in _hits)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(h.screen?.icon ?? Icons.help_outline),
                            title: Text(h.text),
                            subtitle: h.screen == null ? null : Text(h.screen!.label),
                            trailing: h.screen == null
                                ? null
                                : TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onGo(h.screen!);
                                    },
                                    child: const Text('Go there'),
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _ask,
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('Ask AI'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
