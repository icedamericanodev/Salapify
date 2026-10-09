import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What Android may copy off this phone, read from the rule file itself.
///
/// Founder decisions, 2026-10-09: setting up a new phone by copying directly
/// from the old one brings the records across, and app lock stays behind.
/// Until that day the rule copied only files/, the ledger lives in
/// app_flutter/, and the privacy sheet promised a copy that never happened.
/// Nothing on a phone would ever have said so, which is why this reads the
/// file rather than trusting a comment in it.
void main() {
  final String rules = File(
    'android/app/src/main/res/xml/data_extraction_rules.xml',
  ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  String section(String tag) =>
      RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(rules)!.group(1)!;

  test('nothing goes to the cloud', () {
    final String cloud = section('cloud-backup');
    expect(cloud, isNot(contains('<include')));
    for (final String domain in <String>['root', 'file', 'sharedpref']) {
      expect(cloud, contains('<exclude domain="$domain" />'));
    }
  });

  test('a phone to phone copy carries the records', () {
    expect(
      section('device-transfer'),
      contains('<include domain="root" path="app_flutter/" />'),
      reason:
          'the ledger is in app_flutter/ (getApplicationDocumentsDirectory '
          'on Android), and nothing copies it to the new phone',
    );
  });

  test('and leaves app lock behind, by its real file name', () {
    // Read from the code, so renaming the file cannot quietly start
    // carrying it.
    final String lockCode = File(
      'lib/features/lock/app_lock.dart',
    ).readAsStringSync();
    final String name = RegExp(
      r"'\$\{dir\.path\}/([a-z_]+\.json)'",
    ).firstMatch(lockCode)!.group(1)!;
    expect(name, 'app_lock.json');

    final String d2d = section('device-transfer');
    expect(
      d2d,
      contains('<exclude domain="root" path="app_flutter/$name" />'),
      reason: 'app lock would arrive switched on, on a phone it never asked',
    );
    expect(
      d2d,
      contains('<exclude domain="root" path="app_flutter/$name.tmp" />'),
    );
  });
}
