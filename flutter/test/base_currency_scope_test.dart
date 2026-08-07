// A peso total never contains a non-peso amount.
//
// Delivery D of docs/features/unified-financial-accounts.md, and the part that
// document calls the most dangerous item in it. The reason, restated because
// it is the whole justification for this file existing:
//
//   A MISSING feature is visible. A WRONG TOTAL is not.
//
// Every engine adds balances as if they were one currency, because until now
// they were. The moment a dollar account can exist, $1,000 lands in a peso net
// worth as ₱1,000 and understates the truth by roughly ₱55,000, with nothing
// on screen to suggest anything is off.
//
// So these tests are not about a currency picker. They are about the two
// numbers that would go wrong: net worth, and the daily safe-to-spend figure
// that reaches Home and the home screen widget.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/analytics.dart'
    show emergencyRunway, healthScore;
import 'package:salapify/money/base_currency_scope.dart';
import 'package:salapify/money/commitmentload.dart' show commitmentLoad;
import 'package:salapify/money/commitments.dart' show safeToSpend;
import 'package:salapify/money/statements.dart' show netWorthParts;
import 'package:salapify/money/surplus.dart' show nextPesoPlan;
import 'package:salapify/money/windfall.dart' show splitWindfall;

Map<String, dynamic> _data({
  String? base,
  List<Map<String, dynamic>> accounts = const [],
  List<Map<String, dynamic>> assets = const [],
  List<Map<String, dynamic>> debts = const [],
}) => {
  'settings': {
    'onboarded': true,
    'paydaySchedule': {'mode': 'monthly', 'day': 20},
    'currencyCode': ?base,
  },
  'accounts': accounts,
  'assets': assets,
  'debts': debts,
  'transactions': <Map<String, dynamic>>[],
};

void main() {
  final ref = DateTime(2026, 7, 10);

  group('the rule itself', () {
    test('a row with NO currency is in the base currency', () {
      // Not a guess. Every row in every existing backup means exactly this:
      // there was no per-row currency to disagree with, so all of them were
      // the app's one currency by construction. Treating absent as foreign
      // would empty every total in the app on the day this shipped.
      expect(inBaseCurrency({'balance': 1}, 'PHP'), isTrue);
      expect(inBaseCurrency({'currencyCode': ''}, 'PHP'), isTrue);
      expect(inBaseCurrency({'currencyCode': null}, 'PHP'), isTrue);
      expect(inBaseCurrency(null, 'PHP'), isTrue);
    });

    test('the code is compared case insensitively', () {
      expect(inBaseCurrency({'currencyCode': 'php'}, 'PHP'), isTrue);
      expect(inBaseCurrency({'currencyCode': 'USD'}, 'usd'), isTrue);
      expect(inBaseCurrency({'currencyCode': 'usd'}, 'PHP'), isFalse);
    });

    test('an unusable base setting falls back to PHP, as it always did', () {
      for (final v in <dynamic>[null, '', 'PH', 'PHPP', 42]) {
        // Built by hand rather than through _data, because the point is that
        // a NON-STRING setting survives, and a String? parameter would refuse
        // to carry one.
        final d = {
          'settings': {'currencyCode': v},
        };
        expect(baseCurrencyOf(d), 'PHP', reason: '$v');
      }
      expect(baseCurrencyOf({'settings': <String, dynamic>{}}), 'PHP');
      expect(baseCurrencyOf(<String, dynamic>{}), 'PHP');
      expect(
        baseCurrencyOf({
          'settings': {'currencyCode': 'usd'},
        }),
        'USD',
      );
    });
  });

  group('net worth', () {
    test('a dollar account is NOT added to a peso net worth', () {
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 5000},
          {
            'id': 'b',
            'kind': 'savings',
            'balance': 1000,
            'currencyCode': 'USD',
          },
        ],
      );
      final parts = netWorthParts(d);
      expect(
        parts['accounts'],
        5000,
        reason:
            '\$1,000 was counted as ₱1,000, which understates net worth by '
            'about ₱55,000 and says nothing about it',
      );
      expect(parts['netWorth'], 5000);
    });

    test('a dollar DEBT is not subtracted either', () {
      // The more dangerous direction of the same error: leaving a foreign debt
      // in a peso total makes net worth look BETTER than it is.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 5000},
        ],
        debts: [
          {'id': 'd', 'remaining': 100000},
          {'id': 'e', 'remaining': 2000, 'currencyCode': 'USD'},
        ],
      );
      expect(netWorthParts(d)['debts'], 100000);
      expect(netWorthParts(d)['netWorth'], 5000 - 100000);
    });

    test('a foreign ASSET is skipped too', () {
      final d = _data(
        assets: [
          {'id': 'x', 'value': 3000},
          {'id': 'y', 'value': 500, 'currencyCode': 'JPY'},
        ],
      );
      expect(netWorthParts(d)['assets'], 3000);
    });

    test('when the BASE is dollars, the peso row is the excluded one', () {
      // The rule is about disagreeing with the base, not about dollars. A test
      // that only ever excluded USD would pass on a hardcoded "skip USD".
      final d = _data(
        base: 'USD',
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 1000},
          {'id': 'b', 'kind': 'cash', 'balance': 5000, 'currencyCode': 'PHP'},
        ],
      );
      expect(netWorthParts(d)['accounts'], 1000);
    });

    test('with no foreign rows at all, nothing changed', () {
      // The half that proves this is a filter and not an off switch. Every
      // backup that exists today takes exactly the path it always did.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 5000},
          {'id': 'b', 'kind': 'savings', 'balance': 12000},
        ],
        assets: [
          {'id': 'x', 'value': 3000},
        ],
        debts: [
          {'id': 'd', 'remaining': 4000},
        ],
      );
      final parts = netWorthParts(d);
      expect(parts['accounts'], 17000);
      expect(parts['assets'], 20000);
      expect(parts['debts'], 4000);
      expect(parts['netWorth'], 16000);
    });
  });

  group('the daily number', () {
    test('a dollar wallet does not become spendable pesos', () {
      // This one matters more than net worth. safeToSpend drives the figure on
      // Home AND on the home screen widget, so counting a dollar balance as
      // pesos there tells somebody they can spend money they do not have.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 10000},
          {
            'id': 'b',
            'kind': 'ewallet',
            'balance': 2000,
            'currencyCode': 'USD',
          },
        ],
      );
      expect(safeToSpend(d, ref)['liquid'], 10000);
    });

    test('with no foreign rows the daily number is untouched', () {
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 10000},
          {'id': 'b', 'kind': 'ewallet', 'balance': 2000},
        ],
      );
      expect(safeToSpend(d, ref)['liquid'], 12000);
    });
  });

  group('saying so', () {
    test('nothing excluded means no notice at all', () {
      expect(excludedNotice(_data()), isNull);
      expect(
        excludedNotice(
          _data(
            accounts: [
              {'id': 'a', 'kind': 'cash', 'balance': 1},
            ],
          ),
        ),
        isNull,
      );
    });

    test('one excluded row is NAMED, with its currency', () {
      // Naming rather than counting, because "1 account is not counted" tells
      // somebody there is a problem and not which one, and being able to see
      // exactly what is missing is the entire reason for excluding rather than
      // converting.
      final notice = excludedNotice(
        _data(
          accounts: [
            {
              'id': 'b',
              'kind': 'savings',
              'name': 'Chase',
              'balance': 1000,
              'currencyCode': 'USD',
            },
          ],
        ),
      );
      expect(notice, contains('Chase (USD)'));
      expect(notice, contains('not counted'));
      expect(notice, contains('PHP'));
    });

    test('many excluded rows name two and count the rest', () {
      final notice = excludedNotice(
        _data(
          accounts: [
            for (var i = 0; i < 5; i++)
              {
                'id': 'a$i',
                'kind': 'cash',
                'name': 'Acct $i',
                'balance': 1,
                'currencyCode': 'USD',
              },
          ],
        ),
      );
      expect(notice, contains('Acct 0 (USD) and Acct 1 (USD) and 3 more'));
    });

    test('a nameless row still reads as a sentence', () {
      final notice = excludedNotice(
        _data(
          accounts: [
            {'id': 'a', 'kind': 'cash', 'balance': 1, 'currencyCode': 'USD'},
          ],
        ),
      );
      expect(notice, isNotNull);
      expect(notice, contains('One item (USD)'));
    });

    test('the notice carries no em or en dashes, same as all copy', () {
      final notice = excludedNotice(
        _data(
          accounts: [
            {
              'id': 'a',
              'kind': 'cash',
              'name': 'X',
              'balance': 1,
              'currencyCode': 'USD',
            },
          ],
        ),
      )!;
      expect(notice.contains('—'), isFalse);
      expect(notice.contains('–'), isFalse);
    });
  });

  group('the runway and health engines respect the base currency', () {
    // These two engines were ported 1:1 from RN and never gained the exclusion
    // rule, so they summed foreign balances as pesos while safeToSpend and
    // netWorthParts (right beside them, on the same data) did not. That is the
    // exact "two screens disagree about the money" failure the rule exists to
    // stop.

    test('a dollar account is NOT added to the emergency runway buffer', () {
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 5000},
          {
            'id': 'b',
            'kind': 'savings',
            'balance': 1000,
            'currencyCode': 'USD',
          },
        ],
      );
      // The bug counted $1,000 as ₱1,000, so the buffer read 6000 and
      // disagreed with safeToSpend's liquid figure on the very same data.
      expect(emergencyRunway(d, ref)['buffer'], 5000);
    });

    test('with no foreign account the runway buffer is unchanged', () {
      // The filter-not-off-switch half: an all-base blob takes the old path.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 5000},
          {'id': 'b', 'kind': 'savings', 'balance': 1000},
        ],
      );
      expect(emergencyRunway(d, ref)['buffer'], 6000);
    });

    test('a dollar DEBT does not drag down the health debt score', () {
      // With a peso buffer and no peso debt the debt sub-score is a full 25.
      // The bug counted a $2,000 debt as ₱2,000, inventing a debt load and
      // dropping the score. The fix leaves the foreign debt out.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 100000},
        ],
        debts: [
          {'id': 'e', 'remaining': 2000, 'currencyCode': 'USD'},
        ],
      );
      final parts = healthScore(d, ref)['parts'] as Map;
      expect(parts['debt'], 25);
    });

    test('a real peso debt still lowers the health debt score', () {
      // The companion that proves the line above is a filter, not an off
      // switch: a base-currency debt is counted exactly as before. Debt 50000
      // over assets 100000 is a 0.5 ratio, so round((1 - 0.5) * 25) = 13.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 100000},
        ],
        debts: [
          {'id': 'd', 'remaining': 50000},
        ],
      );
      final parts = healthScore(d, ref)['parts'] as Map;
      expect(parts['debt'], 13);
      expect(parts['debt'], lessThan(25));
    });

    test('a dollar account does not inflate health assets', () {
      // A foreign account counted as pesos would swell assets and make the
      // same peso debt look small (ratio 0.05, score 24). Excluding it keeps
      // the ratio honest at 0.5, score 13.
      final d = _data(
        accounts: [
          {'id': 'a', 'kind': 'cash', 'balance': 100000},
          {
            'id': 'b',
            'kind': 'savings',
            'balance': 900000,
            'currencyCode': 'USD',
          },
        ],
        debts: [
          {'id': 'd', 'remaining': 50000},
        ],
      );
      final parts = healthScore(d, ref)['parts'] as Map;
      expect(parts['debt'], 13);
    });
  });

  group('the debt-side engines respect the base currency', () {
    // The three sites the f3.67 QA pass named: a foreign debt must not be added
    // as pesos to the commitment load, ranked in the next-peso order, or paid
    // down from a peso windfall. Rate 3 is well above the 1 percent high-rate
    // floor, so these debts genuinely qualify for the debt tiers.

    test('commitmentLoad leaves a foreign debt minimum out of the total', () {
      final d = _data(
        debts: [
          {
            'id': 'a',
            'type': 'credit card',
            'remaining': 40000,
            'minPayment': 500,
          },
          {
            'id': 'b',
            'type': 'credit card',
            'remaining': 40000,
            'minPayment': 2000,
            'currencyCode': 'USD',
          },
        ],
      );
      final load = commitmentLoad(d, ref);
      expect(
        load['minimumsTotal'],
        500,
        reason: 'the USD 2000 minimum was counted as pesos',
      );
      expect(load['minimumsCount'], 1);
    });

    test('commitmentLoad still counts a base debt minimum', () {
      final d = _data(
        debts: [
          {
            'id': 'a',
            'type': 'credit card',
            'remaining': 40000,
            'minPayment': 500,
          },
        ],
      );
      expect(commitmentLoad(d, ref)['minimumsTotal'], 500);
    });

    test('nextPesoPlan never picks a foreign debt as the costliest', () {
      final foreignOnly = _data(
        debts: [
          {
            'id': 'b',
            'name': 'US card',
            'type': 'credit card',
            'remaining': 50000,
            'monthlyRate': 3,
            'currencyCode': 'USD',
          },
        ],
      );
      expect(
        nextPesoPlan(foreignOnly, ref)['topDebt'],
        isNull,
        reason: 'a USD debt was ranked in a peso order of operations',
      );
      final baseDebt = _data(
        debts: [
          {
            'id': 'a',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 50000,
            'monthlyRate': 3,
          },
        ],
      );
      expect(nextPesoPlan(baseDebt, ref)['topDebt'], isNotNull);
    });

    test('splitWindfall never allocates pesos to a foreign debt', () {
      final foreignOnly = _data(
        debts: [
          {
            'id': 'b',
            'name': 'US card',
            'type': 'credit card',
            'remaining': 50000,
            'monthlyRate': 3,
            'currencyCode': 'USD',
          },
        ],
      );
      final slices =
          splitWindfall(foreignOnly, ref, amount: 100000)['slices'] as List;
      expect(
        slices.every((s) => (s as Map)['key'] != 'debt'),
        isTrue,
        reason: 'a USD debt got a peso payment from the windfall',
      );
      final baseDebt = _data(
        debts: [
          {
            'id': 'a',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 50000,
            'monthlyRate': 3,
          },
        ],
      );
      final baseSlices =
          splitWindfall(baseDebt, ref, amount: 100000)['slices'] as List;
      expect(baseSlices.any((s) => (s as Map)['key'] == 'debt'), isTrue);
    });
  });

  test('junk never throws', () {
    for (final junk in [null, 'nope', 42, <String, dynamic>{}, []]) {
      expect(() => baseCurrencyOf(junk), returnsNormally, reason: '$junk');
      expect(() => allForeignRows(junk), returnsNormally, reason: '$junk');
      expect(() => excludedNotice(junk), returnsNormally, reason: '$junk');
      expect(() => inBaseCurrency(junk, 'PHP'), returnsNormally);
    }
  });
}
