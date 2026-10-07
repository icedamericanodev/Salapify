// Unit suite for money/cashflow_calendar.dart. Net-new composition math (no RN
// counterpart), so it is covered by these Dart tests, not a golden replay. The
// invariants that must never break: the running balance is exactly the start
// plus the cumulative money in minus money out; a payday raises the balance on
// its day and a bill or debt due lowers it; a bill already posted this month is
// never double counted; the lowest day and the run-out flag are correct; and
// junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/cashflow_calendar.dart';

void main() {
  // A steady setup: 8,000 liquid today (the 10th), sweldo of 20,000 recurring
  // income on the 15th, rent 12,000 recurring bill on the 20th, and a credit
  // card minimum of 1,500 due on the 25th.
  Map<String, dynamic> data() => {
    'accounts': [
      {'id': 'g', 'kind': 'ewallet', 'balance': 8000},
      {'id': 's', 'kind': 'savings', 'balance': 50000}, // not liquid
    ],
    'recurring': [
      {
        'id': 'r1',
        'type': 'income',
        'label': 'Sweldo',
        'amount': 20000,
        'dayOfMonth': 15,
      },
      {
        'id': 'r2',
        'type': 'expense',
        'label': 'Rent',
        'amount': 12000,
        'dayOfMonth': 20,
      },
    ],
    'debts': [
      {
        'id': 'd1',
        'name': 'Card',
        'remaining': 30000,
        'minPayment': 1500,
        'dueDay': 25,
      },
    ],
  };

  final ref = DateTime(2026, 7, 10);

  List<Map<String, dynamic>> daysOf(Map<String, dynamic> r) =>
      (r['days'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> dayAt(Map<String, dynamic> r, String iso) =>
      daysOf(r).firstWhere((d) => d['date'] == iso);

  test('start balance is the liquid accounts only, never savings', () {
    final r = cashFlowCalendar(data(), ref);
    expect(r['startBalance'], 8000);
  });

  test('the running balance is exactly start plus cumulative in minus out', () {
    final r = cashFlowCalendar(data(), ref);
    var running = r['startBalance'] as double;
    for (final d in daysOf(r)) {
      running += (d['moneyIn'] as double) - (d['moneyOut'] as double);
      expect(
        (d['balance'] as double),
        closeTo(running, 1e-9),
        reason: 'balance must equal the carried running total on ${d['date']}',
      );
    }
    expect(r['endBalance'], closeTo(running, 1e-9));
  });

  test('sweldo raises the balance on payday, rent and card lower it', () {
    final r = cashFlowCalendar(data(), ref);
    // Window runs 10 Jul to 31 Jul. Before the 15th: still 8000.
    expect(dayAt(r, '2026-07-14')['balance'], 8000);
    // The 15th: +20000 sweldo.
    expect(dayAt(r, '2026-07-15')['moneyIn'], 20000);
    expect(dayAt(r, '2026-07-15')['balance'], 28000);
    // The 20th: -12000 rent.
    expect(dayAt(r, '2026-07-20')['moneyOut'], 12000);
    expect(dayAt(r, '2026-07-20')['balance'], 16000);
    // The 25th: -1500 card minimum, bank adjusted (25 Jul 2026 is a Saturday,
    // so the due moves to Monday the 27th).
    final card = dayAt(r, '2026-07-27');
    expect(card['moneyOut'], 1500);
    expect(card['balance'], 14500);
    // End of month balance: 8000 + 20000 - 12000 - 1500 = 14500.
    expect(r['endBalance'], 14500);
  });

  test('events are labeled and carry the right kind', () {
    final r = cashFlowCalendar(data(), ref);
    final sweldo = (dayAt(r, '2026-07-15')['events'] as List).first;
    expect(sweldo['label'], 'Sweldo');
    expect(sweldo['kind'], 'income');
    expect(sweldo['amount'], 20000);
    final rent = (dayAt(r, '2026-07-20')['events'] as List).first;
    expect(rent['kind'], 'bill');
    final card = (dayAt(r, '2026-07-27')['events'] as List).first;
    expect(card['label'], 'Card');
    expect(card['kind'], 'debt');
  });

  test('each event carries the running balance right after it', () {
    // Two events on one day: an income and a bill land on the same date, and
    // each must show its own running balance, not the shared day close.
    final d = {
      'accounts': [
        {'id': 'c', 'kind': 'cash', 'balance': 1000},
      ],
      'recurring': [
        {
          'id': 'a',
          'type': 'income',
          'label': 'Bonus',
          'amount': 5000,
          'dayOfMonth': 15,
        },
        {
          'id': 'b',
          'type': 'expense',
          'label': 'Rent',
          'amount': 3000,
          'dayOfMonth': 15,
        },
      ],
      'debts': [],
    };
    final r = cashFlowCalendar(d, ref);
    final events = (dayAt(r, '2026-07-15')['events'] as List).cast<Map>();
    expect(events.length, 2);
    // Income applies first (recurring loop order): 1000 + 5000 = 6000, then
    // 6000 - 3000 = 3000. The two balanceAfter values differ.
    expect(events[0]['balanceAfter'], 6000);
    expect(events[1]['balanceAfter'], 3000);
    // The last event of the window ends at the window end balance.
    expect(events[1]['balanceAfter'], dayAt(r, '2026-07-15')['balance']);
  });

  test('a tight month flags the lowest day and the run-out', () {
    // Only 500 liquid, rent 12,000 on the 20th, sweldo not until next month.
    final tight = {
      'accounts': [
        {'id': 'g', 'kind': 'cash', 'balance': 500},
      ],
      'recurring': [
        {
          'id': 'r2',
          'type': 'expense',
          'label': 'Rent',
          'amount': 12000,
          'dayOfMonth': 20,
        },
      ],
      'debts': [],
    };
    final r = cashFlowCalendar(tight, ref);
    expect(r['anyNegative'], true);
    expect((r['lowest'] as Map)['date'], '2026-07-20');
    expect((r['lowest'] as Map)['balance'], 500 - 12000);
    expect(r['tightestDrop'], 12000);
  });

  test('a bill already posted this month is not double counted', () {
    final d = data();
    // Mark rent as already posted this month, so it must not appear again.
    (d['recurring'] as List)[1]['lastPosted'] = '2026-07';
    final r = cashFlowCalendar(d, ref);
    // No rent event on the 20th, and end balance is 8000 + 20000 - 1500.
    expect(dayAt(r, '2026-07-20')['moneyOut'], 0);
    expect(r['endBalance'], 26500);
  });

  test('a recurring day already passed this month does not appear', () {
    // A bill on the 5th, today is the 10th, not yet posted: its occurrence is
    // next month, outside this month's window, so it must not show.
    final d = {
      'accounts': [
        {'id': 'g', 'kind': 'cash', 'balance': 5000},
      ],
      'recurring': [
        {
          'id': 'r',
          'type': 'expense',
          'label': 'Netflix',
          'amount': 500,
          'dayOfMonth': 5,
        },
      ],
      'debts': [],
    };
    final r = cashFlowCalendar(d, ref);
    expect(
      r['endBalance'],
      5000,
      reason: 'the 5th is behind us, next hit is next month',
    );
  });

  test('a fixed look-ahead window runs the right number of days', () {
    final r = cashFlowCalendar(data(), ref, days: 7);
    // 10 Jul through 17 Jul inclusive is 8 day rows.
    expect(daysOf(r).length, 8);
    expect(daysOf(r).last['date'], '2026-07-17');
  });

  test('an empty app is a flat line at zero, not a crash', () {
    final r = cashFlowCalendar({}, ref);
    expect(r['startBalance'], 0);
    expect(r['endBalance'], 0);
    expect(r['anyNegative'], false);
    for (final d in daysOf(r)) {
      expect(d['balance'], 0);
    }
  });

  test('non-finite balances and amounts are guarded', () {
    final d = {
      'accounts': [
        {'id': 'g', 'kind': 'cash', 'balance': double.infinity},
      ],
      'recurring': [
        {
          'id': 'r',
          'type': 'income',
          'label': 'x',
          'amount': 'abc',
          'dayOfMonth': 15,
        },
      ],
      'debts': [],
    };
    final r = cashFlowCalendar(d, ref);
    // Infinite balance coerces to 0, junk amount is dropped; nothing throws.
    expect(r['startBalance'], 0);
    expect(r['endBalance'], 0);
  });
}
