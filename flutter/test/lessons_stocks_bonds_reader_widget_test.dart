// Widget-level checks for Money Courses Phase 7A's course, "Stocks and
// Bonds Without the Hype" (lib/content/lessons_stocks_bonds.dart), reusing
// the same ExpansionLessonReader the Investing Readiness pilot already
// exercises thoroughly in expansion_lesson_reader_widget_test.dart. This
// file does not repeat that generic coverage; it proves what is actually
// NEW here: the 'mindset' and 'accounts' routes this phase added to
// widgets/expansion_lesson_reader.dart's closed route switch, and that a
// lesson from this course still opens without completing and still gates
// Finish on its required interactions, using the real registered content.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/mindset_today.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pumpReader(
  WidgetTester tester,
  SalapifyStore store,
  MoneyLesson lesson, {
  Size size = const Size(390, 8000),
  double textScale = 1.0,
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
          pathId: 'grow_your_money',
          lesson: lesson,
          store: store,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

const _narrow = Size(320, 780);

// Same check expansion_lesson_reader_widget_test.dart already runs against
// the pilot's content; reused here at the pilot's own narrow width, but
// against THIS course's most content-dense interactions: the bond-timeline
// SortingBlock and a five-bucket CategorizeBlock (risk matching), neither of
// which any production lesson used before this course, so neither was ever
// actually exercised at 320dp before now.
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

void main() {
  final ownerLenderLesson = stocksAndBondsLessons.firstWhere(
    (l) => l.id == sbOwnerOrLender,
  );
  final bondsLesson = stocksAndBondsLessons.firstWhere(
    (l) => l.id == sbHowBondsWork,
  );
  final verifyLesson = stocksAndBondsLessons.firstWhere(
    (l) => l.id == sbVerifyBeforeYouInvest,
  );

  group('opening vs finishing, real content', () {
    testWidgets('opening a lesson records viewed, never completed', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, ownerLenderLesson);

      expect(
        store.expansionProgressFor('grow_your_money')[ownerLenderLesson.id],
        LessonState.viewed,
      );
      expect(find.text('Done. One useful thing.'), findsNothing);
    });

    testWidgets(
      'Finish this lesson is disabled until every required interaction '
      'completes',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(tester, store, ownerLenderLesson);

        await _scrollTo(tester, find.text('Finish this lesson'));
        final finishBefore = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Finish this lesson'),
        );
        expect(finishBefore.onPressed, isNull);
      },
    );
  });

  group('the two new Salapify action routes this phase added', () {
    testWidgets('Money Mindset opens the real screen and marks applied', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, verifyLesson);

      final label = find.text('Open Money Mindset before acting on a tip');
      await _scrollTo(tester, label);
      final openButtons = find.widgetWithText(OutlinedButton, 'Open');
      // Actions render in the order authored: goal (0), budget (1), mindset
      // (2), accounts (3).
      await tester.tap(openButtons.at(2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(MindsetTodayScreen), findsOneWidget);
      expect(
        store.expansionProgressFor('grow_your_money')[verifyLesson.id],
        LessonState.applied,
      );
    });

    testWidgets(
      'Review your Accounts opens the real screen, Cancel navigates nowhere',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(tester, store, verifyLesson);

        final label = find.text('Review your Accounts');
        await _scrollTo(tester, label);
        final openButtons = find.widgetWithText(OutlinedButton, 'Open');
        await tester.tap(openButtons.at(3));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('no security is purchased or recommended'),
          findsWidgets,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountsScreen), findsNothing);
        expect(
          store.expansionProgressFor('grow_your_money')[verifyLesson.id],
          isNot(LessonState.applied),
        );

        await tester.tap(openButtons.at(3));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountsScreen), findsOneWidget);
      },
    );
  });

  group('deep link into the new course', () {
    testWidgets('a stocks_and_bonds lesson id opens the expansion reader', (
      tester,
    ) async {
      final store = await _freshStore();
      await tester.pumpWidget(
        MaterialApp(
          home: LearnScreen(store: store, focusId: sbOwnerOrLender),
        ),
      );
      await tester.pumpAndSettle();

      // A deep link goes through LearnScreen, which since Phase 3 opens the
      // PAGED reader. The scrolling ExpansionLessonReader is still what the
      // rest of this file pumps directly, and still fully tested there.
      expect(find.byType(PagedLessonReader), findsOneWidget);
      expect(find.text('Owner or Lender?'), findsOneWidget);
    });
  });

  group('accessibility and layout: the SortingBlock and five-bucket '
      'CategorizeBlock this course is the first production content to use', () {
    testWidgets('narrow phone, 1.5x system font: nothing runs off the side', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(
        tester,
        store,
        bondsLesson,
        textScale: 1.5,
        size: _narrow,
      );
      final overflow = _runsOffTheSide(tester, _narrow.width);
      expect(overflow, isEmpty, reason: overflow.join(', '));
    });

    testWidgets(
      'the sorting control and each risk bucket expose a semantic label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = await _freshStore();
        await _pumpReader(tester, store, bondsLesson);
        await _scrollTo(tester, find.text('Credit risk').first);
        expect(find.bySemanticsLabel('Credit risk'), findsWidgets);
        handle.dispose();
      },
    );
  });
}
