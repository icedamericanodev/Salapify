// What the shell promises: leaving a tab and coming back leaves it as you left
// it.
//
// Before the shell, main.dart's body was a switch expression, so changing tabs
// changed the body's widget TYPE. Flutter unmounted the old screen and disposed
// its State. Everything the user had done to that screen went with it: the
// text typed into Activity's filter, the chip they had picked, and the place
// they had scrolled to. Nothing was saving those, because nothing was keeping
// them.
//
// That failure is quiet. Coming back to a tab and finding it at the top is
// indistinguishable from never having scrolled it, so it reads as forgetting
// rather than as a bug, which is precisely why it survived this long.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/insights.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Enough entries that History is comfortably taller than the viewport.
Map<String, dynamic> _seed() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 9000},
  ],
  'transactions': [
    for (var i = 0; i < 40; i++)
      {
        'id': 't$i',
        'type': i.isEven ? 'expense' : 'income',
        'label': i.isEven ? 'Jollibee $i' : 'Sweldo $i',
        'amount': 100 + i,
        'date': '2026-07-${(i % 27 + 1).toString().padLeft(2, '0')}',
        'accountId': 'cash',
      },
  ],
};

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_seed())});
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Activity keeps its search text across a tab switch', (
    tester,
  ) async {
    await _boot(tester);
    await goToTab(tester, 'Activity');

    await tester.enterText(find.byType(TextField).first, 'Jollibee');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sweldo'), findsNothing);

    await goToTab(tester, 'Budget');
    await goToTab(tester, 'Activity');

    expect(
      find.widgetWithText(TextField, 'Jollibee'),
      findsOneWidget,
      reason:
          'The typed filter was thrown away by the round trip. That is the '
          'old switch-expression behaviour: the screen was unmounted and its '
          'State disposed.',
    );
    expect(find.textContaining('Sweldo'), findsNothing);
  });

  testWidgets('Activity keeps its filter chip across a tab switch', (
    tester,
  ) async {
    await _boot(tester);
    await goToTab(tester, 'Activity');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();

    await goToTab(tester, 'Insights');
    await goToTab(tester, 'Activity');

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Income'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('a tab keeps its scroll position', (tester) async {
    await _boot(tester);
    await goToTab(tester, 'Activity');

    // .last, not .first: Activity's filter chips are a horizontal
    // SingleChildScrollView that comes earlier in the tree, and dragging that
    // vertically does nothing at all.
    final list = find.byType(Scrollable).last;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrolled = tester.widget<Scrollable>(list).controller!.offset;
    expect(scrolled, greaterThan(0));

    await goToTab(tester, 'Budget');
    await goToTab(tester, 'Activity');

    expect(
      tester
          .widget<Scrollable>(find.byType(Scrollable).last)
          .controller!
          .offset,
      closeTo(scrolled, 1),
      reason:
          'The list went back to the top. Each destination is meant to own a '
          'ScrollController through the shell, so its place survives.',
    );
  });

  testWidgets('tapping the tab you are on scrolls it back to the top', (
    tester,
  ) async {
    await _boot(tester);
    await goToTab(tester, 'Activity');
    final list = find.byType(Scrollable).last;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.widget<Scrollable>(list).controller!.offset, greaterThan(0));

    // The same destination again, which is a scroll-to-top rather than a
    // no-op. Every phone user already expects this from other apps.
    await goToTab(tester, 'Activity');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scrollable>(find.byType(Scrollable).last)
          .controller!
          .offset,
      0,
    );
  });

  testWidgets('Log is reachable from every destination', (tester) async {
    // The reason the FAB moved into the shell. It used to be on Home only,
    // which put the most frequent action in the app behind a tab change.
    await _boot(tester);
    for (final label in ['Home', 'Activity', 'Budget', 'Utang', 'Insights']) {
      await goToTab(tester, label);
      expect(
        find.widgetWithText(FloatingActionButton, 'Log'),
        findsOneWidget,
        reason: 'No Log button on $label.',
      );
    }
  });

  testWidgets('an unvisited destination is not built at startup', (
    tester,
  ) async {
    // The laziness is the point, not an implementation detail. A plain
    // IndexedStack builds every child on the first frame, which would run
    // Insights' engine calls before the user has seen Home. On a cheap Android
    // that is a cold start paid for screens nobody opened.
    // skipOffstage: false is the whole test. Every ordinary finder skips the
    // inactive children of an IndexedStack, so a plain findsNothing here would
    // pass whether Insights was never built OR built and merely hidden, which
    // are the two things this is meant to tell apart. The first version of
    // this test did exactly that and passed with laziness disabled.
    await _boot(tester);
    expect(
      find.byType(InsightsScreen, skipOffstage: false),
      findsNothing,
      reason:
          'Insights was built before it was ever opened, so every destination '
          'is being constructed at startup and its engine calls with it.',
    );

    await goToTab(tester, 'Insights');
    expect(find.byType(InsightsScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Insights'), findsWidgets);

    // And once visited it STAYS built, which is what makes the state above
    // survive.
    await goToTab(tester, 'Budget');
    expect(find.byType(InsightsScreen, skipOffstage: false), findsOneWidget);
  });
}
