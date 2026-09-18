import 'dart:math' as math;

/// JavaScript's Math.round, which is NOT Dart's num.round().
///
/// JS rounds a half UP, toward positive infinity, so Math.round(-2.5) is -2.
/// Dart rounds a half AWAY from zero, so (-2.5).round() is -3. Every figure in
/// the ported engine is non-negative today, where the two agree, but money code
/// outlives the assumptions it was written under. Porting the exact rule costs
/// one line and removes the question.
int jsRound(double value) => (value + 0.5).floor();

/// The prototype's `Math.round(x * 10) / 10`, kept in one place so the
/// one-decimal rounding cannot drift between callers.
double jsRound1(double value) => jsRound(value * 10) / 10;

/// Guards a lower bound the way Math.max(floor, value) does.
double atLeast(double floor, double value) => math.max(floor, value);
