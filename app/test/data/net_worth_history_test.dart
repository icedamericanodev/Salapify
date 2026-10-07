// The monthly net worth records: what is written, what survives, and what
// must never be written at all.
//
// Founder decision, 2026-10-07: "Save from now on". That makes this stored
// data, the category this repository stops for, so the round trip is
// measured rather than assumed, along with the ways a store like this goes
// wrong:
//   1. It writes, and the next launch cannot read it back.
//   2. A past month moves when today's balance does, so the "history" is
//      really just today repeated.
//   3. The example data's balances are recorded as somebody's past.
//   4. A bad row, or an unknown field from a newer build, stops a ledger
//      loading or is silently dropped on the next save.
//   5. It survives a wipe.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/net_worth_history.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

FinancialPosition _position(double assets, double liabilities) =>
    computePosition(<Account>[
      Account(
        id: 'a',
        name: 'Bank',
        kind: AccountKind.bank,
        institution: 'Bank',
        balance: Money.fromDouble(assets),
        monogram: 'B',
      ),
      Account(
        id: 'l',
        name: 'Card',
        kind: AccountKind.credit,
        institution: 'Bank',
        balance: Money.fromDouble(liabilities),
        monogram: 'C',
      ),
    ], null);

NetWorthPoint _p(int y, int m, double a, double l) => NetWorthPoint(
  year: y,
  month: m,
  assets: Money.fromDouble(a),
  liabilities: Money.fromDouble(l),
);

/// A LOADED app, the way it really starts: saving is off until [restore]
/// has read the file, and recording rides on saving, so an unloaded state
/// records nothing by design. A first launch loads the example book.
Future<FinancialState> _loaded(DateTime clock) async {
  final FinancialState s = FinancialState(
    clock: clock,
    store: MemorySnapshotStore(),
  );
  await s.restore();
  return s;
}

/// A real book: loaded, the example data removed, and one real account, so
/// recording is on and there is something to measure.
Future<FinancialState> _realBook(DateTime clock) async {
  final FinancialState s = await _loaded(clock);
  s.removeSampleData();
  s.addAccount(
    const Account(
      id: 'acc_bpi',
      name: 'BPI Savings',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: Money.pesos(20000),
      monogram: 'BPI',
    ),
  );
  return s;
}

Transaction _spend(String id, double amount, String date) => Transaction(
  id: id,
  type: TransactionType.expense,
  amount: Money.fromDouble(amount),
  category: 'Groceries',
  accountId: 'acc_bpi',
  date: date,
  createdAt: 0,
);

void main() {
  group('the engine', () {
    test('this month is replaced, earlier months are left alone', () {
      final List<NetWorthPoint> before = <NetWorthPoint>[
        _p(2026, 8, 1000, 100),
        _p(2026, 9, 2000, 100),
      ];
      final List<NetWorthPoint> after = recordNetWorth(
        before,
        _position(5000, 300),
        DateTime(2026, 9, 30),
      );
      expect(after.map((NetWorthPoint p) => p.key), <String>[
        '2026-08',
        '2026-09',
      ]);
      expect(after.first.assets, const Money.pesos(1000));
      // DIRECTIONAL: this month really took the new figures.
      expect(after.last.netWorth, const Money.pesos(4700));
    });

    test('a new month adds a point and keeps the last one as it was', () {
      final List<NetWorthPoint> after = recordNetWorth(
        <NetWorthPoint>[_p(2026, 9, 2000, 100)],
        _position(2500, 0),
        DateTime(2026, 10, 1),
      );
      expect(after, hasLength(2));
      expect(after.first.netWorth, const Money.pesos(1900));
      expect(after.last.key, '2026-10');
    });

    test('nothing changed hands back the same list, so no extra work', () {
      final List<NetWorthPoint> h = <NetWorthPoint>[_p(2026, 9, 5000, 300)];
      expect(
        identical(
          recordNetWorth(h, _position(5000, 300), DateTime(2026, 9, 12)),
          h,
        ),
        isTrue,
      );
    });

    test('the chart\'s newest point is LIVE, never the stored one', () {
      // Stored September says 2,000; today the book says 9,000. The chart
      // must agree with the headline beside it, not with an old save.
      final List<NetWorthPoint> series = netWorthSeries(
        <NetWorthPoint>[_p(2026, 8, 1000, 0), _p(2026, 9, 2000, 0)],
        _position(9000, 0),
        DateTime(2026, 9, 18),
      );
      expect(series.last.netWorth, const Money.pesos(9000));
      expect(series, hasLength(2));
    });

    test('a point from the future is not drawn', () {
      // A phone whose clock was set back must not plot next year.
      final List<NetWorthPoint> series = netWorthSeries(
        <NetWorthPoint>[_p(2027, 3, 1, 0), _p(2026, 8, 1000, 0)],
        _position(9000, 0),
        DateTime(2026, 9, 18),
      );
      expect(series.map((NetWorthPoint p) => p.key), <String>[
        '2026-08',
        '2026-09',
      ]);
    });
  });

  group('recording in the app', () {
    test(
      'a change in a real book records this month, matching Position',
      () async {
        final DateTime clock = DateTime.utc(2026, 10, 7);
        final FinancialState s = await _realBook(clock);
        s.logTransaction(_spend('t1', 1500, '2026-10-07'));

        final FinancialPosition p = computePosition(
          s.accounts,
          null,
          debts: s.debts,
          plans: s.installments,
        );
        expect(s.netWorthHistory, hasLength(1));
        expect(s.netWorthHistory.single.key, '2026-10');
        expect(s.netWorthHistory.single.netWorth, p.netWorth);
      },
    );

    test('the example data is never recorded as anybody\'s past', () async {
      // LOADED, so saving is on and the only thing stopping a record is the
      // example data itself. An unloaded state would pass this for the
      // wrong reason.
      final FinancialState s = await _loaded(DateTime.utc(2026, 10, 7));
      expect(s.hasSampleData, isTrue);
      s.logTransaction(_spend('t1', 1500, '2026-10-07'));
      expect(
        s.netWorthHistory,
        isEmpty,
        reason: 'a demo balance was recorded as history',
      );
    });

    test('an empty book records nothing, not a zero', () async {
      // A zero point followed by the real balances would draw a leap that is
      // only data entry.
      final FinancialState s = await _realBook(DateTime.utc(2026, 10, 7));
      await s.deleteEverything();
      s.toggleGuideStep('anything');
      expect(
        s.netWorthHistory,
        isEmpty,
        reason: 'an empty book was recorded as a net worth of zero',
      );
    });

    test('peeking at the demo does not erase a real history', () async {
      final FinancialState s = await _realBook(DateTime.utc(2026, 10, 7));
      s.logTransaction(_spend('t1', 1500, '2026-10-07'));
      expect(s.netWorthHistory, hasLength(1));

      s.restoreSampleData();
      s.removeSampleData();
      expect(s.netWorthHistory, hasLength(1));
    });

    test('a wipe clears it, and the file then has no key', () async {
      final FinancialState s = await _realBook(DateTime.utc(2026, 10, 7));
      s.logTransaction(_spend('t1', 1500, '2026-10-07'));
      expect(s.netWorthHistory, isNotEmpty);

      await s.deleteEverything();

      expect(s.netWorthHistory, isEmpty);
      final Map<String, dynamic> json = s.snapshot().toJson(
        at: DateTime.utc(2026, 10, 7),
      );
      expect(json.containsKey(Snapshot.kNetWorthHistory), isFalse);
    });
  });

  group('the file', () {
    test('written and read back exactly, to the centavo', () async {
      final FinancialState s = await _realBook(DateTime.utc(2026, 10, 7));
      s.logTransaction(_spend('t1', 1234.56, '2026-10-07'));
      final Snapshot back = Snapshot.fromJson(
        s.snapshot().toJson(at: DateTime.utc(2026, 10, 7)),
      );
      expect(back.netWorthHistory, hasLength(1));
      expect(back.netWorthHistory.single.key, '2026-10');
      expect(
        back.netWorthHistory.single.netWorth,
        s.netWorthHistory.single.netWorth,
      );
    });

    test('a file written before this feature reads as no history', () {
      final Snapshot old = Snapshot.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Object>[],
      });
      expect(old.netWorthHistory, isEmpty);
    });

    test('a bad row is skipped and never stops the ledger loading', () {
      final Snapshot back = Snapshot.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Object>[],
        Snapshot.kNetWorthHistory: <Object?>[
          <String, Object?>{
            'month': '2026-08',
            'assets': 1000,
            'liabilities': 0,
          },
          <String, Object?>{'month': '2026-13', 'assets': 1, 'liabilities': 0},
          <String, Object?>{'month': 'Sept', 'assets': 1, 'liabilities': 0},
          <String, Object?>{'month': '2026-09', 'assets': 'lots'},
          'junk',
          null,
        ],
      });
      expect(back.netWorthHistory.map((NetWorthPoint p) => p.key), <String>[
        '2026-08',
      ]);
    });

    test('a field from a newer build survives a save through this one', () {
      final Map<String, dynamic> written = Snapshot.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Object>[],
        Snapshot.kNetWorthHistory: <Object?>[
          <String, Object?>{
            'month': '2026-08',
            'assets': 1000,
            'liabilities': 0,
            'note': 'from the future',
          },
        ],
      }).toJson(at: DateTime.utc(2026, 10, 7));
      final List<dynamic> rows =
          written[Snapshot.kNetWorthHistory] as List<dynamic>;
      expect((rows.single as Map<String, dynamic>)['note'], 'from the future');
    });

    test('it is not one of the keys that make a file a ledger', () {
      expect(Snapshot.collectionKeys, isNot(contains('netWorthHistory')));
    });
  });
}
