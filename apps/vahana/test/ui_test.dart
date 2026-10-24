import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// Smoke tests: every page builds, empty, on phone and desktop widths,
/// without throwing or overflowing; and the main flows.
void main() {
  const pages = ['Search', 'Garage', 'Finance', 'Guide', 'Settings'];

  testWidgets('every page builds on a desktop window', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('every page builds on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppHarness(tester);
    await app.open();
    await app.run();
    for (final label in pages) {
      final bar = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
      if (bar.evaluate().isNotEmpty) {
        await app.tap(find.ancestor(of: bar, matching: find.byType(NavigationDestination)));
      } else {
        await app.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
        await app.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(label)));
      }
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('cars: add by hand, then every tab builds', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Search');
    expect(find.text('What you want'), findsOneWidget);
    await app.go('Garage');
    await app.tapText('Add');
    await app.tapText('Type it in');
    await app.enter('Car', '2016 Ford Focus Zetec');
    await app.enter('Price', '4250');
    await app.tapText('Save');
    expect(find.text('2016 Ford Focus Zetec'), findsWidgets);
    expect(find.text('FOUND · 1'), findsOneWidget);
    await app.go('Finance');
    expect(find.text('THE PLANS COMPARED'), findsOneWidget);
    await app.go('Guide');
    expect(find.text('Your rights'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('cars: buy, log an MOT, see dates and rights', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Search');
    await app.go('Garage');
    await app.tapText('Add');
    await app.tapText('Type it in');
    await app.enter('Car', '2019 Ford Focus');
    await app.enter('Price', '9000');
    await app.tapText('Save');
    await app.tapText('Open');
    expect(find.text('Before you pay'), findsOneWidget);
    await app.tapText('I bought it');
    expect(find.text('Your rights as the buyer'), findsOneWidget);
    expect(find.text('Logbook'), findsOneWidget);
    await app.tapText('Add');
    await app.tapText('Save');
    expect(tester.takeException(), isNull);
    await app.close();
  });
}
