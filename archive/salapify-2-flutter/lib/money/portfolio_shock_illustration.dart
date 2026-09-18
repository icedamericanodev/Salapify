// A small, deterministic portfolio-shock illustration for Money Courses
// Phase 8 ("Crypto Without the Hype"), Lesson 2 ("Volatility and Possible
// Total Loss"). Same discipline as money/fee_impact_illustration.dart: basic,
// transparent arithmetic only, never a forecast. A fictional starting amount
// times a stated loss percentage, nothing compounded, nothing projected
// forward in time, and no claim that any one scenario is likely.
//
// The three loss percentages this course offers (30, 60, 100) are labeled
// illustrations of what a loss COULD look like, arithmetic exercises, never a
// prediction. See content/lessons_crypto.dart's Lesson 2 for the exact wording
// that keeps that distinction in front of the reader.
//
// Pure Dart, no Flutter import, matching lib/money's own discipline.

/// Every input the illustration needs, so a widget (or a test) can see every
/// assumption in one place rather than a number buried in prose.
class PortfolioShockAssumptions {
  /// A fictional starting amount, in whole pesos.
  final int startingAmountPhp;

  /// A loss scenario as a whole-number percentage, 0 to 100 inclusive.
  final int lossPercent;

  const PortfolioShockAssumptions({
    required this.startingAmountPhp,
    required this.lossPercent,
  });
}

/// What the illustration produces: the amount lost, and what is left.
class PortfolioShockResult {
  final int amountLostPhp;

  /// Starting amount minus the amount lost. Never negative: a 100 percent
  /// loss scenario leaves exactly zero, never less.
  final int amountRemainingPhp;

  const PortfolioShockResult({
    required this.amountLostPhp,
    required this.amountRemainingPhp,
  });
}

/// Computes the loss-only illustration: `startingAmountPhp * lossPercent /
/// 100`, rounded to the nearest whole peso, then subtracted from the
/// starting amount. One multiplication, one division, one subtraction, so
/// the arithmetic can be shown in full inside a lesson.
PortfolioShockResult portfolioShockImpact(PortfolioShockAssumptions a) {
  assert(
    a.lossPercent >= 0 && a.lossPercent <= 100,
    'lossPercent must be a percentage between 0 and 100',
  );
  assert(
    a.startingAmountPhp >= 0,
    'startingAmountPhp represents a fictional holding and cannot be negative',
  );
  final lostPhp = (a.startingAmountPhp * a.lossPercent / 100).round();
  return PortfolioShockResult(
    amountLostPhp: lostPhp,
    amountRemainingPhp: a.startingAmountPhp - lostPhp,
  );
}

/// The fictional starting amounts Lesson 2's simulator offers, and the fixed
/// set of loss scenarios (30, 60, 100 percent) every course instance uses.
/// Named constants, read by both the lesson content and its test, so the two
/// can never quietly drift apart.
const List<int> lossImpactAmountOptionsPhp = [5000, 20000, 50000];
const List<int> lossImpactScenarioPercents = [30, 60, 100];
