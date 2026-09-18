// Display-only helper (no RN counterpart), so these are unit tests. The rule
// they lock: a base-currency account keeps the peso formatter byte-for-byte,
// and a foreign account shows its OWN symbol, never the base peso sign.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/account_currency.dart';
import 'package:salapify/money/currencies.dart' show baseCurrencySymbol;

void main() {
  // The formatters read the app-wide base symbol; pin it to the peso so the
  // base-currency assertions are stable regardless of test order.
  setUp(() => baseCurrencySymbol = '₱');

  test('an account with no currency code is base currency', () {
    expect(accountForeignCode({'balance': 100}, 'PHP'), isNull);
    // The base formatter (formatMoney) drops the .00 on a whole peso; the
    // foreign one (formatConverted) keeps two places. Both are the app's
    // existing formatters, unchanged here.
    expect(formatAccountBalance(100, {'balance': 100}, 'PHP'), '₱100');
    expect(accountAmountText(100, {'balance': 100}, 'PHP'), isNull);
  });

  test('a code equal to the base is still base currency', () {
    expect(accountForeignCode({'currencyCode': 'PHP'}, 'PHP'), isNull);
    expect(accountAmountText(100, {'currencyCode': 'PHP'}, 'PHP'), isNull);
  });

  test('a foreign account shows its own symbol, not the peso', () {
    expect(accountForeignCode({'currencyCode': 'USD'}, 'PHP'), 'USD');
    expect(formatAccountBalance(1000, {'currencyCode': 'USD'}, 'PHP'), '\$1,000.00');
    expect(accountAmountText(1000, {'currencyCode': 'USD'}, 'PHP'), '\$1,000.00');
  });

  test('a zero-decimal currency drops the decimals', () {
    // JPY is a zero-decimal currency in formatConverted.
    expect(formatAccountBalance(1300, {'currencyCode': 'JPY'}, 'PHP'), '¥1,300');
  });

  test('the base itself can be non-peso; then a peso account is the foreign one', () {
    // Base USD: a plain (codeless) account is USD, a PHP account is foreign.
    expect(accountForeignCode({'balance': 5}, 'USD'), isNull);
    expect(accountForeignCode({'currencyCode': 'PHP'}, 'USD'), 'PHP');
    expect(formatAccountBalance(500, {'currencyCode': 'PHP'}, 'USD'), '₱500.00');
  });
}
