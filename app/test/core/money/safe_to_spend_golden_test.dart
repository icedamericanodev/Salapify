import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/core/money/safe_to_spend.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the Safe to Spend port.
///
/// These numbers were NOT worked out by hand and they were not copied from the
/// Dart code. They came out of the prototype's own TypeScript
/// (src/utils/safeToSpendEngine.ts), run under bun against the prototype's own
/// fixture (src/data/initialData.ts). If a figure here ever disagrees with the
/// prototype, the port is wrong, not the vector.
void main() {
  // The vectors were generated with this exact instant pinned.
  final DateTime pinnedNow = DateTime.utc(2026, 9, 18);

  double debtsIOwe() => SeedData.debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .fold<double>(0, (double s, Debt d) => s + d.remaining);

  double debtsOwedToMe() => SeedData.debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (double s, Debt d) => s + d.remaining);

  SafeToSpendAnalysis run({
    required DecisionScenario scenario,
    List<Transaction> transactions = const <Transaction>[],
  }) => computeSafeToSpend(
    accounts: SeedData.accounts,
    transactions: transactions,
    bills: SeedData.bills,
    debtsIOwe: debtsIOwe(),
    installments: SeedData.installments,
    incomeStreams: SeedData.incomeStreams,
    payday: SeedData.payday,
    scenario: scenario,
    now: pinnedNow,
  );

  group('the fixture itself matches the prototype', () {
    test('debt totals agree', () {
      expect(debtsIOwe(), 17350);
      expect(debtsOwedToMe(), 6250);
    });

    test('liquid cash agrees, and excludes what is not spendable', () {
      final double liquid = SeedData.accounts
          .where((Account a) => a.isLiquid)
          .fold<double>(0, (double s, Account a) => s + a.balance);
      expect(liquid, 110720.50);

      // The investment, the receivable and every borrowing line stay out.
      final Set<String> excluded = SeedData.accounts
          .where((Account a) => !a.isLiquid)
          .map((Account a) => a.id)
          .toSet();
      expect(excluded, <String>{
        'acc_mp2',
        'acc_receivables',
        'acc_bpi_cc',
        'acc_personal_loan',
        'acc_pagibig_mortgage',
      });
    });
  });

  group('vector A, conservative, no logged spending', () {
    final SafeToSpendAnalysis a = run(scenario: DecisionScenario.conservative);

    test('headline figures', () {
      expect(a.safeToSpendToday, 9604);
      expect(a.safeToSpendUntilPayday, 38414);
      expect(a.safeToSave, 6779);
      expect(a.amountReserved, 65528);
      expect(a.daysToPayday, 4);
    });

    test('reserved breakdown', () {
      expect(a.reservedBills, 41184);
      expect(a.reservedDebtMinimums, 1388);
      expect(a.reservedInstallments, 6348);
      expect(a.emergencyBuffer, 16608);
    });

    test('totals and runway', () {
      expect(a.totalLiquidCash, 110721);
      expect(a.totalExpectedInflow, 46750);
      expect(a.cashRunwayDays, 119);
      expect(a.cashRunwayMonths, 4);
    });
  });

  group('vector B, optimistic, no logged spending', () {
    final SafeToSpendAnalysis b = run(scenario: DecisionScenario.optimistic);

    test('optimistic frees up more and reserves less', () {
      expect(b.safeToSpendToday, 12752);
      expect(b.safeToSpendUntilPayday, 51007);
      expect(b.safeToSave, 9001);
      expect(b.amountReserved, 50712);
    });

    test('the buffer drops to 5 percent and bills lose the 10 percent pad', () {
      expect(b.emergencyBuffer, 5536);
      expect(b.reservedBills, 37440);
    });

    test('the 13th month counts only in the optimistic scenario', () {
      expect(b.totalExpectedInflow, 121000);
    });
  });

  group('vector C, conservative, with recent spending', () {
    // Pinned exactly as the vector generator built them.
    final List<Transaction> txns = <Transaction>[
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amount: 2840,
        category: 'Bills & Utilities',
        accountId: 'acc_maya',
        date: '2026-09-15',
        createdAt: pinnedNow
            .subtract(const Duration(days: 3))
            .millisecondsSinceEpoch,
      ),
      Transaction(
        id: 't2',
        type: TransactionType.expense,
        amount: 3250.75,
        category: 'Groceries',
        accountId: 'acc_ub_debit',
        date: '2026-09-14',
        createdAt: pinnedNow
            .subtract(const Duration(days: 4))
            .millisecondsSinceEpoch,
      ),
      Transaction(
        id: 't3',
        type: TransactionType.expense,
        amount: 6000,
        category: 'Family & Remittance',
        accountId: 'acc_bpi',
        date: '2026-09-16',
        createdAt: pinnedNow
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
      ),
    ];

    final SafeToSpendAnalysis c = run(
      scenario: DecisionScenario.conservative,
      transactions: txns,
    );

    test('spending changes the runway and nothing else', () {
      // Real burn rate replaces the 28,000 default.
      expect(c.cashRunwayDays, 275);
      expect(c.cashRunwayMonths, 9.2);

      // Everything upstream of the runway is untouched by logged spending.
      expect(c.safeToSpendToday, 9604);
      expect(c.safeToSpendUntilPayday, 38414);
      expect(c.amountReserved, 65528);
    });

    test('and the answer SAYS it measured them', () {
      expect(c.runwayFromLoggedSpending, isTrue);
    });
  });

  group('whether the runway was measured or stood in for', () {
    // The 28,000 default is the prototype's, is deliberate, and is locked by
    // the vectors above, so none of this changes a figure. What it pins is
    // that the answer now carries WHICH of the two it used, because without
    // that a screen cannot tell a measurement from a placeholder and two of
    // them called the placeholder "your recent burn rate".

    test('no logged spending at all is NOT a measurement', () {
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
      );
      expect(
        a.runwayFromLoggedSpending,
        isFalse,
        reason: 'an empty ledger claimed to have measured a burn rate',
      );
      // And the figure itself is untouched, which is the whole point of
      // fixing this in the UI rather than in the engine.
      expect(a.cashRunwayDays, 119);
    });

    test('a very quiet month is not one either', () {
      // Under the prototype's own 5,000 threshold, so the stand-in applies.
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
        transactions: <Transaction>[
          Transaction(
            id: 'tx_small',
            type: TransactionType.expense,
            amount: 400,
            category: 'Food & Dining',
            accountId: 'acc_bpi',
            date: '2026-09-17',
            createdAt: pinnedNow
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        ],
      );
      expect(a.runwayFromLoggedSpending, isFalse);
    });

    test('an explicit override IS a measurement, because a person set it', () {
      // The other half of the alarm. A rule that called everything
      // unmeasured would pass both tests above and be useless: it would hide
      // the runway from somebody who had told the app what they spend.
      final SafeToSpendAnalysis a = computeSafeToSpend(
        accounts: SeedData.accounts,
        transactions: const <Transaction>[],
        bills: SeedData.bills,
        debtsIOwe: debtsIOwe(),
        installments: SeedData.installments,
        incomeStreams: SeedData.incomeStreams,
        payday: SeedData.payday,
        scenario: DecisionScenario.conservative,
        now: pinnedNow,
        monthlyLivingExpenseOverride: 18000,
      );
      expect(a.runwayFromLoggedSpending, isTrue);
    });
  });

  group('the split between spending and saving', () {
    test('safe to spend and safe to save are 85 / 15 of the same pot', () {
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
      );
      // 38414 + 6779 = 45193, the uncommitted cash, to the peso.
      expect(a.safeToSpendUntilPayday + a.safeToSave, 45193);
    });

    test('a day rate never exceeds the whole period', () {
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
      );
      expect(a.safeToSpendToday, lessThanOrEqualTo(a.safeToSpendUntilPayday));
    });
  });
}
