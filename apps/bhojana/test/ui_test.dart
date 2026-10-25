import 'package:bhojana/app/modules.dart';
import 'package:bhojana/domain/reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('a new list takes items, compares one and costs the list', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run(
      searcher: const FakeSearcher({
        'tesco': [
          Offer(shop: 'tesco', title: 'Tesco Free Range Eggs 12', pence: 325, offer: 'Clubcard Price'),
          Offer(shop: 'tesco', title: 'Chocolate', pence: 100),
        ],
        'aldi': [Offer(shop: 'aldi', title: 'Merevale Free Range Eggs 12', pence: 289)],
      }),
    );
    await app.tapText('New list');
    await app.tapText('Create');
    expect(find.text('Weekly shop'), findsWidgets);
    await app.enter('Add an item', '2 free range eggs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();
    expect(find.text('2 × free range eggs'), findsOneWidget);

    await app.tap(find.byTooltip('Item'));
    await app.tapText('Compare prices');
    await app.tap(find.textContaining('Search 6 shops'));
    expect(find.text('Merevale Free Range Eggs 12'), findsOneWidget);
    expect(find.text('Chocolate'), findsNothing);
    await app.tap(find.byTooltip('Keep this price').last);
    expect(find.text('Prices kept'), findsOneWidget);
    await app.tap(find.byType(BackButton));

    expect(find.text('£2.89 at Aldi'), findsOneWidget);
    expect(find.text('£5.78'), findsOneWidget);
    await app.tap(find.byType(Checkbox).first);
    expect(find.text('0 to buy'), findsOneWidget);
    await app.close();
  });

  testWidgets('the postcode is checked and kept', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open();
    await app.run();
    await app.go('Shops');
    await app.tapText('Set');
    await app.enter('Postcode', 'not a code');
    await app.tapText('Save');
    expect(find.text('That does not look like a UK postcode.'), findsOneWidget);
    await app.enter('Postcode', 'bt74  7aa');
    await app.tapText('Save');
    expect(find.textContaining('BT74 7AA.'), findsOneWidget);
    await app.close();
  });
}
