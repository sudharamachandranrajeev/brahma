import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/app/modules.dart';

import 'app_harness.dart';
import 'seed.dart';

/// Smoke tests: every page builds, with and without data, on phone and
/// desktop widths, without throwing or overflowing; and the main flows.
void main() {
  final pages = [for (final d in allDestinations) d.label];

  testWidgets('every page builds on a desktop window, empty and with data', (tester) async {
    for (final seeded in [false, true]) {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seeded ? seedBook : null);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label (seeded: $seeded)');
      }
      await app.close();
    }
  });

  testWidgets('every page builds on a phone', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    for (final label in pages) {
      await app.go(label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await app.close();
  });

  testWidgets('starting from a template, finishing a topic earns an achievement', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Learn');
    await app.tapText('Use a template');
    await app.tapText('Software engineer');
    expect(find.text('Software engineer'), findsOneWidget);
    await app.tapText('Software engineer');
    await app.tapText('Programming fundamentals');
    await app.tap(find.byType(Checkbox).first);
    expect(find.textContaining('Achievement earned: First step'), findsOneWidget);
    await app.close();
  });
}
