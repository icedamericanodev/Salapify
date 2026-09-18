// Money Courses Phase 8 ("Crypto Without the Hype"): proves
// money/portfolio_shock_illustration.dart's pure loss-impact arithmetic,
// kept separate from content per the task's own instruction to unit-test
// calculation logic separately. Also cross-checks that
// content/lessons_crypto.dart's Lesson 2 states the same worked example this
// function produces, the same discipline
// fee_impact_illustration_test.dart already uses for Lesson 5 of "Deposits
// and Pooled Funds".

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/money/portfolio_shock_illustration.dart';

void main() {
  group('portfolioShockImpact', () {
    test('30 percent loss on 5,000 pesos', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 5000,
          lossPercent: 30,
        ),
      );
      expect(result.amountLostPhp, 1500);
      expect(result.amountRemainingPhp, 3500);
    });

    test('60 percent loss on 20,000 pesos', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 20000,
          lossPercent: 60,
        ),
      );
      expect(result.amountLostPhp, 12000);
      expect(result.amountRemainingPhp, 8000);
    });

    test('100 percent loss on 50,000 pesos leaves exactly zero', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 50000,
          lossPercent: 100,
        ),
      );
      expect(result.amountLostPhp, 50000);
      expect(result.amountRemainingPhp, 0);
    });

    test('0 percent loss loses nothing', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 12345,
          lossPercent: 0,
        ),
      );
      expect(result.amountLostPhp, 0);
      expect(result.amountRemainingPhp, 12345);
    });

    test('never assumes any growth: lost plus remaining always equals the '
        'starting amount', () {
      for (final amount in lossImpactAmountOptionsPhp) {
        for (final percent in lossImpactScenarioPercents) {
          final result = portfolioShockImpact(
            PortfolioShockAssumptions(
              startingAmountPhp: amount,
              lossPercent: percent,
            ),
          );
          expect(result.amountLostPhp + result.amountRemainingPhp, amount);
          expect(result.amountRemainingPhp, greaterThanOrEqualTo(0));
        }
      }
    });

    test('rounds to the nearest whole peso', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 999,
          lossPercent: 30,
        ),
      );
      // 999 * 0.30 = 299.7, rounds to 300.
      expect(result.amountLostPhp, 300);
      expect(result.amountRemainingPhp, 699);
    });
  });

  group('the named option lists this course offers', () {
    test('three fictional amounts, three loss scenarios', () {
      expect(lossImpactAmountOptionsPhp.length, 3);
      expect(lossImpactScenarioPercents, [30, 60, 100]);
    });
  });

  group('Lesson 2\'s worked example matches this function\'s own output', () {
    test('the lesson states the same 5,000-pesos-at-30-percent figures', () {
      final lesson = cryptoWithoutHypeLessons.firstWhere(
        (l) => l.id == cryptoRefVolatilityTotalLoss,
      );
      final proseTexts = lesson.blocks
          .whereType<ProseBlock>()
          .map((b) => b.paragraphs.join(' '))
          .join(' ');
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 5000,
          lossPercent: 30,
        ),
      );
      expect(result.amountLostPhp, 1500);
      expect(result.amountRemainingPhp, 3500);
      expect(proseTexts.contains('1,500 pesos'), isTrue);
      expect(proseTexts.contains('3,500 pesos'), isTrue);
    });
  });
}
