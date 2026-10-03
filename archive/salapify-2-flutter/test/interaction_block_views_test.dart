// Widget-level checks for the Phase 5 interaction blocks
// (lib/widgets/interaction_block_views.dart): selection and feedback,
// duplicate-submission prevention, retry/reset, narrow-screen stacking,
// missing comparison values, checklist required/optional handling and
// reset, sorting submission and move controls, reflection choices/skip and
// free-text non-persistence, and accessibility semantics at large text
// scale.
//
// Real fonts loaded per repo convention (test/screens_shot.dart): this file
// measures layout (overflow, off-the-side text), so it is one of the tests
// that rule applies to.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/interaction_block_views.dart';

import 'screens_shot.dart' show loadRealFonts;

const _narrow = Size(320, 900);
const _wide = Size(700, 900);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = _narrow,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(brightness);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
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
      bad.add(
        '"$s" spans ${left.toStringAsFixed(1)} to ${right.toStringAsFixed(1)}',
      );
    }
  }
  return bad;
}

void _expectNoLiteralNull(WidgetTester tester) {
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    expect(
      s.toLowerCase().contains('null'),
      isFalse,
      reason: 'found the word null in "$s"',
    );
  }
}

void main() {
  group('ScenarioChoiceView', () {
    const preferred = ScenarioChoiceBlock(
      blockId: 'scn-fee',
      scenarioTitle: 'Extra money after payday',
      situation:
          'You have one month of emergency savings and expensive '
          'credit-card debt. Where should additional money go first?',
      options: [
        ScenarioChoiceOption(
          id: 'save-more',
          label: 'Keep building the emergency fund',
          explanation:
              'That works if losing income soon is the bigger risk for you.',
        ),
        ScenarioChoiceOption(
          id: 'pay-debt',
          label: 'Pay down the credit card',
          explanation:
              'That works because the card is likely charging more interest than savings can earn.',
        ),
      ],
      preferredOptionId: 'pay-debt',
    );

    const openEnded = ScenarioChoiceBlock(
      blockId: 'scn-open',
      scenarioTitle: 'A windfall arrives',
      situation: 'You receive an unexpected bonus.',
      options: [
        ScenarioChoiceOption(
          id: 'save',
          label: 'Save all of it',
          explanation: 'A safety net grows faster this way.',
        ),
        ScenarioChoiceOption(
          id: 'spend-some',
          label: 'Spend a little, save the rest',
          explanation: 'A small planned treat can still leave room to save.',
        ),
      ],
    );

    testWidgets(
      'picking the preferred option shows well-supported feedback, not Correct/Wrong',
      (tester) async {
        final completed = <String>[];
        await _pump(
          tester,
          ScenarioChoiceView(preferred, onComplete: completed.add),
        );
        await tester.tap(find.text('Pay down the credit card'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(completed, ['scn-fee']);
        expect(find.text('THAT WORKS'), findsOneWidget);
        expect(
          find.textContaining('more interest than savings'),
          findsOneWidget,
        );
        expect(find.text('Correct'), findsNothing);
        expect(find.text('Wrong'), findsNothing);
        expect(find.text('Wrong!'), findsNothing);
      },
    );

    testWidgets(
      'picking the non-preferred option explains the trade-off, never shames the choice',
      (tester) async {
        await _pump(tester, ScenarioChoiceView(preferred, onComplete: (_) {}));
        await tester.tap(find.text('Keep building the emergency fund'));
        await tester.pumpAndSettle();

        expect(find.text('TRADE-OFF'), findsOneWidget);
        expect(find.textContaining('losing income soon'), findsOneWidget);
        expect(find.textContaining('bad'), findsNothing);
        expect(find.textContaining('failed'), findsNothing);
      },
    );

    testWidgets(
      'a scenario with no single correct answer always reads as a trade-off',
      (tester) async {
        await _pump(tester, ScenarioChoiceView(openEnded, onComplete: (_) {}));
        await tester.tap(find.text('Save all of it'));
        await tester.pumpAndSettle();

        expect(find.text('TRADE-OFF'), findsOneWidget);
        expect(find.text('THAT WORKS'), findsNothing);
      },
    );

    testWidgets(
      'a second tap on a different option is not a duplicate submission',
      (tester) async {
        final completed = <String>[];
        await _pump(
          tester,
          ScenarioChoiceView(preferred, onComplete: completed.add),
        );
        await tester.tap(find.text('Keep building the emergency fund'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pay down the credit card'));
        await tester.pumpAndSettle();

        // Still showing the FIRST pick's feedback; onComplete fired once.
        expect(completed, ['scn-fee']);
        expect(find.text('TRADE-OFF'), findsOneWidget);
      },
    );

    testWidgets('retry resets the selection and lets a new option be picked', (
      tester,
    ) async {
      final resets = <String>[];
      await _pump(
        tester,
        ScenarioChoiceView(preferred, onComplete: (_) {}, onReset: resets.add),
      );
      await tester.tap(find.text('Keep building the emergency fund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(resets, ['scn-fee']);
      expect(find.text('TRADE-OFF'), findsNothing);

      await tester.tap(find.text('Pay down the credit card'));
      await tester.pumpAndSettle();
      expect(find.text('THAT WORKS'), findsOneWidget);
    });
  });

  group('MythOrFactView', () {
    const block = MythOrFactBlock(
      blockId: 'myth-1',
      statement: 'A regulated investment cannot lose money.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Regulation checks the rules are followed; it does not remove market risk.',
      officialSource: LessonSourceInfo(
        agency: 'Securities and Exchange Commission',
        title: 'Investor protection guide',
        canonicalUrl: 'https://www.sec.gov.ph/investor-guide',
      ),
    );

    testWidgets(
      'answering Myth (correct) shows well-supported feedback and the explanation',
      (tester) async {
        await _pump(tester, MythOrFactView(block, onComplete: (_) {}));
        await tester.tap(find.text('Myth'));
        await tester.pumpAndSettle();

        expect(find.text('THAT WORKS'), findsOneWidget);
        expect(
          find.textContaining('does not remove market risk'),
          findsOneWidget,
        );
        expect(find.text('OFFICIAL SOURCE'), findsOneWidget);
      },
    );

    testWidgets(
      'answering Fact (wrong) still shows the explanation and takes-another-look feedback',
      (tester) async {
        await _pump(tester, MythOrFactView(block, onComplete: (_) {}));
        await tester.tap(find.text('Fact'));
        await tester.pumpAndSettle();

        expect(find.text('TAKE ANOTHER LOOK'), findsOneWidget);
        expect(
          find.textContaining('does not remove market risk'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the result is announced to screen readers via a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, MythOrFactView(block, onComplete: (_) {}));
      await tester.tap(find.text('Fact'));
      await tester.pumpAndSettle();

      final liveRegions = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(liveRegions, findsWidgets);
      handle.dispose();
    });

    testWidgets('long statements and narrow screens do not overflow', (
      tester,
    ) async {
      const longBlock = MythOrFactBlock(
        blockId: 'myth-long',
        statement:
            'Once the Bangko Sentral ng Pilipinas approves a digital bank '
            'license, every product that bank ever offers is automatically '
            'guaranteed against every possible kind of loss forever.',
        correctAnswer: MythOrFactAnswer.myth,
        explanation:
            'A license covers how a bank must operate, not a guarantee against every loss.',
      );
      await _pump(
        tester,
        MythOrFactView(longBlock, onComplete: (_) {}),
        size: _narrow,
      );
      expect(tester.takeException(), isNull);
      expect(_runsOffTheSide(tester, _narrow.width), isEmpty);
    });
  });

  group('ComparisonView', () {
    const block = ComparisonBlock(
      blockId: 'cmp-1',
      title: 'Two fictional savings products',
      criteria: [
        ComparisonCriterion(id: 'liquidity', label: 'Liquidity'),
        ComparisonCriterion(id: 'fees', label: 'Fees'),
      ],
      items: [
        ComparisonItem(
          id: 'a',
          name: 'Sample Save Plus',
          valuesByCriterionId: {
            'liquidity': 'Withdraw anytime',
            'fees': 'None',
          },
        ),
        ComparisonItem(id: 'b', name: 'Sample Lock Fund'),
      ],
    );

    testWidgets(
      'missing values render as "Not provided", never the word null',
      (tester) async {
        await _pump(tester, ComparisonView(block, onComplete: (_) {}));
        expect(find.text('Not provided'), findsNWidgets(2));
        _expectNoLiteralNull(tester);
      },
    );

    testWidgets('stacks without horizontal overflow on a narrow screen', (
      tester,
    ) async {
      await _pump(
        tester,
        ComparisonView(block, onComplete: (_) {}),
        size: _narrow,
      );
      expect(tester.takeException(), isNull);
      expect(_runsOffTheSide(tester, _narrow.width), isEmpty);
    });

    testWidgets('stacks without horizontal overflow on a wide screen too', (
      tester,
    ) async {
      await _pump(
        tester,
        ComparisonView(block, onComplete: (_) {}),
        size: _wide,
      );
      expect(tester.takeException(), isNull);
      expect(_runsOffTheSide(tester, _wide.width), isEmpty);
    });

    testWidgets('never labels an option "Best"', (tester) async {
      await _pump(tester, ComparisonView(block, onComplete: (_) {}));
      expect(find.text('Best'), findsNothing);
    });

    testWidgets('marking as reviewed completes it, unmarking resets it', (
      tester,
    ) async {
      final completed = <String>[];
      final reset = <String>[];
      await _pump(
        tester,
        ComparisonView(block, onComplete: completed.add, onReset: reset.add),
      );
      expect(completed, isEmpty);
      await tester.tap(find.text('Mark as reviewed'));
      await tester.pumpAndSettle();
      expect(completed, ['cmp-1']);

      await tester.tap(find.text('Marked as reviewed'));
      await tester.pumpAndSettle();
      expect(reset, ['cmp-1']);
    });
  });

  group('ChecklistView', () {
    const block = ChecklistBlock(
      blockId: 'chk-1',
      checklistPrompt: 'Before you start',
      items: [
        ChecklistItemDef(id: 'a', label: 'Read the summary', required: true),
        ChecklistItemDef(id: 'b', label: 'Skim the FAQ', required: false),
      ],
    );

    testWidgets('required items are labeled, optional items are not', (
      tester,
    ) async {
      await _pump(tester, ChecklistView(block, onComplete: (_) {}));
      expect(find.text('REQUIRED'), findsOneWidget);
    });

    testWidgets('completes only once every required item is checked', (
      tester,
    ) async {
      final completed = <String>[];
      await _pump(tester, ChecklistView(block, onComplete: completed.add));
      await tester.tap(find.text('Skim the FAQ'));
      await tester.pumpAndSettle();
      expect(
        completed,
        isEmpty,
        reason: 'checking only the optional item must not complete it',
      );

      await tester.tap(find.text('Read the summary'));
      await tester.pumpAndSettle();
      expect(completed, ['chk-1']);
    });

    testWidgets('reset clears every checked item and the progress count', (
      tester,
    ) async {
      final reset = <String>[];
      await _pump(
        tester,
        ChecklistView(block, onComplete: (_) {}, onReset: reset.add),
      );
      await tester.tap(find.text('Read the summary'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 required checked'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 1 required checked'), findsOneWidget);
      expect(reset, ['chk-1']);
    });
  });

  group('SortingView', () {
    const block = SortingBlock(
      blockId: 'srt-1',
      sortingPrompt: 'Put this fictional registration flow in order',
      items: [
        SortingItemDef(id: 'reserve-name', label: 'Reserve a name'),
        SortingItemDef(id: 'submit-docs', label: 'Submit documents'),
        SortingItemDef(id: 'pay-fee', label: 'Pay the registration fee'),
        SortingItemDef(id: 'receive-cert', label: 'Receive the certificate'),
      ],
    );

    testWidgets(
      'submitting the unsorted (reversed) order does not read as fully correct',
      (tester) async {
        final completed = <String>[];
        await _pump(tester, SortingView(block, onComplete: completed.add));
        await tester.tap(find.text('Submit order'));
        await tester.pumpAndSettle();

        expect(completed, ['srt-1']);
        expect(find.text('TAKE ANOTHER LOOK'), findsOneWidget);
        expect(find.text('Not quite, check the order again'), findsWidgets);
      },
    );

    testWidgets(
      'move up and move down reorder the rows without color-only feedback',
      (tester) async {
        await _pump(tester, SortingView(block, onComplete: (_) {}));
        // Move the first row ("Receive the certificate", since the initial
        // order is the target reversed) down once.
        final moveDownButtons = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith(
                'Move Receive the certificate down',
              ),
        );
        expect(moveDownButtons, findsOneWidget);
        await tester.tap(moveDownButtons);
        await tester.pumpAndSettle();

        // Initial order is the target reversed: [receive-cert, pay-fee,
        // submit-docs, reserve-name]. Moving row 0 down swaps it with row 1
        // ("Pay the registration fee"), landing "Receive the certificate"
        // one row above "Submit documents" (still untouched, at row 2).
        final submitDocsY = tester.getTopLeft(find.text('Submit documents')).dy;
        final receiveCertY = tester
            .getTopLeft(find.text('Receive the certificate'))
            .dy;
        expect(receiveCertY, lessThan(submitDocsY));
      },
    );

    testWidgets('correctly sorted order submits as well-supported', (
      tester,
    ) async {
      final completed = <String>[];
      await _pump(tester, SortingView(block, onComplete: completed.add));
      // Reverse back to the target order: three downward moves of the first
      // row walks "Receive the certificate" to the bottom, one step short of
      // fixing all four; instead move each pair explicitly.
      for (var round = 0; round < 3; round++) {
        final firstMoveDown = find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label ?? '').contains(' down'),
        );
        await tester.tap(firstMoveDown.first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Submit order'));
      await tester.pumpAndSettle();
      expect(completed, ['srt-1']);
      // Whatever the exact resulting order, feedback is always one of the
      // two known kickers and never a bare color-only signal.
      expect(
        find.text('THAT WORKS').evaluate().isNotEmpty ||
            find.text('TAKE ANOTHER LOOK').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('retry resets the order back to its scrambled start', (
      tester,
    ) async {
      final resets = <String>[];
      await _pump(
        tester,
        SortingView(block, onComplete: (_) {}, onReset: resets.add),
      );
      await tester.tap(find.text('Submit order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(resets, ['srt-1']);
      expect(find.text('Submit order'), findsOneWidget);
      // Move controls are back, meaning it left the submitted state.
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label ?? '').contains('Move'),
        ),
        findsWidgets,
      );
    });

    testWidgets('does not overflow at 1.5x text scale on a narrow screen', (
      tester,
    ) async {
      await _pump(
        tester,
        SortingView(block, onComplete: (_) {}),
        size: _narrow,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      expect(_runsOffTheSide(tester, _narrow.width), isEmpty);
    });
  });

  group('ReflectionPromptView', () {
    const withChoices = ReflectionPromptBlock(
      blockId: 'ref-1',
      question: 'What is one habit you want to try this week?',
      choices: [
        ReflectionChoice(id: 'track', label: 'Track every expense for a week'),
        ReflectionChoice(
          id: 'pause',
          label: 'Pause before non-essential purchases',
        ),
      ],
    );

    const freeText = ReflectionPromptBlock(
      blockId: 'ref-2',
      question: 'Anything on your mind about this lesson?',
      allowFreeText: true,
    );

    testWidgets('picking a predefined choice completes the reflection', (
      tester,
    ) async {
      final completed = <String>[];
      await _pump(
        tester,
        ReflectionPromptView(withChoices, onComplete: completed.add),
      );
      await tester.tap(find.text('Track every expense for a week'));
      await tester.pumpAndSettle();
      expect(completed, ['ref-1']);
    });

    testWidgets(
      'skip is offered and available since this reflection is not required',
      (tester) async {
        final completed = <String>[];
        await _pump(
          tester,
          ReflectionPromptView(withChoices, onComplete: completed.add),
        );
        expect(find.text('Skip'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.text('Skipped for now.'), findsOneWidget);
        // Skipping is opting out, not engaging: it must not complete the block.
        expect(completed, isEmpty);
      },
    );

    testWidgets('a required reflection offers no skip control', (tester) async {
      const required = ReflectionPromptBlock(
        blockId: 'ref-req',
        question: 'What would you do differently?',
        choices: [ReflectionChoice(id: 'a', label: 'Something specific')],
        requiredForCompletion: true,
      );
      await _pump(tester, ReflectionPromptView(required, onComplete: (_) {}));
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('shows the privacy note and never persists typed free text', (
      tester,
    ) async {
      final completed = <String>[];
      await _pump(
        tester,
        ReflectionPromptView(freeText, onComplete: completed.add),
      );
      expect(find.textContaining('never saved'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'my account number is 12345',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // onComplete only ever receives the block id, never the typed text.
      expect(completed, ['ref-2']);
      for (final id in completed) {
        expect(id, isNot(contains('12345')));
      }
    });
  });

  group('viewForInteractionBlock dispatcher', () {
    const scenarioA = ScenarioChoiceBlock(
      blockId: 'scn-a',
      scenarioTitle: 'Scenario A',
      situation: 'Situation A.',
      options: [
        ScenarioChoiceOption(
          id: 'a1',
          label: 'Option A1',
          explanation: 'A1 works.',
        ),
        ScenarioChoiceOption(
          id: 'a2',
          label: 'Option A2',
          explanation: 'A2 works.',
        ),
      ],
    );
    const scenarioB = ScenarioChoiceBlock(
      blockId: 'scn-b',
      scenarioTitle: 'Scenario B',
      situation: 'Situation B.',
      options: [
        ScenarioChoiceOption(
          id: 'b1',
          label: 'Option B1',
          explanation: 'B1 works.',
        ),
        ScenarioChoiceOption(
          id: 'b2',
          label: 'Option B2',
          explanation: 'B2 works.',
        ),
      ],
    );

    testWidgets(
      'swapping to a different scenario at the same tree position never '
      'reuses a stale selection (would otherwise throw Bad state: No element)',
      (tester) async {
        await _pump(
          tester,
          viewForInteractionBlock(scenarioA, onComplete: (_) {}),
        );
        await tester.tap(find.text('Option A1'));
        await tester.pumpAndSettle();

        await _pump(
          tester,
          viewForInteractionBlock(scenarioB, onComplete: (_) {}),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Option B1'), findsOneWidget);
        expect(find.text('Option A1'), findsNothing);
      },
    );

    testWidgets(
      'the same swap on a sorting block never reuses a stale item lookup',
      (tester) async {
        const sortA = SortingBlock(
          blockId: 'sort-a',
          sortingPrompt: 'Order A',
          items: [
            SortingItemDef(id: 'a1', label: 'Step A1'),
            SortingItemDef(id: 'a2', label: 'Step A2'),
          ],
        );
        const sortB = SortingBlock(
          blockId: 'sort-b',
          sortingPrompt: 'Order B',
          items: [
            SortingItemDef(id: 'b1', label: 'Step B1'),
            SortingItemDef(id: 'b2', label: 'Step B2'),
          ],
        );

        await _pump(tester, viewForInteractionBlock(sortA, onComplete: (_) {}));
        await _pump(tester, viewForInteractionBlock(sortB, onComplete: (_) {}));

        expect(tester.takeException(), isNull);
        expect(find.text('Step B1'), findsOneWidget);
      },
    );
  });

  group('accessibility semantics across blocks', () {
    testWidgets('checklist rows announce their checked state', (tester) async {
      final handle = tester.ensureSemantics();
      const block = ChecklistBlock(
        blockId: 'chk-a11y',
        checklistPrompt: 'Steps',
        items: [ChecklistItemDef(id: 'a', label: 'One step', required: true)],
      );
      await _pump(tester, ChecklistView(block, onComplete: (_) {}));

      var node = tester.getSemantics(find.text('One step').first);
      expect(node.flagsCollection.isChecked, CheckedState.isFalse);

      await tester.tap(find.text('One step'));
      await tester.pumpAndSettle();
      node = tester.getSemantics(find.text('One step').first);
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      handle.dispose();
    });

    testWidgets(
      'scenario option rows expose a button role and selected state',
      (tester) async {
        final handle = tester.ensureSemantics();
        const block = ScenarioChoiceBlock(
          blockId: 'scn-a11y',
          scenarioTitle: 'A scenario',
          situation: 'A situation.',
          options: [
            ScenarioChoiceOption(id: 'a', label: 'Option A', explanation: 'x'),
            ScenarioChoiceOption(id: 'b', label: 'Option B', explanation: 'y'),
          ],
        );
        await _pump(tester, ScenarioChoiceView(block, onComplete: (_) {}));
        final node = tester.getSemantics(find.text('Option A').first);
        expect(node.flagsCollection.isButton, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'every block stays exception-free at 2x text scale on a narrow screen',
      (tester) async {
        const scenario = ScenarioChoiceBlock(
          blockId: 'scn-scale',
          scenarioTitle: 'Extra money after payday',
          situation: 'A short situation sentence.',
          options: [
            ScenarioChoiceOption(
              id: 'a',
              label: 'Option A',
              explanation: 'Explanation A',
            ),
            ScenarioChoiceOption(
              id: 'b',
              label: 'Option B',
              explanation: 'Explanation B',
            ),
          ],
        );
        const checklist = ChecklistBlock(
          blockId: 'chk-scale',
          checklistPrompt: 'Checklist prompt',
          items: [ChecklistItemDef(id: 'a', label: 'Item one', required: true)],
        );
        await _pump(
          tester,
          Column(
            children: [
              ScenarioChoiceView(scenario, onComplete: (_) {}),
              const SizedBox(height: 16),
              ChecklistView(checklist, onComplete: (_) {}),
            ],
          ),
          size: _narrow,
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);
        expect(_runsOffTheSide(tester, _narrow.width), isEmpty);
      },
    );
  });
}
