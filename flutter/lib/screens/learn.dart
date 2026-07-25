// Learn: the Salapify money courses. Four tracks, each promising one real
// outcome, 22 short lessons, and every lesson ending in one button that does
// something real in the app (log, set a goal, open the debt planner, set
// Steady Pay). Reading a lesson marks it done on the device
// (settings.lessonsRead, carried by backups). Pure content from
// lib/content/lessons.dart, no network, works offline. Education stays free,
// always. PH-scoped tax lessons wear a visible PHILIPPINES tag.

import 'package:flutter/material.dart';

import '../content/lesson_model.dart';
import '../content/lessons.dart';
import '../data/store.dart';
import '../money/course_plan.dart';
import '../money/lesson_insight.dart';
import '../money/lesson_progress.dart';
import '../theme.dart';
import '../widgets/lesson_block_views.dart';
import 'bnpl_calculator.dart';
import 'cashflow.dart';
import 'contribution_calculator.dart';
import 'debts.dart';
import 'goals.dart';
import 'log_sheet.dart';
import 'mindset.dart';
import 'notes.dart';
import 'paluwagan.dart';
import 'recurring.dart';
import 'salary_calculator.dart';
import 'tax_calculator.dart';
import 'thirteenth_calculator.dart';

// The bottom tabs a lesson action can jump to (same indexes as Home's map).
const Map<String, int> _tabRoutes = {
  'budget-tab': 1,
  'utang-tab': 3,
  'insights-tab': 4,
};

class LearnScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Optional lesson id to open straight away (e.g. from a coach nudge).
  final String? focusId;

  /// Lets a lesson action jump to a bottom tab (Budget, Utang, Insights).
  /// When absent, those actions fall back to hidden; every push action still
  /// works.
  final void Function(int)? onSwitchTab;
  const LearnScreen({
    super.key,
    required this.store,
    this.focusId,
    this.onSwitchTab,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.focusId;
    if (id != null) {
      final l = lessonById(id);
      if (l != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open2(context, l));
      }
    }
  }

  /// Resolve a lesson action to a real navigation. Returns null when the
  /// action cannot run here (a tab jump with no tab switcher), so the reader
  /// hides the button instead of showing a dead one.
  VoidCallback? _resolveAction(BuildContext context, Map<String, dynamic>? a) {
    if (a == null) return null;
    final route = a['route'] as String?;
    if (route == null) return null;
    final tab = _tabRoutes[route];
    if (tab != null) {
      final switcher = widget.onSwitchTab;
      if (switcher == null) return null;
      return () {
        Navigator.of(context).popUntil((r) => r.isFirst);
        switcher(tab);
      };
    }
    Widget? screen;
    switch (route) {
      case 'log':
        return () => showLogSheet(context, widget.store);
      case 'mindset':
        screen = MindsetScreen(
          store: widget.store,
          onSwitchTab: widget.onSwitchTab,
        );
      case 'recurring':
        screen = RecurringScreen(store: widget.store);
      case 'goals':
        screen = GoalsScreen(store: widget.store);
      case 'debts':
        screen = DebtsScreen(store: widget.store);
      case 'paluwagan':
        screen = PaluwaganScreen(store: widget.store);
      case 'cashflow':
        screen = CashFlowScreen(store: widget.store);
      case 'notes':
        screen = NotesScreen(store: widget.store);
      case 'tools-bnpl':
        screen = const BnplCalculatorScreen();
      case 'tools-tax':
        screen = const TaxCalculatorScreen();
      case 'tools-contrib':
        screen = const ContributionCalculatorScreen();
      case 'tools-thirteenth':
        screen = const ThirteenthCalculatorScreen();
      case 'tools-salary':
        screen = const SalaryCalculatorScreen();
    }
    if (screen == null) return null;
    final target = screen;
    return () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }

  void _open2(BuildContext context, Map<String, dynamic> lesson) {
    final typed = lessonFromMap(lesson);
    // Opening is NOT finishing. This used to mark the lesson read here, so
    // tapping a card and backing straight out counted as learned forever and
    // the progress figure measured taps. Opening now records inProgress; only
    // reaching the end of the lesson earns learned.
    //
    // Recording is best effort and never blocks reading: a read-only store
    // (after a failed load) must still let the user read.
    if (widget.store.canWrite) {
      widget.store.setLessonState(typed.id, LessonState.viewed);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LessonReader(
          lesson: typed,
          onAction: _resolveAction(
            context,
            (lesson['action'] as Map?)?.cast<String, dynamic>(),
          ),
          store: widget.store,
          onState: widget.store.canWrite
              ? (s) => widget.store.setLessonState(typed.id, s)
              : null,
        ),
      ),
    );
  }

  /// Which track sections are open. Tracks start collapsed so the catalog is
  /// four cards rather than a scroll of 22, which is the whole point of the
  /// change; the recommended one opens itself so a first visit lands on
  /// something to read rather than on a menu.
  final Set<String> _open = {};
  bool _openInitialised = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Money courses',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final progress = widget.store.lessonProgress;
            final doneCount = lessons
                .where(
                  (l) => isDone(progress[l['id']] ?? LessonState.notStarted),
                )
                .length;
            final rec = recommendedTrack(widget.store.data, DateTime.now());
            final stats = {
              for (final t in courseTracks)
                t['key'] as String: trackProgress(
                  trackId: t['key'] as String,
                  lessonIds: [
                    for (final l in lessonsForTrack(t['key'] as String))
                      l['id'] as String,
                  ],
                  minutesById: {
                    for (final l in lessons)
                      l['id'] as String: l['minutes'] as int,
                  },
                  progress: progress,
                ),
            };
            if (!_openInitialised) {
              _openInitialised = true;
              _open.add(rec.trackId);
            }
            final tracksDone = stats.values.where((t) => t.isComplete).length;
            final minutesLeft = stats.values.fold<int>(
              0,
              (a, t) => a + t.minutesLeft,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _header(doneCount, tracksDone, minutesLeft),
                const SizedBox(height: 18),
                for (final track in courseTracks) ...[
                  _trackCard(
                    track,
                    stats[track['key']]!,
                    progress,
                    recommended: track['key'] == rec.trackId,
                    reason: rec.reason,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int doneCount, int tracksDone, int minutesLeft) {
    final total = lessons.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn one money skill, then use it in Salapify.',
          style: TextStyle(
            fontFamily: Barako.displayFont,
            color: Barako.text,
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : doneCount / total,
            minHeight: 8,
            backgroundColor: Barako.border,
            color: Barako.primary,
          ),
        ),
        const SizedBox(height: 8),
        // Wrap, not Row: three facts at a large font scale would overflow.
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            Text(
              '$doneCount of $total lessons',
              style: TextStyle(
                color: Barako.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$tracksDone of ${courseTracks.length} courses',
              style: TextStyle(color: Barako.muted, fontSize: 13),
            ),
            if (minutesLeft > 0)
              Text(
                'about $minutesLeft min left',
                style: TextStyle(color: Barako.muted, fontSize: 13),
              ),
          ],
        ),
      ],
    );
  }

  Widget _trackCard(
    Map<String, dynamic> track,
    TrackProgress stat,
    Map<String, LessonState> progress, {
    required bool recommended,
    required String reason,
  }) {
    final key = track['key'] as String;
    final isOpen = _open.contains(key);
    final trackLessons = lessonsForTrack(key);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: recommended ? Barako.primary : Barako.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended) ...[
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 15, color: Barako.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'RECOMMENDED',
                      style: Barako.kickerStyle.copyWith(
                        color: Barako.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track['emoji'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title'] as String,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track['outcome'] as String,
                        style: TextStyle(
                          color: Barako.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (recommended) ...[
              const SizedBox(height: 8),
              // The reason is always visible. A recommendation the user
              // cannot see the basis for is just the app being bossy.
              Text(
                reason,
                style: TextStyle(
                  color: Barako.primaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.fraction,
                minHeight: 5,
                backgroundColor: Barako.border,
                color: stat.isComplete ? Barako.celebrate : Barako.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${stat.done} of ${stat.total} done',
                  style: TextStyle(
                    color: stat.isComplete ? Barako.primaryText : Barako.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  stat.status,
                  style: TextStyle(color: Barako.faint, fontSize: 12),
                ),
                if (stat.minutesLeft > 0)
                  Text(
                    '${stat.minutesLeft} min left',
                    style: TextStyle(color: Barako.faint, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final nextId =
                          stat.nextLessonId ??
                          (trackLessons.isNotEmpty
                              ? trackLessons.first['id'] as String
                              : null);
                      if (nextId == null) return;
                      final l = lessonById(nextId);
                      if (l != null) _open2(context, l);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      stat.actionLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    if (isOpen) {
                      _open.remove(key);
                    } else {
                      _open.add(key);
                    }
                  }),
                  child: Text(isOpen ? 'Hide lessons' : 'All lessons'),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? Column(
                      children: [
                        const SizedBox(height: 6),
                        for (var i = 0; i < trackLessons.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _lessonRow(
                              trackLessons[i],
                              i + 1,
                              trackLessons.length,
                              progress[trackLessons[i]['id']] ??
                                  LessonState.notStarted,
                            ),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lessonRow(
    Map<String, dynamic> l,
    int position,
    int outOf,
    LessonState state,
  ) {
    final done = isDone(state);
    final started = state != LessonState.notStarted && !done;
    final isPH = l['region'] == 'PH';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open2(context, l),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done
                  ? Icons.check_circle
                  : started
                  ? Icons.pause_circle_outline
                  : Icons.circle_outlined,
              size: 18,
              color: done
                  ? Barako.primary
                  : started
                  ? Barako.primaryText
                  : Barako.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l['title'] as String,
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l['summary'] as String,
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$position of $outOf',
                        style: TextStyle(color: Barako.faint, fontSize: 11),
                      ),
                      Text(
                        '${l['minutes']} min',
                        style: TextStyle(color: Barako.faint, fontSize: 11),
                      ),
                      if (started)
                        Text(
                          'Continue',
                          style: TextStyle(
                            color: Barako.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (isPH)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Barako.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PHILIPPINES',
                            style: TextStyle(
                              color: Barako.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lesson, rendered as a conversation rather than a document.
///
/// Every visible piece is a block with its own widget, assembled by walking
/// the list, so a new lesson needs content and no new UI. The order is fixed
/// because it is the teaching order: why you should care, what it means for
/// YOU, the idea in pieces, a question before the answer, a real person, the
/// trap, the thing to try, the one action, the sentence to keep.
class _LessonReader extends StatefulWidget {
  final MoneyLesson lesson;
  final SalapifyStore store;
  final VoidCallback? onAction;
  final void Function(LessonState)? onState;
  const _LessonReader({
    required this.lesson,
    required this.store,
    this.onAction,
    this.onState,
  });

  @override
  State<_LessonReader> createState() => _LessonReaderState();
}

class _LessonReaderState extends State<_LessonReader> {
  int? _picked;
  bool _understood = false;
  bool _finished = false;

  // Understanding is earned by engaging with the thinking: revealing a
  // discovery answer or answering the check. Not by scrolling.
  void _markUnderstood() {
    if (_understood) return;
    _understood = true;
    widget.onState?.call(LessonState.understood);
  }

  void _answer(int i) {
    setState(() => _picked = i);
    _markUnderstood();
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    widget.onState?.call(LessonState.completed);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final insight = lessonInsight(widget.store.data, l.trackId, DateTime.now());
    final blocks = l.blocks;
    var step = 0;

    final children = <Widget>[
      _hero(l),
      const SizedBox(height: 16),
      InsightView(text: insight.text, personalized: insight.personalized),
      if (l.isPhilippines) ...[const SizedBox(height: 12), _scopeNote(l)],
      const SizedBox(height: 20),
    ];

    for (final b in blocks) {
      children.add(
        RiseIn(
          index: step++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: viewForBlock(b, onRevealed: _markUnderstood),
          ),
        ),
      );
    }

    if (l.check != null) {
      children.add(RiseIn(index: step++, child: _checkCard(l.check!)));
      children.add(const SizedBox(height: 16));
    }

    // The one action. Never required to finish: requiring it would push
    // people to invent financial records just to complete a lesson.
    if (l.action != null && widget.onAction != null) {
      children.add(
        RiseIn(
          index: step++,
          child: FilledButton(
            onPressed: () {
              widget.onState?.call(LessonState.applied);
              widget.onAction!.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              l.action!.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 16));
    }

    children.add(RiseIn(index: step, child: _finishRow()));

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

  // Small on purpose: emoji, kicker, title, one line on why it matters.
  Widget _hero(MoneyLesson l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.emoji, style: const TextStyle(fontSize: 36)),
      const SizedBox(height: 10),
      Row(
        children: [
          Flexible(
            child: Text(
              '${l.minutes} min',
              overflow: TextOverflow.ellipsis,
              style: Barako.kickerStyle,
            ),
          ),
          if (l.isPhilippines) ...[const SizedBox(width: 8), _phTag()],
        ],
      ),
      const SizedBox(height: 6),
      Text(
        l.title,
        style: TextStyle(
          fontFamily: Barako.displayFont,
          color: Barako.text,
          fontSize: 27,
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (l.objective.isNotEmpty || l.summary.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          l.objective.isNotEmpty ? l.objective : l.summary,
          style: TextStyle(color: Barako.muted, fontSize: 15, height: 1.45),
        ),
      ],
    ],
  );

  Widget _phTag() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'PHILIPPINES',
      style: TextStyle(
        color: Barako.muted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );

  // Regional scope near the TOP, never buried at the end where a reader
  // elsewhere would find it too late to matter.
  Widget _scopeNote(MoneyLesson l) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'These rules are Philippine rules. The idea works anywhere, the rates '
      'and deadlines do not. Confirm with the agency or a licensed '
      'professional before you act.'
      '${l.factCheckedOn != null ? ' Facts last checked ${l.factCheckedOn}.' : ''}',
      style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.4),
    ),
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
          Text('QUICK CHECK', style: Barako.kickerStyle),
          const SizedBox(height: 8),
          Text(
            c.question,
            style: TextStyle(
              color: Barako.text,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < c.choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: answered ? null : () => _answer(i),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // Only the correct answer is ever highlighted. A wrong
                    // pick is not stained red: being wrong is how this works.
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
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: answered && i == c.correctIndex
                            ? Barako.primary
                            : Barako.faint,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.choices[i],
                          style: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: answered
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        correct
                            ? 'That is it.'
                            : 'Close. Here is the thinking.',
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !correct && c.whyWrong != null
                            ? '${c.whyWrong} ${c.explanation}'
                            : c.explanation,
                        style: TextStyle(
                          color: Barako.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _finishRow() => _finished
      ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 18, color: Barako.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Done. One useful thing.',
                style: TextStyle(
                  color: Barako.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        )
      : OutlinedButton(
          onPressed: _finish,
          child: const Text('Finish this lesson'),
        );
}
