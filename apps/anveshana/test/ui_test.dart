import 'package:anveshana/db/database.dart';
import 'package:anveshana/domain/book.dart';
import 'package:anveshana/domain/listing.dart';
import 'package:anveshana/domain/pipeline.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';
import 'support.dart';

/// Smoke tests: every page builds, with and without data, on phone and
/// desktop widths, without throwing or overflowing; and the main flows.
void main() {
  Future<void> seed(PropertyBook book) async {
    await book.setHome((lat: 54.344, lon: -7.638, label: 'Work'));
    final id = (await book.importListing(
      parsePropertyPalPage(nextData({'property': samplePropertyPal()})).single,
      today: '2026-10-20',
    )).id;
    await book.log(propertyId: id, channel: 'email', summary: 'Sent the enquiry', at: '2026-10-20T09:00');
    await book.bookViewing(id, '2026-10-24T11:00');
    final owned = newId();
    await book.save(
      book.db.properties,
      PropertiesCompanion.insert(
        id: owned,
        address: '9 Example Row, BT74 1AB',
        kind: PropertyKind.owned.name,
        added: '2025-01-01',
      ),
      owned,
    );
    final t = newId();
    await book.save(
      book.db.tenancies,
      TenanciesCompanion.insert(
        id: t,
        propertyId: owned,
        role: 'landlord',
        start: '2026-01-01',
        rent: 700,
        otherParty: const Value('A Tenant'),
      ),
      t,
    );
    final c = newId();
    await book.save(
      book.db.complianceItems,
      ComplianceItemsCompanion.insert(id: c, propertyId: owned, kind: 'gas', due: '2026-11-01'),
      c,
    );
    final s = newId();
    await book.save(
      book.db.searches,
      SearchesCompanion.insert(
        id: s,
        name: 'Rent near work',
        path: '/property-to-rent/enniskillen',
        maxPrice: const Value(700),
      ),
      s,
    );
  }

  const pages = ['Searches', 'Invest', 'Research', 'Lettings', 'Contacts', 'Settings', 'Hunt'];

  testWidgets('every page builds on a desktop window, empty and with data', (tester) async {
    for (final seeded in [false, true]) {
      final app = AppHarness(tester)..desktop();
      await app.open(seed: seeded ? seed : null);
      await app.run();
      for (final label in pages) {
        await app.go(label);
        expect(tester.takeException(), isNull, reason: '$label (seeded: $seeded)');
      }
      await app.close();
    }
  });

  testWidgets('every page builds on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppHarness(tester);
    await app.open(seed: seed);
    await app.run();
    for (final label in pages) {
      final bar = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
      if (bar.evaluate().isNotEmpty) {
        await app.tap(bar);
      } else {
        await app.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
        await app.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(label)));
      }
      expect(tester.takeException(), isNull, reason: label);
    }
    // A property's page too.
    await app.tapText('Apt 1 Sample Street, Enniskillen, BT74 1AA');
    expect(find.text('Write an enquiry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('the hunt groups by stage and measures from the home point', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seed);
    await app.run();
    expect(find.text('Viewing (1)'), findsOneWidget);
    expect(find.textContaining('£650 pcm'), findsOneWidget);
    expect(find.text('0.5 km'), findsOneWidget);
    await app.close();
  });

  testWidgets('add a property by hand, move it on and log a call', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.tapText('Add');
    await app.tapText('Type it in');
    await app.enter('Address', '3 Lake Road, Enniskillen BT74 7AA');
    await app.enter('Rent a month', '600');
    await app.enter('Bedrooms', '2');
    await app.tapText('Save');
    expect(find.text('New (1)'), findsOneWidget);

    await app.tapText('3 Lake Road, Enniskillen BT74 7AA');
    await app.tap(find.widgetWithText(ChoiceChip, 'Shortlisted'));
    final p = (await tester.runAsync(() => app.session.db.select(app.session.db.properties).getSingle()))!;
    expect(p.stage, Stage.shortlisted.id);
    expect(p.postcode, 'BT74 7AA');
    expect(p.price, 600);

    await app.tap(find.widgetWithText(TextButton, 'Add').first);
    await app.enter('What was said', 'Landlord rang back; viewing Saturday');
    await app.tapText('Save');
    expect(find.text('Landlord rang back; viewing Saturday'), findsOneWidget);
    await app.close();
  });

  testWidgets('the enquiry carries the details from Settings', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seed);
    await app.run();
    await app.go('Settings');
    await app.tap(find.widgetWithText(TextButton, 'Edit').first);
    await app.enter('Name', 'A Tenant');
    await app.enter('Phone', '07700 900123');
    await app.enter('Move in', 'from January 2027');
    await app.tapText('Save');
    expect(find.textContaining('A Tenant'), findsOneWidget);

    await app.go('Hunt');
    await app.tapText('Apt 1 Sample Street, Enniskillen, BT74 1AA');
    await app.tapText('Write an enquiry');
    expect(find.textContaining('Hello Example Lettings,'), findsOneWidget);
    expect(find.textContaining('Could a tenancy start from January 2027?'), findsOneWidget);
    expect(find.textContaining('A Tenant\n07700 900123'), findsOneWidget);
    await app.close();
  });

  testWidgets('appraisals recalculate and save', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Invest');
    expect(find.text('Cash needed'), findsOneWidget);
    // Default buy-to-let in NI at £150,000 with the surcharge.
    expect(find.text('SDLT'), findsOneWidget);
    await app.enter('Price', '200000');
    // 2% of £75,000 plus the 5% surcharge on £200,000.
    expect(find.text('£11,500'), findsOneWidget);
    await app.tap(find.byIcon(Icons.bookmark_add_outlined));
    await app.enter('Name', 'Test flat');
    await app.tapText('Save');
    await app.tapText('Saved');
    expect(find.widgetWithText(ListTile, 'Test flat'), findsOneWidget);

    await app.tapText('Development');
    expect(find.text('Most to pay for the land'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a tenancy shows rent owed', (tester) async {
    final app = AppHarness(tester)..desktop();
    await app.open(seed: seed);
    await app.run();
    await app.go('Lettings');
    // Rent of £700 from 1 January with nothing recorded.
    expect(find.textContaining('owed'), findsOneWidget);
    expect(find.text('Gas safety certificate'), findsOneWidget);
    await app.close();
  });
}
