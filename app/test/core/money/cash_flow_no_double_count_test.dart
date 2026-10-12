import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// A LATENT DOUBLE COUNT IN computeCashFlow, caught before it could be built.
///
/// The three outflow buckets do not use the same test for membership:
///
///   operatingOutflows  excludes by CATEGORY only       (debt, investment)
///   investingOutflows  includes by category OR SUBcategory  (mp2)
///   financingOutflows  includes by category OR SUBcategory  (loan)
///
/// So an expense whose CATEGORY names neither debt nor investment, but whose
/// SUBCATEGORY names mp2 or a loan, is claimed by operating AND by one of the
/// other two. `netCashChange` is the sum of all three, so that peso is
/// subtracted twice and the Cash flow tab disagrees with the Performance tab
/// about the same ledger.
///
/// Measured, on a two line ledger of 50,000 in and 6,000 into MP2 filed under
/// a category called Savings: cash really rose by 44,000 and `netCashChange`
/// reported 38,000. With a 10,000 car loan payment filed under Bills: 40,000
/// real against 30,000 reported.
///
/// NO SHIPPED CATEGORY CAN DO THIS TODAY, which is why this is a guard and not
/// a fix. All 21 categories were checked and none collides, the seed ledger
/// does not collide, and the app has no way to create a category, so the
/// two tabs currently agree to the centavo. The clause that would fire,
/// `_has(t.subcategory, 'loan')` in financingOutflows, exists precisely to
/// catch a loan payment filed under some other category, which means the
/// author anticipated the case that breaks. It is dead code and a trap at the
/// same time.
///
/// Changing the engine is a money-meaning change and is the founder's call, so
/// this file does not touch it. What it does is make the trap impossible to
/// spring by accident: add a category or sub-category that collides and the
/// build goes red here, naming it, instead of two tabs quietly disagreeing on
/// somebody's phone.
bool _names(String? s, String needle) =>
    s != null && s.toLowerCase().contains(needle);

/// The membership tests, copied from computeCashFlow deliberately rather than
/// imported. They are private there, and a guard that shared the code under
/// test would move with it and stop guarding anything.
bool _operatingKeeps(String category) =>
    !_names(category, 'debt') && !_names(category, 'investment');

bool _investingClaims(String category, String? subcategory) =>
    _names(category, 'investment') || _names(subcategory, 'mp2');

bool _financingClaims(String category, String? subcategory) =>
    _names(category, 'debt') ||
    _names(category, 'loan') ||
    _names(subcategory, 'loan');

void main() {
  test('no shipped category and sub-category pair lands in two buckets', () {
    final List<String> collisions = <String>[];

    for (final CategoryInfo c in SeedData.categories) {
      if (c.kind != CategoryKind.expense) continue;
      if (!_operatingKeeps(c.name)) continue;
      for (final String sub in c.subcategories) {
        if (_investingClaims(c.name, sub) || _financingClaims(c.name, sub)) {
          collisions.add('"${c.name}" / "$sub"');
        }
      }
    }

    expect(
      collisions,
      isEmpty,
      reason:
          'each of these is counted as an everyday expense AND as investing '
          'or financing, so Cash flow subtracts it twice and stops agreeing '
          'with Performance about the same money. Either rename it so one '
          'bucket claims it, or take the engine fix to the founder as a '
          'money-meaning change',
    );

    // DIRECTIONAL COMPANION. An empty list is also what you get from a loop
    // that never ran, so prove the sweep actually looked at something.
    final int expenseCategories = SeedData.categories
        .where((CategoryInfo c) => c.kind == CategoryKind.expense)
        .length;
    expect(
      expenseCategories,
      greaterThan(5),
      reason: 'the sweep found almost no expense categories to check',
    );
  });

  test('NO shipped expense category reaches the investing bucket at all', () {
    // THE FINDING THAT MATTERS MOST IN THIS FILE, and it is about a feature
    // rather than a bug.
    //
    // `investingOutflows` claims an expense whose category names "investment"
    // or whose sub-category names "mp2". Not one of the thirteen shipped
    // expense categories does either. There is no Savings and Investments
    // category: the list is food, groceries, transport, bills, housing,
    // health, shopping, debt servicing, family support, business ops,
    // entertainment, adjustments, other.
    //
    // So for anybody using the app's own picker, the Investing OUT side of
    // Cash flow is permanently zero, and so is the `investedOutflows` figure
    // the savings rate was changed on 2026-10-06 to credit. The arithmetic of
    // that change is right and nothing can currently feed it.
    //
    // The app's intended path is different and is coherent: Pag-IBIG MP2 is
    // an AccountKind.investment ACCOUNT, and a contribution is a TRANSFER
    // into it. Transfers are excluded from money in and money out, so on that
    // path the savings rate was never harmed in the first place.
    //
    // The shipped SEED takes a third path and it is the wrong one:
    // tx_mp2_contribution is an EXPENSE under "Debt & Loan Servicing", so the
    // demo counts a contribution to savings as debt repayment and reports it
    // in the debt servicing ratio.
    //
    // Which of the three is right is a product decision about how somebody
    // records putting money away, so it is the founder's, not this test's.
    // This asserts the CURRENT state so that whoever changes it has to come
    // back here, read the above, and update the figure deliberately.
    final List<String> reaching = <String>[];
    for (final CategoryInfo c in SeedData.categories) {
      if (c.kind != CategoryKind.expense) continue;
      if (_names(c.name, 'investment')) reaching.add(c.name);
      for (final String sub in c.subcategories) {
        if (_names(sub, 'mp2')) reaching.add('${c.name} / $sub');
      }
    }

    expect(
      reaching,
      isEmpty,
      reason:
          'a shipped expense category now reaches the investing bucket. That '
          'is probably the intended fix, not a regression. Update this test, '
          'and check the savings rate and Cash flow screenshots, because '
          'figures that could never appear before can appear now',
    );

    // DIRECTIONAL. An empty list is also what a loop that never ran returns.
    expect(
      SeedData.categories
          .where((CategoryInfo c) => c.kind == CategoryKind.expense)
          .length,
      greaterThan(5),
    );
  });

  test('the two tabs agree about the seed ledger, to the centavo', () {
    // The reconciliation the guard above protects, stated as the invariant it
    // really is. Transfers are excluded from both sides by design, so what is
    // left has to foot.
    final ReportSet r = buildReports(
      transactions: SeedData.transactions(DateTime.utc(2026, 9, 18)),
      accounts: const <Account>[],
      period: ReportPeriod.monthly,
      now: DateTime.utc(2026, 9, 18),
    );

    expect(
      r.cashFlow.netCashChange,
      closeTo(r.performance.totalIncome - r.performance.totalExpenses, 0.0001),
      reason: 'Cash flow and Performance disagree about one ledger',
    );

    // DIRECTIONAL COMPANION. Two zeroes agree perfectly.
    expect(r.performance.totalExpenses, greaterThan(0));
    expect(r.cashFlow.netCashChange, isNot(0));
  });

  test('and the double count is real, so the guard above is worth having', () {
    // The collision the shipped categories cannot currently produce, built by
    // hand. This test DOCUMENTS the defect rather than asserting it is fixed:
    // if somebody takes the engine change to the founder and makes it, this
    // expectation flips to 44000 and this comment should go with it.
    final ReportSet r = buildReports(
      transactions: <Transaction>[
        Transaction(
          id: 'i1',
          type: TransactionType.income,
          amount: Money.pesos(50000),
          category: 'Salary',
          accountId: 'acc',
          date: '2026-09-10',
          createdAt: 1,
        ),
        Transaction(
          id: 'e1',
          type: TransactionType.expense,
          amount: Money.pesos(6000),
          category: 'Savings',
          subcategory: 'Pag-IBIG MP2',
          accountId: 'acc',
          date: '2026-09-11',
          createdAt: 2,
        ),
      ],
      accounts: const <Account>[],
      period: ReportPeriod.monthly,
      now: DateTime.utc(2026, 9, 18),
    );

    // Cash genuinely rose by 44,000. Performance says so.
    expect(
      r.performance.totalIncome - r.performance.totalExpenses,
      closeTo(44000, 0.0001),
    );

    // Cash flow says 38,000, because the 6,000 is in two buckets.
    expect(
      r.cashFlow.netCashChange,
      closeTo(38000, 0.0001),
      reason:
          'if this now reads 44000 the engine has been fixed, which is good: '
          'update this test and delete the guard above only if the buckets '
          'were made to use one membership test',
    );
    expect(r.cashFlow.operatingOutflows, closeTo(6000, 0.0001));
    expect(r.cashFlow.investingOutflows, closeTo(6000, 0.0001));
  });
}
