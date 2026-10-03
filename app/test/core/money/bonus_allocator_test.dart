import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/bonus_allocator.dart';
import 'package:salapify/core/money/ph_tax.dart';

/// Splitting a 13th month or year-end bonus, after the tax.
void main() {
  group('the TRAIN arithmetic', () {
    test('a bonus under the ceiling is not taxed at all', () {
      final BonusPlan p = allocateBonus(bonus: 50000);
      expect(p.taxExempt, 50000);
      expect(p.taxable, 0);
      expect(p.estimatedTax, 0);
      expect(p.net, 50000);
      expect(p.isFullyExempt, isTrue);
    });

    test('exactly at the ceiling is still fully exempt', () {
      final BonusPlan p = allocateBonus(bonus: 90000);
      expect(p.taxable, 0);
      expect(p.estimatedTax, 0);
      expect(p.ceilingReached, isTrue);
    });

    test('only the excess above the ceiling is taxed', () {
      // 120,000. The first 90,000 is exempt; 30,000 is taxed at the 20
      // percent stand-in, so 6,000, leaving 114,000.
      final BonusPlan p = allocateBonus(bonus: 120000);
      expect(p.taxExempt, 90000);
      expect(p.taxable, 30000);
      expect(p.estimatedTax, 6000);
      expect(p.net, 114000);
      expect(p.isFullyExempt, isFalse);
    });

    test('the ceiling agrees with the calculator already in the app', () {
      // calculate13thMonthPay has done this tax since the tax batch and is
      // locked by golden vectors. Two engines with their own copy of 90000
      // is how two screens end up disagreeing about one person's December.
      final ThirteenthMonthPlan existing = calculate13thMonthPay(
        basicMonthlySalary: 120000,
      );
      expect(existing.taxExemptThreshold, trainBenefitsExemptCeiling);

      final BonusPlan mine = allocateBonus(bonus: 120000);
      expect(mine.taxExempt, existing.taxExemptAmount);
      expect(mine.taxable, existing.taxableExcessAmount);
      expect(mine.estimatedTax, existing.estimatedWithholdingTax);
      expect(mine.net, existing.net13thMonthPay);
    });

    test('zero and negative are not money', () {
      expect(allocateBonus(bonus: 0).net, 0);
      expect(allocateBonus(bonus: -5000).bonus, 0);
      expect(allocateBonus(bonus: -5000).net, 0);
    });
  });

  group('the allowance is for the YEAR, not for this payment', () {
    test('benefits already received eat into the exemption', () {
      // The spec treats the 90,000 as fresh. It covers the 13th month AND
      // other benefits together, for the year, so somebody who already had a
      // 30,000 performance bonus has 60,000 of room left. Told otherwise,
      // they would believe a 90,000 13th month is entirely tax free when a
      // third of it is not, and be short when the payslip arrives.
      final BonusPlan p = allocateBonus(
        bonus: 90000,
        benefitsAlreadyReceived: 30000,
      );
      expect(p.taxExempt, 60000);
      expect(p.taxable, 30000);
      expect(p.estimatedTax, 6000);
    });

    test('an allowance already used up exempts nothing', () {
      final BonusPlan p = allocateBonus(
        bonus: 40000,
        benefitsAlreadyReceived: 95000,
      );
      expect(p.taxExempt, 0);
      expect(p.taxable, 40000);
    });

    test('and the ordinary case is untouched by the new parameter', () {
      // The other half. A default that quietly reduced everybody's
      // exemption would be worse than the spec's version.
      expect(allocateBonus(bonus: 90000).taxExempt, 90000);
    });
  });

  group('the split', () {
    final BonusPlan p = allocateBonus(bonus: 50000);

    test('it is 50, 30 and 20 of the NET, not of the gross', () {
      // Splitting the gross hands out money the BIR has already taken.
      expect(p.buckets.map((BonusBucket b) => b.percent), <int>[50, 30, 20]);
      expect(p.buckets[0].amount, 25000);
      expect(p.buckets[1].amount, 15000);
      expect(p.buckets[2].amount, 10000);
    });

    test('the buckets add back to the net, to the peso', () {
      for (final double amount in <double>[
        25000,
        50000,
        75000,
        90000,
        120000,
        33333,
        1,
      ]) {
        final BonusPlan q = allocateBonus(bonus: amount);
        final double sum = q.buckets.fold<double>(
          0,
          (double a, BonusBucket b) => a + b.amount,
        );
        expect(
          sum,
          closeTo(q.net, 1.0),
          reason: 'a $amount bonus split into $sum against a net of ${q.net}',
        );
      }
    });

    test('the percentages add to 100', () {
      expect(
        bonusEmergencyPercent + bonusDebtPercent + bonusTreatsPercent,
        100,
      );
    });

    test('a taxed bonus splits what is LEFT', () {
      final BonusPlan q = allocateBonus(bonus: 120000);
      expect(q.net, 114000);
      expect(q.buckets[0].amount, 57000);
    });
  });

  group('it names no product, anywhere', () {
    // The spec routes the first bucket to "SeaBank, Maya, Pag-IBIG MP2". An
    // app that reads your balance and tells you which named institution to
    // move it to is doing the thing an investment adviser is registered to
    // do. pan_bans.dart already fails the build over this wording everywhere
    // Pan can reach; this is the same rule, held here by hand because the
    // content lives outside Pan.
    const List<String> banned = <String>[
      'seabank',
      'gotyme',
      'maribank',
      'tonik',
      'cimb',
      'komo',
      'maya',
      'gcash',
      'mp2',
      'pag-ibig',
      'high-yield',
      'high yield',
      'per annum',
      'p.a.',
      'interest rate',
      'returns',
    ];

    test('not in a bucket name, and not in what it is for', () {
      final BonusPlan p = allocateBonus(bonus: 90000);
      for (final BonusBucket b in p.buckets) {
        final String text = '${b.name} ${b.purpose}'.toLowerCase();
        for (final String word in banned) {
          expect(
            text.contains(word),
            isFalse,
            reason: 'bucket "${b.name}" says "$word"',
          );
        }
      }
    });

    test('and a bucket still says what the money is FOR', () {
      // The other half. Stripping the copy back to nothing would pass the
      // test above and would leave three unexplained percentages.
      for (final BonusBucket b in allocateBonus(bonus: 90000).buckets) {
        expect(b.purpose.length, greaterThan(40), reason: b.name);
        expect(b.name, isNotEmpty);
      }
    });
  });

  group('the bar', () {
    test('it shows how much of the allowance this bonus uses', () {
      expect(allocateBonus(bonus: 45000).exemptUsed, closeTo(0.5, 0.001));
      expect(allocateBonus(bonus: 90000).exemptUsed, 1.0);
    });

    test('it never goes past full, however big the bonus', () {
      expect(allocateBonus(bonus: 500000).exemptUsed, 1.0);
    });

    test('and nothing entered is an empty bar, not a full one', () {
      expect(allocateBonus(bonus: 0).exemptUsed, 0);
    });
  });
}
