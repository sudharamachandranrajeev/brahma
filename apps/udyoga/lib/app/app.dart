import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import 'modules.dart';
import 'providers.dart';
import 'settings_page.dart';

class UdyogaApp extends StatelessWidget {
  const UdyogaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Udyoga',
    debugShowCheckedModeBanner: false,
    theme: udyogaTheme(Brightness.light),
    darkTheme: udyogaTheme(Brightness.dark),
    builder: (context, child) => AppLockGate(child: Backdrop(child: child ?? const SizedBox.shrink())),
    home: home,
  );
}

/// The app, opening the links the platform hands over (a scanned pairing
/// code). There is no onboarding: Today says what to do first. At start it
/// asks to renew lapsed access to the Claude subscription, then offers a
/// new version when there is one.
class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPrompts().ignore());
  }

  Future<void> _startPrompts() async {
    final grant = await ref.read(claudeCodeGrantProvider.future);
    if (grant != null && !grant.activeAt(DateTime.now()) && mounted) {
      final next = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Renew access to your Claude subscription?'),
          content: Text(
            'Udyoga\'s 24-hour access to Claude Code${grant.account.isEmpty ? '' : ' (${grant.account})'} has '
            'ended, so the AI features are paused. Reconnect to check the sign-in and allow another 24 hours.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'forget'), child: const Text('Disconnect')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, 'renew'), child: const Text('Reconnect')),
          ],
        ),
      );
      if (!mounted) return;
      if (next == 'renew') await connectClaudeCode(context, ref);
      if (next == 'forget') await ref.mutate((s) => s.book.setClaudeCodeGrant(null));
    }
    final updater = ref.read(updaterProvider);
    if (updater == null) return;
    final release = await ref.read(updateProvider.future).catchError((_) => null);
    if (release != null && mounted) await offerUpdate(context, updater, release);
  }

  @override
  Widget build(BuildContext context) => LinkHandler(
    child: AppShell(
      destinations: allDestinations,
      floating: true,
      // The routine refresh: at start-up, then hourly while open (it runs
      // only what is due).
      onStart: (ref) => Future.microtask(() => ref.read(refreshTickerProvider)).ignore(),
    ),
  );
}
