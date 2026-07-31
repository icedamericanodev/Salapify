// The backup posture is a promise the user cannot see, so a machine holds it.
//
// Salapify keeps the whole ledger on the device and tells the user so on the
// Privacy receipt. Three things enforce that on Android, and all three are one
// edit away from silently disappearing with every other check still green:
//
//   1. android:allowBackup="false"                 (turns off cloud backup)
//   2. android:fullBackupContent -> backup_rules    (Android 11 and lower)
//   3. android:dataExtractionRules -> the 12+ rules (Android 12 and newer,
//      including the device-to-device transfer that allowBackup does NOT stop)
//
// If any attribute is dropped, or a rules file stops excluding a data domain,
// financial data becomes eligible to leave the phone. Nothing else in the suite
// would notice. This is the guard.
//
// Proven by deliberate break: flipping allowBackup to "true", or deleting a
// dataExtractionRules attribute, or removing the device-transfer <exclude> for
// the "file" domain (where the encrypted database lives), each reddens exactly
// the assertion that names the gap. See the commit that added this file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every app data domain. If Android ever adds one, this list is where a
// reviewer decides whether it needs excluding too; a hard-coded set is a
// promise, not a guess.
const _domains = ['root', 'file', 'database', 'sharedpref', 'external'];

String _readManifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

// Strip XML comments so a domain named in prose can never satisfy a check that
// a domain named in a rule should.
String _stripComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

void main() {
  group('the manifest wires all three controls', () {
    final manifest = _stripComments(_readManifest());

    test('cloud backup is off (allowBackup="false")', () {
      expect(
        manifest.contains('android:allowBackup="false"'),
        isTrue,
        reason:
            'allowBackup is not false, so the ledger becomes eligible for '
            'Google cloud backup. This is the primary control.',
      );
      expect(
        manifest.contains('android:allowBackup="true"'),
        isFalse,
        reason: 'allowBackup is explicitly true, which re-enables cloud backup.',
      );
    });

    test('Android 11 rules are wired (fullBackupContent)', () {
      expect(
        manifest.contains('android:fullBackupContent="@xml/backup_rules"'),
        isTrue,
        reason:
            'fullBackupContent is not wired, so Android 11 and lower fall back '
            'to default backup behavior for the ledger.',
      );
    });

    test('Android 12+ rules are wired (dataExtractionRules)', () {
      expect(
        manifest.contains(
          'android:dataExtractionRules="@xml/data_extraction_rules"',
        ),
        isTrue,
        reason:
            'dataExtractionRules is not wired, so on Android 12+ a '
            'device-to-device transfer (which allowBackup=false does NOT stop) '
            'would carry the ledger.',
      );
    });
  });

  group('the Android 12+ rules exclude everything, both ways', () {
    final xml = _stripComments(
      File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync(),
    );

    // Pull out the two sections so a rule in one cannot count for the other.
    String section(String tag) {
      final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
      expect(m, isNotNull, reason: 'no <$tag> section in the 12+ rules');
      return m!.group(1)!;
    }

    for (final where in ['cloud-backup', 'device-transfer']) {
      test('$where excludes every data domain', () {
        final body = section(where);
        for (final d in _domains) {
          expect(
            body.contains('<exclude domain="$d"'),
            isTrue,
            reason:
                '$where does not exclude the "$d" domain, so that data is '
                'eligible. The encrypted database lives in the "file" domain.',
          );
        }
      });
    }

    test('no <include> re-admits anything', () {
      expect(
        xml.contains('<include'),
        isFalse,
        reason:
            'an <include> in an exclude-only rules file re-admits data to '
            'backup or transfer. There must be none.',
      );
    });
  });

  group('the Android 11 rules exclude everything', () {
    final xml = _stripComments(
      File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync(),
    );

    test('every data domain is excluded', () {
      for (final d in _domains) {
        expect(
          xml.contains('<exclude domain="$d"'),
          isTrue,
          reason:
              'the Android 11 rules do not exclude the "$d" domain, so that '
              'data is eligible for backup on those devices.',
        );
      }
    });

    test('no <include> re-admits anything', () {
      expect(
        xml.contains('<include'),
        isFalse,
        reason: 'an <include> re-admits data to backup. There must be none.',
      );
    });
  });
}
