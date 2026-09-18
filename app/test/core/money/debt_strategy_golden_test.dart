import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt_strategy.dart';

/// Golden vectors for the credit card payoff and the snowball against
/// avalanche simulator, produced by running src/utils/loanCalculators.ts
/// under bun.
void main() {
  group('the credit card minimum payment trap', () {
    final CreditCardPayoffResult minimum =
        calculateCreditCardPayoff(currentBalance: 80000);

    test('80,000 on the minimum takes years and nearly doubles the debt', () {
      expect(minimum.monthsToPayoff, 81);
      expect(minimum.totalInterestPaid, 71600);
      expect(minimum.totalAmountPaid, 151600);
    });

    test('a fixed 8,000 a month clears the same balance in 13', () {
      final CreditCardPayoffResult fixed = calculateCreditCardPayoff(
        currentBalance: 80000,
        paymentStrategy: CardPaymentStrategy.fixedAmount,
        fixedMonthlyPayment: 8000,
      );
      expect(fixed.monthsToPayoff, 13);
      expect(fixed.totalInterestPaid, 16540);

      // The whole argument in one assertion: the same debt costs 55,060 pesos
      // more in interest when paid the way the statement suggests.
      expect(minimum.totalInterestPaid - fixed.totalInterestPaid, 55060);
    });

    test('the warning appears only above 20,000 and only on minimum-only', () {
      expect(minimum.warningMessage, isNotNull);
      expect(minimum.warningMessage, contains('3% monthly BSP cap'));

      expect(
        calculateCreditCardPayoff(currentBalance: 15000).warningMessage,
        isNull,
        reason: 'a small balance does not trap anybody',
      );
      expect(
        calculateCreditCardPayoff(
          currentBalance: 80000,
          paymentStrategy: CardPaymentStrategy.fixedAmount,
          fixedMonthlyPayment: 8000,
        ).warningMessage,
        isNull,
      );
    });

    test('the schedule is THINNED after month 36, so a screen must say about',
        () {
      // 81 months of payoff, 44 rows kept: every month to 36, then every
      // sixth. monthsToPayoff is read off the last row KEPT, so once thinning
      // starts it can under-report by up to five months. Locked deliberately,
      // because a screen reading it as exact would be wrong.
      expect(minimum.schedule.length, 44);
      expect(minimum.schedule.last.month, 81);
      expect(minimum.schedule[35].month, 36);
      expect(minimum.schedule[36].month, 42);
    });

    test('a small balance clears without thinning at all', () {
      final CreditCardPayoffResult small =
          calculateCreditCardPayoff(currentBalance: 15000);
      expect(small.monthsToPayoff, 26);
      expect(small.schedule.length, 26);
      expect(small.totalInterestPaid, 6600);
    });

    test('the balance falls every month and reaches zero', () {
      double previous = double.infinity;
      for (final CardPayoffRow row in minimum.schedule) {
        expect(row.balance, lessThan(previous));
        previous = row.balance;
      }
      expect(minimum.schedule.last.balance, 0);
    });
  });

  group('snowball against avalanche', () {
    const List<DebtItemForStrategy> debts = <DebtItemForStrategy>[
      DebtItemForStrategy(
        id: '1', name: 'Small Card', balance: 18000,
        interestRate: 36, minimumPayment: 900,
      ),
      DebtItemForStrategy(
        id: '2', name: 'Big Card', balance: 95000,
        interestRate: 42, minimumPayment: 3800,
      ),
      DebtItemForStrategy(
        id: '3', name: 'Gadget Plan', balance: 42000,
        interestRate: 12, minimumPayment: 2400,
      ),
    ];

    final StrategyComparison r =
        simulateDebtStrategies(debts: debts, extraMonthlyBudget: 5000);

    test('snowball clears smallest balance first', () {
      expect(r.snowball.monthsToDebtFreedom, 22);
      expect(r.snowball.totalInterestPaid, 56400);
      expect(r.snowball.totalAmountPaid, 211400);
      expect(
        r.snowball.orderOfPayoff,
        <String>['Small Card', 'Gadget Plan', 'Big Card'],
      );
    });

    test('avalanche clears the highest rate first', () {
      expect(r.avalanche.monthsToDebtFreedom, 17);
      expect(r.avalanche.totalInterestPaid, 37738);
      expect(r.avalanche.totalAmountPaid, 192738);
      expect(
        r.avalanche.orderOfPayoff,
        <String>['Big Card', 'Small Card', 'Gadget Plan'],
      );
    });

    test('avalanche wins on both money and time, which is the advice', () {
      expect(r.interestDifference, 18662);
      expect(
        r.avalanche.totalInterestPaid,
        lessThan(r.snowball.totalInterestPaid),
      );
      expect(
        r.avalanche.monthsToDebtFreedom,
        lessThan(r.snowball.monthsToDebtFreedom),
      );
    });

    test('the difference is never negative, whatever the debts look like', () {
      // Avalanche is mathematically optimal on interest, so the comparison can
      // only ever favour it. A negative here would mean the simulator is wrong.
      for (final double extra in <double>[0, 1000, 5000, 20000]) {
        expect(
          simulateDebtStrategies(debts: debts, extraMonthlyBudget: extra)
              .interestDifference,
          greaterThanOrEqualTo(0),
        );
      }
    });

    test('every debt is named once in each payoff order', () {
      for (final StrategySimulationResult s
          in <StrategySimulationResult>[r.snowball, r.avalanche]) {
        expect(s.orderOfPayoff.length, 3);
        expect(s.orderOfPayoff.toSet().length, 3);
        expect(
          s.orderOfPayoff.toSet(),
          <String>{'Small Card', 'Big Card', 'Gadget Plan'},
        );
      }
    });

    test('more extra money never makes either strategy slower', () {
      int months(double extra, bool avalanche) {
        final StrategyComparison c =
            simulateDebtStrategies(debts: debts, extraMonthlyBudget: extra);
        return avalanche
            ? c.avalanche.monthsToDebtFreedom
            : c.snowball.monthsToDebtFreedom;
      }

      for (final bool av in <bool>[true, false]) {
        int previous = 1 << 30;
        for (final double extra in <double>[0, 2000, 5000, 10000, 20000]) {
          final int m = months(extra, av);
          expect(m, lessThanOrEqualTo(previous));
          previous = m;
        }
      }
    });
  });
}
