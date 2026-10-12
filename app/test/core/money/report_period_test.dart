import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Stepping Reports back a period, and the entries behind a category bar
/// (D31). The rule that matters most: every dated entry lands in exactly one
/// period as you step back, never two and never none, and a drill-down list
/// always adds up to the bar it opened from.
void main() {
  Transaction on(String date, {String id = '', int createdAt = 0}) =>
      Transaction(
        id: id.isEmpty ? 'tx_$date' : id,
        type: TransactionType.expense,
        amount: const Money.pesos(10),
        category: 'Food & Dining',
        accountId: 'acc_cash',
        date: date,
        createdAt: createdAt,
      );

  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  group('periodAnchor', () {
    test('a month back from the 31st is the month before, not the same '
        'month again', () {
      final DateTime now = DateTime(2026, 3, 31, 15);
      expect(periodAnchor(ReportPeriod.monthly, now, 1), DateTime(2026, 2, 1));
      expect(periodAnchor(ReportPeriod.monthly, now, 3), DateTime(2025, 12, 1));
      expect(
        periodAnchor(ReportPeriod.quarterly, now, 1),
        DateTime(2025, 12, 1),
      );
      expect(periodAnchor(ReportPeriod.annually, now, 2), DateTime(2024));
    });

    for (final DateTime now in <DateTime>[
      DateTime(2026, 10, 12, 15, 30),
      // Midnight, the shape every pinned test clock has.
      DateTime(2026, 10, 12),
    ]) {
      for (final ReportPeriod period in <ReportPeriod>[
        ReportPeriod.daily,
        ReportPeriod.weekly,
        ReportPeriod.monthly,
      ]) {
        test('$period at ${now.hour}h: every day of the last 60 lands in '
            'exactly one period stepping back', () {
          for (int d = 0; d < 60; d++) {
            final Transaction t = on(
              iso(DateTime(now.year, now.month, now.day - d)),
            );
            int hits = 0;
            for (int back = 0; back < 70; back++) {
              final DateTime a = periodAnchor(period, now, back);
              if (filterByPeriod(<Transaction>[t], period, a).isNotEmpty) {
                hits++;
              }
            }
            expect(hits, 1, reason: '${t.date} landed in $hits periods');
          }
        });
      }
    }
  });

  group('periodLabel', () {
    final DateTime now = DateTime(2026, 10, 12, 15);
    test('now reads as now, the past as dates', () {
      expect(periodLabel(ReportPeriod.monthly, now, 0), 'This month');
      expect(periodLabel(ReportPeriod.weekly, now, 0), 'Last 7 days');
      expect(periodLabel(ReportPeriod.monthly, now, 1), 'Sep 2026');
      expect(periodLabel(ReportPeriod.daily, now, 1), 'Yesterday');
      expect(periodLabel(ReportPeriod.daily, now, 2), 'Sat, Oct 10');
      expect(periodLabel(ReportPeriod.weekly, now, 1), 'Sep 29 to Oct 5');
      expect(periodLabel(ReportPeriod.quarterly, now, 1), 'Jul to Sep 2026');
      expect(periodLabel(ReportPeriod.semiAnnually, now, 1), 'Jan to Jun 2026');
      expect(periodLabel(ReportPeriod.annually, now, 1), '2025');
    });

    test('the week label names exactly the dates the window counts', () {
      final DateTime a = periodAnchor(ReportPeriod.weekly, now, 1);
      expect(
        filterByPeriod(<Transaction>[on('2026-09-29')], ReportPeriod.weekly, a),
        hasLength(1),
      );
      expect(
        filterByPeriod(<Transaction>[on('2026-09-28')], ReportPeriod.weekly, a),
        isEmpty,
      );
      expect(
        filterByPeriod(<Transaction>[on('2026-10-05')], ReportPeriod.weekly, a),
        hasLength(1),
      );
    });
  });

  test('stepping back stops at the period holding the oldest entry', () {
    final DateTime now = DateTime(2026, 10, 12);
    final DateTime oldest = DateTime(2026, 8, 20);
    expect(canStepBack(ReportPeriod.monthly, now, 0, oldest), isTrue);
    expect(canStepBack(ReportPeriod.monthly, now, 1, oldest), isTrue);
    expect(
      canStepBack(ReportPeriod.monthly, now, 2, oldest),
      isFalse,
      reason: 'August holds the oldest entry; July would be empty',
    );
    expect(canStepBack(ReportPeriod.monthly, now, 0, null), isFalse);
  });

  test('every breakdown row equals the entries listed behind it, to the '
      'centavo, for spending and income, on the lived-in example', () {
    final FinancialState s = FinancialState(clock: DateTime(2026, 9, 18));
    addTearDown(s.dispose);
    final List<Transaction> withOdd = <Transaction>[
      ...s.transactions,
      // No category at all: must land on "Uncategorized" in both places.
      const Transaction(
        id: 'tx_blank',
        type: TransactionType.expense,
        amount: Money.pesos(33),
        category: '',
        accountId: 'acc_cash',
        date: '2026-09-17',
        createdAt: 1,
      ),
    ];
    for (final ReportPeriod period in ReportPeriod.values) {
      final ReportSet r = buildReports(
        transactions: withOdd,
        accounts: s.accounts,
        period: period,
        now: s.now,
      );
      for (final TransactionType type in <TransactionType>[
        TransactionType.expense,
        TransactionType.income,
      ]) {
        for (final CategoryBreakdown row in computeCategoryBreakdown(
          r.transactions,
          type,
        )) {
          final List<Transaction> list = entriesInCategory(
            r.transactions,
            type,
            row.category,
          );
          final Money sum = list.fold(
            Money.zero,
            (Money a, Transaction t) => a + t.amount,
          );
          expect(list.length, row.count, reason: '$period ${row.category}');
          expect(
            sum,
            Money.fromDouble(row.total),
            reason: '$period ${row.category}',
          );
        }
      }
    }
    expect(
      entriesInCategory(
        withOdd,
        TransactionType.expense,
        'Uncategorized',
      ).single.id,
      'tx_blank',
    );
  });
}
