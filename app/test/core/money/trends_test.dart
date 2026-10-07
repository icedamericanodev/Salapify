// Reports over time. The money is computed by the existing Reports engine;
// what this file pins is that running it over earlier windows tells the SAME
// story as the screen beside it, and never counts one entry twice.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/core/money/trends.dart';
import 'package:salapify/models/models.dart';

int _seq = 0;

Transaction _tx(
  String date,
  double amount, {
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.confirmed,
}) => Transaction(
  id: 't${_seq++}',
  type: type,
  amount: Money.fromDouble(amount),
  category: 'Groceries',
  accountId: 'a',
  date: date,
  createdAt: 0,
  status: status,
);

int _c(double pesos) => (pesos * 100).round();

void main() {
  final DateTime now = DateTime(2026, 9, 18);

  final List<Transaction> ledger = <Transaction>[
    _tx('2026-07-05', 30000, type: TransactionType.income),
    _tx('2026-07-10', 1200.10),
    _tx('2026-08-03', 40000, type: TransactionType.income),
    _tx('2026-08-04', 800.25),
    _tx('2026-08-17', 1500),
    _tx('2026-08-29', 2000),
    _tx('2026-09-01', 51000, type: TransactionType.income),
    _tx('2026-09-02', 950.50),
    _tx('2026-09-18', 300),
    // Scheduled, later this month: in "This month", not yet on the pace line.
    _tx('2026-09-25', 700),
  ];

  group('the current month IS the This month figure', () {
    test('in and out match buildReports to the centavo', () {
      final TrendSet t = buildTrends(transactions: ledger, now: now);
      final FinancialPerformance f = buildReports(
        transactions: ledger,
        accounts: const <Account>[],
        period: ReportPeriod.monthly,
        now: now,
      ).performance;
      expect(_c(t.months.last.expenses), _c(f.totalExpenses));
      expect(_c(t.months.last.income), _c(f.totalIncome));
      // DIRECTIONAL: a real figure, not two zeros agreeing.
      expect(_c(t.months.last.expenses), _c(950.50 + 300 + 700));
    });

    test('a past month matches running This month on that month', () {
      final TrendSet t = buildTrends(transactions: ledger, now: now);
      final FinancialPerformance august = buildReports(
        transactions: ledger,
        accounts: const <Account>[],
        period: ReportPeriod.monthly,
        now: DateTime(2026, 8, 31),
      ).performance;
      final MonthTotals m = t.months.singleWhere(
        (MonthTotals m) => m.month == 8,
      );
      expect(_c(m.expenses), _c(august.totalExpenses));
      expect(_c(m.income), _c(august.totalIncome));
    });

    test('months before the first entry are left off, oldest first', () {
      final TrendSet t = buildTrends(transactions: ledger, now: now);
      expect(t.months.map((MonthTotals m) => m.month).toList(), <int>[7, 8, 9]);
    });

    test('a discounted entry counts nowhere, here as on the screen', () {
      final TrendSet t = buildTrends(
        transactions: <Transaction>[
          ...ledger,
          _tx('2026-08-10', 99999, status: TransactionStatus.excluded),
        ],
        now: now,
      );
      final MonthTotals aug = t.months.singleWhere(
        (MonthTotals m) => m.month == 8,
      );
      expect(_c(aug.expenses), _c(800.25 + 1500 + 2000));
    });
  });

  group('an unreadable date is counted nowhere, and said so', () {
    test('not once per month', () {
      // `filterByPeriod` keeps an unparseable date on purpose, which is
      // right for ONE period and would count this 5,000 in all six here.
      final TrendSet t = buildTrends(
        transactions: <Transaction>[...ledger, _tx('not a date', 5000)],
        now: now,
      );
      final double total = t.months.fold<double>(
        0,
        (double a, MonthTotals m) => a + m.expenses,
      );
      expect(
        _c(total),
        _c(1200.10 + 800.25 + 1500 + 2000 + 950.50 + 300 + 700),
        reason: 'an undated entry was counted in the trend',
      );
      expect(t.undated, 1);
    });
  });

  group('spending pace', () {
    test('runs day by day to today, and stops there', () {
      final SpendingPace p = buildTrends(transactions: ledger, now: now).pace;
      expect(p.day, 18);
      expect(p.thisMonth[0], 0);
      expect(_c(p.thisMonth[1]), _c(950.50));
      // The 25th is scheduled, not spent.
      expect(_c(p.spentSoFar), _c(950.50 + 300));
    });

    test('the line plus what is dated later IS the month figure', () {
      // The line stops at today and "Money out" does not, so the two differ
      // by exactly the spending dated later this month, and the screen says
      // so. This pins that the difference has a home, to the centavo.
      final TrendSet t = buildTrends(transactions: ledger, now: now);
      expect(_c(t.pace.scheduledLater), _c(700));
      expect(
        _c(t.pace.spentSoFar + t.pace.scheduledLater),
        _c(t.months.last.expenses),
      );
    });

    test('last month runs its whole length and foots to its total', () {
      final SpendingPace p = buildTrends(transactions: ledger, now: now).pace;
      expect(p.lastMonth, hasLength(31));
      expect(_c(p.lastMonth.last), _c(800.25 + 1500 + 2000));
    });

    test('compares the same day of each month', () {
      final SpendingPace p = buildTrends(transactions: ledger, now: now).pace;
      // August to the 18th: 800.25 + 1,500. September to the 18th: 1,250.50.
      expect(_c(p.lastMonthSameDay), _c(800.25 + 1500));
      expect(_c(p.difference), _c(950.50 + 300 - 800.25 - 1500));
    });

    test('the 31st compares against the last day of a shorter month', () {
      final SpendingPace p = buildTrends(
        transactions: <Transaction>[
          _tx('2026-02-28', 1000),
          _tx('2026-03-31', 400),
        ],
        now: DateTime(2026, 3, 31),
      ).pace;
      expect(p.lastMonth, hasLength(28));
      expect(_c(p.lastMonthSameDay), _c(1000));
    });

    test('a first month of use has nothing to compare against', () {
      final SpendingPace p = buildTrends(
        transactions: <Transaction>[_tx('2026-09-02', 500)],
        now: now,
      ).pace;
      expect(p.hasLastMonth, isFalse);
    });
  });
}
