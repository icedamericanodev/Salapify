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

  /// Two to four choices (see [options] above). Checked here rather than
  /// with an assert in the constructor: Dart cannot const-evaluate a
  /// List.length check inside a const constructor, and every fixture in
  /// this codebase constructs these as const. A future authoring or test
  /// pipeline can check this the same way lesson_model.dart's
  /// KnowledgeCheck.isValid is already checked before a block is trusted.
  bool get isValid => options.length >= 2 && options.length <= 4;
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

  /// At least two items (see [items] above). See [ScenarioChoiceBlock.isValid]
  /// for why this is a getter rather than a constructor assert.
  bool get isValid => items.length >= 2;
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

  /// At least one item (see [items] above). See
  /// [ScenarioChoiceBlock.isValid] for why this is a getter rather than a
  /// constructor assert.
  bool get isValid => items.isNotEmpty;
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

  /// At least two items with unique ids (see [items] above): fewer than two
  /// makes [initialOrderIds]' "never already correct" guarantee meaningless,
  /// and a duplicate id would make one item indistinguishable from another
  /// when a move announces "moved to position N". See
  /// [ScenarioChoiceBlock.isValid] for why this is a getter rather than a
  /// constructor assert.
  bool get isValid =>
      items.length >= 2 &&
      items.map((i) => i.id).toSet().length == items.length;
}

// ---------------------------------------------------------------------------
// 6. Categorize (bucket sort)
// ---------------------------------------------------------------------------

class CategorizeBucket {
  final String id;
  final String label;
  const CategorizeBucket({required this.id, required this.label});
}

class CategorizeItemDef {
  final String id;
  final String label;

  /// Shown once this item has been assigned a bucket, whichever bucket was
  /// picked: the point is teaching why, not scoring a right answer.
  final String explanation;

  const CategorizeItemDef({
    required this.id,
    required this.label,
    required this.explanation,
  });
}

/// Assign each item to exactly one of a small set of buckets, by tapping a
/// bucket chip per item (never drag-only, so the block stays keyboard and
/// screen-reader operable). Distinct from [SortingBlock], which orders items
/// along a single line: this groups items into named categories, e.g.
/// sorting fictional goals into "Keep accessible", "Prepare first", and
/// "Consider for long-term investing".
class CategorizeBlock extends InteractionBlock {
  @override
  final String blockId;
  final String categorizePrompt;
  final List<CategorizeBucket> buckets;
  final List<CategorizeItemDef> items;

  /// The bucket id each item belongs in, keyed by [CategorizeItemDef.id].
  final Map<String, String> correctBucketByItemId;

  @override
  final bool requiredForCompletion;

  const CategorizeBlock({
    required this.blockId,
    required this.categorizePrompt,
    required this.buckets,
    required this.items,
    required this.correctBucketByItemId,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => categorizePrompt;

  @override
  String get instructions => 'For each item, choose the group it belongs in.';

  /// Two or more buckets, two or more items, and every item has a bucket
  /// named in [correctBucketByItemId] that actually exists in [buckets]. See
  /// [ScenarioChoiceBlock.isValid] for why this is a getter rather than a
  /// constructor assert.
  bool get isValid {
    if (buckets.length < 2 || items.length < 2) return false;
    final bucketIds = buckets.map((b) => b.id).toSet();
    return items.every((i) => bucketIds.contains(correctBucketByItemId[i.id]));
  }
}

// ---------------------------------------------------------------------------
// 7. Readiness card (a composite summary built from several small answers)
// ---------------------------------------------------------------------------

class ReadinessCardOption {
  final String id;
  final String label;

  /// True when picking this option should count as an area worth reviewing
  /// (an unfunded buffer, unreviewed expensive debt, an unclear answer)
  /// rather than a settled one, for [ReadinessCardBlock]'s own result-style
  /// rule. Never shown to the learner; used only to compute the summary.
  final bool needsReview;

  const ReadinessCardOption({
    required this.id,
    required this.label,
    this.needsReview = false,
  });
}

/// One question on the card, answered by picking exactly one option.
class ReadinessCardField {
  final String id;
  final String label;
  final List<ReadinessCardOption> options;

  const ReadinessCardField({
    required this.id,
    required this.label,
    required this.options,
  });
}

/// The Lesson 5 "Investment Readiness Card": a small set of single-choice
/// questions answered in the lesson session, folded into a reflection
/// summary with one of three result styles. Every answer stays local to this
/// widget's state and is never written to settings or a backup: this is an
/// educational reflection, not a stored profile (see the money-courses
/// expansion pilot's own privacy rule against storing a financial-risk
/// profile). [resultStyleFor] is the one place the three result strings are
/// decided, so the view and a test asserting the banned labels never appear
/// share one definition.
class ReadinessCardBlock extends InteractionBlock {
  @override
  final String blockId;
  final String cardTitle;
  final List<ReadinessCardField> fields;
  @override
  final bool requiredForCompletion;

  const ReadinessCardBlock({
    required this.blockId,
    required this.cardTitle,
    required this.fields,
    this.requiredForCompletion = true,
  });

  @override
  String get prompt => cardTitle;

  @override
  String get instructions =>
      'Answer each question. This builds a private summary on this screen '
      'only.';

  /// The result style for a completed set of answers, keyed by field id to
  /// the chosen option id. Never "Ready", "Approved", "Qualified", or
  /// "Suitable": this is a reflection summary, not an eligibility result or
  /// financial advice.
  static String resultStyleFor(Map<String, ReadinessCardOption> answers) {
    final reviewCount = answers.values.where((o) => o.needsReview).length;
    if (reviewCount >= 2) return 'Foundation needs attention';
    if (reviewCount == 1) return 'Review these areas first';
    return 'You have defined a starting plan';
  }

  /// At least one field, and every field has at least two options (see
  /// [ScenarioChoiceBlock.isValid] for why this is a getter).
  bool get isValid =>
      fields.isNotEmpty && fields.every((f) => f.options.length >= 2);
}

// ---------------------------------------------------------------------------
// 8. Salapify actions (verified in-app destinations, never an automatic
// write)
// ---------------------------------------------------------------------------

/// One offered in-app destination. [route] is resolved by the SAME kind of
/// closed switch content/lesson_model.dart's LessonAction already uses
/// (see widgets/expansion_lesson_reader.dart): an unresolvable route is
/// never shown as a button, so this can never be a dead tap.
class SalapifyActionDef {
  final String id;
  final String label;

  /// Shown before the tap, not only after: "explain what the action will
  /// do" per this phase's own rule. Always says the action only opens a
  /// screen and changes nothing by itself.
  final String description;
  final String route;

  const SalapifyActionDef({
    required this.id,
    required this.label,
    required this.description,
    required this.route,
  });
}

/// A short menu of verified Salapify destinations offered at the end of a
/// lesson, distinct from the single [LessonAction] the core 22 lessons use:
/// this phase's own task needs up to four offers in one lesson, not one.
/// Never required to finish a lesson, the same rule LessonAction already
/// follows: requiring it would push someone to open a screen they do not
/// need just to complete a lesson.
class SalapifyActionsBlock extends InteractionBlock {
  @override
  final String blockId;
  final String menuPrompt;
  final List<SalapifyActionDef> actions;
  @override
  final bool requiredForCompletion;

  const SalapifyActionsBlock({
    required this.blockId,
    required this.menuPrompt,
    required this.actions,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => menuPrompt;

  @override
  String get instructions =>
      'Each one opens a real Salapify screen. Nothing is created or changed '
      'until you act there yourself.';
}

// ---------------------------------------------------------------------------
// 9. Reflection
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

// ---------------------------------------------------------------------------
// 10. Loss-impact simulator
// ---------------------------------------------------------------------------

/// One fictional starting amount a learner can pick inside a
/// [LossImpactSimulatorBlock], in whole pesos.
class LossImpactAmountOption {
  final String id;
  final int amountPhp;
  final String label;

  const LossImpactAmountOption({
    required this.id,
    required this.amountPhp,
    required this.label,
  });
}

/// A deterministic, transparent-arithmetic portfolio-shock illustration:
/// choose a fictional starting amount, choose a loss scenario, see the
/// amount lost and the amount remaining. Added for Money Courses Phase 8
/// ("Crypto Without the Hype"), Lesson 2 ("Volatility and Possible Total
/// Loss"), and generic enough to reuse anywhere a course needs the same
/// shape of illustration.
///
/// Every number shown is computed live by
/// money/portfolio_shock_illustration.dart's portfolioShockImpact, basic
/// arithmetic only, never a forecast: this block carries no return
/// assumption, no compounding, and no claim that any one loss percentage is
/// likely. Selections are local widget state only, the same "never a stored
/// financial-risk profile" rule [ReadinessCardBlock] follows; nothing here
/// is persisted or backed up.
class LossImpactSimulatorBlock extends InteractionBlock {
  @override
  final String blockId;
  final String simulatorTitle;

  /// Shown above the two choice rows, framing what this illustrates and
  /// what it does not.
  final String introduction;

  /// Two or more fictional amounts to choose from.
  final List<LossImpactAmountOption> amountOptions;

  /// Loss scenarios offered, as whole-number percentages. This course always
  /// passes [30, 60, 100]; kept as a field, not hardcoded, so the block
  /// stays reusable for a different set of scenarios elsewhere.
  final List<int> lossPercentOptions;

  @override
  final bool requiredForCompletion;

  const LossImpactSimulatorBlock({
    required this.blockId,
    required this.simulatorTitle,
    required this.introduction,
    required this.amountOptions,
    this.lossPercentOptions = const [30, 60, 100],
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => simulatorTitle;

  @override
  String get instructions =>
      'Choose a fictional amount and a loss scenario to see the arithmetic.';

  /// At least two amount options and at least one loss scenario. See
  /// [ScenarioChoiceBlock.isValid] for why this is a getter rather than a
  /// constructor assert.
  bool get isValid =>
      amountOptions.length >= 2 && lossPercentOptions.isNotEmpty;
}

// ---------------------------------------------------------------------------
// 11. Risk-review checklist (a checklist whose live progress folds into a
// three-tier summary, never an eligibility label)
// ---------------------------------------------------------------------------

/// A checklist (reusing [ChecklistItemDef], the same items [ChecklistBlock]
/// authors) whose live checked count folds into one of three configurable
/// summary strings, ordered from earliest to most complete. Added for Money
/// Courses Phase 8 ("Crypto Without the Hype"), Lesson 6 ("The Crypto
/// Decision Lab"): a plain progress description, deliberately never one of
/// the banned eligibility words (ready, suitable, approved, qualified, safe
/// to invest), and never a recommendation to buy anything.
///
/// [items] is read as two ordered groups: the first [foundationCount] items
/// are the foundational checks (money already handled, before crypto enters
/// the picture at all); the rest are this course's own risk-understanding
/// checks. [summaryFor] never averages the two groups into one count: it
/// asks foundation first, exactly like [LessonSourceInfo]-style prerequisite
/// framing elsewhere in this course, so a learner who has not covered the
/// foundation sees that named specifically rather than a vague "some things
/// left".
class RiskReviewChecklistBlock extends InteractionBlock {
  @override
  final String blockId;
  final String checklistPrompt;
  final List<ChecklistItemDef> items;

  /// How many leading [items] belong to the foundational group. Must be
  /// strictly between 0 and [items.length] for [isValid] to hold, so both
  /// groups are non-empty.
  final int foundationCount;

  /// Shown while at least one foundational item is still unchecked.
  final String foundationSummary;

  /// Shown once every foundational item is checked but at least one
  /// remaining item is not.
  final String partialSummary;

  /// Shown once every item is checked.
  final String completeSummary;

  @override
  final bool requiredForCompletion;

  const RiskReviewChecklistBlock({
    required this.blockId,
    required this.checklistPrompt,
    required this.items,
    required this.foundationCount,
    required this.foundationSummary,
    required this.partialSummary,
    required this.completeSummary,
    this.requiredForCompletion = false,
  });

  @override
  String get prompt => checklistPrompt;

  @override
  String get instructions =>
      'Check off each item, honestly, as it applies right now.';

  /// The ids of the foundational group, in order.
  List<String> get foundationItemIds =>
      items.take(foundationCount).map((i) => i.id).toList();

  /// The summary for a given set of checked item ids. Pure and stateless, so
  /// a test can call this directly without building the widget.
  String summaryFor(Set<String> checkedIds) {
    final allIds = items.map((i) => i.id).toSet();
    if (!foundationItemIds.every(checkedIds.contains)) {
      return foundationSummary;
    }
    if (!allIds.every(checkedIds.contains)) return partialSummary;
    return completeSummary;
  }

  /// At least one item in each group (see [foundationCount] above). See
  /// [ScenarioChoiceBlock.isValid] for why this is a getter rather than a
  /// constructor assert.
  bool get isValid =>
      items.isNotEmpty && foundationCount > 0 && foundationCount < items.length;
}
