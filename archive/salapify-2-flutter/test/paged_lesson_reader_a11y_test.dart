// Large font and screen reader coverage for the reader a learner ACTUALLY
// opens, on every step of it.
//
// Until now the only 1.5x overflow test and the only semantics test on the
// whole lesson surface lived in expansion_lesson_reader_widget_test.dart,
// pumping the scrolling reader. The app stopped opening that reader at f3.57,
// so the lesson surface a learner sees had neither check for three stamps
// (session 37, docs/lunch-and-learn.md).
//
// Copying those two tests across would NOT have closed the gap, and this is
// the part worth saying out loud. The scrolling reader is one ListView, so
// scrolling to the bottom puts every widget through the same measurement. A
// PageView builds one page at a time, so a copied test would measure the
// opening paragraph, pass, and report the whole lesson as safe while eight
// screens behind it went unlooked at. Every test here walks the steps.
//
// It reads the real steps through stepsForLesson rather than tapping
// Continue, for the same reason the render harness does: a required exercise
// gates its own step, so a tap-driven walk would have to satisfy whatever
// exercise each lesson happens to author and would break on an unrelated
// content edit. initialStep opens the reader directly on step N, which is
// what makes a per-step sweep possible at all.
//
// Proven to fail before being trusted. The failure lines are in the commit
// message that introduced this file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_steps.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

/// A small phone. Layout breaks at the narrow end, not the wide one.
const _narrow = Size(320, 780);

/// Lessons chosen for what they RENDER, not for being representative: one
/// prose-led lesson from the pilot course, and one carrying the heaviest
/// interactive widgets in the catalogue (a sorting timeline and a
/// five-bucket categorize grid), which is where a row runs off the side if
/// anything does.
final _lessons = <MoneyLesson>[
  growYourMoneyLessons.firstWhere((l) => l.id == investRefMoneyJob),
  growYourMoneyLessons.firstWhere((l) => l.id == investRefCard),
  stocksAndBondsLessons.firstWhere((l) => l.id == sbHowBondsWork),
];

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pumpStep(
  WidgetTester tester,
  SalapifyStore store,
  MoneyLesson lesson,
  int step, {
  double textScale = 1.0,
  Size size = _narrow,
}) async {
  // The real fonts, because this test MEASURES layout. Flutter's default test
  // font is wider than Plus Jakarta Sans, so a wrap decision comes out one way
  // here and the other way on the phone.
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
        home: PagedLessonReader(
          // A unique key per step, and it is load bearing. Without one,
          // pumping the same widget type at the same position reuses the
          // State, whose _index is a `late` field initialised once, so every
          // step after the first would render step one while this file
          // cheerfully reported it had swept the whole lesson.
          //
          // Not an app defect: the reader is pushed as a fresh route each
          // time a learner opens a lesson, so nothing reuses that State on
          // the phone. It is a real trap for a test that pumps in a loop.
          key: ValueKey('${lesson.id}-$step-$textScale'),
          pathId: 'grow_your_money',
          lesson: lesson,
          store: store,
          initialStep: step,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every Text on screen whose box crosses the left or right edge.
///
/// It measures the render BOX, not the painted glyphs, and that limit was
/// found the hard way rather than reasoned about: the first deliberate break
/// tried here was a sixty character unbreakable word in an exercise kicker,
/// and NOTHING went red. A long word does not widen a Text's box past its
/// constraints, it just paints outside it, so neither this check nor the
/// RenderFlex one below can see that shape at all.
///
/// What these two do catch is a box laid out wider than the screen, which is
/// what an unwrapped Row or a fixed width child produces, and which is the
/// shape that has actually reached the phone here before. A break of that
/// kind reported at step 5 of 10, which is also the proof that the per-step
/// sweep is real: a copied single-screen test would have measured step 1 and
/// declared the lesson safe.
///
/// Said plainly rather than left implied, because a check whose blind spot is
/// undocumented gets trusted for things it never did.
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
      bad.add('"${(w.data ?? w.textSpan?.toPlainText() ?? '').trim()}"');
    }
  }
  return bad;
}

void main() {
  for (final lesson in _lessons) {
    final stepCount = stepsForLesson(lesson).length;

    testWidgets(
      'narrow phone, 1.5x system font: nothing runs off the side on any step '
      'of "${lesson.title}"',
      (tester) async {
        final store = await _freshStore();
        final problems = <String>[];
        for (var i = 0; i < stepCount; i++) {
          await _pumpStep(tester, store, lesson, i, textScale: 1.5);
          for (final t in _runsOffTheSide(tester, _narrow.width)) {
            problems.add('step ${i + 1} of $stepCount: $t');
          }
          // A page that drew nothing is its own defect and would otherwise
          // pass the overflow check perfectly.
          if (find.byType(Text).evaluate().isEmpty) {
            problems.add('step ${i + 1} of $stepCount: drew no text at all');
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );

    testWidgets('no step of "${lesson.title}" overflows its layout', (
      tester,
    ) async {
      // A RenderFlex overflow is the yellow and black barber pole on a phone
      // and is never intended. tester.takeException surfaces it per step.
      final store = await _freshStore();
      final problems = <String>[];
      for (var i = 0; i < stepCount; i++) {
        await _pumpStep(tester, store, lesson, i, textScale: 1.5);
        final err = tester.takeException();
        if (err != null) problems.add('step ${i + 1} of $stepCount: $err');
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  testWidgets('the step counter is announced, on every step', (tester) async {
    // Three shapes carrying the whole "where am I" meaning: a bar, a number,
    // and a position. Only the announcement reaches a screen reader user.
    final handle = tester.ensureSemantics();
    final store = await _freshStore();
    final lesson = _lessons.first;
    final stepCount = stepsForLesson(lesson).length;
    for (var i = 0; i < stepCount; i++) {
      await _pumpStep(tester, store, lesson, i);
      expect(
        find.bySemanticsLabel('Step ${i + 1} of $stepCount'),
        findsOneWidget,
        reason: 'step ${i + 1} announced nothing a screen reader could read',
      );
    }
    handle.dispose();
  });

  testWidgets('a myth and fact pair is labelled, not just coloured', (
    tester,
  ) async {
    // Ported from the scrolling reader's own semantics test, which pumped a
    // widget the app can no longer open. The pair is styled differently and
    // that styling is the only thing distinguishing them visually.
    final handle = tester.ensureSemantics();
    final store = await _freshStore();
    final lesson = _lessons.first;
    final steps = stepsForLesson(lesson);

    var found = false;
    for (var i = 0; i < steps.length && !found; i++) {
      await _pumpStep(tester, store, lesson, i);
      if (find.text('Myth').evaluate().isNotEmpty) {
        expect(find.bySemanticsLabel('Myth'), findsOneWidget);
        expect(find.bySemanticsLabel('Fact'), findsOneWidget);
        found = true;
      }
    }
    expect(
      found,
      isTrue,
      reason:
          '"${lesson.title}" no longer contains a myth and fact pair, so this '
          'test is guarding nothing and should be pointed at a lesson that '
          'does',
    );
    handle.dispose();
  });
}
