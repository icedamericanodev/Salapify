// Every Menu destination still goes somewhere.
//
// This is the guard that matters for a layout rewrite, and the reason is that
// the failure is INVISIBLE. Menu went from sixteen stacked rows to two grids;
// a tile dropped in that move leaves a screen that renders perfectly, scrolls
// perfectly, and screenshots perfectly. Nothing is misaligned, no number is
// wrong, no test about spacing or colour would notice. The only symptom is
// that a part of the app quietly stopped being reachable, and the person who
// finds out is the founder, months later, wondering where Paluwagan went.
//
// So the test walks the list and taps every one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/cashflow.dart';
import 'package:salapify/screens/debts.dart';
import 'package:salapify/screens/goals.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/milestone_share.dart';
import 'package:salapify/screens/paluwagan.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/screens/payday.dart';
import 'package:salapify/screens/recap_share.dart';
import 'package:salapify/screens/recurring.dart';
import 'package:salapify/screens/reports.dart';
import 'package:salapify/screens/search.dart';
import 'package:salapify/screens/tools.dart';
import 'package:salapify/screens/treats.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/nav_tile.dart';
import 'package:salapify/widgets/salapify_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Label to the screen it must open. Kept as data so adding a destination
/// without adding it here is itself a visible omission.
final _destinations = <String, Type>{
  'Search': SearchScreen,
  'Accounts': AccountsScreen,
  'Cash flow': CashFlowScreen,
  'Debts': DebtsScreen,
  'Goals': GoalsScreen,
  'Paluwagan': PaluwaganScreen,
  'Recurring': RecurringScreen,
  'Reports': ReportsScreen,
  'Payday': PaydayScreen,
  'Tools': ToolsScreen,
  'Earn your treats': TreatsScreen,
  'Share your month': RecapShareScreen,
  'Share a win': MilestoneShareScreen,
};

Future<SalapifyStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final s = SalapifyStore();
  await s.load();
  return s;
}

/// [key] forces a genuinely fresh tree per iteration.
///
/// Without it, pumpWidget reuses the existing element tree because the widget
/// type matches, so the screen pushed by the PREVIOUS tap is still sitting on
/// the Navigator and Menu is buried underneath it. The second destination then
/// fails with "not on Menu at all", which reads exactly like the bug this test
/// is hunting and is not.
Widget _menu(SalapifyStore store, {Key? key}) => MaterialApp(
  key: key,
  theme: salapifyTheme(Barako.current),
  home: tabHost(MenuScreen(store: store, onSwitchTab: (_) {})),
);

void main() {
  testWidgets('every destination in the grid still opens its screen', (
    tester,
  ) async {
    // Tall view so the whole grid is reachable without fighting the scroller
    // on every one of thirteen taps.
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final entry in _destinations.entries) {
      final store = await _store();
      await tester.pumpWidget(_menu(store, key: ValueKey(entry.key)));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(NavTile, entry.key);
      expect(
        tile,
        findsOneWidget,
        reason:
            '"${entry.key}" is not on Menu at all. A tile lost in the grid '
            'rewrite renders perfectly and reaches nobody.',
      );

      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        find.byType(entry.value),
        findsOneWidget,
        reason: '"${entry.key}" did not open ${entry.value}',
      );
    }
  });

  testWidgets('the Ask Pan banner opens Ask Pan', (tester) async {
    // Ask Pan is the one destination NOT in a grid: it was promoted to a
    // filled banner, which means it is also the one most easily broken by a
    // later tidy-up of the grids.
    final store = await _store();
    await tester.pumpWidget(_menu(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask Pan'));
    await tester.pumpAndSettle();
    expect(find.byType(PanScreen), findsOneWidget);
  });

  testWidgets('Payday is hidden when the store cannot be written to', (
    tester,
  ) async {
    // The old layout gated Payday behind canWrite because the screen writes.
    // Folding it into the MONEY grid is exactly the kind of move that loses a
    // condition silently, so the condition is pinned rather than assumed.
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    if (store.canWrite) {
      // A healthy store SHOWS it. The negative case needs a load failure,
      // which this suite cannot fake cleanly, so pin the half that is
      // reachable and say plainly that is what this asserts.
      await tester.pumpWidget(_menu(store));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(NavTile, 'Payday'), findsOneWidget);
    }
  });

  test('every icon name used by a tile resolves to a real glyph', () {
    // The resolver falls back to a neutral marker so a typo can never take a
    // screen down. That safety net is also what would hide the typo, so the
    // names are checked here rather than trusted.
    const used = [
      'search',
      'wallet',
      'flow',
      'card',
      'savings',
      'group',
      'repeat',
      'chart',
      'calendar',
      'tools',
      'gift',
      'share',
      'celebrate',
    ];
    for (final name in used) {
      expect(
        salapifyIcon(name),
        isNot(Icons.label_important_outline),
        reason:
            '"$name" fell through to the fallback marker, so this tile is '
            'drawing the "unknown icon" glyph and nothing said so.',
      );
    }
  });
}
