import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/countries.dart';
import '../domain/insights.dart';
import '../domain/json.dart';
import '../domain/n8n.dart';
import '../domain/pipeline.dart';
import '../domain/resume.dart';
import 'applications_page.dart';
import 'common.dart';
import 'contacts_page.dart';
import 'interview_page.dart';
import 'jobs_page.dart';
import 'look.dart';
import 'resume_page.dart';

const _verdicts = {
  'strong': ('Strong fit', Status.good),
  'good': ('Good fit', Status.good),
  'stretch': ('A stretch', Status.warning),
  'long_shot': ('Long shot', Status.serious),
  'unsuitable': ('Not suitable', Status.critical),
};

const _severity = {
  'blocker': ('Blocker', Status.critical),
  'major': ('Major gap', Status.serious),
  'minor': ('Minor gap', Status.warning),
};

class JobPage extends ConsumerWidget {
  const JobPage(this.id, {super.key, this.heroTag});
  final String id;

  /// The tag of the logo the page was opened from, to fly it in.
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(jobsProvider);
    final j = all.value?.where((j) => j.id == id).firstOrNull;
    if (j == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.work_outline, title: 'This job was removed'),
      );
    }
    final hasAi = ref.watch(advisorProvider).value != null;
    final n8n = ref.watch(n8nLinkProvider).value ?? const N8nLink();
    final fit = j.assessment.isEmpty ? null : FitAssessment(decodeObject(j.assessment));
    final cvs = (ref.watch(resumesProvider).value ?? const <Resume>[]).where((r) => r.jobId == id).toList();
    final leads = (ref.watch(leadsProvider).value ?? const <Lead>[]).where((l) => l.jobId == id).toList();
    final application = (ref.watch(applicationsProvider).value ?? const <JobApplication>[])
        .where((a) => a.jobId == id)
        .firstOrNull;
    return PageScaffold(
      title: j.title,
      actions: [
        if (j.url.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open the advert',
            onPressed: () => openLink(context, j.url),
          ),
        PopupMenuButton<String>(
          onSelected: (v) => switch (v) {
            'notes' => _editNotes(context, ref, j),
            'delete' => _delete(context, ref, j),
            _ => null,
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'notes', child: Text('Notes')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
      fabLocation: FloatingActionButtonLocation.centerFloat,
      fab: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 48).clamp(200, 420).toDouble(),
        child: application != null
            ? FloatingActionButton.extended(
                heroTag: null,
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ApplicationPage(application.id))),
                icon: const Icon(Icons.send),
                label: Text('Application: ${Stage.of(application.stage).label}'),
              )
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _apply(context, ref, j),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Apply for this job'),
              ),
      ),
      children: [
        _Header(j, fit: fit, heroTag: heroTag),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (j.status == 'new')
              OutlinedButton.icon(
                onPressed: () => ref.mutate((s) => s.book.setJobStatus(id, 'saved')),
                icon: const Icon(Icons.bookmark_outline),
                label: const Text('Save'),
              ),
            if (j.status == 'new' || j.status == 'saved')
              OutlinedButton.icon(
                onPressed: () => ref.mutate((s) => s.book.setJobStatus(id, 'dismissed')),
                icon: const Icon(Icons.thumb_down_outlined),
                label: const Text('Not for me'),
              ),
            if (j.status == 'dismissed')
              OutlinedButton.icon(
                onPressed: () => ref.mutate((s) => s.book.setJobStatus(id, 'saved')),
                icon: const Icon(Icons.undo),
                label: const Text('Restore'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (j.notes.isNotEmpty) SectionCard(title: 'Notes', child: SelectableText(j.notes)),
        SectionCard(
          title: 'Fit assessment',
          hint: 'job.assess',
          trailing: hasAi
              ? TextButton(
                  onPressed: () => _assess(context, ref, j),
                  child: Text(fit == null ? 'Assess' : 'Redo'),
                )
              : null,
          child: !hasAi
              ? const NeedsKey(what: 'The fit assessment')
              : fit == null
              ? const Text(
                  'The AI reads the advert, researches the employer and the pay, and tells you honestly how '
                  'you match: what you meet, the gaps, your real chances and how to apply.',
                )
              : FitView(fit),
        ),
        SectionCard(
          title: 'Tailored CV',
          hint: 'job.tailor',
          trailing: hasAi
              ? TextButton(onPressed: () => _tailor(context, ref, j, fit), child: const Text('Tailor'))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasAi) const NeedsKey(what: 'Tailoring'),
              if (cvs.isEmpty)
                const Text(
                  'A CV and cover letter for this job, worded to its description and responsibilities, from '
                  'your real experience only.',
                ),
              for (final r in cvs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(r.name),
                  subtitle: Text('Made ${niceDate(r.created)}'),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePage(r.id))),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Contacts',
          hint: 'job.leads',
          trailing: hasAi
              ? TextButton(onPressed: () => _findLeads(context, ref, j), child: const Text('Find'))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in leads) LeadTile(l),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (n8n.isSet)
                    Hint(
                      'job.n8n',
                      child: OutlinedButton.icon(
                        onPressed: () => _findLeadsN8n(context, ref, j, n8n),
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('Ask my n8n workflow'),
                      ),
                    ),
                  if (j.company.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => openUri(context, linkedInPeople('recruiter ${j.company}')),
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Recruiters on LinkedIn'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openUri(context, linkedInPeople('${j.title} ${j.company}')),
                      icon: const Icon(Icons.groups_outlined),
                      label: const Text('People in this team'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Interview practice',
          trailing: hasAi
              ? TextButton(
                  onPressed: () => startPractice(context, ref, role: j.title, job: j),
                  child: const Text('Practise'),
                )
              : null,
          child: Text(
            hasAi
                ? 'Questions this employer is likely to ask for this role, with each answer scored.'
                : 'Add a free Gemini key or a Claude API key in Settings to practise for this interview.',
          ),
        ),
        if (j.description.isNotEmpty) SectionCard(title: 'The advert', child: SelectableText(j.description)),
      ],
    );
  }

  Future<void> _assess(BuildContext context, WidgetRef ref, Job j) async {
    final p = await ref.read(profileProvider.future);
    if (!context.mounted) return;
    final r = await runAi(
      context,
      title: 'Assessing your fit',
      task: (progress) async => (await requireAdvisor(ref)).assessJob(p, j, onProgress: progress),
    );
    if (r == null) return;
    await ref.mutate((s) => s.book.saveAssessment(j.id, FitAssessment(r.withSources)));
  }

  Future<void> _tailor(BuildContext context, WidgetRef ref, Job j, FitAssessment? fit) async {
    final p = await ref.read(profileProvider.future);
    if (!context.mounted) return;
    if (p.isEmpty) return showMessage(context, 'Import your CV on the Profile page first.');
    final r = await runAi(
      context,
      title: 'Tailoring your CV',
      task: (progress) async => (await requireAdvisor(ref)).tailor(p, j, fit: fit, onProgress: progress),
    );
    if (r == null || !context.mounted) return;
    final id = await ref.mutate(
      (s) => s.book.saveResume(
        name: 'CV for ${j.title}${j.company.isEmpty ? '' : ', ${j.company}'}',
        doc: ResumeDoc.fromJson(obj(r.data['resume'])),
        jobId: j.id,
        tailoring: obj(r.data['notes']),
        today: today(),
      ),
    );
    if (context.mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePage(id)));
  }

  Future<void> _findLeadsN8n(BuildContext context, WidgetRef ref, Job j, N8nLink link) async {
    final p = await ref.read(profileProvider.future);
    if (!context.mounted) return;
    final leads = await runAi(
      context,
      title: 'Asking your n8n workflow',
      task: (progress) {
        progress('Waiting for n8n…');
        return n8nLeads(ref.read(httpClientProvider), link, p, j);
      },
    );
    if (leads == null) return;
    final n = await ref.mutate((s) => s.book.importLeads(leads, jobId: j.id, today: today()));
    if (context.mounted) showMessage(context, n == 0 ? 'No new contacts found.' : 'Added $n contacts.');
  }

  Future<void> _findLeads(BuildContext context, WidgetRef ref, Job j) async {
    final p = await ref.read(profileProvider.future);
    if (!context.mounted) return;
    final r = await runAi(
      context,
      title: 'Finding contacts',
      task: (progress) async => (await requireAdvisor(ref)).findLeads(p, job: j, onProgress: progress),
    );
    if (r == null) return;
    final n = await ref.mutate(
      (s) => s.book.importLeads(
        objs(r.data['leads']).map(LeadSuggestion.new).toList(),
        jobId: j.id,
        today: today(),
      ),
    );
    if (context.mounted) showMessage(context, n == 0 ? 'No new contacts found.' : 'Added $n contacts.');
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, Job j) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Apply'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('I have sent my application'),
              subtitle: Text('Starts the follow-up clock'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: const ListTile(
              leading: Icon(Icons.edit_note),
              title: Text('I am preparing it'),
              subtitle: Text('Tracks it as Preparing'),
            ),
          ),
        ],
      ),
    );
    if (sent == null || !context.mounted) return;
    final appId = await ref.mutate((s) => s.book.applyFor(j, today: today(), sent: sent));
    if (j.url.isNotEmpty && !sent && context.mounted) await openLink(context, j.url);
    if (context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicationPage(appId)));
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref, Job j) {
    final notes = TextEditingController(text: j.notes);
    return showFormDialog(
      context,
      title: 'Notes',
      fields: (_) => [Field(notes, 'Notes', lines: 4, autofocus: true)],
      onSave: () async {
        await ref.mutate((s) => s.book.save(s.db.jobListings, j.copyWith(notes: notes.text.trim()), j.id));
        return null;
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Job j) async {
    if (!await confirm(
      context,
      title: 'Delete this job?',
      message:
          'It is removed from every device. A refresh may find it again; "Not for me" hides it for good.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    await ref.mutate((s) => s.book.remove(s.db.jobListings, j.id));
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

/// The job at a glance: the employer's mark (carried over from the list),
/// the title and the facts as pills.
class _Header extends StatelessWidget {
  const _Header(this.j, {required this.fit, this.heroTag});
  final Job j;
  final FitAssessment? fit;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = today();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(tag: heroTag ?? 'logo-${j.id}', child: OrgLogo(j.company.ifEmpty(j.title), size: 64)),
              const Spacer(),
              FitBadge(j.fit, ai: fit != null),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(j.title, style: t.headlineMedium),
          const SizedBox(height: 4),
          Text(
            [j.company, j.location].where((s) => s.isNotEmpty).join(' · '),
            style: t.titleMedium?.copyWith(color: muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (j.salaryText.isNotEmpty || shortSalary(j).isNotEmpty)
                Pill(j.salaryText.ifEmpty(shortSalary(j)), icon: Icons.payments_outlined),
              if (j.remote) const Pill('Remote', icon: Icons.public),
              if (j.country.isNotEmpty) Pill(Country.nameOf(j.country), icon: Icons.place_outlined),
              if (j.posted != null) Pill('Posted ${niceDate(j.posted!)}'),
              if (j.closing != null)
                Pill(
                  'Closes ${niceDate(j.closing!)} (${relativeDay(j.closing!, now)})',
                  status: j.closing!.compareTo(addDays(now, 7)) <= 0 ? Status.serious : null,
                  icon: Icons.event_outlined,
                ),
              Pill('Found ${niceDate(j.found)} via ${sourceName(j.source)}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A fit assessment, laid out to read top-down.
class FitView extends StatelessWidget {
  const FitView(this.fit, {super.key});
  final FitAssessment fit;

  @override
  Widget build(BuildContext context) {
    final v = _verdicts[fit.verdict] ?? ('Assessed', Status.info);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusLabel(v.$2, '${v.$1}: ${fit.fit}%'),
        const SizedBox(height: 8),
        SelectableText(fit.summary),
        if (fit.odds.isNotEmpty) ...[const Subhead('Your chances'), SelectableText(fit.odds)],
        if (fit.matched.isNotEmpty) ...[
          const Subhead('What you meet'),
          Bullets(
            [for (final m in fit.matched) '${str(m['requirement'])}: ${str(m['evidence'])}'],
            icon: Icons.check,
            color: Status.good.color,
          ),
        ],
        if (fit.gaps.isNotEmpty) ...[
          const Subhead('Gaps'),
          for (final g in fit.gaps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusLabel(
                    (_severity[str(g['severity'])] ?? ('Gap', Status.warning)).$2,
                    '${(_severity[str(g['severity'])] ?? ('Gap', Status.warning)).$1}: ${str(g['requirement'])}',
                  ),
                  if (str(g['mitigation']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 2),
                      child: SelectableText(str(g['mitigation'])),
                    ),
                ],
              ),
            ),
        ],
        if (fit.redFlags.isNotEmpty) ...[
          const Subhead('Red flags'),
          Bullets(fit.redFlags, icon: Icons.flag_outlined, color: Status.serious.color),
        ],
        if (fit.responsibilities.isNotEmpty) ...[
          const Subhead('Key responsibilities'),
          Bullets(fit.responsibilities),
        ],
        if (fit.salary.isNotEmpty) ...[const Subhead('Pay'), SelectableText(fit.salary)],
        if (fit.employer.isNotEmpty) ...[const Subhead('The employer'), SelectableText(fit.employer)],
        if (fit.keywords.isNotEmpty) ...[
          const Subhead('Keywords your CV needs'),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in fit.keywords) Chip(label: Text(k))]),
        ],
        if (fit.tips.isNotEmpty) ...[
          const Subhead('How to apply'),
          Bullets(fit.tips, icon: Icons.lightbulb_outline),
        ],
        if (fit.interviewFocus.isNotEmpty) ...[
          const Subhead('What the interview will probe'),
          Bullets(fit.interviewFocus, icon: Icons.record_voice_over_outlined),
        ],
        SourcesList(SourcesList.of(fit.j['sources'])),
      ],
    );
  }
}
