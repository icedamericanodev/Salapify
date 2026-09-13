// The Phase 5 interpretation layer for the Insights tab.
//
// Everything here COMPOSES the golden-locked engines (monthlySeries,
// savingsRate, weekdayPattern in analytics.dart; weekdayPeak and the
// category history in reports_calc.dart); nothing recomputes money from raw
// transactions except the note grouping in [changeDriver], which reads the
// same rows the same way _categoryTotals does. These are net-new
// presentation reads with no RN counterpart, so they are covered by unit
// tests rather than a golden replay, and every division guards its
// denominator.
//
// The honesty rules, each of which exists because a fabricated conclusion is
// worse than none:
// - A pulse never claims a best month before half the month has passed.
// - Category shifts pace the previous month to how far into this month we
//   are, so a half-finished month is never read against a full one.
// - Nothing here compares against history that does not exist; every read
//   has a null or not-comparable branch that says so.
// - A weekday claim needs a real gap (peak at least twice the lightest
//   day) and is worded as a tendency, never a fact.

import 'analytics.dart' show monthlySeries, savingsRate, weekdayPattern;
import 'ledger.dart' show amountOf;
import 'reports_calc.dart' show WeekdayPeak, weekdayPeak;

/// RN formatMoney: sign, peso sign, comma-grouped whole pesos. Same shape as
/// coach.dart's _m; sentences round to the peso.
String _m(dynamic n) {
  final v = amountOf(n);
  if (!v.isFinite) return '₱$v';
  final r = v.round();
  final neg = r < 0;
  final s = r.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}₱$buf';
}

List<Map<String, dynamic>> _txs(dynamic transactions) => [
  for (final t in (transactions is List ? transactions : const []))
    if (t is Map) t.cast<String, dynamic>(),
];

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

String _month7(dynamic date) {
  final s = (date ?? '').toString();
  return s.length >= 7 ? s.substring(0, 7) : s;
}

/// How far into [ref]'s month we are, 0..1. Day one of a 30-day month is
/// 1/30, the last day is 1.0.
double monthFraction(DateTime ref) {
  final daysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
  final f = ref.day / daysInMonth;
  return f < 1 ? f : 1.0;
}

/// A shift is only worth a sentence when the pesos are real. Same absolute
/// floor as Reports' over-usual flag, so the two screens agree on what
/// counts as meaningful.
const double shiftFloor = 500;

/// The one-line read of the month, or null when there is nothing honest to
/// say yet. [tone] is 'good' | 'steady' | 'attention'; [confidence] is
/// 'fact' (arithmetic on this month) or 'trend' (a claim about history).
class MonthPulse {
  final String headline;
  final String detail;
  final String tone;
  final String confidence;

  /// Savings rate percents for the screen's now-vs-last visual; null when
  /// that month had no income.
  final int? ratePctNow;
  final int? ratePctPrev;

  const MonthPulse({
    required this.headline,
    required this.detail,
    required this.tone,
    required this.confidence,
    this.ratePctNow,
    this.ratePctPrev,
  });
}

int? _pct(double? rate) {
  if (rate == null || !rate.isFinite) return null;
  final p = (rate * 100).round();
  // A junk backup can make income microscopic against expenses; the sentence
  // stays honest without printing a five-digit percent.
  return p.clamp(-999, 999);
}

/// The single most important interpretation of the current month.
///
/// Decision order, first match wins:
/// 1. No income logged this month: past mid-month with real spending it says
///    so plainly; earlier it stays silent (income often lands mid-cycle).
/// 2. Spending ahead of income: the attention read, a fact.
/// 3. Best savings share in the visible history (needs three or more prior
///    income months, past mid-month, and a genuinely positive rate).
/// 4. Keeping more / less / about the same share as last month (3-point
///    threshold so noise does not flip the sentence).
/// 5. First income month ever: states the share and that history sharpens it.
MonthPulse? monthPulse(Map<String, dynamic> data, DateTime ref) {
  final txs = data['transactions'];
  final rateNow = savingsRate(txs, data['payments'], ref);
  final prevRef = DateTime(ref.year, ref.month - 1, 15);
  final ratePrev = savingsRate(txs, data['payments'], prevRef);
  final frac = monthFraction(ref);

  if (rateNow == null || !rateNow.isFinite) {
    var spent = 0.0;
    final key = _monthKey(ref);
    for (final t in _txs(txs)) {
      if (t['type'] == 'expense' && _month7(t['date']) == key) {
        spent += amountOf(t['amount']);
      }
    }
    if (spent > 0 && frac >= 0.5) {
      return MonthPulse(
        headline: 'No income logged yet this month.',
        detail:
            '${_m(spent)} has gone out so far. If pay has landed, log it so '
            'the month reads true.',
        tone: 'attention',
        confidence: 'fact',
        ratePctPrev: _pct(ratePrev),
      );
    }
    return null;
  }

  final pctNow = _pct(rateNow)!;
  final pctPrev = _pct(ratePrev);

  if (rateNow < 0) {
    // The flagship attention read names the magnitude: pctNow is negative
    // here (net over income), so its size is how much more went out than
    // came in. A number the reader can act on beats "running ahead".
    return MonthPulse(
      headline: 'You have spent more than you earned this month.',
      detail:
          'About ${pctNow.abs()}% more has gone out than has come in '
          'so far.',
      tone: 'attention',
      confidence: 'fact',
      ratePctNow: pctNow,
      ratePctPrev: pctPrev,
    );
  }

  // Prior income months and their savings shares, for the best-month claim.
  final series = monthlySeries(txs, 7, ref);
  final priorRates = <double>[];
  for (var i = 0; i < series.length - 1; i++) {
    final income = series[i]['income'] as double;
    if (income > 0) priorRates.add((series[i]['net'] as double) / income);
  }
  final isBest =
      priorRates.length >= 3 &&
      rateNow > 0 &&
      frac >= 0.5 &&
      priorRates.every((r) => rateNow > r);
  if (isBest) {
    return MonthPulse(
      headline:
          'Your strongest savings month of the '
          '${priorRates.length + 1} you have logged income for.',
      detail:
          'You are keeping $pctNow% of your income, more than any other '
          'month here.',
      tone: 'good',
      confidence: 'trend',
      ratePctNow: pctNow,
      ratePctPrev: pctPrev,
    );
  }

  if (pctPrev != null) {
    final diff = rateNow - ((ratePrev!.isFinite) ? ratePrev : 0);
    if (diff >= 0.03) {
      return MonthPulse(
        headline: 'You are keeping more of your income than last month.',
        detail: '$pctNow% kept so far, against $pctPrev% last month.',
        tone: 'good',
        confidence: 'fact',
        ratePctNow: pctNow,
        ratePctPrev: pctPrev,
      );
    }
    if (diff <= -0.03) {
      return MonthPulse(
        headline: 'You are keeping less of your income than last month.',
        detail: '$pctNow% kept so far, against $pctPrev% last month.',
        tone: 'steady',
        confidence: 'fact',
        ratePctNow: pctNow,
        ratePctPrev: pctPrev,
      );
    }
    return MonthPulse(
      headline:
          'You are keeping about the same share of income as '
          'last month.',
      detail: '$pctNow% kept so far, $pctPrev% last month.',
      tone: 'steady',
      confidence: 'fact',
      ratePctNow: pctNow,
      ratePctPrev: pctPrev,
    );
  }

  return MonthPulse(
    headline: 'You have kept $pctNow% of your income this month.',
    detail:
        'As more months are logged, this compares itself to your '
        'history.',
    tone: 'steady',
    confidence: 'fact',
    ratePctNow: pctNow,
  );
}

/// One category whose spending moved meaningfully against last month.
class CategoryShift {
  final String label;

  /// This month so far.
  final double now;

  /// Last month, paced to how far into this month we are, so the comparison
  /// is like for like mid-month.
  final double pacedBefore;

  /// now - pacedBefore. Positive means running higher than last month.
  final double change;

  /// `Mostly from <note>.` when one note-group dominates the category, or
  /// `Mostly one ₱X entry.` when a single row does. Null when no driver
  /// stands out; the screen then says nothing rather than something weak.
  final String? driver;

  const CategoryShift({
    required this.label,
    required this.now,
    required this.pacedBefore,
    required this.change,
    this.driver,
  });
}

/// The month's meaningful category movements, or the honest reason there
/// are none yet.
class WhatChanged {
  /// Up to three shifts, biggest absolute move first. Empty when nothing
  /// crossed the floor or the months are not comparable.
  final List<CategoryShift> shifts;

  /// False before a third of the month has passed or when last month has no
  /// logged spending; [note] then says why in a sentence.
  final bool comparable;
  final String? note;

  const WhatChanged({
    required this.shifts,
    required this.comparable,
    this.note,
  });
}

Map<String, double> _categoryTotals(
  List<Map<String, dynamic>> txs,
  int offset,
  DateTime ref,
) {
  final key = _monthKey(DateTime(ref.year, ref.month - offset, 1));
  final totals = <String, double>{};
  for (final t in txs) {
    if (t['type'] != 'expense' || _month7(t['date']) != key) continue;
    final raw = t['label'];
    final label = (raw is String && raw.trim().isNotEmpty)
        ? raw.trim()
        : 'Other';
    totals[label] = (totals[label] ?? 0) + amountOf(t['amount']);
  }
  return totals;
}

/// Why a category moved: the dominant note-group or the dominant single
/// entry this month, or null when nothing stands out. "Dominates" means at
/// least half the category's spend, so the sentence is specific or absent.
String? changeDriver(dynamic transactions, String label, DateTime ref) {
  final key = _monthKey(ref);
  final byNote = <String, double>{};
  final display = <String, String>{};
  var total = 0.0;
  var biggestSingle = 0.0;
  var count = 0;
  for (final t in _txs(transactions)) {
    if (t['type'] != 'expense' || _month7(t['date']) != key) continue;
    final raw = t['label'];
    final rowLabel = (raw is String && raw.trim().isNotEmpty)
        ? raw.trim()
        : 'Other';
    if (rowLabel != label) continue;
    final amt = amountOf(t['amount']);
    if (!(amt > 0)) continue;
    total += amt;
    count += 1;
    if (amt > biggestSingle) biggestSingle = amt;
    final note = (t['note'] is String) ? (t['note'] as String).trim() : '';
    if (note.isNotEmpty) {
      final k = note.toLowerCase();
      byNote[k] = (byNote[k] ?? 0) + amt;
      // First spelling wins for display; the grouping stays case-blind.
      display.putIfAbsent(k, () => note);
    }
  }
  if (!(total > 0) || !total.isFinite) return null;
  String? topNote;
  var topSum = 0.0;
  byNote.forEach((k, v) {
    if (v > topSum) {
      topSum = v;
      topNote = k;
    }
  });
  // A note-group needs more than one row to be a pattern; a single noted
  // entry is better described as the single entry it is.
  if (topNote != null && topSum >= total * 0.5 && count >= 2) {
    final entries = _txs(transactions)
        .where(
          (t) =>
              t['type'] == 'expense' &&
              _month7(t['date']) == key &&
              (t['note'] is String) &&
              (t['note'] as String).trim().toLowerCase() == topNote,
        )
        .length;
    if (entries >= 2) return 'Mostly from ${display[topNote]}.';
  }
  if (biggestSingle >= total * 0.6 && count >= 2) {
    return 'Mostly one ${_m(biggestSingle)} entry.';
  }
  return null;
}

/// Category movements vs last month, honestly paced.
///
/// Gates: at least a third of the month must have passed (before that a
/// paced comparison is mostly noise, the same 34% threshold Reports uses
/// for its flags), and last month must have logged spending (an unlogged
/// month must never read as "everything dropped").
WhatChanged whatChanged(Map<String, dynamic> data, DateTime ref) {
  final txs = _txs(data['transactions']);
  final before = _categoryTotals(txs, 1, ref);
  final frac = monthFraction(ref);
  if (before.isEmpty) {
    return const WhatChanged(
      shifts: [],
      comparable: false,
      note: 'After another logged month, what moved shows up here.',
    );
  }
  if (frac < 0.34) {
    return const WhatChanged(
      shifts: [],
      comparable: false,
      note:
          'Still early in the month. Changes against last month show '
          'once more of it has passed.',
    );
  }
  final now = _categoryTotals(txs, 0, ref);
  final labels = <String>{...now.keys, ...before.keys};
  final shifts = <CategoryShift>[];
  for (final label in labels) {
    final cur = now[label] ?? 0.0;
    final paced = (before[label] ?? 0.0) * frac;
    if (!cur.isFinite || !paced.isFinite) continue;
    final change = cur - paced;
    if (change.abs() < shiftFloor) continue;
    shifts.add(
      CategoryShift(
        label: label,
        now: cur,
        pacedBefore: paced,
        change: change,
        driver: change > 0
            ? changeDriver(data['transactions'], label, ref)
            : null,
      ),
    );
  }
  // Stable order: biggest absolute move first, label as the tiebreak so the
  // list cannot reshuffle between two identical builds.
  shifts.sort((a, b) {
    final c = b.change.abs().compareTo(a.change.abs());
    return c != 0 ? c : a.label.compareTo(b.label);
  });
  return WhatChanged(
    shifts: shifts.length > 3 ? shifts.sublist(0, 3) : shifts,
    comparable: true,
  );
}

/// The trend chart's one-sentence conclusion: how many of the visible
/// months ended ahead. Null when no month has activity yet.
String? trendConclusion(List<Map<String, dynamic>> series) {
  var ahead = 0;
  var active = 0;
  for (final m in series) {
    final income = amountOf(m['income']);
    final expenses = amountOf(m['expenses']);
    if (income > 0 || expenses > 0) active += 1;
    if (amountOf(m['net']) > 0) ahead += 1;
  }
  if (active == 0) return null;
  if (active == 1) {
    return ahead == 1
        ? 'One month logged so far, and it ended ahead.'
        : 'One month logged so far.';
  }
  return 'You kept more than you spent in $ahead of the last '
      '$active active months.';
}

/// A weekday tendency worth one quiet line, or null. Requires at least
/// three active days and a peak at least twice the lightest day, so a
/// near-flat week never gets dressed up as a pattern. Worded as a tendency
/// because a 56-day average is one, not a fact about next Friday.
const List<String> _daysLong = [
  'Sundays',
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
];

String? weekdayLine(Map<String, dynamic> data, DateTime ref) {
  final pattern = weekdayPattern(data['transactions'], ref);
  final WeekdayPeak peak = weekdayPeak(pattern);
  if (peak.activeDays < 3 || peak.peakDay < 0 || peak.lightDay < 0) {
    return null;
  }
  if (!(peak.peakAvg >= peak.lightAvg * 2)) return null;
  return '${_daysLong[peak.peakDay]} tend to be your biggest spending day, '
      'about ${_m(peak.peakAvg)} on average.';
}
