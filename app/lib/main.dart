import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/apps.dart';
import 'app/providers.dart';
import 'app/session.dart';
import 'ui/fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await shareAppFonts();
  await _start();
}

Future<void> _start() async {
  try {
    final suite = await SuiteSession.open(KeyVault(const DeviceSecretStore(), brahmaIdentity), suiteApps);
    runApp(
      ProviderScope(
        overrides: suiteOverrides(suite),
        // Failures are shown with a retry button; silent retries would hide them.
        retry: (_, _) => null,
        child: const BrahmaApp(),
      ),
    );
  } catch (e) {
    // Also in release builds' logs, where smoke tests look for it.
    debugPrint('Brahma startup failed: $e');
    runApp(StartupFailure(e, appName: brahmaIdentity.name, theme: brahmaTheme, onRetry: _start));
  }
}
