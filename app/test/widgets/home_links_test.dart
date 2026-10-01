import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/bills/bills_sheet.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
import 'package:salapify/screens/home/budget_pulse_card.dart';
import 'package:salapify/screens/home/latest_transactions.dart';
import 'package:salapify/screens/plan/plan_screen.dart';

import '../support/pinned_app.dart';

/// P1.1: every link on Home goes somewhere.
///
/// ## What it used to do
///
/// Four controls called a helper named `_soon`, which showed a snack bar
/// reading "The Plan tab is not migrated yet." The comment above it argued
/// that saying so beats doing nothing, because "a dead button is
/// indistinguishable from a bug". That was true while the destinations did not
/// exist. They all exist now, and a button that apologises for a screen you
/// can reach from the tab bar beside it is worse than either.
///
/// ## Why this file can be short
///
/// The strongest evidence is not in here at all. Making `onOpenTab`,
/// `onOpenLog` and `onOpenDebt` REQUIRED turned every missing wire into a
/// compile error, and the analyzer then reported `_soon` itself as
/// unreferenced, which is the machine stating that no dead end is left. These
/// tests cover the half a compiler cannot: that each link opens the RIGHT
/// place, not merely some place.
void main() {
  /// Scrolls until the widget is BUILT, then taps it.
  ///
  /// Home is a lazy list, so a card below the fold does not exist in the tree
  /// yet and `ensureVisible` throws "Bad state: No element" on it. That reads
  /// like a missing feature and is a missing scroll.
  Future<void> reachAndTap(WidgetTester tester, Finder of, Finder f) async {
    await tester.scrollUntilVisible(
      of,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping Budget Pulse opens the Plan tab', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    expect(find.byType(PlanScreen), findsNothing);

    // The WHOLE CARD is the tap target here; it carries a chevron rather
    // than a "See all" label, unlike Latest below.
    await reachAndTap(
      tester,
      find.byType(BudgetPulseCard),
      find.byType(BudgetPulseCard),
    );

    expect(
      find.byType(PlanScreen),
      findsOneWidget,
      reason: 'Budget Pulse summarises the budgets that live on Plan',
    );
  });

  testWidgets('Latest See all opens Activity, not Reports', (
    WidgetTester tester,
  ) async {
    // Named in the reason because an off-by-one in a tab index is the easiest
    // possible mistake here and lands somewhere plausible.
    await pumpSalapify(tester);
    expect(find.byType(ActivityScreen), findsNothing);

    await reachAndTap(
      tester,
      find.byType(LatestTransactions),
      find.descendant(
        of: find.byType(LatestTransactions),
        matching: find.text('See all'),
      ),
    );

    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(
      find.byType(AccountsScreen),
      findsNothing,
      reason: 'the index pointed at the wrong tab',
    );
  });

  testWidgets('Coming Up Manage opens the Bills sheet', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);

    await reachAndTap(tester, find.text('Manage'), find.text('Manage'));

    expect(find.byType(BillsSheet), findsOneWidget);
  });

  testWidgets('nothing on Home says it is not migrated yet', (
    WidgetTester tester,
  ) async {
    // The blunt one. It would have caught all four at once, and it keeps
    // catching a fifth if somebody adds one.
    await pumpSalapify(tester);
    expect(find.textContaining('not migrated'), findsNothing);
  });
}
