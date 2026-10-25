import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vahana/app/app.dart';
import 'package:vahana/app/providers.dart';
import 'package:vahana/db/database.dart';
import 'package:vahana/domain/book.dart';

import 'app_harness.dart';

/// Renders the main screens with the real fonts to PNG files, for checking
/// the look. Runs only when VAHANA_SHOTS names an output folder:
/// `VAHANA_SHOTS=/tmp/shots flutter test test/screenshots_test.dart`.
void main() {
  final out = Platform.environment['VAHANA_SHOTS'];

  Future<void> loadFonts() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    final inter = [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf',
    ];
    await family('Inter', inter);
    // A few list-tile trailing texts ask for the platform's Roboto, which the
    // test engine lacks (it draws boxes); stand Inter in for it.
    await family('Roboto', inter);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }

  // Made-up cars: nothing here is anyone's data.
  Future<void> seed(CarBook book) async {
    // Page explanations ("Got it" banners) off, so the content shows.
    await book.db.setLocalSetting('ui.hints', 'off');
    Future<void> car(String id, VehiclesCompanion c) =>
        book.save(book.db.vehicles, c.copyWith(id: Value(id), added: const Value('2026-10-01')), id);
    await car(
      'a',
      const VehiclesCompanion(
        title: Value('2019 Toyota Yaris 1.5 Hybrid Icon'),
        price: Value(11495),
        year: Value(2019),
        mileage: Value(38200),
        fuel: Value('Hybrid'),
        sellerType: Value('dealer'),
        location: Value('Sampletown'),
        stage: Value('shortlisted'),
        rating: Value(4),
      ),
    );
    await car(
      'b',
      const VehiclesCompanion(
        title: Value('2018 Ford Fiesta 1.0 EcoBoost Zetec'),
        price: Value(8750),
        year: Value(2018),
        mileage: Value(52100),
        fuel: Value('Petrol'),
        sellerType: Value('private'),
        rating: Value(3),
      ),
    );
    await car(
      'c',
      const VehiclesCompanion(
        title: Value('2017 Skoda Octavia Estate 1.6 TDI'),
        price: Value(9400),
        year: Value(2017),
        mileage: Value(71000),
        fuel: Value('Diesel'),
        stage: Value('agreed'),
        boughtOn: Value('2026-06-02'),
        motDue: Value('2026-11-12'),
        taxDue: Value('2027-06-01'),
        insuranceDue: Value('2027-05-28'),
      ),
    );
  }

  testWidgets('screenshots', skip: out == null, (tester) async {
    await tester.runAsync(loadFonts);
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

    for (final dark in [true, false]) {
      tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
      final app = AppHarness(tester);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      await app.open(seed: seed);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: vahanaOverrides(app.session),
            retry: (_, _) => null,
            child: const VahanaApp(),
          ),
        ),
      );
      await app.settle();
      final mode = dark ? 'dark' : 'light';
      await shot('search-$mode');
      for (final page in ['Garage', 'Finance']) {
        await app.dock(page);
        await shot('${page.toLowerCase()}-$mode');
      }
      await tester.flingFrom(const Offset(40, 400), const Offset(300, 0), 1000);
      await app.settle();
      await shot('panel-$mode');
      await app.tap(find.text('Garage').last);
      await app.tap(find.text('Open').last);
      await shot('car-$mode');
      await app.close();
    }

    // One desktop-width shot: the navigation rail layout.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final app = AppHarness(tester);
    tester.view.physicalSize = const Size(2160, 1350);
    tester.view.devicePixelRatio = 1.5;
    await app.open(seed: seed);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: vahanaOverrides(app.session),
          retry: (_, _) => null,
          child: const VahanaApp(),
        ),
      ),
    );
    await app.settle();
    await app.go('Garage');
    await shot('garage-desktop-light');
    await app.go('Finance');
    await shot('finance-desktop-light');
    await app.close();
    tester.view.reset();
    debugDisableShadows = true;
  });
}
