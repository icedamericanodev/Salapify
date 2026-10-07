// Turning a lesson into steps: one idea per screen.
//
// The experience audit's central structural finding was that an 824 word
// expansion lesson renders as a single scroll, so reading one feels like
// reading an article rather than doing something. This file decides where
// the breaks go. The reader (widgets/paged_lesson_reader.dart) only walks
// the list this produces.
//
// Pure Dart, no Flutter import, the same discipline as the rest of
// lib/money, which is what lets the whole pagination decision be tested
// without pumping a widget.
//
// What this deliberately does NOT do: interleave exercises among the prose.
// The audit is right that practice landing after all the reading is the
// weakest placement, but nothing in the content says WHICH idea a given
// exercise tests, so any automatic interleaving would be a guess dressed up
// as pedagogy. Splitting the scroll into steps is the honest half of that
// change and needs no content edits; real interleaving waits until a lesson
// can declare where its exercises belong.

import '../content/interaction_blocks.dart';
import '../content/lesson_blocks.dart';
import '../content/lesson_model.dart';

/// Most paragraphs a single prose step may carry.
///
/// Two, not one. A single paragraph per screen turns a four paragraph idea
/// into four taps and makes the lesson feel padded, which is its own kind of
/// tedium; two keeps a screen readable on a phone without splitting a
/// thought that was written as a pair.
const int maxParagraphsPerStep = 2;

sealed class LessonStep {
  const LessonStep();
}

/// One or two paragraphs, or one whole non-prose block.
class BlockStep extends LessonStep {
  final LessonBlock block;
  const BlockStep(this.block);
}

/// One exercise, alone on its screen so it cannot be scrolled past.
class InteractionStep extends LessonStep {
  final InteractionBlock block;
  const InteractionStep(this.block);
}

/// The knowledge check.
class CheckStep extends LessonStep {
  final KnowledgeCheck check;
  const CheckStep(this.check);
}

/// The end: the finish card, and the collapsed citations underneath it.
class FinishStep extends LessonStep {
  /// Citations and the boundary statement, which never take a step of their
  /// own. They are reference material, and giving them a full screen in the
  /// middle of a lesson is precisely the interruption Batch 2 removed.
  final List<LessonBlock> reference;
  const FinishStep(this.reference);
}

/// Split a prose block into steps of at most [maxParagraphsPerStep]
/// paragraphs, keeping the heading on the FIRST step only.
///
/// The heading names the idea, so repeating it above every continuation
/// screen would read as though the lesson had restarted.
List<BlockStep> _proseSteps(ProseBlock b) {
  final out = <BlockStep>[];
  for (var i = 0; i < b.paragraphs.length; i += maxParagraphsPerStep) {
    final end = (i + maxParagraphsPerStep).clamp(0, b.paragraphs.length);
    out.add(
      BlockStep(
        ProseBlock(
          heading: i == 0 ? b.heading : '',
          paragraphs: b.paragraphs.sublist(i, end),
        ),
      ),
    );
  }
  return out;
}

/// True for a block that proves rather than teaches, the same split
/// widgets/lesson_block_views.dart's own isReferenceBlock draws. Duplicated
/// here as a pure predicate rather than imported, because this file must
/// stay free of any Flutter import.
bool isReferenceLessonBlock(LessonBlock b) =>
    b is OfficialSourceBlock || b is EducationalBoundaryBlock;

/// Every screen of [lesson], in order.
///
/// Always ends with exactly one [FinishStep], so a reader can rely on the
/// last step being the end without checking what kind it is.
List<LessonStep> stepsForLesson(MoneyLesson lesson) {
  final steps = <LessonStep>[];
  final reference = <LessonBlock>[];

  for (final b in lesson.blocks) {
    if (isReferenceLessonBlock(b)) {
      reference.add(b);
      continue;
    }
    if (b is ProseBlock) {
      steps.addAll(_proseSteps(b));
    } else {
      steps.add(BlockStep(b));
    }
  }

  for (final b in lesson.interactionBlocks) {
    steps.add(InteractionStep(b));
  }

  final check = lesson.check;
  if (check != null) steps.add(CheckStep(check));

  steps.add(FinishStep(reference));
  return steps;
}

/// Whether a step must be completed before the reader may move on.
///
/// Only a required interaction gates. Reading never gates, and the knowledge
/// check never gates, matching the rule both existing readers already
/// follow: a quiz is there to teach, not to lock a door.
bool stepGatesProgress(LessonStep step) =>
    step is InteractionStep && step.block.requiredForCompletion;
