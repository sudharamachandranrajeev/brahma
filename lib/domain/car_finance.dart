import 'dart:math' as math;

/// Ways to pay for a car, compared on the same figures.
enum Plan {
  cash('Cash', 'Pay in full. Cheapest overall when the money is not costing you more elsewhere.'),
  loan(
    'Personal loan',
    'Borrow from a bank, then buy as a cash buyer. You own the car from day one and can sell it any time.',
  ),
  hp(
    'Hire purchase (HP)',
    'Dealer finance secured on the car: deposit, equal monthly payments, then it is yours. The lender owns '
        'it until the last payment.',
  ),
  pcp(
    'Personal contract purchase (PCP)',
    'Lower monthly payments because a large final "balloon" (the guaranteed future value) is left to the end. '
        'Then pay it and keep the car, hand it back, or trade it in. Mileage limits and wear charges apply.',
  ),
  lease(
    'Personal lease (PCH)',
    'Long-term rental, usually of a new car: an initial payment of several months, then monthly rentals. '
        'You never own it; road tax is often included; mileage and wear limits apply.',
  );

  const Plan(this.label, this.about);
  final String label, about;
}

/// The figures for one car and one set of quotes. Money in pounds; rates
/// as fractions (0.099 is 9.9% APR).
class CarDeal {
  const CarDeal({
    required this.price,
    this.deposit = 0,
    this.months = 48,
    this.apr = 0.099,
    this.loanApr = 0.069,
    this.balloon = 0,
    this.fees = 0,
    this.optionFee = 10,
    this.endValue,
    this.age = 0,
    this.leaseMonthly = 0,
    this.leaseInitial = 6,
    this.leaseFee = 0,
  });

  final double price;

  /// Cash put down plus any part-exchange value.
  final double deposit;
  final int months;

  /// Dealer finance APR (HP and PCP), and a bank loan's.
  final double apr, loanApr;

  /// PCP's optional final payment (guaranteed minimum future value).
  final double balloon;

  /// Arrangement or documentation fees, paid up front; and HP/PCP's option
  /// to purchase fee, paid with the last payment.
  final double fees, optionFee;

  /// What the car is worth at the end of the term; estimated when null.
  final double? endValue;

  /// The car's age in years today (0 for new).
  final double age;

  /// A lease quote: the monthly rental, how many rentals the initial
  /// payment is, and the broker's fee.
  final double leaseMonthly;
  final int leaseInitial;
  final double leaseFee;

  double get valueAtEnd => endValue ?? estimateValue(price, age: age, months: months);

  /// A PCP balloon when none is given: roughly what the lender would
  /// guarantee, a little under the expected value.
  double get pcpBalloon => balloon > 0 ? balloon : (valueAtEnd * 0.9).roundToDouble();
}

/// One plan worked through.
class PlanResult {
  const PlanResult({
    required this.plan,
    required this.upfront,
    required this.monthly,
    required this.payments,
    this.finalPayment = 0,
    required this.totalPaid,
    required this.interest,
    required this.ownedValue,
    this.handBackCost,
    this.equity,
    this.terminationMonth,
    this.missing,
  });

  final Plan plan;

  /// Paid on day one (deposit, fees, a lease's initial rental).
  final double upfront;
  final double monthly;
  final int payments;

  /// A PCP balloon, or HP's option fee.
  final double finalPayment;

  /// Everything paid, keeping the car where the plan allows.
  final double totalPaid;

  /// Interest and fees: what it costs above the price.
  final double interest;

  /// What the car you hold at the end is worth (0 when leased).
  final double ownedValue;

  /// PCP: what handing it back instead of paying the balloon costs.
  final double? handBackCost;

  /// PCP: the car's value less the balloon at the end, to put towards the next one.
  final double? equity;

  /// HP and PCP: the payment after which you may hand the car back by law
  /// (voluntary termination, once half the total payable is paid). Null
  /// when only the final payment gets you there.
  final int? terminationMonth;

  /// Why the plan cannot be worked out (a lease without a quote).
  final String? missing;

  /// What the car really cost over the term: everything paid less what it is
  /// worth at the end. The fair figure to compare plans by.
  double get netCost => totalPaid - ownedValue;

  /// [netCost] spread over the months of the term.
  double netPerMonth(int months) => months <= 0 ? netCost : netCost / months;
}

/// The monthly rate for a UK APR, which is an annual equivalent rate.
double monthlyRate(double apr) => math.pow(1 + apr, 1 / 12) - 1;

/// The level payment that pays [principal] down to [balloon] over [n]
/// months at monthly rate [r].
double payment(double principal, double r, int n, {double balloon = 0}) {
  if (n <= 0) return 0;
  if (r == 0) return (principal - balloon) / n;
  return (principal - balloon / math.pow(1 + r, n)) * r / (1 - math.pow(1 + r, -n));
}

/// Works out each plan for [d].
List<PlanResult> comparePlans(CarDeal d) {
  final n = d.months;
  final borrowed = math.max(0.0, d.price - d.deposit);
  final value = d.valueAtEnd;

  final loanMonthly = payment(borrowed, monthlyRate(d.loanApr), n);
  final hpMonthly = payment(borrowed, monthlyRate(d.apr), n);
  final balloon = math.min(d.pcpBalloon, borrowed);
  final pcpMonthly = payment(borrowed, monthlyRate(d.apr), n, balloon: balloon);

  // Half of the total amount payable, deposit included, may be handed back
  // for (Consumer Credit Act 1974, s99-100).
  int? terminationMonth(double monthly, double last) {
    final total = d.deposit + d.fees + monthly * n + last;
    final need = total / 2 - d.deposit - d.fees;
    if (need <= 0) return 1;
    if (monthly <= 0) return null;
    final k = (need / monthly).ceil();
    return k <= n ? k : null;
  }

  final hpTotal = d.deposit + d.fees + hpMonthly * n + d.optionFee;
  final pcpTotal = d.deposit + d.fees + pcpMonthly * n + balloon + d.optionFee;
  final loanTotal = d.deposit + loanMonthly * n;
  final leaseTotal = d.leaseMonthly * (d.leaseInitial + n - 1) + d.leaseFee;

  return [
    PlanResult(
      plan: Plan.cash,
      upfront: d.price,
      monthly: 0,
      payments: 0,
      totalPaid: d.price,
      interest: 0,
      ownedValue: value,
    ),
    PlanResult(
      plan: Plan.loan,
      upfront: d.deposit,
      monthly: loanMonthly,
      payments: n,
      totalPaid: loanTotal,
      interest: loanTotal - d.price,
      ownedValue: value,
    ),
    PlanResult(
      plan: Plan.hp,
      upfront: d.deposit + d.fees,
      monthly: hpMonthly,
      payments: n,
      finalPayment: d.optionFee,
      totalPaid: hpTotal,
      interest: hpTotal - d.price,
      ownedValue: value,
      terminationMonth: terminationMonth(hpMonthly, d.optionFee),
    ),
    PlanResult(
      plan: Plan.pcp,
      upfront: d.deposit + d.fees,
      monthly: pcpMonthly,
      payments: n,
      finalPayment: balloon + d.optionFee,
      totalPaid: pcpTotal,
      interest: pcpTotal - d.price,
      ownedValue: value,
      handBackCost: d.deposit + d.fees + pcpMonthly * n,
      equity: value - balloon,
      terminationMonth: terminationMonth(pcpMonthly, balloon + d.optionFee),
    ),
    PlanResult(
      plan: Plan.lease,
      upfront: d.leaseMonthly * d.leaseInitial + d.leaseFee,
      monthly: d.leaseMonthly,
      payments: n - 1,
      totalPaid: leaseTotal,
      interest: 0,
      ownedValue: 0,
      missing: d.leaseMonthly <= 0 ? 'Enter a lease quote\'s monthly rental to compare leasing.' : null,
    ),
  ];
}

/// Share of its value a car loses in each year of age: about 30% in the
/// first, 15% in the second, 12% in the third, then 10% a year. A rule of
/// thumb; make, mileage and condition move it a lot.
const _yearlyLoss = [0.30, 0.15, 0.12];
const _laterLoss = 0.10;

/// The share of its new price a car keeps at [ageYears].
double retained(double ageYears) {
  var v = 1.0;
  var a = math.max(0.0, ageYears);
  for (var year = 0; a > 0; year++) {
    final loss = year < _yearlyLoss.length ? _yearlyLoss[year] : _laterLoss;
    final part = math.min(1.0, a);
    v *= math.pow(1 - loss, part);
    a -= part;
  }
  return v;
}

/// What a car bought for [price] at [age] years old is likely worth after
/// [months] more.
double estimateValue(double price, {double age = 0, required int months}) =>
    (price * retained(age + months / 12) / retained(age)).roundToDouble();

// Running costs ------------------------------------------------------------

enum Fuel {
  petrol('Petrol'),
  diesel('Diesel'),
  hybrid('Hybrid'),
  electric('Electric');

  const Fuel(this.label);
  final String label;

  /// The economy figure's unit, and the energy price's.
  String get economyUnit => this == electric ? 'miles/kWh' : 'mpg';
  String get priceUnit => this == electric ? 'p/kWh' : 'p/litre';

  static Fuel guess(String text) {
    final t = text.toLowerCase();
    if (t.contains('electric') && !t.contains('hybrid')) return electric;
    if (t.contains('hybrid')) return hybrid;
    if (t.contains('diesel')) return diesel;
    return petrol;
  }
}

const litresPerGallon = 4.54609;

/// A year's running costs. Money in pounds; energy in pence.
class Running {
  const Running({
    this.milesPerYear = 8000,
    this.fuel = Fuel.petrol,
    this.economy = 45,
    this.energyPrice = 135,
    this.insurance = 600,
    this.tax = 0,
    this.servicing = 350,
    this.other = 0,
  });

  final double milesPerYear;
  final Fuel fuel;

  /// mpg (UK gallons), or miles per kWh for an electric car.
  final double economy;

  /// Pence per litre, or per kWh.
  final double energyPrice;
  final double insurance, tax, servicing, other;

  double get energyPerYear {
    if (economy <= 0) return 0;
    final units = fuel == Fuel.electric ? milesPerYear / economy : milesPerYear / economy * litresPerGallon;
    return units * energyPrice / 100;
  }

  double get perYear => energyPerYear + insurance + tax + servicing + other;
  double get perMonth => perYear / 12;
  double get perMile => milesPerYear <= 0 ? 0 : perYear / milesPerYear;
}
