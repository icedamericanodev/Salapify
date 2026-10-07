// The personal line at the top of a lesson.
//
// This is what separates a coach from an article: the lesson opens by saying
// something true about THIS person's money, drawn from what they have actually
// logged. "You currently have active debt" lands differently from "debt can be
// expensive", and it costs nothing extra to say, because the data is already
// on the phone.
//
// Two hard rules, because getting this wrong is worse than not doing it.
//
// 1. Never invent a fact. Every line below is derived from logged data, and
//    when there is not enough of it the engine says so plainly instead of
//    guessing. A finance app that tells you something false about your own
//    money loses the only thing it has.
// 2. Never scold. The insight sets context, it does not grade. "You have
//    active debt" is a fact; "you have too much debt" is a judgment nobody
//    asked for.
//
// Pure and unit tested, like the rest of the money layer. No widgets here.

import 'ledger.dart' show amountOf;

class LessonInsight {
  /// The line to show. Never empty.
  final String text;

  /// True when this came from the user's real data. False means the honest
  /// fallback, which the UI presents differently so it never masquerades as
  /// a personal observation.
  final bool personalized;

  const LessonInsight(this.text, {required this.personalized});
}

/// The fallback, worded as a promise rather than an apology.
const LessonInsight _notEnoughYet = LessonInsight(
  'We will make this lesson personal once there is a bit more logged. '
  'Nothing here is a guess about your money.',
  personalized: false,
);

DateTime? _day(dynamic raw) {
  final s = (raw ?? '').toString();
  if (s.length < 10) return null;
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  final when = DateTime(y, m, d);
  // Reject rolled-over impossibles like 2026-02-31 rather than accept a date
  // the user never entered.
  if (when.year != y || when.month != m || when.day != d) return null;
  return when;
}

List<Map> _rows(dynamic raw) => [
  for (final x in (raw is List ? raw : const []))
    if (x is Map) x,
];

/// The one line to open [trackId]'s lesson with, for this data.
///
/// [trackId] steers WHICH true thing gets said: a debt lesson leads with the
/// debt fact, a swing-income lesson leads with the income pattern. The facts
/// themselves are the same either way, so the insight can never contradict
/// itself between two lessons opened a minute apart.
LessonInsight lessonInsight(dynamic data, String trackId, DateTime now) {
  final d = data is Map ? data : const {};
  final txs = _rows(d['transactions']);
  final debts = _rows(d['debts']);

  // ---- facts, gathered once ----
  var expenseCount = 0;
  DateTime? lastIncome;
  DateTime? firstLog;
  var incomeCount = 0;
  for (final t in txs) {
    final when = _day(t['date']);
    if (when == null) continue;
    if (firstLog == null || when.isBefore(firstLog)) firstLog = when;
    if (t['type'] == 'expense') {
      expenseCount++;
    } else if (t['type'] == 'income') {
      incomeCount++;
      if (lastIncome == null || when.isAfter(lastIncome)) lastIncome = when;
    }
  }

  final activeDebts = debts.where((x) => amountOf(x['remaining']) > 0).toList();
  final hasDebt = activeDebts.isNotEmpty;
  final daysSinceIncome = lastIncome == null
      ? null
      : DateTime(now.year, now.month, now.day).difference(lastIncome).inDays;

  // Savings habit: a transfer or an expense into savings is not tracked as a
  // category here, so the honest proxy is goal funding. Only claim the habit
  // when there is real evidence of it.
  final goals = _rows(d['goals']);
  final funded = goals.where((g) => amountOf(g['saved']) > 0).length;

  // ---- the track's preferred line, then the general ones ----
  if (trackId == 'debt' && hasDebt) {
    final n = activeDebts.length;
    return LessonInsight(
      n == 1
          ? 'You have one debt still being paid down. This lesson is about '
                'exactly that.'
          : 'You have $n debts still being paid down. This lesson is about '
                'exactly that.',
      personalized: true,
    );
  }

  if (trackId == 'swing') {
    if (incomeCount >= 3) {
      return LessonInsight(
        'You have $incomeCount income entries logged, which is enough to '
        'start seeing your pattern.',
        personalized: true,
      );
    }
    if (daysSinceIncome != null && daysSinceIncome >= 21) {
      return LessonInsight(
        'Your last logged income was $daysSinceIncome days ago. Uneven gaps '
        'are exactly what this track is for.',
        personalized: true,
      );
    }
  }

  if (trackId == 'cushion' && funded > 0) {
    return LessonInsight(
      funded == 1
          ? 'You already have money set aside in one goal. This builds on '
                'that.'
          : 'You already have money set aside across $funded goals. This '
                'builds on that.',
      personalized: true,
    );
  }

  // General facts, most specific first.
  if (hasDebt) {
    return LessonInsight(
      'You currently have debt being paid down, so this one is worth '
      'reading with that in mind.',
      personalized: true,
    );
  }
  if (daysSinceIncome != null && daysSinceIncome >= 21) {
    return LessonInsight(
      'You have not logged income in $daysSinceIncome days.',
      personalized: true,
    );
  }
  if (expenseCount >= 20) {
    return LessonInsight(
      'You have $expenseCount expenses logged, so your numbers here are '
      'your own, not an example.',
      personalized: true,
    );
  }
  if (expenseCount > 0) {
    return LessonInsight(
      'Your spending history is still short, so keep logging as you read.',
      personalized: true,
    );
  }
  return _notEnoughYet;
}
