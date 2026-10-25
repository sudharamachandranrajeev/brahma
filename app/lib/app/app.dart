import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/home_page.dart';

/// Dawn indigo with a saffron accent, from the lotus icon.
const dusk = Color(0xFF2B2A6B);
const saffron = Color(0xFFF5A35C);

ThemeData brahmaTheme(Brightness b) => buildTheme(b, seed: dusk, accent: saffron);

class BrahmaApp extends StatelessWidget {
  const BrahmaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Brahma',
    debugShowCheckedModeBanner: false,
    theme: brahmaTheme(Brightness.light),
    darkTheme: brahmaTheme(Brightness.dark),
    // Over every page, the hosted apps' too.
    builder: (context, child) => AppLockGate(child: child!),
    home: const LinkHandler(child: HomePage()),
  );
}
