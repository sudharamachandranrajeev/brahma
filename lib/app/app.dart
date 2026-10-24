import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/zen.dart';
import 'modules.dart';
import 'providers.dart';

final _messenger = GlobalKey<ScaffoldMessengerState>();

class VidyaApp extends StatelessWidget {
  const VidyaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vidya',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: _messenger,
    theme: vidyaTheme(Brightness.light),
    darkTheme: vidyaTheme(Brightness.dark),
    builder: (context, child) => Backdrop(child: child ?? const SizedBox.shrink()),
    home: home,
  );
}

/// The app. There is no onboarding: Home says what to do first. Each
/// achievement a write earns is announced once, quietly.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(celebrationsProvider, (_, list) {
      if (list.isEmpty) return;
      final text = list.length == 1
          ? 'Achievement earned: ${list.first.title}'
          : 'Achievements earned: ${list.map((a) => a.title).join(', ')}';
      ref.read(celebrationsProvider.notifier).clear();
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('🏅 $text')));
    });
    return LinkHandler(child: AppShell(destinations: allDestinations, floating: true));
  }
}
