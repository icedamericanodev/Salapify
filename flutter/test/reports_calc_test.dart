// The derived Reports figures are net-new (no RN engine counterpart, the RN
// screen computes them inline), so they are covered by these unit tests instead
// of a golden replay. Each mirrors the arithmetic and the operand order the RN
// screen uses, and confirms the non-finite guards keep the screen alive.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/reports_calc.dart';

void main() {
  group('spendablePosition', () {
    test('assets minus receivables minus liabilities', () {
      final parts = {'assets': 10000, 'receivables': 3000, 'liabilities': 2000};
      expect(spendablePosition(parts), 5000);
    });

    test('reads string amounts the JS way', () {
      final parts = {'assets': '10000', 'receivables': '0', 'liabilities': ''};
      expect(spendablePosition(parts), 10000);
    });

    test('can go negative when you owe more than you own', () {
      final parts = {'assets': 1000, 'receivables': 0, 'liabilities': 4000};
      expect(spendablePosition(parts), -3000);
    });

    test('non-finite operand yields 0, never a crash', () {
      final parts = {
        'assets': double.infinity,
        'receivables': 0,
        'liabilities': 0
      };
      expect(spendablePosition(parts), 0);
    });
  });

  group('savingsRatePct', () {
    test('rounds the percentage kept', () {
      expect(savingsRatePct(2500, 10000), 25);
      expect(savingsRatePct(3333, 10000), 33);
    });

    test('zero income divides by nothing, returns 0', () {
      expect(savingsRatePct(0, 0), 0);
      expect(savingsRatePct(500, 0), 0);
    });

    test('negative income is treated as no income', () {
      expect(savingsRatePct(100, -500), 0);
    });

    test('a negative net (overspent) reads as a negative rate', () {
      expect(savingsRatePct(-2000, 10000), -20);
    });
  });

  group('liquidGap', () {
    test('current assets minus current liabilities', () {
      final bs = {'currentAssets': 8000, 'currentLiabilities': 5000};
      expect(liquidGap(bs), 3000);
    });

    test('short on cash reads negative', () {
      final bs = {'currentAssets': 2000, 'currentLiabilities': 5000};
      expect(liquidGap(bs), -3000);
    });

    test('non-finite operand yields 0', () {
      final bs = {'currentAssets': double.nan, 'currentLiabilities': 0};
      expect(liquidGap(bs), 0);
    });
  });

  group('interestSaved', () {
    test('snowball minus avalanche, matching the RN operand order', () {
      expect(interestSaved(5000, 3000), 2000);
    });

    test('equal cost saves nothing', () {
      expect(interestSaved(3000, 3000), 0);
    });

    test('non-finite operand yields 0', () {
      expect(interestSaved(double.infinity, 3000), 0);
    });
  });

  group('spendingVsUsual', () {
    // monthlySeries is oldest-first; the last entry is the focus month.
    List<Map<String, dynamic>> series(List<double> expenses) => [
          for (var i = 0; i < expenses.length; i++)
            {'key': 'm$i', 'expenses': expenses[i]},
        ];

    test('usual averages only the prior months that had spending', () {
      // Three prior months: 4000, 0, 6000. The zero month is skipped, so
      // usual = (4000 + 6000) / 2 = 5000, not /3.
      final c = spendingVsUsual(series([4000, 0, 6000, 5200]), 1.0);
      expect(c.usual, 5000);
      expect(c.current, 5200);
      expect(c.priorMonths, 2);
      expect(c.hasHistory, true);
    });

    test('a complete month compares against the full usual', () {
      final c = spendingVsUsual(series([5000, 5000, 6000]), 1.0);
      // usual 5000, current 6000, expected 5000 -> +20%.
      expect(c.pctVsExpected, 20);
    });

    test('a partial month paces the usual down so it is judged fairly', () {
      // Halfway through the month, current 2600 against a 5000 usual. Expected
      // 2500, so +4%, not the -48% a full-month comparison would wrongly show.
      final c = spendingVsUsual(series([5000, 2600]), 0.5);
      expect(c.expected, 2500);
      expect(c.pctVsExpected, 4);
    });

    test('no prior spending means no basis to compare', () {
      final c = spendingVsUsual(series([0, 0, 3000]), 1.0);
      expect(c.hasHistory, false);
      expect(c.usual, 0);
      expect(c.pctVsExpected, 0);
    });

    test('empty series is safe', () {
      final c = spendingVsUsual(const [], 1.0);
      expect(c.hasHistory, false);
      expect(c.current, 0);
    });

    test('non-finite frac falls back to a full month', () {
      final c = spendingVsUsual(series([5000, 5000]), double.infinity);
      expect(c.expected, 5000);
    });

    test('a net-negative focus month floors to zero spent', () {
      // Refunds entered as negative expenses could make the month sum negative;
      // it should read as zero spent (matching the bar), not a nonsense delta.
      final c = spendingVsUsual(series([5000, -300]), 1.0);
      expect(c.current, 0);
      expect(c.pctVsExpected, -100);
    });

    test('reads string and junk amounts the JS way', () {
      final c = spendingVsUsual([
        {'key': 'a', 'expenses': '4000'},
        {'key': 'b', 'expenses': null},
        {'key': 'c', 'expenses': '6000'},
        {'key': 'd', 'expenses': 3000},
      ], 1.0);
      expect(c.usual, 5000);
      expect(c.current, 3000);
    });
  });

  group('priorCategoryHistory', () {
    // ref is mid-current-month; the helper looks at the PRIOR months only.
    final ref = DateTime(2026, 7, 15);
    Map<String, dynamic> tx(String date, String label, num amount,
            [String type = 'expense']) =>
        {'date': date, 'label': label, 'amount': amount, 'type': type};

    test('counts prior months a category appears in, and active months', () {
      final txs = [
        tx('2026-06-05', 'Food', 3000),
        tx('2026-05-05', 'Food', 3200),
        tx('2026-04-05', 'Food', 2800),
        tx('2026-06-01', 'Rent', 7000),
        // Current month is excluded from the prior-month window.
        tx('2026-07-05', 'Food', 500),
      ];
      final h = priorCategoryHistory(txs, ref);
      expect(h.monthsSeen['Food'], 3);
      expect(h.monthsSeen['Rent'], 1);
      expect(h.activeMonths, 3); // Jun, May, Apr had spending
    });

    test('regular means present in at least half the active months', () {
      final txs = [
        for (final m in ['2026-06', '2026-05', '2026-04', '2026-03'])
          tx('$m-05', 'Food', 3000),
        tx('2026-06-10', 'Tuition', 15000), // once in 4 active months
      ];
      final h = priorCategoryHistory(txs, ref);
      expect(h.activeMonths, 4);
      expect(h.isRegular('Food'), true); // 4 of 4
      expect(h.isRegular('Tuition'), false); // 1 of 4
    });

    test('income and transfers are ignored; blank labels fold to Other', () {
      final txs = [
        tx('2026-06-15', 'Sweldo', 20000, 'income'),
        tx('2026-06-16', 'To savings', 2000, 'transfer'),
        tx('2026-06-17', '   ', 400),
      ];
      final h = priorCategoryHistory(txs, ref);
      expect(h.monthsSeen.containsKey('Sweldo'), false);
      expect(h.monthsSeen['Other'], 1);
      expect(h.activeMonths, 1);
    });

    test('junk rows and no history are safe', () {
      final h = priorCategoryHistory([null, 42, 'x'], ref);
      expect(h.activeMonths, 0);
      expect(h.isRegular('Food'), false);
    });
  });

  group('netFlowSummary', () {
    List<Map<String, dynamic>> mk(List<List<num>> ie) => [
          for (final row in ie)
            {'income': row[0], 'expenses': row[1], 'net': row[0] - row[1]},
        ];

    test('counts saver months, total, and the largest swing', () {
      // +2000, -500, +1000, 0-activity month
      final s = mk([
        [5000, 3000],
        [4000, 4500],
        [6000, 5000],
        [0, 0],
      ]);
      final r = netFlowSummary(s);
      expect(r.saverMonths, 2);
      expect(r.activeMonths, 3);
      expect(r.totalNet, 2500); // 2000 - 500 + 1000
      expect(r.maxAbs, 2000);
    });

    test('an all-empty window is safe', () {
      final r = netFlowSummary(mk([
        [0, 0],
        [0, 0],
      ]));
      expect(r.saverMonths, 0);
      expect(r.activeMonths, 0);
      expect(r.totalNet, 0);
      expect(r.maxAbs, 0);
    });

    test('a non-finite net does not poison the total', () {
      final s = [
        {'income': double.infinity, 'expenses': 0, 'net': double.infinity},
        {'income': 1000, 'expenses': 400, 'net': 600},
      ];
      final r = netFlowSummary(s);
      expect(r.totalNet, 600); // the infinite net reads as 0
    });
  });

  group('weekdayPeak', () {
    List<Map<String, dynamic>> mk(List<num> avgByDay) =>
        [for (var i = 0; i < avgByDay.length; i++) {'day': i, 'avg': avgByDay[i]}];

    test('names the busiest and quietest active day', () {
      // Sun..Sat; Fri (5) highest, Mon (1) lowest active.
      final r = weekdayPeak(mk([0, 100, 300, 0, 250, 900, 400]));
      expect(r.peakDay, 5);
      expect(r.peakAvg, 900);
      expect(r.lightDay, 1);
      expect(r.lightAvg, 100);
      expect(r.maxAvg, 900);
      expect(r.activeDays, 5);
    });

    test('a single active day names no lightest', () {
      final r = weekdayPeak(mk([0, 0, 0, 500, 0, 0, 0]));
      expect(r.peakDay, 3);
      expect(r.lightDay, -1);
      expect(r.activeDays, 1);
    });

    test('no spend at all is safe', () {
      final r = weekdayPeak(mk([0, 0, 0, 0, 0, 0, 0]));
      expect(r.peakDay, -1);
      expect(r.lightDay, -1);
      expect(r.maxAvg, 0);
    });
  });
}
