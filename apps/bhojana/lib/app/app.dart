import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/look.dart';
import 'modules.dart';

class BhojanaApp extends StatelessWidget {
  const BhojanaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Bhojana',
    debugShowCheckedModeBanner: false,
    theme: bhojanaTheme(Brightness.light),
    darkTheme: bhojanaTheme(Brightness.dark),
    builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
    home: home,
  );
}

/// The app, opening the links the platform hands over (a scanned pairing
/// code).
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => const LinkHandler(child: BhojanaHome());
}

/// Bhojana's screens. [onHome] leads back to the Brahma suite's home screen
/// when the suite hosts Bhojana.
class BhojanaHome extends StatelessWidget {
  const BhojanaHome({super.key, this.onHome});
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) =>
      AppShell(destinations: allDestinations, floating: true, onHome: onHome);
}
