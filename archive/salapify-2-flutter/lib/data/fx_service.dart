// The device side of live exchange rates: fetch today's public rates when
// online, cache them, and hand them to the currency converter. Everything
// degrades gracefully: offline, a failed fetch, or an uncovered currency all
// leave the user without a rate, and the converter says so. It never sends any
// user or financial data, only the base currency code in the URL.
//
// The cache is a SEPARATE SharedPreferences key, not the main data blob, so
// live rates never bloat a user's backup. All parsing goes through the pure,
// golden-locked fxrates.dart.
//
// Every fetch ATTEMPT is also recorded to its own small prefs key (again
// outside the backup), so the Privacy receipt screen can show the user a real
// log of every time this app reached out, success or not. The receipt is the
// standing rule for the whole codebase: any future connection must appear
// there, or it does not ship.

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../money/fxrates.dart';

// DateTime.fromMillisecondsSinceEpoch throws beyond this; a hand-edited or
// corrupted entry past it must be dropped, not crash the receipt screen.
const int _maxEpochMs = 8640000000000000;

/// Parse a stored receipt log into well-formed entries only. Junk (not a
/// list, foreign entries, wrong field types, an out-of-range timestamp) is
/// dropped, never thrown on.
List<Map<String, dynamic>> parseFxLog(dynamic stored) => [
  for (final e in (stored is List ? stored : const []))
    if (e is Map &&
        e['at'] is int &&
        (e['at'] as int) >= 0 &&
        (e['at'] as int) <= _maxEpochMs &&
        e['base'] is String &&
        e['ok'] is bool)
      e.cast<String, dynamic>(),
];

/// Append one fetch attempt to the receipt log, newest first, capped so the
/// stored list stays tiny.
List<Map<String, dynamic>> appendFxLog(
  dynamic existing, {
  required String base,
  required bool ok,
  required int atMs,
  int cap = 10,
}) {
  final out = [
    {'at': atMs, 'base': base, 'ok': ok},
    ...parseFxLog(existing),
  ];
  return out.length > cap ? out.sublist(0, cap) : out;
}

class FxRates {
  final String base;
  final Map<String, dynamic> rates;
  final int? fetchedAt; // ms since epoch
  const FxRates(this.base, this.rates, this.fetchedAt);
}

class FxService {
  static const String cacheKey = 'salapify_fx_v1';
  static const String logKey = 'salapify_fx_log_v1';
  static const Duration timeout = Duration(seconds: 6);

  /// The recorded fetch attempts, newest first. Never throws; a corrupt log
  /// reads as empty.
  Future<List<Map<String, dynamic>>> fetchLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(logKey);
      if (raw == null) return const [];
      return parseFxLog(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _recordFetch(String base, bool ok, int atMs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      dynamic existing;
      final raw = prefs.getString(logKey);
      if (raw != null) existing = jsonDecode(raw);
      await prefs.setString(
        logKey,
        jsonEncode(appendFxLog(existing, base: base, ok: ok, atMs: atMs)),
      );
    } catch (_) {
      // The receipt log must never break the converter.
    }
  }

  /// The last cached table for this base, or null. Never throws.
  Future<FxRates?> cached(String base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return null;
      final j = jsonDecode(raw);
      if (j is Map && j['base'] == base && j['rates'] is Map) {
        return FxRates(
          base,
          (j['rates'] as Map).cast<String, dynamic>(),
          j['fetchedAt'] is int ? j['fetchedAt'] as int : null,
        );
      }
    } catch (_) {
      // A corrupt cache must never crash the converter.
    }
    return null;
  }

  /// Try the network. Returns fresh rates and updates the cache on success, or
  /// null on any failure (offline, timeout, non-200, bad body). Never throws.
  /// Every attempt, either way, lands in the Privacy receipt log.
  Future<FxRates?> refresh(String base, {int? nowMs}) async {
    final result = await _attempt(base, nowMs: nowMs);
    await _recordFetch(
      base,
      result != null,
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    return result;
  }

  Future<FxRates?> _attempt(String base, {int? nowMs}) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final req = await client
          .getUrl(Uri.parse(fxEndpoint(base)))
          .timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final parsed = parseRatesResponse(jsonDecode(body));
      if (parsed == null || parsed['rates'] is! Map) return null;
      final stamp = parsed['fetchedAt'] is num
          ? (parsed['fetchedAt'] as num).round()
          : (nowMs ?? DateTime.now().millisecondsSinceEpoch);
      final rates = (parsed['rates'] as Map).cast<String, dynamic>();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          cacheKey,
          jsonEncode({'base': base, 'rates': rates, 'fetchedAt': stamp}),
        );
      } catch (_) {
        // A full disk must not crash the converter; the rates still show.
      }
      return FxRates(base, rates, stamp);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Cache first, refresh only when the cache is stale or absent. Returns the
  /// best rates available, or null when there is nothing to show.
  Future<FxRates?> load(String base) async {
    final c = await cached(base);
    if (c != null &&
        isFresh(c.fetchedAt, DateTime.now().millisecondsSinceEpoch)) {
      return c;
    }
    final fresh = await refresh(base);
    return fresh ?? c;
  }
}
