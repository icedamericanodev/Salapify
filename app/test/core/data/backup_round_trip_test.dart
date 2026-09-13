// Restore is the founder's only safety net if the cutover goes wrong, so it is
// proven before anything else leans on it.
//
// The other backup tests check the FORMAT: keys, shapes, migrations, refusals.
// This one checks the thing the founder actually cares about, which is that
// their money survives the trip. A backup can round-trip with every key in
// place and every golden vector green while a balance quietly changes, because
// no format test computes a total.
//
// So the assertions here are about pesos, and they are directional as well as
// conservative: a test that only says "net worth is unchanged" passes just as
// happily when the restore silently dropped everything and both sides are
// zero. Each invariant below is paired with a check that the data is really
// there.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/backup.dart';
import 'package:salapify/core/money/statements.dart';

/// A backup shaped like a real one: several account kinds, money in both
/// directions, a debt part way through, and a foreign-currency account, which
/// is the row most likely to be mishandled by a total.
///
/// Written as a literal rather than generated, because a fixture produced by
/// the same code under test proves only that the code agrees with itself.
Map<String, dynamic> _foundersBackup() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'a_cash', 'name': 'Cash on hand', 'kind': 'cash', 'balance': 3200.0},
    {'id': 'a_gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 8410.50},
    {
      'id': 'a_bpi',
      'name': 'BPI Savings',
      'kind': 'savings',
      'balance': 96715.25,
    },
    {
      'id': 'a_bdo',
      'name': 'BDO Payroll',
      'kind': 'checking',
      'balance': 66000.0,
    },
    // Foreign. netWorthParts must NOT add this into a peso total as if it
    // were pesos, and the restored copy must make the same choice.
    {
      'id': 'a_usd',
      'name': 'USD savings',
      'kind': 'savings',
      'balance': 1000.0,
      'currencyCode': 'USD',
    },
  ],
  // `remaining`, not `balance`. netWorthParts totals debts on `remaining`, and
  // the first version of this fixture used `balance`, which made both debts
  // count as zero and the expected total wrong by six thousand pesos. The
  // assertion caught the fixture, which is the test doing its job.
  'debts': [
    {
      'id': 'd_hc',
      'name': 'Home Credit',
      'remaining': 2000.0,
      'apr': 0.0,
      'minPayment': 1000.0,
    },
    {
      'id': 'd_card',
      'name': 'BPI Gold Mastercard',
      'remaining': 4000.0,
      'apr': 36.0,
    },
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'amount': 250.0,
      'label': 'Jollibee',
      'date': '2026-09-13',
      'accountId': 'a_gcash',
    },
    {
      'id': 't2',
      'type': 'income',
      'amount': 21000.0,
      'label': 'Sweldo',
      'date': '2026-09-15',
      'accountId': 'a_bdo',
    },
    {
      'id': 't3',
      'type': 'expense',
      'amount': 1699.0,
      'label': 'Converge',
      'date': '2026-09-11',
      'accountId': 'a_gcash',
    },
  ],
  'people': [
    {'id': 'p_jun', 'name': 'Kuya Jun'},
    {'id': 'p_bing', 'name': 'Ate Bing'},
  ],
  // cashLeg matters and is not decoration. Only a receivable where real money
  // left the founder's pocket counts toward net worth; a note recording that
  // someone owes a share of something does not. Without this flag the 3,500 is
  // correctly ignored by the total, which is another thing the expected figure
  // caught in this fixture's first draft.
  'receivables': [
    {
      'id': 'r1',
      'personId': 'p_bing',
      'person': 'Ate Bing',
      'amount': 3500.0,
      'date': '2026-09-01',
      'cashLeg': true,
      'payments': [],
    },
  ],
  'goals': [
    {
      'id': 'g1',
      'name': 'Emergency fund',
      'target': 100000.0,
      'saved': 42000.0,
    },
  ],
  'categories': [
    {'id': 'c_food', 'name': 'Food', 'emoji': '🍚'},
    {'id': 'c_bills', 'name': 'Bills', 'emoji': '💡'},
  ],
  'recurring': [
    {'id': 'rc1', 'name': 'Spotify', 'amount': 149.0, 'dayOfMonth': 14},
  ],
  'settings': {'baseCurrency': 'PHP', 'payday': '15/30'},
};

/// The trip a real restore makes: through JSON and back, exactly as it would
/// go through a file on disk.
Map<String, dynamic> _throughAFile(Map<String, dynamic> data) =>
    sanitizeData(jsonDecode(jsonEncode(data)));

/// Assets minus liabilities, straight from the engine the Accounts hero uses.
/// The key is 'netWorth'; the first version of this file guessed 'net' and got
/// a null, which is a fair reminder that reading the function beats assuming
/// its shape.
double _netWorth(Map<String, dynamic> d) =>
    (netWorthParts(d)['netWorth'] as num).toDouble();

void main() {
  group('a real schema v12 backup survives the trip', () {
    test('the money is identical, and there was money to begin with', () {
      final original = sanitizeData(_foundersBackup());
      final restored = _throughAFile(original);

      // The did-anything-happen half. Without it, "net worth matches" passes
      // perfectly when the restore returned an empty ledger and both sides
      // are zero, which is the exact failure this test exists to catch.
      expect(
        (restored['accounts'] as List).length,
        5,
        reason: 'the restored backup lost accounts',
      );
      expect((restored['transactions'] as List).length, 3);
      expect((restored['debts'] as List).length, 2);
      expect((restored['receivables'] as List).length, 1);

      // A HAND-COMPUTED figure, not the other side of the same function.
      //
      // Comparing restored against original is weaker than it looks: both go
      // through sanitizeData, so a bug that mangles every balance identically
      // on both sides keeps them equal and the test stays green. That is not
      // hypothetical. Rounding balances to whole pesos was tried as a
      // deliberate break while writing this file, and this assertion, in its
      // original comparing form, passed straight through it.
      //
      //   PHP accounts  3,200.00 + 8,410.50 + 96,715.25 + 66,000.00
      //                 = 174,325.75
      //   USD 1,000     excluded, not a peso
      //   receivable    + 3,500.00        = assets 177,825.75
      //   debts         2,000.00 + 4,000.00 = liabilities 6,000.00
      //                 net                = 171,825.75
      const expected = 171825.75;
      expect(
        _netWorth(original),
        expected,
        reason: 'the fixture does not total what the arithmetic above says',
      );
      expect(
        _netWorth(restored),
        expected,
        reason: 'net worth moved across a restore',
      );
    });

    test('every account keeps its own balance, not just the total', () {
      // A total can survive while two accounts swap balances, so the rows are
      // checked one by one and by id.
      final original = sanitizeData(_foundersBackup());
      final restored = _throughAFile(original);

      Map<String, double> byId(Map<String, dynamic> d) => {
        for (final a in d['accounts'] as List)
          (a as Map)['id'] as String: (a['balance'] as num).toDouble(),
      };

      final before = byId(original);
      final after = byId(restored);
      expect(after.keys.toSet(), before.keys.toSet());
      for (final id in before.keys) {
        expect(after[id], before[id], reason: 'balance of $id changed');
      }
      // Centavos are the point of the whole engine, so one row carries them.
      expect(after['a_gcash'], 8410.50);
      expect(after['a_bpi'], 96715.25);
    });

    test(
      'a foreign row is still excluded from the peso total after restore',
      () {
        // The one row a naive total gets wrong. If the restore lost the
        // currencyCode, this USD 1,000 would silently land in the peso net worth
        // as 1,000 pesos and the total would rise with nothing on screen to
        // explain it.
        final original = sanitizeData(_foundersBackup());
        final restored = _throughAFile(original);

        final usd =
            (restored['accounts'] as List).firstWhere(
                  (a) => (a as Map)['id'] == 'a_usd',
                )
                as Map;
        expect(usd['currencyCode'], 'USD', reason: 'the currency was dropped');

        final withoutUsd = _netWorth({
          ...restored,
          'accounts': (restored['accounts'] as List)
              .where((a) => (a as Map)['id'] != 'a_usd')
              .toList(),
        });
        expect(
          _netWorth(restored),
          withoutUsd,
          reason: 'the USD balance leaked into the peso total',
        );
      },
    );

    test('debts and money owed to you both survive, on their own sides', () {
      final restored = _throughAFile(sanitizeData(_foundersBackup()));

      final debts = {
        for (final d in restored['debts'] as List)
          (d as Map)['id'] as String: (d['remaining'] as num).toDouble(),
      };
      expect(debts['d_hc'], 2000.0);
      expect(debts['d_card'], 4000.0);

      final r = (restored['receivables'] as List).single as Map;
      expect(r['amount'], 3500.0);
      // The link to the person, not just the number. A receivable that keeps
      // its amount and loses whose it is has lost the useful half.
      expect(r['personId'], 'p_bing');
    });

    test('a second trip changes nothing, so restore is stable', () {
      // A restore that keeps drifting is a restore that corrupts a ledger over
      // several phone moves rather than in one visible step.
      final once = _throughAFile(sanitizeData(_foundersBackup()));
      final twice = _throughAFile(once);
      expect(
        jsonEncode(twice),
        jsonEncode(once),
        reason: 'the second restore produced a different file',
      );
    });

    test('the schema version is stamped, and a newer one is refused', () {
      final restored = _throughAFile(sanitizeData(_foundersBackup()));
      expect(restored['schemaVersion'], schemaVersion);

      // Refusing loudly is the correct behaviour: a v3 app quietly opening a
      // file from a FUTURE version would drop whatever it did not understand.
      expect(
        () => sanitizeData({..._foundersBackup(), 'schemaVersion': 99}),
        throwsA(isA<NewerBackupException>()),
      );
    });
  });
}
