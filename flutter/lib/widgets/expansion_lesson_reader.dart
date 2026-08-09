// Reusable reader for Money Courses expansion-path lessons (Phase 6 pilot:
// "Are You Ready to Invest?", path id 'grow_your_money'). The promoted,
// public equivalent of screens/learn.dart's private _LessonReader, per the
// audit's own Phase 3 note ("_LessonReader needs to stop being private").
//
// Kept as its own widget rather than folding into _LessonReader: an
// expansion lesson has two things the core 22 never do, Phase 5 interaction
// blocks (content/interaction_blocks.dart) that gate real completion, and a
// separate settings.expansionProgress write path, and bolting both onto the
// core reader would make every one of the 22 shipped lessons carry weight
// they never use.
//
// Completion discipline, per this phase's own rules: opening or scrolling
// never finishes a lesson. "Finish this lesson" only becomes available once
// every REQUIRED interaction block has fired its own onComplete (see
// money/interaction_completion.dart); the knowledge check never gates it,
// matching the core reader's own convention that a quiz is never mandatory.
// Retrying an interaction (Reset/Start over/Try again) removes it from the
// completed set again, so a learner who changes their mind cannot finish on
// a stale completion.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../content/course_sequences.dart';
import '../content/interaction_blocks.dart';
import '../content/lesson_model.dart';
import '../data/store.dart';
import '../money/interaction_completion.dart';
import '../money/lesson_flow.dart';
import '../money/lesson_progress.dart';
import '../money/reading_time.dart';
import 'celebration.dart';
import '../screens/accounts.dart';
import '../screens/budget.dart';
import '../screens/debts.dart';
import '../screens/goals.dart';
import '../screens/mindset.dart';
import '../screens/notifications_security.dart';
import '../screens/recurring.dart';
import '../screens/salary_calculator.dart';
import '../theme.dart';
import '../typography.dart';
import 'screen_header.dart' show HeaderTier, headerStyle;
import 'interaction_block_views.dart';
import 'lesson_block_views.dart';
import 'salapify_icon.dart';

/// Verified, existing Salapify screens a [SalapifyActionsBlock] may open.
/// The one closed switch, matching the discipline screens/learn.dart's own
/// _resolveAction already follows for the core [LessonAction]: a route not
/// listed here resolves to null, and SalapifyActionsView renders that
/// action as plain text rather than a dead button. 'mindset' and 'accounts'
/// were added for Money Courses Phase 7A ("Stocks and Bonds Without the
/// Hype"); 'recurring' and 'notifications' were added for Money Courses
/// Phase 9 ("Insurance Decoded", the first course in the Protect Your
/// Future path), for its recurring-premium and reminders actions. Every
/// prior route still resolves exactly as before, so this changes nothing
/// for any earlier course.
/// Promoted from private so the paged reader (widgets/paged_lesson_reader
/// .dart) resolves the very same closed set. Two readers with two route
/// tables is how one of them quietly ends up with a dead button.
VoidCallback? resolveExpansionActionRoute(
  BuildContext context,
  SalapifyStore store,
  String route,
) {
  final Widget? screen = switch (route) {
    'goals' => GoalsScreen(store: store),
    'debts' => DebtsScreen(store: store),
    'budget' => BudgetScreen(store: store),
    'mindset' => MindsetScreen(store: store),
    'accounts' => AccountsScreen(store: store),
    'recurring' => RecurringScreen(store: store),
    'notifications' => NotificationsSecurityScreen(store: store),
    // Added for the Batch C1B income connection: the SSS & PhilHealth course
    // links to the take-home-pay calculator so contributions read as the
    // gross-to-net deductions they are. Const, no store, same as the tools hub
    // opens it.
    'salary' => const SalaryCalculatorScreen(),
    _ => null,
  };
  if (screen == null) return null;
  return () =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class ExpansionLessonReader extends StatefulWidget {
  final String pathId;
  final MoneyLesson lesson;
  final SalapifyStore store;

  /// Opens another lesson in this same path in place of this one. Null when
  /// the reader was opened somewhere that cannot navigate onward (a
  /// screenshot harness, a deep link into a single lesson), and the finish
  /// card simply omits its Next button rather than offering a dead tap.
  final void Function(String lessonId)? onOpenLesson;

  const ExpansionLessonReader({
    super.key,
    required this.pathId,
    required this.lesson,
    required this.store,
    this.onOpenLesson,
  });

  @override
  State<ExpansionLessonReader> createState() => _ExpansionLessonReaderState();
}

class _ExpansionLessonReaderState extends State<ExpansionLessonReader> {
  int? _picked;
  bool _finished = false;
  FinishOutcome? _outcome;
  final Set<String> _completedBlockIds = {};

  @override
  void initState() {
    super.initState();
    // A lesson the store already recorded as done opens DONE.
    //
    // This is the defect the experience audit filed as C6. Completion lived
    // only in this widget's own _completedBlockIds, which starts empty on
    // every build, and nothing ever read the stored state back. So reopening
    // a lesson finished last week showed "0 of 5 required interactions
    // completed" over a disabled Finish button while the hub showed its tick.
    // Showing a learner their earned progress as zeroed is worse than not
    // showing progress at all.
    final stored =
        widget.store.expansionProgressFor(widget.pathId)[widget.lesson.id] ??
        LessonState.notStarted;
    if (isDone(stored)) {
      _finished = true;
      _outcome = _computeOutcome();
    }
    // Best effort and never blocks reading, the same convention
    // screens/learn.dart's _open2 follows: a read-only store (after a failed
    // load) must still let the user read.
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonStarted(widget.pathId, widget.lesson.id);
    }
  }

  /// The outcome of finishing this lesson, against this path's progress with
  /// THIS lesson forced to completed. Overlaid rather than re-read after the
  /// write, for the same two reasons the core reader does it: the store write
  /// is a Future that may not have landed, and on a read-only store it never
  /// lands at all.
  FinishOutcome _computeOutcome() {
    final path = learningPathById(widget.pathId);
    return finishOutcome(
      finishedId: widget.lesson.id,
      sequence: path == null ? const [] : expansionFlowSequence(path),
      progress: {
        ...widget.store.expansionProgressFor(widget.pathId),
        widget.lesson.id: LessonState.completed,
      },
    );
  }

  void _onInteractionComplete(String blockId) {
    setState(() => _completedBlockIds.add(blockId));
  }

  void _onInteractionReset(String blockId) {
    setState(() => _completedBlockIds.remove(blockId));
  }

  void _onAnySalapifyActionConfirmed() {
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonApplied(widget.pathId, widget.lesson.id);
    }
  }

  bool get _readyToFinish => allRequiredInteractionsComplete(
    widget.lesson.interactionBlocks,
    _completedBlockIds,
  );

  void _finish() {
    if (_finished || !_readyToFinish) return;
    final outcome = _computeOutcome();
    setState(() {
      _finished = true;
      _outcome = outcome;
    });
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonCompleted(
        widget.pathId,
        widget.lesson.id,
      );
    }
    // Confetti for a finished course or a finished path only, matching the
    // core reader: a celebration that fires on all 71 expansion lessons
    // stops meaning anything by the third one.
    final message = switch (outcome.scope) {
      FinishScope.path => 'Path finished. Every lesson done.',
      FinishScope.course =>
        'Course finished: ${outcome.completedCourseTitle ?? ''}'.trim(),
      FinishScope.lesson => null,
    };
    if (message != null) showCelebration(context, message);
  }

  /// "3 of 6 in Insurance Decoded", or null when this lesson is not in the
  /// path's own sequence (never in practice; a missing id must not crash).
  String? _positionLabel() {
    final path = learningPathById(widget.pathId);
    if (path == null) return null;
    final sequence = expansionFlowSequence(path);
    final i = sequence.indexWhere((l) => l.id == widget.lesson.id);
    if (i < 0) return null;
    final me = sequence[i];
    final inCourse = sequence.where((l) => l.groupId == me.groupId).toList();
    final pos = inCourse.indexWhere((l) => l.id == me.id) + 1;
    return '$pos of ${inCourse.length} · ${me.groupTitle}';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final blocks = l.blocks;
    final outstanding = outstandingRequiredInteractions(
      l.interactionBlocks,
      _completedBlockIds,
    );
    var step = 0;

    final children = <Widget>[_hero(l), const SizedBox(height: 20)];

    // Citations and the boundary statement leave the teaching flow and
    // gather into one line at the end (see LessonReferenceFooter). They used
    // to interrupt the reading three to five times per lesson, landing
    // exactly where a reader decides whether to keep going. Nothing is
    // removed: the footer names every agency and carries the boundary
    // sentence while collapsed, and opens to the same cards as before.
    final teaching = [
      for (final b in blocks)
        if (!isReferenceBlock(b)) b,
    ];
    final reference = [
      for (final b in blocks)
        if (isReferenceBlock(b)) b,
    ];

    for (final b in teaching) {
      children.add(
        RiseIn(
          index: step++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: viewForBlock(b),
          ),
        ),
      );
    }

    for (final b in l.interactionBlocks) {
      children.add(
        RiseIn(
          index: step++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: viewForInteractionBlock(
              b,
              onComplete: _onInteractionComplete,
              onReset: _onInteractionReset,
              resolveSalapifyRoute: (route) =>
                  resolveExpansionActionRoute(context, widget.store, route),
              onAnySalapifyActionConfirmed: _onAnySalapifyActionConfirmed,
            ),
          ),
        ),
      );
    }

    if (l.check != null) {
      children.add(RiseIn(index: step++, child: _checkCard(l.check!)));
      children.add(const SizedBox(height: 16));
    }

    if (reference.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LessonReferenceFooter(reference),
        ),
      );
    }

    children.add(RiseIn(index: step, child: _finishRow(outstanding)));

    final position = _positionLabel();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        // Where am I, and in what. An 824 word lesson in one scroll gave a
        // reader no orientation at all once the hero scrolled away.
        title: position == null
            ? null
            : Text(position, style: AppText.caption.tint(Barako.muted)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(MoneyLesson l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SalapifyGlyph(l.icon, size: 28),
      const SizedBox(height: 10),
      Text('${displayMinutes(l)} min', style: Barako.kickerStyle),
      const SizedBox(height: 6),
      Text(l.title, style: headerStyle(HeaderTier.cover)),
      if (l.objective.isNotEmpty || l.summary.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          l.objective.isNotEmpty ? l.objective : l.summary,
          style: AppText.body.tint(Barako.muted).copyWith(height: 1.45),
        ),
      ],
    ],
  );

  // Distinct from screens/learn.dart's one-shot _checkCard: this phase's own
  // rule is "users may retry", so a wrong pick offers Try again instead of
  // locking the card at the first answer.
  Widget _checkCard(KnowledgeCheck c) {
    final picked = _picked;
    final answered = picked != null;
    final correct = answered && picked == c.correctIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matches the production paged reader and learn.dart: same kicker
          // wording and a screen-reader heading, so the fallback reader does
          // not silently rename the check or drop its heading (C5 19.1/22.2).
          Semantics(
            header: true,
            child: Text('QUICK CHECK', style: Barako.kickerStyle),
          ),
          const SizedBox(height: 8),
          Text(c.question, style: AppText.bodyStrong.copyWith(height: 1.45)),
          const SizedBox(height: 12),
          for (var i = 0; i < c.choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                selected: answered && i == _picked,
                enabled: !answered,
                label: answered && i == c.correctIndex
                    ? '${c.choices[i]}, correct answer'
                    : c.choices[i],
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractiveDimension,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: answered
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() => _picked = i);
                            },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: answered && i == c.correctIndex
                                ? Barako.primary
                                : Barako.border,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              answered && i == c.correctIndex
                                  ? salapifyIcon('selected')
                                  : salapifyIcon('unselected'),
                              size: 18,
                              color: answered && i == c.correctIndex
                                  ? Barako.primary
                                  : Barako.faint,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.choices[i],
                                style: AppText.label.w4
                                    .tint(Barako.textSecondary)
                                    .copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                correct ? 'That is it.' : 'Close. Here is the thinking.',
                style: AppText.label.w7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              !correct && c.whyWrong != null
                  ? '${c.whyWrong} ${c.explanation}'
                  : c.explanation,
              style: AppText.label.w4
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.5),
            ),
            if (!correct) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _picked = null),
                icon: Icon(salapifyIcon('startOver'), size: 16),
                label: const Text('Try again'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _finishRow(List<InteractionBlock> outstanding) {
    if (_finished) {
      final outcome = _outcome;
      final headline = switch (outcome?.scope) {
        FinishScope.path => 'Path finished. Every lesson done.',
        FinishScope.course =>
          'Course finished: ${outcome?.completedCourseTitle ?? ''}'.trim(),
        _ => 'Done. One useful thing.',
      };
      final next = outcome?.next;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Barako.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              header: true,
              child: Row(
                children: [
                  Icon(
                    salapifyIcon('selected'),
                    size: 18,
                    color: Barako.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      headline,
                      style: AppText.label.w7.tint(Barako.primary),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.lesson.keyTakeaway.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.lesson.keyTakeaway,
                style: AppText.label.w4
                    .tint(Barako.textSecondary)
                    .copyWith(height: 1.5),
              ),
            ],
            if (outcome != null && outcome.totalInCourse > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${outcome.doneInCourse} of ${outcome.totalInCourse} done in '
                'this course',
                style: AppText.caption.tint(Barako.muted),
              ),
            ],
            if (next != null && widget.onOpenLesson != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onOpenLesson!(next.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  // Two lines by design, same reason as the core reader's
                  // own Next button: as one run the minutes wrapped and
                  // stranded "min" on a line of its own.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${outcome?.nextStartsNewCourse == true ? 'Next course' : 'Next'}: '
                        '${next.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${next.minutes} min',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back to courses'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (outstanding.isNotEmpty) {
      final total = requiredInteractionBlocks(
        widget.lesson.interactionBlocks,
      ).length;
      final done = total - outstanding.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '$done of $total required interactions completed',
              style: AppText.caption.tint(Barako.muted),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: null,
            child: const Text('Finish this lesson'),
          ),
        ],
      );
    }
    return OutlinedButton(
      onPressed: _finish,
      child: const Text('Finish this lesson'),
    );
  }
}
