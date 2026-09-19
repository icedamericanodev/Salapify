// The two dependencies the paged reader takes from OUTSIDE itself, and what
// happens when nobody supplies them.
//
// This file exists because of a defect the f3.57 retrospective reproduced on
// shipped code. Phase 3 moved two decisions from inside the reader out to its
// call site in learn.dart, and neither absence is loud:
//
//   interaction_block_views.dart:  resolveRoute: resolveSalapifyRoute ?? (_) => null
//   lesson_finish_card.dart:       if (next != null && onOpenLesson != null) ...
//
// So deleting the wiring in learn.dart removes a working button from the
// phone and leaves the whole suite green. Both deletions were run on shipped
// code: the route one passed 2,623 tests, the next-lesson one passed all nine
// reader and Learn test files. Nothing anywhere referenced
// `resolveSalapifyRoute` in a test.
//
// A dependency whose absent value is a DEGRADED APP rather than an error is
// invisible by construction, and no amount of care at the call site fixes
// that. The two halves are guarded differently, on purpose:
//
//   ROUTES are now unrepresentably-missing. PagedLessonReader resolves them
//   itself when nobody supplies one, which is what the scrolling reader
//   always did inline. The test below builds a reader with NO resolver, the
//   exact case that used to produce dead text, and drives it.
//
//   onOpenLesson cannot be defaulted internally: it has to push a screen and
//   the reader must not import screens. So it is checked at the app's own
//   call site, by opening a lesson the way a person does and asserting the
//   reader was handed one. That is a WIRING check, not a click-through, and
//   it is written that way deliberately: every expansion lesson gates its
//   later steps behind a required exercise, so a walk-to-the-finish-card test
//   would have to satisfy each lesson's own exercise and would then break
//   whenever an author edited one. This check cannot tell you the button
//   looks right. It can tell you the button exists at all, which is exactly
//   what was silently deleted.
//
// Both were proven to fail before they were trusted. The failure lines are in
// the commit message that introduced this file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/goals.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A two block lesson: one paragraph, then one actions block, and NO required
/// exercise anywhere.
///
/// Synthetic on purpose. Every real expansion lesson gates its actions step
/// behind a required exercise, so a test using real content would spend most
/// of its length satisfying whichever exercise that lesson happens to author
/// and would fail on an edit that has nothing to do with route wiring. What
/// is being proven here is a property of the READER, so the lesson should be
/// the smallest thing that exercises it.
const _actionLabel = 'Open goals from a lesson';

const _lesson = MoneyLesson(
  id: 'wiring-fixture',
  trackId: 'investing_readiness',
  title: 'Route wiring fixture',
  icon: 'checklist',
  minutes: 1,
  summary: 'A fixture lesson with one action and no gate.',
  objective: 'Prove the reader resolves its own routes.',
  sections: [],
  authoredBlocks: [
    ProseBlock(
      heading: 'A first step',
      paragraphs: ['One short paragraph so the reader has a step to start on.'],
    ),
  ],
  interactionBlocks: [
    SalapifyActionsBlock(
      blockId: 'wiring-actions',
      menuPrompt: 'One real thing to do next.',
      actions: [
        SalapifyActionDef(
          id: 'open-goals',
          label: _actionLabel,
          description: 'Opens Goals. Nothing changes automatically.',
          route: 'goals',
        ),
      ],
    ),
  ],
);

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Presses the advance button until [target] appears or the reader runs out.
///
/// The last advance is labelled "Finish", not "Continue". A loop that only
/// knows the one word stops one step short of the finish card.
Future<bool> _advanceUntil(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40; i++) {
    if (target.evaluate().isNotEmpty) return true;
    var next = find.widgetWithText(FilledButton, 'Continue');
    if (next.evaluate().isEmpty) {
      next = find.widgetWithText(FilledButton, 'Finish');
    }
    if (next.evaluate().isEmpty) break;
    // A required exercise disables its own step's button. Report that rather
    // than spinning forty times against a control that will never enable.
    if (tester.widget<FilledButton>(next).onPressed == null) break;
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
  return target.evaluate().isNotEmpty;
}

void main() {
  testWidgets('a reader given no route resolver still opens the real screen', (
    tester,
  ) async {
    // The case that used to render every action as PLAIN TEXT. Nothing
    // crashed and nothing looked obviously broken, the button simply was not
    // a button, which is why it survived a green suite.
    final store = await _freshStore();
    _phone(tester);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: PagedLessonReader(
          pathId: 'grow_your_money',
          lesson: _lesson,
          store: store,
          // Deliberately absent. That is the whole test.
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await _advanceUntil(tester, find.text(_actionLabel)),
      isTrue,
      reason: 'never reached the actions step',
    );

    // "Open" is the button SalapifyActionsView builds only when the route
    // resolved to something. An unresolved action has a label and no button.
    final open = find.widgetWithText(OutlinedButton, 'Open');
    expect(
      open,
      findsOneWidget,
      reason:
          'the action rendered as text with no button, which is exactly what '
          'a null route resolver produces',
    );

    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsScreen), findsOneWidget);
  });

  testWidgets('the hub hands the reader a way to open the next lesson', (
    tester,
  ) async {
    // Deleting the onOpenLesson block in learn.dart re-creates the dead end
    // that f3.54 shipped a whole finish card to fix, and does it silently:
    // the finish card just stops drawing its Next button.
    final store = await _freshStore();
    _phone(tester);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: LearnScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    final growCard = find.ancestor(
      of: find.text('Grow Your Money'),
      matching: find.byType(Card),
    );
    final allCourses = find.descendant(
      of: growCard,
      matching: find.widgetWithText(TextButton, 'All courses'),
    );
    // scrollUntilVisible stops once the widget is BUILT, which on a lazy list
    // is not the same as being inside the viewport: it reported success at
    // y=923 on an 844 tall frame and the tap then missed the render tree.
    // ensureVisible is what actually brings it on screen.
    await tester.scrollUntilVisible(
      allCourses,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(allCourses);
    await tester.pumpAndSettle();
    await tester.tap(allCourses);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Are You Ready to Invest?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give Your Money a Job'));
    await tester.pumpAndSettle();

    final reader = tester.widget<PagedLessonReader>(
      find.byType(PagedLessonReader),
    );
    expect(
      reader.onOpenLesson,
      isNotNull,
      reason:
          'the hub opened a lesson without giving the reader any way to open '
          'the next one, so the finish card will draw no Next button',
    );
  });
}
