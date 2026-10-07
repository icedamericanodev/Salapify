// Avalanche vs Snowball, f4.64. A side-by-side of the two payoff orders so a
// person can see the trade before they commit to one.
//
// Both projections come from the SAME golden-locked debtFreeProjection every
// other payoff surface uses; this only runs it twice (once per strategy) and
// subtracts, exactly the way whatIfLadder composes it. It invents no number the
// engine did not already compute.
//
//   Avalanche pays the highest interest RATE first, so it is the cheapest total
//   interest and never slower.
//   Snowball pays the smallest BALANCE first, so it clears a whole debt sooner,
//   which some people find easier to keep going with. It can cost a little more
//   interest, and never less.
//
// The honest verdict the card shows is built from the two numbers the engine
// returns, months-to-free and total interest, never a made-up one.

import 'debtmath.dart' show debtFreeProjection;

/// Compare the two strategies at a given [extra] monthly payment. Returns
/// { avalanche, snowball, interestSaved, monthsSaved, sameInterest } where each
/// projection is the debtFreeProjection map { months, totalInterest, date } or
/// null (a balance that grows faster than the minimums can never be projected).
///
/// interestSaved and monthsSaved are what AVALANCHE saves versus snowball
/// (snowball total minus avalanche total), and are null whenever either side
/// has no finite payoff, so the caller tells the honest story rather than a
/// made-up figure. sameInterest is true when the two orders cost the identical
/// interest to the centavo, which happens with a single debt or when every rate
/// is equal, and is the case where the card must NOT claim a saving.
Map<String, dynamic> avalancheVsSnowball(
  dynamic debts, {
  double extra = 0,
  DateTime? ref,
}) {
  final avalanche = debtFreeProjection(debts, 'avalanche', extra, ref);
  final snowball = debtFreeProjection(debts, 'snowball', extra, ref);

  double? interestSaved;
  int? monthsSaved;
  var sameInterest = false;
  if (avalanche != null && snowball != null) {
    final aInt = avalanche['totalInterest'] as double;
    final sInt = snowball['totalInterest'] as double;
    final aMonths = avalanche['months'] as int;
    final sMonths = snowball['months'] as int;
    interestSaved = sInt - aInt;
    monthsSaved = sMonths - aMonths;
    // Guard the presentation against float dust: differences under half a
    // centavo are not a real saving and must read as "the same".
    sameInterest = interestSaved.abs() < 0.005;
    if (sameInterest) interestSaved = 0.0;
  }

  return {
    'avalanche': avalanche,
    'snowball': snowball,
    'interestSaved': interestSaved,
    'monthsSaved': monthsSaved,
    'sameInterest': sameInterest,
  };
}
