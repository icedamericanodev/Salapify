// "Kaya mo ba ito?" the Afford-This stress test. The user names a purchase they
// are eyeing, either a one-time price or a monthly installment (hulugan / BNPL)
// and its term, and this composes the golden-locked engines into an HONEST
// picture of what it does to their money: the hit to spendable cash before the
// next sweldo, the share of a typical month it would spoke-for, whether it still
// fits on a LEAN income month, and how much emergency cushion a lump buy burns.
//
// This is NEW composition, not a port, so it is unit-tested here against hand
// computed vectors rather than golden-locked to RN. It only READS: it never
// touches savingsRate, safe-to-spend, the health score, or any stored state.
// It is a mirror, not a salesman: the framing defaults to caution and every
// verdict surfaces its lean-month assumption, so it never reads as "go buy it".
//
// Trust rules baked in:
// - Degrades honestly on thin data. With fewer than the income months
//   commitmentLoad needs, the recurring-share verdict is 'unknown' and only the
//   cash-now hit is asserted, never a made-up "you can afford it".
// - No loan or lending vocabulary (Play policy, and the audience's distrust): it
//   weighs a commitment, it never offers one.
// - All divisions guard against zero and non-finite inputs, so a junk backup or
//   an absurd amount can never crash the card.

import 'analytics.dart' show emergencyRunway, monthlySeries;
import 'commitmentload.dart' show commitmentLoad;
import 'commitments.dart' show safeToSpend;
import 'ledger.dart' show amountOf;

/// The two ways this audience takes something on: pay the whole price now, or
/// split it into a fixed monthly for a set number of months.
enum AffordMode { oneTime, installment }

/// A commitment eats a comfortable slice of a typical month below this share,
/// gets tight up to [_heavyShare], and is heavy above it. 0.5 and 0.65 are the
/// same guardrails the commitmentLoad card already teaches (half your income
/// spoken for is the worry line), so the two screens never disagree.
const double _tightShare = 0.5;
const double _heavyShare = 0.65;

/// On a LEAN income month a commitment that eats more than this share leaves too
/// little to live on, so it fails the lean test even if it fits a typical month.
const double _leanFitShare = 0.7;

/// A one-time buy that swallows more than this fraction of today's spendable
/// cash is tight even when it technically fits, so the verdict warns rather than
/// flatters.
const double _oneTimeTightFraction = 0.6;

double _num(dynamic v) {
  final n = amountOf(v);
  return n.isFinite ? n : 0.0;
}

/// The leanest completed month's income over the trailing window, or null when
/// there is not one yet. monthlySeries is golden-locked, so this stays
/// consistent with every other income figure to the peso. Utang collected is
/// already excluded upstream (source 'receivable' is not income).
///
/// With four or more income months the single lowest is dropped as a possible
/// freak month (a between-jobs gap, a commission dry spell), so one outlier does
/// not false-alarm every commitment; with fewer, the plain minimum is used.
double? _leanIncome(Map<String, dynamic> data, DateTime ref) {
  final series = monthlySeries(data['transactions'], 7, ref);
  final incomes = <double>[
    for (final m in series.take(6))
      if (_num(m['income']) > 0) _num(m['income']),
  ]..sort();
  if (incomes.isEmpty) return null;
  return incomes.length >= 4 ? incomes[1] : incomes.first;
}

/// Weigh a hypothetical purchase against the user's real money. Pure and
/// read-only. [amount] is the one-time price in [AffordMode.oneTime], or the
/// monthly installment in [AffordMode.installment]; [termMonths] is only read
/// for an installment. Returns the parts a card needs plus a single [verdict]
/// of 'comfortable' | 'tight' | 'heavy' | 'no-fit' | 'unknown', where 'unknown'
/// means there is not enough income history to judge a recurring commitment.
Map<String, dynamic> affordCheck(
  Map<String, dynamic> data,
  DateTime ref, {
  required AffordMode mode,
  required dynamic amount,
  dynamic termMonths,
}) {
  final amt = _num(amount);
  final term = _num(termMonths).floor();

  final sts = safeToSpend(data, ref);
  final load = commitmentLoad(data, ref);
  final runway = emergencyRunway(data, ref);

  final available = _num(sts['available']);
  final buffer = _num(runway['buffer']);
  final avg = _num(runway['avgMonthlyExpense']);
  final typicalIncome = _num(load['typicalIncome']);
  final hasIncomeBase = load['hasIncomeBase'] == true && typicalIncome > 0;
  final monthlyCommitted = _num(load['monthlyCommitted']);
  final currentShare = load['committedShare'];
  final leanIncome = _leanIncome(data, ref);

  // Nothing to weigh yet: the card shows its prompt, not a verdict.
  if (!(amt > 0)) {
    return {
      'mode': mode == AffordMode.installment ? 'installment' : 'oneTime',
      'applicable': false,
      'verdict': 'unknown',
      'amount': amt,
    };
  }

  // The cash that leaves your pocket right away: the whole price for a one-time
  // buy, or the first installment for a plan. Both are `amt` here (a plan's
  // first payment is one month), kept as its own name so the intent is clear.
  final cashNow = amt;
  final availableAfter = available - cashNow;
  final fitsNow = availableAfter >= 0;
  final shortNow = availableAfter < 0 ? -availableAfter : 0.0;

  final base = <String, dynamic>{
    'mode': mode == AffordMode.installment ? 'installment' : 'oneTime',
    'applicable': true,
    'amount': amt,
    'availableNow': available,
    'availableAfter': availableAfter,
    'fitsNow': fitsNow,
    'shortNow': shortNow,
    'daysLeft': sts['daysLeft'],
    'payday': sts['payday'],
    'hasIncomeBase': hasIncomeBase,
    'incomeMonths': load['incomeMonths'],
    'typicalIncome': typicalIncome,
    'monthlyCommitted': monthlyCommitted,
    'currentShare': currentShare,
    'leanIncome': leanIncome,
  };

  if (mode == AffordMode.installment) {
    final months = term > 0 ? term : 0;
    final totalCost = months > 0 ? amt * months : null;
    final newMonthlyCommitted = monthlyCommitted + amt;
    final newShare =
        hasIncomeBase ? newMonthlyCommitted / typicalIncome : null;
    final newLeanShare = (leanIncome != null && leanIncome > 0)
        ? newMonthlyCommitted / leanIncome
        : null;
    final bool? fitsLean =
        newLeanShare == null ? null : newLeanShare <= _leanFitShare;
    // A "lean month" is only a real stress test if the user has actually had a
    // leaner sweldo than usual. With flat income the lean month IS the typical
    // month, so the card must not imply a downturn resilience the data cannot
    // show. 0.9: at least ~10% below typical to count as genuinely lean.
    final leanIsDistinct = leanIncome != null &&
        typicalIncome > 0 &&
        leanIncome < typicalIncome * 0.9;

    String verdict;
    if (!hasIncomeBase || newShare == null) {
      // Cannot honestly judge a recurring commitment with no typical income yet.
      verdict = 'unknown';
    } else if (newShare > 1 || (newLeanShare != null && newLeanShare > 1)) {
      // The commitment alone would eat a whole month (or a whole lean month):
      // it does not fit.
      verdict = 'no-fit';
    } else if (newShare >= _heavyShare || fitsLean == false) {
      verdict = 'heavy';
    } else if (newShare >= _tightShare) {
      verdict = 'tight';
    } else {
      verdict = 'comfortable';
    }
    // Even a well-fitting plan is at least heavy if you cannot make the first
    // payment from spendable cash without dipping into savings or bills.
    if (shortNow > 0 && (verdict == 'comfortable' || verdict == 'tight')) {
      verdict = 'heavy';
    }

    return {
      ...base,
      'termMonths': months,
      'monthly': amt,
      'totalCost': totalCost,
      'newMonthlyCommitted': newMonthlyCommitted,
      'newShare': newShare,
      'newLeanShare': newLeanShare,
      'fitsLean': fitsLean,
      'leanIsDistinct': leanIsDistinct,
      'verdict': verdict,
    };
  }

  // One-time buy. Your accounts are ONE pot: emergencyRunway.buffer already
  // sums every account, so the spendable cash in `available` is money that is
  // ALSO inside `buffer`, not a separate layer on top of it. So the honest test
  // is the whole price against the whole pot, never the cushion stacked above
  // spendable cash. `overflow` (price past spendable-till-sweldo) stays as the
  // informational "this dips past your day to day cash" figure.
  final overflow = shortNow;
  final eatsCushion = overflow > 0;
  final cushionAfter = buffer - amt > 0 ? buffer - amt : 0.0;
  final wipesCushion = amt > buffer; // more than all the money in your accounts
  final cushionMonthsLost =
      (avg > 0 && amt.isFinite) ? amt / avg : null;
  final runwayMonthsAfter = avg > 0 ? cushionAfter / avg : null;

  String verdict;
  if (wipesCushion) {
    verdict = 'no-fit';
  } else if (eatsCushion) {
    verdict = 'heavy';
  } else if (available > 0 && amt / available > _oneTimeTightFraction) {
    verdict = 'tight';
  } else {
    verdict = 'comfortable';
  }

  return {
    ...base,
    'eatsCushion': eatsCushion,
    'overflow': overflow,
    'buffer': buffer,
    'cushionAfter': cushionAfter,
    'wipesCushion': wipesCushion,
    'avgMonthlyExpense': avg,
    'cushionMonthsLost': cushionMonthsLost,
    'runwayMonthsAfter': runwayMonthsAfter,
    'verdict': verdict,
  };
}
