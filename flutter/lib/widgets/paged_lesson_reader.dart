// One idea per screen.
//
// The experience audit's central structural finding: an 824 word expansion
// lesson rendered as a single scroll, so reading one felt like reading an
// article rather than doing something. Batch 2 removed the citation stack
// that padded it and Batch 3 fixed how it opens; this changes the shape.
//
// A lesson is now a short sequence of screens (money/lesson_steps.dart
// decides where the breaks go) with one Continue button. Every block view is
// reused exactly as it is, so this is a change to assembly and navigation
// only, and no lesson content moved.
//
// What stays identical to the scrolling reader, on purpose:
//   - Opening never finishes a lesson, and a finished one opens finished.
//   - Only a REQUIRED interaction gates progress, and it gates the step it
//     lives on rather than a button far below it. The quiz never gates.
//   - Confetti fires for a finished course or path, never a lesson.
//   - Citations and the boundary statement ride the finish screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../content/course_sequences.dart';
import '../content/lesson_model.dart';
import '../data/store.dart';
import '../money/lesson_flow.dart';
import '../money/lesson_progress.dart';
import '../money/lesson_steps.dart';
import '../money/reading_time.dart';
import '../theme.dart';
import '../typography.dart';
import 'screen_header.dart' show HeaderTier, headerStyle;
import 'celebration.dart';
import 'expansion_lesson_reader.dart' show resolveExpansionActionRoute;
import 'interaction_block_views.dart';
import 'lesson_block_views.dart';
import 'lesson_finish_card.dart';
import 'salapify_icon.dart';

class PagedLessonReader extends StatefulWidget {
  final String pathId;
  final MoneyLesson lesson;
  final SalapifyStore store;
  final void Function(String lessonId)? onOpenLesson;

  /// Resolves a SalapifyActionsBlock route to a real navigation.
  ///
  /// OPTIONAL, and when it is absent this reader resolves the route itself
  /// through `resolveExpansionActionRoute`, which is what the scrolling
  /// reader has always done inline. That default is the point of this
  /// parameter existing at all, and it is a fix, not a convenience.
  ///
  /// Phase 3 moved this decision from INSIDE the reader out to the call
  /// site, and an absent value here does not crash: SalapifyActionsView
  /// falls back to `(_) => null` and renders every action as plain text
  /// instead of a button. So deleting the two lines in learn.dart that
  /// supply it silently removed a working button from the phone while the
  /// whole suite stayed green, which the f3.57 retrospective reproduced by
  /// doing exactly that. A dependency that moved from default-on to
  /// default-off, whose absent value is a degraded app rather than an error,
  /// is invisible by construction.
  ///
  /// Passing a resolver still overrides this, so a screen with its own route
  /// table (or a test) loses nothing.
  final VoidCallback? Function(String route)? resolveSalapifyRoute;

  const PagedLessonReader({
    super.key,
    required this.pathId,
    required this.lesson,
    required this.store,
    this.onOpenLesson,
    this.resolveSalapifyRoute,
    this.initialStep = 0,
  });

  /// Which step to open on. Zero for a real learner, always.
  ///
  /// This exists for the render harness and for tests that need to look at a
  /// block sitting five steps in. Before it, migrating the lesson shots off
  /// the scrolling reader would have produced seventeen pictures of first
  /// steps: every shot in that set exists to review ONE novel widget (a bond
  /// timeline, a readiness card, a fact sheet), and in a paged reader that
  /// widget is never on the screen the reader opens on. A tidy picture of the
  /// wrong screen is exactly what the render rule warns about.
  ///
  /// Advancing by tapping Continue is not a substitute: a required exercise
  /// gates its own step, so a shot of any block sitting after one would have
  /// to satisfy whatever exercise that lesson happens to author, and would
  /// break whenever an author edited it.
  ///
  /// Out of range values are clamped rather than thrown, so a lesson losing a
  /// step can never take a screen down.
  final int initialStep;

  @override
  State<PagedLessonReader> createState() => _PagedLessonReaderState();
}

class _PagedLessonReaderState extends State<PagedLessonReader> {
  late final List<LessonStep> _steps = stepsForLesson(widget.lesson);
  late final PageController _pages = PageController(initialPage: _startIndex);
  final Set<String> _completedBlockIds = {};
  late int _index = _startIndex;

  int get _startIndex =>
      widget.initialStep.clamp(0, _steps.isEmpty ? 0 : _steps.length - 1);
  int? _picked;
  bool _finished = false;
  FinishOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    // A lesson the store already recorded as done opens DONE, the same rule
    // the scrolling reader follows (audit defect C6).
    final stored =
        widget.store.expansionProgressFor(widget.pathId)[widget.lesson.id] ??
        LessonState.notStarted;
    if (isDone(stored)) {
      _finished = true;
      _outcome = _computeOutcome();
    }
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonStarted(widget.pathId, widget.lesson.id);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

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

  bool get _canAdvance {
    final step = _steps[_index];
    if (!stepGatesProgress(step)) return true;
    return _completedBlockIds.contains((step as InteractionStep).block.blockId);
  }

  void _go(int to) {
    if (to < 0 || to >= _steps.length) return;
    setState(() => _index = to);
    _pages.animateToPage(
      to,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (_steps[to] is FinishStep) _finish();
  }

  void _finish() {
    if (_finished) return;
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
    final message = switch (outcome.scope) {
      FinishScope.path => 'Path finished. Every lesson done.',
      FinishScope.course =>
        'Course finished: ${outcome.completedCourseTitle ?? ''}'.trim(),
      FinishScope.lesson => null,
    };
    if (message != null) showCelebration(context, message);
  }

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
    final position = _positionLabel();
    final onLast = _steps[_index] is FinishStep;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: position == null
            ? null
            : Text(position, style: AppText.caption.tint(Barako.muted)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Semantics(
            // Spoken as a real position rather than a bare percentage, which
            // is what a determinate bar announces by default.
            label: 'Step ${_index + 1} of ${_steps.length}',
            child: LinearProgressIndicator(
              value: (_index + 1) / _steps.length,
              minHeight: 3,
              backgroundColor: Barako.border,
              color: Barako.primary,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    // Advancing is the Continue button's job alone. Free
                    // swiping would let a reader slide straight past a
                    // required exercise, which is the one thing the gate
                    // exists to prevent.
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _steps.length,
                    itemBuilder: (context, i) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i == 0) ...[
                            _hero(widget.lesson),
                            const SizedBox(height: 20),
                          ],
                          _stepView(_steps[i]),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!onLast) _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepView(LessonStep step) => switch (step) {
    BlockStep() => viewForBlock(step.block),
    InteractionStep() => viewForInteractionBlock(
      step.block,
      onComplete: (id) => setState(() => _completedBlockIds.add(id)),
      onReset: (id) => setState(() => _completedBlockIds.remove(id)),
      // The same closed route table the scrolling reader resolves inline,
      // so the two readers can never drift into different sets of live
      // buttons. See the doc comment on the field.
      resolveSalapifyRoute:
          widget.resolveSalapifyRoute ??
          (route) => resolveExpansionActionRoute(context, widget.store, route),
      onAnySalapifyActionConfirmed: () {
        if (widget.store.canWrite) {
          widget.store.markExpansionLessonApplied(
            widget.pathId,
            widget.lesson.id,
          );
        }
      },
    ),
    CheckStep() => _checkCard(step.check),
    FinishStep() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LessonFinishCard(
          outcome: _outcome,
          keyTakeaway: widget.lesson.keyTakeaway,
          onOpenLesson: widget.onOpenLesson,
        ),
        if (step.reference.isNotEmpty) ...[
          const SizedBox(height: 16),
          LessonReferenceFooter(step.reference),
        ],
      ],
    ),
  };

  Widget _bottomBar() {
    final gated = !_canAdvance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gated) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Finish this activity to continue.',
                style: AppText.caption.tint(Barako.muted),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (_index > 0)
                TextButton(
                  onPressed: () => _go(_index - 1),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: gated
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _go(_index + 1);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  _steps.length - _index == 2 ? 'Finish' : 'Continue',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
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
}
