import 'dart:io';
import 'dart:ui' as ui;

import 'package:brahma/app/app.dart';
import 'package:brahma/app/apps.dart';
import 'package:brahma/app/providers.dart';
import 'package:brahma/app/session.dart';
import 'package:brahma/ui/fonts.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udyoga/app/providers.dart' as udyoga;
import 'package:vani/app/providers.dart' as vani;

import '../../apps/vani/test/fake_hub.dart';
import 'seed.dart';

/// Renders the home screen and a few hosted apps with the real fonts to PNG
/// files, for checking the look and for the README. Every app is filled with
/// made-up data first (test/seed.dart). Runs only when BRAHMA_SHOTS names an
/// output folder: `BRAHMA_SHOTS=/tmp/shots flutter test test/screenshots_test.dart`.
void main() {
  final out = Platform.environment['BRAHMA_SHOTS'];

  Future<void> loadFonts() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts';
    await family('Roboto', [
      for (final w in ['Regular', 'Medium', 'Bold']) '$fonts/Roboto-$w.ttf',
    ]);
    await family('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    // The apps' own fonts, the way the suite loads them.
    await shareAppFonts();
  }

  testWidgets('screenshots', skip: out == null, (tester) async {
    final dir = Directory.systemTemp.createTempSync('brahma-shots');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
    await tester.runAsync(loadFonts);
    // Tests draw elevation as black outlines unless told otherwise.
    debugDisableShadows = false;
    final key = GlobalKey();
    var n = 0;

    Future<void> settle() async {
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('$out/${(++n).toString().padLeft(2, '0')}-$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    final suite = (await tester.runAsync(
      () => SuiteSession.open(KeyVault(MemorySecretStore(), brahmaIdentity), suiteApps),
    ))!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await tester.runAsync(() => seedSuite(suite, today));
    final hub = FakeHub();
    for (final (size, ratio, form) in [
      (const Size(1170, 2532), 3.0, 'phone'),
      (const Size(1600, 1000), 1.0, 'desktop'),
    ]) {
      for (final dark in [false, true]) {
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = ratio;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              // A fresh tree per shot, so each starts at the top.
              key: ValueKey('$form-$dark'),
              overrides: [
                ...suiteOverrides(suite),
                vani.httpClientProvider.overrideWithValue(hub.client),
                // No start-up job refresh: it would show a spinner.
                udyoga.refreshTickerProvider.overrideWithValue(null),
                // No GitHub: the panel reads "All clear".
                updateCheck.findings.overrideWith((_) async => const []),
                startupUpdateProvider.overrideWith((_) async => null),
                deviceFactsProvider.overrideWith((_) async => const DeviceFacts()),
                sentinelRulesProvider.overrideWith(
                  (_) async => SentinelRules(DateTime.now(), null, const []),
                ),
                threatFeedProvider.overrideWith((_) async => ThreatList(DateTime.now(), const [])),
              ],
              retry: (_, _) => null,
              child: const BrahmaApp(),
            ),
          ),
        );
        await settle();
        final mode = dark ? 'dark' : 'light';
        await shot('home-$form-$mode');
        if (dark) continue;
        for (final name in ['Udyoga', 'Vani', 'Vidya']) {
          await tester.ensureVisible(find.text(name));
          await tester.pump();
          await tester.tap(find.text(name));
          await settle();
          await shot('${name.toLowerCase()}-$form-$mode');
          final rail = find.byTooltip('All apps').hitTestable();
          if (rail.evaluate().isNotEmpty) {
            await tester.tap(rail.first);
          } else {
            // Phones keep "All apps" under More.
            final more = find.text('More').hitTestable();
            // Vani's bar has icons only.
            await tester.tap(more.evaluate().isEmpty ? find.byIcon(Icons.grid_view_rounded) : more.last);
            await settle();
            await tester.tap(find.text('All apps').last);
          }
          await settle();
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(suite.close);
    tester.view.reset();
    debugDisableShadows = true;
    dir.deleteSync(recursive: true);
  });
}
