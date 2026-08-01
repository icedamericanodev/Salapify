// Is the shared fixture still a phone somebody USES?
//
// Four separate machines now read livedInBlob: the render harness, the
// readability sweep, the machine-date check, and the cut-off check. All four are
// only as good as the states that fixture actually reaches, and none of them can
// tell the difference between "this screen is fine" and "this screen had nothing
// on it".
//
// That is not a theoretical worry, it is the same defect twice.
//
// Session 17: every screenshot ever taken was of an EMPTY app, because shoot()
// seeded an empty store. The rule "look at the screen" was followed faithfully
// against a fixture that could not show a money defect, and a crossed-out peso
// sign reached the founder's phone.
//
// Session 18, f2.90: every receivable in the fixture was already overdue, so the
// branch that prints a due date was unreachable and the check written for that
// exact line was a no-op on the day it shipped.
//
// And the fixture used to be pinned to a constant July 2026, which would have
// made the first of those return BY THE CALENDAR, with nobody touching a line.
//
// So this file asserts the fixture presents the states it exists to present. It
// is deliberately about the DATA and not about any screen: a screen test that
// happens to cover one of these would pass for its own reasons.

import 'package:flutter_test/flutter_test.dart';

import 'screens_shot.dart' show livedInBlob;

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in (livedInBlob[key] is List ? livedInBlob[key] as List : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

DateTime _parse(String iso) => DateTime.parse(iso);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  test('there is spending in the CURRENT month', () {
    // The one that would have broken on its own two days after being written.
    // Budget, Insights and the Home month card all compare against
    // DateTime.now(), so an expense dated last month is an expense those screens
    // correctly ignore, and every one of them reverts to its empty state.
    final thisMonth = _rows('transactions').where((t) {
      if (t['type'] != 'expense') return false;
      final d = _parse(t['date'] as String);
      return d.year == today.year && d.month == today.month;
    }).toList();
    expect(
      thisMonth,
      isNotEmpty,
      reason:
          'every expense in the fixture is outside the current month, so '
          'Budget, Insights and the Home month card all render as a phone '
          'nobody has used. That is the exact state this fixture replaced.',
    );
  });

  test('no entry is dated in the future', () {
    // A future-dated expense is not lived in, it is a bug that would make the
    // month totals disagree with the list that produced them.
    for (final t in _rows('transactions')) {
      final d = _parse(t['date'] as String);
      expect(
        d.isAfter(today),
        isFalse,
        reason: '${t['label']} is dated ${t['date']}, which has not happened',
      );
    }
  });

  test('somebody is overdue AND somebody still has time to pay', () {
    // BOTH, because the utang row has two branches and each needs a case. The
    // second half is exactly what was missing when "Due 2026-08-15" shipped: all
    // three receivables were overdue, so the due-date branch could not be
    // reached from this fixture and the guard written for it was silent.
    final due = _rows(
      'receivables',
    ).map((r) => _parse(r['dueDate'] as String)).toList();
    expect(due, isNotEmpty, reason: 'no receivables at all');
    expect(
      due.where((d) => d.isBefore(today)),
      isNotEmpty,
      reason: 'nobody is overdue, so the Overdue branch is unreachable',
    );
    expect(
      due.where((d) => !d.isBefore(today)),
      isNotEmpty,
      reason:
          'everybody is overdue, so the "Due <date>" branch is unreachable and '
          'any check written for it is a no-op. This is the f2.90 blind spot.',
    );
  });

  test('spending spans at least three distinct weekdays in the last 8 weeks', () {
    // The reports half of the session 26 month-boundary lesson. The Reports
    // WHEN YOU SPEND card only renders with at least three active weekdays in
    // the last eight weeks (lib/screens/reports.dart's activeDays < 3 gate), and
    // the fixture collapsing every date onto today at the start of a month is
    // exactly what hid it. The overdue self-check above caught the utang half at
    // the data level; this catches the spending half the same way, so a
    // regression is a red build and not a screen that quietly stops rendering a
    // card.
    final cutoff = today.subtract(const Duration(days: 56));
    final weekdays = _rows('transactions')
        .where((t) => t['type'] == 'expense')
        .map((t) => _parse(t['date'] as String))
        .where((d) => !d.isBefore(cutoff))
        .map((d) => d.weekday)
        .toSet();
    expect(
      weekdays.length,
      greaterThanOrEqualTo(3),
      reason:
          'expenses land on ${weekdays.length} distinct weekday(s) in the last '
          'eight weeks, so the weekday-spending pattern has no spread and '
          'Reports hides its WHEN YOU SPEND card, the session 26 rot.',
    );
  });

  test('the money that makes screens interesting is all present', () {
    // A short, blunt inventory. Not elegant, and better than the alternative:
    // somebody trimming the fixture to make one shot tidier and quietly
    // emptying four machines at once. CLAUDE.md says do not shrink it; this is
    // that sentence with a machine behind it.
    expect(_rows('accounts').length, greaterThanOrEqualTo(4), reason: 'accounts');
    expect(
      _rows('accounts').where((a) => (a['currencyCode'] ?? '') != ''),
      isNotEmpty,
      reason:
          'no foreign-currency account, so the conversion and exclusion rules, '
          'which are the most dangerous money code in the app, are drawn on no '
          'screen at all',
    );
    expect(_rows('assets'), isNotEmpty, reason: 'assets');
    expect(_rows('debts').length, greaterThanOrEqualTo(2), reason: 'debts');
    expect(_rows('payables'), isNotEmpty, reason: 'somebody I owe');
    expect(_rows('goals'), isNotEmpty, reason: 'a goal');
    expect(
      _rows('accounts').where((a) => (a['target'] ?? 0) != 0),
      isNotEmpty,
      reason:
          'no savings account has a target, which is the state that hid the '
          'cut-off "49% of PHP1..." defect until f2.89',
    );
    expect(
      _rows('transactions').where((t) => t['type'] == 'income'),
      isNotEmpty,
      reason: 'no income, so every rate and ratio in the app reads as zero',
    );
    expect(
      _rows('transactions').where((t) => (t['categoryId'] ?? '') != '').length,
      greaterThanOrEqualTo(8),
      reason:
          'too few categorised expenses for the breakdown cards to say '
          'anything. categoryId, not a plain category string: the engine does '
          'not read the latter and the first version of this fixture used it.',
    );
  });

  test('payday is still ahead, so the cycle card has something to say', () {
    final sched = (livedInBlob['settings'] as Map)['paydaySchedule'] as Map;
    expect(sched['mode'], 'monthly');
    expect(sched['day'], isA<int>());
    // Not asserting a specific number of days: a monthly payday is always
    // ahead of today by between 1 and 31 days, which is the point of using a
    // schedule rather than a stored date.
  });
}
