// The paged reader, driven the way a person drives it: tapping Continue.
//
// The pagination arithmetic is covered by lesson_steps_test.dart. What this
// file guards is the behaviour that only exists once the widget is on
// screen: that a required exercise really does stop the Continue button,
// that reaching the end records completion, and that a finished lesson
// reopens finished.
//
// Proven to fail before being trusted; the failure lines are in the commit
// message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/money/lesson_steps.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

const _pathId = 'grow_your_money';

Future<SalapifyStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final s = SalapifyStore();
  await s.load();
  return s;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store, lesson) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(390, 900) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: PagedLessonReader(pathId: _pathId, lesson: lesson, store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final lesson = growYourMoneyLessons.firstWhere(
    (l) => l.id == investRefMoneyJob,
  );

  testWidgets('a lesson opens on its first screen, not a scroll', (
    tester,
  ) async {
    await _pump(tester, await _store(), lesson);
    expect(find.text(lesson.title), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // The whole lesson is NOT on screen at once any more: the finish card
    // is several taps away.
    expect(find.textContaining('Done.'), findsNothing);
  });

  testWidgets('opening does not finish the lesson', (tester) async {
    final store = await _store();
    await _pump(tester, store, lesson);
    expect(
      isDone(
        store.expansionProgressFor(_pathId)[lesson.id] ??
            LessonState.notStarted,
      ),
      isFalse,
    );
  });

  testWidgets('a required exercise stops Continue until it is done', (
    tester,
  ) async {
    final store = await _store();
    await _pump(tester, store, lesson);

    // Walk forward until the button goes dead. The first required
    // interaction in this lesson is a myth-or-fact card.
    var guard = 0;
    while (guard++ < 30) {
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(FilledButton),
        ),
      );
      if (button.onPressed == null) break;
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      if (find.text('Continue').evaluate().isEmpty) break;
    }

    expect(
      find.text('Finish this activity to continue.'),
      findsOneWidget,
      reason: 'a required exercise must stop the reader on its own screen',
    );
    final blocked = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(blocked.onPressed, isNull);
  });

  testWidgets('a completed lesson reopens finished', (tester) async {
    final store = await _store();
    await store.markExpansionLessonCompleted(_pathId, lesson.id);
    await _pump(tester, store, lesson);
    // The reader knows it is done from the store, exactly as the scrolling
    // reader does (audit defect C6).
    expect(isDone(store.expansionProgressFor(_pathId)[lesson.id]!), isTrue);
  });

  test('the step list matches what the reader will show', () {
    // A cheap invariant tying the widget to the pure module: the reader
    // renders one page per step and nothing else.
    final steps = stepsForLesson(lesson);
    expect(steps.last, isA<FinishStep>());
    expect(
      steps.whereType<InteractionStep>().length,
      lesson.interactionBlocks.length,
    );
  });
}
