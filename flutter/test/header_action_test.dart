// The header actions are raised keys, and they sit exactly on the content
// edge, on every tab.
//
// Both tests exist because a probe found both failing. The alignment one: the
// header row used Flexible plus Spacer, two flex children splitting the free
// space, so on short titles ("Budget") the title's unused share became dead
// space at the END of the row and the Menu key floated 19dp off the edge,
// while wide titles ("Activity") sat flush. Invisible with a bare glyph,
// obvious with a bordered key. The empty-Insights one: the empty state's
// header simply never passed onMenu, so a brand new user's Insights tab had
// no way into Menu at all, and Menu is the only door to 16 destinations.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<void> _boot(WidgetTester tester) async {
  // 390 logical points wide, the shot harness phone.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
}

/// Enough data that every tab has something to scroll.
Map<String, dynamic> _richBlob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
    {'id': 'bank', 'name': 'Bank', 'kind': 'bank', 'balance': 90000},
  ],
  'transactions': [
    for (var i = 1; i <= 30; i++)
      {
        'id': 't$i',
        'type': 'expense',
        'label': 'Entry $i',
        'amount': 100 + i,
        'date': '2026-07-${(i % 27 + 1).toString().padLeft(2, '0')}',
        'accountId': 'cash',
      },
  ],
  'debts': [
    for (var i = 1; i <= 6; i++)
      {
        'id': 'd$i',
        'name': 'Debt $i',
        'type': 'personal',
        'remaining': 5000 * i,
        'monthlyRate': 2,
        'minPayment': 300,
        'dueDay': 5,
      },
  ],
  'people': [
    {'id': 'p1', 'name': 'Migs'},
  ],
  'receivables': [
    for (var i = 1; i <= 8; i++)
      {
        'id': 'r$i',
        'personId': 'p1',
        'person': 'Migs',
        'amount': 500 + i,
        'payments': <Map<String, dynamic>>[],
        'paid': false,
      },
  ],
};

void main() {
  testWidgets('the Menu key sits flush with the content edge on every tab', (
    tester,
  ) async {
    await _boot(tester);
    for (final tab in ['Home', 'Activity', 'Budget', 'Utang', 'Insights']) {
      await goToTab(tester, tab);
      final key = tester.getRect(find.byTooltip('Menu').first);
      expect(
        key.right,
        390.0 - 20.0,
        reason:
            'On $tab the Menu key is not on the 20dp content edge where '
            'every card ends. A header action that floats off the shared '
            'edge reads as misplaced, and this exact drift shipped once.',
      );
      expect(key.size, const Size(48, 48));
    }
  });

  testWidgets('the Menu key survives a deep scroll on every tab', (
    tester,
  ) async {
    // The founder's call: the header pins on all five tabs, so Menu is one
    // tap away at any scroll depth. Before this, Home, Budget, and Insights
    // put the header inside the list and Menu scrolled away on exactly the
    // three longest screens.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(_richBlob()),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    for (final tab in ['Home', 'Activity', 'Budget', 'Utang', 'Insights']) {
      await goToTab(tester, tab);
      final before = tester.getRect(find.byTooltip('Menu').first);
      // Drag the active tab's list well past a screenful. The finder skips
      // offstage trees, so .first is the visible tab's scrollable.
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(
        find.byTooltip('Menu'),
        findsWidgets,
        reason:
            'On $tab the Menu key scrolled off screen. The header must '
            'be pinned outside the list on every tab.',
      );
      final after = tester.getRect(find.byTooltip('Menu').first);
      expect(
        after,
        before,
        reason:
            'On $tab the Menu key moved when the list scrolled. Pinned '
            'means the same rect at any depth.',
      );
    }
  });

  testWidgets('a brand new user still has Menu on the Insights tab', (
    tester,
  ) async {
    // The empty store is the point: Insights shows its empty state, and that
    // branch must carry the same header chrome as the full one.
    await _boot(tester);
    await goToTab(tester, 'Insights');
    expect(
      find.byTooltip('Menu'),
      findsOneWidget,
      reason:
          'The empty-state Insights header lost its onMenu wiring. Menu is '
          'the only way into 16 destinations, so the emptiest account had '
          'the fewest ways out of the screen.',
    );
  });
}
