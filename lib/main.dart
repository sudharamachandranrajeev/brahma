import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'ui/look.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  try {
    final session = await AppSession.open(KeyVault(const DeviceSecretStore(), udyogaIdentity));
    runApp(
      ProviderScope(
        overrides: udyogaOverrides(session),
        // Failures are shown with a retry button; silent retries would hide them.
        retry: (_, _) => null,
        child: const UdyogaApp(),
      ),
    );
  } catch (e) {
    // Also in release builds' logs, where smoke tests look for it.
    debugPrint('Udyoga startup failed: $e');
    runApp(StartupFailure(e, appName: udyogaIdentity.name, theme: udyogaTheme, onRetry: _start));
  }
}
