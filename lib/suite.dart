import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/modules.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'db/database.dart';
import 'domain/pipeline.dart';
import 'ui/hints.dart';
import 'ui/look.dart';

/// Udyoga as the Brahma suite app hosts it.
final udyogaSuite = SuiteApp(
  identity: udyogaIdentity,
  tagline: 'Career and job search',
  icon: Icons.work_outline,
  open: AppSession.open,
  overrides: (s) => [sessionProvider.overrideWithValue(s as AppSession)],
  hints: udyogaHints,
  theme: udyogaTheme,
  home: (onHome) => AppShell(destinations: allDestinations, floating: true, onHome: onHome),
  builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
  // The routine refresh, as in the app (it runs only what is due).
  onStart: (ref) => Future.microtask(() => ref.read(refreshTickerProvider)).ignore(),
  summary: (_) => const _Summary(),
);

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today();
    final jobs = ref.watch(jobsProvider).value ?? const <Job>[];
    final apps = ref.watch(applicationsProvider).value ?? const <JobApplication>[];
    final leads = ref.watch(leadsProvider).value ?? const <Lead>[];
    bool due(String? followUp) => followUp != null && followUp.compareTo(now) <= 0;
    final open = apps.where((a) => Stage.of(a.stage).open).toList();
    final dueCount =
        open.where((a) => due(a.followUp)).length +
        leads.where((l) => due(l.followUp) && l.status != 'cold').length;
    return SummaryFigures([
      ('${jobs.where((j) => j.status == 'new').length}', 'new openings'),
      ('${open.length}', 'open applications'),
      ('$dueCount', 'follow-ups due'),
    ], next: jobs.isEmpty ? 'Import your CV and refresh Jobs to find openings.' : null);
  }
}
