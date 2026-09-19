import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/currencies.dart';
import 'package:salapify/core/money/fx_rates.dart';

/// Live rates, and every way the wire can lie.
///
/// The one thing this file exists to stop: a rate used in the WRONG
/// DIRECTION. The API answers in units per peso and the app works in pesos per
/// unit, so an inversion that goes missing turns a 58 peso dollar into a 0.017
/// peso dollar, which is obviously wrong, or a 0.39 peso yen into a 2.57 peso
/// yen, which is not obviously anything and would quietly overstate an OFW's
/// savings by six times.
void main() {
  String apiBody(Map<String, double> ratesPerPeso) => jsonEncode(
    <String, dynamic>{
      'result': 'success',
      'base_code': 'PHP',
      'rates': <String, dynamic>{'PHP': 1, ...ratesPerPeso},
    },
  );

  group('reading the API', () {
    test('it inverts units-per-peso into pesos-per-unit', () {
      final FxRates? r = FxRates.fromApiJson(
        apiBody(<String, double>{'USD': 0.017094, 'JPY': 2.564}),
      );
      expect(r, isNotNull);
      // 1 / 0.017094 is about 58.5, which is what a dollar costs in pesos.
      expect(r!.rateFor(CurrencyCode.usd), closeTo(58.5, 0.1));
      expect(
        r.rateFor(CurrencyCode.jpy),
        closeTo(0.39, 0.01),
        reason:
            'a yen costs well under a peso. If this comes back as 2.56 the '
            'rate was used the wrong way up, and nothing on screen would look '
            'odd enough to catch it.',
      );
      expect(r.rateFor(CurrencyCode.php), 1.0);
      expect(r.source, FxSource.live);
    });

    test('the peso is always worth one peso', () {
      final FxRates? r = FxRates.fromApiJson(
        apiBody(<String, double>{'USD': 0.017}),
      );
      expect(r!.convert(1000, CurrencyCode.php, CurrencyCode.php), 1000);
    });

    test('a response that is not success is refused', () {
      expect(
        FxRates.fromApiJson(
          jsonEncode(<String, dynamic>{
            'result': 'error',
            'base_code': 'PHP',
            'rates': <String, dynamic>{'USD': 0.017},
          }),
        ),
        isNull,
      );
    });

    test('a response based on another currency is refused, not inverted', () {
      // The inversion assumes a peso base. A USD-based response would invert
      // every rate against the wrong unit and produce numbers that are
      // internally consistent and completely wrong.
      expect(
        FxRates.fromApiJson(
          jsonEncode(<String, dynamic>{
            'result': 'success',
            'base_code': 'USD',
            'rates': <String, dynamic>{'PHP': 58.5},
          }),
        ),
        isNull,
      );
    });

    test('a zero or negative rate is dropped rather than divided by', () {
      final FxRates? r = FxRates.fromApiJson(
        apiBody(<String, double>{'USD': 0, 'EUR': -1, 'SGD': 0.0228}),
      );
      expect(r, isNotNull);
      expect(r!.rateFor(CurrencyCode.usd), isNull);
      expect(r.rateFor(CurrencyCode.eur), isNull);
      expect(r.rateFor(CurrencyCode.sgd), closeTo(43.86, 0.1));
    });

    test('junk, an empty body and the wrong shape all return null', () {
      expect(FxRates.fromApiJson('not json at all'), isNull);
      expect(FxRates.fromApiJson(''), isNull);
      expect(FxRates.fromApiJson('[1,2,3]'), isNull);
      expect(FxRates.fromApiJson(apiBody(<String, double>{})), isNull);
    });
  });

  group('converting', () {
    FxRates rates() => FxRates.fromApiJson(
      apiBody(<String, double>{'USD': 0.017094, 'SGD': 0.0228, 'JPY': 2.564}),
    )!;

    test('pesos to dollars and back again returns where it started', () {
      final FxRates r = rates();
      final double usd = r.convert(58500, CurrencyCode.php, CurrencyCode.usd)!;
      expect(usd, closeTo(1000, 1));
      expect(
        r.convert(usd, CurrencyCode.usd, CurrencyCode.php),
        closeTo(58500, 1),
        reason: 'a round trip that does not return is a rate used one way up',
      );
    });

    test('it goes between two foreign currencies through the peso', () {
      final FxRates r = rates();
      final double sgd = r.convert(100, CurrencyCode.usd, CurrencyCode.sgd)!;
      // 100 USD is about 5,850 pesos, which is about 133 SGD.
      expect(sgd, closeTo(133, 2));
    });

    test('a pair with no rate returns null, never a silent one to one', () {
      const FxRates partial = FxRates(
        pesosPerUnit: <String, double>{'PHP': 1.0},
        source: FxSource.live,
      );
      expect(
        partial.convert(1000, CurrencyCode.php, CurrencyCode.usd),
        isNull,
        reason:
            'falling back to 1 would report a 1,000 peso amount as 1,000 '
            'dollars, which is a plausible number and a 57,500 peso error',
      );
    });
  });

  group('how old the rates are', () {
    test('built-in rates are always stale, whatever the clock says', () {
      expect(
        FxRates.builtIn().staleAt(DateTime(2026, 9, 19)),
        isTrue,
        reason:
            'they are months old by construction, and calling them fresh is '
            'a lie told by a rounding rule',
      );
    });

    test('fetched today is fresh, two days ago is not', () {
      final DateTime now = DateTime(2026, 9, 19, 12);
      FxRates at(DateTime when) => FxRates(
        pesosPerUnit: const <String, double>{'PHP': 1.0, 'USD': 58.5},
        source: FxSource.cached,
        fetchedAt: when,
      );
      expect(at(now).staleAt(now), isFalse);
      expect(at(now.subtract(const Duration(hours: 20))).staleAt(now), isFalse);
      expect(at(now.subtract(const Duration(days: 2))).staleAt(now), isTrue);
    });

    test('the built-in table always has something to convert with', () {
      final FxRates b = FxRates.builtIn();
      for (final CurrencyCode c in CurrencyCode.values) {
        expect(
          b.rateFor(c),
          isNotNull,
          reason:
              'the offline fallback is missing $c, so the converter shows '
              'nothing on a phone with no signal',
        );
      }
    });
  });

  group('the cache', () {
    test('what is written is what comes back', () {
      final FxRates live = FxRates.fromApiJson(
        apiBody(<String, double>{'USD': 0.017094}),
        now: DateTime.utc(2026, 9, 19, 8),
      )!;
      final FxRates? back = FxRates.fromCacheJson(jsonEncode(live.toJson()));

      expect(back, isNotNull);
      expect(back!.rateFor(CurrencyCode.usd), closeTo(58.5, 0.01));
      expect(back.fetchedAt, DateTime.utc(2026, 9, 19, 8));
      expect(
        back.source,
        FxSource.cached,
        reason:
            'rates read off the disk must not claim to be live. "Updated just '
            'now" about a week old number is the one thing this screen must '
            'never say.',
      );
    });

    test('a damaged cache returns null rather than a wrong rate', () {
      expect(FxRates.fromCacheJson('{ half written'), isNull);
      expect(FxRates.fromCacheJson('{}'), isNull);
      expect(
        FxRates.fromCacheJson(
          jsonEncode(<String, dynamic>{
            'pesosPerUnit': <String, dynamic>{'USD': 'fifty eight'},
          }),
        ),
        isNull,
        reason: 'a rate stored as text is a rate nobody should convert with',
      );
    });
  });
}
