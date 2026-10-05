import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The release build must never go back to the debug key.
///
/// ## Why a test rather than a comment
///
/// `release` signed with `signingConfigs.getByName("debug")` for the whole of
/// `app/`'s life, under a `TODO` saying to fix it. A TODO is not a mechanism:
/// it had been read many times by then, including during three expert reviews
/// of the delivery pipeline, and the line survived all of them until somebody
/// asked what happens on the SECOND base APK.
///
/// What happens is the worst shape a defect can have. The Android debug
/// keystore is generated per machine, so a CI runner signs every run with a
/// different key. Android refuses to install an update whose signature differs
/// from the installed app's, and its only route out is uninstall, which
/// deletes the app's whole data directory. The FIRST install works perfectly.
/// The bill arrives at the first native change, weeks of records later.
///
/// Nothing else in the repository can see this. It is not a Dart symbol, so
/// the analyzer is blind to it. It does not change any widget, so no render
/// shows it. A debug-signed APK builds, installs and runs correctly, so even
/// `flutter build apk` passing proves nothing. The only moment it is
/// observable is the moment it is already too late.
void main() {
  late String gradle;

  setUpAll(() {
    final File f = File('android/app/build.gradle.kts');
    expect(
      f.existsSync(),
      isTrue,
      reason: 'android/app/build.gradle.kts moved, so this guard is reading '
          'nothing. Point it at the new path rather than deleting it.',
    );
    gradle = f.readAsStringSync();
  });

  test('the release build is signed with the preview key', () {
    expect(
      gradle,
      contains('signingConfigs.getByName("preview")'),
      reason: 'release must sign with the committed preview key, or two base '
          'APKs cannot install over each other',
    );
  });

  test('the release build is NOT signed with the debug key', () {
    // Deliberately a search for the debug config ANYWHERE in the file rather
    // than a parse of the release block. There is no legitimate reason for
    // this app to name the debug signing config at all, and a loose check
    // that cannot be satisfied by moving the line is worth more here than a
    // precise one that can.
    expect(
      gradle,
      isNot(contains('signingConfigs.getByName("debug")')),
      reason: 'a debug keystore is generated per machine, so two CI builds '
          'carry two different signatures and the second cannot install over '
          'the first. The only way out is an uninstall, which deletes '
          'everything the person has entered.',
    );
  });

  test('the preview keystore is actually present', () {
    // The config can be perfect and the file absent, which fails at build
    // time on a runner rather than here. It is committed through a single
    // named exception in android/.gitignore, and an exception spelled out in
    // full is exactly the kind of thing a later cleanup deletes.
    expect(
      File('android/app/preview-keystore.jks').existsSync(),
      isTrue,
      reason: 'android/app/preview-keystore.jks is missing. It is committed '
          'on purpose through the "!app/preview-keystore.jks" line in '
          'android/.gitignore.',
    );
  });

  test('no SECOND keystore has appeared beside it', () {
    // The blanket ban on *.jks in android/.gitignore is what stops a real
    // Play upload key being committed in a hurry, and it is carried by a
    // single narrow negation. If somebody widens that negation to a pattern,
    // the next key lands silently. One file is allowed. Any other is a
    // finding, not a convenience.
    final List<String> keystores = Directory('android')
        .listSync(recursive: true)
        .whereType<File>()
        .map((File f) => f.path.replaceAll(r'\', '/'))
        .where(
          (String p) =>
              p.endsWith('.jks') ||
              p.endsWith('.keystore') ||
              p.endsWith('key.properties'),
        )
        .toList()
      ..sort();

    expect(
      keystores,
      <String>['android/app/preview-keystore.jks'],
      reason: 'exactly one keystore belongs in this repository, the preview '
          'key. A production upload key must never be committed, and neither '
          'must a key.properties holding real passwords.',
    );
  });

  test('the file still says the preview key is not the production key', () {
    // The comment is load bearing rather than decorative. Anyone who finds a
    // committed private key and no explanation reasonably concludes it was a
    // mistake, and either deletes it, which breaks in place updates, or
    // reuses it for the store, which is far worse because the key a Play app
    // is first signed with is the key it is married to.
    expect(gradle, contains('not the Play production key'));
  });
}
