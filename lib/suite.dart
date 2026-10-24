import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/session.dart';
import 'app/shell.dart';
import 'domain/hub.dart';
import 'ui/hints.dart';
import 'ui/look.dart';

/// Vani as the Brahma suite app hosts it.
final vaniSuite = SuiteApp(
  identity: vaniIdentity,
  tagline: 'Social media: posts, inbox and alerts',
  icon: Icons.campaign_outlined,
  open: AppSession.open,
  overrides: (s) => [sessionProvider.overrideWithValue(s as AppSession)],
  hints: vaniHints,
  theme: vaniTheme,
  themeMode: (ref) => ref.watch(themeProvider).value,
  home: (onHome) => VaniShell(onHome: onHome),
  builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
  summary: (_) => const _Summary(),
);

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(overviewProvider)) {
    AsyncData(value: final o) => SummaryFigures([
      ('${o.upcoming.length}', 'posts scheduled'),
      ('${o.inboxNew}', 'new in inbox'),
      ('${o.alerts.where((a) => !a.read).length}', 'unread alerts'),
    ]),
    AsyncError(error: NoHubException()) => const SummaryFigures(
      [],
      next: 'Connect your social hub in Settings.',
    ),
    AsyncError(:final error) => SummaryFigures(const [], next: describeError(error)),
    _ => const SizedBox(height: 48),
  };
}
