import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the Reports engine.
///
/// Every number below was PRINTED by running the prototype's own arithmetic,
/// lifted verbatim out of src/components/ReportsScreen.tsx into
/// app/tool/gen_report_vectors.ts, over app/'s own seed fixture. Nothing here
/// was worked out by hand. To regenerate after a fixture change:
///
///   flutter test test/tool/dump_fixture_test.dart
///   bun app/tool/gen_report_vectors.ts `the printed json`
///
/// The clock is PINNED to 2026-09-18. Every period filter and the run rate
/// read the current date, so an unpinned test passes on the day it is written
/// and fails the next morning.
void main() {
  final DateTime now = DateTime.utc(2026, 9, 18);

  ReportSet build({
    ReportPeriod period = ReportPeriod.monthly,
    ProfileEntity? profile,
  }) {
    return buildReports(
      transactions: SeedData.transactions(),
      accounts: SeedData.accounts,
      period: period,
      now: now,
      profile: profile,
    );
  }

  /// Money is compared to the centavo. A looser tolerance here would let a
  /// real rounding divergence through, which is the one thing these vectors
  /// exist to catch.
  void closeTo(double actual, double expected, String what) {
    expect(actual, moreOrLessEquals(expected, epsilon: 0.005), reason: what);
  }

  group('financial position, which takes no period', () {
    test('all entities', () {
      final FinancialPosition p = build().position;
      closeTo(p.totalAssets, 181970.5, 'totalAssets');
      closeTo(p.totalLiabilities, 399200, 'totalLiabilities');
      closeTo(p.netWorth, -217229.5, 'netWorth');
      closeTo(p.cashEquivalents, 110720.5, 'cashEquivalents');
      closeTo(p.investments, 65000, 'investments');
      closeTo(p.receivables, 6250, 'receivables');
      closeTo(p.creditCards, 4200, 'creditCards');
      closeTo(p.loans, 395000, 'loans');
      expect(p.assetAccounts.length, 8);
      expect(p.liabilityAccounts.length, 3);
    });

    test('personal only', () {
      final FinancialPosition p = build(
        profile: ProfileEntity.personal,
      ).position;
      closeTo(p.totalAssets, 130020.5, 'totalAssets');
      closeTo(p.totalLiabilities, 14200, 'totalLiabilities');
      closeTo(p.netWorth, 115820.5, 'netWorth');
      closeTo(p.cashEquivalents, 58770.5, 'cashEquivalents');
      closeTo(p.loans, 10000, 'loans');
      expect(p.assetAccounts.length, 5);
      expect(p.liabilityAccounts.length, 2);
    });

    test('business only', () {
      final FinancialPosition p = build(
        profile: ProfileEntity.business,
      ).position;
      closeTo(p.totalAssets, 12400, 'totalAssets');
      closeTo(p.totalLiabilities, 0, 'totalLiabilities');
      closeTo(p.netWorth, 12400, 'netWorth');
      expect(p.assetAccounts.length, 1);
      expect(p.liabilityAccounts.isEmpty, isTrue);
    });

    test('net worth is assets minus liabilities, in every scope', () {
      // An invariant rather than a vector. It cannot be satisfied by an engine
      // that computes two of the three numbers correctly and the third from a
      // different set of accounts, which is the failure a per-figure vector
      // would miss.
      for (final ProfileEntity? scope in <ProfileEntity?>[
        null,
        ProfileEntity.personal,
        ProfileEntity.household,
        ProfileEntity.business,
        ProfileEntity.sideHustle,
      ]) {
        final FinancialPosition p = build(profile: scope).position;
        closeTo(
          p.netWorth,
          p.totalAssets - p.totalLiabilities,
          'net worth disagrees with its own parts for $scope',
        );
      }
    });
  });

  group('performance, all entities, this month', () {
    late FinancialPerformance perf;
    setUp(() => perf = build().performance);

    test('the income statement', () {
      closeTo(perf.totalIncome, 51000, 'totalIncome');
      closeTo(perf.totalExpenses, 24274.75, 'totalExpenses');
      closeTo(perf.netSurplus, 26725.25, 'netSurplus');
    });

    test('the business segment', () {
      closeTo(perf.businessRevenue, 18500, 'businessRevenue');
      closeTo(perf.businessExpenses, 3149, 'businessExpenses');
      closeTo(perf.businessNetProfit, 15351, 'businessNetProfit');
    });

    test('the ratios, in percent rather than fractions', () {
      closeTo(perf.savingsRate, 52.40245098039216, 'savingsRate');
      closeTo(perf.debtServicingExpenses, 4950, 'debtServicingExpenses');
      closeTo(perf.debtServiceRatio, 9.705882352941178, 'debtServiceRatio');
    });

    test('the month-end run rate', () {
      closeTo(perf.projectedIncome, 85000, 'projectedIncome');
      closeTo(perf.projectedExpenses, 40457.916666666664, 'projectedExpenses');
      closeTo(perf.projectedSurplus, 44542.083333333336, 'projectedSurplus');
    });
  });

  group('cash flow, all entities, this month', () {
    late CashFlow flow;
    setUp(() => flow = build().cashFlow);

    test('operating', () {
      closeTo(flow.operatingInflows, 51000, 'operatingInflows');
      closeTo(flow.operatingOutflows, 19324.75, 'operatingOutflows');
      closeTo(flow.netOperating, 31675.25, 'netOperating');
    });

    test('investing is zero, and that is the fixture rather than a bug', () {
      // Nothing in the fixture is income categorised as investment, dividend
      // or interest, and nothing is an expense categorised as investment or
      // sub-categorised mp2. The prototype prints zeros here too. Asserted
      // rather than skipped, so the day a vector makes this non-zero the test
      // says so instead of quietly agreeing.
      closeTo(flow.investingInflows, 0, 'investingInflows');
      closeTo(flow.investingOutflows, 0, 'investingOutflows');
      closeTo(flow.netInvesting, 0, 'netInvesting');
    });

    test('financing', () {
      closeTo(flow.financingInflows, 0, 'financingInflows');
      closeTo(flow.financingOutflows, 4950, 'financingOutflows');
      closeTo(flow.netFinancing, -4950, 'netFinancing');
    });

    test('transfers are counted and then left out of the net change', () {
      expect(flow.transfersCount, 1);
      closeTo(flow.transfersVolume, 5000, 'transfersVolume');
      closeTo(flow.netCashChange, 26725.25, 'netCashChange');

      // The invariant that makes the point: the 5,000 transfer is visible and
      // contributes nothing. Moving your own money between your own accounts
      // is not cash entering or leaving anything you own.
      closeTo(
        flow.netCashChange,
        flow.netOperating + flow.netInvesting + flow.netFinancing,
        'the net change picked up something outside the three sections',
      );
    });
  });

  group('the period filter', () {
    test('every period selects the count the prototype selects', () {
      const Map<ReportPeriod, int> expected = <ReportPeriod, int>{
        ReportPeriod.daily: 1,
        ReportPeriod.weekly: 9,
        ReportPeriod.monthly: 14,
        ReportPeriod.quarterly: 14,
        ReportPeriod.semiAnnually: 14,
        ReportPeriod.annually: 14,
      };
      expected.forEach((ReportPeriod period, int count) {
        expect(
          build(period: period).transactions.length,
          count,
          reason: 'the $period window selected the wrong entries',
        );
      });
    });

    test('today sees only today', () {
      final ReportSet r = build(period: ReportPeriod.daily);
      closeTo(r.performance.totalExpenses, 180, 'totalExpenses');
      closeTo(r.performance.totalIncome, 0, 'totalIncome');
      expect(r.transactions.single.date, '2026-09-18');
    });

    test('excluded and duplicate entries never reach a total', () {
      // tx_excluded_double is a 2,840 Meralco bill marked excluded because it
      // was charged twice. It is in the fixture, it is on the Activity screen
      // struck through, and it must not be in this sum. The same 2,840 DOES
      // appear once, from tx_meralco, which is what makes this worth a test:
      // a double count and a correct count differ by exactly the figure a
      // careless reader would expect to see.
      final ReportSet r = build();
      expect(
        r.transactions.any((Transaction t) => t.id == 'tx_excluded_double'),
        isFalse,
        reason: 'an excluded entry reached the report',
      );
      final double bills = r.expenseByCategory
          .firstWhere(
            (CategoryBreakdown c) => c.category == 'Bills & Utilities',
          )
          .total;
      closeTo(bills, 2840, 'the excluded Meralco bill was counted twice');
    });
  });

  group('the profile filter', () {
    test('personal, this month', () {
      final FinancialPerformance p = build(
        profile: ProfileEntity.personal,
      ).performance;
      closeTo(p.totalIncome, 32500, 'totalIncome');
      closeTo(p.totalExpenses, 11835, 'totalExpenses');
      closeTo(p.netSurplus, 20665, 'netSurplus');
      closeTo(p.savingsRate, 63.58461538461538, 'savingsRate');
      closeTo(p.debtServiceRatio, 15.230769230769232, 'debtServiceRatio');
    });

    test('business, this year', () {
      final ReportSet r = build(
        period: ReportPeriod.annually,
        profile: ProfileEntity.business,
      );
      expect(r.transactions.length, 3);
      closeTo(r.performance.totalIncome, 18500, 'totalIncome');
      closeTo(r.performance.totalExpenses, 3149, 'totalExpenses');
      closeTo(r.performance.businessNetProfit, 15351, 'businessNetProfit');
    });

    test('an account with no profile shows under every entity', () {
      // The asymmetry worth locking: a transaction with no profile counts as
      // personal, an ACCOUNT with no profile passes every filter. Both are the
      // prototype's, and a future tidy-up that makes them consistent would
      // make unclassified wallets vanish from most reports.
      const Account orphan = Account(
        id: 'acc_orphan',
        name: 'Unsorted Wallet',
        kind: AccountKind.cash,
        institution: 'Cash',
        balance: 1000,
        monogram: 'U',
      );
      for (final ProfileEntity scope in ProfileEntity.values) {
        final List<Account> kept = filterAccountsByProfile(<Account>[
          orphan,
        ], scope);
        expect(kept, hasLength(1), reason: 'the orphan vanished under $scope');
      }
    });
  });

  group('category breakdown', () {
    test('expenses, biggest first, with sub-categories', () {
      final List<CategoryBreakdown> rows = build().expenseByCategory;

      expect(rows.map((CategoryBreakdown c) => c.category).toList(), <String>[
        'Family Support & Remittance',
        'Debt & Loan Servicing',
        'Groceries',
        'Housing & Rent',
        'Bills & Utilities',
        'Shopping & Personal',
        'Business & Freelance Ops',
        'Food & Dining',
        'Transport & Commute',
      ], reason: 'the ordering is biggest first');

      final CategoryBreakdown debt = rows[1];
      closeTo(debt.total, 4950, 'debt total');
      expect(debt.count, 2);
      closeTo(debt.percentage, 20.391559, 'debt percentage');
      expect(debt.subcategories, hasLength(2));

      final CategoryBreakdown food = rows.firstWhere(
        (CategoryBreakdown c) => c.category == 'Food & Dining',
      );
      closeTo(food.total, 465, 'food total');
      expect(food.count, 2);
      closeTo(
        food.subcategories
            .firstWhere(
              (SubcategoryBreakdown s) => s.name == 'Coffee & Milk Tea',
            )
            .percentageOfCategory,
        38.709677,
        'coffee share of Food & Dining',
      );
    });

    test('income', () {
      final List<CategoryBreakdown> rows = build().incomeByCategory;
      expect(rows.map((CategoryBreakdown c) => c.category).toList(), <String>[
        'Salary & Compensation',
        'Business Revenue',
      ]);
      closeTo(rows[0].percentage, 63.72549, 'salary share');
      closeTo(rows[1].percentage, 36.27451, 'business revenue share');
    });

    test('the percentages of one side add up to a hundred', () {
      for (final List<CategoryBreakdown> rows in <List<CategoryBreakdown>>[
        build().expenseByCategory,
        build().incomeByCategory,
      ]) {
        final double sum = rows.fold<double>(
          0,
          (double s, CategoryBreakdown c) => s + c.percentage,
        );
        closeTo(sum, 100, 'the shares do not account for the whole');
      }
    });

    test('a category total equals its sub-categories', () {
      for (final CategoryBreakdown c in build().expenseByCategory) {
        final double subs = c.subcategories.fold<double>(
          0,
          (double s, SubcategoryBreakdown x) => s + x.total,
        );
        closeTo(subs, c.total, '${c.category} disagrees with its own parts');
      }
    });
  });

  group('the whole report agrees with itself', () {
    test(
      'income minus expenses is the surplus, and cash flow says the same',
      () {
        for (final ReportPeriod period in ReportPeriod.values) {
          final ReportSet r = build(period: period);
          closeTo(
            r.performance.netSurplus,
            r.performance.totalIncome - r.performance.totalExpenses,
            'surplus disagrees with its parts in $period',
          );

          // Operating plus investing plus financing has to reach the same place
          // as income minus expenses, because they sort the SAME entries. They
          // are computed by entirely separate filters, so this catches a
          // category rule drifting in one of them and not the other.
          closeTo(
            r.cashFlow.netCashChange,
            r.performance.netSurplus,
            'the two views of the same money disagree in $period',
          );
        }
      },
    );

    test('every breakdown total equals the performance total', () {
      for (final ReportPeriod period in ReportPeriod.values) {
        final ReportSet r = build(period: period);
        final double expenses = r.expenseByCategory.fold<double>(
          0,
          (double s, CategoryBreakdown c) => s + c.total,
        );
        final double income = r.incomeByCategory.fold<double>(
          0,
          (double s, CategoryBreakdown c) => s + c.total,
        );
        closeTo(expenses, r.performance.totalExpenses, 'expenses in $period');
        closeTo(income, r.performance.totalIncome, 'income in $period');
      }
    });
  });
}
