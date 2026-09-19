// The accessibility guideline suite, across the screens users actually touch.
//
// Four of Flutter's own guidelines, applied to the shell at every destination,
// to the Menu screen, and to the log sheet. Until this file, only the shared
// segmented control had ever been checked (segmented_test.dart), and writing
// THAT test taught the lesson this whole file leans on: a passing
// accessibility test is worth nothing until it has been watched failing. Its
// first version measured nothing three different ways, so every guideline here
// was run against the unfixed screens first and its failures are quoted in the
// commit that landed this file.
//
// The known offenders it caught, all fixed in the same commit:
//   menu.dart      minimumSize Size(0, 40) + shrinkWrap on the theme link
//   overview.dart  minimumSize Size(0, 36) + shrinkWrap on a welcome action
//   log_sheet.dart VisualDensity.compact on the type chips
//   history.dart   the query-clear IconButton had no tooltip, so a screen
//                  reader had nothing to say for it
//
// The seed data is deliberately RICH: every destination shows its populated
// shape, because empty states have fewer controls and a guideline over an
// empty screen certifies almost nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _rich() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 18000},
    {'id': 'bank', 'name': 'BPI', 'kind': 'bank', 'balance': 52000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 1200,
      'date': '2026-07-20',
      'accountId': 'cash',
    },
    {
      'id': 't2',
      'type': 'income',
      'label': 'Sweldo',
      'amount': 25000,
      'date': '2026-07-15',
      'accountId': 'bank',
    },
  ],
  'debts': [
    {
      'id': 'd1',
      'name': 'BPI card',
      'type': 'credit card',
      'remaining': 12000,
      'monthlyRate': 3,
      'minPayment': 500,
      'dueDay': 28,
    },
  ],
  'people': [
    {'id': 'p1', 'name': 'Migs'},
  ],
  'receivables': [
    {
      'id': 'r1',
      'personId': 'p1',
      'person': 'Migs',
      'amount': 1500,
      'payments': <Map<String, dynamic>>[],
      'paid': false,
      'dueDate': '2026-08-15',
    },
  ],
  // The floating Pan helper is turned OFF for this sweep on purpose. It is an
  // app-level, user-movable, user-dismissable overlay, not part of any screen's
  // content, and when mounted it sits over a tab's content and makes the
  // contrast guideline read an occluded label (a date behind the pill) rather
  // than the screen's own text. The helper's own accessibility (a 48 tap
  // target, its semantics label, the Chat with Pan button) is covered by
  // pan_helper_bubble_test; here we measure each screen's content.
  'settings': {'monthlyLimit': 15000, 'panHelperEnabled': false},
};

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_rich())});
  await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
  await tester.pumpAndSettle();
}

/// Every guideline in one pass over whatever is currently on screen.
Future<void> _meetsAll(WidgetTester tester, String where) async {
  final handle = tester.ensureSemantics();
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: 'androidTapTargetGuideline on $where',
  );
  await expectLater(
    tester,
    meetsGuideline(iOSTapTargetGuideline),
    reason: 'iOSTapTargetGuideline on $where',
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: 'labeledTapTargetGuideline on $where',
  );
  await expectLater(
    tester,
    meetsGuideline(textContrastGuideline),
    reason: 'textContrastGuideline on $where',
  );
  handle.dispose();
}

void main() {
  testWidgets('every bar destination meets all four guidelines', (
    tester,
  ) async {
    await _boot(tester);
    for (final label in ['Home', 'Activity', 'Insights', 'Accounts']) {
      await goToTab(tester, label);
      await _meetsAll(tester, 'the $label tab');
    }
  });

  testWidgets('the Budget screen meets all four guidelines', (tester) async {
    // Budget left the bar (founder direction, matching the mockup's four-tab
    // bar) and is a pushed screen off the Menu now. Its own guideline pass
    // still runs, just over a route instead of a resident tab.
    await _boot(tester);
    await goToTab(tester, 'Budget');
    await _meetsAll(tester, 'the Budget screen');
  });

  testWidgets('the Utang screen meets all four guidelines, both segments', (
    tester,
  ) async {
    // Utang is also a pushed screen now, opening on "I owe". Both segments get
    // checked from one push: "Owed to me" is a different screen wearing the
    // same header, and the empty-vs-rich control counts differ between them.
    await _boot(tester);
    await goToTab(tester, 'Utang');
    await _meetsAll(tester, 'the Utang screen, I owe segment');
    await tester.tap(find.text('Owed to me'));
    await tester.pumpAndSettle();
    await _meetsAll(tester, 'the Utang screen, Owed to me segment');
  });

  testWidgets('Menu meets all four guidelines, every screenful', (
    tester,
  ) async {
    // A SWEEP, not a top-and-bottom pair. The guidelines measure only what is
    // built, a lazy ListView builds only the viewport, and Menu is more than
    // three viewports long. The first version of this test certified the top
    // and then jumped to the bottom, and the proof pass caught it: a control
    // shrunk to 40 pixels in the MIDDLE band still passed, because the jump
    // scrolled straight over it and the list disposed it. Certifying a long
    // screen means certifying every screenful of it.
    await _boot(tester);
    await openMenu(tester);
    final scrollable = find
        .descendant(
          of: find.byType(MenuScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    var prev = -1.0;
    var screenful = 0;
    while (true) {
      final pixels = tester.state<ScrollableState>(scrollable).position.pixels;
      if (pixels <= prev) break;
      prev = pixels;
      await _meetsAll(tester, 'Menu, screenful $screenful');
      screenful++;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(
      screenful,
      greaterThanOrEqualTo(3),
      reason:
          'The sweep ended after $screenful screenfuls, but Menu is longer '
          'than that. If it shrank, the sweep is certifying less of the '
          'screen than it claims.',
    );
  });

  testWidgets('Activity with an active filter meets the guidelines', (
    tester,
  ) async {
    // Typing into the filter is what makes the clear button EXIST, and that
    // button had no tooltip, which is no name at all to a screen reader. A
    // suite that never types never meets the control.
    await _boot(tester);
    await goToTab(tester, 'Activity');
    await tester.enterText(find.byType(TextField).first, 'Groc');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear filter'), findsOneWidget);
    await _meetsAll(tester, 'Activity while filtering');
  });

  testWidgets('the log sheet meets all four guidelines', (tester) async {
    await _boot(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Log'));
    await tester.pumpAndSettle();
    await _meetsAll(tester, 'the log sheet');
  });

  testWidgets('the Home welcome state meets all four guidelines', (
    tester,
  ) async {
    // The empty state is the one screen every new user sees, and it is where
    // overview.dart kept a 36 pixel button. Seeded empty on purpose.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();
    await _meetsAll(tester, 'the welcome state');
    // The migration link sits at the bottom of the welcome card, where the 36
    // pixel version hid from the unscrolled pass.
    await tester.scrollUntilVisible(
      find.text('Coming from the old app? Import a backup'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await _meetsAll(tester, 'the welcome state, scrolled to the import link');
  });
}
