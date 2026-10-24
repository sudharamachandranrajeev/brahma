import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The brightness [app] asks for: its own setting, else the system's.
Brightness appBrightness(BuildContext context, WidgetRef ref, SuiteApp app) =>
    switch (app.themeMode?.call(ref) ?? ThemeMode.system) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

/// One app's screens inside the suite, as if it ran on its own: its name
/// and hints, its theme, its own navigator (so the pages it opens keep its
/// look) and its own snackbars. [onHome] returns to the suite's home.
class HostedApp extends ConsumerStatefulWidget {
  const HostedApp(this.app, {super.key, required this.onHome});
  final SuiteApp app;
  final VoidCallback onHome;

  @override
  ConsumerState<HostedApp> createState() => _HostedAppState();
}

class _HostedAppState extends ConsumerState<HostedApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final pages = NavigatorPopHandler<Object?>(
      // Back closes the app's own pages first, then the app.
      onPopWithResult: (_) => _navigator.currentState!.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => app.home(widget.onHome)),
      ),
    );
    return ProviderScope(
      overrides: [
        appIdentityProvider.overrideWithValue(app.identity),
        hintTextsProvider.overrideWithValue({...coreHints, ...app.hints}),
      ],
      child: AnimatedTheme(
        data: app.theme(ref, appBrightness(context, ref, app)),
        child: ScaffoldMessenger(
          child: Builder(builder: (context) => app.builder?.call(context, pages) ?? pages),
        ),
      ),
    );
  }
}
