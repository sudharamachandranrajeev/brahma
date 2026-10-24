import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'hosted_app.dart';
import 'settings_page.dart';

/// The life dashboard: one card per app with its figures for today. A card
/// opens the app.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Start the sync controller, then each app's own background work.
    ref.read(syncProvider);
    for (final app in ref.read(suiteProvider).apps) {
      app.onStart?.call(ref);
    }
  }

  void _open(SuiteApp app) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.short,
      pageBuilder: (context, _, _) => HostedApp(app, onHome: () => Navigator.of(context).pop()),
      transitionsBuilder: (context, animation, _, child) {
        final eased = CurvedAnimation(parent: animation, curve: Motion.curve);
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(eased), child: child),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(suiteProvider).apps;
    final type = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brahma'),
        actions: [
          const SyncIndicator(),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            FadeIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: type.headlineSmall),
                    const SizedBox(height: 4),
                    Text(niceDate(today()), style: type.bodyMedium),
                  ],
                ),
              ),
            ),
            for (var row = 0; row * columns < apps.length; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) const SizedBox(width: 12),
                        Expanded(
                          child: row * columns + c < apps.length
                              ? _AppCard(apps[row * columns + c], onOpen: _open)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
  }
}

/// An app's card, drawn in the app's own theme.
class _AppCard extends ConsumerWidget {
  const _AppCard(this.app, {required this.onOpen});
  final SuiteApp app;
  final void Function(SuiteApp app) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = app.theme(ref, Theme.of(context).brightness);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final type = Theme.of(context).textTheme;
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(app),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          child: Icon(app.icon),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(app.identity.name, style: type.titleMedium),
                              Text(
                                app.tagline,
                                style: type.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Hint('home.open', child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    app.summary(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
