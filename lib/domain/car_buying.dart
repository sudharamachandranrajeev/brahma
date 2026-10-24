import 'dart:convert';

import '../db/database.dart';
import 'car_finance.dart';

typedef CheckItem = ({String id, String title, String body});

/// A list of things to tick off for a car, kept in its meta under [id].
class Checklist {
  const Checklist(this.id, this.title, this.items, {this.forOwned = false});
  final String id, title;
  final List<CheckItem> items;

  /// Shown once the car is bought (or being sold), not while looking.
  final bool forOwned;

  Set<String> done(Vehicle v) => {
    for (final x in ((jsonDecode(v.meta) as Map)[id] as List? ?? const [])) '$x',
  };
}

/// Before paying: the faults, finance, clocking and scams buyers report most.
const buyChecks = Checklist('checks', 'Before you pay', [
  (
    id: 'history',
    title: 'History check',
    body:
        'Finance owing (about 1 in 3 cars checked), stolen, written off, plate changes, mileage records '
        '(HPI, Experian, RAC). A car with finance on it can be taken back from you.',
  ),
  (
    id: 'mot',
    title: 'MOT history',
    body:
        'Free on GOV.UK: failures, advisories and the mileage at each test. Gaps or drops suggest clocking. '
        'Northern Ireland records can be in km.',
  ),
  (
    id: 'recall',
    title: 'Recalls',
    body: 'Free on GOV.UK. Open recalls are fixed free by a franchised dealer.',
  ),
  (
    id: 'v5c',
    title: 'V5C logbook and identity',
    body:
        'Seller\'s name and address match the V5C and their ID, and you meet at that address. The VIN on the '
        'car, colour and engine size match the V5C and the free GOV.UK vehicle check (cloned cars).',
  ),
  (
    id: 'service',
    title: 'Service history',
    body: 'Stamped book or invoices; cambelt and big jobs done on time.',
  ),
  (
    id: 'drive',
    title: 'Test drive',
    body: 'Cold start, brakes, steering, clutch, warning lights, noises, all electrics.',
  ),
  (
    id: 'inspect',
    title: 'Independent inspection',
    body:
        'AA, RAC or a trusted garage for anything of value. Electric: ask for a battery health (SoH) report.',
  ),
  (
    id: 'insurance',
    title: 'Insurance quote',
    body: 'Quote this exact car first: it can change what you can afford.',
  ),
  (
    id: 'price',
    title: 'The full price in writing',
    body: 'Dealer admin fees run £75–500 and add-ons (GAP, paint protection) are optional and often cheaper elsewhere.',
  ),
  (
    id: 'payment',
    title: 'Safe payment',
    body:
        'Never pay a deposit for a car you have not seen. Pay by bank transfer at handover or part by credit card '
        '(Section 75 from £100). No "escrow" or courier services.',
  ),
]);

/// Collecting the car: what lets you drive it home legally.
const collectChecks = Checklist('collect', 'Collection day', [
  (
    id: 'insure',
    title: 'Insured from today',
    body: 'Arrange cover before driving away (dealers may give drive-away cover).',
  ),
  (
    id: 'tax',
    title: 'Taxed in your name',
    body: 'Tax does not pass with the car. Tax it online with the 12-digit reference on the V5C/2 new keeper slip.',
  ),
  (
    id: 'v5c2',
    title: 'New keeper slip (V5C/2)',
    body: 'Keep it; the seller tells DVLA. The new V5C comes in about 5 days.',
  ),
  (
    id: 'receipt',
    title: 'Receipt and advert',
    body: 'Date, price, both names, reg and VIN. Save the advert: it is what was promised.',
  ),
  (
    id: 'keys',
    title: 'Keys, book pack and locking wheel nut',
    body: 'All keys you were told of, the manuals and service book.',
  ),
], forOwned: true);

/// Selling: the scams and paperwork sellers report.
const sellChecks = Checklist('sell', 'Selling safely', [
  (
    id: 'value',
    title: 'Know its value',
    body: 'Log several offers. Instant-buyer sites often cut the online price at inspection; a private sale usually pays more.',
  ),
  (
    id: 'finance',
    title: 'Settle any finance',
    body: 'Get the settlement figure from the lender; the buyer\'s check will show it.',
  ),
  (
    id: 'viewing',
    title: 'Viewings',
    body:
        'Two of you present. Check the driver\'s licence and insurance before a test drive, go with them, and keep '
        'the keys between drives. Watch for anyone tampering under the bonnet to talk the price down.',
  ),
  (
    id: 'paid',
    title: 'Money cleared first',
    body:
        'Keep the car, keys and V5C until the money shows as cleared in your own bank app. No screenshots, '
        'drafts or overpayments.',
  ),
  (
    id: 'dvla',
    title: 'Tell DVLA the same day',
    body: 'Online (gov.uk/sold-bought-vehicle) and give the buyer the V5C/2. Until you do, fines come to you (up to £1,000).',
  ),
  (
    id: 'after',
    title: 'Tax and insurance',
    body:
        'Tax refund for full months comes automatically and the direct debit stops; DVLA never texts about refunds. '
        'Cancel or move the insurance; take off a private plate first.',
  ),
], forOwned: true);

const checklists = [buyChecks, collectChecks, sellChecks];

/// Whether [a] and [b] are the same make and model, by fields or title.
bool sameModel(Vehicle a, Vehicle b) {
  String key(Vehicle v) => v.make.isNotEmpty && v.model.isNotEmpty
      ? '${v.make} ${v.model}'.toLowerCase()
      : v.title
            .toLowerCase()
            .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .join(' ');
  return key(a) == key(b) && key(a).isNotEmpty;
}

/// How an advert's price sits against similar cars you have saved.
class PriceView {
  const PriceView({required this.median, required this.count, required this.diff});
  final int median, count;

  /// Above (+) or below (-) the median, as a fraction.
  final double diff;
}

PriceView? fairPrice(Vehicle v, List<Vehicle> all) {
  if (v.price == null) return null;
  final peers = [
    for (final o in all)
      if (o.id != v.id && o.price != null && sameModel(o, v)) o.price!,
  ]..sort();
  if (peers.length < 2) return null;
  final mid = peers.length.isOdd
      ? peers[peers.length ~/ 2]
      : ((peers[peers.length ~/ 2 - 1] + peers[peers.length ~/ 2]) / 2).round();
  return PriceView(median: mid, count: peers.length, diff: v.price! / mid - 1);
}

/// Earlier prices of an advert, oldest first (from refreshing its link).
List<({String date, int price})> priceHistory(Vehicle v) => [
  for (final p in ((jsonDecode(v.meta) as Map)['prices'] as List? ?? const []))
    if (p is Map) (date: '${p['date']}', price: (p['price'] as num).round()),
];

/// Warnings worth raising before going further with [v].
List<String> redFlags(Vehicle v, List<Vehicle> all, {required int thisYear}) {
  final price = fairPrice(v, all);
  final age = v.year == null ? null : (thisYear - v.year!).clamp(1, 60);
  final perYear = age == null || v.mileage == null ? null : v.mileage! / age;
  return [
    if (price != null && price.diff <= -0.25)
      'Priced ${(-price.diff * 100).round()}% under the ${price.count} similar cars you saved. Cheap cars are '
          'the usual bait in deposit scams: see it in person before paying anything, and ask why.',
    if (perYear != null && v.condition == 'used' && perYear < 2500 && age! >= 4)
      'Only about ${perYear.round()} miles a year: check the MOT mileage record for clocking.',
    if (perYear != null && perYear > 20000)
      'About ${perYear.round()} miles a year: heavy use; check the service history closely.',
    if (v.sellerType == 'private' && v.sellerPhone.isEmpty)
      'Private seller with no phone number: insist on a call and meet at the address on the V5C.',
    if (v.condition == 'used' && Fuel.guess(v.fuel) == Fuel.electric)
      'Used electric car: ask for a battery health (SoH) report; few adverts show one.',
    if (v.registration.isEmpty && v.condition == 'used')
      'No registration yet: ask for it to run the free MOT, tax and recall checks.',
  ];
}
