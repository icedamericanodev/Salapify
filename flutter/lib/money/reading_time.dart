// How long a lesson actually takes, as opposed to how long it says it takes.
//
// The declared `minutes` on each lesson is authored by hand, and the
// experience audit measured how far that had drifted on the long expansion
// lessons: one lesson labelled 6 minutes carries 1,379 words plus an eight
// by eight categorize grid plus two more exercises, which is nearer thirteen.
// A time promise the app breaks on every lesson teaches people to distrust
// every number in the app, including the ones about their money.
//
// So the reader shows a COMPUTED estimate instead. Two deliberate choices,
// both on the honest side:
//
// 1. It never shows LESS than the authored figure (see [displayMinutes]).
//    The author may know something this file cannot, and rounding a lesson
//    down is the exact failure being fixed.
// 2. Exercise text is COUNTED, not waved at. The first version of this file
//    used a flat per-interaction allowance and came out visibly wrong: the
//    lesson the whole fix exists for still estimated at its authored six
//    minutes, because an eight by eight grid of labels and explanations was
//    invisible to the counter. An exercise is not a pause in the reading,
//    it is reading, and often the densest reading in the lesson. Only the
//    tapping itself is a flat allowance now.
//
// Pure Dart, no Flutter import, same discipline as the rest of lib/money.

import '../content/interaction_blocks.dart';
import '../content/lesson_blocks.dart';
import '../content/lesson_model.dart';

/// Words per minute, the ordinary adult silent-reading rate.
///
/// Left at the standard figure rather than slowed to make lessons look
/// longer. The estimate now counts the exercise text (see
/// [_interactionWords]), which is where the missing minutes actually were,
/// so the reading rate does not have to be bent to compensate for a gap in
/// the counting. Bending it would also have quietly moved the core 22, whose
/// authored figures the audit found accurate.
const int wordsPerMinute = 200;

/// Seconds allowed per interaction block for the DOING, on top of reading
/// its text: choosing, tapping, changing your mind.
const int secondsPerInteraction = 20;

int _words(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// Every word a reader actually reads in one block.
int _blockWords(LessonBlock b) => switch (b) {
  ProseBlock() =>
    _words(b.heading) + b.paragraphs.fold<int>(0, (a, p) => a + _words(p)),
  NuggetsBlock() => b.items.fold<int>(0, (a, i) => a + _words(i)),
  DiscoveryBlock() => _words(b.question) + _words(b.reveal),
  StoryBlock() => _words(b.who) + _words(b.text),
  DiagramBlock() =>
    b.steps.fold<int>(0, (a, s) => a + _words(s)) + _words(b.caption),
  TrapBlock() => _words(b.mostPeople) + _words(b.worksBetter),
  ChallengeBlock() => _words(b.prompt) + _words(b.compare),
  RulesBlock() => b.passages.fold<int>(0, (a, p) => a + _words(p)),
  ReflectionBlock() => _words(b.line),
  // Reference material, and since Batch 2 it sits collapsed behind one line
  // at the end of the lesson. A reader who never opens it never reads it, so
  // counting it would inflate every regulated lesson's estimate by a
  // paragraph nobody was made to read.
  OfficialSourceBlock() => 0,
  EducationalBoundaryBlock() => 0,
  RiskWarningBlock() => _words(b.title) + _words(b.text),
};

/// Every word a reader meets inside one interaction block: the prompt, every
/// option they weigh, and the explanation they read afterwards.
///
/// This is counted rather than waved at with a flat allowance, because the
/// first version of this file did wave at it and came out visibly wrong: the
/// lesson the whole fix exists for, "Risks and Scam Checks", still estimated
/// at its authored 6 minutes because its eight by eight grid of labels and
/// explanations was invisible to the counter. An exercise is not a pause in
/// the reading, it IS reading, and quite often the densest reading in the
/// lesson.
///
/// Exhaustive over the sealed type on purpose: a new interaction block
/// becomes a compile error here rather than silently counting as zero.
int _interactionWords(InteractionBlock b) => switch (b) {
  ScenarioChoiceBlock() =>
    _words(b.scenarioTitle) +
        _words(b.situation) +
        b.options.fold<int>(
          0,
          (a, o) => a + _words(o.label) + _words(o.explanation),
        ),
  MythOrFactBlock() => _words(b.statement) + _words(b.explanation),
  ComparisonBlock() =>
    _words(b.title) +
        b.criteria.fold<int>(0, (a, c) => a + _words(c.label)) +
        b.items.fold<int>(
          0,
          (a, i) =>
              a +
              _words(i.name) +
              _words(i.caution ?? '') +
              i.valuesByCriterionId.values.fold<int>(
                0,
                (x, v) => x + _words(v),
              ),
        ),
  ChecklistBlock() =>
    _words(b.checklistPrompt) +
        b.items.fold<int>(
          0,
          (a, i) => a + _words(i.label) + _words(i.explanation ?? ''),
        ),
  RiskReviewChecklistBlock() =>
    _words(b.checklistPrompt) +
        _words(b.foundationSummary) +
        _words(b.partialSummary) +
        _words(b.completeSummary) +
        b.items.fold<int>(
          0,
          (a, i) => a + _words(i.label) + _words(i.explanation ?? ''),
        ),
  SortingBlock() =>
    _words(b.sortingPrompt) +
        b.items.fold<int>(
          0,
          (a, i) => a + _words(i.label) + _words(i.explanation ?? ''),
        ),
  CategorizeBlock() =>
    _words(b.categorizePrompt) +
        b.buckets.fold<int>(0, (a, x) => a + _words(x.label)) +
        b.items.fold<int>(
          0,
          (a, i) => a + _words(i.label) + _words(i.explanation),
        ),
  ReadinessCardBlock() =>
    _words(b.cardTitle) +
        b.fields.fold<int>(
          0,
          (a, f) =>
              a +
              _words(f.label) +
              f.options.fold<int>(0, (x, o) => x + _words(o.label)),
        ),
  SalapifyActionsBlock() =>
    _words(b.menuPrompt) +
        b.actions.fold<int>(
          0,
          (a, x) => a + _words(x.label) + _words(x.description),
        ),
  ReflectionPromptBlock() =>
    _words(b.question) +
        _words(b.privacyNote) +
        b.choices.fold<int>(0, (a, c) => a + _words(c.label)),
  LossImpactSimulatorBlock() =>
    _words(b.simulatorTitle) +
        _words(b.introduction) +
        b.amountOptions.fold<int>(0, (a, o) => a + _words(o.label)),
};

/// Total words a reader meets in [lesson]: its blocks, its exercises, and
/// its knowledge check.
int lessonWordCount(MoneyLesson lesson) {
  var n = 0;
  for (final b in lesson.blocks) {
    n += _blockWords(b);
  }
  for (final b in lesson.interactionBlocks) {
    n += _interactionWords(b);
  }
  final check = lesson.check;
  if (check != null) {
    n += _words(check.question);
    n += check.choices.fold<int>(0, (a, c) => a + _words(c));
    n += _words(check.explanation);
    n += _words(check.whyWrong ?? '');
  }
  return n;
}

/// The computed estimate, in whole minutes, rounded up and never zero.
int estimatedMinutes(MoneyLesson lesson) {
  final readingSeconds = lessonWordCount(lesson) * 60 / wordsPerMinute;
  final doingSeconds = lesson.interactionBlocks.length * secondsPerInteraction;
  final total = readingSeconds + doingSeconds;
  final minutes = (total / 60).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// What the app SHOWS: the larger of the authored figure and the computed
/// one.
///
/// Taking the maximum rather than always preferring the computation is what
/// keeps this from quietly shortening a lesson an author deliberately
/// marked as slower, and it means the core 22 (whose authored figures the
/// audit found accurate) display exactly as they always have.
int displayMinutes(MoneyLesson lesson) {
  final computed = estimatedMinutes(lesson);
  return computed > lesson.minutes ? computed : lesson.minutes;
}
