import 'package:anveshana/domain/appraisal.dart';
import 'package:anveshana/domain/tax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double tax(double price, Nation n, BuyerType b, {bool nonResident = false}) =>
      residentialTax(price, n, b, nonResident: nonResident).total;

  group('purchase tax', () {
    test('SDLT, England and Northern Ireland alike', () {
      for (final n in [Nation.england, Nation.northernIreland]) {
        expect(tax(300000, n, BuyerType.mover), 5000); // 2% of 125k + 5% of 50k
        expect(tax(300000, n, BuyerType.additional), 20000); // plus 5% of 300k
        expect(tax(125000, n, BuyerType.mover), 0);
      }
    });

    test('SDLT first-time buyers: relief to £500,000, none above', () {
      expect(tax(300000, Nation.england, BuyerType.firstTime), 0);
      expect(tax(400000, Nation.england, BuyerType.firstTime), 5000);
      expect(tax(500001, Nation.england, BuyerType.firstTime), 15000); // standard rates, rounded down
    });

    test('SDLT surcharges stack, and skip purchases under £40,000', () {
      expect(tax(200000, Nation.northernIreland, BuyerType.additional, nonResident: true), 15500);
      expect(tax(30000, Nation.england, BuyerType.additional), 0);
    });

    test('LBTT in Scotland, with first-time relief and the 8% ADS', () {
      expect(tax(200000, Nation.scotland, BuyerType.mover), 1100);
      expect(tax(200000, Nation.scotland, BuyerType.firstTime), 500);
      final ads = residentialTax(200000, Nation.scotland, BuyerType.additional);
      expect(ads.extra, 16000);
      expect(ads.total, 17100);
    });

    test('LTT in Wales: main and higher rates, no first-time relief', () {
      expect(tax(300000, Nation.wales, BuyerType.mover), 4500);
      expect(tax(300000, Nation.wales, BuyerType.firstTime), 4500);
      expect(tax(300000, Nation.wales, BuyerType.additional), 19950);
    });

    test('non-residential rates for land', () {
      expect(nonResidentialTax(300000, Nation.england).total, 4500);
      expect(nonResidentialTax(300000, Nation.scotland).total, 3500);
      expect(nonResidentialTax(300000, Nation.wales).total, 2750);
    });
  });

  group('income tax on rent', () {
    test('Section 24: interest earns a 22% credit, never a refund', () {
      expect(personalRentalTax(10000, 6000, rate: .42), closeTo(4200 - 1320, .001));
      expect(personalRentalTax(10000, 20000, rate: .22), 0);
    });

    test('corporation tax with marginal relief', () {
      expect(corporationTax(40000), closeTo(7600, .001));
      expect(corporationTax(100000), closeTo(22750, .001));
      expect(corporationTax(300000), closeTo(75000, .001));
    });
  });

  group('mortgages', () {
    test('repayment payment and balance', () {
      expect(repaymentPayment(100000, .05, 25), closeTo(584.59, .01));
      expect(balanceAfter(100000, .05, 25, 300), closeTo(0, .01));
      expect(balanceAfter(100000, 0, 10, 60), closeTo(50000, .01));
    });
  });

  group('buy-to-let', () {
    const input = BtlInput(
      price: 150000,
      nation: Nation.northernIreland,
      mortgage: Mortgage(depositPct: .25, rate: .05, interestOnly: true, fee: 1000),
      legal: 1500,
      survey: 500,
      refurb: 0,
      rent: 850,
      voidWeeks: 0,
      agentPct: .10,
      maintenancePct: .05,
      insurance: 300,
      serviceCharge: 0,
      otherCosts: 200,
      taxRate: .22,
    );

    test('cash in, yields, cash flow and tax', () {
      final r = appraiseBtl(input);
      // SDLT with the surcharge: 5% of 125k + 7% of 25k.
      expect(r.purchaseTax.total, 8000);
      expect(r.loan, 112500);
      expect(r.cashIn, 37500 + 8000 + 1000 + 1500 + 500);
      expect(r.grossYield, closeTo(10200 / 150000, 1e-9));
      expect(r.runningCosts, closeTo(10200 * .15 + 500, 1e-9));
      expect(r.mortgagePayments, closeTo(5625, 1e-9));
      final profit = 10200 - (1530 + 500);
      expect(r.tax, closeTo(profit * .22 - 5625 * .22, 1e-6));
      expect(r.cashFlow, closeTo(10200 - 2030 - 5625 - r.tax, 1e-6));
    });

    test('stress test and break-even rent', () {
      final r = appraiseBtl(input);
      expect(r.maxLoanByIcr, closeTo(10200 / (1.25 * .055), 1e-6));
      expect(r.passesStressTest, isTrue);
      final at = appraiseBtl(BtlInput.fromJson({...input.toJson(), 'rent': r.breakEvenRent}));
      expect(at.cashFlowBeforeTax, closeTo(0, 1e-6));
    });

    test('inputs survive JSON, and missing ones take defaults', () {
      expect(BtlInput.fromJson(input.toJson()).toJson(), input.toJson());
      expect(BtlInput.fromJson(const {}).price, 150000);
    });
  });

  group('home purchase', () {
    test('affordability and letting later', () {
      final r = appraiseHome(
        HomeInput.fromJson(const {
          'price': 200000,
          'buyer': 'firstTime',
          'income': 40000,
          'multiple': 4.5,
          'letRent': 900,
          'mortgage': {'depositPct': .1, 'rate': .045, 'years': 30, 'interestOnly': false, 'fee': 0},
        }),
      );
      expect(r.purchaseTax.total, 0);
      expect(r.loan, 180000);
      expect(r.affordable, isTrue);
      expect(r.monthly, closeTo(repaymentPayment(180000, .045, 30), 1e-9));
      expect(r.stressedMonthly, greaterThan(r.monthly));
      expect(r.letGrossYield, closeTo(.054, 1e-9));
    });
  });

  group('development', () {
    test('residual land value makes exactly the target margin', () {
      const input = DevInput(
        nation: Nation.england,
        land: 100000,
        units: [UnitType(count: 4, sizeM2: 95, price: 260000)],
        buildCostM2: 1300,
      );
      final r = appraiseDev(input);
      expect(r.gdv, 4 * 260000);
      expect(r.areaM2, 380);
      expect(r.residualLand, greaterThan(0));
      final atResidual = appraiseDev(input.withLand(r.residualLand));
      expect(atResidual.marginOnGdv, closeTo(input.targetMargin, 1e-6));
      expect(r.residualLand > 100000, r.marginOnGdv > input.targetMargin);
    });

    test('a scheme that cannot make the margin has no land value', () {
      final r = appraiseDev(const DevInput(units: [UnitType(count: 1, sizeM2: 200, price: 100000)]));
      expect(r.residualLand, 0);
      expect(r.profit, lessThan(0));
    });
  });
}
