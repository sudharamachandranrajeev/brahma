import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/widgets.dart';
import 'links.dart';
import 'pairing_dialogs.dart';
import 'providers.dart';

/// Wraps an app's home and opens the setup and pairing links the platform
/// hands over (a scanned pairing code).
class LinkHandler extends ConsumerStatefulWidget {
  const LinkHandler({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LinkHandler> createState() => _LinkHandlerState();
}

class _LinkHandlerState extends ConsumerState<LinkHandler> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final links = PlatformLinks(ref.read(appIdentityProvider));
    links.listen(_open);
    links.initial().then((link) {
      if (link != null) _open(link);
    });
  }

  Future<void> _open(String link) async {
    // One at a time: a second scan while a dialog is up is ignored.
    if (_opening || !mounted) return;
    _opening = true;
    try {
      await openBrahmaLink(context, ref, link);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown when the app cannot open its keys or database. Nothing is deleted:
/// the user is told what failed and can retry.
class StartupFailure extends StatelessWidget {
  const StartupFailure(
    this.error, {
    super.key,
    required this.appName,
    required this.theme,
    required this.onRetry,
  });
  final Object error;
  final String appName;
  final ThemeData Function(Brightness) theme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Status.critical.color),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) => Text(
                      '$appName could not open your data',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(describeError(error), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'Your data has not been changed or deleted. On Linux, check that the desktop keyring is '
                    'running and unlocked.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
