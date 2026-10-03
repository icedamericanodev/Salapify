import 'dart:convert';

import 'currencies.dart';

/// Live foreign exchange rates, and what to do when there are none.
///
/// Ported from the prototype's FX converter in
/// `src/components/PhilippineFeaturesModal.tsx`, which fetches
/// `https://open.er-api.com/v6/latest/PHP`.
///
/// ## Why that API
///
/// It needs NO API KEY. That is the whole argument and it is decisive for this
/// app: a key is a secret to store, a secret to rotate, a secret to keep out
/// of a public repository, and a thing that expires at the worst moment. An
/// endpoint with no key has none of those failure modes. It is also the one
/// the prototype already uses, so the numbers match rather than merely being
/// close.
///
/// (`exchangerate.host`, the usual alternative, now requires a key. So does
/// Fixer and so does OpenExchangeRates. For a free, unauthenticated, daily
/// rate this is the sensible one.)
///
/// ## The rates are a QUOTE, never a promise
///
/// Mid-market rates. Nobody transacts at them: a bank's remittance rate, a
/// money changer's board and a card's conversion are all worse, sometimes by
/// several percent. Anything built on this has to say so, which is why
/// [FxRates.disclaimer] is a constant here rather than a sentence somebody
/// remembers to write on one screen and forgets on the next.

/// Where a set of rates came from. The user is told, because "58.50" from
/// three weeks ago and "58.50" from this morning are different claims.
enum FxSource {
  /// Shipped in the app. Always available, always stale.
  builtIn,

  /// Read back from the last successful fetch on this device.
  cached,

  /// Fetched just now.
  live,
}

class FxRates {
  const FxRates({
    required this.pesosPerUnit,
    required this.source,
    this.fetchedAt,
  });

  /// The built-in table, which is what the app has known since before any of
  /// this. Never empty, so there is always something to convert with.
  factory FxRates.builtIn() => FxRates(
    pesosPerUnit: <String, double>{
      for (final MapEntry<CurrencyCode, double> e in exchangeRatesToPhp.entries)
        e.key.wire: e.value,
    },
    source: FxSource.builtIn,
  );

  /// How many PESOS one unit of each currency is worth.
  ///
  /// The API answers the other way round, as units per peso, and a rate
  /// inverted by accident is the kind of mistake that looks plausible: it
  /// turns a 58 peso dollar into a 0.017 peso dollar, which is obviously
  /// wrong, or a 0.39 peso yen into a 2.57 peso yen, which is not.
  final Map<String, double> pesosPerUnit;

  final FxSource source;
  final DateTime? fetchedAt;

  static const String disclaimer =
      'Mid-market rates, for working things out. Banks, money changers and '
      'cards all give you less than this.';

  double? rateFor(CurrencyCode code) => pesosPerUnit[code.wire];

  /// Converts between any two of the currencies, through pesos.
  ///
  /// Returns null when either side has no rate, rather than falling back to 1.
  /// A silent rate of 1 would report a 1,000 dollar balance as 1,000 pesos,
  /// which is a plausible looking number and a 57,500 peso error.
  double? convert(double amount, CurrencyCode from, CurrencyCode to) {
    final double? fromRate = rateFor(from);
    final double? toRate = rateFor(to);
    if (fromRate == null || toRate == null) return null;
    if (toRate == 0) return null;
    return amount * fromRate / toRate;
  }

  /// True when these rates are old enough to be worth saying so about.
  ///
  /// open.er-api.com updates once a day, so anything past two days has
  /// certainly missed an update rather than merely being a few hours old.
  bool staleAt(DateTime now) {
    if (source == FxSource.builtIn) return true;
    final DateTime? at = fetchedAt;
    if (at == null) return true;
    return now.difference(at).inDays >= 2;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pesosPerUnit': pesosPerUnit,
    'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
  };

  /// Reads a cached set back. Returns null on anything it cannot trust, so a
  /// damaged cache falls through to the built-in table rather than putting a
  /// wrong rate on screen.
  static FxRates? fromCacheJson(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Object? rates = decoded['pesosPerUnit'];
      if (rates is! Map) return null;

      final Map<String, double> parsed = <String, double>{};
      for (final MapEntry<Object?, Object?> e in rates.entries) {
        final Object? k = e.key;
        final Object? v = e.value;
        if (k is String && v is num && v > 0 && v.isFinite) {
          parsed[k] = v.toDouble();
        }
      }
      if (parsed.isEmpty) return null;

      final Object? at = decoded['fetchedAt'];
      return FxRates(
        pesosPerUnit: parsed,
        source: FxSource.cached,
        fetchedAt: at is String ? DateTime.tryParse(at) : null,
      );
    } on Object {
      return null;
    }
  }

  /// Reads what open.er-api.com returns.
  ///
  /// Shape: `{"result":"success","base_code":"PHP","rates":{"USD":0.0177,...}}`
  ///
  /// Returns null rather than throwing on anything unexpected. The caller's
  /// answer to null is to keep the rates it already had, which is always a
  /// better answer than an exception on a screen somebody opened to convert
  /// two numbers.
  static FxRates? fromApiJson(String raw, {DateTime? now}) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['result'] != 'success') return null;

      // Only PHP-based responses, because the inversion below assumes it. A
      // base change would silently invert every rate against the wrong unit.
      if (decoded['base_code'] != 'PHP') return null;

      final Object? rates = decoded['rates'];
      if (rates is! Map) return null;

      final Map<String, double> pesos = <String, double>{'PHP': 1.0};
      for (final CurrencyCode code in CurrencyCode.values) {
        if (code == CurrencyCode.php) continue;
        final Object? perPeso = rates[code.wire];
        // A zero or a negative would divide into infinity or a negative rate.
        if (perPeso is! num || !perPeso.isFinite || perPeso <= 0) continue;
        pesos[code.wire] = 1 / perPeso.toDouble();
      }

      // Nothing but the peso itself means the response was the wrong shape.
      if (pesos.length < 2) return null;

      return FxRates(
        pesosPerUnit: pesos,
        source: FxSource.live,
        fetchedAt: now ?? DateTime.now(),
      );
    } on Object {
      return null;
    }
  }
}
