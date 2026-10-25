import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/ai.dart';
import '../domain/countries.dart';
import '../domain/feeds.dart';
import '../domain/json.dart';
import '../domain/pipeline.dart';
import '../domain/profile.dart';
import 'common.dart';
import 'job_page.dart';
import 'look.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  var status = 'new';
  var byFit = true;
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refresh = ref.watch(refreshProvider);
    final hasAi = ref.watch(advisorProvider).value != null;
    return PageScaffold(
      title: 'Jobs',
      banner: 'page.jobs',
      actions: [
        HintIconButton(
          'jobs.portals',
          icon: Icons.travel_explore,
          label: 'Search job sites',
          onPressed: () => showPortals(context, ref),
        ),
        HintIconButton(
          'jobs.ai',
          icon: Icons.auto_awesome,
          label: 'AI job search',
          onPressed: refresh.running ? null : () => _run(ai: true, hasAi: hasAi),
        ),
        HintIconButton(
          'jobs.refresh',
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: refresh.running ? null : () => _run(),
        ),
      ],
      fab: Hint(
        'jobs.add',
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => addJob(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add job'),
        ),
      ),
      children: [
        if (refresh.running)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(refresh.status)),
              ],
            ),
          )
        else if (refresh.last != null || refresh.status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StatusLabel(
              refresh.last?.problems.isEmpty ?? false ? Status.good : Status.warning,
              refresh.last?.summary ?? refresh.status,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final e in jobStatuses.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: status == e.key,
                onSelected: (_) => setState(() => status = e.key),
              ),
            const SizedBox(width: 8),
            Hint(
              'jobs.fit',
              child: FilterChip(
                label: const Text('Best fit first'),
                selected: byFit,
                onSelected: (v) => setState(() => byFit = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Filter by title, employer or place',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AsyncView(
          ref.watch(jobsProvider),
          builder: (all) {
            final q = search.text.trim().toLowerCase();
            final jobs = all
                .where((j) => j.status == status)
                .where((j) => q.isEmpty || '${j.title} ${j.company} ${j.location}'.toLowerCase().contains(q))
                .toList();
            if (byFit) jobs.sort((a, b) => (b.fit ?? -1).compareTo(a.fit ?? -1));
            if (jobs.isEmpty) {
              return EmptyState(
                icon: Icons.work_outline,
                title: status == 'new' ? 'No new jobs' : 'Nothing here',
                message: status == 'new'
                    ? 'Refresh to check the job sites for your target roles, run the AI search, or add a job '
                          'you found yourself.'
                    : null,
              );
            }
            return Column(children: [for (final j in jobs) JobTile(j)]);
          },
        ),
      ],
    );
  }

  Future<void> _run({bool ai = false, bool hasAi = true}) async {
    if (ai && !hasAi) {
      return showMessage(context, needsAiKey);
    }
    try {
      final r = await ref.read(refreshProvider.notifier).run(force: true, ai: ai);
      if (r != null && mounted) showMessage(context, r.summary);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

class JobTile extends StatelessWidget {
  const JobTile(this.job, {super.key, this.list = 'jobs'});
  final Job job;

  /// Which list the tile is in; it keeps the logo's hero tag unique when
  /// the same job shows on two pages at once.
  final String list;

  @override
  Widget build(BuildContext context) {
    final j = job;
    final tag = 'logo-$list-${j.id}';
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final now = today();
    final pay = shortSalary(j);
    final closingSoon =
        j.closing != null && j.closing!.compareTo(addDays(now, 7)) <= 0 && j.closing!.compareTo(now) >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tilt(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobPage(j.id, heroTag: tag))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(tag: tag, child: OrgLogo(j.company.ifEmpty(j.title))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(j.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              [j.company, j.location].where((s) => s.isNotEmpty).join(' · '),
                              style: t.bodyMedium?.copyWith(color: muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (pay.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            pay,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(
                              fontFamily: headingFont,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (j.remote) const Pill('Remote', icon: Icons.public),
                      if (j.country.isNotEmpty) Pill(Country.nameOf(j.country)),
                      Pill('via ${sourceName(j.source)}'),
                      if (j.status == 'applied') const Pill('Applied', status: Status.good, icon: Icons.send),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Found ${relativeDay(j.found, now)}',
                          style: t.bodySmall?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (closingSoon)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pill('Closes ${relativeDay(j.closing!, now)}', status: Status.serious),
                          ),
                        ),
                      Hint('jobs.fit', child: FitBadge(j.fit, ai: j.assessment.isNotEmpty)),
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

/// Pay in a few characters ("£32k–38k"), else the advert's own short wording.
String shortSalary(Job j) {
  String k(int v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 || v >= 100000 ? 0 : 1)}k' : '$v';
  final sym = switch (j.currency.toUpperCase()) {
    'GBP' => '£',
    'EUR' => '€',
    'USD' || 'CAD' || 'AUD' => r'$',
    'INR' => '₹',
    '' => '',
    final c => '$c ',
  };
  if (j.salaryMax != null || j.salaryMin != null) {
    final lo = j.salaryMin ?? j.salaryMax!, hi = j.salaryMax ?? j.salaryMin!;
    return lo == hi ? '$sym${k(lo)}' : '$sym${k(lo)}–${k(hi)}';
  }
  return j.salaryText.length <= 24 ? j.salaryText : '';
}

String sourceName(String source) => switch (source) {
  'adzuna' => 'Adzuna',
  'reed' => 'Reed',
  'remotive' => 'Remotive',
  'jobicy' => 'Jobicy',
  'arbeitnow' => 'Arbeitnow',
  'ai' => 'AI search',
  _ => 'you',
};

/// Searches for the profile's roles on every job site for each target
/// country, opened in the browser.
Future<void> showPortals(BuildContext context, WidgetRef ref) async {
  final p = await ref.read(profileProvider.future);
  if (!context.mounted) return;
  final terms = p.searchTerms;
  if (terms.isEmpty) {
    return showMessage(context, 'Add your current role or target roles to your profile first.');
  }
  var term = terms.first;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Search job sites', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in terms)
                  ChoiceChip(
                    label: Text(t),
                    selected: t == term,
                    onSelected: (_) => setState(() => term = t),
                  ),
              ],
            ),
            for (final c in p.searchCountries.isEmpty ? [''] : p.searchCountries) ...[
              Subhead(c.isEmpty ? 'Anywhere' : Country.nameOf(c)),
              for (final portal in portalsFor(c))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_new, size: 18),
                  title: Text(portal.name),
                  subtitle: portal.note.isEmpty ? null : Text(portal.note),
                  onTap: () => openUri(context, portal.link(term, _place(p, c))),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _place(CandidateProfile p, String country) {
  if (country == p.country && p.targets.locations.isNotEmpty) return p.targets.locations.first;
  return Country.nameOf(country);
}

/// Adds a job from its link or advert text (read by the AI), or typed in.
Future<void> addJob(BuildContext context, WidgetRef ref) async {
  final url = TextEditingController();
  final advert = TextEditingController();
  final title = TextEditingController();
  final company = TextEditingController();
  final location = TextEditingController();
  final hasAi = await ref.read(advisorProvider.future) != null;
  if (!context.mounted) return;
  String? id;
  final ok = await showFormDialog(
    context,
    title: 'Add a job',
    action: 'Add',
    width: 600,
    fields: (_) => [
      Field(url, 'Link to the advert', hint: 'https://…', autofocus: true),
      Field(
        advert,
        'Advert text',
        lines: 4,
        helper: hasAi
            ? 'Paste the advert, or leave it empty and the AI reads the link.'
            : 'Paste the job description, responsibilities and person specification.',
      ),
      if (!hasAi) ...[Field(title, 'Job title'), Field(company, 'Employer'), Field(location, 'Location')],
    ],
    onSave: () async {
      final link = url.text.trim();
      final text = advert.text.trim();
      if (link.isNotEmpty && !(Uri.tryParse(link)?.hasScheme ?? false)) {
        return 'The link starts with https://';
      }
      final p = await ref.read(profileProvider.future);
      Posting posting;
      if (hasAi && (link.isNotEmpty || text.isNotEmpty)) {
        final advisor = await requireAdvisor(ref);
        final a = await advisor.readAdvert(url: link, text: text);
        posting = Posting(
          source: 'manual',
          sourceId: link.isNotEmpty ? link : newId(),
          title: str(a['title']),
          company: str(a['company']),
          location: str(a['location']),
          country: str(a['country']).toUpperCase(),
          remote: a['remote'] == true,
          salaryText: str(a['salaryText']),
          url: link,
          description: str(a['description']).isNotEmpty ? str(a['description']) : text,
          posted: str(a['posted']).length == 10 ? str(a['posted']) : null,
          closing: str(a['closing']).length == 10 ? str(a['closing']) : null,
        );
        if (posting.title.isEmpty) return 'The AI could not read a job advert there. Paste the text instead.';
      } else {
        if (title.text.trim().isEmpty) return 'Enter the job title.';
        posting = Posting(
          source: 'manual',
          sourceId: link.isNotEmpty ? link : newId(),
          title: title.text.trim(),
          company: company.text.trim(),
          location: location.text.trim(),
          country: p.country,
          url: link,
          description: text,
        );
      }
      final added = await ref.mutate((s) => s.book.importPostings([posting], p, today: today()));
      id = added.firstOrNull;
      if (id == null) return 'That job is already on your list.';
      await ref.mutate((s) => s.book.setJobStatus(id!, 'saved'));
      return null;
    },
  );
  if (ok && id != null && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobPage(id!)));
  }
}
