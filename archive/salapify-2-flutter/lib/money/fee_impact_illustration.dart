// A small, deterministic fee-impact illustration for Money Courses Phase 7B
// ("Deposits and Pooled Funds"), Lesson 5 ("Read a Fund Fact Sheet").
//
// The task is explicit about what this must and must not be: basic
// transparent arithmetic showing that fees reduce what an investor keeps,
// using fictional values with every assumption disclosed, never a forecast
// of what an investment returns. The safest way to honor "never a forecast"
// is to never model a return at all: this measures the effect of a fee
// alone, charged each year against the ORIGINAL starting amount, with no
// growth, no market movement, and no compounding assumed anywhere. That
// keeps the illustration honest about what it is (a fee costs money over
// time) without smuggling in a claim about what a fund might earn.
//
// Pure Dart, no Flutter import, and deliberately not a general investment
// calculator: [FeeImpactAssumptions] has exactly the three inputs this one
// illustration needs, not a reusable rate/term engine.

/// Every input the illustration needs, so a lesson (or a test) can see every
/// assumption in one place rather than a number buried in prose.
class FeeImpactAssumptions {
  /// A fictional starting amount, in whole pesos.
  final int startingAmountPhp;

  /// A fictional annual fee rate, e.g. 0.015 for 1.5% a year. Never sourced
  /// from a real fund: see this course's own rule against citing a current,
  /// named fee.
  final double annualFeeRate;

  /// How many years the fee is illustrated over.
  final int years;

  const FeeImpactAssumptions({
    required this.startingAmountPhp,
    required this.annualFeeRate,
    required this.years,
  });
}

/// What the illustration produces: the fee taken, and what is left.
class FeeImpactResult {
  final int totalFeesPaidPhp;

  /// Starting amount minus total fees. No growth or return is ever added
  /// back in, on purpose: this is the fee's effect alone, not a projection.
  final int amountRetainedPhp;

  const FeeImpactResult({
    required this.totalFeesPaidPhp,
    required this.amountRetainedPhp,
  });
}

/// Computes the fee-only illustration. The fee is charged once per year
/// against the ORIGINAL starting amount, not a compounding balance, so the
/// arithmetic stays simple enough for a lesson to show in full: one
/// multiplication, one multiplication by the year count, one subtraction.
FeeImpactResult feeImpact(FeeImpactAssumptions a) {
  final feePerYearPhp = (a.startingAmountPhp * a.annualFeeRate).round();
  final totalFeesPhp = feePerYearPhp * a.years;
  return FeeImpactResult(
    totalFeesPaidPhp: totalFeesPhp,
    amountRetainedPhp: a.startingAmountPhp - totalFeesPhp,
  );
}

/// The exact fictional figures content/lessons_deposits_pooled_funds.dart
/// states in Lesson 5's fee-impact illustration block. Kept as one named
/// constant, read by both the lesson content and its test, so the two can
/// never quietly drift apart: a change to either without the other fails the
/// test that cross-checks the lesson's own prose against this function's
/// output.
const feeImpactIllustrationAssumptions = FeeImpactAssumptions(
  startingAmountPhp: 100000,
  annualFeeRate: 0.015,
  years: 5,
);
