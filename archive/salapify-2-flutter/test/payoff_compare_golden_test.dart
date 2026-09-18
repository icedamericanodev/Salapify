// Golden vectors for avalancheVsSnowball, the f4.64 payoff comparison. The
// month-by-month interest is the golden-locked debtFreeProjection's job and is
// tested elsewhere; this locks the COMPOSITION: that avalanche never costs more
// interest than snowball, that the reported saving is exactly the difference of
// the two engine numbers, and that a single debt or equal rates read as "the
// same" rather than a fake saving.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/debtmath.dart' show debtFreeProjection;
import 'package:salapify/money/payoff_compare.dart';

void main() {
  final ref = DateTime(2026, 8, 1);

  // A: small balance, cheap. B: large balance, expensive. Snowball clears the
  // small A first and lets the expensive B keep accruing; avalanche kills B
  // first. The difference only appears once there is money ABOVE the minimums to
  // allocate by priority, which is the honest heart of this feature.
  List<Map<String, dynamic>> spread() => [
    {'id': 'A', 'remaining': 5000, 'monthlyRate': 1.0, 'minPayment': 500},
    {'id': 'B', 'remaining': 20000, 'monthlyRate': 5.0, 'minPayment': 1000},
  ];

  test('at the minimums the two orders are identical, no saving claimed', () {
    // With no budget above the minimums there is nothing to allocate by
    // priority, so both orders pay the same total interest. The card must say
    // "the same", never invent a saving.
    final r = avalancheVsSnowball(spread(), ref: ref);
    expect(r['avalanche'], r['snowball']);
    expect(r['sameInterest'], isTrue);
    expect(r['interestSaved'], 0.0);
    expect(r['monthsSaved'], 0);
  });

  test('with extra above the minimums, avalanche pays less interest', () {
    final r = avalancheVsSnowball(spread(), extra: 1000, ref: ref);
    final ava = r['avalanche'] as Map<String, dynamic>;
    final snow = r['snowball'] as Map<String, dynamic>;

    // Avalanche pays strictly less interest here, and is never slower.
    expect(
      ava['totalInterest'] as double,
      lessThan(snow['totalInterest'] as double),
    );
    expect(ava['months'] as int, lessThanOrEqualTo(snow['months'] as int));

    // The reported saving is EXACTLY the difference of the two engine numbers,
    // not a re-derivation.
    final expectedSaved =
        (snow['totalInterest'] as double) - (ava['totalInterest'] as double);
    expect(r['interestSaved'] as double, closeTo(expectedSaved, 1e-9));
    expect(r['interestSaved'] as double, greaterThan(0));
    expect(
      r['monthsSaved'] as int,
      (snow['months'] as int) - (ava['months'] as int),
    );
    expect(r['sameInterest'], isFalse);

    // The composed projections are byte-for-byte the engine's own output at the
    // same extra, so the card can never disagree with the payoff plan.
    expect(ava, debtFreeProjection(spread(), 'avalanche', 1000, ref));
    expect(snow, debtFreeProjection(spread(), 'snowball', 1000, ref));
  });

  test('one debt: the two orders are identical, no saving claimed', () {
    final debts = [
      {'id': 'A', 'remaining': 12000, 'monthlyRate': 3.0, 'minPayment': 1500},
    ];
    final r = avalancheVsSnowball(debts, ref: ref);
    expect(r['avalanche'], r['snowball']);
    expect(r['sameInterest'], isTrue);
    expect(r['interestSaved'], 0.0);
    expect(r['monthsSaved'], 0);
  });

  test('equal rates: same total interest, so the card must not claim a saving', () {
    // With equal rates the total balance falls the same way whichever order you
    // pay, so total interest and months are identical.
    final debts = [
      {'id': 'A', 'remaining': 4000, 'monthlyRate': 2.0, 'minPayment': 600},
      {'id': 'B', 'remaining': 15000, 'monthlyRate': 2.0, 'minPayment': 900},
    ];
    final r = avalancheVsSnowball(debts, ref: ref);
    expect(r['sameInterest'], isTrue);
    expect(r['interestSaved'], 0.0);
    expect(r['monthsSaved'], 0);
  });

  test('an extra payment is passed through to both strategies', () {
    final debts = [
      {'id': 'A', 'remaining': 5000, 'monthlyRate': 1.0, 'minPayment': 500},
      {'id': 'B', 'remaining': 20000, 'monthlyRate': 5.0, 'minPayment': 1000},
    ];
    final withExtra = avalancheVsSnowball(debts, extra: 3000, ref: ref);
    final noExtra = avalancheVsSnowball(debts, ref: ref);
    // Paying more clears the debt sooner under avalanche.
    expect(
      (withExtra['avalanche'] as Map)['months'] as int,
      lessThan((noExtra['avalanche'] as Map)['months'] as int),
    );
    // The projections match the engine run with the same extra.
    expect(
      withExtra['avalanche'],
      debtFreeProjection(debts, 'avalanche', 3000, ref),
    );
  });

  test('avalanche is never worse than snowball, the invariant the card leans on', () {
    // The whole verdict depends on interestSaved and monthsSaved never being
    // negative (avalanche, greedy on the highest rate, never costs more or takes
    // longer). Prove it across a spread of debts and extras rather than assume
    // it, because the copy prints "pays X less" and a negative would read as
    // nonsense.
    final books = [
      spread(),
      [
        {'id': 'A', 'remaining': 3000, 'monthlyRate': 2.0, 'minPayment': 300},
        {'id': 'B', 'remaining': 9000, 'monthlyRate': 3.5, 'minPayment': 700},
        {'id': 'C', 'remaining': 25000, 'monthlyRate': 6.0, 'minPayment': 1200},
      ],
      [
        {'id': 'A', 'remaining': 15000, 'monthlyRate': 0.0, 'minPayment': 1000},
        {'id': 'B', 'remaining': 4000, 'monthlyRate': 8.0, 'minPayment': 400},
      ],
    ];
    for (final book in books) {
      for (final extra in [0, 500, 1000, 3000, 8000]) {
        final r = avalancheVsSnowball(book, extra: extra.toDouble(), ref: ref);
        final saved = r['interestSaved'] as double?;
        final monthsSaved = r['monthsSaved'] as int?;
        if (saved != null) {
          expect(
            saved,
            greaterThanOrEqualTo(-0.005),
            reason: 'avalanche cost MORE interest at extra=$extra',
          );
        }
        if (monthsSaved != null) {
          expect(
            monthsSaved,
            greaterThanOrEqualTo(0),
            reason: 'avalanche was SLOWER at extra=$extra',
          );
        }
      }
    }
  });

  test('no debts: both sides are the trivial zero projection, no saving', () {
    final r = avalancheVsSnowball(const [], ref: ref);
    expect((r['avalanche'] as Map)['months'], 0);
    expect((r['snowball'] as Map)['months'], 0);
    expect(r['interestSaved'], 0.0);
    expect(r['sameInterest'], isTrue);
  });
}
