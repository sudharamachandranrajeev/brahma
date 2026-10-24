import 'dart:math' as math;

/// Where in the UK a property is. Each nation has its own purchase tax:
/// SDLT in England and Northern Ireland, LBTT in Scotland, LTT in Wales.
enum Nation {
  england('England'),
  northernIreland('Northern Ireland'),
  scotland('Scotland'),
  wales('Wales');

  const Nation(this.label);
  final String label;

  String get taxName => switch (this) {
    england || northernIreland => 'Stamp Duty Land Tax',
    scotland => 'Land and Buildings Transaction Tax',
    wales => 'Land Transaction Tax',
  };

  /// From a postcodes.io `country`, or a postcode's area (BT = Northern Ireland).
  static Nation? fromCountry(String? country) => switch (country) {
    'England' => england,
    'Northern Ireland' => northernIreland,
    'Scotland' => scotland,
    'Wales' => wales,
    _ => null,
  };
}

/// Who is buying, as the purchase taxes see it.
enum BuyerType {
  firstTime('First-time buyer'),
  mover('Home mover (replacing a main home)'),
  additional('Additional property (buy-to-let, second home)');

  const BuyerType(this.label);
  final String label;
}

/// A rate on the slice of the price up to [upTo] (null: no upper limit).
typedef Band = ({double? upTo, double rate});

/// Rates as of the tax-rates date below; the guide page lists them.
const ratesAsOf = 'October 2026';

// SDLT residential (England and Northern Ireland), from 1 April 2025.
const _sdlt = <Band>[
  (upTo: 125000, rate: 0),
  (upTo: 250000, rate: .02),
  (upTo: 925000, rate: .05),
  (upTo: 1500000, rate: .10),
  (upTo: null, rate: .12),
];
// First-time buyers: price up to £500,000.
const _sdltFirstTime = <Band>[(upTo: 300000, rate: 0), (upTo: 500000, rate: .05)];
const _sdltFirstTimeMax = 500000;
// Higher rates for additional dwellings: 5 points on every band, from 31 Oct 2024.
const _sdltSurcharge = .05;
// Buyers not resident in the UK: 2 points (England and Northern Ireland).
const _sdltNonResident = .02;

// LBTT residential (Scotland), from 1 April 2021.
const _lbtt = <Band>[
  (upTo: 145000, rate: 0),
  (upTo: 250000, rate: .02),
  (upTo: 325000, rate: .05),
  (upTo: 750000, rate: .10),
  (upTo: null, rate: .12),
];
// First-time buyer relief raises the nil band to £175,000.
const _lbttFirstTime = <Band>[
  (upTo: 175000, rate: 0),
  (upTo: 250000, rate: .02),
  (upTo: 325000, rate: .05),
  (upTo: 750000, rate: .10),
  (upTo: null, rate: .12),
];
// Additional Dwelling Supplement: 8% of the whole price, from 5 Dec 2024.
const _lbttAds = .08;

// LTT main residential rates (Wales), from 10 October 2022.
const _ltt = <Band>[
  (upTo: 225000, rate: 0),
  (upTo: 400000, rate: .06),
  (upTo: 750000, rate: .075),
  (upTo: 1500000, rate: .10),
  (upTo: null, rate: .12),
];
// LTT higher residential rates, from 11 December 2024.
const _lttHigher = <Band>[
  (upTo: 180000, rate: .05),
  (upTo: 250000, rate: .085),
  (upTo: 400000, rate: .10),
  (upTo: 750000, rate: .125),
  (upTo: 1500000, rate: .15),
  (upTo: null, rate: .17),
];

// Non-residential and mixed use (land for development).
const _sdltNonResidential = <Band>[
  (upTo: 150000, rate: 0),
  (upTo: 250000, rate: .02),
  (upTo: null, rate: .05),
];
const _lbttNonResidential = <Band>[
  (upTo: 150000, rate: 0),
  (upTo: 250000, rate: .01),
  (upTo: null, rate: .05),
];
const _lttNonResidential = <Band>[
  (upTo: 225000, rate: 0),
  (upTo: 250000, rate: .01),
  (upTo: 1000000, rate: .05),
  (upTo: null, rate: .06),
];

/// Below this price the additional-property surcharges do not apply.
const _surchargeFloor = 40000;

/// One slice of the price and the tax on it.
typedef Slice = ({double from, double to, double rate, double tax});

class PurchaseTax {
  const PurchaseTax(this.name, this.slices, {this.extra = 0, this.extraLabel = '', this.note = ''});
  final String name;
  final List<Slice> slices;

  /// A charge on the whole price outside the bands (Scotland's ADS).
  final double extra;
  final String extraLabel;
  final String note;

  /// Rounded down to the pound, as the tax authorities do.
  double get total => slices.fold(extra, (t, s) => t + s.tax).floorToDouble();
}

List<Slice> _apply(double price, List<Band> bands, {double add = 0}) {
  final out = <Slice>[];
  var from = 0.0;
  for (final b in bands) {
    if (price <= from) break;
    final to = b.upTo == null ? price : math.min(price, b.upTo!);
    final rate = b.rate + add;
    out.add((from: from, to: to, rate: rate, tax: (to - from) * rate));
    from = to;
  }
  return out;
}

/// The tax on buying a home at [price].
PurchaseTax residentialTax(double price, Nation nation, BuyerType buyer, {bool nonResident = false}) {
  final additional = buyer == BuyerType.additional && price >= _surchargeFloor;
  switch (nation) {
    case Nation.england || Nation.northernIreland:
      final add = (additional ? _sdltSurcharge : 0.0) + (nonResident ? _sdltNonResident : 0.0);
      if (buyer == BuyerType.firstTime && price <= _sdltFirstTimeMax) {
        return PurchaseTax('SDLT', _apply(price, _sdltFirstTime, add: add), note: 'First-time buyer relief');
      }
      return PurchaseTax(
        'SDLT',
        _apply(price, _sdlt, add: add),
        note: [
          if (buyer == BuyerType.firstTime) 'Over £500,000: no first-time buyer relief',
          if (additional) 'Includes the 5% additional-property surcharge',
          if (nonResident) 'Includes the 2% non-resident surcharge',
        ].join('. '),
      );
    case Nation.scotland:
      return PurchaseTax(
        'LBTT',
        _apply(price, buyer == BuyerType.firstTime ? _lbttFirstTime : _lbtt),
        extra: additional ? price * _lbttAds : 0,
        extraLabel: additional ? 'Additional Dwelling Supplement (8%)' : '',
        note: buyer == BuyerType.firstTime ? 'First-time buyer relief' : '',
      );
    case Nation.wales:
      return PurchaseTax(
        'LTT',
        _apply(price, additional ? _lttHigher : _ltt),
        note: additional ? 'Higher residential rates' : '',
      );
  }
}

/// The tax on buying land or commercial property (a development site).
PurchaseTax nonResidentialTax(double price, Nation nation) => switch (nation) {
  Nation.england || Nation.northernIreland => PurchaseTax('SDLT', _apply(price, _sdltNonResidential)),
  Nation.scotland => PurchaseTax('LBTT', _apply(price, _lbttNonResidential)),
  Nation.wales => PurchaseTax('LTT', _apply(price, _lttNonResidential)),
};

/// How rental profit is taxed.
enum Ownership {
  personal('In my name'),
  company('Limited company');

  const Ownership(this.label);
  final String label;
}

/// Property income rates from 6 April 2027 (Finance Act 2026), England,
/// Wales and Northern Ireland: two points above the main rates. Scotland
/// sets its own.
const propertyIncomeRates = {'Basic 22%': .22, 'Higher 42%': .42, 'Additional 47%': .47};

/// Mortgage interest is not deducted from a landlord's rental profit; it
/// earns a credit at the property basic rate (22% from April 2027).
const financeCreditRate = .22;

/// Income tax on a year's rental profit held personally ("Section 24").
/// [profit] is before finance costs; [finance] is the mortgage interest.
/// A credit larger than the tax is carried forward, not paid out.
double personalRentalTax(
  double profit,
  double finance, {
  required double rate,
  double creditRate = financeCreditRate,
}) {
  if (profit <= 0) return 0;
  final tax = profit * rate;
  final credit = math.min(finance, profit) * creditRate;
  return math.max(0, tax - credit);
}

/// Corporation tax on a company's profit after interest: 19% up to
/// £50,000, 25% from £250,000, marginal relief between.
double corporationTax(double profit) {
  if (profit <= 0) return 0;
  if (profit <= 50000) return profit * .19;
  if (profit >= 250000) return profit * .25;
  return profit * .25 - (250000 - profit) * 3 / 200;
}
