import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// Renders the main pages with the real fonts to PNG files, for checking
/// the look and for the README. Runs only when VANI_SHOTS names an output
/// folder: `VANI_SHOTS=/tmp/shots flutter test test/screenshots_test.dart`.
void main() {
  final out = Platform.environment['VANI_SHOTS'];

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
    final pub = Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache';
    final brands = Directory('$pub/hosted/pub.dev')
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains('font_awesome_flutter-'))
        .map((d) => File('${d.path}/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf'))
        .where((f) => f.existsSync())
        .lastOrNull;
    if (brands != null) await family('packages/font_awesome_flutter/FontAwesomeBrands', [brands.path]);
  }

  testWidgets('screenshots', skip: out == null, (tester) async {
    await tester.runAsync(loadFonts);
    // Tests draw elevation as black outlines unless told otherwise.
    debugDisableShadows = false;
    final key = GlobalKey();

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('$out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    const pages = ['Home', 'Calendar', 'Inbox', 'Alerts', 'Analytics', 'Accounts', 'Settings'];
    for (final phone in [false, true]) {
      for (final theme in [ThemeMode.dark, ThemeMode.light]) {
        final app = AppHarness(tester);
        if (phone) {
          tester.view.physicalSize = const Size(1170, 2532);
          tester.view.devicePixelRatio = 3;
        } else {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
        }
        await app.open(theme: theme);
        await app.run(key: key);
        final tag = '${phone ? 'phone' : 'desktop'}-${theme.name}';
        for (final (i, page) in pages.indexed) {
          // Light mode: the main three pages are enough.
          if (theme == ThemeMode.light && i > 2) break;
          await app.go(page);
          // Let count-ups and staggered entrances finish.
          await tester.pump(const Duration(seconds: 2));
          await app.settle();
          await shot('$tag-${i + 1}-${page.toLowerCase()}');
        }
        if (theme == ThemeMode.dark) {
          await app.compose();
          await tester.pump(const Duration(seconds: 1));
          await app.settle();
          await shot('$tag-8-compose');
        }
        await app.close();
        tester.view.reset();
      }
    }
    debugDisableShadows = true;
  });
}
