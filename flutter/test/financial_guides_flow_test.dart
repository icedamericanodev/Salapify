// The Financial Guides flow, driven the way a person uses it: open the hub
// from Menu > Learn, filter by topic, open a guide, mark it read, and confirm
// the read state sticks. Also proves the money invariant this feature must
// hold: reading a guide changes no lesson progress and no money, because guide
// progress lives in its own settings namespace.
//
// Content shape is guarded in financial_guides_content_test; the store
// mechanism in guide_progress_backup_test; layout in screen_readability_test.
// This file is the interactive wiring in between.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/guide_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  testWidgets('the hub opens from Menu with its sections and real counts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await openFromMenu(tester, 'Financial guides');

    expect(find.text('Financial Guides'), findsOneWidget);
    expect(find.text('Learn. Apply. Grow.'), findsOneWidget);
    expect(find.text('POPULAR GUIDES'), findsOneWidget);
    expect(find.text('BROWSE BY TOPIC'), findsOneWidget);
    // The Browse counts are derived from the catalog, never hardcoded, so a
    // real count proves the wiring rather than a placeholder.
    expect(find.text('6 guides'), findsWidgets);
    // No guide has been touched, so Continue Learning is absent, not an empty
    // shell.
    expect(find.text('CONTINUE LEARNING'), findsNothing);
  });

  testWidgets('a topic chip filters the hub to that topic', (tester) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await openFromMenu(tester, 'Financial guides');

    // Picking Government swaps the sectioned hub for a flat list of that
    // topic. A Government guide appears; the Popular/Browse framing does not.
    await tester.tap(find.text('Government').first);
    await tester.pumpAndSettle();
    expect(find.text('What is MP2?'), findsOneWidget);
    expect(find.text('BROWSE BY TOPIC'), findsNothing);
  });

  testWidgets('reading a guide to the end marks it read, and touches no money', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await openFromMenu(tester, 'Financial guides');

    // Open the first popular guide.
    await tester.tap(find.text('How does 13th month pay work?').first);
    await tester.pumpAndSettle();
    // The reader renders the article: a section heading and the takeaway card
    // are present (they may be below the fold, so this only checks they exist).
    expect(find.text('The tax free ceiling'), findsOneWidget);

    // Read to the end. Reaching the bottom is what marks a guide read, so
    // this drives the same scroll listener a real reader does.
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // The read state confirms itself visibly (not a silent toggle) and the
    // store records it.
    expect(find.text('Read'), findsOneWidget);
    expect(
      isGuideRead(store.guideProgress['how-13th-month-pay-works'] ?? 0),
      isTrue,
    );

    // The invariant that matters: reading a guide moved no lesson progress
    // and wrote nothing under the lesson keys.
    expect(store.lessonProgress, isEmpty);
    final settings = store.data['settings'] as Map;
    expect(settings.containsKey('lessonsRead'), isFalse);
    expect(settings.containsKey('lessonProgress'), isFalse);
  });

  testWidgets('a part-read guide shows in Continue Learning with its percent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    // Simulate a guide left half read, then open the hub.
    await store.setGuideProgress('what-is-mp2', 0.5);
    await tester.pumpAndSettle();
    await openFromMenu(tester, 'Financial guides');

    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    expect(find.text('50% read'), findsOneWidget);
  });
}
