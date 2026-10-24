import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import 'modules.dart';
import 'providers.dart';

class UdyogaApp extends StatelessWidget {
  const UdyogaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Udyoga',
    debugShowCheckedModeBanner: false,
    theme: udyogaTheme(Brightness.light),
    darkTheme: udyogaTheme(Brightness.dark),
    builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
    home: home,
  );
}

/// The app, opening the links the platform hands over (a scanned pairing
/// code). There is no onboarding: Today says what to do first.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) => LinkHandler(
    child: AppShell(
      destinations: allDestinations,
      floating: true,
      // The routine refresh: at start-up, then hourly while open (it runs
      // only what is due).
      onStart: (ref) => Future.microtask(() => ref.read(refreshTickerProvider)).ignore(),
    ),
  );
}
