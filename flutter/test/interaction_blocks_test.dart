// Model-level tests for the Phase 5 interaction blocks
// (lib/content/interaction_blocks.dart) and their pure completion gate
// (lib/money/interaction_completion.dart). No Flutter widgets here: these
// are the same "malformed input drops rather than renders" and "pure fold,
// no system clock" disciplines the rest of lib/content and lib/money already
// carry, checked without a widget tester.
//
// Every fixture below is built for this file only. Nothing here registers a
// production Money Courses lesson, per this phase's own instruction.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/money/interaction_completion.dart';

void main() {
  group('ScenarioChoiceBlock', () {
    const block = ScenarioChoiceBlock(
      blockId: 'scn-1',
      scenarioTitle: 'Extra money after payday',
      situation:
          'You have one month of emergency savings and expensive '
          'credit-card debt. Where should additional money go first?',
      options: [
        ScenarioChoiceOption(
          id: 'save-more',
          label: 'Keep building the emergency fund',
          explanation:
              'That works if losing income right now would be the bigger '
              'problem for you.',
        ),
        ScenarioChoiceOption(
          id: 'pay-debt',
          label: 'Pay down the credit card',
          explanation:
              'That works because the card is likely charging more in '
              'interest than the emergency fund could realistically earn.',
        ),
      ],
      preferredOptionId: 'pay-debt',
    );

    test('exposes the shared contract fields', () {
      expect(block.blockId, 'scn-1');
      expect(block.prompt, block.scenarioTitle);
      expect(block.instructions, isNotEmpty);
      expect(block.requiredForCompletion, isFalse);
    });

    test('supports a scenario with no single correct answer', () {
      const openScenario = ScenarioChoiceBlock(
        blockId: 'scn-2',
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
      expect(openScenario.preferredOptionId, isNull);
    });

    test(
      'carries an optional risk note built from the existing RiskWarningBlock',
      () {
        const withRisk = ScenarioChoiceBlock(
          blockId: 'scn-3',
          scenarioTitle: 'Borrowing to invest',
          situation: 'A friend suggests borrowing to invest in a fund.',
          options: [
            ScenarioChoiceOption(id: 'a', label: 'Do it', explanation: 'x'),
            ScenarioChoiceOption(id: 'b', label: 'Skip it', explanation: 'y'),
          ],
          riskNote: RiskWarningBlock(
            title: 'Borrowed money is still owed',
            text:
                'If the investment loses value, the loan does not shrink with it.',
          ),
        );
        expect(withRisk.riskNote, isNotNull);
        expect(withRisk.riskNote!.title, 'Borrowed money is still owed');
      },
    );
  });

  group('MythOrFactBlock', () {
    const block = MythOrFactBlock(
      blockId: 'myth-1',
      statement: 'A regulated investment cannot lose money.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Regulation checks that a provider follows the rules; it does not '
          'remove market risk.',
      officialSource: LessonSourceInfo(
        agency: 'Securities and Exchange Commission',
        title: 'Investor protection guide',
        canonicalUrl: 'https://www.sec.gov.ph/investor-guide',
      ),
    );

    test('the fixture statement resolves to Myth', () {
      expect(block.correctAnswer, MythOrFactAnswer.myth);
      expect(block.explanation, isNotEmpty);
    });

    test('official source is optional', () {
      const noSource = MythOrFactBlock(
        blockId: 'myth-2',
        statement: 'Filing an income tax return is always required.',
        correctAnswer: MythOrFactAnswer.myth,
        explanation:
            'Some earners are exempt or covered by substituted filing.',
      );
      expect(noSource.officialSource, isNull);
    });
  });

  group('ComparisonBlock', () {
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

    test('a missing value resolves to "Not provided", never null', () {
      final item = block.items.last;
      expect(item.valueFor('liquidity'), 'Not provided');
      expect(item.valueFor('fees'), 'Not provided');
    });

    test('a blank string also resolves to "Not provided"', () {
      const item = ComparisonItem(
        id: 'c',
        name: 'Sample Blank Fund',
        valuesByCriterionId: {'liquidity': '   '},
      );
      expect(item.valueFor('liquidity'), 'Not provided');
    });
  });

  group('ChecklistBlock and completion gating', () {
    const block = ChecklistBlock(
      blockId: 'chk-1',
      checklistPrompt: 'Before you start',
      items: [
        ChecklistItemDef(id: 'a', label: 'Read the summary', required: true),
        ChecklistItemDef(
          id: 'b',
          label: 'Optional: read the FAQ',
          required: false,
        ),
      ],
      requiredForCompletion: true,
    );

    test('required and optional items are both representable', () {
      expect(block.items.where((i) => i.required).length, 1);
      expect(block.items.where((i) => !i.required).length, 1);
    });

    test(
      'allRequiredInteractionsComplete stays false until the required block id is present',
      () {
        final blocks = <InteractionBlock>[block];
        expect(allRequiredInteractionsComplete(blocks, {}), isFalse);
        expect(allRequiredInteractionsComplete(blocks, {'chk-1'}), isTrue);
      },
    );

    test(
      'a non-required block never appears in outstandingRequiredInteractions',
      () {
        const optional = ChecklistBlock(
          blockId: 'chk-2',
          checklistPrompt: 'Nice to know',
          items: [ChecklistItemDef(id: 'a', label: 'Skim this')],
          requiredForCompletion: false,
        );
        final outstanding = outstandingRequiredInteractions([
          block,
          optional,
        ], {});
        expect(outstanding.map((b) => b.blockId), ['chk-1']);
      },
    );
  });

  group('SortingBlock', () {
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

    test('the initial order is a permutation of the target order', () {
      final target = block.items.map((i) => i.id).toSet();
      expect(block.initialOrderIds.toSet(), target);
      expect(block.initialOrderIds.length, block.items.length);
    });

    test('the initial order is never already the target order', () {
      expect(
        block.initialOrderIds,
        isNot(block.items.map((i) => i.id).toList()),
      );
    });
  });

  group('ReflectionPromptBlock', () {
    test('is skippable exactly when it is not required', () {
      const optional = ReflectionPromptBlock(
        blockId: 'ref-1',
        question: 'What is one habit you want to try this week?',
      );
      const required = ReflectionPromptBlock(
        blockId: 'ref-2',
        question: 'What is one habit you want to try this week?',
        requiredForCompletion: true,
      );
      expect(optional.isSkippable, isTrue);
      expect(required.isSkippable, isFalse);
    });

    test('carries a privacy note whenever free text is allowed', () {
      const block = ReflectionPromptBlock(
        blockId: 'ref-3',
        question: 'Anything on your mind about this?',
        allowFreeText: true,
      );
      expect(block.privacyNote, isNotEmpty);
    });
  });

  group('allRequiredInteractionsComplete across mixed block kinds', () {
    test('every required block must complete, not just one of them', () {
      const scenario = ScenarioChoiceBlock(
        blockId: 'scn-req',
        scenarioTitle: 'Required scenario',
        situation: 'x',
        options: [
          ScenarioChoiceOption(id: 'a', label: 'A', explanation: 'x'),
          ScenarioChoiceOption(id: 'b', label: 'B', explanation: 'y'),
        ],
        requiredForCompletion: true,
      );
      const myth = MythOrFactBlock(
        blockId: 'myth-req',
        statement: 'x',
        correctAnswer: MythOrFactAnswer.fact,
        explanation: 'x',
        requiredForCompletion: true,
      );
      const optionalReflection = ReflectionPromptBlock(
        blockId: 'ref-opt',
        question: 'Optional reflection',
      );
      final blocks = <InteractionBlock>[scenario, myth, optionalReflection];

      expect(allRequiredInteractionsComplete(blocks, {}), isFalse);
      expect(allRequiredInteractionsComplete(blocks, {'scn-req'}), isFalse);
      expect(
        allRequiredInteractionsComplete(blocks, {'scn-req', 'myth-req'}),
        isTrue,
      );
      // The optional reflection never has to appear in the set.
      expect(
        outstandingRequiredInteractions(blocks, {'scn-req', 'myth-req'}),
        isEmpty,
      );
    });
  });
}
