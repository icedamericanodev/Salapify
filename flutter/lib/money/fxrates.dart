// The pure, testable core of live exchange rates, ported 1:1 from
// mobile/lib/fxrates.js. Salapify stays offline first: this only makes the app
// nicer when it has internet by fetching today's public rates. It never sends
// any user or financial data, only downloads a table of public market rates.
// Offline, on a failed fetch, or an uncovered currency, the user types the rate
// by hand, so nothing here is ever load bearing for correctness. The network
// fetch and cache live in the fx service (it touches the device); everything
// here is pure and golden verified against the RN app.

/// Free, no API key. Rates are UNITS PER 1 base.
const String fxProvider = 'open.er-api.com';
String fxEndpoint(String? base) =>
    'https://open.er-api.com/v6/latest/${Uri.encodeComponent(base == null || base.isEmpty ? 'PHP' : base)}';

/// Refetch at most twice a day; rates barely move for budgeting.
const int fxMaxAgeMs = 12 * 60 * 60 * 1000;

double? _rate(dynamic rates, dynamic code) {
  if (rates is! Map) return null;
  final v = rates[code];
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  return (n != null && n.isFinite) ? n : null;
}

/// Turn the provider response into { base, rates, fetchedAt } or null. Anything
/// unexpected returns null so the caller falls back to a typed rate.
Map<String, dynamic>? parseRatesResponse(dynamic json) {
  if (json is! Map ||
      json['result'] != 'success' ||
      json['rates'] is! Map) {
    return null;
  }
  final base = json['base_code'] is String ? json['base_code'] as String : null;
  if (base == null) return null;
  final raw = json['time_last_update_unix'];
  final fetched = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
  return {
    'base': base,
    'rates': json['rates'],
    'fetchedAt':
        (fetched != null && fetched.isFinite && fetched > 0) ? fetched * 1000 : null,
  };
}

/// base currency per 1 unit of `code`. The provider gives units-per-base, so we
/// invert. Null when the code is missing or the rate is not a positive number.
double? basePerUnit(dynamic rates, dynamic code) {
  final perBase = _rate(rates, code);
  if (perBase == null || perBase <= 0) return null;
  return 1 / perBase;
}

/// The cross rate to convert 1 unit of `from` into `to` using one units-per-base
/// table. rates[to] / rates[from] cancels the base out. Null when either
/// currency is missing or non positive, so a gap never yields a wrong figure.
double? crossRate(dynamic rates, dynamic from, dynamic to) {
  final f = _rate(rates, from);
  final t = _rate(rates, to);
  if (f == null || f <= 0 || t == null || t <= 0) return null;
  return t / f;
}

/// Round a rate to four significant figures so the pre filled value is tidy for
/// both strong (56.34) and weak (0.002315) currencies. Mirrors JS
/// Number(n.toPrecision(4)); null on a non positive or non finite input.
double? roundRate(dynamic r) {
  final n = r is num ? r.toDouble() : double.tryParse('${r ?? ''}');
  if (n == null || !n.isFinite || n <= 0) return null;
  return double.parse(n.toStringAsPrecision(4));
}

/// Is a cached table still fresh enough to skip a refetch? A null or zero stamp
/// is never fresh (JS treats both as falsy).
bool isFresh(dynamic fetchedAt, num nowMs) {
  final f = fetchedAt is num ? fetchedAt.toDouble() : double.tryParse('${fetchedAt ?? ''}');
  if (f == null || f == 0) return false;
  return nowMs - f < fxMaxAgeMs;
}
