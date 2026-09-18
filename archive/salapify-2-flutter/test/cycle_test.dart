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
      // A garbage schedule is not a schedule the user set, so the card makes
      // no claim on any day, and junk transactions never throw either way.
      final junky = {
        'accounts': [
          {'id': 'c'},
        ],
        'transactions': 'junk',
        'settings': {'paydaySchedule': 'garbage'},
      };
      expect(paydayRitual(junky, DateTime(2026, 7, 14)).isPayday, isFalse);
      expect(paydayRitual(junky, DateTime(2026, 7, 15)).isPayday, isFalse);
    });

    test('no payday set means the card never claims it is payday', () {
      // This test used to assert the opposite, pinning a real bug: with no
      // schedule stored, normalizeSchedule falls back to 15/31 and the card
      // told EVERY user it was payday on the 15th and the month end. Nothing
      // in the app wrote paydaySchedule, so a monthly-on-the-30th earner and
      // every swing-income user were simply told something false, with no way
      // to correct it. A forecast may guess; a claim may not.
      final d = base();
      (d['settings'] as Map).remove('paydaySchedule');
      expect(paydayRitual(d, DateTime(2026, 7, 15)).isPayday, isFalse);
      expect(paydayRitual(d, DateTime(2026, 7, 31)).isPayday, isFalse);
      expect(paydayRitual(d, DateTime(2026, 7, 16)).isPayday, isFalse);
    });

    test('setting a payday turns the card back on, on that day only', () {
      final d = base();
      (d['settings'] as Map)['paydaySchedule'] = {'mode': 'monthly', 'day': 30};
      expect(paydayRitual(d, DateTime(2026, 7, 30)).isPayday, isTrue);
      expect(paydayRitual(d, DateTime(2026, 7, 15)).isPayday, isFalse);
      expect(paydayRitual(d, DateTime(2026, 7, 31)).isPayday, isFalse);
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

    test(
      'categoryId resolves through categories, matching monthRecap (QA)',
      () {
        // Imported RN data carries categoryId with the note as label; the two
        // windows on one screen must name the same top category.
        final d = seed();
        d['categories'] = [
          {'id': 'cat1', 'name': 'Food'},
        ];
        d['transactions'] = [
          {
            'id': 'e1',
            'type': 'expense',
            'label': 'grab to work',
            'amount': 2000,
            'date': '2026-07-06',
          },
          {
            'id': 'e2',
            'type': 'expense',
            'label': 'jollibee',
            'amount': 900,
            'categoryId': 'cat1',
            'date': '2026-07-07',
          },
          {
            'id': 'e3',
            'type': 'expense',
            'label': 'mcdo',
            'amount': 700,
            'categoryId': 'cat1',
            'date': '2026-07-08',
          },
        ];
        final r = cycleRecap(d, ref);
        final top = (r['topCats'] as List).first as Map;
        expect(top['label'], 'grab to work');
        expect(top['amount'], 2000);
        final second = (r['topCats'] as List)[1] as Map;
        expect(
          second['label'],
          'Food',
          reason: 'the two cat1 rows fold into the category name',
        );
        expect(second['amount'], 1600);
      },
    );

    test('on payday itself the card shows the FINISHED cycle (QA)', () {
      // Ref Jul 5 IS the payday: the window becomes Jun 5 through Jul 4, so
      // the fresh salary stays out of the finished story and the card never
      // brags "kept 100%" about a cycle a few hours old.
      final d = seed();
      final r = cycleRecap(d, DateTime(2026, 7, 5));
      expect(r['label'], 'payday cycle since Jun 5');
      expect(
        r['moneyIn'],
        9999,
        reason: 'only the Jul 4 income sits in Jun 5..Jul 4',
      );
      expect(r['moneyOut'], 0);
    });

    test('cycleRecapText says cycle, never month', () {
      final r = cycleRecap(seed(), ref);
      final hidden = cycleRecapText(r, (n) => 'P$n', true);
      expect(hidden, contains('of my income this cycle'));
      expect(hidden.contains('month'), isFalse);
      final open = cycleRecapText(r, (n) => 'P$n');
      expect(open, contains('Money in P10000.0'));
      expect(open, contains('My payday cycle since Jul 5 with Salapify:'));
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
