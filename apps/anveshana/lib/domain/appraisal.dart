import 'dart:math' as math;

import 'tax.dart';

// Appraisals are plans, not bookkeeping: amounts are pounds as doubles and
// shown rounded. Inputs are kept as JSON so new fields never need a schema
// change; each reader falls back to a default.

double _d(Map<String, Object?> j, String k, double fallback) => switch (j[k]) {
  num v => v.toDouble(),
  _ => fallback,
};

bool _b(Map<String, Object?> j, String k, bool fallback) => switch (j[k]) {
  bool v => v,
  _ => fallback,
};

T _e<T extends Enum>(Map<String, Object?> j, String k, List<T> values, T fallback) =>
    values.where((v) => v.name == j[k]).firstOrNull ?? fallback;

/// Monthly payment on a repayment mortgage.
double repaymentPayment(double loan, double annualRate, int years) {
  if (loan <= 0) return 0;
  final n = years * 12;
  final r = annualRate / 12;
  if (r == 0) return loan / n;
  return loan * r / (1 - math.pow(1 + r, -n));
}

/// What is still owed after [months] of payments on a repayment mortgage.
double balanceAfter(double loan, double annualRate, int years, int months) {
  final r = annualRate / 12;
  final pay = repaymentPayment(loan, annualRate, years);
  if (r == 0) return math.max(0, loan - pay * months);
  final g = math.pow(1 + r, months);
  return math.max(0, loan * g - pay * (g - 1) / r);
}

/// Shared mortgage inputs.
class Mortgage {
  const Mortgage({
    this.depositPct = .25,
    this.rate = .05,
    this.years = 25,
    this.interestOnly = true,
    this.fee = 999,
  });
  final double depositPct;
  final double rate;
  final int years;
  final bool interestOnly;

  /// Arrangement fee, paid up front.
  final double fee;

  factory Mortgage.fromJson(Map<String, Object?> j, {bool interestOnly = true, double depositPct = .25}) =>
      Mortgage(
        depositPct: _d(j, 'depositPct', depositPct),
        rate: _d(j, 'rate', .05),
        years: _d(j, 'years', 25).round(),
        interestOnly: _b(j, 'interestOnly', interestOnly),
        fee: _d(j, 'fee', 999),
      );

  Map<String, Object?> toJson() => {
    'depositPct': depositPct,
    'rate': rate,
    'years': years,
    'interestOnly': interestOnly,
    'fee': fee,
  };

  double monthly(double loan) => interestOnly ? loan * rate / 12 : repaymentPayment(loan, rate, years);
  double balance(double loan, int months) => interestOnly ? loan : balanceAfter(loan, rate, years, months);

  /// Interest paid over the first year.
  double firstYearInterest(double loan) =>
      interestOnly ? loan * rate : monthly(loan) * 12 - (loan - balanceAfter(loan, rate, years, 12));
}

/// A buy-to-let purchase.
class BtlInput {
  const BtlInput({
    this.price = 150000,
    this.nation = Nation.northernIreland,
    this.buyer = BuyerType.additional,
    this.nonResident = false,
    this.mortgage = const Mortgage(),
    this.legal = 1500,
    this.survey = 500,
    this.refurb = 0,
    this.rent = 850,
    this.voidWeeks = 2,
    this.agentPct = .12,
    this.maintenancePct = .08,
    this.insurance = 350,
    this.serviceCharge = 0,
    this.otherCosts = 300,
    this.ownership = Ownership.personal,
    this.taxRate = .22,
    this.icr = 1.25,
    this.stressRate = .055,
    this.growth = .03,
    this.years = 10,
  });

  final double price;
  final Nation nation;
  final BuyerType buyer;
  final bool nonResident;
  final Mortgage mortgage;
  final double legal, survey, refurb;

  /// Monthly rent.
  final double rent;
  final double voidWeeks;

  /// Letting and management fee, share of rent collected (incl. VAT).
  final double agentPct;
  final double maintenancePct;

  /// Yearly: landlord insurance, service charge and ground rent, other
  /// (safety certificates, licensing, accountant).
  final double insurance, serviceCharge, otherCosts;
  final Ownership ownership;

  /// Marginal property income rate when held personally.
  final double taxRate;

  /// Lender's interest cover ratio and the rate it tests at.
  final double icr, stressRate;

  /// Yearly price growth and the years to project.
  final double growth;
  final int years;

  factory BtlInput.fromJson(Map<String, Object?> j) => BtlInput(
    price: _d(j, 'price', 150000),
    nation: _e(j, 'nation', Nation.values, Nation.northernIreland),
    buyer: _e(j, 'buyer', BuyerType.values, BuyerType.additional),
    nonResident: _b(j, 'nonResident', false),
    mortgage: Mortgage.fromJson((j['mortgage'] as Map?)?.cast() ?? const {}),
    legal: _d(j, 'legal', 1500),
    survey: _d(j, 'survey', 500),
    refurb: _d(j, 'refurb', 0),
    rent: _d(j, 'rent', 850),
    voidWeeks: _d(j, 'voidWeeks', 2),
    agentPct: _d(j, 'agentPct', .12),
    maintenancePct: _d(j, 'maintenancePct', .08),
    insurance: _d(j, 'insurance', 350),
    serviceCharge: _d(j, 'serviceCharge', 0),
    otherCosts: _d(j, 'otherCosts', 300),
    ownership: _e(j, 'ownership', Ownership.values, Ownership.personal),
    taxRate: _d(j, 'taxRate', .22),
    icr: _d(j, 'icr', 1.25),
    stressRate: _d(j, 'stressRate', .055),
    growth: _d(j, 'growth', .03),
    years: _d(j, 'years', 10).round(),
  );

  Map<String, Object?> toJson() => {
    'price': price,
    'nation': nation.name,
    'buyer': buyer.name,
    'nonResident': nonResident,
    'mortgage': mortgage.toJson(),
    'legal': legal,
    'survey': survey,
    'refurb': refurb,
    'rent': rent,
    'voidWeeks': voidWeeks,
    'agentPct': agentPct,
    'maintenancePct': maintenancePct,
    'insurance': insurance,
    'serviceCharge': serviceCharge,
    'otherCosts': otherCosts,
    'ownership': ownership.name,
    'taxRate': taxRate,
    'icr': icr,
    'stressRate': stressRate,
    'growth': growth,
    'years': years,
  };
}

class BtlResult {
  BtlResult._({
    required this.purchaseTax,
    required this.loan,
    required this.cashIn,
    required this.rentCollected,
    required this.runningCosts,
    required this.mortgagePayments,
    required this.interest,
    required this.tax,
    required this.grossYield,
    required this.netYield,
    required this.maxLoanByIcr,
    required this.breakEvenRent,
    required this.futureValue,
    required this.futureEquity,
  });

  final PurchaseTax purchaseTax;
  final double loan;

  /// Deposit, purchase tax, fees and works: the cash the deal needs.
  final double cashIn;

  /// A year's rent after voids, and costs other than the mortgage.
  final double rentCollected, runningCosts;
  final double mortgagePayments, interest, tax;
  final double grossYield, netYield;

  /// The largest loan the lender's stress test allows at this rent.
  final double maxLoanByIcr;

  /// Monthly rent at which the cash flow before tax is zero.
  final double breakEvenRent;
  final double futureValue, futureEquity;

  double get cashFlowBeforeTax => rentCollected - runningCosts - mortgagePayments;
  double get cashFlow => cashFlowBeforeTax - tax;
  double get monthlyCashFlow => cashFlow / 12;

  /// Yearly cash flow after tax over the cash put in.
  double get cashOnCash => cashIn <= 0 ? 0 : cashFlow / cashIn;
  bool get passesStressTest => loan <= maxLoanByIcr;
}

BtlResult appraiseBtl(BtlInput i) {
  final purchaseTax = residentialTax(i.price, i.nation, i.buyer, nonResident: i.nonResident);
  final loan = i.price * (1 - i.mortgage.depositPct);
  final cashIn = i.price - loan + purchaseTax.total + i.mortgage.fee + i.legal + i.survey + i.refurb;
  final fullRent = i.rent * 12;
  final collected = fullRent * (1 - i.voidWeeks / 52);
  final running = collected * (i.agentPct + i.maintenancePct) + i.insurance + i.serviceCharge + i.otherCosts;
  final payments = i.mortgage.monthly(loan) * 12;
  final interest = i.mortgage.firstYearInterest(loan);
  final profit = collected - running;
  final tax = switch (i.ownership) {
    Ownership.personal => personalRentalTax(profit, interest, rate: i.taxRate),
    Ownership.company => corporationTax(profit - interest),
  };
  // Rent at which collected rent covers running costs and payments:
  // r * 12 * k * (1 - fees) = fixed + payments.
  final k = 1 - i.voidWeeks / 52;
  final variable = 12 * k * (1 - i.agentPct - i.maintenancePct);
  final fixed = i.insurance + i.serviceCharge + i.otherCosts + payments;
  final futureValue = i.price * math.pow(1 + i.growth, i.years);
  return BtlResult._(
    purchaseTax: purchaseTax,
    loan: loan,
    cashIn: cashIn,
    rentCollected: collected,
    runningCosts: running,
    mortgagePayments: payments,
    interest: interest,
    tax: tax,
    grossYield: i.price <= 0 ? 0 : fullRent / i.price,
    netYield: i.price <= 0 ? 0 : profit / i.price,
    maxLoanByIcr: i.icr <= 0 || i.stressRate <= 0 ? double.infinity : fullRent / (i.icr * i.stressRate),
    breakEvenRent: variable <= 0 ? double.infinity : fixed / variable,
    futureValue: futureValue,
    futureEquity: futureValue - i.mortgage.balance(loan, i.years * 12),
  );
}

/// Buying a home to live in, and optionally letting it later.
class HomeInput {
  const HomeInput({
    this.price = 180000,
    this.nation = Nation.northernIreland,
    this.buyer = BuyerType.firstTime,
    this.mortgage = const Mortgage(depositPct: .10, interestOnly: false, rate: .045, years: 30),
    this.legal = 1500,
    this.survey = 500,
    this.income = 45000,
    this.multiple = 4.5,
    this.currentRent = 700,
    this.upkeep = 1500,
    this.insurance = 300,
    this.letRent = 0,
  });

  final double price;
  final Nation nation;
  final BuyerType buyer;
  final Mortgage mortgage;
  final double legal, survey;

  /// Gross household income a year, and the lender's income multiple.
  final double income, multiple;

  /// Rent paid today, for comparison.
  final double currentRent;

  /// Yearly upkeep and buildings insurance.
  final double upkeep, insurance;

  /// Monthly rent if the home is let later (0: not planned).
  final double letRent;

  factory HomeInput.fromJson(Map<String, Object?> j) => HomeInput(
    price: _d(j, 'price', 180000),
    nation: _e(j, 'nation', Nation.values, Nation.northernIreland),
    buyer: _e(j, 'buyer', BuyerType.values, BuyerType.firstTime),
    mortgage: Mortgage.fromJson(
      (j['mortgage'] as Map?)?.cast() ?? const {'rate': .045, 'years': 30},
      interestOnly: false,
      depositPct: .10,
    ),
    legal: _d(j, 'legal', 1500),
    survey: _d(j, 'survey', 500),
    income: _d(j, 'income', 45000),
    multiple: _d(j, 'multiple', 4.5),
    currentRent: _d(j, 'currentRent', 700),
    upkeep: _d(j, 'upkeep', 1500),
    insurance: _d(j, 'insurance', 300),
    letRent: _d(j, 'letRent', 0),
  );

  Map<String, Object?> toJson() => {
    'price': price,
    'nation': nation.name,
    'buyer': buyer.name,
    'mortgage': mortgage.toJson(),
    'legal': legal,
    'survey': survey,
    'income': income,
    'multiple': multiple,
    'currentRent': currentRent,
    'upkeep': upkeep,
    'insurance': insurance,
    'letRent': letRent,
  };
}

class HomeResult {
  HomeResult._({
    required this.purchaseTax,
    required this.loan,
    required this.cashIn,
    required this.monthly,
    required this.stressedMonthly,
    required this.maxLoan,
    required this.monthlyInterest,
    required this.monthlyOwnCost,
    required this.letGrossYield,
    required this.letStressCover,
  });

  final PurchaseTax purchaseTax;
  final double loan, cashIn;
  final double monthly;

  /// The payment if rates rose three points, as lenders check.
  final double stressedMonthly;
  final double maxLoan;

  /// The cost of owning that is not saving: interest, upkeep, insurance.
  final double monthlyInterest, monthlyOwnCost;
  final double letGrossYield;

  /// Rent over the stressed interest when let (lenders want 125%–145%).
  final double letStressCover;

  double get ltv => loan / (loan + cashIn);
  bool get affordable => loan <= maxLoan;
}

HomeResult appraiseHome(HomeInput i, {double stressRise = .03, double letStressRate = .055}) {
  final purchaseTax = residentialTax(i.price, i.nation, i.buyer);
  final loan = i.price * (1 - i.mortgage.depositPct);
  final m = i.mortgage;
  final interest = m.firstYearInterest(loan) / 12;
  return HomeResult._(
    purchaseTax: purchaseTax,
    loan: loan,
    cashIn: i.price - loan + purchaseTax.total + m.fee + i.legal + i.survey,
    monthly: m.monthly(loan),
    stressedMonthly: Mortgage(
      rate: m.rate + stressRise,
      years: m.years,
      interestOnly: m.interestOnly,
    ).monthly(loan),
    maxLoan: i.income * i.multiple,
    monthlyInterest: interest,
    monthlyOwnCost: interest + (i.upkeep + i.insurance) / 12,
    letGrossYield: i.price <= 0 ? 0 : i.letRent * 12 / i.price,
    letStressCover: loan <= 0 ? 0 : i.letRent * 12 / (loan * letStressRate),
  );
}

/// A block of identical units in a scheme.
class UnitType {
  const UnitType({this.name = 'House', this.count = 1, this.sizeM2 = 90, this.price = 200000});
  final String name;
  final int count;
  final double sizeM2;
  final double price;

  factory UnitType.fromJson(Map<String, Object?> j) => UnitType(
    name: (j['name'] as String?) ?? 'Unit',
    count: _d(j, 'count', 1).round(),
    sizeM2: _d(j, 'sizeM2', 90),
    price: _d(j, 'price', 200000),
  );

  Map<String, Object?> toJson() => {'name': name, 'count': count, 'sizeM2': sizeM2, 'price': price};
}

/// A small residential development, appraised the residual way.
class DevInput {
  const DevInput({
    this.nation = Nation.northernIreland,
    this.land = 100000,
    this.units = const [UnitType(name: 'Semi-detached', count: 4, sizeM2: 95, price: 250000)],
    this.buildCostM2 = 1350,
    this.externalsPct = .10,
    this.feesPct = .10,
    this.contingencyPct = .05,
    this.planning = 15000,
    this.financeRate = .09,
    this.buildMonths = 12,
    this.saleMonths = 6,
    this.salesPct = .025,
    this.targetMargin = .20,
  });

  final Nation nation;
  final double land;
  final List<UnitType> units;
  final double buildCostM2;

  /// Roads, drainage and gardens; professional fees; contingency (each a
  /// share of build cost).
  final double externalsPct, feesPct, contingencyPct;

  /// Planning, surveys, section 106 / developer contributions.
  final double planning;
  final double financeRate;
  final int buildMonths, saleMonths;

  /// Agents and legal on sales, share of the sale prices.
  final double salesPct;

  /// Profit on GDV the scheme should make (lenders look for 15–20%).
  final double targetMargin;

  factory DevInput.fromJson(Map<String, Object?> j) => DevInput(
    nation: _e(j, 'nation', Nation.values, Nation.northernIreland),
    land: _d(j, 'land', 100000),
    units: switch (j['units']) {
      List l when l.isNotEmpty => [for (final u in l) UnitType.fromJson((u as Map).cast())],
      _ => const [UnitType(name: 'Semi-detached', count: 4, sizeM2: 95, price: 250000)],
    },
    buildCostM2: _d(j, 'buildCostM2', 1350),
    externalsPct: _d(j, 'externalsPct', .10),
    feesPct: _d(j, 'feesPct', .10),
    contingencyPct: _d(j, 'contingencyPct', .05),
    planning: _d(j, 'planning', 15000),
    financeRate: _d(j, 'financeRate', .09),
    buildMonths: _d(j, 'buildMonths', 12).round(),
    saleMonths: _d(j, 'saleMonths', 6).round(),
    salesPct: _d(j, 'salesPct', .025),
    targetMargin: _d(j, 'targetMargin', .20),
  );

  Map<String, Object?> toJson() => {
    'nation': nation.name,
    'land': land,
    'units': [for (final u in units) u.toJson()],
    'buildCostM2': buildCostM2,
    'externalsPct': externalsPct,
    'feesPct': feesPct,
    'contingencyPct': contingencyPct,
    'planning': planning,
    'financeRate': financeRate,
    'buildMonths': buildMonths,
    'saleMonths': saleMonths,
    'salesPct': salesPct,
    'targetMargin': targetMargin,
  };

  DevInput withLand(double land) => DevInput.fromJson({...toJson(), 'land': land});
}

class DevResult {
  DevResult._({
    required this.gdv,
    required this.areaM2,
    required this.build,
    required this.landTax,
    required this.finance,
    required this.sales,
    required this.totalCost,
    required this.residualLand,
  });

  /// Gross development value: what the finished units sell for.
  final double gdv;
  final double areaM2;

  /// Construction with externals, fees and contingency.
  final double build;
  final double landTax, finance, sales, totalCost;

  /// The most the land is worth while still making the target margin.
  final double residualLand;

  double get profit => gdv - totalCost;
  double get marginOnGdv => gdv <= 0 ? 0 : profit / gdv;
  double get marginOnCost => totalCost <= 0 ? 0 : profit / totalCost;
}

DevResult appraiseDev(DevInput i) {
  final r = _devCosts(i);
  // Land value at which profit is exactly the target: profit falls as land
  // rises (land, its tax and its finance), so bisect.
  var lo = 0.0, hi = math.max(r.gdv, 1.0);
  for (var n = 0; n < 60; n++) {
    final mid = (lo + hi) / 2;
    final c = _devCosts(i.withLand(mid));
    if (c.gdv - c.total >= i.targetMargin * c.gdv) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  // No land price makes the target: the scheme does not work as drawn.
  final bare = _devCosts(i.withLand(0));
  final residual = bare.gdv - bare.total < i.targetMargin * bare.gdv ? 0.0 : lo;
  return DevResult._(
    gdv: r.gdv,
    areaM2: r.area,
    build: r.build,
    landTax: r.landTax,
    finance: r.finance,
    sales: r.sales,
    totalCost: r.total,
    residualLand: residual,
  );
}

({double gdv, double area, double build, double landTax, double finance, double sales, double total})
_devCosts(DevInput i) {
  final gdv = i.units.fold(0.0, (t, u) => t + u.count * u.price);
  final area = i.units.fold(0.0, (t, u) => t + u.count * u.sizeM2);
  final construction = area * i.buildCostM2;
  final build = construction * (1 + i.externalsPct) * (1 + i.feesPct + i.contingencyPct);
  final landTax = nonResidentialTax(i.land, i.nation).total;
  // Land is financed from the start to the last sale; building costs are
  // drawn evenly, so on average half is out during the build, all during sales.
  final months = i.buildMonths + i.saleMonths;
  final landOut = i.land + landTax + i.planning;
  final finance =
      landOut * i.financeRate * months / 12 + build * i.financeRate * (i.buildMonths / 2 + i.saleMonths) / 12;
  final sales = gdv * i.salesPct;
  return (
    gdv: gdv,
    area: area,
    build: build,
    landTax: landTax,
    finance: finance,
    sales: sales,
    total: landOut + build + finance + sales,
  );
}
