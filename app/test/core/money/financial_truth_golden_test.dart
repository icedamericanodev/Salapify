import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/financial_truth.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the Financial Truth engine, produced by running
/// src/utils/financialTruthEngine.ts under bun.
void main() {
  const double eps = 1e-4;

  group('digital twin', () {
    const double cash = 110720.5;
    const double runrate = 28000;
    const double netWorth = 250000;
    const double income = 51000;

    TwinSimulationResult run(TwinScenario s) => simulateDigitalTwin(
      scenario: s,
      currentLiquidCash: cash,
      monthlyExpenseRunrate: runrate,
      currentNetWorth: netWorth,
      monthlyIncome: income,
    );

    test('the baseline is the same for every scenario', () {
      for (final TwinScenario s in TwinScenario.values) {
        expect(run(s).baselineRunwayMonths, closeTo(3.9543, eps));
        expect(run(s).baselineSafeToSpend, closeTo(44288.20, 0.01));
      }
    });

    test('job loss EXTENDS the runway, which looks wrong and is not', () {
      final TwinSimulationResult r = run(TwinScenario.jobLoss);
      // Survival mode cuts spending by a quarter, and the runway metric only
      // reads cash against spending, so it improves. The damage shows in the
      // buffer impact and in net worth, not here. A screen that showed the
      // runway alone would tell somebody losing their job that things got
      // better.
      expect(r.simulatedRunwayMonths, closeTo(5.2724, eps));
      expect(r.simulatedRunwayMonths, greaterThan(r.baselineRunwayMonths));
      expect(r.bufferImpactPhp, -153000);
      expect(r.simulatedNetWorth, 187000);
      expect(r.simulatedSafeToSpend, 0);
    });

    test('delayed income costs half a month of expenses', () {
      final TwinSimulationResult r = run(TwinScenario.delayedIncome);
      expect(r.simulatedRunwayMonths, closeTo(3.4543, eps));
      expect(r.simulatedSafeToSpend, closeTo(29016.15, 0.01));
      expect(r.bufferImpactPhp, -14000);
      expect(
        r.simulatedNetWorth,
        netWorth,
        reason: 'a delay moves timing, not wealth',
      );
    });

    test('a 3,500 rent rise costs 42,000 a year', () {
      final TwinSimulationResult r = run(TwinScenario.rentIncrease);
      expect(r.simulatedRunwayMonths, closeTo(3.5149, eps));
      expect(r.simulatedSafeToSpend, closeTo(40788.20, 0.01));
      expect(r.bufferImpactPhp, -42000);
      expect(r.simulatedNetWorth, 208000);
    });

    test('a 50,000 medical bill nearly halves the runway', () {
      final TwinSimulationResult r = run(TwinScenario.medicalExpense);
      expect(r.simulatedRunwayMonths, closeTo(2.1686, eps));
      expect(r.simulatedSafeToSpend, closeTo(12144.10, 0.01));
      expect(r.bufferImpactPhp, -50000);
      expect(r.simulatedNetWorth, 200000);
    });

    test('a new child is the largest recurring shock of the eight', () {
      final TwinSimulationResult r = run(TwinScenario.newChild);
      expect(r.simulatedRunwayMonths, closeTo(2.6362, eps));
      expect(r.bufferImpactPhp, -168000);
      expect(r.simulatedNetWorth, 82000);
    });

    test('the 13th month is the only scenario that helps on every measure', () {
      final TwinSimulationResult r = run(TwinScenario.thirteenthMonth);
      expect(r.simulatedRunwayMonths, closeTo(5.7757, eps));
      expect(r.simulatedSafeToSpend, closeTo(59588.20, 0.01));
      expect(r.bufferImpactPhp, 51000);
      expect(r.simulatedNetWorth, 301000);

      expect(r.simulatedRunwayMonths, greaterThan(r.baselineRunwayMonths));
      expect(r.simulatedSafeToSpend, greaterThan(r.baselineSafeToSpend));
      expect(r.simulatedNetWorth, greaterThan(r.baselineNetWorth));
    });

    test('prepaying debt trades runway for net worth', () {
      final TwinSimulationResult r = run(TwinScenario.debtPrepayment);
      expect(r.simulatedRunwayMonths, closeTo(2.8829, eps));
      expect(r.simulatedNetWorth, closeTo(255400, 0.01));
      expect(r.bufferImpactPhp, closeTo(5400, 0.01));

      // Less cash on hand, more wealth. That trade is the decision.
      expect(r.simulatedRunwayMonths, lessThan(r.baselineRunwayMonths));
      expect(r.simulatedNetWorth, greaterThan(r.baselineNetWorth));
    });

    test('a business slowdown leaves the runway alone and cuts net worth', () {
      final TwinSimulationResult r = run(TwinScenario.businessSlowdown);
      // Spending has not changed, so the runway cannot. Only income fell.
      expect(r.simulatedRunwayMonths, closeTo(r.baselineRunwayMonths, eps));
      expect(r.simulatedSafeToSpend, closeTo(36638.20, 0.01));
      expect(r.simulatedNetWorth, closeTo(204100, 0.01));
    });

    test('a zero runrate assumes six months instead of dividing by zero', () {
      final TwinSimulationResult r = simulateDigitalTwin(
        scenario: TwinScenario.jobLoss,
        currentLiquidCash: 50000,
        monthlyExpenseRunrate: 0,
        currentNetWorth: 100000,
        monthlyIncome: 40000,
      );
      expect(r.baselineRunwayMonths, 6);
      expect(r.simulatedRunwayMonths, 0);
    });

    test('every scenario offers three recommendations', () {
      for (final TwinScenario s in TwinScenario.values) {
        expect(run(s).recommendations.length, 3, reason: '$s');
      }
    });
  });

  group('control centre scan', () {
    Transaction tx(
      String id,
      double amount,
      String category,
      String date, {
      String? merchant,
      TransactionType type = TransactionType.expense,
    }) => Transaction(
      id: id,
      type: type,
      amount: amount,
      category: category,
      accountId: 'acc_cash',
      date: date,
      createdAt: 0,
      merchant: merchant,
    );

    test('the same charge twice within 48 hours is flagged', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: <Transaction>[
          tx('t1', 1299, 'Shopping', '2026-09-10', merchant: 'Lazada'),
          tx('t2', 1299, 'Shopping', '2026-09-11', merchant: 'Lazada'),
        ],
        accounts: const <Account>[],
        debts: const <Debt>[],
        budgets: const <Budget>[],
      );
      final Iterable<ControlCenterAlert> dup = alerts.where(
        (ControlCenterAlert a) => a.type == AlertType.duplicateCharge,
      );
      expect(dup.length, 1);
      expect(dup.first.amount, 1299);
      expect(dup.first.severity, AlertSeverity.medium);
    });

    test('the same charge three days apart is NOT a duplicate', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: <Transaction>[
          tx('t1', 1299, 'Shopping', '2026-09-10', merchant: 'Lazada'),
          tx('t2', 1299, 'Shopping', '2026-09-14', merchant: 'Lazada'),
        ],
        accounts: const <Account>[],
        debts: const <Debt>[],
        budgets: const <Budget>[],
      );
      expect(
        alerts.where(
          (ControlCenterAlert a) => a.type == AlertType.duplicateCharge,
        ),
        isEmpty,
      );
    });

    test('a negative balance is flagged, but never on a borrowing account', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: const <Transaction>[],
        accounts: const <Account>[
          Account(
            id: 'a1',
            name: 'GCash',
            kind: AccountKind.gcash,
            institution: 'GCash',
            balance: -250,
            monogram: 'GC',
          ),
          Account(
            id: 'a2',
            name: 'BPI Card',
            kind: AccountKind.credit,
            institution: 'BPI',
            balance: -40000,
            monogram: 'BPI',
          ),
        ],
        debts: const <Debt>[],
        budgets: const <Budget>[],
      );
      final Iterable<ControlCenterAlert> neg = alerts.where(
        (ControlCenterAlert a) => a.type == AlertType.balanceMismatch,
      );
      expect(neg.length, 1, reason: 'a credit card is SUPPOSED to be negative');
      expect(neg.first.relatedAccountId, 'a1');
      expect(neg.first.amount, 250);
    });

    test('category drift needs 15 percent over, and 30 to turn high', () {
      List<ControlCenterAlert> at(double spent) => runControlCenterScan(
        transactions: <Transaction>[tx('t', spent, 'Food', '2026-09-10')],
        accounts: const <Account>[],
        debts: const <Debt>[],
        budgets: const <Budget>[
          Budget(category: 'Food', limit: 10000, emoji: 'F'),
        ],
      );

      expect(
        at(
          11000,
        ).where((ControlCenterAlert a) => a.type == AlertType.categoryDrift),
        isEmpty,
        reason: '10 percent over is within tolerance',
      );

      final ControlCenterAlert medium = at(
        11600,
      ).firstWhere((ControlCenterAlert a) => a.type == AlertType.categoryDrift);
      expect(medium.severity, AlertSeverity.medium);

      final ControlCenterAlert high = at(
        14000,
      ).firstWhere((ControlCenterAlert a) => a.type == AlertType.categoryDrift);
      expect(high.severity, AlertSeverity.high);
      expect(high.amount, 4000);
    });

    test('cash under 5,000 is critical', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: const <Transaction>[],
        accounts: const <Account>[
          Account(
            id: 'a1',
            name: 'Cash',
            kind: AccountKind.cash,
            institution: 'Cash',
            balance: 1200,
            monogram: 'C',
          ),
        ],
        debts: const <Debt>[],
        budgets: const <Budget>[],
      );
      final ControlCenterAlert a = alerts.firstWhere(
        (ControlCenterAlert x) => x.type == AlertType.cashShortfall,
      );
      expect(a.severity, AlertSeverity.critical);
      expect(a.amount, 1200);
    });

    test('debt above 80 percent of reserves raises pressure', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: const <Transaction>[],
        accounts: const <Account>[
          Account(
            id: 'a1',
            name: 'BPI',
            kind: AccountKind.bank,
            institution: 'BPI',
            balance: 20000,
            monogram: 'B',
          ),
        ],
        debts: const <Debt>[
          Debt(
            id: 'd1',
            person: 'Home Credit',
            direction: DebtDirection.iOwe,
            totalAmount: 30000,
            paidAmount: 0,
            isSettled: false,
          ),
          Debt(
            id: 'd2',
            person: 'Settled',
            direction: DebtDirection.iOwe,
            totalAmount: 99000,
            paidAmount: 99000,
            isSettled: true,
          ),
        ],
        budgets: const <Budget>[],
      );
      final ControlCenterAlert a = alerts.firstWhere(
        (ControlCenterAlert x) => x.type == AlertType.debtPaymentRisk,
      );
      expect(a.amount, 30000, reason: 'a settled debt is not pressure');
      expect(a.severity, AlertSeverity.high);
    });

    test('a clean ledger raises nothing at all', () {
      final List<ControlCenterAlert> alerts = runControlCenterScan(
        transactions: <Transaction>[tx('t', 500, 'Food', '2026-09-10')],
        accounts: const <Account>[
          Account(
            id: 'a1',
            name: 'BPI',
            kind: AccountKind.bank,
            institution: 'BPI',
            balance: 90000,
            monogram: 'B',
          ),
        ],
        debts: const <Debt>[],
        budgets: const <Budget>[
          Budget(category: 'Food', limit: 10000, emoji: 'F'),
        ],
      );
      expect(
        alerts,
        isEmpty,
        reason: 'an engine that always finds something gets ignored',
      );
    });
  });
}
