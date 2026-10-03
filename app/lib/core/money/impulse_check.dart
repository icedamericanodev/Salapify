/// The Money Mindset check, from the prototype's `handleEvaluateMindset` in
/// `src/components/PhilippineFeaturesModal.tsx`.
///
/// Three questions about a thing somebody wants to buy, scored out of 100, and
/// a verdict. The point is not the arithmetic, it is the pause: the questions
/// are what make somebody notice they are about to buy a want they will use
/// once, and the score is only how the app says so out loud.
///
/// ## The hours-of-work line is the one that lands
///
/// A 4,500 peso pair of earbuds against a 35,000 peso salary is twenty hours
/// of work. The prototype divides the monthly figure by 160, which is a
/// forty hour week over four weeks, and that is kept exactly: a different
/// divisor would be a different claim about somebody's life, and this one is
/// the prototype's.
library;

enum NeedOrWant { need, want }

enum UseFrequency { daily, weekly, rarely }

/// Whether a cheaper version of the same thing exists.
enum CheaperAlternative { yes, no }

enum ImpulseVerdict { green, yellow, red }

class ImpulseResult {
  const ImpulseResult({
    required this.score,
    required this.verdict,
    required this.headline,
    required this.advice,
    required this.hoursOfWork,
  });

  final int score;
  final ImpulseVerdict verdict;

  /// Short enough to sit beside the score.
  final String headline;

  /// What to actually do, which is the only part worth reading twice.
  final String advice;

  /// How long somebody works to pay for this. Null when no salary is known,
  /// rather than a zero: "0.0 hours of work" reads as free.
  final double? hoursOfWork;
}

/// The prototype's own weights, unchanged: 40 or 10, then 40 or 30 or 10,
/// then 20 or 5. Maximum 100, minimum 25.
ImpulseResult checkImpulse({
  required double price,
  required double monthlyIncome,
  required NeedOrWant needOrWant,
  required UseFrequency useFrequency,
  required CheaperAlternative cheaperAlternative,
}) {
  int score = 0;
  score += needOrWant == NeedOrWant.need ? 40 : 10;
  score += switch (useFrequency) {
    UseFrequency.daily => 40,
    UseFrequency.weekly => 30,
    UseFrequency.rarely => 10,
  };
  score += cheaperAlternative == CheaperAlternative.no ? 20 : 5;

  // 160 hours: forty a week, four weeks. The prototype's divisor.
  final double hourly = monthlyIncome / 160;
  final double? hours = hourly > 0 && price > 0 ? price / hourly : null;

  if (score >= 70) {
    return ImpulseResult(
      score: score,
      verdict: ImpulseVerdict.green,
      headline: 'Green light',
      advice:
          'This one earns its place. Even so, sleep on it for a day. Nothing '
          'worth buying gets worse overnight.',
      hoursOfWork: hours,
    );
  }
  if (score >= 40) {
    return ImpulseResult(
      score: score,
      verdict: ImpulseVerdict.yellow,
      headline: 'Think about it',
      advice:
          'Somewhere between a want and a need. Wait two days, or look for '
          'the cheaper version you already said exists.',
      hoursOfWork: hours,
    );
  }
  return ImpulseResult(
    score: score,
    verdict: ImpulseVerdict.red,
    headline: 'Walk away',
    advice:
        'This has the shape of an itch rather than a need. Leave it three '
        'days. If you still want it then, it was real.',
    hoursOfWork: hours,
  );
}
