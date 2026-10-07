// Pure tests for the monthly net worth history: the upsert, the "last month"
// lookup, the trend, and the store-shaped recordNetWorthSnapshot. Every literal
// here is either a month string or a value we put in, so nothing is asserted
// against a number this feature computes on its own; where a net worth is
// involved it is compared to netWorthParts, the golden-locked source.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/net_worth_history.dart';
import 'package:salapify/money/statements.dart' show netWorthParts;
import 'package:salapify/widgets/net_worth_sparkline.dart'
    show netWorthSparkDomain;

void main() {
  group('netWorthMonthKey', () {
    test('is zero-padded YYYY-MM', () {
      expect(netWorthMonthKey(DateTime(2026, 8, 13)), '2026-08');
      expect(netWorthMonthKey(DateTime(2026, 1, 1)), '2026-01');
      expect(netWorthMonthKey(DateTime(9, 3, 1)), '0009-03');
    });
  });

  group('netWorthWindow', () {
    // Four recorded months, ascending, plus a live current month. The live
    // figure is deliberately different from any recorded value so the "last
    // point is live, not a stored snapshot" rule is visible.
    final history = [
      {'month': '2026-03', 'value': 100000},
      {'month': '2026-04', 'value': 110000},
      {'month': '2026-05', 'value': 120000},
      {'month': '2026-06', 'value': 130000},
    ];

    test('appends the live current month as the final point', () {
      final all = netWorthWindow(history, '2026-07', 145000);
      expect(all.length, 5);
      expect(all.last, (month: '2026-07', value: 145000.0));
      // The recorded months come through in order, untouched.
      expect(all.first, (month: '2026-03', value: 100000.0));
    });

    test('replaces the current month snapshot with the live figure', () {
      // A snapshot already recorded for the current month must NOT be plotted;
      // the live figure stands in for it, so the last point matches the hero.
      final withCurrent = [
        ...history,
        {'month': '2026-07', 'value': 140000},
      ];
      final all = netWorthWindow(withCurrent, '2026-07', 145000);
      expect(all.where((p) => p.month == '2026-07').length, 1);
      expect(all.last, (month: '2026-07', value: 145000.0));
    });

    test('a period window keeps only the most recent months, incl. today', () {
      final threeM = netWorthWindow(history, '2026-07', 145000, months: 3);
      expect(threeM.length, 3);
      expect(threeM.first.month, '2026-05');
      expect(threeM.last, (month: '2026-07', value: 145000.0));
    });

    test('a window larger than the data keeps everything', () {
      final all = netWorthWindow(history, '2026-07', 145000, months: 24);
      expect(all.length, 5);
    });

    test('thin data returns exactly what exists, never an invented point', () {
      // No history at all: one point, the live figure. The screen shows a
      // not-enough-history state off this; it must not fabricate a second.
      final oneM = netWorthWindow(const [], '2026-07', 145000, months: 1);
      expect(oneM, [(month: '2026-07', value: 145000.0)]);
    });
  });

  group('netWorthStats', () {
    test('is the high, low and mean of the points', () {
      final points = netWorthWindow([
        {'month': '2026-04', 'value': 110000},
        {'month': '2026-05', 'value': 130000},
      ], '2026-06', 120000);
      final s = netWorthStats(points)!;
      expect(s.high, 130000);
      expect(s.low, 110000);
      // (110000 + 130000 + 120000) / 3
      expect(s.avg, closeTo(120000, 0.0001));
    });

    test('is null for no points', () {
      expect(netWorthStats(const []), isNull);
    });
  });

  group('upsertNetWorthSnapshot', () {
    test('appends a new month in date order', () {
      final start = [
        {'month': '2026-06', 'value': 100.0},
      ];
      final out = upsertNetWorthSnapshot(start, '2026-07', 250.0);
      expect(out.map((r) => r['month']).toList(), ['2026-06', '2026-07']);
      expect(out.last['value'], 250.0);
    });

    test('replaces the same month rather than duplicating it', () {
      final start = [
        {'month': '2026-07', 'value': 100.0},
      ];
      final out = upsertNetWorthSnapshot(start, '2026-07', 999.0);
      expect(out.length, 1);
      expect(out.single['value'], 999.0);
    });

    test('does not mutate the input list', () {
      final start = [
        {'month': '2026-07', 'value': 100.0},
      ];
      upsertNetWorthSnapshot(start, '2026-08', 200.0);
      expect(start.length, 1, reason: 'the caller\'s list must be untouched');
    });

    test('caps to the most recent maxNetWorthMonths, dropping the oldest', () {
      var history = <Map<String, dynamic>>[];
      // 30 consecutive months, well past the 24 cap.
      for (var i = 0; i < 30; i++) {
        final d = DateTime(2020, 1 + i, 1);
        history = upsertNetWorthSnapshot(
          history,
          netWorthMonthKey(d),
          i.toDouble(),
        );
      }
      expect(history.length, maxNetWorthMonths);
      // 30 months from 2020-01 (i=0) to 2022-06 (i=29). Keeping the newest 24
      // drops i=0..5 (2020-01..2020-06), so the trail runs 2020-07..2022-06.
      expect(history.first['month'], '2020-07'); // 2020-01 + 6 months
      expect(history.last['month'], '2022-06'); // 2020-01 + 29 months
    });
  });

  group('priorNetWorthValue', () {
    final history = [
      {'month': '2026-05', 'value': 100.0},
      {'month': '2026-06', 'value': 200.0},
      {'month': '2026-08', 'value': 400.0},
    ];

    test('is the most recent month strictly before the current one', () {
      expect(priorNetWorthValue(history, '2026-08'), 200.0);
    });

    test('skips a gap month with no snapshot (uses most recent prior)', () {
      // July has no row, so August compares to June.
      expect(priorNetWorthValue(history, '2026-08'), 200.0);
    });

    test('is null when no earlier month exists', () {
      expect(priorNetWorthValue(history, '2026-05'), isNull);
      expect(priorNetWorthValue(const [], '2026-08'), isNull);
    });

    test('ignores the current and future months', () {
      // Comparing at 2026-06 must not pick 2026-08 (the future) or 2026-06.
      expect(priorNetWorthValue(history, '2026-06'), 100.0);
    });
  });

  group('netWorthTrend', () {
    test('is null with no prior month, so the hero can hide the line', () {
      expect(netWorthTrend(const [], '2026-08', 500.0), isNull);
    });

    test('reports the peso delta against the prior month', () {
      final t = netWorthTrend([
        {'month': '2026-07', 'value': 1000.0},
      ], '2026-08', 1250.0);
      expect(t!['delta'], closeTo(250.0, 1e-9));
      expect(t['prior'], 1000.0);
    });

    test('gives a percent only off a positive base', () {
      final up = netWorthTrend([
        {'month': '2026-07', 'value': 1000.0},
      ], '2026-08', 1250.0);
      expect(up!['pct'], closeTo(25.0, 1e-9));
    });

    test('omits the percent off a zero base (no divide-by-zero nonsense)', () {
      final t = netWorthTrend([
        {'month': '2026-07', 'value': 0.0},
      ], '2026-08', 500.0);
      expect(t!['pct'], isNull);
      expect(t['delta'], closeTo(500.0, 1e-9));
    });

    test('omits the percent off a negative base (you are not "50% less in debt")', () {
      final t = netWorthTrend([
        {'month': '2026-07', 'value': -2000.0},
      ], '2026-08', -1000.0);
      expect(t!['pct'], isNull);
      expect(t['delta'], closeTo(1000.0, 1e-9));
    });

    test('omits an absurd percent off a rounding-level base', () {
      // First month recorded at a couple of pesos, now a real balance: the
      // ratio explodes to millions of percent, so pct is suppressed and the
      // peso delta stands alone.
      final t = netWorthTrend([
        {'month': '2026-07', 'value': 2.0},
      ], '2026-08', 100000.0);
      expect(t!['pct'], isNull);
      expect(t['delta'], closeTo(99998.0, 1e-9));
    });

    test('keeps the percent for a large-but-real month (up to 10x)', () {
      // A genuine doubling still shows its percent; the guard only trips past a
      // ten-fold change, where the base was not a real figure.
      final t = netWorthTrend([
        {'month': '2026-07', 'value': 5000.0},
      ], '2026-08', 10000.0);
      expect(t!['pct'], closeTo(100.0, 1e-9));
    });

    test('a fall gives a negative delta', () {
      final t = netWorthTrend([
        {'month': '2026-07', 'value': 5000.0},
      ], '2026-08', 4200.0);
      expect(t!['delta'], closeTo(-800.0, 1e-9));
      expect(t['pct'], closeTo(-16.0, 1e-9));
    });
  });

  group('netWorthSeries', () {
    final history = [
      {'month': '2026-06', 'value': 100.0},
      {'month': '2026-07', 'value': 200.0},
    ];

    test('is prior months then today\'s live figure as the last point', () {
      final s = netWorthSeries(history, '2026-08', 250.0);
      expect(s, [100.0, 200.0, 250.0]);
    });

    test('drops any current-month snapshot and uses the live figure instead', () {
      final withCurrent = [
        ...history,
        {'month': '2026-08', 'value': 999.0}, // stale current-month snapshot
      ];
      final s = netWorthSeries(withCurrent, '2026-08', 250.0);
      // 999 is not plotted; the live 250 is the last point.
      expect(s, [100.0, 200.0, 250.0]);
    });

    test('is a single live point when there is no prior history', () {
      expect(netWorthSeries(const [], '2026-08', 250.0), [250.0]);
      // The hero hides the chart below two points.
      expect(netWorthSeries(const [], '2026-08', 250.0).length, lessThan(2));
    });
  });

  group('netWorthSparkDomain', () {
    test('pads the data range on both sides, never touching an edge', () {
      final (lo, hi) = netWorthSparkDomain([200000.0, 228000.0]);
      expect(lo, lessThan(200000.0));
      expect(hi, greaterThan(228000.0));
    });

    test('a flat series gets a symmetric band so it sits mid-card', () {
      final (lo, hi) = netWorthSparkDomain([50000.0, 50000.0]);
      expect(lo, lessThan(50000.0));
      expect(hi, greaterThan(50000.0));
      expect(50000.0 - lo, closeTo(hi - 50000.0, 1e-6));
    });
  });

  group('recordNetWorthSnapshot', () {
    // A tiny store-shaped blob whose net worth is whatever netWorthParts says,
    // never a number hardcoded here.
    Map<String, dynamic> blob() => {
      'accounts': [
        {'name': 'Cash', 'kind': 'cash', 'balance': 8000.0},
      ],
      'debts': [
        {'name': 'Card', 'remaining': 3000.0},
      ],
      'settings': {'currency': 'PHP'},
    };

    test('stores the live net worth under settings.netWorthHistory', () {
      final data = blob();
      final expected = netWorthParts(data)['netWorth'] as double;
      final out = recordNetWorthSnapshot(data, DateTime(2026, 8, 13));
      final history = netWorthHistoryOf(out);
      expect(history.single['month'], '2026-08');
      expect(history.single['value'], closeTo(expected, 1e-9));
      // Lives under settings, next to the other Flutter-era collections.
      expect((out['settings'] as Map)['netWorthHistory'], isNotNull);
      expect(out.containsKey('netWorthHistory'), isFalse,
          reason: 'it is a settings key, never a new top-level key');
    });

    test('is a no-op (same instance) when this month already matches', () {
      final first = recordNetWorthSnapshot(blob(), DateTime(2026, 8, 13));
      final again = recordNetWorthSnapshot(first, DateTime(2026, 8, 20));
      expect(identical(again, first), isTrue,
          reason: 'no write when the month and figure are unchanged');
    });

    test('records a new month while keeping the earlier one', () {
      final aug = recordNetWorthSnapshot(blob(), DateTime(2026, 8, 13));
      // Change the net worth, then a new month arrives.
      final richer = {
        ...aug,
        'accounts': [
          {'name': 'Cash', 'kind': 'cash', 'balance': 20000.0},
        ],
      };
      final sep = recordNetWorthSnapshot(richer, DateTime(2026, 9, 1));
      final months = netWorthHistoryOf(sep).map((r) => r['month']).toList();
      expect(months, ['2026-08', '2026-09']);
    });

    test('does not mutate the input blob', () {
      final data = blob();
      recordNetWorthSnapshot(data, DateTime(2026, 8, 13));
      expect((data['settings'] as Map).containsKey('netWorthHistory'), isFalse);
    });
  });

  group('netWorthHistoryOf tolerance', () {
    test('drops malformed rows and a non-list', () {
      final data = {
        'settings': {
          'netWorthHistory': [
            {'month': '2026-07', 'value': 100.0},
            {'month': '', 'value': 5.0}, // empty month
            {'month': '2026-08'}, // no value
            {'value': 9.0}, // no month
            'garbage',
            {'month': '2026-09', 'value': 300.0},
          ],
        },
      };
      final out = netWorthHistoryOf(data);
      expect(out.map((r) => r['month']).toList(), ['2026-07', '2026-09']);
    });

    test('is empty when settings or the key is absent', () {
      expect(netWorthHistoryOf({}), isEmpty);
      expect(netWorthHistoryOf({'settings': {}}), isEmpty);
      expect(netWorthHistoryOf(null), isEmpty);
    });
  });
}
