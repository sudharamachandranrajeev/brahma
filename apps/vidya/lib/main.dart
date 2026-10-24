import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'ui/zen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  try {
    final session = await AppSession.open(KeyVault(const DeviceSecretStore(), vidyaIdentity));
    runApp(
      ProviderScope(
        overrides: vidyaOverrides(session),
        // Failures are shown with a retry button; silent retries would hide them.
        retry: (_, _) => null,
        child: const VidyaApp(),
      ),
    );
  } catch (e) {
    // Also in release builds' logs, where smoke tests look for it.
    debugPrint('Vidya startup failed: $e');
    runApp(StartupFailure(e, appName: vidyaIdentity.name, theme: vidyaTheme, onRetry: _start));
  }
}
