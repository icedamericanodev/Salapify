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

  group('paydayRitual', () {
    test('fires only on the scheduled payday', () {
      // Schedule pays on the 20th; ref July 10 is not a payday, July 20 is.
      expect(paydayRitual(base(), ref).isPayday, isFalse);
      final r = paydayRitual(base(), DateTime(2026, 7, 20));
      expect(r.isPayday, isTrue);
      expect(r.salaryLogged, isFalse);
    });

    test('a real income today flips salaryLogged; a collection does not', () {
      final payday = DateTime(2026, 7, 20);
      final d = base();
      d['transactions'] = [
        {
          'id': 'r1',
          'type': 'income',
          'source': 'receivable',
          'label': 'Migs paid',
          'amount': 500,
          'date': '2026-07-20',
        },
      ];
      expect(
        paydayRitual(d, payday).salaryLogged,
        isFalse,
        reason: 'getting paid back is not a salary',
      );
      (d['transactions'] as List).add({
        'id': 'i1',
        'type': 'income',
        'label': 'Sweldo',
        'amount': 20000,
        'date': '2026-07-20',
      });
      expect(paydayRitual(d, payday).salaryLogged, isTrue);
    });

    test('a fresh store never shows the ritual, and junk never throws', () {
      expect(paydayRitual({}, DateTime(2026, 7, 20)).isPayday, isFalse);
      expect(paydayRitual(null, ref).isPayday, isFalse);
      // A garbage schedule falls back to the semimonthly 15/31 default, so
      // the 15th IS a payday under it and the 14th is not, and junk
      // transactions never throw either way.
      final junky = {
        'accounts': [
          {'id': 'c'},
        ],
        'transactions': 'junk',
        'settings': {'paydaySchedule': 'garbage'},
      };
      expect(paydayRitual(junky, DateTime(2026, 7, 14)).isPayday, isFalse);
      expect(paydayRitual(junky, DateTime(2026, 7, 15)).isPayday, isTrue);
    });

    test('the default schedule pays on the 15th and end of month', () {
      final d = base();
      (d['settings'] as Map).remove('paydaySchedule');
      expect(paydayRitual(d, DateTime(2026, 7, 15)).isPayday, isTrue);
      expect(paydayRitual(d, DateTime(2026, 7, 31)).isPayday, isTrue);
      expect(paydayRitual(d, DateTime(2026, 7, 16)).isPayday, isFalse);
    });
  });

  group('cycleRecap', () {
    // Monthly payday on the 5th; ref July 10 makes the window Jul 5..Jul 10.
    Map<String, dynamic> seed() => {
      'accounts': [
        {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
      ],
      'settings': {
        'paydaySchedule': {'mode': 'monthly', 'day': 5},
      },
      'transactions': [
        {
          'id': 'i0',
          'type': 'income',
          'label': 'Old',
          'amount': 9999,
          'date': '2026-07-04',
        },
        {
          'id': 'i1',
          'type': 'income',
          'label': 'Sweldo',
          'amount': 10000,
          'date': '2026-07-05',
        },
        {
          'id': 'r1',
          'type': 'income',
          'source': 'receivable',
          'label': 'Migs',
          'amount': 500,
          'date': '2026-07-06',
        },
        {
          'id': 'e1',
          'type': 'expense',
          'label': 'Food',
          'amount': 2000,
          'date': '2026-07-06',
        },
        {
          'id': 'e2',
          'type': 'expense',
          'label': 'food',
          'amount': 1000,
          'date': '2026-07-08',
        },
        {
          'id': 'e3',
          'type': 'expense',
          'label': 'Grab',
          'amount': 500,
          'date': '2026-07-10',
        },
        {
          'id': 'e4',
          'type': 'expense',
          'label': 'Future',
          'amount': 777,
          'date': '2026-07-11',
        },
      ],
    };

    test('windows from the previous payday through today, to the peso', () {
      final r = cycleRecap(seed(), ref);
      expect(
        r['moneyIn'],
        10000,
        reason: 'Jul 4 income and the receivable are out',
      );
      expect(r['moneyOut'], 3500, reason: 'the Jul 11 future expense is out');
      expect(r['kept'], 6500);
      expect(r['keptRate'], 0.65);
      expect(r['daysLogged'], 4, reason: 'Jul 5, 6, 8, 10');
      expect(r['label'], 'payday cycle since Jul 5');
      expect(r['kicker'], 'MY CYCLE SINCE JUL 5');
      expect(r['monthKey'], 'cycle-2026-07-05');
      // Case-insensitive category fold, biggest first.
      final top = (r['topCats'] as List).first as Map;
      expect(top['label'], 'Food');
      expect(top['amount'], 3000);
      expect(r['verdict'], contains('Reaching payday with money left'));
    });

    test('a losing cycle stays kind and honest', () {
      final d = seed();
      (d['transactions'] as List).add({
        'id': 'e5',
        'type': 'expense',
        'label': 'Rent',
        'amount': 9000,
        'date': '2026-07-09',
      });
      final r = cycleRecap(d, ref);
      expect((r['kept'] as double) < 0, isTrue);
      expect(r['verdict'], contains('tracked every day of it honestly'));
      expect(r['verdict'], contains('fresh start'));
    });

    test('an empty window reads as a quiet cycle', () {
      final r = cycleRecap({
        'settings': {
          'paydaySchedule': {'mode': 'monthly', 'day': 5},
        },
      }, ref);
      expect(r['daysLogged'], 0);
      expect(r['verdict'], contains('A quiet cycle so far'));
      expect(r['keptRate'], isNull);
    });

    test('overflowed income guards keptRate to null, never NaN', () {
      final d = seed();
      // Added one by one: the seed list's inferred element type rejects a
      // List<dynamic> through addAll.
      for (final id in ['x1', 'x2']) {
        (d['transactions'] as List).add({
          'id': id,
          'type': 'income',
          'label': 'Big',
          'amount': 1.5e308,
          'date': '2026-07-07',
        });
      }
      final r = cycleRecap(d, ref);
      expect(r['keptRate'], isNull);
      expect(r['verdict'], contains('tracked this cycle honestly'));
    });

    test('junk never throws', () {
      expect(cycleRecap(null, ref)['daysLogged'], 0);
      expect(cycleRecap('junk', ref)['daysLogged'], 0);
      final r = cycleRecap({
        'transactions': [
          42,
          'x',
          {'type': 'expense', 'date': 'bad', 'amount': 'abc'},
        ],
        'payments': 'junk',
        'receivables': [
          {'payments': 'junk'},
        ],
      }, ref);
      expect(r['daysLogged'], 0);
    });
  });
}
