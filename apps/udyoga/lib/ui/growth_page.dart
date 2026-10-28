import 'dart:isolate';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/insights.dart';
import '../domain/json.dart';
import '../domain/linkedin_export.dart';
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
  'idea': Icons.lightbulb_outline,
  'win': Icons.emoji_events_outlined,
};

/// Where a member asks LinkedIn for a copy of their data.
const _linkedInExportPage = 'https://www.linkedin.com/mypreferences/d/download-my-data';

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
          builder: (items) {
            final all = items.where((g) => !noteKinds.containsKey(g.kind)).toList();
            final notes = items.where((g) => noteKinds.containsKey(g.kind)).toList()
              ..sort((a, b) => b.added.compareTo(a.added));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_plan(all), const SizedBox(height: 12), _NotesCard(notes), const _LinkedInCard()],
            );
          },
        ),
      ],
    );
  }

  Widget _plan(List<GrowthItem> all) {
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
            for (final g in all.where((g) => g.status == s)) _GrowthTile(g, onEdit: () => _edit(context, g)),
          ],
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

/// The candidate's own ideas, tips and wins: anything that could move their
/// career on, jotted down in a few seconds. The AI reads them with the
/// profile in every request.
class _NotesCard extends ConsumerWidget {
  const _NotesCard(this.notes);
  final List<GrowthItem> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Ideas and wins',
    hint: 'growth.notes',
    trailing: TextButton.icon(
      onPressed: () => editNote(context, ref, null),
      icon: const Icon(Icons.add),
      label: const Text('Note'),
    ),
    child: notes.isEmpty
        ? const Text(
            'Jot down anything that could help: an idea, a tip someone gave you, a company to watch, a win '
            'or praise at work. The AI takes them into account in your assessment, career map, job search, '
            'CVs and interview practice.',
          )
        : Column(
            children: [
              for (final n in notes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_kindIcons[n.kind]),
                  title: Text(n.title),
                  subtitle: Text(
                    [if (n.why.isNotEmpty) n.why, '${noteKinds[n.kind]} · ${niceDate(n.added)}'].join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => editNote(context, ref, n),
                  trailing: n.url.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Open',
                          onPressed: () => openLink(context, n.url),
                        ),
                ),
            ],
          ),
  );
}

/// Adds or edits an idea or win; an idea can become a goal in the plan.
Future<void> editNote(BuildContext context, WidgetRef ref, GrowthItem? n) {
  final title = TextEditingController(text: n?.title);
  final detail = TextEditingController(text: n?.why);
  final url = TextEditingController(text: n?.url);
  var kind = n?.kind ?? 'idea';
  return showFormDialog(
    context,
    title: n == null ? 'Add a note' : 'Edit the note',
    fields: (setState) => [
      SegmentedButton<String>(
        segments: [
          for (final e in noteKinds.entries)
            ButtonSegment(value: e.key, label: Text(e.value), icon: Icon(_kindIcons[e.key])),
        ],
        selected: {kind},
        onSelectionChanged: (v) => setState(() => kind = v.first),
      ),
      Field(
        title,
        kind == 'win' ? 'The win' : 'The idea',
        autofocus: n == null,
        hint: kind == 'win'
            ? 'Cut month-end close from 8 days to 5'
            : 'Ask a former colleague about their data team',
      ),
      Field(detail, 'More detail (optional)', lines: 3),
      Field(url, 'Link (optional)'),
      if (n != null)
        Wrap(
          spacing: 8,
          children: [
            if (n.kind == 'idea')
              TextButton.icon(
                onPressed: () async {
                  await ref.mutate(
                    (s) => s.book.save(s.db.careerGrowth, n.copyWith(kind: 'goal', status: 'planned'), n.id),
                  );
                  if (context.mounted) Navigator.of(context, rootNavigator: true).pop(false);
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Make it a goal'),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await ref.mutate((s) => s.book.remove(s.db.careerGrowth, n.id));
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop(false);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Write the note.';
      await ref.mutate(
        (s) => s.book.saveNote(
          id: n?.id,
          kind: kind,
          title: title.text.trim(),
          detail: detail.text.trim(),
          url: url.text.trim(),
          added: n?.added ?? today(),
        ),
      );
      return null;
    },
  );
}

/// Imports the archive LinkedIn gives its members: read on this device,
/// nothing fetched from LinkedIn.
class _LinkedInCard extends ConsumerWidget {
  const _LinkedInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'From LinkedIn',
    hint: 'growth.linkedin',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bring in your LinkedIn data: jobs, skills and certifications fill gaps in your profile, '
          'recommendations become wins, applications and saved jobs join your pipeline, and connections at '
          'the employers you are pursuing (and recruiters) become contacts. Ask LinkedIn for a copy of your '
          'data, then import the ZIP it emails you. It is read on this device; Udyoga never signs in to '
          'LinkedIn.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => importLinkedIn(context, ref),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import the ZIP'),
            ),
            TextButton.icon(
              onPressed: () => openLink(context, _linkedInExportPage),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Get your data from LinkedIn'),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> importLinkedIn(BuildContext context, WidgetRef ref) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: 'Your LinkedIn data (ZIP)',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  final done = await runAi(
    context,
    title: 'LinkedIn data',
    status: 'Reading the archive…',
    task: (progress) async {
      // A full archive holds every message too; unzip it off the UI thread.
      final export = await Isolate.run(() => LinkedInExport.read(bytes));
      progress('Adding it to Udyoga…');
      return ref.mutate((s) => s.book.importLinkedIn(export, today: today()));
    },
  );
  if (done == null || !context.mounted) return;
  String n(int count, String one, [String? many]) => '$count ${count == 1 ? one : many ?? '${one}s'}';
  final parts = [
    if (done.jobs > 0) n(done.jobs, 'job'),
    if (done.skills > 0) n(done.skills, 'skill'),
    if (done.certifications > 0) n(done.certifications, 'certification'),
    if (done.wins > 0) n(done.wins, 'recommendation'),
    if (done.applications > 0) n(done.applications, 'application'),
    if (done.savedJobs > 0) n(done.savedJobs, 'saved job'),
    if (done.contacts > 0) n(done.contacts, 'contact'),
  ];
  showMessage(
    context,
    parts.isEmpty ? 'Nothing new: you already have it all.' : 'Added ${parts.join(', ')}.',
  );
}
