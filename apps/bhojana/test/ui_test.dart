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

  testWidgets('a new item is priced at every shop by itself and the cheapest shop named', (tester) async {
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

    // Searched and kept without the user comparing.
    expect(find.text('£2.89 at Aldi · Merevale Free Range Eggs 12'), findsOneWidget);
    expect(find.text('£5.78'), findsOneWidget);
    expect(find.text('£6.50'), findsOneWidget);
    expect(
      find.text('Cheapest at Aldi: £5.78 for all 1 item, 72p less than Tesco.', findRichText: true),
      findsOneWidget,
    );

    // Picking a product by hand replaces the automatic pick at that shop.
    await app.tap(find.byTooltip('Item'));
    await app.tapText('Compare prices');
    await app.tap(find.textContaining('Search 6 shops'));
    expect(find.text('Chocolate'), findsNothing);
    expect(find.text('Merevale Free Range Eggs 12'), findsNWidgets(2));
    await app.tap(find.byTooltip('Keep this price').last);
    expect(find.text('Merevale Free Range Eggs 12'), findsNWidgets(2));
    await app.tap(find.byType(BackButton));

    expect(find.text('£2.89 at Aldi'), findsOneWidget);
    await app.tap(find.byType(Checkbox).first);
    expect(find.text('0 to buy'), findsOneWidget);
    await app.close();
  });

  testWidgets('a multi-buy is shown with the single price and counts only once taken', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run(
      searcher: const FakeSearcher({
        'tesco': [
          Offer(shop: 'tesco', title: 'Heinz Beans 415g', pence: 140, deal: 'Any 2 for £2 Clubcard Price'),
        ],
        'asda': [Offer(shop: 'asda', title: 'Heinz Beans 415g', pence: 130)],
      }),
    );
    await app.tapText('New list');
    await app.tapText('Create');
    await app.enter('Add an item', '2 heinz beans');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();

    expect(find.text('Multi-buy deals: 1 to decide'), findsOneWidget);
    expect(find.text('Single purchase: £1.40 each'), findsOneWidget);
    expect(
      find.text(
        'Multi-buy deal: Any 2 for £2 Clubcard Price (£1.00 each). For your 2, buy 2 for £2.00 instead of £2.80.',
      ),
      findsOneWidget,
    );
    // Single prices until the user says yes.
    expect(
      find.text('Cheapest at Asda: £2.60 for all 1 item, 20p less than Tesco.', findRichText: true),
      findsOneWidget,
    );

    await app.tapText('Take deal');
    expect(find.text('Multi-buy deals'), findsOneWidget);
    expect(
      find.text('Cheapest at Tesco: £2.00 for all 1 item, 60p less than Asda.', findRichText: true),
      findsOneWidget,
    );

    await app.tapText('Single price');
    expect(
      find.text('Cheapest at Asda: £2.60 for all 1 item, 20p less than Tesco.', findRichText: true),
      findsOneWidget,
    );
    await app.close();
  });

  testWidgets('a shop that shows its bot check asks the user to answer it', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run(
      searcher: const FakeSearcher(
        {
          'asda': [Offer(shop: 'asda', title: 'Heinz Beans 415g', pence: 130)],
        },
        {'tesco'},
      ),
    );
    await app.tapText('New list');
    await app.tapText('Create');
    await app.enter('Add an item', 'heinz beans');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();

    expect(find.text('Tesco wants to check you are a person'), findsOneWidget);
    expect(find.text('Open Tesco'), findsOneWidget);
    expect(find.text('Asda'), findsWidgets);
    await app.close();
  });

  testWidgets('an item has its own page, and a search result can be added as one', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run(
      searcher: const FakeSearcher({
        'aldi': [Offer(shop: 'aldi', title: 'Lurpak Spreadable Butter 500g', pence: 450)],
      }),
    );
    await app.tapText('2 × semi-skimmed milk');
    expect(find.text('Dairy & eggs'), findsOneWidget);
    expect(find.text('Best, Aldi'), findsOneWidget);
    expect(find.text('Cowbelle Semi Skimmed Milk 4 Pints'), findsOneWidget);
    await app.tap(find.byTooltip('One more'));
    await app.tap(find.byType(BackButton));
    expect(find.text('3 × semi-skimmed milk'), findsOneWidget);

    await app.go('Compare');
    await app.enter('Product', 'butter');
    await app.tap(find.textContaining('Search 6 shops'));
    await app.tap(find.byTooltip('Add to list'));
    expect(find.text('Lurpak Spreadable Butter 500g'), findsOneWidget);
    expect(find.text('Dairy & eggs'), findsOneWidget);
    expect(find.text('Best, Aldi'), findsOneWidget);
    await app.close();
  });

  testWidgets('a watched item shows on the list when its price falls', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    expect(find.text('A price drop'), findsNothing);
    await app.tapText('2 × semi-skimmed milk');
    await app.tapText('Watch the price');
    expect(find.text('Watching the price'), findsOneWidget);
    expect(find.text('£1.39 at Aldi, down 10p from £1.49 on 18 Oct'), findsOneWidget);
    await app.tap(find.byType(BackButton));
    expect(find.text('A price drop'), findsOneWidget);
    expect(find.text('£1.39 at Aldi, down 10p from £1.49 on 18 Oct'), findsOneWidget);
    await app.close();
  });

  testWidgets('the list can be grouped by aisle, and bought items added again', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    expect(find.text('Fruit & veg'), findsNothing);
    await app.tap(find.byTooltip('Group by aisle'));
    for (final aisle in ['Fruit & veg', 'Bakery', 'Dairy & eggs', 'Household']) {
      expect(find.text(aisle), findsOneWidget, reason: aisle);
    }
    await app.tap(find.byTooltip('Show in the order added'));
    expect(find.text('Fruit & veg'), findsNothing);

    await app.tap(find.byTooltip('Item').first);
    await app.tapText('Delete');
    expect(find.text('Add again'), findsOneWidget);
    await app.tap(find.widgetWithText(ActionChip, 'semi-skimmed milk'));
    expect(find.text('Add again'), findsNothing);
    expect(find.text('semi-skimmed milk'), findsOneWidget);
    await app.close();
  });

  testWidgets('a budget is set for the list and the running total kept against it', (tester) async {
    final app = AppHarness(tester)..phone();
    await app.open(seed: seedBook);
    await app.run();
    expect(find.text('Running total'), findsOneWidget);
    expect(find.text('0p in the basket'), findsOneWidget);
    await app.tapText('Set a budget');
    await app.enter('Budget in £', '4');
    await app.tapText('Save');
    expect(find.text('Budget £4.00'), findsOneWidget);
    expect(find.text('The list is 18p over budget.'), findsOneWidget);

    await app.tap(find.byType(Checkbox).at(1));
    expect(find.text('£1.40 in the basket'), findsOneWidget);
    await app.tapText('Change');
    await app.enter('Budget in £', '');
    await app.tapText('Save');
    expect(find.text('Running total'), findsOneWidget);
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
