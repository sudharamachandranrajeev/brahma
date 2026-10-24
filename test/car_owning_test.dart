import 'package:anveshana/db/database.dart';
import 'package:anveshana/domain/book.dart';
import 'package:anveshana/domain/car_buying.dart';
import 'package:anveshana/domain/car_owning.dart';
import 'package:anveshana/domain/tax.dart';
import 'package:anveshana/domain/pipeline.dart';
import 'package:anveshana/domain/vehicles.dart';
import 'package:drift/drift.dart' show Value;
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Vehicle car({
  String id = 'a',
  String title = '2018 Ford Focus',
  int? price,
  int? year,
  int? mileage,
  String sellerType = 'dealer',
  String? motDue,
  String? firstRegistered,
  String? boughtOn,
  String fuel = '',
  String meta = '{}',
}) => Vehicle(
  id: id,
  deleted: false,
  hlc: '',
  title: title,
  make: '',
  model: '',
  year: year,
  mileage: mileage,
  price: price,
  fuel: fuel,
  transmission: '',
  body: '',
  registration: '',
  condition: 'used',
  sellerType: sellerType,
  seller: '',
  sellerPhone: '',
  location: '',
  source: 'manual',
  url: '',
  stage: 'new',
  rating: 0,
  notes: '',
  added: '2026-01-01',
  motDue: motDue,
  firstRegistered: firstRegistered,
  boughtOn: boughtOn,
  meta: meta,
);

CarLog log(String kind, String date, {int? odo, int? pence, double? amount}) => CarLog(
  id: '$kind$date',
  deleted: false,
  hlc: '',
  vehicleId: 'a',
  date: date,
  kind: kind,
  odometer: odo,
  costPence: pence,
  amount: amount,
  provider: '',
  notes: '',
);

void main() {
  group('MOT dates', () {
    test('first MOT is 3 years on in Great Britain and 4 in Northern Ireland', () {
      expect(firstMotDue('2024-03-14', Nation.england), '2027-03-14');
      expect(firstMotDue('2024-03-14', Nation.northernIreland), '2028-03-14');
    });

    test('a test up to a month early keeps the date in GB, not in NI', () {
      expect(nextMotDue('2027-02-20', previousDue: '2027-03-14', nation: Nation.england), '2028-03-14');
      expect(nextMotDue('2027-02-13', previousDue: '2027-03-14', nation: Nation.england), '2028-02-13');
      expect(
        nextMotDue('2027-02-20', previousDue: '2027-03-14', nation: Nation.northernIreland),
        '2028-02-20',
      );
      expect(nextMotDue('2027-03-20', previousDue: '2027-03-14', nation: Nation.england), '2028-03-20');
    });
  });

  group('deadlines', () {
    test('sorted, with the first MOT worked out from registration', () {
      final v = car(firstRegistered: '2024-03-14');
      final d = deadlines(v, nation: Nation.northernIreland, today: '2028-03-01');
      expect(d.single.kind, DueKind.mot);
      expect(d.single.estimated, isTrue);
      expect(d.single.days, 13);
      expect(deadlines(car(motDue: '2026-10-01'), today: '2026-10-24').single.overdue, isTrue);
    });

    test('logging an MOT or a service moves the date; a renewal runs on from the old date', () {
      final v = car(motDue: '2027-03-14');
      expect(afterLog(v, LogKind.mot, '2027-03-01').motDue, '2028-03-14');
      expect(afterLog(v, LogKind.service, '2026-11-01').serviceDue, '2027-11-01');
      expect(
        afterLog(
          v.copyWith(insuranceDue: const Value('2026-11-10')),
          LogKind.insurance,
          '2026-10-20',
        ).insuranceDue,
        '2027-11-10',
      );
      expect(afterLog(v, LogKind.fuel, '2026-11-01'), v);
    });
  });

  group('buying', () {
    test('rights run from the purchase date by seller type', () {
      final d = car(boughtOn: '2026-10-01');
      expect(buyerRights(d, '2026-10-20').first, contains('reject'));
      expect(buyerRights(d, '2026-12-01').first, contains('presumed'));
      expect(buyerRights(d, '2027-06-01').single, contains('After six months'));
      expect(
        buyerRights(car(boughtOn: '2026-10-01', sellerType: 'private'), '2026-10-02').single,
        contains('Private sale'),
      );
    });

    test('price is read against similar saved cars; a bargain is flagged', () {
      final cars = [
        car(id: '1', price: 8000),
        car(id: '2', price: 8400),
        car(id: '3', price: 8200),
        car(id: '4', price: 5000, year: 2018, mileage: 15000),
      ];
      final p = fairPrice(cars.last, cars)!;
      expect(p.median, 8200);
      expect(p.diff, lessThan(-0.25));
      final flags = redFlags(cars.last, cars, thisYear: 2026);
      expect(flags.any((f) => f.contains('under the 3 similar')), isTrue);
      expect(flags.any((f) => f.contains('clocking')), isTrue);
      expect(fairPrice(cars.first, cars.sublist(0, 2)), isNull);
    });
  });

  group('logbook', () {
    test('costs, real economy, tyres and insurance change', () {
      final s = carStats([
        log('fuel', '2026-01-01', odo: 10000, pence: 6000, amount: 40),
        log('fuel', '2026-02-01', odo: 10450, pence: 6000, amount: 45.4609),
        log('insurance', '2025-10-01', pence: 50000),
        log('insurance', '2026-10-01', pence: 60000),
        log('tyres', '2026-05-01', amount: 2.5),
        log('valuation', '2026-06-01', pence: 700000),
      ], today: '2026-10-24');
      expect(s.spentTotal, 1220);
      expect(s.spentThisYear, 720);
      expect(s.mpg, closeTo(450 / 10, 0.01));
      expect(s.insuranceChange, closeTo(0.2, 1e-9));
      expect(s.tread, 2.5);
      expect(s.latestValue, 7000);
    });

    test('PCP pace projects the excess charge', () {
      const p = PcpAllowance(
        start: '2026-01-01',
        end: '2028-12-31',
        milesPerYear: 8000,
        startMiles: 10000,
        pencePerMile: 10,
      );
      final pace = p.pace(10000 + 6000, '2026-07-01');
      expect(pace.allowedTotal, closeTo(24000, 30));
      expect(pace.projected, greaterThan(pace.allowedTotal));
      expect(pace.excessCost, closeTo((pace.projected - pace.allowedTotal) * 0.1, 0.01));
    });

    test('service history lists services, repairs, MOTs and tyres only', () {
      final text = serviceHistory(car(), [
        log('service', '2026-03-01', odo: 40000),
        log('fuel', '2026-03-02'),
      ]);
      expect(text, contains('Service'));
      expect(text, isNot(contains('Fuel')));
    });
  });

  group('book', () {
    test('buying starts ownership; logs update the car; refreshing keeps a price history', () async {
      final book = PropertyBook(await Store.open(memoryDatabase()));
      const advert = CarAdvert(url: 'https://x.example/1', title: 'Focus', price: 8000, mileage: 50000);
      final id = (await book.importCar(advert, today: '2026-10-01')).id;
      await book.importCar(
        const CarAdvert(url: 'https://x.example/1', title: 'Focus', price: 7500, mileage: 50000),
        today: '2026-10-10',
      );
      var v = await (book.db.select(book.db.vehicles)..where((t) => t.id.equals(id))).getSingle();
      expect(priceHistory(v).map((p) => p.price), [8000, 7500]);

      await book.setVehicleStage(v, Stage.agreed, today: '2026-10-12');
      v = await (book.db.select(book.db.vehicles)..where((t) => t.id.equals(id))).getSingle();
      expect(v.boughtOn, '2026-10-12');

      await book.addCarLog(
        v,
        kind: LogKind.mot,
        date: '2026-10-13',
        odometer: 51000,
        costPence: 5485,
        nation: Nation.england,
      );
      v = await (book.db.select(book.db.vehicles)..where((t) => t.id.equals(id))).getSingle();
      expect(v.motDue, '2027-10-13');
      expect(v.mileage, 51000);

      await book.removeVehicle(id);
      expect(await book.db.select(book.db.carLogs).get().then((l) => l.where((x) => !x.deleted)), isEmpty);
      await book.db.close();
    });
  });
}
