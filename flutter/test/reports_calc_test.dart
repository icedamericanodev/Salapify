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
}
