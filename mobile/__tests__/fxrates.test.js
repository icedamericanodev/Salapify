// Regression suite for lib/fxrates.js: the pure core of live exchange rates.
// The network fetch and cache live in the hook and are not unit tested here; this
// covers the parsing and conversion math that decides what rate a user sees.

import { parseRatesResponse, basePerUnit, roundRate, isFresh, crossRate, FX_MAX_AGE_MS } from '../lib/fxrates';
import { formatConverted } from '../lib/currencies';

describe('parseRatesResponse only trusts a well formed success response', () => {
  test('a good response parses to base, rates, and a millisecond timestamp', () => {
    const out = parseRatesResponse({
      result: 'success',
      base_code: 'PHP',
      time_last_update_unix: 1710000000,
      rates: { PHP: 1, USD: 0.0176, JPY: 2.62 },
    });
    expect(out.base).toBe('PHP');
    expect(out.rates.USD).toBe(0.0176);
    expect(out.fetchedAt).toBe(1710000000 * 1000);
  });
  test('a failure or malformed response returns null', () => {
    expect(parseRatesResponse(null)).toBeNull();
    expect(parseRatesResponse({ result: 'error' })).toBeNull();
    expect(parseRatesResponse({ result: 'success', base_code: 'PHP' })).toBeNull(); // no rates
    expect(parseRatesResponse({ result: 'success', rates: { USD: 1 } })).toBeNull(); // no base
  });
  test('a missing timestamp is null, not a wrong date', () => {
    const out = parseRatesResponse({ result: 'success', base_code: 'PHP', rates: { USD: 1 } });
    expect(out.fetchedAt).toBeNull();
  });
});

describe('basePerUnit inverts the provider units-per-base into base-per-unit', () => {
  test('1 USD in PHP is 1 / (USD per PHP)', () => {
    // 1 PHP = 0.0176 USD, so 1 USD = 1/0.0176 ≈ 56.8 PHP.
    expect(basePerUnit({ USD: 0.0176 }, 'USD')).toBeCloseTo(56.818, 2);
  });
  test('a missing or non positive rate is null, never a wrong number', () => {
    expect(basePerUnit({ USD: 0.0176 }, 'VND')).toBeNull();
    expect(basePerUnit({ USD: 0 }, 'USD')).toBeNull();
    expect(basePerUnit({ USD: -1 }, 'USD')).toBeNull();
    expect(basePerUnit(null, 'USD')).toBeNull();
  });
});

describe('roundRate keeps four significant figures for strong and weak currencies', () => {
  test('strong and weak currencies both stay accurate and tidy', () => {
    expect(roundRate(56.818181)).toBe(56.82);
    expect(roundRate(0.38167)).toBe(0.3817);
    expect(roundRate(0.00231499)).toBe(0.002315);
  });
  test('a bad input is null', () => {
    expect(roundRate(0)).toBeNull();
    expect(roundRate(NaN)).toBeNull();
  });
});

describe('crossRate converts between any two currencies from one base table', () => {
  // Table is units-per-PHP: 1 PHP = 0.0176 USD = 2.62 JPY.
  const rates = { PHP: 1, USD: 0.0176, JPY: 2.62 };
  test('base to another currency is just that currency rate', () => {
    expect(crossRate(rates, 'PHP', 'USD')).toBeCloseTo(0.0176, 6);
  });
  test('two non-base currencies cancel the base out (1 USD in JPY)', () => {
    // 1 USD = (2.62 JPY per PHP) / (0.0176 USD per PHP) ≈ 148.86 JPY.
    expect(crossRate(rates, 'USD', 'JPY')).toBeCloseTo(2.62 / 0.0176, 4);
  });
  test('same currency is 1', () => {
    expect(crossRate(rates, 'USD', 'USD')).toBeCloseTo(1, 9);
  });
  test('a missing currency yields null, never a wrong figure', () => {
    expect(crossRate(rates, 'USD', 'VND')).toBeNull();
    expect(crossRate(rates, 'VND', 'USD')).toBeNull();
    expect(crossRate(null, 'USD', 'JPY')).toBeNull();
  });
});

describe('formatConverted shows the right decimals per currency', () => {
  test('two decimals for normal currencies, none for zero-decimal ones', () => {
    expect(formatConverted(12.5, 'USD')).toBe('$12.50');
    expect(formatConverted(1300.4, 'JPY')).toBe('¥1,300');
    expect(formatConverted(690.5, 'PHP')).toBe('₱690.50');
  });
  test('a bad amount is empty, never NaN', () => {
    expect(formatConverted(NaN, 'USD')).toBe('');
  });
});

describe('isFresh gates the refetch', () => {
  const now = 1710000000000;
  test('within the max age is fresh, beyond it is stale', () => {
    expect(isFresh(now - 1000, now)).toBe(true);
    expect(isFresh(now - FX_MAX_AGE_MS - 1, now)).toBe(false);
    expect(isFresh(null, now)).toBe(false);
  });
});
