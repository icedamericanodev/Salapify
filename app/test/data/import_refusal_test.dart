import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/import.dart';

/// `checkImportFile` must REFUSE, never throw.
///
/// ## Why this is the worst place for a silent failure
///
/// It is reached from one screen: Settings, Restore from a backup. Somebody is
/// there because something has already gone wrong. The function only caught
/// `SnapshotFormatException`, and the decoder throws other things:
///
///   - `_reqInt` calls `toInt()` and `paydayFromJson` calls `round()`, and
///     both throw `UnsupportedError` on an infinite double. `1e400` is valid
///     JSON and Dart decodes it to `double.infinity`.
///   - `Money.fromDouble` refuses a figure it cannot count in centavos with a
///     plain `FormatException`, which is not a subtype of
///     `SnapshotFormatException`.
///
/// An escape does not show an error. The call sites are a tap handler and a
/// `setState`, so the throw goes to a log nobody reads and the BUTTON SIMPLY
/// DOES NOTHING. No red box, no "Nothing on this phone has changed". On the
/// paste route it also leaves `_busy` set, which permanently disables "Put the
/// earlier ledger back".
String _file(String amountJson, {String createdAt = '1'}) =>
    '''
{
  "schemaVersion": 1,
  "accounts": [
    {"id":"a1","name":"BPI","kind":"bank","institution":"BPI",
     "balance":23000,"monogram":"B"}
  ],
  "transactions": [
    {"id":"t1","type":"expense","amount":$amountJson,"category":"Food",
     "accountId":"a1","date":"2026-09-12","createdAt":$createdAt}
  ],
  "debts": [], "budgets": [], "goals": [], "upcoming": [],
  "installments": [], "bills": [], "incomeStreams": []
}''';

void main() {
  group('a figure the app cannot use is refused, not thrown', () {
    test('an amount too large to count in centavos', () {
      // Every file already on a phone was written by a build with NO magnitude
      // check, so this is the realistic one: an upgrade meeting a fat-fingered
      // row somebody typed months ago.
      final ImportCheck r = checkImportFile(_file('1e17'));
      expect(r, isA<ImportRefused>());
      expect((r as ImportRefused).reason, isNotEmpty);
    });

    test('an infinite number, which valid JSON can carry', () {
      // 1e400 overflows a double to Infinity. jsonDecode accepts it happily.
      expect(jsonDecode('{"a":1e400}'), <String, dynamic>{
        'a': double.infinity,
      });

      final ImportCheck r = checkImportFile(_file('1e400'));
      expect(r, isA<ImportRefused>());
    });

    test(
      'an infinite value in an INT field, which throws a different type',
      () {
        // UnsupportedError from toInt(), not a FormatException at all. This one
        // predates the centavo work and escaped the same way.
        final ImportCheck r = checkImportFile(_file('250', createdAt: '1e400'));
        expect(r, isA<ImportRefused>());
      },
    );

    test('and the refusal says something a person can act on', () {
      final ImportRefused r = checkImportFile(_file('1e17')) as ImportRefused;
      // The screen appends "Nothing on this phone has changed." itself, so the
      // reason must carry the cause rather than the reassurance.
      expect(r.reason.length, greaterThan(20));
      expect(r.reason, isNot(contains('Exception')));
    });

    test(
      'a GOOD file is still accepted, so this did not refuse everything',
      () {
        // The directional half. A function that refused every file would pass
        // all four tests above and break restore completely.
        final ImportCheck r = checkImportFile(_file('250'));
        expect(
          r,
          isNot(isA<ImportRefused>()),
          reason: 'an ordinary backup must still import',
        );
      },
    );
  });
}
