import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/book.dart';
import '../domain/stats.dart';
import 'charts.dart';
import 'common.dart';
import 'dialogs.dart';
import 'zen.dart';

class CoursePage extends ConsumerWidget {
  const CoursePage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Backdrop(
    child: AsyncView(
      ref.watch(statsProvider),
      builder: (s) {
        final c = s.courses.where((x) => x.id == id).firstOrNull;
        if (c == null) return const Scaffold(body: Center(child: Text('This course was deleted.')));
        final t = Theme.of(context).textTheme;
        final topics = s.topicsOf(id);
        final tests = s.assessments.where((a) => a.courseId == id).toList()
          ..sort((a, b) => b.day.compareTo(a.day));
        final spent = s.hoursOn(id);
        return Scaffold(
          appBar: AppBar(
            title: Text(c.title),
            actions: [
              if (c.url.isNotEmpty)
                IconButton(
                  tooltip: 'Open link',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => openLink(context, c.url),
                ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await editCourseDialog(context, ref, c);
                    case 'delete':
                      if (!await askSure(context, 'Delete course?', 'Its topics are deleted too.') ||
                          !context.mounted) {
                        return;
                      }
                      await ref.mutate((x) => x.book.removeCourse(id));
                      if (context.mounted) Navigator.pop(context);
                    default:
                      await ref.mutate((x) => x.book.setCourseStatus(c, v, today: s.today));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  for (final (k, l) in [
                    ('planned', 'Mark planned'),
                    ('doing', 'Mark in progress'),
                    ('done', 'Mark complete'),
                    ('dropped', 'Drop'),
                  ])
                    if (c.status != k) PopupMenuItem(value: k, child: Text(l)),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => logSessionDialog(context, ref, courseId: id),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Log time'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(label: Text(courseKinds[c.kind] ?? c.kind)),
                          Chip(
                            label: Text(switch (c.status) {
                              'done' => 'Complete',
                              'doing' => 'In progress',
                              'dropped' => 'Dropped',
                              _ => 'Planned',
                            }),
                          ),
                          if (c.provider.isNotEmpty) Chip(label: Text(c.provider)),
                          if (c.due != null) Chip(label: Text('Due ${niceDate(c.due!)}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Meter(
                        'Progress',
                        s.courseProgress(c),
                        trailing:
                            '${spent.toStringAsFixed(1)} h studied${c.hours > 0 ? ' of ~${c.hours} h' : ''}',
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Topics',
                        trailing: IconButton(
                          tooltip: 'Add topic',
                          icon: const Icon(Icons.add),
                          onPressed: () => addTopicDialog(context, ref, id),
                        ),
                        child: topics.isEmpty
                            ? const Text('Break the course into topics to track it.')
                            : Column(
                                children: [
                                  for (final tp in topics)
                                    Dismissible(
                                      key: ValueKey(tp.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        child: const Icon(Icons.delete_outline),
                                      ),
                                      confirmDismiss: (_) => askSure(context, 'Delete topic?', tp.title),
                                      onDismissed: (_) =>
                                          ref.mutate((x) => x.book.remove(x.db.learnTopics, tp.id)),
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        value: tp.done != null,
                                        title: Text(
                                          tp.title,
                                          style: tp.done != null
                                              ? const TextStyle(decoration: TextDecoration.lineThrough)
                                              : null,
                                        ),
                                        subtitle: Text(
                                          tp.done != null
                                              ? 'Done ${relativeDay(tp.done!, s.today)}'
                                              : minutesText(tp.minutes),
                                        ),
                                        onChanged: (v) => ref.mutate(
                                          (x) => x.book.setTopicDone(tp, v ?? false, today: s.today),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      SectionCard(
                        title: 'Tests',
                        trailing: IconButton(
                          tooltip: 'Record a test',
                          icon: const Icon(Icons.add),
                          onPressed: () => addAssessmentDialog(context, ref, courseId: id),
                        ),
                        child: tests.isEmpty
                            ? const Text('No tests recorded.')
                            : Column(
                                children: [
                                  if (tests.length > 1)
                                    Sparkline([for (final a in tests.reversed) Stats.percentOf(a)]),
                                  for (final a in tests)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(a.title),
                                      subtitle: Text(niceDate(a.day)),
                                      trailing: Text(
                                        '${Stats.percentOf(a).round()}%',
                                        style: t.titleMedium?.merge(tabular),
                                      ),
                                      onLongPress: () async {
                                        if (await askSure(context, 'Delete test?', a.title) &&
                                            context.mounted) {
                                          await ref.mutate((x) => x.book.remove(x.db.learnAssessments, a.id));
                                        }
                                      },
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
