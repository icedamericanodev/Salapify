// The Phase 4 catalog screens: a path's courses, and one course's lessons.
//
// The module tests (lesson_flow_test.dart) already prove the arithmetic. What
// only a widget test can prove is that the arithmetic reaches the screen, that
// tapping a course card actually pushes the course, and that exactly ONE
// course carries the loud button.
//
// That last one is the reason this file exists at all. The first render of
// PathScreen put a filled accent button on every card, five identical orange
// slabs down the page, and nothing in lesson_flow_test.dart could have seen
// it: focusCourseId can be perfectly right while the screen ignores it.
//
// Every test here was proven to fail before it was trusted. The failure lines
// are in the commit message that introduced this file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/expansion_display.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/path_screen.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _grow = publishedLearningPaths.firstWhere(
  (p) => p.id == 'grow_your_money',
);

/// Reveal the advanced Grow courses tucked behind the "Go deeper" disclosure
/// (Batch C1B). A no-op on a path that has none, so callers can use it freely.
Future<void> _openGoDeeper(WidgetTester tester) async {
  final toggle = find.text('GO DEEPER');
  if (toggle.evaluate().isEmpty) return;
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

/// A deliberately TALL viewport, so a lazy ListView builds every course card
/// at once and a count assertion means what it says.
///
/// The default 800x600 test window builds about two cards and the other three
/// simply do not exist yet, which reads as "the screen is missing courses"
/// when the screen is fine. Whether the layout survives a real phone is a
/// different question, asked by screen_readability_test.dart against the
/// actual 1170x2532 frame; this file is only asking whether the arithmetic
/// reaches the widgets.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpPath(WidgetTester tester, SalapifyStore store) async {
  _tallPhone(tester);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: PathScreen(path: _grow, store: store, onOpenLesson: (_, _, _) {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the path screen lists every course, advanced ones behind Go '
      'deeper', (tester) async {
    final store = await _freshStore();
    await _pumpPath(tester, store);

    // Read from the content rather than typed here: a sixth course joining
    // this path must not make this test look like it asserts a total of five.
    final mainstream = [
      for (final g in _grow.groups)
        if (!isAdvancedGrowGroup(g.id)) g,
    ];
    final advanced = [
      for (final g in _grow.groups)
        if (isAdvancedGrowGroup(g.id)) g,
    ];
    // The regrouping only means anything if Grow really has both kinds.
    expect(mainstream, isNotEmpty);
    expect(advanced, isNotEmpty);

    // Mainstream courses show by default; the advanced ones sit behind the
    // collapsed Go deeper disclosure (Batch C1B).
    for (final g in mainstream) {
      expect(find.text(g.title), findsOneWidget, reason: g.title);
    }
    expect(find.text('GO DEEPER'), findsOneWidget);
    for (final g in advanced) {
      expect(
        find.text(g.title),
        findsNothing,
        reason: 'hidden until Go deeper opens: ${g.title}',
      );
    }
    // The count still totals every course, hidden or not: identity and
    // progress are untouched by which header a course sits under.
    expect(
      find.text('0 of ${_grow.groups.length} courses done'),
      findsOneWidget,
    );

    // Opening Go deeper makes every course reachable on its own card.
    await _openGoDeeper(tester);
    for (final g in _grow.groups) {
      expect(find.text(g.title), findsOneWidget, reason: g.title);
    }
  });

  testWidgets('exactly one course carries the filled button', (tester) async {
    // The whole point of the focus rule. Four outlined buttons and one filled
    // one, never five filled. Counted across every course, so Go deeper is
    // opened first to render the advanced cards too.
    final store = await _freshStore();
    await _pumpPath(tester, store);
    await _openGoDeeper(tester);

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(_grow.groups.length - 1));
  });

  testWidgets('the filled button follows the half-read course', (tester) async {
    // Start the SECOND course and leave it unfinished. The loud button has to
    // move off the first card and onto that one, which is the difference
    // between "first unfinished" and "resume what you started".
    final store = await _freshStore();
    final secondGroup = _grow.groups[1];
    await store.markExpansionLessonCompleted(
      _grow.id,
      secondGroup.lessonIds.first,
    );
    await _pumpPath(tester, store);

    final filled = tester.widget<FilledButton>(find.byType(FilledButton));
    expect((filled.child as Text).data, 'Continue');

    // And it is inside the second course's card, not merely somewhere on the
    // screen saying the right word.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(secondGroup.title),
          matching: find.byType(Card),
        ),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a course card opens that course', (tester) async {
    final store = await _freshStore();
    await _pumpPath(tester, store);

    final second = _grow.groups[1];
    await tester.tap(find.text(second.title));
    await tester.pumpAndSettle();

    expect(find.byType(CourseScreen), findsOneWidget);
    // The lessons of THAT course, not of the one above it.
    expect(
      find.text('0 of ${second.lessonIds.length} lessons done'),
      findsOneWidget,
    );
  });

  testWidgets('the course screen shows its lessons in order with minutes', (
    tester,
  ) async {
    final store = await _freshStore();
    final group = _grow.groups.first;
    _tallPhone(tester);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: CourseScreen(
          path: _grow,
          groupId: group.id,
          store: store,
          onOpenLesson: (_, _, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < group.lessonIds.length; i++) {
      expect(
        find.text('${i + 1} of ${group.lessonIds.length}'),
        findsOneWidget,
        reason: 'position ${i + 1}',
      );
    }
    expect(find.text(growYourMoneyLessons.first.title), findsOneWidget);
  });

  testWidgets('the course screen counts a finished lesson', (tester) async {
    // The orientation line the first draft of this screen did not have. It has
    // to react to real progress, not just render a zero.
    final store = await _freshStore();
    final group = _grow.groups.first;
    await store.markExpansionLessonCompleted(_grow.id, group.lessonIds.first);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: CourseScreen(
          path: _grow,
          groupId: group.id,
          store: store,
          onOpenLesson: (_, _, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 of ${group.lessonIds.length} lessons done'),
      findsOneWidget,
    );
  });

  testWidgets(
    'opening a lesson from a course card never touches core progress',
    (tester) async {
      // The load-bearing isolation between the two progress stores. A path
      // screen writing into settings.lessonProgress would silently advance the
      // core 22 and nothing on this screen would look wrong.
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(
        _grow.id,
        _grow.groups.first.lessonIds.first,
      );
      await _pumpPath(tester, store);

      expect(store.lessonProgress, isEmpty);
      expect(store.expansionProgressFor(_grow.id), isNotEmpty);
    },
  );
}
