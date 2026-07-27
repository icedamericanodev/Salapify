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
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
}

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
