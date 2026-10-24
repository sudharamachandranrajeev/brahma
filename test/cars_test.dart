import 'dart:convert';

import 'package:vahana/domain/car_finance.dart';
import 'package:vahana/domain/car_sources.dart';
import 'package:vahana/domain/vehicles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String ldPage(Map<String, Object?> ld) =>
    '<html><head><meta property="og:title" content="OG title">'
    '<script type="application/ld+json">${jsonEncode(ld)}</script></head></html>';

void main() {
  group('advert pages', () {
    test('schema.org car data is read', () {
      final a = parseCarAdvert(
        ldPage({
          '@context': 'https://schema.org',
          '@type': ['Product', 'Car'],
          'name': '2016 Ford Focus 1.0 Zetec',
          'brand': {'@type': 'Brand', 'name': 'Ford'},
          'model': 'Focus',
          'vehicleModelDate': '2016',
          'mileageFromOdometer': {'value': 64000, 'unitCode': 'SMI'},
          'fuelType': 'Petrol',
          'offers': {
            '@type': 'Offer',
            'price': '4250',
            'seller': {'@type': 'AutoDealer', 'name': 'Sample Motors', 'telephone': '028 0000 0000'},
          },
        }),
        'https://www.usedcarsni.com/2016-ford-focus-1',
      );
      expect(a.title, '2016 Ford Focus 1.0 Zetec');
      expect(a.make, 'Ford');
      expect(a.year, 2016);
      expect(a.mileage, 64000);
      expect(a.price, 4250);
      expect(a.sellerType, 'dealer');
      expect(a.source, 'usedcarsni.com');
    });

    test('kilometres become miles; a private seller is a Person', () {
      final a = parseCarAdvert(
        ldPage({
          '@type': 'Car',
          'name': 'Sample',
          'mileageFromOdometer': {'value': 160934, 'unitCode': 'KMT'},
          'offers': [
            {
              'price': 3000,
              'seller': {'@type': 'Person'},
            },
          ],
        }),
        'https://example.com/x',
      );
      expect(a.mileage, closeTo(100000, 1));
      expect(a.sellerType, 'private');
    });

    test('Open Graph tags are the fallback, a bare page is refused', () {
      final a = parseCarAdvert(
        '<meta property="og:title" content="2018 Honda Civic &amp; more - £7,995">'
            '<meta property="og:image" content="https://example.com/i.jpg">',
        'https://example.com/y',
      );
      expect(a.title, '2018 Honda Civic & more - £7,995');
      expect(a.price, 7995);
      expect(a.year, 2018);
      expect(a.image, 'https://example.com/i.jpg');
      expect(() => parseCarAdvert('<html></html>', 'https://example.com/z'), throwsFormatException);
    });

    test('only https pages are fetched and Facebook is refused', () async {
      final client = MockClient((_) async => http.Response(ldPage({'@type': 'Car', 'name': 'X'}), 200));
      expect(
        (await fetchCarAdvert('https://example.com/a#top', client: client)).url,
        'https://example.com/a',
      );
      await expectLater(fetchCarAdvert('http://example.com/a', client: client), throwsFormatException);
      await expectLater(
        fetchCarAdvert('https://www.facebook.com/marketplace/item/1', client: client),
        throwsFormatException,
      );
    });
  });

  group('sources', () {
    const s = CarSearch(make: 'Ford', model: 'Focus', maxPrice: 10000, postcode: 'BT74 7HG', radius: 30);

    test('search links carry the filters', () {
      final by = {for (final c in carSources) c.id: c.url(s)};
      expect(by['autotrader']!.queryParameters, containsPair('postcode', 'BT747HG'));
      expect(by['autotrader']!.queryParameters, containsPair('price-to', '10000'));
      expect(by['gumtree']!.queryParameters, containsPair('vehicle_make', 'ford'));
      expect(by['usedcarsni']!.queryParameters, containsPair('make', '7'));
      expect(by['usedcarsni']!.queryParameters, containsPair('model', '908'));
      expect(by['donedeal']!.path, '/cars/Ford/Focus');
      expect(by['cinch']!.toString(), 'https://www.cinch.co.uk/used-cars/ford/focus?maxPrice=10000');
    });

    test('Northern Ireland sites lead for BT postcodes and are hidden elsewhere', () {
      expect(sourcesFor(s).first.onlyNi, isTrue);
      final gb = s.copyWith(postcode: 'M1 1AA');
      expect(sourcesFor(gb).any((c) => c.onlyNi), isFalse);
    });

    test('new cars see deal sites, not used-only ones', () {
      final ids = sourcesFor(s.copyWith(condition: 'new')).map((c) => c.id);
      expect(ids, containsAll(['carwow', 'leasing', 'autotrader']));
      expect(ids, isNot(contains('gumtree')));
    });

    test('a custom link is filled from the search and must be a web address', () {
      const c = CustomSource(name: 'x', link: 'https://example.com/s?q={query}&pc={postcode}&max={maxPrice}');
      expect(c.resolve(s).toString(), 'https://example.com/s?q=Ford%20Focus&pc=BT747HG&max=10000');
      expect(const CustomSource(name: 'x', link: 'javascript:alert(1)').resolve(s), isNull);
    });
  });

  group('finance', () {
    test('a payment pays the loan off', () {
      final m = payment(10000, monthlyRate(0.1), 48);
      var bal = 10000.0;
      for (var i = 0; i < 48; i++) {
        bal = bal * (1 + monthlyRate(0.1)) - m;
      }
      expect(bal, closeTo(0, 0.01));
      expect(payment(1200, 0, 12), 100);
    });

    test('PCP is cheaper monthly than HP but leaves a final payment', () {
      final r = {
        for (final x in comparePlans(const CarDeal(price: 15000, deposit: 1500, months: 48))) x.plan: x,
      };
      expect(r[Plan.pcp]!.monthly, lessThan(r[Plan.hp]!.monthly));
      expect(r[Plan.pcp]!.finalPayment, greaterThan(1000));
      expect(r[Plan.cash]!.interest, 0);
      expect(r[Plan.hp]!.interest, greaterThan(0));
      expect(r[Plan.loan]!.totalPaid, lessThan(r[Plan.hp]!.totalPaid));
      expect(r[Plan.lease]!.missing, isNotNull);
    });

    test('hand-back is possible once half is paid, and a lease owns nothing', () {
      final r = {
        for (final x in comparePlans(
          const CarDeal(price: 15000, deposit: 1500, months: 48, leaseMonthly: 250),
        ))
          x.plan: x,
      };
      final k = r[Plan.hp]!.terminationMonth!;
      expect(k, inInclusiveRange(1, 48));
      final paid = 1500 + r[Plan.hp]!.monthly * k;
      expect(paid, greaterThanOrEqualTo(r[Plan.hp]!.totalPaid / 2));
      expect(r[Plan.lease]!.ownedValue, 0);
      expect(r[Plan.lease]!.totalPaid, 250 * (6 + 47));
    });

    test('depreciation falls with age and a used car keeps more of its price', () {
      expect(retained(0), 1);
      expect(retained(1), closeTo(0.70, 0.001));
      expect(retained(3), inInclusiveRange(0.4, 0.6));
      expect(
        estimateValue(10000, age: 5, months: 24),
        greaterThan(estimateValue(10000, age: 0, months: 24) * 0.8),
      );
    });

    test('running costs: petrol by mpg, electric by miles per kWh', () {
      const petrol = Running(milesPerYear: 9000, economy: 45, energyPrice: 140, insurance: 0, servicing: 0);
      expect(petrol.energyPerYear, closeTo(9000 / 45 * 4.54609 * 1.4, 0.01));
      const ev = Running(
        milesPerYear: 9000,
        fuel: Fuel.electric,
        economy: 3.5,
        energyPrice: 28,
        insurance: 0,
        servicing: 0,
      );
      expect(ev.energyPerYear, closeTo(9000 / 3.5 * 0.28, 0.01));
      expect(Fuel.guess('Plug-in Hybrid'), Fuel.hybrid);
    });
  });
}
