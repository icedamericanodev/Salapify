import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt_strategy.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/strategy_debts.dart';
import 'package:salapify/models/models.dart';

/// The payoff calculator on the person's OWN debts (D31), not three examples.
void main() {
  Debt debt(
    String id,
    String person, {
    DebtDirection direction = DebtDirection.iOwe,
    int total = 10000,
    int paid = 0,
    bool settled = false,
    String? archivedAt,
    int? minimum,
  }) => Debt(
    id: id,
    person: person,
    direction: direction,
    totalAmount: Money.pesos(total),
    paidAmount: Money.pesos(paid),
    isSettled: settled,
    archivedAt: archivedAt,
    minimumPayment: minimum == null ? null : Money.pesos(minimum),
  );

  test('only open money the person OWES, by what is left', () {
    final List<DebtItemForStrategy> out = strategyDebtsFrom(<Debt>[
      debt('a', 'BDO Card', total: 30000, paid: 5000, minimum: 1500),
      debt('b', 'Kuya Mark', direction: DebtDirection.owedToMe),
      debt('c', 'Old loan', settled: true),
      debt('d', 'Shelved', archivedAt: '2026-09-01'),
      debt('e', 'Paid off', total: 500, paid: 500),
    ]);
    expect(out.map((DebtItemForStrategy d) => d.id), <String>['a']);
    expect(out.single.balance, 25000);
    expect(out.single.minimumPayment, 1500);
  });

  test('a typed rate is used, and no rate means 0, never a guess', () {
    final List<DebtItemForStrategy> out = strategyDebtsFrom(
      <Debt>[debt('a', 'Card', minimum: 500), debt('b', 'Nanay')],
      ratesById: <String, double>{'a': 36},
    );
    expect(out.first.interestRate, 36);
    expect(out.last.interestRate, 0);
    expect(out.last.minimumPayment, 0, reason: 'a minimum was invented');
  });

  test('two debts to the same person do not share one rate', () {
    final List<DebtItemForStrategy> out = strategyDebtsFrom(<Debt>[
      debt('a', 'Aling Nena'),
      debt('b', 'Aling Nena'),
    ]);
    expect(out.map((DebtItemForStrategy d) => d.name).toSet(), hasLength(2));
  });

  test('the simulation runs on them and clears them', () {
    final StrategyComparison r = simulateDebtStrategies(
      debts: strategyDebtsFrom(
        <Debt>[
          debt('a', 'Card', total: 20000, minimum: 1000),
          debt('b', 'Loan', total: 6000, minimum: 500),
        ],
        ratesById: <String, double>{'a': 36},
      ),
      extraMonthlyBudget: 2000,
    );
    expect(r.avalanche.orderOfPayoff, hasLength(2));
    expect(r.avalanche.monthsToDebtFreedom, lessThan(240));
    // Card has the rate, so avalanche goes at it first.
    expect(r.avalanche.orderOfPayoff.first, 'Card');
  });
}
