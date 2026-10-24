import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/pipeline.dart';
import '../domain/profile.dart';
import 'applications_page.dart';
import 'common.dart';
import 'contacts_page.dart';
import 'jobs_page.dart';
import 'look.dart';

/// Next steps, from setting up to the day's chasing.
List<({IconData icon, String text})> nextSteps({
  required CandidateProfile profile,
  required bool hasAi,
  required bool assessed,
  required bool mapped,
  required int jobs,
  required int applications,
  required int practice,
  String? update,
}) => [
  if (update != null)
    (icon: Icons.system_update_outlined, text: 'Udyoga $update is out: update it in Settings.'),
  if (!hasAi)
    (
      icon: Icons.key_outlined,
      text: 'Add a free Gemini key (or a Claude key) in Settings to turn on the AI features.',
    ),
  if (profile.isEmpty) (icon: Icons.upload_file, text: 'Import your CV on the Profile page.'),
  if (!profile.isEmpty && profile.searchCountries.isEmpty)
    (icon: Icons.public, text: 'Choose the countries to search in on the Profile page.'),
  if (!profile.isEmpty && hasAi && !assessed)
    (icon: Icons.insights, text: 'Run the assessment on the Career page to see where you stand.'),
  if (!profile.isEmpty && hasAi && !mapped)
    (icon: Icons.account_tree_outlined, text: 'Build your career map on the Career page.'),
  if (!profile.isEmpty && jobs == 0) (icon: Icons.refresh, text: 'Refresh the Jobs page to find openings.'),
  if (jobs > 0 && applications == 0)
    (icon: Icons.send_outlined, text: 'Pick your best match, tailor your CV to it and apply.'),
  if (applications > 0 && practice == 0 && hasAi)
    (icon: Icons.record_voice_over_outlined, text: 'Practise an interview before you need one.'),
];

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today();
    final profile = ref.watch(profileProvider).value ?? const CandidateProfile();
    final hasAi = ref.watch(advisorProvider).value != null;
    final jobs = ref.watch(jobsProvider).value ?? const <Job>[];
    final apps = ref.watch(applicationsProvider).value ?? const <JobApplication>[];
    final leads = ref.watch(leadsProvider).value ?? const <Lead>[];
    final events = ref.watch(eventsProvider).value ?? const <JobEvent>[];
    final practice = ref.watch(practiceProvider).value ?? const <PracticeSession>[];
    final assessed = ref.watch(latestReportProvider('assessment')).value != null;
    final mapped = ref.watch(latestReportProvider('career_map')).value != null;
    final refresh = ref.watch(refreshProvider);

    final open = apps.where((a) => Stage.of(a.stage).open).toList();
    final dueApps = open.where((a) => a.followUp != null && a.followUp!.compareTo(now) <= 0).toList();
    final dueLeads = leads
        .where((l) => l.followUp != null && l.followUp!.compareTo(now) <= 0 && l.status != 'cold')
        .toList();
    final byId = {for (final a in apps) a.id: a};
    final interviews =
        events
            .where(
              (e) =>
                  e.kind == 'interview' &&
                  e.at.substring(0, 10).compareTo(now) >= 0 &&
                  byId.containsKey(e.applicationId),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final fresh = jobs.where((j) => j.status == 'new').toList()
      ..sort((a, b) => (b.fit ?? -1).compareTo(a.fit ?? -1));
    final closing = jobs
        .where((j) => j.status == 'saved' && j.closing != null && j.closing!.compareTo(now) >= 0)
        .where((j) => j.closing!.compareTo(addDays(now, 7)) <= 0)
        .toList();
    final steps = nextSteps(
      profile: profile,
      hasAi: hasAi,
      assessed: assessed,
      mapped: mapped,
      jobs: jobs.length,
      applications: apps.length,
      practice: practice.length,
      update: ref.watch(updateProvider).value?.version,
    );
    final sent = apps.where((a) => a.applied != null).length;
    final heard = apps
        .where(
          (a) => a.applied != null && const ['screening', 'interview', 'offer', 'accepted'].contains(a.stage),
        )
        .length;

    return PageScaffold(
      title: 'Today',
      banner: 'page.today',
      actions: [
        HintIconButton(
          'apps.calendar',
          icon: Icons.event_available_outlined,
          label: 'Reminders to calendar',
          onPressed: () => exportReminders(context, ref),
        ),
      ],
      children: [
        _Greeting(profile),
        TiltGrid(
          minWidth: 160,
          children: [
            KpiTile(
              label: 'Follow-ups due',
              value: '${dueApps.length + dueLeads.length}',
              icon: Icons.notifications_active_outlined,
              status: dueApps.isEmpty && dueLeads.isEmpty
                  ? null
                  : (color: Status.warning.color, icon: Status.warning.icon),
              caption: dueApps.isEmpty && dueLeads.isEmpty ? 'All caught up' : 'Chase them today',
            ),
            KpiTile(label: 'In progress', value: '${open.length}', icon: Icons.send_outlined),
            KpiTile(
              label: 'Interviews',
              value: '${interviews.length}',
              icon: Icons.record_voice_over_outlined,
            ),
            KpiTile(label: 'New matches', value: '${fresh.length}', icon: Icons.work_outline),
            KpiTile(
              label: 'Response rate',
              value: sent == 0 ? '–' : '${(heard * 100 / sent).round()}%',
              icon: Icons.mark_email_unread_outlined,
              caption: sent == 0 ? 'No applications sent yet' : '$heard of $sent heard back',
            ),
          ],
        ),
        if (refresh.running)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(refresh.status)),
              ],
            ),
          ),
        if (steps.isNotEmpty)
          SectionCard(
            title: 'Next steps',
            child: Column(
              children: [
                for (final s in steps)
                  ListTile(contentPadding: EdgeInsets.zero, leading: Icon(s.icon), title: Text(s.text)),
              ],
            ),
          ),
        if (interviews.isNotEmpty)
          SectionCard(
            title: 'Upcoming interviews',
            child: Column(
              children: [
                for (final e in interviews)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(byId[e.applicationId]!.title),
                    subtitle: Text(
                      '${niceDateTime(e.at)} (${relativeDay(e.at.substring(0, 10), now)}) ${e.summary}',
                    ),
                    onTap: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => ApplicationPage(e.applicationId))),
                  ),
              ],
            ),
          ),
        if (dueApps.isNotEmpty || dueLeads.isNotEmpty)
          SectionCard(
            title: 'Follow up today',
            child: Column(
              children: [for (final a in dueApps) ApplicationTile(a), for (final l in dueLeads) LeadTile(l)],
            ),
          ),
        if (closing.isNotEmpty)
          SectionCard(
            title: 'Closing this week',
            child: Column(children: [for (final j in closing) JobTile(j, list: 'closing')]),
          ),
        SectionCard(
          title: 'Best new matches',
          child: fresh.isEmpty
              ? const Text('No new matches. Jobs refresh every few hours while Udyoga is open.')
              : Column(children: [for (final j in fresh.take(5)) JobTile(j, list: 'fresh')]),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting(this.p);
  final CandidateProfile p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.name.isNotEmpty) ...[
            Row(
              children: [
                OrgLogo(p.name, size: 46),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back', style: t.bodyMedium?.copyWith(color: muted)),
                    Text(p.name, style: t.titleMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const Headline(["Let's get ", 'you hired', ' for the job you ', 'deserve', '.']),
          if (p.currentRole.isNotEmpty || p.targets.roles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.targets.roles.isNotEmpty ? 'Aiming for ${p.targets.roles.take(3).join(', ')}' : p.currentRole,
              style: t.bodyLarge?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
