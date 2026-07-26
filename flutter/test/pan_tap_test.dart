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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _storeWithSomeMoney() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  // Enough logged that the coach produces a check-in card, which is what
  // carries Pan on Home.
  await store.addEntry({
    'type': 'expense',
    'amount': 250.0,
    'category': 'Food',
    'date': DateTime.now().toIso8601String(),
  });
  return store;
}

void main() {
  testWidgets('tapping Pan on Home opens Ask Pan', (tester) async {
    final store = await _storeWithSomeMoney();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: OverviewScreen(store: store, onSwitchTab: (_) {}),
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
        home: OverviewScreen(store: store, onSwitchTab: (_) {}),
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
}
