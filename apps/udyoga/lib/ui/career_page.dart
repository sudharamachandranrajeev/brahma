import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/claude.dart';
import '../domain/countries.dart';
import '../domain/insights.dart';
import '../domain/json.dart';
import '../domain/profile.dart';
import 'common.dart';

const _directions = {
  'vertical': ('Up', Icons.north),
  'lateral': ('Sideways', Icons.east),
  'specialist': ('Specialist', Icons.center_focus_strong_outlined),
  'management': ('Management', Icons.groups_outlined),
  'pivot': ('Change of field', Icons.alt_route),
  'independent': ('Independent', Icons.storefront_outlined),
};

const _realism = {
  'likely': ('Likely', Status.good),
  'possible': ('Possible', Status.info),
  'ambitious': ('Ambitious', Status.warning),
};

const _exposure = {
  'low': ('Low AI exposure', Status.good),
  'medium': ('Medium AI exposure', Status.warning),
  'high': ('High AI exposure', Status.serious),
};

class CareerPage extends ConsumerWidget {
  const CareerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAi = ref.watch(advisorProvider).value != null;
    final assessment = ref.watch(latestReportProvider('assessment')).value;
    final map = ref.watch(latestReportProvider('career_map')).value;
    final reports = ref.watch(reportsProvider).value ?? const <Report>[];
    final p = ref.watch(profileProvider).value ?? const CandidateProfile();
    return PageScaffold(
      title: 'Career',
      banner: 'page.career',
      children: [
        if (!hasAi) const NeedsKey(what: 'The career map and assessment'),
        if (p.isEmpty) const StatusLabel(Status.info, 'Import your CV on the Profile page first.'),
        SectionCard(
          title: 'Career map',
          hint: 'career.map',
          trailing: hasAi && !p.isEmpty
              ? TextButton(
                  onPressed: () => _map(context, ref, p),
                  child: Text(map == null ? 'Build' : 'Refresh'),
                )
              : null,
          child: map == null
              ? const Text(
                  'Every realistic way on from your current role (up, sideways, specialist, management, a change '
                  'of field or going independent) with the steps, timeframes, pay, requirements, the odds and how '
                  'AI is changing each path. Refreshed monthly when the AI routine is on.',
                )
              : _MapView(
                  CareerMap(decodeObject(map.content)),
                  created: map.created,
                  sources: SourcesList.fromJson(map.sources),
                  versions: reports.where((r) => r.kind == 'career_map').length,
                ),
        ),
        SectionCard(
          title: 'Where you stand',
          hint: 'career.assess',
          trailing: hasAi && !p.isEmpty
              ? TextButton(
                  onPressed: () => _assess(context, ref, p),
                  child: Text(assessment == null ? 'Assess' : 'Redo'),
                )
              : null,
          child: assessment == null
              ? const Text(
                  'A candid assessment of your CV against today\'s market: your level and competitiveness, '
                  'strengths and weaknesses, the toughest obstacles and how to prepare for them, how AI affects '
                  'your field, the roles to target, other countries worth considering, and what to learn.',
                )
              : AssessmentView(
                  Assessment(decodeObject(assessment.content)),
                  created: assessment.created,
                  sources: SourcesList.fromJson(assessment.sources),
                ),
        ),
      ],
    );
  }

  Future<void> _assess(BuildContext context, WidgetRef ref, CandidateProfile p) async {
    final r = await runAi(
      context,
      title: 'Assessing your profile',
      task: (progress) async => (await requireAdvisor(ref)).assess(p, onProgress: progress),
    );
    if (r == null) return;
    await ref.mutate((s) => s.book.saveReport('assessment', r.data, r.sources, at: today()));
  }

  Future<void> _map(BuildContext context, WidgetRef ref, CandidateProfile p) async {
    final a = await ref.read(latestReportProvider('assessment').future);
    if (!context.mounted) return;
    final r = await runAi(
      context,
      title: 'Mapping your career paths',
      task: (progress) async => (await requireAdvisor(ref)).careerMap(
        p,
        assessment: a == null ? null : Assessment(decodeObject(a.content)),
        onProgress: progress,
      ),
    );
    if (r == null) return;
    await ref.mutate((s) => s.book.saveReport('career_map', r.data, r.sources, at: today()));
  }
}

/// The map as a tree: the current role at the root, a branch per path and
/// its roles in order down each branch.
class _MapView extends ConsumerWidget {
  const _MapView(this.map, {required this.created, required this.sources, required this.versions});
  final CareerMap map;
  final String created;
  final List<Source> sources;
  final int versions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final paths = map.paths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Updated ${niceDate(created)}${versions > 1 ? ' · $versions versions kept' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Center(
          child: _Node(
            title: map.current.ifEmpty('You now'),
            subtitle: 'Now',
            color: scheme.primaryContainer,
            onColor: scheme.onPrimaryContainer,
          ),
        ),
        _Line(color: scheme.outlineVariant),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final path in paths)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 220,
                    child: _Branch(path, recommended: path.name == map.recommended),
                  ),
                ),
            ],
          ),
        ),
        if (map.recommended.isNotEmpty) ...[
          const Subhead('Recommended'),
          SelectableText('${map.recommended}. ${map.rationale}'),
        ],
        if (map.currentSummary.isNotEmpty) ...[
          const Subhead('Your current role'),
          SelectableText(map.currentSummary),
        ],
        if (map.trends.isNotEmpty) ...[
          const Subhead('Hiring trends'),
          Bullets(map.trends, icon: Icons.trending_up),
        ],
        SourcesList(sources),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Center(child: Container(width: 2, height: 16, color: color));
}

class _Node extends StatelessWidget {
  const _Node({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onColor,
    this.onTap,
  });
  final String title, subtitle;
  final Color color, onColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onColor),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Branch extends ConsumerWidget {
  const _Branch(this.path, {required this.recommended});
  final CareerPath path;
  final bool recommended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dir = _directions[path.direction] ?? ('Path', Icons.route);
    final real = _realism[path.realism] ?? ('', Status.info);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: recommended ? scheme.primary : scheme.outlineVariant,
              width: recommended ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _details(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(dir.$2, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(dir.$1, style: Theme.of(context).textTheme.labelMedium)),
                      if (recommended)
                        Icon(Icons.star, size: 18, color: scheme.primary, semanticLabel: 'Recommended'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(path.name, style: Theme.of(context).textTheme.titleSmall),
                  if (real.$1.isNotEmpty) StatusLabel(real.$2, real.$1),
                  if (path.ai.exposure.isNotEmpty)
                    StatusLabel(
                      (_exposure[path.ai.exposure] ?? ('', Status.info)).$2,
                      (_exposure[path.ai.exposure] ?? ('AI: ${path.ai.exposure}', Status.info)).$1,
                    ),
                ],
              ),
            ),
          ),
        ),
        for (final step in path.steps) ...[
          _Line(color: scheme.outlineVariant),
          _Node(
            title: step.role,
            subtitle: [step.timeframe, if (step.likelihood > 0) '${step.likelihood}% likely'].join(' · '),
            color: scheme.surfaceContainerHighest,
            onColor: scheme.onSurface,
            onTap: () => _details(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _details(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(path.name, style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(path.summary),
          for (final (i, step) in path.steps.indexed) ...[
            Subhead('${i + 1}. ${step.role}'),
            Text(
              [
                step.timeframe,
                step.salary,
                if (step.likelihood > 0) '${step.likelihood}% likely on this path',
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
            if (step.requirements.isNotEmpty) Bullets(step.requirements),
            if (step.certifications.isNotEmpty) Bullets(step.certifications, icon: Icons.verified_outlined),
            if (step.employers.isNotEmpty) Text('Employers: ${step.employers.join(', ')}'),
          ],
          const Subhead('AI and this path'),
          AiOutlookView(path.ai),
          if (path.risks.isNotEmpty) ...[
            const Subhead('Risks'),
            Bullets(path.risks, icon: Icons.warning_amber_rounded, color: Status.warning.color),
          ],
          if (path.firstMoves.isNotEmpty) ...[
            const Subhead('First moves (next three months)'),
            Bullets(path.firstMoves, icon: Icons.directions_run),
          ],
          const SizedBox(height: 16),
          Hint(
            'career.target',
            child: FilledButton.icon(
              onPressed: () async {
                final n = await ref.mutate((s) => s.book.targetPath(path, today: today()));
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) showMessage(context, 'Added $n goals and certifications to Growth.');
              },
              icon: const Icon(Icons.flag),
              label: const Text('Target this path'),
            ),
          ),
        ],
      ),
    ),
  );
}

class AiOutlookView extends StatelessWidget {
  const AiOutlookView(this.ai, {super.key});
  final AiOutlook ai;

  @override
  Widget build(BuildContext context) {
    final e = _exposure[ai.exposure];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e != null) StatusLabel(e.$2, e.$1),
        if (ai.summary.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(ai.summary)),
        if (ai.atRisk.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Being automated:'),
          Bullets(ai.atRisk, icon: Icons.south_east, color: Status.warning.color),
        ],
        if (ai.growing.isNotEmpty) ...[
          const Text('Growing in value:'),
          Bullets(ai.growing, icon: Icons.north_east, color: Status.good.color),
        ],
        if (ai.skills.isNotEmpty) ...[
          const Text('Skills that keep you ahead:'),
          Bullets(ai.skills, icon: Icons.bolt),
        ],
      ],
    );
  }
}

class AssessmentView extends ConsumerWidget {
  const AssessmentView(this.a, {super.key, required this.created, required this.sources});
  final Assessment a;
  final String created;
  final List<Source> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const comp = {'strong': Status.good, 'average': Status.info, 'weak': Status.warning};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assessed ${niceDate(created)}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SelectableText(a.verdict, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StatusLabel(comp[a.competitiveness] ?? Status.info, '${a.level} · ${a.competitiveness} candidate'),
        if (a.position.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(a.position)),
        if (a.strengths.isNotEmpty) ...[
          const Subhead('Strengths'),
          Bullets(
            [
              for (final s in a.strengths)
                '${str(s['point'])}${str(s['evidence']).isEmpty ? '' : ' (${str(s['evidence'])})'}',
            ],
            icon: Icons.check,
            color: Status.good.color,
          ),
        ],
        if (a.weaknesses.isNotEmpty) ...[
          const Subhead('Weaknesses and fixes'),
          Bullets(
            [
              for (final w in a.weaknesses)
                '${str(w['point'])}${str(w['fix']).isEmpty ? '' : '. Fix: ${str(w['fix'])}'}',
            ],
            icon: Icons.build_outlined,
            color: Status.warning.color,
          ),
        ],
        if (a.challenges.isNotEmpty) ...[
          const Subhead('The toughest challenges'),
          for (final c in a.challenges)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(Icons.terrain, color: Status.serious.color),
              title: Text(str(c['challenge'])),
              children: [
                Align(alignment: Alignment.centerLeft, child: SelectableText(str(c['why']))),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText('How to prepare: ${str(c['prepare'])}'),
                ),
                const SizedBox(height: 8),
              ],
            ),
        ],
        const Subhead('AI in your field'),
        AiOutlookView(a.ai),
        if (a.targetRoles.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: Subhead('Roles to target')),
              TextButton(onPressed: () => _useTargets(context, ref), child: const Text('Search for these')),
            ],
          ),
          for (final r in a.targetRoles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(str(r['title'])),
              subtitle: Text([str(r['salaryRange']), str(r['why'])].where((s) => s.isNotEmpty).join('\n')),
              trailing: FitBadge(intOf(r['fit']), ai: true),
            ),
        ],
        if (a.countries.isNotEmpty) ...[
          const Subhead('Countries'),
          for (final c in a.countries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text('${Country.nameOf(str(c['country']).toUpperCase())}: ${str(c['demand'])} demand'),
              subtitle: Text(
                [
                  str(c['salaryRange']),
                  str(c['rightToWork']),
                  str(c['verdict']),
                ].where((s) => s.isNotEmpty).join('\n'),
              ),
            ),
        ],
        if (a.learning.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: Subhead('Learning and certifications')),
              TextButton(
                onPressed: () async {
                  final n = await ref.mutate((s) => s.book.suggestLearning(a.learning, today: today()));
                  if (context.mounted) {
                    showMessage(context, n == 0 ? 'Already in Growth.' : 'Added $n to Growth.');
                  }
                },
                child: const Text('Add to Growth'),
              ),
            ],
          ),
          for (final l in a.learning)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(l.priority == 'essential' ? Icons.priority_high : Icons.school_outlined),
              title: Text(l.title),
              subtitle: Text(
                [
                  [l.provider, l.cost, l.duration].where((s) => s.isNotEmpty).join(' · '),
                  l.why,
                ].where((s) => s.isNotEmpty).join('\n'),
              ),
              onTap: l.url.isEmpty ? null : () => openLink(context, l.url),
            ),
        ],
        if (a.quickWins.isNotEmpty) ...[const Subhead('This week'), Bullets(a.quickWins, icon: Icons.bolt)],
        SourcesList(sources),
      ],
    );
  }

  /// Puts the assessment's roles and search terms into the profile's targets.
  Future<void> _useTargets(BuildContext context, WidgetRef ref) async {
    final p = await ref.read(profileProvider.future);
    final roles = {
      ...p.targets.roles,
      for (final r in a.targetRoles) str(r['title']),
    }.where((s) => s.isNotEmpty);
    final terms = {...p.targets.keywords, ...a.searchTerms}.where((s) => s.isNotEmpty);
    await ref.mutate(
      (s) => s.book.saveProfile(
        p.copyWith(
          targets: p.targets.copyWith(roles: roles.toList(), keywords: terms.take(12).toList()),
        ),
      ),
    );
    if (context.mounted) {
      showMessage(context, 'Your target roles and search terms are updated. Refresh Jobs to search.');
    }
  }
}
