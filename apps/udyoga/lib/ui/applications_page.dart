import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/calendar.dart';
import '../domain/pipeline.dart';
import 'common.dart';
import 'look.dart';
import 'job_page.dart';
import 'resume_page.dart';

const _eventIcons = {
  'applied': Icons.send_outlined,
  'followup': Icons.mark_email_read_outlined,
  'reply': Icons.mark_email_unread_outlined,
  'interview': Icons.record_voice_over_outlined,
  'offer': Icons.celebration_outlined,
  'accepted': Icons.handshake_outlined,
  'rejected': Icons.block,
  'withdrawn': Icons.undo,
  'note': Icons.sticky_note_2_outlined,
};

/// How a follow-up date reads against today.
Status followUpStatus(String date, String today) => date.compareTo(today) < 0
    ? Status.serious
    : date == today
    ? Status.warning
    : Status.info;

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  var open = true;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Applications',
    banner: 'page.applications',
    actions: [
      HintIconButton(
        'apps.calendar',
        icon: Icons.event_available_outlined,
        label: 'Follow-ups to calendar',
        onPressed: () => exportReminders(context, ref),
      ),
    ],
    fab: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _add(context),
      icon: const Icon(Icons.add),
      label: const Text('Add application'),
    ),
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Active'), icon: Icon(Icons.pending_actions)),
          ButtonSegment(value: false, label: Text('Closed'), icon: Icon(Icons.inventory_2_outlined)),
        ],
        selected: {open},
        onSelectionChanged: (s) => setState(() => open = s.first),
      ),
      const SizedBox(height: 12),
      AsyncView(
        ref.watch(applicationsProvider),
        builder: (all) {
          final mine = all.where((a) => Stage.of(a.stage).open == open).toList();
          if (mine.isEmpty) {
            return EmptyState(
              icon: Icons.send_outlined,
              title: open ? 'No active applications' : 'Nothing closed yet',
              message: open ? 'Apply from a job on the Jobs page, or add one you made elsewhere.' : null,
            );
          }
          final stages = open ? Stage.openStages : Stage.values.where((s) => !s.open).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TiltGrid(
                minWidth: 140,
                children: [
                  for (final s in stages)
                    KpiTile(
                      label: s.label,
                      value: '${mine.where((a) => a.stage == s.id).length}',
                      icon: s.open ? Icons.pending_outlined : Icons.check_circle_outline,
                    ),
                ],
              ),
              for (final s in stages)
                if (mine.any((a) => a.stage == s.id)) ...[
                  Subhead(s.label),
                  for (final a in mine.where((a) => a.stage == s.id)) ApplicationTile(a),
                ],
            ],
          );
        },
      ),
    ],
  );

  Future<void> _add(BuildContext context) {
    final title = TextEditingController();
    final company = TextEditingController();
    final url = TextEditingController();
    var applied = today();
    return showFormDialog(
      context,
      title: 'Add an application',
      fields: (setState) => [
        Field(title, 'Job title', autofocus: true),
        Field(company, 'Employer'),
        Field(url, 'Link', hint: 'https://…'),
        DateField(value: applied, label: 'Applied on', onChanged: (v) => setState(() => applied = v)),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty) return 'Enter the job title.';
        await ref.mutate((s) async {
          final id = newId();
          await s.book.save(
            s.db.jobApplications,
            JobApplicationsCompanion.insert(
              id: id,
              title: title.text.trim(),
              company: Value(company.text.trim()),
              url: Value(url.text.trim()),
              updated: applied,
            ),
            id,
          );
          await s.book.moveTo(id, Stage.applied, date: applied);
        });
        return null;
      },
    );
  }
}

/// Stage colours, as in the list: open stages neutral, outcomes tinted.
Status? stageStatus(Stage s) => switch (s) {
  Stage.interview || Stage.offer || Stage.accepted => Status.good,
  Stage.screening => Status.info,
  Stage.rejected => Status.serious,
  Stage.noReply || Stage.withdrawn => Status.warning,
  _ => null,
};

class ApplicationTile extends StatelessWidget {
  const ApplicationTile(this.a, {super.key});
  final JobApplication a;

  @override
  Widget build(BuildContext context) {
    final now = today();
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final stage = Stage.of(a.stage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tilt(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicationPage(a.id))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      OrgLogo(a.company.ifEmpty(a.title)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              [a.company, a.location].where((s) => s.isNotEmpty).join(' · '),
                              style: t.bodyMedium?.copyWith(color: muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Pill(stage.label, status: stageStatus(stage)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            if (a.applied != null) 'Applied ${niceDate(a.applied!)}',
                            'updated ${relativeDay(a.updated, now)}',
                          ].join(' · '),
                          style: t.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                      if (a.followUp != null && stage.open)
                        Pill(
                          'Follow up ${relativeDay(a.followUp!, now)}',
                          status: followUpStatus(a.followUp!, now),
                          icon: Icons.notifications_none,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything with a date to act on: application follow-ups, contacts to
/// chase, interviews and closing dates of saved jobs.
Future<List<Reminder>> reminders(WidgetRef ref) async {
  final apps = await ref.read(applicationsProvider.future);
  final leads = await ref.read(leadsProvider.future);
  final events = await ref.read(eventsProvider.future);
  final jobs = await ref.read(jobsProvider.future);
  final now = today();
  final byId = {for (final a in apps) a.id: a};
  return [
    for (final a in apps)
      if (a.followUp != null && Stage.of(a.stage).open)
        (
          id: 'followup-${a.id}',
          title: 'Follow up: ${a.title}${a.company.isEmpty ? '' : ' at ${a.company}'}',
          date: a.followUp!,
          details: [a.followUpNote, a.url].where((s) => s.isNotEmpty).join('\n'),
        ),
    for (final e in events)
      if (e.kind == 'interview' && e.at.substring(0, 10).compareTo(now) >= 0 && byId[e.applicationId] != null)
        (
          id: 'interview-${e.id}',
          title: 'Interview: ${byId[e.applicationId]!.title}',
          date: e.at.substring(0, 10),
          details: '${e.at.length > 10 ? 'At ${e.at.substring(11)}. ' : ''}${e.summary}',
        ),
    for (final l in leads)
      if (l.followUp != null && l.status != 'cold')
        (
          id: 'lead-${l.id}',
          title: 'Contact ${l.name}${l.company.isEmpty ? '' : ' (${l.company})'}',
          date: l.followUp!,
          details: l.notes,
        ),
    for (final j in jobs)
      if (j.status == 'saved' && j.closing != null && j.closing!.compareTo(now) >= 0)
        (
          id: 'closing-${j.id}',
          title: 'Closing: ${j.title}${j.company.isEmpty ? '' : ' at ${j.company}'}',
          date: addDays(j.closing!, -2),
          details: 'Closes ${niceDate(j.closing!)}. ${j.url}',
        ),
  ];
}

/// Saves every reminder as one calendar file; each rings at 9 am.
Future<void> exportReminders(BuildContext context, WidgetRef ref) async {
  final list = await reminders(ref);
  if (!context.mounted) return;
  if (list.isEmpty) return showMessage(context, 'Nothing to remind you about yet.');
  final stamp =
      '${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').substring(0, 15)}Z';
  await saveBytes(
    context,
    'udyoga-reminders.ics',
    utf8.encode(icsFile(list, stamp: stamp)),
    mime: 'text/calendar',
  );
}

class ApplicationPage extends ConsumerWidget {
  const ApplicationPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(applicationsProvider);
    final a = all.value?.where((a) => a.id == id).firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.send_outlined, title: 'This application was removed'),
      );
    }
    final now = today();
    final stage = Stage.of(a.stage);
    final events = (ref.watch(eventsProvider).value ?? const <JobEvent>[])
        .where((e) => e.applicationId == id)
        .toList();
    final cvs = ref.watch(resumesProvider).value ?? const <Resume>[];
    final cv = cvs.where((r) => r.id == a.resumeId).firstOrNull;
    final hasAi = ref.watch(advisorProvider).value != null;
    return PageScaffold(
      title: a.title,
      actions: [
        if (a.url.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open the advert',
            onPressed: () => openLink(context, a.url),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () => _delete(context, ref, a),
        ),
      ],
      fab: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _log(context, ref, a),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Log what happened'),
      ),
      children: [
        SectionCard(
          title: [a.company, a.location].where((s) => s.isNotEmpty).join(' · ').ifEmpty('Application'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Choice<Stage>(
                label: 'Stage',
                value: stage,
                options: {for (final s in Stage.values) s: s.label},
                onChanged: (s) => ref.mutate((x) => x.book.moveTo(id, s, date: now)),
              ),
              Text(
                [
                  if (a.applied != null) 'Applied ${niceDate(a.applied!)}',
                  'Last change ${niceDate(a.updated)} (${relativeDay(a.updated, now)})',
                  if (a.reference.isNotEmpty) 'Reference ${a.reference}',
                ].join('\n'),
              ),
              if (a.notes.isNotEmpty) ...[const SizedBox(height: 8), Text(a.notes)],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (a.jobId != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobPage(a.jobId!))),
                      icon: const Icon(Icons.work_outline),
                      label: const Text('The job'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _details(context, ref, a),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (stage.open)
          SectionCard(
            title: 'Follow-up',
            hint: 'apps.followup',
            trailing: TextButton(onPressed: () => _followUp(context, ref, a), child: const Text('Change')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (a.followUp == null)
                  const Text('No follow-up set.')
                else
                  StatusLabel(
                    followUpStatus(a.followUp!, now),
                    '${niceDate(a.followUp!)} (${relativeDay(a.followUp!, now)})',
                  ),
                if (a.followUpNote.isNotEmpty) ...[const SizedBox(height: 6), Text(a.followUpNote)],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => ref.mutate(
                        (s) => s.book.logEvent(id, 'followup', at: nowLocal(), summary: 'Chased up'),
                      ),
                      icon: const Icon(Icons.done),
                      label: const Text('I chased it up'),
                    ),
                    if (a.followUp != null)
                      OutlinedButton.icon(
                        onPressed: () => openUri(
                          context,
                          googleCalendarLink(
                            title: 'Follow up: ${a.title}${a.company.isEmpty ? '' : ' at ${a.company}'}',
                            date: a.followUp!,
                            details: [a.followUpNote, a.url].where((s) => s.isNotEmpty).join('\n'),
                          ),
                        ),
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Add to Google Calendar'),
                      ),
                    if (hasAi)
                      Hint(
                        'apps.chase',
                        child: OutlinedButton.icon(
                          onPressed: () => _draft(context, ref, a, events),
                          icon: const Icon(Icons.edit_note),
                          label: Text(stage == Stage.interview ? 'Draft a thank-you' : 'Draft a chaser'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (stage == Stage.rejected && hasAi)
          SectionCard(
            title: 'Feedback',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Asking for feedback is how you get better at this. Most employers answer a short, gracious request.',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _draft(context, ref, a, events),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Draft a feedback request'),
                  ),
                ),
              ],
            ),
          ),
        SectionCard(
          title: 'CV sent',
          trailing: TextButton(
            onPressed: cvs.isEmpty ? null : () => _pickCv(context, ref, a, cvs),
            child: Text(cv == null ? 'Choose' : 'Change'),
          ),
          child: cv == null
              ? Text(
                  cvs.isEmpty
                      ? 'Tailor a CV from the job page to keep it with the application.'
                      : 'Not recorded.',
                )
              : ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(cv.name),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePage(cv.id))),
                ),
        ),
        SectionCard(
          title: 'Timeline',
          child: events.isEmpty
              ? const Text('Nothing logged yet.')
              : Column(
                  children: [
                    for (final e in events)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_eventIcons[e.kind] ?? Icons.circle_outlined),
                        title: Text(e.summary.isEmpty ? eventKinds[e.kind]?.$1 ?? e.kind : e.summary),
                        subtitle: Text('${eventKinds[e.kind]?.$1 ?? e.kind} · ${niceDateTime(e.at)}'),
                        onLongPress: () => _removeEvent(context, ref, e),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref, JobApplication a) {
    var kind = 'reply';
    var date = today();
    final time = TextEditingController(text: DateTime.now().toIso8601String().substring(11, 16));
    final summary = TextEditingController();
    return showFormDialog(
      context,
      title: 'Log what happened',
      fields: (setState) => [
        Choice<String>(
          label: 'What',
          value: kind,
          options: {for (final e in eventKinds.entries) e.key: e.value.$1},
          onChanged: (v) => setState(() => kind = v),
        ),
        DateField(
          value: date,
          label: kind == 'interview' ? 'Interview date' : 'Date',
          onChanged: (v) => setState(() => date = v),
        ),
        const SizedBox(height: 12),
        Field(time, 'Time', hint: '14:30'),
        Field(
          summary,
          'Details',
          lines: 2,
          hint: kind == 'interview' ? 'Panel interview, 45 minutes, Teams' : 'What they said',
        ),
      ],
      onSave: () async {
        final t = time.text.trim();
        if (t.isNotEmpty && !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t)) return 'Time as 14:30';
        final at = t.isEmpty ? '${date}T09:00' : '${date}T${t.padLeft(5, '0')}';
        await ref.mutate((s) => s.book.logEvent(a.id, kind, at: at, summary: summary.text.trim()));
        return null;
      },
    );
  }

  Future<void> _followUp(BuildContext context, WidgetRef ref, JobApplication a) {
    var on = true;
    var date = a.followUp ?? addDays(today(), 7);
    final note = TextEditingController(text: a.followUpNote);
    return showFormDialog(
      context,
      title: 'Follow-up',
      fields: (setState) => [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me to follow up'),
          value: on,
          onChanged: (v) => setState(() => on = v),
        ),
        if (on) ...[
          DateField(value: date, label: 'Follow up on', onChanged: (v) => setState(() => date = v)),
          const SizedBox(height: 12),
          Field(note, 'What to ask', lines: 2),
        ],
      ],
      onSave: () async {
        await ref.mutate((s) => s.book.setFollowUp(a.id, on ? date : null, note: on ? note.text.trim() : ''));
        return null;
      },
    );
  }

  Future<void> _details(BuildContext context, WidgetRef ref, JobApplication a) {
    final title = TextEditingController(text: a.title);
    final company = TextEditingController(text: a.company);
    final location = TextEditingController(text: a.location);
    final url = TextEditingController(text: a.url);
    final reference = TextEditingController(text: a.reference);
    final notes = TextEditingController(text: a.notes);
    return showFormDialog(
      context,
      title: 'Application',
      fields: (_) => [
        Field(title, 'Job title'),
        Field(company, 'Employer'),
        Field(location, 'Location'),
        Field(url, 'Link'),
        Field(reference, 'Reference', hint: 'Job or candidate reference'),
        Field(notes, 'Notes', lines: 3),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty) return 'Enter the job title.';
        await ref.mutate(
          (s) => s.book.save(
            s.db.jobApplications,
            a.copyWith(
              title: title.text.trim(),
              company: company.text.trim(),
              location: location.text.trim(),
              url: url.text.trim(),
              reference: reference.text.trim(),
              notes: notes.text.trim(),
            ),
            a.id,
          ),
        );
        return null;
      },
    );
  }

  Future<void> _pickCv(BuildContext context, WidgetRef ref, JobApplication a, List<Resume> cvs) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('CV sent'),
        children: [
          for (final r in cvs)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, r.id), child: Text(r.name)),
        ],
      ),
    );
    if (picked == null) return;
    await ref.mutate((s) => s.book.save(s.db.jobApplications, a.copyWith(resumeId: Value(picked)), a.id));
  }

  Future<void> _draft(BuildContext context, WidgetRef ref, JobApplication a, List<JobEvent> events) async {
    final stage = Stage.of(a.stage);
    final purpose = switch (stage) {
      Stage.rejected =>
        'a short, gracious request for feedback on why the application was unsuccessful, '
            'and interest in future roles',
      Stage.interview =>
        'a thank-you to the interview panel that restates fit in one line and asks about timescales',
      Stage.offer => 'a reply to the job offer that thanks them and asks the open questions',
      _ => 'a polite follow-up asking for an update on the application and the timetable',
    };
    final p = await ref.read(profileProvider.future);
    if (!context.mounted) return;
    final d = await runAi(
      context,
      title: 'Drafting',
      task: (_) async => (await requireAdvisor(ref)).draft(
        p,
        purpose: purpose,
        context: [
          'Job: ${a.title}${a.company.isEmpty ? '' : ' at ${a.company}'}',
          if (a.reference.isNotEmpty) 'Reference: ${a.reference}',
          if (a.applied != null) 'Applied: ${a.applied}',
          'Stage: ${stage.label}',
          for (final e in events.take(8)) '${e.at}: ${eventKinds[e.kind]?.$1 ?? e.kind}: ${e.summary}',
        ].join('\n'),
      ),
    );
    if (d == null || !context.mounted) return;
    await showDraft(context, d.subject, d.message);
  }

  Future<void> _removeEvent(BuildContext context, WidgetRef ref, JobEvent e) async {
    if (await confirm(
      context,
      title: 'Remove this entry?',
      message: e.summary,
      action: 'Remove',
      destructive: true,
    )) {
      await ref.mutate((s) => s.book.remove(s.db.jobEvents, e.id));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, JobApplication a) async {
    if (!await confirm(
      context,
      title: 'Delete this application?',
      message: 'It and its timeline are removed from every device.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    await ref.mutate((s) async {
      final events = await (s.db.select(s.db.jobEvents)..where((e) => e.applicationId.equals(a.id))).get();
      for (final e in events) {
        await s.book.remove(s.db.jobEvents, e.id);
      }
      await s.book.remove(s.db.jobApplications, a.id);
    });
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

/// A drafted message to copy into e-mail or LinkedIn.
Future<void> showDraft(BuildContext context, String subject, String message) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Draft'),
    scrollable: true,
    content: SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subject.isNotEmpty) ...[
            Text('Subject: $subject', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
          ],
          SelectableText(message),
          const SizedBox(height: 8),
          const Text('Read it through and make it yours before sending.'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      FilledButton.icon(
        onPressed: () => copyText(
          context,
          subject.isEmpty ? message : 'Subject: $subject\n\n$message',
          what: 'Draft copied.',
        ),
        icon: const Icon(Icons.copy),
        label: const Text('Copy'),
      ),
    ],
  ),
);
