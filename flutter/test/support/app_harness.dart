// One place the widget suite navigates through.
//
// This file exists because 24 test files reached the Menu screen by tapping
// find.text('Menu'), and 30 call sites then copied the same four-line
// tap / scroll / ensureVisible / tap dance around it. Menu is moving off the
// bottom bar and into a header action, so all of that stops working at once.
//
// One function body changes here. Twenty-four files do not. That is the point.
//
// On scoping: every finder below is narrowed to the widget it means, even
// though a wider one would work today. The reason is not the IndexedStack
// migration. That worry turned out to be unfounded, and
// test/nav_ambiguity_test.dart documents why with evidence: IndexedStack ships
// its own element that visits only the selected child during the onstage walk,
// so inactive destinations never reach a default finder at all.
//
// The reason is cheaper than that. A finder scoped to the NavigationBar cannot
// be broken by a screen that happens to reuse a word, and a scroll scoped to
// the screen under test cannot quietly scroll a different one. Neither failure
// is possible today. Both are one refactor away, and neither announces itself
// when it arrives: a test scrolling the wrong screen does not report "wrong
// screen", it reports "not found".
//
// Deliberately NOT named *_test.dart, so `flutter test` never collects it, the
// same trick screens_shot.dart uses for the same reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/screens/menu.dart';

/// The bottom bar destination with this label.
///
/// Scoped to the NavigationBar, which is what makes it survive every screen
/// being mounted at once. `find.text('Budget')` is ambiguous the moment the
/// Budget screen exists in the tree with its own header; this never is.
Finder navDestination(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

/// Switch to a primary destination by its bottom bar label.
Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(navDestination(label));
  await tester.pumpAndSettle();
}

/// Open the Menu screen, however Menu is currently reached.
///
/// The whole point of this function is that its BODY is allowed to change and
/// its 24 callers are not. Today Menu is a bottom bar destination. Shortly it
/// becomes a header action, and only these three lines move.
Future<void> openMenu(WidgetTester tester) async {
  // Menu left the bottom bar and became a header action on every primary
  // screen. This is the whole payoff of the file: 24 test files reached Menu
  // through here, and moving it cost exactly these two lines.
  //
  // byTooltip, because the action is an icon with no visible text. The tooltip
  // is also the screen reader's only label for it, so a finder that stops
  // working here means a real accessibility regression, not just a broken test.
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

/// Scroll [target] into view, searching only inside [scope].
///
/// [scope] is not optional politeness. With every destination mounted, an
/// unscoped scrollable finder picks Home and scrolls that instead, forever, in
/// silence.
Future<void> scrollTo(
  WidgetTester tester,
  Finder target, {
  required Finder scope,
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find
        .descendant(of: scope, matching: find.byType(Scrollable))
        .first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// Open Menu, find a destination on it, and tap it.
///
/// This replaces the tap / scrollUntilVisible / ensureVisible / tap quadruple
/// that was copied into 24 files, each with its own slightly different spelling.
Future<void> openFromMenu(
  WidgetTester tester,
  String label, {
  double delta = 200,
}) async {
  await openMenu(tester);
  final target = find.text(label);
  await scrollTo(tester, target, scope: find.byType(MenuScreen), delta: delta);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Mount a primary destination the way the shell mounts it: as a body inside a
/// Scaffold.
///
/// The five destinations stopped returning their own Scaffold when the shell
/// took ownership of the one Scaffold, the nav bar and the Log button. That is
/// the right shape for the app and it changes the contract for tests: a screen
/// pumped as a bare `home:` now has no Material ancestor, and anything Material
/// inside it (a ChoiceChip, a TextField's fill) asserts.
///
/// The failure is loud and the message is good ("No Material widget found"), so
/// this is a nuisance rather than a hazard. It gets a helper anyway, so the next
/// person adding a screen test copies the right thing.
Widget tabHost(Widget destination) => Scaffold(body: destination);

/// Expand a folded Insights tool by its launcher line and settle.
///
/// The tools band renders each tool as a one-line launcher since Phase 2
/// batch 5; a test that asserts on tool CONTENT comes through here first.
/// Launcher titles: 'Can you afford it?', 'A lump sum is landing?',
/// 'What if you paid a little extra', 'What if you saved each week'.
Future<void> openInsightsTool(WidgetTester tester, String title) async {
  final launcher = find.text(title);
  await tester.scrollUntilVisible(
    launcher,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(launcher);
  await tester.pumpAndSettle();
}

/// Open the Utang tab on its "Owed to me" segment.
///
/// The tab merged with Debts and now opens on "I owe" (the founder's call:
/// what you owe is the more pressing half). Tests that assert on receivables
/// content (STILL OUT, a person's name) come through here, so the next change
/// to the segment control is one edit rather than a hunt.
Future<void> goToOwedToMe(WidgetTester tester) async {
  await goToTab(tester, 'Utang');
  await tester.tap(find.text('Owed to me'));
  await tester.pumpAndSettle();
}
