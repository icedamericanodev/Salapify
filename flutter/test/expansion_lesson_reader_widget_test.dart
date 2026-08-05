// Widget-level checks for the Money Courses Phase 6 pilot's reader
// (widgets/expansion_lesson_reader.dart), using the real registered content
// (lib/content/lessons_grow.dart) rather than fixtures, so a change to the
// real course is what this file actually protects.
//
// Covers: opening never finishes a lesson, finishing is gated on every
// required interaction, retrying an interaction removes it from the
// completed set again, the Salapify actions confirmation flow never writes
// a financial record and never marks anything "applied" before a real
// confirm, and the reader stays usable at a narrow width and a large system
// font (real fonts loaded per repo convention, see test/screens_shot.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/goals.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

const _narrow = Size(320, 780);

Future<void> _pumpReader(
  WidgetTester tester,
  SalapifyStore store,
  String pathId,
  MoneyLesson lesson, {
  double textScale = 1.0,
  // Tall enough that a whole lesson (content blocks, every interaction,
  // the mastery check, and the finish row) renders without the ListView
  // needing to virtualize any of it away. Tests that care about a REAL
  // phone-sized viewport (overflow, narrow width) pass their own smaller
  // `size` explicitly; every other test just needs everything reachable by
  // find() without a scroll-then-tap dance whose finder indices drift as
  // the list virtualizes rows in and out while scrolling.
  Size size = const Size(390, 6000),
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: ExpansionLessonReader(
          pathId: pathId,
          lesson: lesson,
          store: store,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _runsOffTheSide(WidgetTester tester, double width) {
  final bad = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    final Offset topLeft, topRight;
    try {
      topLeft = ro.localToGlobal(Offset.zero);
      topRight = ro.localToGlobal(Offset(ro.size.width, 0));
    } catch (_) {
      continue;
    }
    final left = topLeft.dx < topRight.dx ? topLeft.dx : topRight.dx;
    final right = topLeft.dx > topRight.dx ? topLeft.dx : topRight.dx;
    if (left < -0.5 || right > width + 0.5) {
      final w = e.widget as Text;
      final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      bad.add('"$s"');
    }
  }
  return bad;
}

// The reader is a plain ListView, so content below the fold is not built
// until scrolled into view (the same reason learn_screen_test.dart scrolls
// to "Finish this lesson" rather than finding it immediately).
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  final moneyJobLesson = growYourMoneyLessons.firstWhere(
    (l) => l.id == investRefMoneyJob,
  );
  final cardLesson = growYourMoneyLessons.firstWhere(
    (l) => l.id == investRefCard,
  );

  group('opening vs finishing', () {
    testWidgets('opening a lesson records viewed, never completed', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, 'grow_your_money', moneyJobLesson);
      expect(
        store.expansionProgressFor('grow_your_money')[moneyJobLesson.id],
        LessonState.viewed,
      );
    });

    testWidgets(
      'Finish this lesson is disabled until every required interaction is done',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(tester, store, 'grow_your_money', moneyJobLesson);

        final finishButtonFinder = find.widgetWithText(
          OutlinedButton,
          'Finish this lesson',
        );
        await _scrollTo(tester, finishButtonFinder);
        expect(finishButtonFinder, findsOneWidget);
        final button = tester.widget<OutlinedButton>(finishButtonFinder);
        expect(
          button.onPressed,
          isNull,
          reason: 'required interactions are not done yet',
        );
        expect(
          store.expansionProgressFor('grow_your_money')[moneyJobLesson.id],
          isNot(LessonState.completed),
        );
      },
    );

    testWidgets(
      'answering every required interaction unlocks Finish, and tapping it marks completed',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(tester, store, 'grow_your_money', moneyJobLesson);

        // 1. Myth or fact (required).
        final mythFinder = find.text('Myth').first;
        await _scrollTo(tester, mythFinder);
        await tester.tap(mythFinder);
        await tester.pumpAndSettle();

        // 2. Categorize: assign all four goals to a bucket (required).
        // Every item's chip row offers the same three bucket labels in the
        // same order, so the Nth occurrence of "Keep accessible" is item
        // N's own chip; tapping it is enough to engage that item, whatever
        // the (later, correctness-only) feedback says. The reflection
        // block below also offers a "Keep accessible" choice, but it comes
        // after all four items in reading order, so indices 0 to 3 never
        // reach it.
        for (var i = 0; i < 4; i++) {
          final chip = find.text('Keep accessible').at(i);
          await _scrollTo(tester, chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
        }

        final finishButtonFinder = find.widgetWithText(
          OutlinedButton,
          'Finish this lesson',
        );
        await _scrollTo(tester, finishButtonFinder);
        final button = tester.widget<OutlinedButton>(finishButtonFinder);
        expect(button.onPressed, isNotNull);

        await tester.tap(finishButtonFinder);
        await tester.pumpAndSettle();
        expect(
          store.expansionProgressFor('grow_your_money')[moneyJobLesson.id],
          LessonState.completed,
        );
      },
    );
  });

  group('retry removes a completion', () {
    testWidgets('Try again on the mastery check does not block re-answering', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, 'grow_your_money', moneyJobLesson);
      // Pick the wrong answer first (index 1, per lessons_grow.dart).
      final wrongChoice = find.text(
        'Put it into a long-term investment to try to grow it before rent is due',
      );
      await _scrollTo(tester, wrongChoice);
      await tester.tap(wrongChoice);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      // Back to unanswered: the correct choice is tappable again.
      await tester.tap(
        find.text('Keep it accessible and stable, since it is needed soon'),
      );
      await tester.pumpAndSettle();
      expect(find.text('That is it.'), findsOneWidget);
    });
  });

  group('Salapify actions: confirm before anything happens', () {
    testWidgets('Cancel never navigates and never marks the lesson applied', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, 'grow_your_money', cardLesson);

      // Actions render in the order authored in lessons_grow.dart:
      // emergency fund (0), debt (1), budget (2), investment goal (3).
      // Each starts with its own "Open" button; tapping the label alone
      // does nothing, only the button does.
      final openButtons = find.widgetWithText(OutlinedButton, 'Open');
      await _scrollTo(tester, find.text('Review debt'));
      await tester.tap(openButtons.at(1));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('Nothing changes automatically'),
        findsWidgets,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        store.expansionProgressFor('grow_your_money')[cardLesson.id],
        isNot(LessonState.applied),
      );
    });

    testWidgets('Continue opens the real screen and marks the lesson applied', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, 'grow_your_money', cardLesson);

      final label = find.text('Review or create an Emergency Fund goal');
      await _scrollTo(tester, label);
      final openButtons = find.widgetWithText(OutlinedButton, 'Open');
      await tester.tap(openButtons.at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(GoalsScreen), findsOneWidget);
      expect(
        store.expansionProgressFor('grow_your_money')[cardLesson.id],
        LessonState.applied,
      );
    });

    testWidgets(
      'back navigation returns to the same lesson with progress kept',
      (tester) async {
        // Required test 12 (Phase 16): back navigation must return to the
        // same lesson and preserve progress. GoalsScreen is a normal
        // Navigator.push on top of the reader, so the reader's own State is
        // never disposed while it is open; popping back must land on the
        // exact same reader instance, still showing this action as opened.
        final store = await _freshStore();
        await _pumpReader(tester, store, 'grow_your_money', cardLesson);
        final readerState = tester.state(find.byType(ExpansionLessonReader));

        final label = find.text('Review or create an Emergency Fund goal');
        await _scrollTo(tester, label);
        final openButtons = find.widgetWithText(OutlinedButton, 'Open');
        await tester.tap(openButtons.at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(GoalsScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(GoalsScreen), findsNothing);
        expect(find.byType(ExpansionLessonReader), findsOneWidget);
        // Same State object: Flutter never rebuilt the reader from scratch,
        // so its local progress (the confirmed action) survived the trip.
        expect(
          tester.state(find.byType(ExpansionLessonReader)),
          same(readerState),
        );
        await _scrollTo(tester, find.text('Opened'));
        expect(find.text('Opened'), findsOneWidget);
        expect(
          store.expansionProgressFor('grow_your_money')[cardLesson.id],
          LessonState.applied,
        );
      },
    );
  });

  group('accessibility and layout', () {
    testWidgets('narrow phone, 1.5x system font: nothing runs off the side', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(
        tester,
        store,
        'grow_your_money',
        moneyJobLesson,
        textScale: 1.5,
        size: _narrow,
      );
      final overflow = _runsOffTheSide(tester, _narrow.width);
      expect(overflow, isEmpty, reason: overflow.join(', '));
    });

    testWidgets('every interaction control exposes a semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final store = await _freshStore();
      await _pumpReader(tester, store, 'grow_your_money', moneyJobLesson);
      await _scrollTo(tester, find.text('Myth').first);
      expect(find.bySemanticsLabel('Myth'), findsOneWidget);
      expect(find.bySemanticsLabel('Fact'), findsOneWidget);
      handle.dispose();
    });
  });
}
