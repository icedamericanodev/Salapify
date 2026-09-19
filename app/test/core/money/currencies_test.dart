import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/currencies.dart';

/// Golden vectors for the multi-currency port.
///
/// Every number and every string below was PRINTED BY THE PROTOTYPE, by
/// running src/utils/currencies.ts under bun via app/tool/gen_currency_vectors.ts.
/// None of it was worked out by hand, which is the whole point: a figure I
/// derive myself can agree with my own misreading of the source.
void main() {
  group('convertToPhp matches the prototype', () {
    const List<(double, CurrencyCode, double)> vectors =
        <(double, CurrencyCode, double)>[
          (0.0, CurrencyCode.php, 0.0),
          (0.5, CurrencyCode.php, 0.5),
          (1.0, CurrencyCode.php, 1.0),
          (12.345, CurrencyCode.php, 12.345),
          (999.995, CurrencyCode.php, 999.995),
          (1000.0, CurrencyCode.php, 1000.0),
          (12345.67, CurrencyCode.php, 12345.67),
          (-2500.0, CurrencyCode.php, -2500.0),
          (1234567.89, CurrencyCode.php, 1234567.89),
          (0.0, CurrencyCode.usd, 0.0),
          (0.5, CurrencyCode.usd, 29.25),
          (1.0, CurrencyCode.usd, 58.5),
          (12.345, CurrencyCode.usd, 722.1825),
          (999.995, CurrencyCode.usd, 58499.7075),
          (1000.0, CurrencyCode.usd, 58500.0),
          (12345.67, CurrencyCode.usd, 722221.695),
          (-2500.0, CurrencyCode.usd, -146250.0),
          (1234567.89, CurrencyCode.usd, 72222221.565),
          (0.0, CurrencyCode.eur, 0.0),
          (0.5, CurrencyCode.eur, 31.9),
          (1.0, CurrencyCode.eur, 63.8),
          (12.345, CurrencyCode.eur, 787.611),
          (999.995, CurrencyCode.eur, 63799.681),
          (1000.0, CurrencyCode.eur, 63800.0),
          (12345.67, CurrencyCode.eur, 787653.7459999999),
          (-2500.0, CurrencyCode.eur, -159500.0),
          (1234567.89, CurrencyCode.eur, 78765431.38199998),
          (0.0, CurrencyCode.jpy, 0.0),
          (0.5, CurrencyCode.jpy, 0.1925),
          (1.0, CurrencyCode.jpy, 0.385),
          (12.345, CurrencyCode.jpy, 4.7528250000000005),
          (999.995, CurrencyCode.jpy, 384.99807500000003),
          (1000.0, CurrencyCode.jpy, 385.0),
          (12345.67, CurrencyCode.jpy, 4753.08295),
          (-2500.0, CurrencyCode.jpy, -962.5),
          (1234567.89, CurrencyCode.jpy, 475308.63765),
          (0.0, CurrencyCode.sgd, 0.0),
          (0.5, CurrencyCode.sgd, 22.1),
          (1.0, CurrencyCode.sgd, 44.2),
          (12.345, CurrencyCode.sgd, 545.6490000000001),
          (999.995, CurrencyCode.sgd, 44199.779),
          (1000.0, CurrencyCode.sgd, 44200.0),
          (12345.67, CurrencyCode.sgd, 545678.6140000001),
          (-2500.0, CurrencyCode.sgd, -110500.0),
          (1234567.89, CurrencyCode.sgd, 54567900.738),
        ];

    test('every vector', () {
      for (final (double amount, CurrencyCode code, double php) in vectors) {
        expect(
          convertToPhp(amount, code),
          closeTo(php, 1e-9),
          reason:
              'convertToPhp($amount, ${code.wire}) drifted from the '
              'prototype. Regenerate with '
              'bun app/tool/gen_currency_vectors.ts rather than editing '
              'this expectation.',
        );
      }
    });

    test(
      'the default is pesos, so an unclassified balance is not inflated',
      () {
        expect(convertToPhp(1000), 1000);
      },
    );
  });

  group('formatCurrency matches the prototype', () {
    const List<(double, CurrencyCode, String, String)> vectors =
        <(double, CurrencyCode, String, String)>[
          (0.0, CurrencyCode.php, r"₱0.00", r"₱0"),
          (0.5, CurrencyCode.php, r"₱0.50", r"₱1"),
          (1.0, CurrencyCode.php, r"₱1.00", r"₱1"),
          (12.345, CurrencyCode.php, r"₱12.35", r"₱12"),
          (999.995, CurrencyCode.php, r"₱1,000.00", r"₱1,000"),
          (1000.0, CurrencyCode.php, r"₱1,000.00", r"₱1,000"),
          (12345.67, CurrencyCode.php, r"₱12,345.67", r"₱12,346"),
          (-2500.0, CurrencyCode.php, r"-₱2,500.00", r"-₱2,500"),
          (1234567.89, CurrencyCode.php, r"₱1,234,567.89", r"₱1,234,568"),
          (0.0, CurrencyCode.usd, r"$0.00", r"$0"),
          (0.5, CurrencyCode.usd, r"$0.50", r"$1"),
          (1.0, CurrencyCode.usd, r"$1.00", r"$1"),
          (12.345, CurrencyCode.usd, r"$12.35", r"$12"),
          (999.995, CurrencyCode.usd, r"$1,000.00", r"$1,000"),
          (1000.0, CurrencyCode.usd, r"$1,000.00", r"$1,000"),
          (12345.67, CurrencyCode.usd, r"$12,345.67", r"$12,346"),
          (-2500.0, CurrencyCode.usd, r"-$2,500.00", r"-$2,500"),
          (1234567.89, CurrencyCode.usd, r"$1,234,567.89", r"$1,234,568"),
          (0.0, CurrencyCode.eur, r"€0.00", r"€0"),
          (0.5, CurrencyCode.eur, r"€0.50", r"€1"),
          (1.0, CurrencyCode.eur, r"€1.00", r"€1"),
          (12.345, CurrencyCode.eur, r"€12.35", r"€12"),
          (999.995, CurrencyCode.eur, r"€1,000.00", r"€1,000"),
          (1000.0, CurrencyCode.eur, r"€1,000.00", r"€1,000"),
          (12345.67, CurrencyCode.eur, r"€12,345.67", r"€12,346"),
          (-2500.0, CurrencyCode.eur, r"-€2,500.00", r"-€2,500"),
          (1234567.89, CurrencyCode.eur, r"€1,234,567.89", r"€1,234,568"),
          (0.0, CurrencyCode.jpy, r"¥0.00", r"¥0"),
          (0.5, CurrencyCode.jpy, r"¥0.50", r"¥1"),
          (1.0, CurrencyCode.jpy, r"¥1.00", r"¥1"),
          (12.345, CurrencyCode.jpy, r"¥12.35", r"¥12"),
          (999.995, CurrencyCode.jpy, r"¥1,000.00", r"¥1,000"),
          (1000.0, CurrencyCode.jpy, r"¥1,000.00", r"¥1,000"),
          (12345.67, CurrencyCode.jpy, r"¥12,345.67", r"¥12,346"),
          (-2500.0, CurrencyCode.jpy, r"-¥2,500.00", r"-¥2,500"),
          (1234567.89, CurrencyCode.jpy, r"¥1,234,567.89", r"¥1,234,568"),
          (0.0, CurrencyCode.sgd, r"S$0.00", r"S$0"),
          (0.5, CurrencyCode.sgd, r"S$0.50", r"S$1"),
          (1.0, CurrencyCode.sgd, r"S$1.00", r"S$1"),
          (12.345, CurrencyCode.sgd, r"S$12.35", r"S$12"),
          (999.995, CurrencyCode.sgd, r"S$1,000.00", r"S$1,000"),
          (1000.0, CurrencyCode.sgd, r"S$1,000.00", r"S$1,000"),
          (12345.67, CurrencyCode.sgd, r"S$12,345.67", r"S$12,346"),
          (-2500.0, CurrencyCode.sgd, r"-S$2,500.00", r"-S$2,500"),
          (1234567.89, CurrencyCode.sgd, r"S$1,234,567.89", r"S$1,234,568"),
        ];

    test('every vector, with and without decimals', () {
      for (final (double amount, CurrencyCode code, String withDp, String noDp)
          in vectors) {
        expect(
          formatCurrency(amount, code),
          withDp,
          reason:
              'formatCurrency($amount, ${code.wire}) drifted. Dart\'s '
              'NumberFormat and JavaScript toLocaleString are different '
              'implementations of the same grouping rules, so this is the '
              'assertion most likely to catch a real difference.',
        );
        expect(
          formatCurrency(amount, code, includeDecimals: false),
          noDp,
          reason: 'formatCurrency($amount, ${code.wire}, no decimals) drifted.',
        );
      }
    });

    test('the minus sits before the symbol, not after it', () {
      expect(formatCurrency(-2500, CurrencyCode.usd), startsWith('-'));
      expect(formatCurrency(-2500, CurrencyCode.usd), isNot(contains(r'$-')));
    });
  });

  group('the three lookup tables cover every currency', () {
    test('no enum value is missing a symbol, a name or a rate', () {
      for (final CurrencyCode c in CurrencyCode.values) {
        expect(
          currencySymbols[c],
          isNotNull,
          reason:
              '${c.name} has no symbol. formatCurrency would silently '
              'fall back to the peso sign and label foreign money as pesos.',
        );
        expect(currencyNames[c], isNotNull, reason: '${c.name} has no name.');
        expect(
          currencyShortNames[c],
          isNotNull,
          reason: '${c.name} has no short name.',
        );
        expect(
          exchangeRatesToPhp[c],
          isNotNull,
          reason:
              '${c.name} has no rate. convertToPhp would fall back to 1.0 '
              'and count a dollar as a peso.',
        );
      }
    });

    test('the wire spelling round trips', () {
      for (final CurrencyCode c in CurrencyCode.values) {
        expect(currencyFromWire(c.wire), c);
        expect(currencyFromWire(c.wire.toLowerCase()), c);
      }
      expect(currencyFromWire('XYZ'), isNull);
    });
  });
}
