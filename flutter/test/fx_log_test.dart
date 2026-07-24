// The Privacy receipt's fetch log: every FX fetch attempt is recorded to its
// own prefs key (never the backup blob), newest first, capped, and junk-safe.
// The log must never break the converter, and a corrupt stored log must read
// as empty instead of crashing the receipt screen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/fx_service.dart';
import 'package:salapify/screens/privacy_receipt.dart' show fxLogWhen;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseFxLog', () {
    test('keeps only well-formed entries', () {
      final parsed = parseFxLog([
        {'at': 1000, 'base': 'PHP', 'ok': true},
        {'at': 'junk', 'base': 'PHP', 'ok': true},
        {'at': 2000, 'base': 5, 'ok': true},
        {'at': 3000, 'base': 'USD', 'ok': 'yes'},
        'junk',
        null,
      ]);
      expect(parsed.length, 1);
      expect(parsed.single['base'], 'PHP');
    });

    test('a non-list reads as empty', () {
      expect(parseFxLog('junk'), isEmpty);
      expect(parseFxLog(null), isEmpty);
      expect(parseFxLog({'at': 1}), isEmpty);
    });

    test('an out-of-range timestamp is dropped, never crashes the screen', () {
      // DateTime.fromMillisecondsSinceEpoch throws past ~8.64e15; a corrupted
      // or hand-edited prefs entry must not take down the receipt.
      final parsed = parseFxLog([
        {'at': 9223372036854775807, 'base': 'PHP', 'ok': true},
        {'at': -5, 'base': 'PHP', 'ok': true},
        {'at': 1000, 'base': 'PHP', 'ok': true},
      ]);
      expect(parsed.length, 1);
      expect(parsed.single['at'], 1000);
    });
  });

  group('appendFxLog', () {
    test('newest entry goes first', () {
      final log = appendFxLog(
        [
          {'at': 1000, 'base': 'PHP', 'ok': true},
        ],
        base: 'USD',
        ok: false,
        atMs: 2000,
      );
      expect(log.first, {'at': 2000, 'base': 'USD', 'ok': false});
      expect(log.last['at'], 1000);
    });

    test('caps the stored list', () {
      var log = <Map<String, dynamic>>[];
      for (var i = 0; i < 15; i++) {
        log = appendFxLog(log, base: 'PHP', ok: true, atMs: i);
      }
      expect(log.length, 10);
      expect(log.first['at'], 14, reason: 'newest kept');
      expect(log.last['at'], 5, reason: 'oldest beyond the cap dropped');
    });

    test('junk existing state is dropped, not kept', () {
      final log = appendFxLog('not a list', base: 'PHP', ok: true, atMs: 1);
      expect(log.length, 1);
    });
  });

  group('FxService.fetchLog', () {
    test('reads back recorded entries', () async {
      SharedPreferences.setMockInitialValues({
        FxService.logKey: jsonEncode([
          {'at': 2000, 'base': 'USD', 'ok': true},
          {'at': 1000, 'base': 'PHP', 'ok': false},
        ]),
      });
      final log = await FxService().fetchLog();
      expect(log.length, 2);
      expect(log.first['base'], 'USD');
    });

    test('a corrupt stored log reads as empty, never throws', () async {
      SharedPreferences.setMockInitialValues({FxService.logKey: '{broken'});
      expect(await FxService().fetchLog(), isEmpty);
    });

    test('no log yet reads as empty', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await FxService().fetchLog(), isEmpty);
    });
  });

  group('a real refresh records its attempt', () {
    test('an offline failure lands in the log as ok=false', () async {
      SharedPreferences.setMockInitialValues({});
      // The phone is offline: every HTTP client fails. This is FORCED here
      // rather than assumed, because a machine with working internet (a CI
      // runner) would otherwise really reach the rates endpoint, succeed, and
      // fail this test while nothing was wrong with the app. The failed
      // attempt must still be recorded, because the receipt logs attempts,
      // not just successes.
      final service = FxService();
      var askedForAClient = false;
      final result = await HttpOverrides.runZoned(
        () => service.refresh('PHP', nowMs: 1234567890),
        createHttpClient: (_) {
          askedForAClient = true;
          throw const SocketException('offline, by test design');
        },
      );
      expect(
        askedForAClient,
        isTrue,
        reason:
            'the forced-offline client must be the one used, so this test '
            'can never quietly start depending on the machine having internet',
      );
      expect(result, isNull);
      final log = await service.fetchLog();
      expect(log.length, 1);
      expect(log.single['ok'], false);
      expect(log.single['base'], 'PHP');
      expect(log.single['at'], 1234567890);
    });
  });

  group('fxLogWhen', () {
    test('formats a local timestamp plainly, year included', () {
      final at = DateTime(2026, 7, 24, 9, 5).millisecondsSinceEpoch;
      expect(fxLogWhen(at), 'Jul 24 2026, 9:05 AM');
    });

    test('noon and midnight read as 12', () {
      final noon = DateTime(2026, 1, 2, 12, 0).millisecondsSinceEpoch;
      final midnight = DateTime(2026, 1, 2, 0, 30).millisecondsSinceEpoch;
      expect(fxLogWhen(noon), 'Jan 2 2026, 12:00 PM');
      expect(fxLogWhen(midnight), 'Jan 2 2026, 12:30 AM');
    });
  });
}
