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
}
