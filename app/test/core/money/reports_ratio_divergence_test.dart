import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/models/models.dart';

/// Where Salapify's two published ratios DEPART from the prototype, on purpose.
///
/// Founder approved both, 2026-10-06. Each is a prototype behaviour that is
/// arithmetically correct and reads wrong for the person it describes, which
/// is the same shape as the eleven differences already recorded on PR 473.
///
/// ## Why this file exists at all, and it is not a formality
///
/// `reports_golden_test.dart` PASSED UNCHANGED through both changes. Not
/// because the changes are harmless: because the seed fixture contains no
/// investment outflow and no repayment inflow, so both new terms are zero and
/// the formulas collapse to the prototype's. The vectors proved parity on the
/// cases somebody thought to include and nothing whatever about these two.
///
/// That is the exact trap the porting-money-logic skill names. A fixture that
/// cannot reach a branch cannot defend it, and a green replay over such a
/// fixture is the most misleading possible evidence. So the fixtures here are
/// built to reach it.
void main() {
  final DateTime now = DateTime.utc(2026, 9, 18);

  Transaction tx({
    required String id,
    required TransactionType type,
    required double amount,
    required String category,
    String? subcategory,
  }) => Transaction(
    id: id,
    type: type,
    amount: Money.fromDouble(amount),
    category: category,
    subcategory: subcategory,
    accountId: 'acc',
    date: '2026-09-10',
    createdAt: 1,
  );

  FinancialPerformance perf(List<Transaction> txs) => buildReports(
    transactions: txs,
    accounts: const <Account>[],
    period: ReportPeriod.monthly,
    now: now,
  ).performance;

  group('money moved into an investment counts as SAVED, not spent', () {
    // THE PROTOTYPE'S BEHAVIOUR, and why it is wrong rather than merely
    // different. savingsRate is (income - allExpenses) / income, and
    // `totalExpenses` counts every expense transaction, Pag-IBIG MP2 included.
    // So putting 10,000 into MP2 REDUCED the savings rate by the act of
    // saving, while the Cash flow tab pulled the same 10,000 out of spending
    // and into investing. One ledger, two tabs, opposite verdicts, and the
    // discouraging one is the one read first.

    final List<Transaction> ledger = <Transaction>[
      tx(
        id: 'i1',
        type: TransactionType.income,
        amount: 50000,
        category: 'Salary',
      ),
      tx(
        id: 'e1',
        type: TransactionType.expense,
        amount: 30000,
        category: 'Groceries',
      ),
      tx(
        id: 'e2',
        type: TransactionType.expense,
        amount: 10000,
        category: 'Investment',
      ),
    ];

    test('the investment is counted as saved', () {
      final FinancialPerformance f = perf(ledger);
      // Kept 10,000 in cash, put 10,000 away. 20,000 of 50,000.
      expect(f.savingsRate, closeTo(40, 0.0001));
    });

    test('the prototype would have said 20, which is the defect', () {
      // Stated as its own assertion so the divergence is MEASURED rather than
      // described in a comment. (50,000 - 40,000) / 50,000 is the old answer.
      final FinancialPerformance f = perf(ledger);
      expect(
        f.netSurplus / f.totalIncome * 100,
        closeTo(20, 0.0001),
        reason:
            'the old formula is still reachable from the stored figures, '
            'and it is the number the savings rate must no longer be',
      );
      expect(f.savingsRate, isNot(closeTo(20, 0.0001)));
    });

    test(
      '"You kept" still reports CASH kept, which is a different question',
      () {
        // The directional half for the rename. If keptRate had simply been
        // pointed at the new savingsRate, the card would claim the person kept
        // 40% while its own hero figure shows 10,000 of 50,000.
        final FinancialPerformance f = perf(ledger);
        expect(f.keptRate, closeTo(20, 0.0001));
        expect(f.netSurplus, closeTo(10000, 0.0001));
      },
    );

    test('with nothing invested the two rates agree, as they always did', () {
      // Without this, every assertion above is satisfied by a formula that
      // simply inflates the savings rate for everybody.
      final FinancialPerformance f = perf(<Transaction>[
        tx(
          id: 'i1',
          type: TransactionType.income,
          amount: 50000,
          category: 'Salary',
        ),
        tx(
          id: 'e1',
          type: TransactionType.expense,
          amount: 30000,
          category: 'Groceries',
        ),
      ]);
      expect(f.savingsRate, closeTo(40, 0.0001));
      expect(f.keptRate, closeTo(40, 0.0001));
      expect(f.investedOutflows, 0);
    });

    test('an MP2 SUBCATEGORY counts too, not just the category', () {
      // The filter matches computeCashFlow's exactly, and that second clause
      // is the one a narrower test would miss.
      final FinancialPerformance f = perf(<Transaction>[
        tx(
          id: 'i1',
          type: TransactionType.income,
          amount: 50000,
          category: 'Salary',
        ),
        tx(
          id: 'e1',
          type: TransactionType.expense,
          amount: 10000,
          category: 'Savings',
          subcategory: 'MP2',
        ),
      ]);
      expect(f.investedOutflows, closeTo(10000, 0.0001));
    });
  });

  group('money repaid to you is not money earned', () {
    // `applyDebtPayment` writes a collected repayment as INCOME under
    // 'Receivables & Repayments' (core/money/debt.dart). That is right for the
    // ledger, and the balance sheet already treats the same event correctly as
    // an asset. It is not earnings, so including it in the denominator made
    // both ratios read BETTER in any month a cousin paid you back, which is
    // the month they describe least well.

    final List<Transaction> ledger = <Transaction>[
      tx(
        id: 'i1',
        type: TransactionType.income,
        amount: 50000,
        category: 'Salary',
      ),
      tx(
        id: 'i2',
        type: TransactionType.income,
        amount: 50000,
        category: 'Receivables & Repayments',
      ),
      tx(
        id: 'e1',
        type: TransactionType.expense,
        amount: 10000,
        category: 'Debt & Loan Servicing',
      ),
    ];

    test('debt servicing divides by what was EARNED', () {
      final FinancialPerformance f = perf(ledger);
      // 10,000 against 50,000 earned, not against 100,000 of money that
      // happened to arrive.
      expect(f.debtServiceRatio, closeTo(20, 0.0001));
    });

    test('the savings rate cannot exceed 100 because money came back', () {
      // THE DEFECT THIS FILE MISSED ON ITS FIRST PASS, found by a QA review.
      //
      // Taking the repayment out of the DENOMINATOR while leaving it inside
      // `netSurplus` on the numerator subtracts the same peso from the bottom
      // and leaves it on the top. This exact ledger printed 180.0% on a field
      // documented as "Percent, 0 to 100".
      //
      // The group above asserted `debtServiceRatio` on this fixture and never
      // asserted `savingsRate`, which is the whole reason it stayed green.
      final FinancialPerformance f = perf(ledger);

      // Earned 50,000. Spent 10,000 of it. Nothing invested.
      expect(f.savingsRate, closeTo(80, 0.0001));
      expect(
        f.savingsRate,
        lessThanOrEqualTo(100),
        reason: 'a rate over 100 is arithmetic escaping, not a good month',
      );
    });

    test('a repayment far larger than earnings still reports sanely', () {
      // The shape that made it absurd rather than merely wrong: a small salary
      // and a large sum coming back reads as a four figure percentage.
      final FinancialPerformance f = perf(<Transaction>[
        tx(
          id: 'i1',
          type: TransactionType.income,
          amount: 2000,
          category: 'Salary',
        ),
        tx(
          id: 'i2',
          type: TransactionType.income,
          amount: 30000,
          category: 'Receivables & Repayments',
        ),
      ]);
      // Earned 2,000, spent nothing, so every peso earned was kept.
      expect(f.savingsRate, closeTo(100, 0.0001));
    });

    test('the repayment is still counted as money IN', () {
      // It really did arrive, so "Money in" must not quietly shrink. The fix
      // is to the ratios, not to the cash.
      final FinancialPerformance f = perf(ledger);
      expect(f.totalIncome, closeTo(100000, 0.0001));
      expect(f.repaymentInflows, closeTo(50000, 0.0001));
    });

    test('the prototype would have said 10, which is the defect', () {
      final FinancialPerformance f = perf(ledger);
      expect(
        f.debtServicingExpenses / f.totalIncome * 100,
        closeTo(10, 0.0001),
        reason: 'halved by a repayment, which is the reading being replaced',
      );
      expect(f.debtServiceRatio, isNot(closeTo(10, 0.0001)));
    });

    test('with no repayment the denominator is unchanged', () {
      // The directional half. Every assertion above also passes if the
      // denominator were made smaller for everybody.
      final FinancialPerformance f = perf(<Transaction>[
        tx(
          id: 'i1',
          type: TransactionType.income,
          amount: 50000,
          category: 'Salary',
        ),
        tx(
          id: 'e1',
          type: TransactionType.expense,
          amount: 10000,
          category: 'Debt & Loan Servicing',
        ),
      ]);
      expect(f.debtServiceRatio, closeTo(20, 0.0001));
      expect(f.repaymentInflows, 0);
    });

    test(
      'a month that is ONLY a repayment reports no rate, not a flattering one',
      () {
        // Earned income is zero, so there is nothing to take a ratio of. The
        // guard has to be on EARNED income rather than on total income, and this
        // is the case that tells the two apart: totalIncome is 50,000 here, so a
        // `totalIncome > 0` check would sail through and divide by zero.
        final FinancialPerformance f = perf(<Transaction>[
          tx(
            id: 'i1',
            type: TransactionType.income,
            amount: 50000,
            category: 'Receivables & Repayments',
          ),
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 10000,
            category: 'Debt & Loan Servicing',
          ),
        ]);
        expect(f.debtServiceRatio, 0);
        expect(f.savingsRate, 0);
        expect(f.debtServiceRatio.isFinite, isTrue);
        expect(f.savingsRate.isFinite, isTrue);
      },
    );
  });
}
