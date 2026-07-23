// The Windfall Split Planner. A lump of money lands at once, a 13th month, a
// mid-year bonus, a tax refund, a paluwagan payout, a big utang repaid, and this
// pours it through the SAME sound order of operations the next-peso card uses,
// each tier capped at its real gap, so the app never tells someone to bury cash
// they need next week or to fund a gadget goal while a credit card compounds.
//
// It composes engines already golden-locked to the RN app (emergencyRunway,
// goalPace) and mirrors surplus.dart's tier definitions and rate rules so the
// two screens never disagree. It only READS: it never posts a transaction, never
// touches savingsRate / safe-to-spend / the health score. A windfall is one-off,
// not recurring income, so nothing here feeds a monthly figure. A guide the user
// then acts on by hand, not a promise.

import 'analytics.dart' show emergencyRunway, goalPace;
import 'ledger.dart' show amountOf;

/// The exact interest-bearing set surplus.dart uses: a 0 rate on one of these
/// almost always means the user never entered it, not that the debt is free.
const Set<String> _interestBearingTypes = {
  'credit card',
  'bnpl',
  'personal loan',
  'mortgage',
  'auto',
  'short term',
  'long term',
};

/// Only debt above this MONTHLY rate jumps ahead of the fuller fund and goals,
/// the same 1%/mo (~12.7%/yr) line surplus.dart draws, safely above any PH
/// savings vehicle so a low-rate SSS or Pag-IBIG loan is never over-prioritized.
const double _highRateMonthly = 1;

double _num(dynamic v) {
  final n = amountOf(v);
  return n.isFinite ? n : 0.0;
}

double _max0(double x) => x > 0 ? x : 0.0;

/// Plan how to split a windfall of [amount]. [setAside] is money the user carves
/// off the top FIRST for known near-term costs (noche buena, gifts, tuition,
/// premiums), so the waterfall never claims cash already spoken for. Returns the
/// ordered [slices] (each {key,label,amount,detail}), the [leftover] that is
/// theirs to enjoy or invest long term, and honesty flags. `applicable` is false
/// when there is nothing to split.
Map<String, dynamic> splitWindfall(
  Map<String, dynamic> data,
  DateTime ref, {
  required dynamic amount,
  dynamic setAside,
}) {
  final gross = _num(amount);
  if (!(gross > 0)) {
    return {'applicable': false, 'gross': gross, 'slices': const [], 'leftover': 0.0};
  }
  final reserve = _num(setAside).clamp(0, gross).toDouble();
  var pool = gross - reserve;

  final runway = emergencyRunway(data, ref);
  final buffer = _num(runway['buffer']);
  final avg = _num(runway['avgMonthlyExpense']);
  final hasHistory = runway['monthsCovered'] != null;

  // Starter cushion: one month of typical spend when known, else a 10k floor.
  final usedFloor = !(hasHistory && avg > 0);
  final starterTarget = usedFloor ? _num(runway['firstTarget']) : avg;
  final starterGap = _max0(starterTarget - buffer);
  // Fuller fund is only meaningful once we know a typical month (3x it).
  final fullTarget = usedFloor ? 0.0 : avg * 3;

  final slices = <Map<String, dynamic>>[];

  // 1. Starter cushion first: a shock with no cushion becomes new utang.
  if (starterGap > 0 && pool > 0) {
    final give = pool < starterGap ? pool : starterGap;
    pool -= give;
    slices.add({
      'key': 'starter',
      'label': 'Emergency cushion',
      'amount': give,
      'detail': usedFloor
          ? 'Build a first cushion toward ${_whole(starterTarget)}. Log a few months and this becomes one month of your real spending.'
          : 'Top up toward one month of your usual spending (${_whole(starterTarget)}).',
    });
  }

  // 2. High-rate debts, costliest first, each capped at what is still owed.
  //    A 0-rate BNPL is NOT a forgotten rate: PH BNPL (SPayLater, Home Credit,
  //    Billease) is often genuinely 0% but with fixed due dates and steep late
  //    penalties, so it gets its own "clear it" tier below. A 0 rate on any
  //    OTHER interest-bearing debt (a card, a loan) almost always means the rate
  //    was never entered, so that stays a flag, never ranked on a fake zero.
  final debts = <Map<String, dynamic>>[];
  final bnplZero = <Map<String, dynamic>>[];
  var rateUnfilled = false;
  for (final raw in (data['debts'] is List ? data['debts'] as List : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    final remaining = _num(d['remaining']);
    if (!(remaining > 0.5)) continue;
    final rate = _num(d['monthlyRate']);
    if (rate >= _highRateMonthly) {
      debts.add({
        'name': _debtName(d['name']),
        'rate': rate,
        'remaining': remaining,
        'i': debts.length,
      });
    } else if (rate <= 0 && d['type'] == 'bnpl') {
      bnplZero.add({
        'name': _debtName(d['name']),
        'remaining': remaining,
        'i': bnplZero.length,
      });
    } else if (rate <= 0 && _interestBearingTypes.contains(d['type'])) {
      rateUnfilled = true;
    }
  }
  // Stable order: Dart's sort is not stable, so an insertion-index tiebreak
  // keeps exact ties in listed order, matching analytics._stableSorted.
  debts.sort((a, b) {
    final c = (b['rate'] as double).compareTo(a['rate'] as double);
    if (c != 0) return c;
    final r =
        (b['remaining'] as double).compareTo(a['remaining'] as double);
    return r != 0 ? r : (a['i'] as int).compareTo(b['i'] as int);
  });
  for (final d in debts) {
    if (pool <= 0) break;
    final owed = d['remaining'] as double;
    final give = pool < owed ? pool : owed;
    pool -= give;
    slices.add({
      'key': 'debt',
      'label': 'Pay down ${d['name']}',
      'amount': give,
      'detail':
          'At ${_ratePct(d['rate'] as double)} a month, paying this beats any savings return. Costliest debt first.',
    });
  }

  // 2b. Clear 0% BNPL installments. Even at no interest, a windfall is the best
  //     moment to wipe a fixed-date, penalty-bearing hulog: it frees the monthly
  //     payment and removes the late-fee risk. Smallest first, so whole
  //     installments are cleared and monthly obligations actually disappear.
  bnplZero.sort((a, b) {
    final c =
        (a['remaining'] as double).compareTo(b['remaining'] as double);
    return c != 0 ? c : (a['i'] as int).compareTo(b['i'] as int);
  });
  for (final b in bnplZero) {
    if (pool <= 0) break;
    final owed = b['remaining'] as double;
    final give = pool < owed ? pool : owed;
    pool -= give;
    slices.add({
      'key': 'bnpl',
      'label': 'Clear ${b['name']}',
      'amount': give,
      'detail':
          'A 0% installment still has fixed due dates and late penalties. Clearing it now frees your monthly cash and drops that risk.',
    });
  }

  // 3. Fuller fund up to three months, from the cushion AFTER the starter top-up.
  if (fullTarget > 0 && pool > 0) {
    final starterGiven = slices.isNotEmpty && slices.first['key'] == 'starter'
        ? slices.first['amount'] as double
        : 0.0;
    final fullGap = _max0(fullTarget - buffer - starterGiven);
    if (fullGap > 0) {
      final give = pool < fullGap ? pool : fullGap;
      pool -= give;
      slices.add({
        'key': 'fuller',
        'label': 'Grow your safety net',
        'amount': give,
        'detail': 'Toward three months of expenses (${_whole(fullTarget)}), real peace of mind.',
      });
    }
  }

  // 4. Active goals, soonest-behind first, each capped at what is left to fund.
  final goals = _activeGoals(data['goals'], ref);
  for (final g in goals) {
    if (pool <= 0) break;
    final rem = g['remaining'] as double;
    final give = pool < rem ? pool : rem;
    pool -= give;
    slices.add({
      'key': 'goal',
      'label': 'Fund ${g['name']}',
      'amount': give,
      'detail': 'Move this goal forward while you have the cash.',
    });
  }

  // 5. Whatever remains is genuinely theirs, guilt free, or for long-term
  // investing. Naming it keeps the plan followable instead of all-or-nothing.
  final leftover = _max0(pool);

  return {
    'applicable': true,
    'gross': gross,
    'setAside': reserve,
    'allocated': (gross - reserve) - leftover,
    'leftover': leftover,
    'slices': slices,
    'hasHistory': hasHistory,
    'usedFloor': usedFloor,
    'rateUnfilled': rateUnfilled,
  };
}

String _debtName(dynamic raw) =>
    (raw is String && raw.trim().isNotEmpty) ? raw.trim() : 'your debt';

List<Map<String, dynamic>> _activeGoals(dynamic goals, DateTime ref) {
  final out = <(Map<String, dynamic>, Map<String, dynamic>)>[];
  for (final g in (goals is List ? goals : const [])) {
    if (g is! Map) continue;
    final gm = g.cast<String, dynamic>();
    if (!(_num(gm['target']) > 0)) continue;
    final p = goalPace(gm, ref);
    if (p['done'] == true || !(_num(p['remaining']) > 0)) continue;
    out.add((gm, p));
  }
  int rank(String? s) =>
      s == 'behind' ? 0 : (s == 'due-soon' || s == 'active') ? 1 : 2;
  final indexed = List.generate(out.length, (i) => (out[i], i));
  indexed.sort((a, b) {
    final r = rank(a.$1.$2['status'] as String?)
        .compareTo(rank(b.$1.$2['status'] as String?));
    if (r != 0) return r;
    final da = (a.$1.$2['targetDate'] as String?) ?? '';
    final db = (b.$1.$2['targetDate'] as String?) ?? '';
    if (da.isNotEmpty && db.isNotEmpty && da != db) return da.compareTo(db);
    final rem =
        (b.$1.$2['remaining'] as num).compareTo(a.$1.$2['remaining'] as num);
    // Insertion-index tiebreak so exact ties keep listed order (stable).
    return rem != 0 ? rem : a.$2.compareTo(b.$2);
  });
  return [
    for (final e in indexed)
      {'name': _debtName(e.$1.$1['name']), 'remaining': _num(e.$1.$2['remaining'])},
  ];
}

String _whole(double v) {
  if (!v.isFinite) return '₱--';
  // Same trillion ceiling the card's peso formatter uses, so corrupt huge data
  // never prints int64-saturation garbage.
  if (v.abs() > 1e12) {
    return v < 0 ? '-₱1,000,000,000,000+' : '₱1,000,000,000,000+';
  }
  final n = v.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}₱$buf';
}

String _ratePct(double rate) {
  if (!rate.isFinite) return '--';
  if (rate.abs() > 999) return '999%+'; // corrupt rate, never int64 garbage
  final r = rate % 1 == 0 ? rate.toInt().toString() : rate.toStringAsFixed(1);
  return '$r%';
}
