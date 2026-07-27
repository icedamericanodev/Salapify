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
  await tester.tap(navDestination('Menu'));
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
