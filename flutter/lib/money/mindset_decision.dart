// Money Mindset's Decision Score: a read-only 0..100 mirror of what a purchase
// would do to the money, composed ENTIRELY from the golden-locked engines the
// rest of the app already ships (emergencyRunway, safeToSpend, commitmentLoad,
// goalTradeoff). It writes nothing and invents no second set of numbers, the
// same contract afford.dart and mindset_purchase.dart keep. If this screen and
// the Afford card ever disagree, one of them is reading the engines wrong.
//
// Two stages, on purpose:
//  1. financialScore (0..100): objective, reproducible from the ledger, and
//     un-gameable by a self-report answer. This is the number on the Impact
//     screen. The four axes and their weights are below.
//  2. applyReflection: the three private questions can only NUDGE the outcome
//     toward waiting, never toward buying, so "it's essential!" can never turn a
//     real cash crunch green.
//
// Bands use IMPACT words, never commands (founder decision, 2026-08-13): the app
// shows the impact, the user decides. Fits comfortably / Worth a pause / Big
// impact. Keeping it an aid and not advice is the same trust line as no-lending.
//
// The axis math lives in small pure helpers so every branch is pinned by a
// hand-computed vector in mindset_decision_test.dart (and can be broken to prove
// the test fails), the repo rule for money logic.
import 'analytics.dart' show emergencyRunway;
import 'commitmentload.dart' show commitmentLoad;
import 'commitments.dart' show safeToSpend;
import 'ledger.dart' show amountOf;
import 'mindset_purchase.dart' show goalTradeoff;

/// How the purchase is taken on. Mirrors the screen's three paths.
enum MindsetMode { oneTime, subscription, credit }

// Axis weights. Buffer weighted highest: not going backwards on the emergency
// cushion is the single most important guardrail in personal finance. The
// income anchors (0.5 tight, 0.65 heavy) are the same worry lines afford.dart
// and the commitmentLoad card already teach, so the screens never disagree.
const double wBuffer = 40;
const double wIncome = 25;
const double wReserved = 20;
const double wGoal = 15;

double _n(dynamic v) {
  final x = amountOf(v);
  return x.isFinite ? x : 0.0;
}

double _clamp(double x, double lo, double hi) => x < lo ? lo : (x > hi ? hi : x);
double _clamp01(double x) => _clamp(x, 0, 1);

/// floor(x + 0.5): the app-wide rounding, so a score never disagrees with any
/// other money figure by a rounding hair.
int mindsetRound(double x) => (x + 0.5).floor();

int mindsetBand(double score) => score >= 70 ? 1 : (score >= 45 ? 2 : 3);

/// The neutral impact label for a band. Founder chose impact words over
/// "Proceed / Wait" commands.
String mindsetBandLabel(int band) => switch (band) {
  1 => 'Fits comfortably',
  2 => 'Worth a pause',
  _ => 'Big impact',
};

/// The cushion comfort word, from months of typical expenses the accounts still
/// cover after the buy. Null runway (no expense history) reads as a plain Okay.
String mindsetBufferLabel(double? runwayAfter) {
  if (runwayAfter == null) return 'Okay';
  if (runwayAfter <= 0) return 'Empties your cushion';
  if (runwayAfter < 1) return 'Thin';
  if (runwayAfter < 3) return 'Okay';
  return 'Comfortable';
}

// ----------------------------------------------------------------- axes (pure)

/// Axis 1 (weight 40). Months of expenses still covered after the buy, graded:
/// 3+ months is full marks (the emergency-fund norm), 1 to 3 ramps 60..100,
/// under 1 ramps 0..60, and empty is zero. [avg] is the typical monthly expense;
/// when it is unknown (thin history) the caller passes the 10000 starter floor
/// as a one-month proxy, never a fabricated number.
double bufferAxis(double bufferAfter, double avg) {
  final denom = avg > 0 ? avg : 10000.0;
  final runwayAfter = bufferAfter / denom;
  if (runwayAfter >= 3) return 100;
  if (runwayAfter >= 1) return 60 + (runwayAfter - 1) / 2 * 40;
  return _clamp(runwayAfter * 60, 0, 60);
}

/// Axis 2 (weight 25), one-time: the share of a typical month's income the price
/// eats. 5% or less is full marks, 50% or more is zero.
double incomeAxisOneTime(double price, double typicalIncome) {
  if (!(typicalIncome > 0)) return double.nan; // caller drops the axis
  final p = price / typicalIncome;
  return _clamp01((0.5 - p) / (0.5 - 0.05)) * 100;
}

/// Axis 2 (weight 25), recurring: the NEW total recurring share once this
/// monthly load is added. 35% or less full marks, 65% or more zero, the same
/// heavy line the Afford card uses.
double incomeAxisRecurring(
  double monthlyCommitted,
  double monthlyLoad,
  double typicalIncome,
) {
  if (!(typicalIncome > 0)) return double.nan; // caller drops the axis
  final newShare = (monthlyCommitted + monthlyLoad) / typicalIncome;
  return _clamp01((0.65 - newShare) / (0.65 - 0.35)) * 100;
}

/// Axis 3 (weight 20). Did the immediate outflow dip into money reserved for
/// bills and debt due before the next sweldo? Not dipping is full marks; any dip
/// caps this axis under 50. [daysLeft] gives sweldo relief: a small dip within
/// three days of payday is a timing wrinkle, not a crunch, so the penalty halves.
double reservedAxis(double availableAfter, double committed, int daysLeft) {
  if (availableAfter >= 0) return 100;
  final shortfall = -availableAfter;
  final reserved = committed > shortfall ? committed : shortfall;
  var s = _clamp01(1 - shortfall / reserved) * 50;
  if (daysLeft <= 3) s = 50 + s / 2; // sweldo lands soon
  return s;
}

/// Axis 4 (weight 15). How far a linked goal slips. With a deadline, 0 days is
/// full marks and 90+ days is zero. Without a deadline, it grades on how much of
/// what is left the purchase would swallow. Caller drops the axis when no goal is
/// linked (returns NaN here for a null tradeoff).
double goalAxis(Map<String, dynamic>? tradeoff) {
  if (tradeoff == null) return double.nan; // caller drops the axis
  final delay = tradeoff['delay'];
  if (delay is Map) {
    final periods = (delay['periods'] as num?)?.toDouble() ?? 0;
    final frequency = delay['frequency'] as String? ?? 'monthly';
    final perDay = const {
      'weekly': 7.0,
      'monthly': 30.0,
      'quarterly': 91.0,
      'annual': 365.0,
    };
    final delayDays = periods * (perDay[frequency] ?? 30.0);
    return _clamp01((90 - delayDays) / 90) * 100;
  }
  // Goal present but no deadline: grade on the share of remaining it eats.
  final pr = _n(tradeoff['percentOfRemaining']) / 100;
  return _clamp01(1 - pr) * 100;
}

/// The weighted average of the present axes. A skipped axis (NaN) leaves BOTH
/// sums, so the result stays 0..100 and every point is explainable.
double combineAxes(List<({double weight, double score})> axes) {
  var num = 0.0, den = 0.0;
  for (final a in axes) {
    if (a.score.isNaN) continue;
    num += a.weight * a.score;
    den += a.weight;
  }
  if (den <= 0) return double.nan; // nothing to judge yet
  return num / den;
}

/// The credit markup penalty: paying more for the same item should cost points.
/// [markup] is extraCost / price (from bnplCost). Capped so a 30%+ markup is the
/// full 15-point hit.
double creditPenalty(double markup) => _clamp(markup, 0, 0.3) / 0.3 * 15;

// ------------------------------------------------------------- orchestrator

/// The financial Decision Score and its axis breakdown for a hypothetical
/// purchase. Pure and read-only: it only READS the engines, never a write.
///
/// [cashNow] is the immediate outflow (the whole price for one-time, one bill
/// for a subscription, the first installment for credit). [monthlyLoad] is the
/// ongoing monthly bite (0 for one-time). [creditMarkup] is extraCost/price for
/// a credit plan (0 otherwise). [goal] is the linked savings goal, if any, and
/// [goalAmount] the amount weighed against it (defaults to cashNow).
Map<String, dynamic> mindsetDecision(
  Map<String, dynamic> data,
  DateTime ref, {
  required MindsetMode mode,
  required double cashNow,
  double monthlyLoad = 0,
  double creditMarkup = 0,
  Map<String, dynamic>? goal,
  double? goalAmount,
}) {
  final runway = emergencyRunway(data, ref);
  final sts = safeToSpend(data, ref);
  final load = commitmentLoad(data, ref);

  final buffer = _n(runway['buffer']);
  final avg = _n(runway['avgMonthlyExpense']);
  final available = _n(sts['available']);
  final committed = _n(sts['committed']);
  final daysLeft = (sts['daysLeft'] as num?)?.toInt() ?? 30;
  final typicalIncome = _n(load['typicalIncome']);
  final hasIncome = load['hasIncomeBase'] == true && typicalIncome > 0;
  final monthlyCommitted = _n(load['monthlyCommitted']);

  final bufferAfter = buffer - cashNow;
  final runwayAfter = avg > 0 ? bufferAfter / avg : null;
  final availableAfter = available - cashNow;

  final sBuffer = bufferAxis(bufferAfter, avg);
  final sIncome = !hasIncome
      ? double.nan
      : (mode == MindsetMode.oneTime
            ? incomeAxisOneTime(cashNow, typicalIncome)
            : incomeAxisRecurring(monthlyCommitted, monthlyLoad, typicalIncome));
  final sReserved = reservedAxis(availableAfter, committed, daysLeft);
  final tradeoff = goalTradeoff(
    goal: goal,
    purchaseAmount: goalAmount ?? cashNow,
    now: ref,
  );
  final sGoal = goalAxis(tradeoff);

  var financial = combineAxes([
    (weight: wBuffer, score: sBuffer),
    (weight: wIncome, score: sIncome),
    (weight: wReserved, score: sReserved),
    (weight: wGoal, score: sGoal),
  ]);
  if (mode == MindsetMode.credit && creditMarkup > 0 && !financial.isNaN) {
    financial = _clamp(financial - creditPenalty(creditMarkup), 0, 100);
  }
  final score = financial.isNaN ? 0 : mindsetRound(financial);
  final band = mindsetBand(score.toDouble());

  return {
    'financialScore': score,
    'band': band,
    'bandLabel': mindsetBandLabel(band),
    'bufferAfter': bufferAfter,
    'runwayAfter': runwayAfter,
    'bufferLabel': mindsetBufferLabel(runwayAfter),
    'availableAfter': availableAfter,
    'dipsReserved': availableAfter < 0,
    'daysLeft': daysLeft,
    'goalTradeoff': tradeoff,
    'axes': [
      {'name': 'buffer', 'weight': wBuffer, 'score': sBuffer, 'skipped': sBuffer.isNaN},
      {'name': 'income', 'weight': wIncome, 'score': sIncome, 'skipped': sIncome.isNaN},
      {'name': 'reserved', 'weight': wReserved, 'score': sReserved, 'skipped': sReserved.isNaN},
      {'name': 'goal', 'weight': wGoal, 'score': sGoal, 'skipped': sGoal.isNaN},
    ],
    'incomeKnown': hasIncome,
  };
}

/// The three private reflection answers, applied as penalties ONLY. A "Yes" adds
/// nothing; the financial score is the ceiling and reflection can only nudge
/// toward waiting. Q2 ("can you afford this without touching reserved money") is
/// the one whose "No" hard-caps the band at 2, because being unable to cover
/// bills after a buy should always stop a green light, whatever the number says.
Map<String, dynamic> applyReflection(
  int financialScore, {
  required bool essential, // Q1: is this essential right now?
  required bool affordWithoutReserved, // Q2
  required bool wanted24h, // Q3: wanted it for at least 24 hours?
}) {
  var adj = 0;
  if (!essential) adj -= 8;
  if (!affordWithoutReserved) adj -= 25;
  if (!wanted24h) adj -= 10;
  final adjusted = _clamp(financialScore + adj.toDouble(), 0, 100).toInt();
  var band = mindsetBand(adjusted.toDouble());
  if (!affordWithoutReserved && band < 2) band = 2; // hard cap: never green
  return {
    'adjustedScore': adjusted,
    'finalBand': band,
    'finalBandLabel': mindsetBandLabel(band),
  };
}

/// How long to suggest sleeping on it, by band. Bigger impact, longer pause. A
/// tiny one-time buy (under a day of typical spend) gets a shorter nudge even in
/// the heaviest band, so the cool-off never feels absurd on a ₱100 item.
Duration? mindsetCoolOff(int band, {double? cashNow, double? avgDaily}) {
  switch (band) {
    case 3:
      if (cashNow != null && avgDaily != null && avgDaily > 0 && cashNow < avgDaily) {
        return const Duration(days: 3);
      }
      return const Duration(days: 7);
    case 2:
      return const Duration(days: 3);
    default:
      return null; // Band 1: no pause suggested
  }
}
