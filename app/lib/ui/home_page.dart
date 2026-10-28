import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app.dart';
import '../app/apps.dart';
import '../app/providers.dart';
import 'hosted_app.dart';
import 'settings_page.dart';

/// The life dashboard: a greeting, then one card per app with its figures
/// for today. A card opens the app.
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
    final gap = width >= 700 ? 16.0 : 12.0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: ListView(
              padding: EdgeInsets.fromLTRB(gap, gap, gap, 32),
              children: [
                const FadeIn(child: _Hero()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
                  child: Text('Your apps', style: type.titleSmall?.copyWith(color: muted)),
                ),
                ..._grid([for (final app in apps) _AppCard(app, onOpen: _open)], columns, gap),
                if (linkedApps.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                    child: Text('More Brahma apps', style: type.titleSmall?.copyWith(color: muted)),
                  ),
                  ..._grid([for (final app in linkedApps) _LinkedCard(app)], columns, gap, after: apps.length),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [cards] in rows of [columns] equal-height cells, each fading in after
/// the [after] cards above it.
List<Widget> _grid(List<Widget> cards, int columns, double gap, {int after = 0}) => [
  for (var row = 0; row * columns < cards.length; row++)
    Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: gap),
              Expanded(
                child: row * columns + c < cards.length
                    ? FadeIn(
                        delay: Duration(milliseconds: 50 * (after + row * columns + c + 1)),
                        child: cards[row * columns + c],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    ),
];

/// The top of the page: Brahma's dusk-to-saffron panel with the greeting,
/// the date, Sentinel, sync and settings.
class _Hero extends StatelessWidget {
  const _Hero();

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    const ink = Colors.white;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dusk, Color(0xFF4A3D8F), Color(0xFF8A4F7D)],
        ),
      ),
      child: Stack(
        children: [
          // Sunrise: a saffron glow behind the top corner.
          Positioned(
            right: -120,
            top: -140,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [saffron.withValues(alpha: 0.55), saffron.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 12, 12, wide ? 32 : 24),
            child: IconButtonTheme(
              // Light icons on the panel, the sync one too while sync is off.
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: ink,
                  disabledForegroundColor: ink.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.spa_outlined, color: saffron),
                      const SizedBox(width: 10),
                      Text(
                        'Brahma',
                        style: type.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const SyncIndicator(),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 36 : 24),
                  Text(
                    _greeting(),
                    style: (wide ? type.displaySmall : type.headlineMedium)?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    niceDate(today()),
                    style: type.titleMedium?.copyWith(color: ink.withValues(alpha: 0.78)),
                  ),
                  SizedBox(height: wide ? 20 : 16),
                  const _SentinelChip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sentinel's summary on the panel; opens the Sentinel page.
class _SentinelChip extends ConsumerWidget {
  const _SentinelChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(sentinelProvider);
    const ink = Colors.white;
    // Saffron for something to look at: the panel's own colours stay legible.
    final color = r.toFix.isEmpty ? ink : saffron;
    return Material(
      color: ink.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => openSentinel(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sentinelIcon(r.status), size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'Sentinel · ${sentinelSummary(r)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An app's card: Brahma's neutral frame, tinted with the app's colour, and
/// the app's figures.
class _AppCard extends ConsumerStatefulWidget {
  const _AppCard(this.app, {required this.onOpen});
  final SuiteApp app;
  final void Function(SuiteApp app) onOpen;

  @override
  ConsumerState<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<_AppCard> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    final type = base.textTheme;
    final own = app.theme(ref, base.brightness).colorScheme;
    final accent = own.primary;
    final dark = base.brightness == Brightness.dark;
    final radius = BorderRadius.circular(24);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Motion.short,
        curve: Motion.curve,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: const Alignment(0.4, 1),
            colors: [
              Color.alphaBlend(accent.withValues(alpha: dark ? 0.16 : 0.09), scheme.surfaceContainerLow),
              scheme.surfaceContainerLow,
            ],
          ),
          border: Border.all(
            color: _hover ? accent.withValues(alpha: 0.6) : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            if (_hover)
              BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => widget.onOpen(app),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, Color.lerp(accent, Colors.black, 0.25)!],
                          ),
                        ),
                        child: Icon(app.icon, color: own.onPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.identity.name,
                              style: type.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              app.tagline,
                              style: type.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Hint(
                        'home.open',
                        child: AnimatedContainer(
                          duration: Motion.short,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hover ? accent : scheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: _hover ? own.onPrimary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // The figures in Brahma's type, with the app's colour as primary.
                  Theme(
                    data: base.copyWith(colorScheme: scheme.copyWith(primary: accent)),
                    child: Builder(builder: app.summary),
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

/// A linked app's card: the same frame as [_AppCard], without figures. It
/// opens the app's download page in the browser.
class _LinkedCard extends StatelessWidget {
  const _LinkedCard(this.app);
  final LinkedApp app;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(app.page, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open ${app.page}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = app.color;
    final radius = BorderRadius.circular(24);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: const Alignment(0.4, 1),
          colors: [
            Color.alphaBlend(accent.withValues(alpha: dark ? 0.16 : 0.09), scheme.surfaceContainerLow),
            scheme.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, Color.lerp(accent, Colors.black, 0.25)!],
                    ),
                  ),
                  child: Icon(app.icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: type.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        app.tagline,
                        style: type.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Opens in your browser',
                  child: Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
