import 'dart:convert';
import 'dart:io';

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

  group('a backup from an EARLIER Salapify is named, not called a stranger', () {
    // THE FIXTURE IS REAL, and that is the whole point of this group.
    //
    // salapify2_export_envelope.json is byte for byte the `rnText` field of
    // archive/salapify-2-flutter/test/goldens/backup_export_goldens.json,
    // which is Salapify 2's own committed proof of what its export writes.
    // It is copied in rather than read across because app/ must not depend on
    // the archive staying where it is.
    //
    // A HAND BUILT OBJECT IS WHAT LET THIS THROUGH FOR MONTHS.
    // snapshot_test.dart already had a test for "the older Salapify" using
    // {"accounts":[],"transactions":[],"receivables":[],"people":[]}, which is
    // the shape of the data INSIDE the envelope and a shape nothing has ever
    // written to a file. The real export wraps all of that one level down
    // under `data`, so the guard that test proved could never fire on a real
    // file. Reading the real bytes is the only version of this test worth
    // having.
    final String realExport = File(
      'test/data/salapify2_export_envelope.json',
    ).readAsStringSync();

    test('the fixture really is a Salapify 2 envelope, not a Salapify 3 one', () {
      // Guards the guard. If somebody regenerates this fixture from the wrong
      // app, every assertion below would still pass while testing nothing.
      final Map<String, dynamic> m =
          jsonDecode(realExport) as Map<String, dynamic>;
      expect(m.keys.toSet(), <String>{'app', 'version', 'exportedAt', 'data'});
      expect(m['app'], 'salapify');
      expect(m['data'], isA<Map<String, dynamic>>());
      expect(
        m.containsKey('schemaVersion'),
        isFalse,
        reason: 'the ledger sits one level down, which is the whole problem',
      );
    });

    test('it is refused rather than half read', () {
      expect(checkImportFile(realExport), isA<ImportRefused>());
    });

    test('the refusal says WHICH app it came from', () {
      final ImportRefused r = checkImportFile(realExport) as ImportRefused;
      expect(r.reason, contains('earlier version of Salapify'));
    });

    test('the refusal tells the person to KEEP the file', () {
      // The sentence is the safety mechanism here, not the refusal.
      //
      // Nothing is written either way, so no tap can lose data. But somebody
      // who has just exported their entire financial history out of the old
      // app, and is then told the file "is not a Salapify backup", may
      // reasonably decide the export is broken or the file is junk and delete
      // the only copy that has ever existed off one phone. That is the loss
      // this group exists to prevent, and it happens outside the app.
      final ImportRefused r = checkImportFile(realExport) as ImportRefused;
      expect(r.reason, contains('Keep this file'));
      expect(r.reason, contains('only copy'));
      expect(
        r.reason,
        isNot(contains('not a Salapify backup')),
        reason: 'it IS a Salapify backup, and saying otherwise is what risks '
            'the file being deleted',
      );
    });

    test('nothing on this phone is said to have changed', () {
      final ImportRefused r = checkImportFile(realExport) as ImportRefused;
      expect(r.reason, contains('Nothing on this phone has changed'));
    });

    test(
      'a Salapify 3 backup is still accepted, so this did not refuse everything',
      () {
        // The directional half, per CLAUDE.md. Every assertion above also
        // passes if checkImportFile were changed to refuse every file in
        // existence, which would break restore completely and silently.
        expect(checkImportFile(_file('250')), isNot(isA<ImportRefused>()));
      },
    );

    test('a file that merely mentions salapify is NOT mistaken for one', () {
      // The envelope branch keys on `app == 'salapify'` AND a `data` map. One
      // without the other must fall through to the ordinary gate, or the new
      // branch becomes a way to get the wrong refusal on an unrelated file.
      final ImportRefused r =
          checkImportFile('{"app":"salapify","version":2}') as ImportRefused;
      expect(r.reason, isNot(contains('earlier version of Salapify')));
    });
  });
}
