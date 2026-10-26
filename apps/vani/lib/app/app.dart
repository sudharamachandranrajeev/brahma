import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/hub_setup.dart';
import '../ui/look.dart';
import 'providers.dart';
import 'shell.dart';

class VaniApp extends ConsumerWidget {
  const VaniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Vani',
    debugShowCheckedModeBanner: false,
    theme: vaniTheme(Brightness.light),
    darkTheme: vaniTheme(Brightness.dark),
    themeMode: ref.watch(themeProvider).value ?? ThemeMode.dark,
    themeAnimationDuration: const Duration(milliseconds: 350),
    builder: (context, child) => AppLockGate(child: Backdrop(child: child ?? const SizedBox.shrink())),
    // There is no onboarding: without a hub every page offers to connect one.
    home: LinkHandler(
      onAppLink: (context, link) => openHubLink(context, ref, link),
      child: const VaniShell(),
    ),
  );
}
