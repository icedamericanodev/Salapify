// Reusable interaction blocks for future Money Courses expansion paths
// (Grow Your Money, Protect Your Future, Build Your Business), Phase 5 of
// the expansion: docs/money_courses_expansion_audit.md.
//
// This is deliberately a SEPARATE sealed hierarchy from LessonBlock
// (content/lesson_blocks.dart), not an extension of it. LessonBlock's own
// switch in widgets/lesson_block_views.dart is exhaustive over the nine
// kinds the 22 shipped lessons already use, and every one of those blocks is
// either static prose or, at most, a single reveal tracked by one
// lesson-wide callback. An interaction block needs more: a stable id so one
// specific interaction can be told apart from every other one in the same
// lesson, an explicit requiredForCompletion flag, and its own completion
// event distinct from merely being opened or scrolled past. Folding that
// contract onto LessonBlock would either weaken it for the nine existing
// kinds or force every one of them to carry fields they never use. Kept
// separate, so none of the 22 shipped lessons or their blocks change shape.
//
// No production lesson registers any of these yet, and none is expected to
// in this phase: see the phase's own instruction to use test fixtures only.
// A future expansion-path lesson type can compose these once real content
// exists to review them against.
//
// Completion is enforced by money/interaction_completion.dart, a small pure
// helper, not a second progress engine: it never touches
// money/lesson_progress.dart or settings.expansionProgress, it only answers
// "have the required blocks in this list each fired their own onComplete".

import 'lesson_blocks.dart' show RiskWarningBlock;
import 'lesson_model.dart' show LessonSourceInfo;

/// The shared contract every interaction block satisfies. Not called
/// InteractionBlock's superclass by accident: keeping the field surface tiny
/// and explicit is what stops this from growing into a generic form engine.
sealed class InteractionBlock {
  /// Stable within one lesson, unique by convention (the same discipline
  /// MoneyLesson.id and CourseTrack.id already use). This is what
  /// money/interaction_completion.dart keys a completed set by.
  String get blockId;

  /// The question or task shown to the learner.
  String get prompt;

  /// Accessible instructions read out alongside [prompt]: HOW to interact
  /// ("Choose one option", "Use the move up and move down buttons"), not
  /// what the block is called.
  String get instructions;

  /// Whether this interaction must be completed before an expansion lesson
  /// containing it can be marked complete. Opening or viewing the block
  /// never satisfies this; only the view's own onComplete callback does.
  bool get requiredForCompletion;

  const InteractionBlock();
}

// ---------------------------------------------------------------------------
// 1. Scenario choice
// ---------------------------------------------------------------------------

/// One option inside a [ScenarioChoiceBlock].
class ScenarioChoiceOption {
  final String id;
  final String label;

  /// Shown after this option is picked. Always trade-off language ("that
  /// works for this scenario because...", "either option may work, but..."),
  /// never a bare "Correct" or "Wrong": see widgets/interaction_block_views.dart's
  /// InteractionFeedbackCard, which this explanation is rendered inside.
  final String explanation;

  const ScenarioChoiceOption({
    required this.id,
    required this.label,
    required this.explanation,
  });
}

/// A short situation with two to four choices, each with its own trade-off
/// explanation. Some scenarios have one option the lesson leans toward
/// ([preferredOptionId]); many legitimately do not, and the block reads the
/// same way either way, never as a graded quiz.
class ScenarioChoiceBlock extends InteractionBlock {
  @override
  final String blockId;
  final String scenarioTitle;
  final String situation;

  /// Two to four choices, each with a stable id.
  final List<ScenarioChoiceOption> options;

  /// The option this scenario leans toward, if any. Null means the scenario
  /// has no single correct answer and every option's explanation stands on
  /// its own, unranked.
  final String? preferredOptionId;

  /// An optional caution shown once an option is picked, reusing the same
  /// RiskWarningBlock/RiskWarningView Phase 2 already ships rather than a
  /// second warning card type.
  final RiskWarningBlock? riskNote;

  @override
  final bool requiredForCompletion;

  // Two to four choices is a content-authoring rule (see [options] above),
  // not an assert here: Dart cannot const-evaluate a List.length check in a
  // const constructor, and every fixture in this codebase constructs these
  // as const.
  const ScenarioChoiceBlock({
    required this.blockId,
    required this.scenarioTitle,
    required this.situation,
    required this.options,
    this.preferredOptionId,
    this.riskNote,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => scenarioTitle;

  @override
  String get instructions =>
      'Read the situation, then choose the option you would take.';
}

// ---------------------------------------------------------------------------
// 2. Myth or fact
// ---------------------------------------------------------------------------

enum MythOrFactAnswer { myth, fact }

/// A single true-or-false-shaped statement with an always-shown explanation.
/// [officialSource] reuses [LessonSourceInfo] (content/lesson_model.dart)
/// rather than a new citation type; the view renders it through the same
/// OfficialSourceView Phase 2 already ships.
class MythOrFactBlock extends InteractionBlock {
  @override
  final String blockId;
  final String statement;
  final MythOrFactAnswer correctAnswer;
  final String explanation;
  final LessonSourceInfo? officialSource;
  @override
  final bool requiredForCompletion;

  const MythOrFactBlock({
    required this.blockId,
    required this.statement,
    required this.correctAnswer,
    required this.explanation,
    this.officialSource,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => statement;

  @override
  String get instructions => 'Choose Myth or Fact, then read why.';
}

// ---------------------------------------------------------------------------
// 3. Comparison
// ---------------------------------------------------------------------------

class ComparisonCriterion {
  final String id;
  final String label;
  const ComparisonCriterion({required this.id, required this.label});
}

/// One product or option in a [ComparisonBlock]. [valuesByCriterionId] is
/// keyed by [ComparisonCriterion.id]; a missing or blank entry renders as
/// "Not provided" in the view, never the literal word "null".
class ComparisonItem {
  final String id;
  final String name;
  final Map<String, String> valuesByCriterionId;

  /// An optional per-item caution, rendered through the same RiskWarningView
  /// every other caution in a lesson uses.
  final String? caution;

  const ComparisonItem({
    required this.id,
    required this.name,
    this.valuesByCriterionId = const {},
    this.caution,
  });

  /// The value for one criterion, or "Not provided" when missing, blank, or
  /// whitespace only. The single place that decides this so the view and any
  /// test asserting "no visible null" agree on one definition.
  String valueFor(String criterionId) {
    final v = valuesByCriterionId[criterionId];
    return (v == null || v.trim().isEmpty) ? 'Not provided' : v.trim();
  }
}

/// Two or more items compared across a shared set of criteria. Never labels
/// one option "Best": the view has no such badge, and nothing in this model
/// ranks items against each other.
class ComparisonBlock extends InteractionBlock {
  @override
  final String blockId;
  final String title;
  final List<ComparisonCriterion> criteria;
  final List<ComparisonItem> items;
  @override
  final bool requiredForCompletion;

  // At least two items is a content-authoring rule (see [items] above), not
  // an assert: Dart cannot const-evaluate a List.length check here, and
  // every fixture in this codebase constructs these as const.
  const ComparisonBlock({
    required this.blockId,
    required this.title,
    required this.criteria,
    required this.items,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => title;

  @override
  String get instructions => 'Compare each option across the criteria below.';
}

// ---------------------------------------------------------------------------
// 4. Checklist
// ---------------------------------------------------------------------------

class ChecklistItemDef {
  final String id;
  final String label;
  final String? explanation;
  final bool required;

  const ChecklistItemDef({
    required this.id,
    required this.label,
    this.explanation,
    this.required = true,
  });
}

/// An interactive checklist. Checked state is local to the lesson session
/// (see the phase's own "keep answers local" rule): nothing here is
/// persisted or backed up.
class ChecklistBlock extends InteractionBlock {
  @override
  final String blockId;
  final String checklistPrompt;
  final List<ChecklistItemDef> items;

  /// When true, the block only registers as complete once every item marked
  /// [ChecklistItemDef.required] is checked. When false, checking any one
  /// item is enough, an informational checklist with no hard "all done"
  /// rule.
  final bool allRequiredMustBeChecked;

  @override
  final bool requiredForCompletion;

  // At least one item is a content-authoring rule (see [items] above), not
  // an assert: Dart cannot const-evaluate a List.length check here, and
  // every fixture in this codebase constructs these as const.
  const ChecklistBlock({
    required this.blockId,
    required this.checklistPrompt,
    required this.items,
    this.allRequiredMustBeChecked = true,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => checklistPrompt;

  @override
  String get instructions => 'Check off each item as you complete it.';
}

// ---------------------------------------------------------------------------
// 5. Sorting / sequencing
// ---------------------------------------------------------------------------

class SortingItemDef {
  final String id;
  final String label;
  final String? explanation;

  const SortingItemDef({
    required this.id,
    required this.label,
    this.explanation,
  });
}

/// Arrange items into a target order using Move Up / Move Down controls
/// (never drag-and-drop only, so the block stays keyboard and screen-reader
/// operable).
class SortingBlock extends InteractionBlock {
  @override
  final String blockId;
  final String sortingPrompt;

  /// Authored in the CORRECT, target order.
  final List<SortingItemDef> items;
  @override
  final bool requiredForCompletion;

  // At least two items is a content-authoring rule (see [items] above), not
  // an assert: Dart cannot const-evaluate a List.length check here, and
  // every fixture in this codebase constructs these as const.
  const SortingBlock({
    required this.blockId,
    required this.sortingPrompt,
    required this.items,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => sortingPrompt;

  @override
  String get instructions =>
      'Use the move up and move down buttons to put these in order, then submit.';

  /// The starting order shown before the learner touches anything: the
  /// target order reversed. Deterministic on purpose, no randomness, so the
  /// same block starts in the same scrambled state on every phone and in
  /// every test, and (for two or more items) is never already correct.
  List<String> get initialOrderIds =>
      items.map((i) => i.id).toList().reversed.toList();
}

// ---------------------------------------------------------------------------
// 6. Reflection
// ---------------------------------------------------------------------------

class ReflectionChoice {
  final String id;
  final String label;
  const ReflectionChoice({required this.id, required this.label});
}

/// A lightweight reflection prompt, distinct from the existing static
/// ReflectionBlock in content/lesson_blocks.dart (a single always-last
/// takeaway sentence with no interaction). This one is interactive: an
/// optional set of predefined choices, an optional short free-text field
/// that is never persisted, and a skip option whenever the reflection is not
/// required.
class ReflectionPromptBlock extends InteractionBlock {
  @override
  final String blockId;
  final String question;
  final List<ReflectionChoice> choices;
  final bool allowFreeText;

  /// Shown next to the free-text field whenever [allowFreeText] is true.
  /// This phase never stores what is typed, in this field or anywhere else.
  final String privacyNote;

  @override
  final bool requiredForCompletion;

  const ReflectionPromptBlock({
    required this.blockId,
    required this.question,
    this.choices = const [],
    this.allowFreeText = false,
    this.privacyNote =
        'This stays on your screen only. It is never saved, backed up, or sent anywhere.',
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => question;

  @override
  String get instructions => requiredForCompletion
      ? 'Answer to continue.'
      : 'Answer if you would like to, or skip.';

  /// A skip control is offered exactly when the reflection is not required.
  bool get isSkippable => !requiredForCompletion;
}
