import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import 'modules.dart';

ThemeData vahanaTheme(Brightness b) => instrumentTheme(b);

class VahanaApp extends StatelessWidget {
  const VahanaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vahana Anveshana',
    debugShowCheckedModeBanner: false,
    theme: vahanaTheme(Brightness.light),
    darkTheme: vahanaTheme(Brightness.dark),
    builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
    home: home,
  );
}

/// The app, opening the links the platform hands over (a scanned pairing
/// code). There is no onboarding: every screen works empty.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LinkHandler(child: AppShell(destinations: allDestinations, floating: true));
}
