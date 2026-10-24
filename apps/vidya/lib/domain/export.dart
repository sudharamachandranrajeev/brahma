import 'package:brahma_core/brahma_core.dart';

import 'book.dart';
import 'stats.dart';

/// The portfolio as Markdown, to paste into a CV, a profile or a README:
/// skills by category, the work that shows them, and what was completed.
String portfolioMarkdown(Stats s) {
  final out = StringBuffer('# Portfolio\n');

  final rated = s.skills.where((k) => k.level > 0).toList()
    ..sort((a, b) => b.level != a.level ? b.level.compareTo(a.level) : a.name.compareTo(b.name));
  if (rated.isNotEmpty) {
    out.write('\n## Skills\n\n');
    final byCategory = <String, List<String>>{};
    for (final k in rated) {
      (byCategory[k.category] ??= []).add('${k.name} (${skillLevels[k.level.clamp(0, 5)]})');
    }
    for (final e in byCategory.entries) {
      out.write('- **${e.key}:** ${e.value.join(', ')}\n');
    }
  }

  if (s.portfolio.isNotEmpty) {
    out.write('\n## Work\n');
    for (final p in s.portfolio) {
      final title = p.url.isEmpty ? p.title : '[${p.title}](${p.url})';
      out.write('\n### $title\n\n');
      out.write('${portfolioKinds[p.kind] ?? p.kind} · ${niceDate(p.day)}\n');
      if (p.summary.isNotEmpty) out.write('\n${p.summary}\n');
      if (p.skills.isNotEmpty) out.write('\nSkills: ${p.skills}\n');
    }
  }

  final done = s.courses.where((c) => c.status == 'done').toList()
    ..sort((a, b) => (b.finished ?? '').compareTo(a.finished ?? ''));
  if (done.isNotEmpty) {
    out.write('\n## Learning completed\n\n');
    for (final c in done) {
      final parts = [
        courseKinds[c.kind] ?? c.kind,
        if (c.provider.isNotEmpty) c.provider,
        if (c.finished != null) niceDate(c.finished!),
      ];
      out.write('- ${c.title} (${parts.join(', ')})\n');
    }
  }

  out.write(
    '\n---\n\n${s.hours.round()} hours of study · ${s.topicsDone} topics · '
    '${s.coursesDone} courses completed\n',
  );
  return out.toString();
}
