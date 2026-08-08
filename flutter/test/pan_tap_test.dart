// Pan is a control, so he has to behave like one.
//
// He reacted to the user's money from the day he was drawn, and did nothing
// at all when they reached for him. A character who responds to your finances
// but ignores your finger teaches, in one tap, that he is scenery.
//
// Two halves are pinned here and the second matters as much as the first:
//
// 1. Tapping him opens Ask Pan.
// 2. He is ANNOUNCED. Pan was deliberately hidden from the screen reader
//    while he was decoration, which was right: an image repeating what the
//    card already says is noise. The moment he became tappable that reversed.
//    An interactive target that announces nothing is a control a blind user
//    cannot find, cannot reach, and has no way to know exists. Making
//    something tappable without making it findable is a regression dressed as
//    a feature.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/screens/utang.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<SalapifyStore> _storeWithSomeMoney() async {
  // A real decision (an overdue utang) so the check-in renders the FULL Pan
  // card. The calm all-clear became a slim row without Pan in the Phase 3
  // calmer-Home pass, so Pan's tap contract is pinned on the state where he
  // actually appears.
  final overdue = DateTime.now().subtract(const Duration(days: 20));
  final iso =
      '${overdue.year.toString().padLeft(4, '0')}-${overdue.month.toString().padLeft(2, '0')}-${overdue.day.toString().padLeft(2, '0')}';
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      ],
      'transactions': <Map<String, dynamic>>[],
      'receivables': [
        {
          'id': 'r1',
          'person': 'Ana',
          'amount': 1000,
          'dueDate': iso,
          'paid': false,
        },
      ],
    }),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  testWidgets('tapping Pan on Home opens Ask Pan', (tester) async {
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(OverviewScreen(store: store, onSwitchTab: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    final pan = find.byType(PanMascot);
    if (pan.evaluate().isEmpty) {
      // No check-in card in this state, so there is no Pan to tap. Say so
      // rather than passing silently on a screen that never rendered him.
      fail('Pan did not render on Home, so this test proved nothing.');
    }

    await tester.tap(pan.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      find.byType(PanScreen),
      findsOneWidget,
      reason:
          'Tapping Pan did nothing. He reacts to the money and ignores the '
          'finger, which teaches in one tap that he is scenery.',
    );
  });

  testWidgets('Pan is announced as a button once he is tappable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(OverviewScreen(store: store, onSwitchTab: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Ask Pan'),
      findsOneWidget,
      reason:
          'Pan is tappable but announces nothing, so a screen reader user '
          'cannot find him or know he exists. Tappable without findable is a '
          'regression dressed as a feature.',
    );
    handle.dispose();
  });

  testWidgets('Pan greets a new user on the empty tab screens', (tester) async {
    // The narrow rule: Pan appears on the empty state of a TAB, because that
    // is where a brand new user meets the app with nothing else on screen to
    // build any warmth. He must NOT appear on a filtered empty state, which
    // is a search result rather than a first meeting. A character on every
    // blank surface is wallpaper, and wallpaper is invisible within a day.
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(UtangScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(PanMascot),
      findsOneWidget,
      reason:
          'the empty Utang tab is a first meeting, and it showed only an icon',
    );
  });

  testWidgets('Pan stays away from a filtered empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await store.addEntry({
      'type': 'expense',
      'amount': 99.0,
      'category': 'Food',
      'date': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(HistoryScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    // Filter to something that matches nothing, which is the "no entries
    // match" state rather than the first-meeting state.
    await tester.enterText(find.byType(TextField).first, 'zzzznothingmatches');
    await tester.pumpAndSettle();

    expect(
      find.text('No entries match'),
      findsOneWidget,
      reason: 'the filtered empty state should be showing',
    );
    expect(
      find.byType(PanMascot),
      findsNothing,
      reason:
          'a failed search is not a first meeting. Pan on every blank surface '
          'is wallpaper, and wallpaper stops being noticed within a day.',
    );
  });
}
