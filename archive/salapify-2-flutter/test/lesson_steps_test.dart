// Guards for money/lesson_steps.dart: where a lesson breaks into screens.
//
// Proven to fail before being trusted; the failure lines are in the commit
// message.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/money/lesson_steps.dart';

MoneyLesson _lesson({
  List<LessonBlock> blocks = const [],
  List<InteractionBlock> interactions = const [],
  KnowledgeCheck? check,
}) => MoneyLesson(
  id: 'x',
  trackId: 't',
  title: 'T',
  icon: 'growth',
  minutes: 1,
  summary: 's',
  objective: 'o',
  sections: const [],
  authoredBlocks: blocks,
  interactionBlocks: interactions,
  check: check,
);

const _myth = MythOrFactBlock(
  blockId: 'm1',
  statement: 's',
  correctAnswer: MythOrFactAnswer.myth,
  explanation: 'e',
  requiredForCompletion: true,
);

const _optional = MythOrFactBlock(
  blockId: 'm2',
  statement: 's',
  correctAnswer: MythOrFactAnswer.fact,
  explanation: 'e',
);

void main() {
  group('prose splitting', () {
    test('a long prose block becomes several steps', () {
      final steps = stepsForLesson(
        _lesson(
          blocks: [
            ProseBlock(heading: 'H', paragraphs: ['a', 'b', 'c', 'd', 'e']),
          ],
        ),
      );
      // 5 paragraphs at 2 per step is 3 steps, plus the finish step.
      expect(steps.length, 4);
      expect(steps.last, isA<FinishStep>());
    });

    test('the heading rides only the first step', () {
      final steps = stepsForLesson(
        _lesson(
          blocks: [
            ProseBlock(heading: 'WHY IT MATTERS', paragraphs: ['a', 'b', 'c']),
          ],
        ),
      );
      final prose = [
        for (final s in steps)
          if (s is BlockStep && s.block is ProseBlock) s.block as ProseBlock,
      ];
      expect(prose.first.heading, 'WHY IT MATTERS');
      expect(
        prose.skip(1).every((p) => p.heading.isEmpty),
        isTrue,
        reason: 'a repeated heading reads as though the lesson restarted',
      );
    });

    test('no prose step carries more than the cap', () {
      final steps = stepsForLesson(
        _lesson(
          blocks: [ProseBlock(paragraphs: List.generate(7, (i) => 'p$i'))],
        ),
      );
      for (final s in steps) {
        if (s is BlockStep && s.block is ProseBlock) {
          expect(
            (s.block as ProseBlock).paragraphs.length,
            lessThanOrEqualTo(maxParagraphsPerStep),
          );
        }
      }
    });

    test('every paragraph survives the split, in order', () {
      final original = List.generate(7, (i) => 'p$i');
      final steps = stepsForLesson(
        _lesson(blocks: [ProseBlock(paragraphs: original)]),
      );
      final seen = [
        for (final s in steps)
          if (s is BlockStep && s.block is ProseBlock)
            ...(s.block as ProseBlock).paragraphs,
      ];
      expect(seen, original, reason: 'pagination must not lose a paragraph');
    });
  });

  group('step composition', () {
    test('each interaction gets its own step', () {
      final steps = stepsForLesson(
        _lesson(interactions: const [_myth, _optional]),
      );
      expect(steps.whereType<InteractionStep>().length, 2);
    });

    test('the check becomes one step, and only when present', () {
      expect(stepsForLesson(_lesson()).whereType<CheckStep>(), isEmpty);
      final withCheck = stepsForLesson(
        _lesson(
          check: const KnowledgeCheck(
            question: 'q',
            choices: ['a', 'b', 'c'],
            correctIndex: 0,
            explanation: 'e',
          ),
        ),
      );
      expect(withCheck.whereType<CheckStep>().length, 1);
    });

    test('citations never take a step, they ride the finish', () {
      final steps = stepsForLesson(
        _lesson(
          blocks: const [
            ProseBlock(paragraphs: ['a']),
            OfficialSourceBlock(
              agency: 'A',
              sourceTitle: 'T',
              canonicalUrl: 'https://example.test/',
            ),
            EducationalBoundaryBlock(),
          ],
        ),
      );
      expect(
        steps.whereType<BlockStep>().length,
        1,
        reason: 'a citation must not get a screen of its own mid lesson',
      );
      final finish = steps.last as FinishStep;
      expect(finish.reference.length, 2);
    });

    test('a lesson always ends in exactly one finish step', () {
      for (final l in [
        _lesson(),
        _lesson(interactions: const [_myth]),
      ]) {
        final steps = stepsForLesson(l);
        expect(steps.last, isA<FinishStep>());
        expect(steps.whereType<FinishStep>().length, 1);
      }
    });
  });

  group('gating', () {
    test('a required interaction gates progress', () {
      expect(stepGatesProgress(const InteractionStep(_myth)), isTrue);
    });

    test('an optional interaction does not', () {
      expect(stepGatesProgress(const InteractionStep(_optional)), isFalse);
    });

    test('reading and the quiz never gate', () {
      expect(
        stepGatesProgress(const BlockStep(ProseBlock(paragraphs: ['a']))),
        isFalse,
      );
      expect(
        stepGatesProgress(
          const CheckStep(
            KnowledgeCheck(
              question: 'q',
              choices: ['a', 'b', 'c'],
              correctIndex: 0,
              explanation: 'e',
            ),
          ),
        ),
        isFalse,
        reason: 'a quiz teaches, it does not lock a door',
      );
    });
  });

  group('against real shipped content', () {
    test('the longest crypto lesson becomes many screens, not one', () {
      final l = cryptoWithoutHypeLessons.firstWhere(
        (x) => x.id == cryptoRefScamsProviderVerification,
      );
      expect(
        stepsForLesson(l).length,
        greaterThan(6),
        reason: 'this is the wall of text the whole change exists for',
      );
    });

    test('every Grow lesson paginates and ends correctly', () {
      for (final l in growYourMoneyLessons) {
        final steps = stepsForLesson(l);
        expect(steps.length, greaterThan(1), reason: l.id);
        expect(steps.last, isA<FinishStep>(), reason: l.id);
      }
    });
  });
}
