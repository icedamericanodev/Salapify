// Golden vectors for the multi-currency port.
//
// Run with: bun app/tool/gen_currency_vectors.ts
//
// This imports the PROTOTYPE'S OWN currencies.ts and prints what it returns.
// The printed numbers become the Dart expectations in
// app/test/core/money/currencies_test.dart, so the two implementations are
// pinned to each other rather than to my reading of either one.
//
// formatCurrency calls toLocaleString('en-PH'), which is a browser and
// runtime API. Dart's NumberFormat is a different implementation of the same
// grouping rules, so the STRINGS are the part of this port most likely to
// drift, and they are exactly what this dump captures.

import {
  SUPPORTED_CURRENCIES,
  CURRENCY_SYMBOLS,
  CURRENCY_NAMES,
  EXCHANGE_RATES_TO_PHP,
  convertToPhp,
  formatCurrency,
} from '../../src/utils/currencies';
import type { CurrencyCode } from '../../src/types';

const codes: CurrencyCode[] = ['PHP', 'USD', 'EUR', 'JPY', 'SGD'];

// Amounts chosen to catch the things that actually break a money formatter:
// zero, a sub-peso value, a value that rounds at the second decimal, a
// thousands boundary, a negative, and something large enough to need two
// group separators.
const amounts = [0, 0.5, 1, 12.345, 999.995, 1000, 12345.67, -2500, 1234567.89];

const out: Record<string, unknown> = {};

out.supported = SUPPORTED_CURRENCIES;
out.symbols = CURRENCY_SYMBOLS;
out.names = CURRENCY_NAMES;
out.rates = EXCHANGE_RATES_TO_PHP;

const conversions: Array<{ amount: number; currency: string; php: number }> = [];
const formats: Array<{
  amount: number;
  currency: string;
  withDecimals: string;
  withoutDecimals: string;
}> = [];

for (const c of codes) {
  for (const a of amounts) {
    conversions.push({ amount: a, currency: c, php: convertToPhp(a, c) });
    formats.push({
      amount: a,
      currency: c,
      withDecimals: formatCurrency(a, c, true),
      withoutDecimals: formatCurrency(a, c, false),
    });
  }
}

out.conversions = conversions;
out.formats = formats;

console.log(JSON.stringify(out, null, 2));
