import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sentinel/core_checks.dart';
import '../sentinel/sentinel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'providers.dart';

/// The report in a few words: "All clear", "2 to look at" or "Checking…".
String sentinelSummary(SentinelReport r) {
  final n = r.toFix.length;
  if (n > 0) return '$n to look at';
  return r.checking ? 'Checking…' : 'All clear';
}

/// The shield for a report's [SentinelReport.status].
IconData sentinelIcon(Status status) => switch (status) {
  Status.good || Status.info => Icons.gpp_good_outlined,
  Status.warning => Icons.gpp_maybe_outlined,
  Status.serious || Status.critical => Icons.gpp_bad_outlined,
};

Future<void> openSentinel(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SentinelPage()));

/// Sentinel's row in Settings: the summary, opening the Sentinel page.
class SentinelTile extends ConsumerWidget {
  const SentinelTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(sentinelProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(sentinelIcon(r.status), color: r.status == Status.good ? null : r.status.color),
      title: const Text('Sentinel'),
      subtitle: Text(sentinelSummary(r)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openSentinel(context),
    );
  }
}

/// Everything Sentinel found, most severe first, each with its fix.
class SentinelPage extends ConsumerWidget {
  const SentinelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(sentinelProvider);
    final type = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final checks = ref.watch(sentinelChecksProvider);
    final updates = ref.watch(updateChecksProvider).value ?? true;
    return PageScaffold(
      title: 'Sentinel',
      actions: [
        IconButton(tooltip: 'Check again', icon: const Icon(Icons.refresh), onPressed: () => recheck(ref)),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Row(
            children: [
              Icon(
                sentinelIcon(r.status),
                size: 40,
                color: r.status == Status.good ? StatusColors.good : r.status.color,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sentinelSummary(r), style: type.headlineSmall),
                    Text(
                      'Checks: ${checks.map((c) => c.title).join(', ')}.',
                      style: type.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final f in r.findings) _FindingCard(f),
        SectionCard(
          title: 'Settings',
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              if (ref.watch(appIdentityProvider).releases != null)
                SwitchListTile(
                  title: const Text('Look for new versions'),
                  subtitle: const Text('Asks GitHub for the newest release once each start.'),
                  value: updates,
                  onChanged: (v) => ref.read(updateChecksProvider.notifier).set(v),
                ),
              ListTile(
                title: const Text('Snoozed'),
                subtitle: Text(r.snoozed == 0 ? 'Nothing snoozed.' : '${r.snoozed} hidden for now.'),
                trailing: OutlinedButton(
                  onPressed: r.snoozed == 0 ? null : () => ref.read(snoozesProvider.notifier).restore(),
                  child: const Text('Show again'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FindingCard extends ConsumerWidget {
  const _FindingCard(this.finding);
  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = finding;
    final type = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(f.status.icon, color: f.status.color),
                const SizedBox(width: 12),
                Expanded(child: Text(f.title, style: type.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(f.why),
            if (f.steps != null) ...[const SizedBox(height: 8), Text(f.steps!)],
            const SizedBox(height: 4),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => ref.read(snoozesProvider.notifier).snooze(f.id),
                  child: const Text('Snooze 30 days'),
                ),
                if (f.fix case final fix?)
                  FilledButton.tonal(
                    // Checks watch what a fix changes, so they rerun by themselves.
                    onPressed: () => guarded(context, () => fix.run(ref)),
                    child: Text(fix.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
