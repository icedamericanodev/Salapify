// The Learn flow: open from Tools, read a lesson, and see it marked done with
// the progress count going up. The lesson content is locked separately in
// lessons_golden_test; this covers the screen and the read-tracking write.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

// The headline now counts the WHOLE catalog, core plus every published
// path, by the founder's decision on audit finding H2. It used to count the
// core 22 only, which meant finishing all 18 Protect Your Future lessons
// still read "0 of 22".
int get _catalogTotal =>
    lessons.length +
    publishedLearningPaths.fold<int>(0, (a, p) => a + p.lessonIds.length);

void main() {
  testWidgets('opening does not finish a lesson; reaching the end does', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await openFromMenu(tester, 'Tools');
    await tester.scrollUntilVisible(
      find.text('Money courses'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Money courses'));
    await tester.pumpAndSettle();

    // The catalog is now four track cards, not a scroll of 22 lessons.
    expect(find.text('0 of $_catalogTotal lessons'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);
    // An empty store has no debt and little income, so the starting track is
    // recommended, with its reason visible.
    expect(
      find.textContaining('Recommended as the place to start'),
      findsOneWidget,
    );

    // Start opens the first unfinished lesson of that track.
    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing here is a guess'), findsOneWidget);

    // Backing out WITHOUT reaching the end must not count. The old screen
    // marked a lesson read the moment it opened, so the figure counted taps.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('0 of $_catalogTotal lessons'),
      findsOneWidget,
      reason: 'a lesson opened and abandoned is not a lesson learned',
    );

    // Now read it properly.
    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Finish this lesson'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish this lesson'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 of $_catalogTotal lessons'), findsOneWidget);
    // And the track button becomes Continue now that it is started.
    expect(find.text('Continue'), findsWidgets);
  });
}
