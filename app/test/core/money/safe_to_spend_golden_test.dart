import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/core/money/safe_to_spend.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';
import 'package:salapify/core/money/money.dart';

/// Golden vectors for the Safe to Spend port.
///
/// These numbers were NOT worked out by hand and they were not copied from the
/// Dart code. They came out of the prototype's own TypeScript
/// (archive/prototype-google-ai-studio/src/utils/safeToSpendEngine.ts), run under bun against the prototype's own
/// fixture (archive/prototype-google-ai-studio/src/data/initialData.ts). If a figure here ever disagrees with the
/// prototype, the port is wrong, not the vector.
void main() {
  // The vectors were generated with this exact instant pinned.
  final DateTime pinnedNow = DateTime.utc(2026, 9, 18);

  double debtsIOwe() => SeedData.debts(testToday)
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .fold<double>(0, (double s, Debt d) => s + d.remaining.pesos);

  double debtsOwedToMe() => SeedData.debts(testToday)
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (double s, Debt d) => s + d.remaining.pesos);

  /// The fixture AS THE PROTOTYPE CAN REPRESENT IT, which means every account
  /// spendable.
  ///
  /// P2.3 added `Account.purpose` and marked one seeded account protected, so
  /// `SeedData.accounts` is no longer the prototype's fixture. The TypeScript
  /// has no concept of purpose and never will, so a vector generated from it
  /// can only ever describe the all-spendable case. Running the Dart port
  /// against the shipped seed and calling the result "parity" would be a
  /// parity claim about a fixture the other side cannot express.
  ///
  /// So this group pins the honest comparison, and every vector below is
  /// byte for byte the one that was here before P2.3. Re-run against the live
  /// TypeScript on 2026-10-04 and all fourteen figures still matched.
  ///
  /// The protected behaviour has its own group at the bottom of this file,
  /// with its own vectors, generated from the same untouched engine.
  List<Account> allSpendable() => SeedData.accounts(
    testToday,
  ).map((Account a) => a.copyWith(purpose: AccountPurpose.spendable)).toList();

  SafeToSpendAnalysis run({
    required DecisionScenario scenario,
    List<Transaction> transactions = const <Transaction>[],
  }) => computeSafeToSpend(
    accounts: allSpendable(),
    transactions: transactions,
    bills: SeedData.bills(testToday),
    debtsIOwe: debtsIOwe(),
    installments: SeedData.installments(testToday),
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
      final double liquid = SeedData.accounts(testToday)
          .where((Account a) => a.isLiquid)
          .fold<double>(0, (double s, Account a) => s + a.balance.pesos);
      expect(liquid, 110720.50);

      // The investment, the receivable and every borrowing line stay out.
      final Set<String> excluded = SeedData.accounts(
        testToday,
      ).where((Account a) => !a.isLiquid).map((Account a) => a.id).toSet();
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
      expect(a.safeToSpendToday, Money.pesos(9604));
      expect(a.safeToSpendUntilPayday, Money.pesos(38414));
      expect(a.safeToSave, Money.pesos(6779));
      expect(a.amountReserved, Money.pesos(65528));
      expect(a.daysToPayday, 4);
    });

    test('reserved breakdown', () {
      expect(a.reservedBills, Money.pesos(41184));
      expect(a.reservedDebtMinimums, Money.pesos(1388));
      expect(a.reservedInstallments, Money.pesos(6348));
      expect(a.emergencyBuffer, Money.pesos(16608));
    });

    test('totals and runway', () {
      expect(a.totalLiquidCash, Money.pesos(110721));
      expect(a.totalExpectedInflow, Money.pesos(46750));
      expect(a.cashRunwayDays, 119);
      expect(a.cashRunwayMonths, 4);
    });
  });

  group('vector B, optimistic, no logged spending', () {
    final SafeToSpendAnalysis b = run(scenario: DecisionScenario.optimistic);

    test('optimistic frees up more and reserves less', () {
      expect(b.safeToSpendToday, Money.pesos(12752));
      expect(b.safeToSpendUntilPayday, Money.pesos(51007));
      expect(b.safeToSave, Money.pesos(9001));
      expect(b.amountReserved, Money.pesos(50712));
    });

    test('the buffer drops to 5 percent and bills lose the 10 percent pad', () {
      expect(b.emergencyBuffer, Money.pesos(5536));
      expect(b.reservedBills, Money.pesos(37440));
    });

    test('the 13th month counts only in the optimistic scenario', () {
      expect(b.totalExpectedInflow, Money.pesos(121000));
    });
  });

  group('vector C, conservative, with recent spending', () {
    // Pinned exactly as the vector generator built them.
    final List<Transaction> txns = <Transaction>[
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amount: Money.pesos(2840),
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
        amount: Money.of(3250, 75),
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
        amount: Money.pesos(6000),
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
      expect(c.safeToSpendToday, Money.pesos(9604));
      expect(c.safeToSpendUntilPayday, Money.pesos(38414));
      expect(c.amountReserved, Money.pesos(65528));
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
            amount: Money.pesos(400),
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
        accounts: SeedData.accounts(testToday),
        transactions: const <Transaction>[],
        bills: SeedData.bills(testToday),
        debtsIOwe: debtsIOwe(),
        installments: SeedData.installments(testToday),
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
      expect(a.safeToSpendUntilPayday + a.safeToSave, Money.pesos(45193));
    });

    test('a day rate never exceeds the whole period', () {
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
      );
      expect(a.safeToSpendToday, lessThanOrEqualTo(a.safeToSpendUntilPayday));
    });
  });

  // -------------------------------------------------------------------------
  // P2.3, protected accounts.
  // -------------------------------------------------------------------------

  /// Vectors for the SHIPPED seed, in which `acc_maya` is set aside.
  ///
  /// These were generated the same way as every figure above: by executing
  /// `archive/prototype-google-ai-studio/src/utils/safeToSpendEngine.ts` under bun against `archive/prototype-google-ai-studio/src/data/
  /// initialData.ts`, on 2026-10-04. Nothing here was worked out by hand or
  /// read off the Dart.
  ///
  /// The generator ran the untouched engine TWICE, because a protected
  /// account is not simply absent:
  ///
  ///   - with `acc_maya` REMOVED from the fixture, which is arithmetically
  ///     exactly what protecting it does to every figure built on the
  ///     spendable subset (the buffer, what is reserved, and the headline);
  ///   - UNMODIFIED, which is what the cash runway must still see, because
  ///     protected money does not stop existing when income stops.
  ///
  /// Each expectation below is tagged with which of the two runs locks it.
  /// Splitting them is the entire point of P2.3 and the thing most likely to
  /// be "tidied" into a single figure by a later reader.
  group('vector D, the shipped seed, with Maya Savings set aside', () {
    SafeToSpendAnalysis seedAsShipped(DecisionScenario scenario) =>
        computeSafeToSpend(
          accounts: SeedData.accounts(testToday),
          transactions: const <Transaction>[],
          bills: SeedData.bills(testToday),
          debtsIOwe: debtsIOwe(),
          installments: SeedData.installments(testToday),
          incomeStreams: SeedData.incomeStreams,
          payday: SeedData.payday,
          scenario: scenario,
          now: pinnedNow,
        );

    test('the seed really does ship one protected account, and only one', () {
      // Guards the guard. If the seed ever went back to all-spendable, every
      // assertion below would pass against the vectors in the groups above
      // and prove nothing at all.
      final List<Account> protectedOnes = SeedData.accounts(
        testToday,
      ).where((Account a) => a.purpose == AccountPurpose.protected).toList();
      expect(protectedOnes.map((Account a) => a.id), <String>['acc_maya']);

      // And the other savings-named account is deliberately NOT protected.
      final Account mari = SeedData.accounts(
        testToday,
      ).firstWhere((Account a) => a.id == 'acc_seabank');
      expect(
        mari.purpose,
        AccountPurpose.spendable,
        reason:
            'MariBank is left spendable on purpose, as a live example that '
            'Salapify does not guess this for the user',
      );
    });

    test('conservative: the headline falls to the generated figures', () {
      final SafeToSpendAnalysis d = seedAsShipped(
        DecisionScenario.conservative,
      );

      // FROM THE maya-removed RUN.
      expect(d.safeToSpendToday, Money.pesos(6840));
      expect(d.safeToSpendUntilPayday, Money.pesos(27359));
      expect(d.safeToSave, Money.pesos(4828));
      expect(d.amountReserved, Money.pesos(63233));
      expect(d.emergencyBuffer, Money.pesos(14313));

      // Untouched by the split, and the maya-removed run agrees: neither
      // bills nor instalments nor debt minimums read the account list.
      expect(d.reservedBills, Money.pesos(41184));
      expect(d.reservedInstallments, Money.pesos(6348));
      expect(d.reservedDebtMinimums, Money.pesos(1388));
    });

    test('conservative: the runway does NOT fall, which is the hard part', () {
      final SafeToSpendAnalysis d = seedAsShipped(
        DecisionScenario.conservative,
      );

      // FROM THE UNMODIFIED RUN, both of them, and this is the assertion
      // that fails if somebody "fixes" the runway to use spendable cash.
      // The maya-removed run says 102 days and 3.4 months; those are the
      // WRONG answers here and are written down so the next reader can see
      // that the difference was deliberate and measured, not overlooked.
      expect(
        d.cashRunwayDays,
        119,
        reason:
            'setting money aside cut this saver from 119 days to 102, which '
            'punishes them for saving: the runway asks how long they last if '
            'income stops, and the emergency fund is exactly that money',
      );
      expect(d.cashRunwayMonths, 4);
      expect(
        d.totalLiquidCash,
        Money.pesos(110721),
        reason:
            'totalLiquidCash keeps its old meaning, every liquid account, so '
            'the runway above has something to divide',
      );
    });

    test('and the answer says how much was held back', () {
      final SafeToSpendAnalysis d = seedAsShipped(
        DecisionScenario.conservative,
      );
      expect(d.protectedCash, Money.pesos(15300));

      // The two halves account for the whole, with nothing unexplained. A
      // screen showing one without the other is showing a figure that does
      // not add up to what the Accounts tab says the person has.
      expect(
        d.totalLiquidCash - d.protectedCash,
        Money.pesos(95421),
        reason: 'the spendable subset from the maya-removed run',
      );
    });

    test('optimistic falls the same way, and keeps the same runway', () {
      final SafeToSpendAnalysis d = seedAsShipped(DecisionScenario.optimistic);

      // maya-removed run.
      expect(d.safeToSpendToday, Money.pesos(9663));
      expect(d.safeToSpendUntilPayday, Money.pesos(38652));
      expect(d.safeToSave, Money.pesos(6821));
      expect(d.amountReserved, Money.pesos(49947));
      expect(d.emergencyBuffer, Money.pesos(4771));

      // unmodified run.
      expect(d.cashRunwayDays, 119);
      expect(d.totalLiquidCash, Money.pesos(110721));
    });

    test('an all-spendable ledger is unchanged, to the peso', () {
      // The other half of the claim this whole file rests on: the new field
      // changes NOTHING for anybody who has not used it. Without this, the
      // groups above could be passing because the parity helper papers over
      // a real behaviour change.
      final SafeToSpendAnalysis a = run(
        scenario: DecisionScenario.conservative,
      );
      expect(a.safeToSpendToday, Money.pesos(9604));
      expect(a.emergencyBuffer, Money.pesos(16608));
      expect(
        a.protectedCash,
        Money.zero,
        reason: 'nothing is set aside, so nothing was held back',
      );
    });
  });
}
