// The one native failure a Dart test can actually catch.
//
// HomeTile.providerClass must exactly equal the receiver declared in
// AndroidManifest.xml. A typo in either compiles, analyzes clean, passes every
// other test in this suite, and produces a widget that simply never updates.
// The founder would find that on their phone, and fixing it would cost another
// manual APK install, because a manifest is not patchable over the air.
//
// So this reads the real manifest off disk and compares. It is cheap, it is
// exact, and it is the only thing standing between a one character mistake and
// a wasted install.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/services/home_tile.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test(
    'the provider class Dart pushes to is the one the manifest declares',
    () {
      // The manifest uses the short form, ".YourNumberWidget", relative to the
      // package. Dart needs the qualified name, so the comparison rebuilds one
      // from the other rather than hardcoding the answer twice.
      final receiver = RegExp(
        r'<receiver\s+android:name="\.(\w+)"',
      ).firstMatch(manifest);
      expect(
        receiver,
        isNotNull,
        reason: 'no widget receiver in the manifest at all',
      );
      final declared = 'dev.icedamericano.salapify.${receiver!.group(1)}';
      expect(
        HomeTile.providerClass,
        declared,
        reason:
            'the app would push updates to a receiver that does not exist, so '
            'the tile would never change, and fixing it costs another install',
      );
    },
  );

  test('the Kotlin file for that receiver exists', () {
    final short = HomeTile.providerClass.split('.').last;
    final f = File(
      'android/app/src/main/kotlin/dev/icedamericano/salapify/$short.kt',
    );
    expect(f.existsSync(), isTrue, reason: 'no Kotlin behind the receiver');
    // It must extend the plugin's provider, or it never receives the data.
    expect(f.readAsStringSync(), contains('HomeWidgetProvider'));
  });

  test('the receiver is exported, and points at its provider info', () {
    // Not doctrine, a decision: OEM launchers have a history of only
    // honouring exported providers, and the cost of being wrong here is a
    // widget that never updates plus another manual install.
    expect(manifest, contains('android:exported="true"'));
    expect(manifest, contains('@xml/your_number_widget_info'));
  });

  test('the widget declares 4x2 both ways, and never on the lock screen', () {
    final info = File(
      'android/app/src/main/res/xml/your_number_widget_info.xml',
    ).readAsStringSync();
    // Modern launchers read the cell counts; older ones read the dp. Both
    // must be present AND must agree, or the tile lands a different size on
    // different phones. 70 * n - 30 is the cell formula.
    expect(info, contains('android:targetCellWidth="4"'));
    expect(info, contains('android:targetCellHeight="2"'));
    expect(info, contains('android:minWidth="250dp"'));
    expect(info, contains('android:minHeight="110dp"'));
    // A peso figure on a lock screen is exactly the privacy failure this
    // whole design avoids.
    expect(info, contains('android:widgetCategory="home_screen"'));
    expect(info, isNot(contains('keyguard')));
  });

  test('the layout carries the first render, not placeholders', () {
    // A tile dragged out before the app has ever run shows these strings, and
    // so does the widget picker preview. They have to be real sentences.
    final layout = File(
      'android/app/src/main/res/layout/widget_your_number.xml',
    ).readAsStringSync();
    expect(layout, contains('Open the app once'));
    expect(layout, contains('Log an expense'));
    // Every id the Kotlin sets must exist in the layout, or the update throws
    // at runtime on a phone.
    final kotlin = File(
      'android/app/src/main/kotlin/dev/icedamericano/salapify/'
      'YourNumberWidget.kt',
    ).readAsStringSync();
    for (final id in RegExp(r'R\.id\.(\w+)').allMatches(kotlin)) {
      // The CLOSING QUOTE matters. Without it, "@+id/yn_asof" matches
      // "@+id/yn_asof_typo" as a substring, so a renamed id passed happily.
      // Proven by renaming one and watching this stay green.
      expect(
        layout,
        contains('@+id/${id.group(1)}"'),
        reason: 'the Kotlin sets ${id.group(1)}, which the layout lacks',
      );
    }
  });
}
