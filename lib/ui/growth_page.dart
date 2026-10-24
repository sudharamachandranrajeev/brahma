import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/insights.dart';
import '../domain/json.dart';
import '../domain/pipeline.dart';
import 'common.dart';
import 'look.dart';

const _kindIcons = {
  'certification': Icons.verified_outlined,
  'course': Icons.menu_book_outlined,
  'degree': Icons.school_outlined,
  'skill': Icons.build_outlined,
  'experience': Icons.work_history_outlined,
  'goal': Icons.flag_outlined,
};

class GrowthPage extends ConsumerStatefulWidget {
  const GrowthPage({super.key});

  @override
  ConsumerState<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends ConsumerState<GrowthPage> {
  var showDone = false;

  @override
  Widget build(BuildContext context) {
    final assessment = ref.watch(latestReportProvider('assessment')).value;
    return PageScaffold(
      title: 'Growth',
      banner: 'page.growth',
      actions: [
        if (assessment != null)
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add suggestions from your assessment',
            onPressed: () async {
              final n = await ref.mutate(
                (s) => s.book.suggestLearning(
                  Assessment(decodeObject(assessment.content)).learning,
                  today: today(),
                ),
              );
              if (context.mounted) {
                showMessage(context, n == 0 ? 'Nothing new to add.' : 'Added $n suggestions.');
              }
            },
          ),
      ],
      fab: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('Show done and dropped'),
            selected: showDone,
            onSelected: (v) => setState(() => showDone = v),
          ),
        ),
        const SizedBox(height: 12),
        AsyncView(
          ref.watch(growthProvider),
          builder: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                icon: Icons.school_outlined,
                title: 'Nothing planned yet',
                message:
                    'Run the assessment on the Career page for certifications and courses that move you on, '
                    'or pick a career path to turn its steps into goals.',
              );
            }
            const order = ['doing', 'planned', 'suggested', 'done', 'dropped'];
            final statuses = order.where((s) => showDone || (s != 'done' && s != 'dropped'));
            final active = all.where((g) => g.status == 'doing' || g.status == 'planned').length;
            final done = all.where((g) => g.status == 'done').length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TiltGrid(
                  minWidth: 150,
                  children: [
                    KpiTile(label: 'Under way', value: '$active', icon: Icons.trending_up),
                    KpiTile(label: 'Done', value: '$done', icon: Icons.emoji_events_outlined),
                    KpiTile(
                      label: 'Suggested',
                      value: '${all.where((g) => g.status == 'suggested').length}',
                      icon: Icons.lightbulb_outline,
                    ),
                  ],
                ),
                for (final s in statuses)
                  if (all.any((g) => g.status == s)) ...[
                    Subhead(growthStatuses[s]!),
                    for (final g in all.where((g) => g.status == s))
                      _GrowthTile(g, onEdit: () => _edit(context, g)),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, GrowthItem? g) {
    final title = TextEditingController(text: g?.title);
    final provider = TextEditingController(text: g?.provider);
    final url = TextEditingController(text: g?.url);
    final why = TextEditingController(text: g?.why);
    final cost = TextEditingController(text: g?.cost);
    final duration = TextEditingController(text: g?.duration);
    var kind = g?.kind ?? 'certification';
    var status = g?.status ?? 'planned';
    String? target = g?.target;
    return showFormDialog(
      context,
      title: g == null ? 'Add to your plan' : g.title,
      fields: (setState) => [
        Field(title, 'What', autofocus: g == null),
        Choice<String>(
          label: 'Kind',
          value: kind,
          options: growthKinds,
          onChanged: (v) => setState(() => kind = v),
        ),
        Choice<String>(
          label: 'Status',
          value: status,
          options: growthStatuses,
          onChanged: (v) => setState(() => status = v),
        ),
        Field(provider, 'Provider or awarding body'),
        Field(url, 'Link'),
        Field(cost, 'Cost'),
        Field(duration, 'Time it takes'),
        Field(why, 'Why', lines: 2),
        if (target == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => target = addMonths(today(), 3)),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Set a target date'),
            ),
          )
        else
          DateField(value: target!, label: 'Target date', onChanged: (v) => setState(() => target = v)),
        if (g != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await ref.mutate((s) => s.book.remove(s.db.careerGrowth, g.id));
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop(false);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty) return 'Enter what it is.';
        final id = g?.id ?? newId();
        await ref.mutate(
          (s) => s.book.save(
            s.db.careerGrowth,
            CareerGrowthCompanion.insert(
              id: id,
              title: title.text.trim(),
              kind: kind,
              provider: Value(provider.text.trim()),
              url: Value(url.text.trim()),
              why: Value(why.text.trim()),
              cost: Value(cost.text.trim()),
              duration: Value(duration.text.trim()),
              status: Value(status),
              progress: Value(status == 'done' ? 100 : g?.progress ?? 0),
              target: Value(target),
              done: Value(status == 'done' ? g?.done ?? today() : null),
              path: Value(g?.path ?? ''),
              added: g?.added ?? today(),
            ),
            id,
          ),
        );
        return null;
      },
    );
  }
}

class _GrowthTile extends ConsumerWidget {
  const _GrowthTile(this.g, {required this.onEdit});
  final GrowthItem g;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today();
    final late = g.target != null && g.status != 'done' && g.target!.compareTo(now) < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_kindIcons[g.kind] ?? Icons.school_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.title, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        [
                          growthKinds[g.kind] ?? g.kind,
                          g.provider,
                          g.cost,
                          g.duration,
                          if (g.path.isNotEmpty) 'for ${g.path}',
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                    ],
                  ),
                ),
                if (g.url.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open',
                    onPressed: () => openLink(context, g.url),
                  ),
                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: onEdit),
              ],
            ),
            if (g.why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(g.why)),
            if (g.target != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StatusLabel(late ? Status.warning : Status.info, 'Target ${niceDate(g.target!)}'),
              ),
            if (g.status == 'doing' || g.status == 'planned')
              _Progress(
                g.progress,
                onDone: (v) => ref.mutate((s) => s.book.setGrowth(g, progress: v, today: now)),
              )
            else if (g.status == 'suggested')
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => ref.mutate((s) => s.book.setGrowth(g, status: 'planned', today: now)),
                      child: const Text('Plan it'),
                    ),
                    TextButton(
                      onPressed: () => ref.mutate((s) => s.book.setGrowth(g, status: 'dropped', today: now)),
                      child: const Text('Not for me'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A progress slider that moves while dragged and saves when let go.
class _Progress extends StatefulWidget {
  const _Progress(this.value, {required this.onDone});
  final int value;
  final ValueChanged<int> onDone;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  late double v = widget.value.toDouble();

  @override
  void didUpdateWidget(_Progress old) {
    super.didUpdateWidget(old);
    v = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Slider(
          value: v,
          max: 100,
          divisions: 10,
          label: '${v.round()}%',
          semanticFormatterCallback: (v) => '${v.round()}% done',
          onChanged: (x) => setState(() => v = x),
          onChangeEnd: (x) => widget.onDone(x.round()),
        ),
      ),
      SizedBox(width: 44, child: Text('${v.round()}%', style: tabular)),
    ],
  );
}
