// Does the tile's Log button actually log?
//
// The widget picker description promising "a one tap Log button" is frozen in
// res/values/strings.xml. It cannot be edited over the air. So the promise has
// to be true from the first install, and it was not: the tap was parked in a
// static field whose only reader ran in ShellScreen.initState, and the shell
// is built inside a ListenableBuilder with no key, so its Element is reused on
// every store change and initState never runs a second time.
//
// The practical shape of that: it worked exactly once per app process. Open
// Salapify, press Home, tap the tile. The app comes forward on whatever tab
// you left it on and nothing happens. Forever.
//
// Worse, the tap did not vanish. It sat in memory until the NEXT shell mount,
// which on a fresh install is the moment onboarding finishes, and then fired
// on top of the first-log sheet. Two stacked log sheets on somebody's first
// minute in the app.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart' show SalapifyApp;
import 'package:salapify/services/home_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    HomeTile.pendingUri = null;
    HomeTile.onLogTap = null;
  });

  Future<void> boot(WidgetTester tester, Map<String, dynamic> blob) async {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> onboarded() => {
    'schemaVersion': 12,
    'settings': {'onboarded': true},
  };

  int sheets() => find.byType(BottomSheet).evaluate().length;

  testWidgets('a tap on a RUNNING app opens the log sheet', (tester) async {
    // The warm launch, which is most launches. The app is alive, the tap
    // arrives through the plugin's stream, and something has to act on it
    // right then, because no initState is ever going to run again.
    await boot(tester, onboarded());
    expect(sheets(), 0, reason: 'a sheet was already open before the tap');

    HomeTile.deliver('salapify://log');
    await tester.pumpAndSettle();

    expect(sheets(), 1, reason: 'the one tap Log button did nothing');
    expect(
      HomeTile.pendingUri,
      isNull,
      reason: 'a served tap stayed parked and will fire again later',
    );
  });

  testWidgets('two taps in a row do not stack two sheets', (tester) async {
    await boot(tester, onboarded());
    HomeTile.deliver('salapify://log');
    await tester.pumpAndSettle();
    HomeTile.deliver('salapify://log');
    await tester.pumpAndSettle();
    expect(sheets(), 1, reason: 'a second sheet opened behind the first');
  });

  testWidgets('a plain tile tap opens the app and no sheet', (tester) async {
    // The tile has two tap targets. Only one of them logs.
    await boot(tester, onboarded());
    HomeTile.deliver('salapify://home');
    await tester.pumpAndSettle();
    expect(sheets(), 0);
  });

  testWidgets('a tap that arrives before the app is ready is served once', (
    tester,
  ) async {
    // The cold launch. The tap lands while the store is still loading, before
    // any shell exists, so it MUST be parked. Then it must be served exactly
    // once, and it must not still be sitting there afterwards.
    HomeTile.deliver('salapify://log');
    expect(HomeTile.pendingUri, isNotNull, reason: 'a cold tap was dropped');
    await boot(tester, onboarded());
    expect(sheets(), 1, reason: 'the parked tap was never served');
    expect(HomeTile.pendingUri, isNull);
  });

  testWidgets('a tap parked during onboarding never doubles the first sheet', (
    tester,
  ) async {
    // The nastiest version. Fresh install: drag the tile out, tap its Log bar
    // (Kotlin's yn_bar_tap fallback is "1", so the bar is a log intent before
    // the app has ever run), land in onboarding. The tap parks. Finish
    // onboarding, the shell mounts, and the first-log prompt opens a sheet.
    // The parked tap then opens a SECOND one underneath it.
    await boot(tester, {
      'schemaVersion': 12,
      'settings': {'onboarded': true, 'firstLogPrompt': true},
    });
    HomeTile.pendingUri = 'salapify://log';

    // Remount the shell the way finishing onboarding does.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true, 'firstLogPrompt': true},
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    expect(
      sheets(),
      1,
      reason: 'the welcome sheet and a minutes-old widget tap both fired',
    );
    expect(HomeTile.pendingUri, isNull);
  });

  testWidgets('a tap the shell cannot serve is dropped, not left to detonate', (
    tester,
  ) async {
    // A failed read. The shell refuses to open a sheet over a store that
    // cannot be written, which is correct. What was wrong is that it returned
    // BEFORE clearing the tap, so the tap survived to the next mount.
    SharedPreferences.setMockInitialValues({storageKey: '{ not json'});
    final store = SalapifyStore();
    HomeTile.pendingUri = 'salapify://log';
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(store.canWrite, isFalse, reason: 'the fixture did not break it');
    expect(sheets(), 0, reason: 'a sheet opened over an unwritable store');
    expect(
      HomeTile.pendingUri,
      isNull,
      reason: 'the tap is still queued for whenever the shell next mounts',
    );
  });

  testWidgets('the handler is released when the shell goes away', (
    tester,
  ) async {
    // Otherwise a tap after the shell is torn down calls into a dead State,
    // and the mounted check inside it is the only thing between that and a
    // crash on somebody's phone.
    await boot(tester, onboarded());
    expect(HomeTile.onLogTap, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(HomeTile.onLogTap, isNull, reason: 'a dangling handler survived');
  });
}
