// fxrates.js: the pure, testable core of live exchange rates.
//
// Salapify stays offline first. This layer only makes the app NICER when it has
// internet: it fetches today's public rates so the log sheet can pre fill the
// rate for a foreign expense. It never sends any user or financial data, it only
// downloads a table of public market rates. When the phone is offline, the fetch
// fails, or a currency is not covered, the user types the rate by hand exactly as
// before, so nothing here is ever load bearing for correctness.
//
// The network fetch and cache live in hooks/useFxRates.js (they touch the device);
// everything here is pure so it can be unit tested.

// Free, no API key. The response shape is documented and stable:
//   { result: 'success', base_code: 'PHP', time_last_update_unix: 1710000000,
//     rates: { USD: 0.0176, JPY: 2.62, ... } }  // rates are UNITS PER 1 base
export const FX_PROVIDER = 'open.er-api.com';
export const FX_ENDPOINT = (base) =>
  `https://open.er-api.com/v6/latest/${encodeURIComponent(String(base || 'PHP'))}`;

// Refetch at most twice a day. Rates barely move day to day for budgeting, and a
// stale-by-a-few-hours rate the user can see and override is fine.
export const FX_MAX_AGE_MS = 12 * 60 * 60 * 1000;

// Turn the provider response into { base, rates, fetchedAt } or null. Anything
// unexpected returns null so the caller falls back to a typed rate.
export function parseRatesResponse(json) {
  if (!json || json.result !== 'success' || !json.rates || typeof json.rates !== 'object') return null;
  const base = typeof json.base_code === 'string' ? json.base_code : null;
  if (!base) return null;
  const fetchedAt = Number(json.time_last_update_unix);
  return {
    base,
    rates: json.rates,
    fetchedAt: Number.isFinite(fetchedAt) && fetchedAt > 0 ? fetchedAt * 1000 : null,
  };
}

// base currency per 1 unit of `code`. The provider gives units-per-base, so we
// invert. Returns null when the code is missing or the rate is not a positive
// number, so a bad or absent entry never yields a wrong figure.
export function basePerUnit(rates, code) {
  const perBase = rates ? Number(rates[code]) : NaN;
  if (!Number.isFinite(perBase) || perBase <= 0) return null;
  return 1 / perBase;
}

// Round a rate to four significant figures so the pre filled value is tidy for
// both strong (56.34) and weak (0.002315) currencies without losing accuracy.
export function roundRate(r) {
  const n = Number(r);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Number(n.toPrecision(4));
}

// Is a cached table still fresh enough to skip a refetch?
export function isFresh(fetchedAt, nowMs) {
  if (!fetchedAt) return false;
  return nowMs - fetchedAt < FX_MAX_AGE_MS;
}
