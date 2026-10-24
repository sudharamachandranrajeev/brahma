import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/modules.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'domain/car_owning.dart';
import 'domain/pipeline.dart';
import 'ui/hints.dart';
import 'ui/look.dart';

/// Vahana Anveshana as the Brahma suite app hosts it.
final vahanaSuite = SuiteApp(
  identity: vahanaIdentity,
  tagline: 'Cars: buying, owning and selling',
  icon: Icons.directions_car_outlined,
  open: AppSession.open,
  overrides: (s) => [sessionProvider.overrideWithValue(s as AppSession)],
  hints: vahanaHints,
  theme: (_, b) => vahanaTheme(b),
  builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
  home: (onHome) => AppShell(destinations: allDestinations, onHome: onHome, floating: true),
  summary: (_) => const _Summary(),
);

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today();
    final cars = ref.watch(vehiclesProvider).value ?? const [];
    final nation = ref.watch(carSearchProvider).value?.nation;
    final owned = cars.where((v) => v.boughtOn != null && v.soldOn == null);
    final looking = cars.where((v) => v.boughtOn == null && Stage.of(v.stage).active);
    final due = [for (final v in owned) ...deadlines(v, nation: nation, today: now).where((d) => d.soon)];
    return SummaryFigures([
      ('${looking.length}', 'being considered'),
      ('${owned.length}', 'owned'),
      ('${due.length}', 'dates due in 30 days'),
    ], next: cars.isEmpty ? 'Search, then add an advert link in the Garage.' : null);
  }
}
