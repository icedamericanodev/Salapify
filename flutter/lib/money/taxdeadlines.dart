// Upcoming BIR filing deadlines for a self-employed or freelance taxpayer on
// the calendar year, ported from mobile/lib/taxdeadlines.js and golden locked
// against it.
//
// Pure, and it takes "today" rather than reading a clock, which is what makes
// it testable at a year boundary and on a leap day. The screen reads the
// device date every time it opens, so nothing here depends on a notification
// firing: many Android phones kill those silently, and a filing date you
// missed because a push did not arrive is the worst possible way to learn
// this app is unreliable.
//
// Awareness only, never a filing service, and the screen says so out loud.

/// One filing deadline: what it is, when, and how far away.
class TaxDeadline {
  final String form;
  final String title;
  final String what;
  final int year;
  final DateTime date;
  final int daysLeft;
  const TaxDeadline({
    required this.form,
    required this.title,
    required this.what,
    required this.year,
    required this.date,
    required this.daysLeft,
  });
}

class _Spec {
  final String form;
  final String title;
  final String what;
  final int month;
  final int day;
  const _Spec(this.form, this.title, this.what, this.month, this.day);
}

const _annual = _Spec(
  '1701 / 1701A',
  'Annual income tax',
  'Income tax for the whole of last year.',
  4,
  15,
);

const _incomeQuarterly = [
  _Spec(
    '1701Q',
    'Quarterly income tax',
    'Income tax for January to March.',
    5,
    15,
  ),
  _Spec(
    '1701Q',
    'Quarterly income tax',
    'Income tax for April to June.',
    8,
    15,
  ),
  _Spec(
    '1701Q',
    'Quarterly income tax',
    'Income tax for July to September.',
    11,
    15,
  ),
];

/// Percentage tax applies only to a non-VAT filer who is NOT on the 8% option,
/// because the 8% replaces it.
const _percentageQuarterly = [
  _Spec(
    '2551Q',
    'Percentage tax',
    '3% percentage tax for October to December.',
    1,
    25,
  ),
  _Spec(
    '2551Q',
    'Percentage tax',
    '3% percentage tax for January to March.',
    4,
    25,
  ),
  _Spec(
    '2551Q',
    'Percentage tax',
    '3% percentage tax for April to June.',
    7,
    25,
  ),
  _Spec(
    '2551Q',
    'Percentage tax',
    '3% percentage tax for July to September.',
    10,
    25,
  ),
];

/// The upcoming deadlines, soonest first.
///
/// A deadline falling TODAY still counts as upcoming, with 0 days left, which
/// is the whole reason the comparison is against local midnight rather than
/// the current moment. Telling someone a filing is "past" at 9am on the day it
/// is due would be both wrong and alarming.
List<TaxDeadline> taxDeadlines(
  DateTime? today, {
  bool onEightPercent = false,
  int count = 4,
}) {
  // A DELIBERATE divergence from RN, the only one in this port, and it is
  // here because the goldens showed what RN actually does: JS coerces
  // new Date(null) to the epoch, so taxDeadlines(null) returns filing
  // deadlines dated 1970 with a confident days-left count. That is a
  // coercion wart, not a behaviour, and printing "Annual income tax, April
  // 15 1970, in 104 days" on a tax screen would be worse than printing
  // nothing. Junk strings already return empty in RN too; this makes null
  // behave like the junk it is.
  if (today == null) return const [];
  final n = count.isFinite ? count : 4;
  final wanted = n < 1 ? 1 : (n > 12 ? 12 : n);
  final specs = [
    _annual,
    ..._incomeQuarterly,
    if (!onEightPercent) ..._percentageQuarterly,
  ];
  final startToday = DateTime(today.year, today.month, today.day);
  final out = <TaxDeadline>[];
  // This year and next, so the list wraps past a year boundary correctly.
  for (final y in [today.year, today.year + 1]) {
    for (final s in specs) {
      final d = DateTime(y, s.month, s.day);
      if (!d.isBefore(startToday)) {
        out.add(
          TaxDeadline(
            form: s.form,
            title: s.title,
            what: s.what,
            year: y,
            date: d,
            // Whole days, computed from local midnight to local midnight. A
            // difference in days would be wrong across a DST change; the
            // Philippines has none, and the RN app does the same arithmetic,
            // so this stays identical to the live app by construction.
            daysLeft: (d.difference(startToday).inHours / 24).round(),
          ),
        );
      }
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out.take(wanted).toList();
}

/// "Due today", "Tomorrow", "In 9 days", "In about 3 months".
///
/// Rounded to months past 30 days on purpose: nobody plans around "in 87
/// days", and a precise number that far out reads as false precision.
String deadlineDaysLabel(int n) {
  if (n <= 0) return 'Due today';
  if (n == 1) return 'Tomorrow';
  if (n <= 30) return 'In $n days';
  final months = (n / 30).round();
  return 'In about $months ${months == 1 ? 'month' : 'months'}';
}
