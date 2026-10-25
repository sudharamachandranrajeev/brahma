import 'package:anveshana/app/session.dart' as anveshana;
import 'package:anveshana/db/database.dart' as anveshana_db;
import 'package:anveshana/domain/listing.dart';
import 'package:anveshana/domain/pipeline.dart';
import 'package:artha/app/session.dart' as artha;
import 'package:artha/modules/finance/domain/accounting.dart';
import 'package:artha/modules/finance/domain/ledger.dart';
import 'package:brahma/app/session.dart';
import 'package:drift/drift.dart' show Value;
import 'package:udyoga/app/session.dart' as udyoga;
import 'package:vahana/app/session.dart' as vahana;
import 'package:vahana/db/database.dart' as vahana_db;
import 'package:vani/app/session.dart' as vani;
import 'package:vani/domain/hub.dart';
import 'package:vidya/app/session.dart' as vidya;

import '../../apps/udyoga/test/seed.dart' as udyoga_seed;
import '../../apps/vani/test/fake_hub.dart';
import '../../apps/vidya/test/seed.dart' as vidya_seed;

/// Fills every app in [suite] with made-up data dated around [today]
/// (yyyy-MM-dd), so the dashboard cards and the hosted apps have something
/// to show. No real people or accounts: names, places and companies are
/// invented. Vani reads its hub through [FakeHub]; give the root
/// ProviderScope its client.
Future<void> seedSuite(SuiteSession suite, String today) async {
  for (final s in [suite.hub, ...suite.sessions]) {
    // Tip banners would cover the content in the shots.
    await s.db.setLocalSetting('ui.hints', 'off');
    switch (s) {
      case artha.AppSession():
        await _artha(s.ledger, today);
      case anveshana.AppSession():
        await _anveshana(s, today);
      case vahana.AppSession():
        await _vahana(s, today);
      case udyoga.AppSession():
        await udyoga_seed.seedBook(s.book, today: today);
      case vidya.AppSession():
        await vidya_seed.seedBook(s.book, today: today);
      case vani.AppSession():
        await s.prefs.saveHub(const HubLink(url: hubUrl, token: hubToken));
    }
  }
}

String _day(String today, int ago) =>
    DateTime.parse('${today}T00:00:00Z').subtract(Duration(days: ago)).toIso8601String().substring(0, 10);

String _ahead(String today, int days) => _day(today, -days);

Future<void> _artha(Ledger ledger, String today) async {
  await ledger.setUp('GBP');
  final bank = await ledger.saveAccount(name: 'Everyday current', subtype: 'current', commodityId: 'GBP');
  final saver = await ledger.saveAccount(name: 'Rainy day saver', subtype: 'savings', commodityId: 'GBP');
  final isa = await ledger.saveAccount(name: 'Index fund ISA', subtype: 'isa_stocks', commodityId: 'GBP');
  final card = await ledger.saveAccount(name: 'Rewards card', subtype: 'credit_card', commodityId: 'GBP');
  final opening = _day(today, 90);
  for (final (account, pence) in [(bank, 245000), (saver, 1200000), (isa, 1865000), (card, -32000)]) {
    await ledger.saveEntry(
      simpleEntry(
        date: opening,
        currency: 'GBP',
        accountId: account,
        categoryId: openingBalancesId,
        amount: -pence,
        payee: 'Opening balance',
      ),
    );
  }
  // This month: pay in, then the usual spending.
  final month = '${today.substring(0, 8)}01';
  Future<void> spend(String date, String category, int pence, String payee, {String? from}) =>
      ledger.saveEntry(
        simpleEntry(
          date: date,
          currency: 'GBP',
          accountId: from ?? bank,
          categoryId: category,
          amount: pence,
          payee: payee,
        ),
      );
  await spend(month, 'cat.salary', -342000, 'Northwind Health payroll');
  await spend(month, 'cat.housing', 95000, 'Riverside Lettings');
  await spend(month, 'cat.utilities', 8400, 'Example Energy');
  await spend(month, 'cat.council_tax', 14200, 'City council');
  await spend(_day(today, 1), 'cat.groceries', 6240, 'Fresh Market', from: card);
  await spend(_day(today, 2), 'cat.eating_out', 2850, 'Corner Café', from: card);
  await spend(_day(today, 3), 'cat.transport', 4500, 'Metro rail');
  await spend(_day(today, 4), 'cat.subscriptions', 1099, 'Streamly');
}

Future<void> _anveshana(anveshana.AppSession s, String today) async {
  final book = s.book;
  Listing listing(String id, String address, int price, int beds, {bool rent = true}) => Listing(
    source: 'example',
    sourceId: id,
    url: 'https://listings.example.test/$id',
    address: address,
    price: price,
    priceSuffix: rent ? 'pm' : '',
    beds: beds,
    baths: 1,
    style: beds > 2 ? 'Semi-detached' : 'Apartment',
    status: rent ? 'toLet' : 'forSale',
    agent: 'Example Estates',
  );
  final a = await book.importListing(listing('1', '12 Willow Row, Sampletown SA1 2BC', 950, 3), today: today);
  final b = await book.importListing(
    listing('2', '4 Harbour Court, Sampletown SA2 4DE', 825, 2),
    today: today,
  );
  await book.importListing(listing('3', '27 Orchard Lane, Sampletown SA3 6FG', 1100, 3), today: today);
  await book.importListing(
    listing('4', '8 Mill View, Sampletown SA4 8HJ', 215000, 3, rent: false),
    kind: PropertyKind.buy,
    today: today,
  );
  await book.setStage(a.id, Stage.viewing);
  await book.setStage(b.id, Stage.shortlisted);
  await book.bookViewing(a.id, '${_ahead(today, 2)}T17:30');
  await book.bookViewing(b.id, '${_ahead(today, 5)}T11:00');
  // A flat already let out, with its certificates coming due.
  final owned = await book.importListing(
    listing('5', '3 Station Road, Sampletown SA5 1KL', 780, 2),
    kind: PropertyKind.owned,
    today: _day(today, 400),
  );
  for (final (kind, days) in [('gas', 12), ('alarms', 26), ('eicr', 300)]) {
    final id = 'seed-$kind';
    await book.save(
      s.db.complianceItems,
      anveshana_db.ComplianceItemsCompanion.insert(
        id: id,
        propertyId: owned.id,
        kind: kind,
        due: _ahead(today, days),
      ),
      id,
    );
  }
}

Future<void> _vahana(vahana.AppSession s, String today) async {
  Future<void> car(String id, vahana_db.VehiclesCompanion c) =>
      s.book.save(s.db.vehicles, c.copyWith(id: Value(id), added: Value(_day(today, 20))), id);
  await car(
    'seed-a',
    const vahana_db.VehiclesCompanion(
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
    'seed-b',
    const vahana_db.VehiclesCompanion(
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
    'seed-c',
    vahana_db.VehiclesCompanion(
      title: const Value('2017 Skoda Octavia Estate 1.6 TDI'),
      price: const Value(9400),
      year: const Value(2017),
      mileage: const Value(71000),
      fuel: const Value('Diesel'),
      stage: const Value('agreed'),
      boughtOn: Value(_day(today, 140)),
      motDue: Value(_ahead(today, 18)),
      taxDue: Value(_ahead(today, 220)),
      insuranceDue: Value(_ahead(today, 215)),
    ),
  );
}
