// Pure-logic vectors for the interaction blocks the Money Courses Phase 6
// pilot introduces (content/interaction_blocks.dart: CategorizeBlock,
// ReadinessCardBlock, SalapifyActionsBlock), plus proof that
// money/interaction_completion.dart's existing gating helpers work
// correctly against the real "Are You Ready to Invest?" content, not just
// a fixture.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/money/interaction_completion.dart';

void main() {
  group('every pilot lesson\'s interactions are well formed', () {
    test('unique block ids within each lesson', () {
      for (final lesson in growYourMoneyLessons) {
        expect(
          hasUniqueBlockIds(lesson.interactionBlocks),
          isTrue,
          reason: '${lesson.id} has a duplicate interaction blockId',
        );
      }
    });

    test('at least one required interaction per lesson', () {
      for (final lesson in growYourMoneyLessons) {
        expect(requiredInteractionBlocks(lesson.interactionBlocks), isNotEmpty);
      }
    });
  });

  group('completion gating (money/interaction_completion.dart)', () {
    test('nothing is complete before any block fires onComplete', () {
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefMoneyJob,
      );
      expect(
        allRequiredInteractionsComplete(lesson.interactionBlocks, const {}),
        isFalse,
      );
      expect(
        outstandingRequiredInteractions(lesson.interactionBlocks, const {}),
        requiredInteractionBlocks(lesson.interactionBlocks),
      );
    });

    test('complete once every required block id is in the completed set', () {
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefMoneyJob,
      );
      final requiredIds = requiredInteractionBlocks(
        lesson.interactionBlocks,
      ).map((b) => b.blockId).toSet();
      expect(
        allRequiredInteractionsComplete(lesson.interactionBlocks, requiredIds),
        isTrue,
      );
    });

    test('an optional block never blocks completion on its own', () {
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefProtectBase,
      );
      final optional = lesson.interactionBlocks.where(
        (b) => !b.requiredForCompletion,
      );
      expect(
        optional,
        isNotEmpty,
        reason: 'fixture assumption: lesson 2 has an optional block',
      );
      final requiredIds = requiredInteractionBlocks(
        lesson.interactionBlocks,
      ).map((b) => b.blockId).toSet();
      // Completing every REQUIRED block, and none of the optional ones,
      // still counts as fully complete.
      expect(
        allRequiredInteractionsComplete(lesson.interactionBlocks, requiredIds),
        isTrue,
      );
    });

    test(
      'retrying (removing a block id) makes the lesson incomplete again',
      () {
        final lesson = growYourMoneyLessons.firstWhere(
          (l) => l.id == investRefMoneyJob,
        );
        final required = requiredInteractionBlocks(lesson.interactionBlocks);
        final completed = required.map((b) => b.blockId).toSet();
        expect(
          allRequiredInteractionsComplete(lesson.interactionBlocks, completed),
          isTrue,
        );
        completed.remove(required.first.blockId);
        expect(
          allRequiredInteractionsComplete(lesson.interactionBlocks, completed),
          isFalse,
        );
      },
    );
  });

  group('CategorizeBlock', () {
    CategorizeBlock categorizeBlockFor(String lessonId) {
      final lesson = growYourMoneyLessons.firstWhere((l) => l.id == lessonId);
      return lesson.interactionBlocks.whereType<CategorizeBlock>().first;
    }

    test('lesson 1 sort is valid: 2+ buckets, 2+ items, every item mapped', () {
      final block = categorizeBlockFor(investRefMoneyJob);
      expect(block.isValid, isTrue);
      expect(block.buckets.length, 3);
      expect(block.items.length, 4);
    });

    test('lesson 3 match is valid too', () {
      final block = categorizeBlockFor(investRefGoalTimeAccess);
      expect(block.isValid, isTrue);
    });

    test('an item mapped to a bucket that does not exist is invalid', () {
      final block = categorizeBlockFor(investRefMoneyJob);
      final broken = CategorizeBlock(
        blockId: block.blockId,
        categorizePrompt: block.categorizePrompt,
        buckets: block.buckets,
        items: block.items,
        correctBucketByItemId: {
          for (final i in block.items) i.id: 'not-a-real-bucket',
        },
      );
      expect(broken.isValid, isFalse);
    });
  });

  group('ReadinessCardBlock', () {
    ReadinessCardBlock readinessCard() {
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefCard,
      );
      return lesson.interactionBlocks.whereType<ReadinessCardBlock>().first;
    }

    test(
      'covers purpose, timing, contribution, buffer, debt, and max loss',
      () {
        final ids = readinessCard().fields.map((f) => f.id).toSet();
        expect(ids, {
          'purpose',
          'target-date',
          'contribution',
          'buffer',
          'debt',
          'max-loss',
        });
      },
    );

    test('every field offers at least two options', () {
      for (final field in readinessCard().fields) {
        expect(field.options.length, greaterThanOrEqualTo(2));
      }
    });

    test('two or more flagged answers reads as Foundation needs attention', () {
      final card = readinessCard();
      final answers = {
        for (final f in card.fields.take(2))
          f.id: f.options.firstWhere((o) => o.needsReview),
      };
      expect(
        ReadinessCardBlock.resultStyleFor(answers),
        'Foundation needs attention',
      );
    });

    test('exactly one flagged answer reads as Review these areas first', () {
      final card = readinessCard();
      final answers = <String, ReadinessCardOption>{};
      var flaggedOnce = false;
      for (final f in card.fields) {
        if (!flaggedOnce) {
          answers[f.id] = f.options.firstWhere((o) => o.needsReview);
          flaggedOnce = true;
        } else {
          answers[f.id] = f.options.firstWhere((o) => !o.needsReview);
        }
      }
      expect(
        ReadinessCardBlock.resultStyleFor(answers),
        'Review these areas first',
      );
    });

    test('no flagged answers reads as a defined starting plan', () {
      final card = readinessCard();
      final answers = {
        for (final f in card.fields)
          f.id: f.options.firstWhere((o) => !o.needsReview),
      };
      expect(
        ReadinessCardBlock.resultStyleFor(answers),
        'You have defined a starting plan',
      );
    });
  });

  group(
    'SalapifyActionsBlock: structurally incapable of an automatic write',
    () {
      test(
        'an action carries only a label, description, and route, nothing else',
        () {
          const action = SalapifyActionDef(
            id: 'x',
            label: 'Label',
            description: 'Description',
            route: 'goals',
          );
          // There is no field here a caller could use to run a store mutation:
          // only opaque strings the reader resolves through its own verified,
          // read-then-navigate switch (see
          // widgets/expansion_lesson_reader.dart's _resolveGrowAction).
          expect(action.route, isA<String>());
          expect(action.label, isA<String>());
          expect(action.description, isA<String>());
        },
      );

      test('the block is never required to finish the lesson', () {
        final lesson = growYourMoneyLessons.firstWhere(
          (l) => l.id == investRefCard,
        );
        final actionsBlock = lesson.interactionBlocks
            .whereType<SalapifyActionsBlock>()
            .first;
        expect(actionsBlock.requiredForCompletion, isFalse);
      });
    },
  );
}
