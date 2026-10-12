import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/money/fx_rates.dart';

/// Fetches live rates, and keeps the last good set on the device.
///
/// THIS IS THE ONLY NETWORK CALL IN SALAPIFY. Founder direction, 2026-09-19:
/// "Live rates for FX converter, suggest reliable API and implement. Lets fix
/// the data privacy later on. Lets build first freely, we are not yet
/// launching it in app store."
///
/// What that means in practice, written down so nobody has to reconstruct it:
///
///   - The app's own header used to say "Offline Only", which this request
///     made false. RESOLVED on 2026-09-19 by founder direction: the badge
///     reads "On this phone", which is true of the ledger without
///     qualification, and it taps through to a receipt that names this
///     request by name. `main.dart`'s doc comment was corrected with it.
///   - `android:INTERNET` had to move into the release manifest. It was in
///     the debug one only, which is why this would have worked on the
///     founder's emulator and failed silently in a real build.
///   - Play's data safety form will have to declare it before launch.
///
/// None of that is a blocker today and all of it is a blocker before the
/// store. It is listed in docs/reviews/ rather than left implied.
///
/// The call itself is as small as it can be: no key, no account, no headers
/// identifying anybody, no body, and the only thing the server learns is that
/// some device asked for today's rates.
class FxService {
  FxService({this.endpoint = defaultEndpoint, this.cacheDir});

  /// open.er-api.com, keyless, and the prototype's own choice.
  static const String defaultEndpoint = 'https://open.er-api.com/v6/latest/PHP';

  final String endpoint;

  /// Where the cache file goes. Null means ask path_provider, which is what
  /// the app does; a test passes a temp directory and never touches a
  /// platform channel.
  final Directory? cacheDir;

  static const String _fileName = 'salapify_fx_cache.json';

  /// Short on purpose. Somebody tapping Refresh is standing there watching,
  /// and a converter that hangs for thirty seconds is worse than one that
  /// says "could not reach it" in five and keeps yesterday's rates.
  static const Duration timeout = Duration(seconds: 8);

  Future<File?> _cacheFile() async {
    try {
      final Directory dir =
          cacheDir ?? await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } on Object {
      // No documents directory, which on a device usually means the plugin is
      // not registered. Caching is a convenience, so losing it is not worth
      // failing the whole converter over.
      return null;
    }
  }

  /// The best rates available WITHOUT touching the network.
  ///
  /// Always returns something: the cache when there is one, the built-in table
  /// when there is not. A converter that shows nothing until a request
  /// finishes is a converter that shows nothing on a train.
  Future<FxRates> loadCached() async {
    try {
      final File? f = await _cacheFile();
      if (f == null || !await f.exists()) return FxRates.builtIn();
      final FxRates? cached = FxRates.fromCacheJson(await f.readAsString());
      return cached ?? FxRates.builtIn();
    } on Object {
      return FxRates.builtIn();
    }
  }

  /// Asks the server for today's rates.
  ///
  /// Returns null on ANY failure, and null means "keep what you had". No
  /// offline state, no timeout and no malformed response is allowed to take
  /// away rates the app already has.
  Future<FxRates?> fetch({DateTime? now}) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .getUrl(Uri.parse(endpoint))
          .timeout(timeout);
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      if (response.statusCode != 200) return null;

      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      final FxRates? rates = FxRates.fromApiJson(body, now: now);
      if (rates != null) await _save(rates);
      return rates;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _save(FxRates rates) async {
    try {
      final File? f = await _cacheFile();
      if (f == null) return;
      await f.writeAsString(jsonEncode(rates.toJson()), flush: true);
    } on Object {
      // A cache that cannot be written is a slower app, not a broken one.
    }
  }
}
