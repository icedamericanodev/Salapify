// The merged-manifest allowlist, exercised instead of trusted.
//
// The real check runs in CI against the merged manifest of a real build, which
// is the only place that file exists. But a workflow step is only ever tested
// by shipping, so the LOGIC lives in .github/scripts/check-merged-manifest.sh
// and this drives it through every failure shape on the branch, before the
// merge: an unexpected permission, a rogue exported component, backup turned
// back on, a backup-rules attribute dropped, and cleartext enabled.
//
// It is a Dart test only because `flutter test` is what runs on the branch.
// There is nothing Flutter about it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = '../.github/scripts/check-merged-manifest.sh';

// A merged manifest that matches the allowlist exactly. Each failing case is
// this with one thing changed, so the test proves the check reacts to that one
// thing and nothing else.
const _goodManifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="dev.icedamericano.salapify">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <application android:label="Salapify Preview" android:allowBackup="false"
        android:fullBackupContent="@xml/backup_rules"
        android:dataExtractionRules="@xml/data_extraction_rules">
        <activity android:name="dev.icedamericano.salapify.MainActivity"
            android:exported="true"/>
        <receiver android:name="dev.icedamericano.salapify.YourNumberWidget"
            android:exported="true"/>
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false"/>
        <provider
            android:name="androidx.core.content.FileProvider"
            android:exported="false"/>
    </application>
</manifest>
''';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('salapify_manifest'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult check(String manifest) {
    final f = File('${tmp.path}/AndroidManifest.xml')
      ..writeAsStringSync(manifest);
    return Process.runSync('bash', [_script, f.path]);
  }

  test('the script the workflow calls actually exists', () {
    expect(
      File(_script).existsSync(),
      isTrue,
      reason: 'the merged-manifest check script is missing; CI would pass by '
          'calling nothing.',
    );
  });

  test('a manifest matching the allowlist passes', () {
    final r = check(_goodManifest);
    expect(
      r.exitCode,
      0,
      reason: 'the allowlisted manifest was rejected:\n${r.stdout}',
    );
    expect(r.stdout, contains('MANIFEST CHECK PASSED'));
  });

  test('a missing manifest fails, never a silent pass', () {
    final r = Process.runSync('bash', [_script, '${tmp.path}/nope.xml']);
    expect(r.exitCode, isNot(0));
  });

  test('an unexpected permission fails and is named', () {
    final r = check(
      _goodManifest.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.CAMERA"/>\n    <application',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout, contains('CAMERA'));
  });

  test('a non-android.permission (OEM/custom) permission is also caught', () {
    // The security audit found the first cut only inspected the
    // android.permission.* namespace, so an OEM or custom permission a
    // dependency merges in slipped through unchecked. This proves the fix: a
    // vendor badge permission must fail just like any other.
    final r = check(
      _goodManifest.replaceFirst(
        '<application',
        '<uses-permission android:name="com.sec.android.provider.badge.permission.WRITE"/>\n    <application',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout, contains('com.sec.android.provider.badge.permission.WRITE'));
  });

  test('a rogue exported component fails', () {
    final r = check(
      _goodManifest.replaceFirst(
        '<provider\n            android:name="androidx.core.content.FileProvider"\n            android:exported="false"/>',
        '<receiver android:name="com.evil.Exfiltrator" android:exported="true"/>',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout, contains('Exfiltrator'));
  });

  test('allowBackup turned back on fails', () {
    final r = check(
      _goodManifest.replaceAll(
        'android:allowBackup="false"',
        'android:allowBackup="true"',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout.toString().toLowerCase(), contains('backup'));
  });

  test('a dropped backup-rules attribute fails', () {
    final r = check(
      _goodManifest.replaceAll(
        'android:dataExtractionRules="@xml/data_extraction_rules"',
        '',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout, contains('dataExtractionRules'));
  });

  test('cleartext traffic enabled fails', () {
    final r = check(
      _goodManifest.replaceFirst(
        'android:allowBackup="false"',
        'android:allowBackup="false" android:usesCleartextTraffic="true"',
      ),
    );
    expect(r.exitCode, isNot(0));
    expect(r.stdout.toString().toLowerCase(), contains('cleartext'));
  });
}
