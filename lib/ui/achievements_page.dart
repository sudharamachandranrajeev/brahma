import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/achievements.dart';
import '../domain/stats.dart';
import 'common.dart';
import 'zen.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocks = {for (final u in ref.watch(unlocksProvider).value ?? const <Unlock>[]) u.id: u.day};
    return PageScaffold(
      title: 'Achievements',
      body: AsyncView(
        ref.watch(statsProvider),
        onRetry: () => ref.invalidate(statsProvider),
        builder: (s) {
          final groups = <String, List<Achievement>>{};
          for (final a in achievements) {
            (groups[a.group] ??= []).add(a);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                        child: Text(
                          '${unlocks.length} of ${achievements.length} earned · each is worth ${Stats.xpAchievement} experience',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: muted(context)),
                        ),
                      ),
                      for (final g in groups.entries)
                        SectionCard(
                          title: g.key,
                          child: TileGrid(
                            minWidth: 260,
                            children: [
                              for (final a in g.value) _Badge(a, a.value(s), unlocks[a.key], s.today),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.a, this.value, this.day, this.today);
  final Achievement a;
  final num value;
  final String? day, today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final got = day != null;
    final frac = (value / a.target).clamp(0, 1).toDouble();
    return Semantics(
      label: '${a.title}. ${a.description} ${got ? 'Earned' : 'Not yet earned'}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: got ? clay.withValues(alpha: isDark(context) ? 0.14 : 0.1) : softFill(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: got ? clay.withValues(alpha: 0.5) : hairline(context)),
        ),
        child: Row(
          children: [
            Icon(got ? a.icon : Icons.lock_outline, size: 30, color: got ? clay : muted(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: t.titleSmall),
                  Text(a.description, style: t.bodySmall?.copyWith(color: muted(context))),
                  const SizedBox(height: 6),
                  got
                      ? Text(
                          'Earned ${relativeDay(day!, today!)}',
                          style: t.labelSmall?.copyWith(color: clay),
                        )
                      : LinearProgressIndicator(value: frac, minHeight: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
