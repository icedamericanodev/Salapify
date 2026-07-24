// Your Number composer: no new money math, so these tests pin the composition
// contract: the card shows only when there is a positive number, every figure
// matches the engines it reads, crunch stays silent (the coach owns it), the
// comeback greeting triggers at three quiet days, and junk resolves to
// silence instead of a crash.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/cycle.dart';

void main() {
  final ref = DateTime(2026, 7, 10);
  const schedule = {'mode': 'monthly', 'day': 20};

  Map<String, dynamic> base({num balance = 10000}) => {
    'accounts': [
      {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': balance},
    ],
    'transactions': <Map<String, dynamic>>[],
    'settings': {'paydaySchedule': schedule},
  };

  test('a positive number shows, matching safeToSpend to the peso', () {
    final s = cycleStatus(base(), ref);
    expect(s.show, isTrue);
    expect(s.reason, 'ok');
    // 10000 available over the 10 days to the Jul 20 payday.
    expect(s.daysLeft, 10);
    expect(s.perDay, 1000);
    expect(s.payday, '2026-07-20');
    expect(s.onTrack, isNull, reason: 'thin logging keeps the pace silent');
  });

  test('fresh store stays silent', () {
    final s = cycleStatus({}, ref);
    expect(s.show, isFalse);
    expect(s.reason, 'fresh');
  });

  test('no liquid cash stays silent as quiet', () {
    final s = cycleStatus(base(balance: 0), ref);
    expect(s.show, isFalse);
    expect(s.reason, 'quiet');
  });

  test('committed cash stays silent; the coach crunch card owns it', () {
    final d = base(balance: 100);
    d['debts'] = [
      {
        'id': 'd1',
        'name': 'Card',
        'type': 'credit card',
        'remaining': 5000,
        'minPayment': 500,
        'dueDay': 15,
      },
    ];
    final s = cycleStatus(d, ref);
    expect(s.show, isFalse);
    expect(s.reason, 'committed');
  });

  test('a thick recent pace reads through paydayProjection', () {
    final d = base();
    d['transactions'] = [
      for (var day = 3; day <= 9; day++)
        {
          'id': 'e$day',
          'type': 'expense',
          'label': 'Food',
          'amount': 2800,
          'date': '2026-07-0$day',
        },
    ];
    final s = cycleStatus(d, ref);
    expect(s.show, isTrue);
    // 7 x 2800 over the trailing 14 days = 1400 a day against a number that
    // shrank: available is 10000 minus nothing (expenses already left the
    // balance in real life, but the fixture balance stays 10000), so perDay
    // stays 1000 and the pace runs over.
    expect(s.dailyPace, closeTo(1400, 0.001));
    expect(s.onTrack, isFalse);
    expect(s.easeOff, closeTo(400, 0.001));
    expect(s.gapDays, 1, reason: 'last log Jul 9, ref Jul 10');
    expect(s.comeback, isFalse);
  });

  test('three quiet days greet the comeback, two do not', () {
    final d = base();
    d['transactions'] = [
      {
        'id': 'e1',
        'type': 'expense',
        'label': 'Food',
        'amount': 100,
        'date': '2026-07-07',
      },
    ];
    expect(cycleStatus(d, ref).comeback, isTrue, reason: 'gap of 3 days');
    (d['transactions'] as List).add({
      'id': 'e2',
      'type': 'expense',
      'label': 'Load',
      'amount': 50,
      'date': '2026-07-08',
    });
    final s = cycleStatus(d, ref);
    expect(s.gapDays, 2);
    expect(s.comeback, isFalse);
  });

  test('one junk-dated row cannot mute the comeback greeting (QA)', () {
    // A corrupted date that sorts lexicographically above every real ISO date
    // must not win the latest-log race and hide the greeting for valid logs.
    final d = base();
    d['transactions'] = [
      {
        'id': 'e1',
        'type': 'expense',
        'label': 'Food',
        'amount': 100,
        'date': '2026-07-05',
      },
      {
        'id': 'bad',
        'type': 'expense',
        'label': 'Junk',
        'amount': 10,
        'date': 'corrupted!!',
      },
    ];
    final s = cycleStatus(d, ref);
    expect(s.gapDays, 5, reason: 'the valid Jul 5 log still counts');
    expect(s.comeback, isTrue);
  });

  test('a future-dated log reads as zero gap, never negative', () {
    final d = base();
    d['transactions'] = [
      {
        'id': 'e1',
        'type': 'expense',
        'label': 'Adv',
        'amount': 100,
        'date': '2030-01-01',
      },
    ];
    final s = cycleStatus(d, ref);
    expect(s.gapDays, 0);
    expect(s.comeback, isFalse);
  });

  test('overflowed balances stay silent instead of lying', () {
    final d = {
      'accounts': [
        {'id': 'a', 'name': 'A', 'kind': 'cash', 'balance': 1.7e308},
        {'id': 'b', 'name': 'B', 'kind': 'cash', 'balance': 1.7e308},
      ],
      'settings': {'paydaySchedule': schedule},
    };
    final s = cycleStatus(d, ref);
    expect(s.show, isFalse);
    expect(s.reason, 'nonfinite');
  });

  test('junk never throws', () {
    expect(cycleStatus(null, ref).show, isFalse);
    expect(cycleStatus('junk', ref).show, isFalse);
    final s = cycleStatus({
      'accounts': 'nope',
      'transactions': [
        42,
        'x',
        {'type': 'expense', 'date': 7},
      ],
    }, ref);
    expect(s.show, isFalse);
  });
}
