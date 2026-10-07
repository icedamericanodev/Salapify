// Money Courses Phase 7B: proves money/fee_impact_illustration.dart's pure
// fee arithmetic, kept separate from content per the task's own instruction
// to keep calculation logic separate and unit-tested. Also cross-checks
// that content/lessons_deposits_pooled_funds.dart's Lesson 5 states the
// SAME three figures this function produces for
// feeImpactIllustrationAssumptions, since that lesson cannot call this
// function directly (a MoneyLesson is authored as a compile-time const, and
// Dart cannot call a user function inside a const expression) and instead
// states the numbers as literals.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/money/fee_impact_illustration.dart';

void main() {
  group('feeImpact', () {
    test('charges the fee once per year against the original amount only', () {
      const assumptions = FeeImpactAssumptions(
        startingAmountPhp: 100000,
        annualFeeRate: 0.015,
        years: 5,
      );
      final result = feeImpact(assumptions);
      expect(result.totalFeesPaidPhp, 7500);
      expect(result.amountRetainedPhp, 92500);
    });

    test('zero years means zero fees and nothing lost', () {
      const assumptions = FeeImpactAssumptions(
        startingAmountPhp: 50000,
        annualFeeRate: 0.02,
        years: 0,
      );
      final result = feeImpact(assumptions);
      expect(result.totalFeesPaidPhp, 0);
      expect(result.amountRetainedPhp, 50000);
    });

    test('never assumes any growth or return: retained is never more than '
        'the starting amount', () {
      const assumptions = FeeImpactAssumptions(
        startingAmountPhp: 200000,
        annualFeeRate: 0.01,
        years: 10,
      );
      final result = feeImpact(assumptions);
      expect(result.amountRetainedPhp, lessThan(200000));
      expect(
        result.amountRetainedPhp + result.totalFeesPaidPhp,
        200000,
        reason:
            'fees plus what remains must always equal the starting '
            'amount, since no growth is ever modeled',
      );
    });
  });

  group('the real illustration this course uses', () {
    test('feeImpactIllustrationAssumptions produces the exact figures '
        'Lesson 5 states', () {
      final result = feeImpact(feeImpactIllustrationAssumptions);
      expect(result.totalFeesPaidPhp, 7500);
      expect(result.amountRetainedPhp, 92500);
    });

    test('Lesson 5\'s fee-impact paragraph states these same figures', () {
      final lesson = depositsAndPooledFundsLessons.firstWhere(
        (l) => l.id == dpReadAFactSheet,
      );
      final proseTexts = lesson.blocks
          .whereType<ProseBlock>()
          .map((b) => b.paragraphs.join(' '))
          .join(' ');
      expect(proseTexts.contains('1,500 pesos'), isTrue);
      expect(proseTexts.contains('7,500 pesos'), isTrue);
      expect(proseTexts.contains('92,500 pesos'), isTrue);
    });
  });
}
