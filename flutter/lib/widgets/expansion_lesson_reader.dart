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

import '../content/interaction_blocks.dart';
import '../content/lesson_model.dart';
import '../data/store.dart';
import '../money/interaction_completion.dart';
import '../screens/budget.dart';
import '../screens/debts.dart';
import '../screens/goals.dart';
import '../theme.dart';
import '../typography.dart';
import 'interaction_block_views.dart';
import 'lesson_block_views.dart';
import 'salapify_icon.dart';

/// Verified, existing Salapify screens a [SalapifyActionsBlock] may open.
/// The one closed switch, matching the discipline screens/learn.dart's own
/// _resolveAction already follows for the core [LessonAction]: a route not
/// listed here resolves to null, and SalapifyActionsView renders that
/// action as plain text rather than a dead button.
VoidCallback? _resolveGrowAction(
  BuildContext context,
  SalapifyStore store,
  String route,
) {
  final Widget? screen = switch (route) {
    'goals' => GoalsScreen(store: store),
    'debts' => DebtsScreen(store: store),
    'budget' => BudgetScreen(store: store),
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

  const ExpansionLessonReader({
    super.key,
    required this.pathId,
    required this.lesson,
    required this.store,
  });

  @override
  State<ExpansionLessonReader> createState() => _ExpansionLessonReaderState();
}

class _ExpansionLessonReaderState extends State<ExpansionLessonReader> {
  int? _picked;
  bool _finished = false;
  final Set<String> _completedBlockIds = {};

  @override
  void initState() {
    super.initState();
    // Best effort and never blocks reading, the same convention
    // screens/learn.dart's _open2 follows: a read-only store (after a failed
    // load) must still let the user read.
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonStarted(widget.pathId, widget.lesson.id);
    }
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
    setState(() => _finished = true);
    if (widget.store.canWrite) {
      widget.store.markExpansionLessonCompleted(
        widget.pathId,
        widget.lesson.id,
      );
    }
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

    for (final b in blocks) {
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
                  _resolveGrowAction(context, widget.store, route),
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

    children.add(RiseIn(index: step, child: _finishRow(outstanding)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
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
      Text('${l.minutes} min', style: Barako.kickerStyle),
      const SizedBox(height: 6),
      Text(
        l.title,
        style: AppText.title.w7.copyWith(fontSize: 27, height: 1.1),
      ),
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
          Text('MASTERY CHECK', style: Barako.kickerStyle),
          const SizedBox(height: 8),
          Text(c.question, style: AppText.bodyStrong.copyWith(height: 1.45)),
          const SizedBox(height: 12),
          for (var i = 0; i < c.choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: answered ? null : () => setState(() => _picked = i),
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(salapifyIcon('selected'), size: 18, color: Barako.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Done. One useful thing.',
              style: AppText.label.w7.tint(Barako.primary),
            ),
          ),
        ],
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
