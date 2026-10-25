import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bhojana/app/app.dart';
import 'package:bhojana/app/providers.dart';

import 'app_harness.dart';
import 'seed.dart';

/// Renders the main pages with the real fonts to PNG files, for checking
/// the look and for the README. Runs only when BHOJANA_SHOTS names an
/// output folder: `BHOJANA_SHOTS=/tmp/shots flutter test test/screenshots_test.dart`.
void main() {
  final out = Platform.environment['BHOJANA_SHOTS'];

  Future<void> loadFonts() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    await family('Inter', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf',
    ]);
    await family('PlusJakartaSans', [
      for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/PlusJakartaSans-$w.ttf',
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }

  testWidgets('screenshots', skip: out == null, (tester) async {
    await tester.runAsync(loadFonts);
    // Tests draw elevation as black outlines unless told otherwise.
    debugDisableShadows = false;
    final key = GlobalKey();
    var n = 0;

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

    Widget app(AppHarness h) => RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: bhojanaOverrides(h.session),
        retry: (_, _) => null,
        child: const BhojanaApp(),
      ),
    );

    for (final dark in [false, true]) {
      tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
      final h = AppHarness(tester);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      await h.open(seed: seedBook);
      await tester.pumpWidget(app(h));
      await h.settle();
      final mode = dark ? 'dark' : 'light';
      await shot('list-$mode');
      if (!dark) {
        for (final page in ['Compare', 'Shops']) {
          await h.go(page);
          await shot('${page.toLowerCase()}-$mode');
        }
      }
      await h.close();
    }
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.view.reset();

    final h = AppHarness(tester)..desktop();
    await h.open(seed: seedBook);
    await tester.pumpWidget(app(h));
    await h.settle();
    await shot('list-desktop');
    await h.go('Shops');
    await shot('shops-desktop');
    await h.close();
    debugDisableShadows = true;
  });
}
