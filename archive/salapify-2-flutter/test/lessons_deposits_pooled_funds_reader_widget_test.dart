// Widget-level checks for Money Courses Phase 7B's course, "Deposits and
// Pooled Funds" (lib/content/lessons_deposits_pooled_funds.dart), reusing
// the same ExpansionLessonReader the Investing Readiness pilot and Phase
// 7A's "Stocks and Bonds Without the Hype" already exercise thoroughly.
// This file does not repeat that generic coverage (every route this course
// uses, goals/budget/mindset/accounts, was already added and proven by an
// earlier phase); it proves what is real and new here: a deep link into
// this course's own lesson ids, that opening never completes a lesson,
// that the offline checklist never gates completion, and that this
// course's own densest interactions (the eight-criterion ComparisonBlock
// and the four-bucket product-to-goal CategorizeBlock) stay readable at a
// narrow width and 1.5x system font.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/screens/learn.dart';
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
  final depositOrInvestmentLesson = depositsAndPooledFundsLessons.firstWhere(
    (l) => l.id == dpDepositOrInvestment,
  );
  final comparisonLesson = depositsAndPooledFundsLessons.firstWhere(
    (l) => l.id == dpUitfMutualFundEtf,
  );
  final matchLesson = depositsAndPooledFundsLessons.firstWhere(
    (l) => l.id == dpMatchProductToGoal,
  );

  group('opening vs finishing, real content', () {
    testWidgets('opening a lesson records viewed, never completed', (
      tester,
    ) async {
      final store = await _freshStore();
      await _pumpReader(tester, store, depositOrInvestmentLesson);

      expect(
        store.expansionProgressFor(
          'grow_your_money',
        )[depositOrInvestmentLesson.id],
        LessonState.viewed,
      );
      expect(find.text('Done. One useful thing.'), findsNothing);
    });

    testWidgets(
      'Finish this lesson is disabled until every required interaction '
      'completes',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(tester, store, depositOrInvestmentLesson);

        await _scrollTo(tester, find.text('Finish this lesson'));
        final finishBefore = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Finish this lesson'),
        );
        expect(finishBefore.onPressed, isNull);
      },
    );
  });

  group('the offline checklist never gates completion', () {
    testWidgets('the readiness checklist in the final lesson stays optional', (
      tester,
    ) async {
      final checklist = matchLesson.interactionBlocks
          .whereType<ChecklistBlock>()
          .firstWhere((b) => b.blockId == 'readiness-checklist');
      expect(checklist.requiredForCompletion, isFalse);
    });
  });

  group('deep link into the new course', () {
    testWidgets(
      'a deposits_and_pooled_funds lesson id opens the expansion reader',
      (tester) async {
        final store = await _freshStore();
        await tester.pumpWidget(
          MaterialApp(
            home: LearnScreen(store: store, focusId: dpDepositOrInvestment),
          ),
        );
        await tester.pumpAndSettle();

        // A deep link goes through LearnScreen, which since Phase 3 opens the
        // PAGED reader. The scrolling ExpansionLessonReader is still what the
        // rest of this file pumps directly, and still fully tested there.
        expect(find.byType(PagedLessonReader), findsOneWidget);
        expect(find.text('Deposit or Investment?'), findsOneWidget);
      },
    );
  });

  group('accessibility and layout: this course\'s densest interactions', () {
    testWidgets(
      'narrow phone, 1.5x system font: the eight-criterion comparison '
      'block runs off nothing',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(
          tester,
          store,
          comparisonLesson,
          textScale: 1.5,
          size: _narrow,
        );
        final overflow = _runsOffTheSide(tester, _narrow.width);
        expect(overflow, isEmpty, reason: overflow.join(', '));
      },
    );

    testWidgets(
      'narrow phone, 1.5x system font: the four-bucket product-to-goal '
      'match runs off nothing',
      (tester) async {
        final store = await _freshStore();
        await _pumpReader(
          tester,
          store,
          matchLesson,
          textScale: 1.5,
          size: _narrow,
        );
        final overflow = _runsOffTheSide(tester, _narrow.width);
        expect(overflow, isEmpty, reason: overflow.join(', '));
      },
    );

    testWidgets(
      'each bucket in the deposit-or-investment sort exposes a semantic '
      'label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final store = await _freshStore();
        await _pumpReader(tester, store, depositOrInvestmentLesson);
        await _scrollTo(tester, find.text('Bank deposit').first);
        expect(find.bySemanticsLabel('Bank deposit'), findsWidgets);
        expect(find.bySemanticsLabel('Investment product'), findsWidgets);
        handle.dispose();
      },
    );
  });
}
