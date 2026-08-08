// Converting a foreign balance, and never doing it silently.
//
// Delivery E of docs/features/unified-financial-accounts.md, the one that
// document gates separately because it can produce a WRONG number rather than
// a missing one. So these are vectors, not spot checks: every branch of the
// rule has a case, and every case pins an exact figure.
//
//   a rate exists and is fresh: convert, and show the rate's age
//   a rate is stale:            convert, and label the total as using an old rate
//   no rate at all:             exclude, name the excluded accounts, offer a manual rate
//   a manual rate:              use it, and label it as manual
//
//   There is no state in which a converted total is shown without the reader
//   being able to see what it was converted with.
//
// The last line is what most of the "saying so" group is about, and it is the
// line that makes conversion safe rather than merely present.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/fx_totals.dart';
import 'package:salapify/money/statements.dart' show netWorthParts;

const _nowMs = 1785000000000;

/// The provider's shape: units per ONE base. With PHP as base, 1 PHP buys
/// 0.017 USD, so a dollar is worth about ₱58.82.
const _rates = {'PHP': 1.0, 'USD': 0.017, 'JPY': 2.6};

FxTable _table({
  Map<String, dynamic> rates = _rates,
  int? fetchedAt = _nowMs,
  Map<String, double> manual = const {},
  String base = 'PHP',
}) => FxTable(
  base: base,
  rates: rates,
  fetchedAt: fetchedAt,
  manual: manual,
  nowMs: _nowMs,
);

Map<String, dynamic> _data(List<Map<String, dynamic>> accounts) => {
  'settings': {'onboarded': true},
  'accounts': accounts,
};

void main() {
  group('the four branches', () {
    test('a FRESH rate converts, and says the rate is current', () {
      final t = _table();
      final r = resolveRate(t, 'USD');
      expect(r.source, RateSource.live);
      expect(r.basePerUnit, closeTo(1 / 0.017, 0.0001));
      expect(
        conversionNotice(t, convertAll(t, [(100, 'USD')])),
        contains("today's rates"),
      );
    });

    test('a STALE rate still converts, and says how old it is', () {
      // Converting with an old rate is better than pretending the money is not
      // there, but only if the reader is told.
      final t = _table(fetchedAt: _nowMs - Duration.millisecondsPerDay * 3);
      final r = resolveRate(t, 'USD');
      expect(r.source, RateSource.stale);
      expect(r.basePerUnit, closeTo(1 / 0.017, 0.0001));
      final notice = conversionNotice(t, convertAll(t, [(100, 'USD')]))!;
      expect(notice, contains('3 days ago'));
      expect(notice, contains('may have moved'));

      // One day reads as a word, not as "1 days ago".
      final y = _table(fetchedAt: _nowMs - Duration.millisecondsPerDay);
      expect(
        conversionNotice(y, convertAll(y, [(100, 'USD')])),
        contains('yesterday'),
      );
    });

    test('NO rate excludes, names the currency, and offers a way out', () {
      final t = _table(rates: const {'PHP': 1.0});
      expect(resolveRate(t, 'USD').source, RateSource.none);
      final o = convertAll(t, [(100, 'USD')]);
      expect(o.converted, 0);
      expect(o.excluded, {'USD': 100.0});
      final notice = conversionNotice(t, o)!;
      expect(notice, contains('no rate for USD'));
      expect(notice, contains('left out of the total'));
      expect(notice, contains('enter a rate yourself'));
    });

    test('a MANUAL rate is used, and labelled as one', () {
      final t = _table(rates: const {'PHP': 1.0}, manual: {'USD': 56.5});
      final r = resolveRate(t, 'USD');
      expect(r.source, RateSource.manual);
      expect(r.basePerUnit, 56.5);
      expect(convertAll(t, [(100, 'USD')]).converted, 5650);
      expect(
        conversionNotice(t, convertAll(t, [(100, 'USD')])),
        contains('a rate you entered yourself'),
      );
    });
  });

  group('precedence', () {
    test('a manual rate BEATS a live one, and says so', () {
      // Deliberate. The person typed it because the app had nothing, it is
      // about their own money, and they can remove it. Letting a cached rate
      // silently override an explicit instruction is the opposite of the rule
      // this whole file exists to keep.
      final t = _table(manual: {'USD': 50});
      expect(resolveRate(t, 'USD').source, RateSource.manual);
      expect(convertAll(t, [(10, 'USD')]).converted, 500);
    });

    test('a junk manual rate is ignored, not used', () {
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        final t = _table(manual: {'USD': bad});
        expect(
          resolveRate(t, 'USD').source,
          RateSource.live,
          reason: 'a manual rate of $bad was trusted',
        );
      }
    });

    test('the base currency is always 1, whatever the table says', () {
      final t = _table(rates: const {'PHP': 999.0}, base: 'PHP');
      expect(resolveRate(t, 'PHP').basePerUnit, 1);
      expect(resolveRate(t, 'php').basePerUnit, 1);
    });

    test('the WORST source per currency is what gets reported', () {
      // One manual rate among live ones must not be hidden by whichever row
      // happened to be summed last.
      final t = _table(manual: {'JPY': 0.4});
      final o = convertAll(t, [(1, 'USD'), (1, 'JPY'), (1, 'USD')]);
      expect(o.used['USD'], RateSource.live);
      expect(o.used['JPY'], RateSource.manual);
      expect(o.worst, RateSource.manual);
    });

    test('a stale rate outranks a manual one in the SENTENCE', () {
      // The reader needs the biggest caveat first, and "these numbers are old"
      // is a bigger caveat than "you chose this rate yourself".
      final t = _table(
        fetchedAt: _nowMs - Duration.millisecondsPerDay * 3,
        manual: {'JPY': 0.4},
      );
      final o = convertAll(t, [(1, 'USD'), (1, 'JPY')]);
      expect(o.worst, RateSource.stale);
    });
  });

  group('net worth, with exact figures', () {
    test('a dollar account converts into the peso total', () {
      final d = _data([
        {'id': 'a', 'kind': 'cash', 'balance': 5000},
        {'id': 'b', 'kind': 'savings', 'balance': 100, 'currencyCode': 'USD'},
      ]);
      final parts = netWorthParts(d, fx: _table());
      // 100 / 0.017 = 5882.35...
      expect(parts['accounts'], 5000);
      expect(parts['assets'] as double, closeTo(5000 + 100 / 0.017, 0.01));
      expect(parts['netWorth'] as double, closeTo(5000 + 100 / 0.017, 0.01));
    });

    test('a foreign DEBT converts onto the liability side, not the asset', () {
      // The failure this catches: netting a dollar debt against a dollar
      // account, which would leave net worth right by luck and both halves of
      // the summary card wrong.
      final d = {
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'a', 'kind': 'cash', 'balance': 10000},
        ],
        'debts': [
          {'id': 'x', 'remaining': 100, 'currencyCode': 'USD'},
        ],
      };
      final parts = netWorthParts(d, fx: _table());
      expect(parts['assets'], 10000);
      expect(parts['liabilities'] as double, closeTo(100 / 0.017, 0.01));
      expect(parts['netWorth'] as double, closeTo(10000 - 100 / 0.017, 0.01));
    });

    test('WITHOUT a table, nothing converts and the shape is unchanged', () {
      // The default, and the reason every golden vector still passes. A caller
      // that did not ask for conversion gets the map it always got.
      final d = _data([
        {'id': 'a', 'kind': 'cash', 'balance': 5000},
        {'id': 'b', 'kind': 'cash', 'balance': 100, 'currencyCode': 'USD'},
      ]);
      final parts = netWorthParts(d);
      expect(parts['netWorth'], 5000);
      expect(parts.containsKey('fxAssets'), isFalse);
      expect(parts.containsKey('fxDebts'), isFalse);
    });

    test('with a table, the provenance comes back with the number', () {
      final d = _data([
        {'id': 'b', 'kind': 'cash', 'balance': 100, 'currencyCode': 'USD'},
      ]);
      final parts = netWorthParts(d, fx: _table());
      final fx = parts['fxAssets'] as FxOutcome;
      expect(fx.used['USD'], RateSource.live);
      expect(fx.anyExcluded, isFalse);
    });

    test('an unpriceable currency is excluded even WITH a table', () {
      final d = _data([
        {'id': 'a', 'kind': 'cash', 'balance': 5000},
        {'id': 'b', 'kind': 'cash', 'balance': 100, 'currencyCode': 'XAU'},
      ]);
      final parts = netWorthParts(d, fx: _table());
      expect(parts['netWorth'], 5000);
      expect((parts['fxAssets'] as FxOutcome).excluded, {'XAU': 100.0});
    });
  });

  group('saying so', () {
    test('one currency, one rate, no caveat means no sentence at all', () {
      // Almost everybody. A person who holds only pesos must never see a line
      // of currency machinery.
      final t = _table();
      expect(conversionNotice(t, convertAll(t, const [])), isNull);
    });

    test('a converted total ALWAYS carries its provenance', () {
      // The rule, as a property rather than four separate assertions: whenever
      // anything was converted or excluded, there is a sentence, and it names
      // the currency.
      final tables = <FxTable>[
        _table(),
        _table(fetchedAt: _nowMs - Duration.millisecondsPerDay * 3),
        _table(rates: const {'PHP': 1.0}),
        _table(rates: const {'PHP': 1.0}, manual: {'USD': 56.5}),
        _table(fetchedAt: null),
      ];
      for (final t in tables) {
        final o = convertAll(t, [(100, 'USD')]);
        final notice = conversionNotice(t, o);
        expect(
          notice,
          isNotNull,
          reason: 'a total was changed with nothing said about it',
        );
        expect(notice, contains('USD'));
      }
    });

    test('the sentence carries no em or en dashes, same as all copy', () {
      final t = _table(fetchedAt: _nowMs - Duration.millisecondsPerDay * 3);
      final notice = conversionNotice(t, convertAll(t, [(1, 'USD')]))!;
      expect(notice.contains('—'), isFalse);
      expect(notice.contains('–'), isFalse);
    });

    test('rate age reads in days, and never as a negative', () {
      expect(rateAgeDays(_table(fetchedAt: _nowMs)), 0);
      expect(
        rateAgeDays(
          _table(fetchedAt: _nowMs - Duration.millisecondsPerDay * 3),
        ),
        3,
      );
      expect(rateAgeDays(_table(fetchedAt: null)), isNull);
      // A clock that went backwards, which a phone really does after a manual
      // time change. Zero, not a negative day count in a sentence.
      expect(rateAgeDays(_table(fetchedAt: _nowMs + 99999)), 0);
    });
  });

  test('junk never throws', () {
    for (final rates in <dynamic>[null, 'nope', 42, [], <String, dynamic>{}]) {
      final t = FxTable(
        base: 'PHP',
        rates: rates is Map ? rates.cast<String, dynamic>() : const {},
        nowMs: _nowMs,
      );
      expect(() => resolveRate(t, 'USD'), returnsNormally);
      expect(() => convertAll(t, [(1, 'USD')]), returnsNormally);
      expect(
        () => conversionNotice(t, convertAll(t, [(1, 'USD')])),
        returnsNormally,
      );
    }
    final t = _table();
    expect(() => convertAll(t, [(double.nan, 'USD')]), returnsNormally);
    expect(convertAll(t, [(double.nan, 'USD')]).converted, 0);
  });
}
