// Learn: the Salapify money courses. Four tracks, each promising one real
// outcome, 22 short lessons, and every lesson ending in one button that does
// something real in the app (log, set a goal, open the debt planner, set
// Steady Pay). Reading a lesson marks it done on the device
// (settings.lessonsRead, carried by backups). Pure content from
// lib/content/lessons.dart, no network, works offline. Education stays free,
// always. PH-scoped tax lessons wear a visible PHILIPPINES tag.

import 'package:flutter/material.dart';

import '../content/course_sequences.dart';
import '../content/expansion_display.dart';
import '../content/learning_path.dart';
import '../content/learning_paths.dart';
import '../content/lesson_model.dart';
import '../content/lessons.dart';
import '../data/store.dart';
import '../money/course_plan.dart';
import '../money/expansion_recommendation.dart';
import '../money/lesson_flow.dart';
import '../money/lesson_insight.dart';
import '../money/lesson_progress.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/screen_header.dart' show HeaderTier, headerStyle;
import '../widgets/celebration.dart';
import '../widgets/expansion_lesson_reader.dart';
import '../widgets/paged_lesson_reader.dart';
import '../widgets/lesson_block_views.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/progress_bar.dart';
import '../widgets/salapify_icon.dart';
import 'bnpl_calculator.dart';
import 'cashflow.dart';
import 'contribution_calculator.dart';
import 'debts.dart';
import 'goals.dart';
import 'log_sheet.dart';
import 'mindset.dart';
import 'notes.dart';
import 'paluwagan.dart';
import 'path_screen.dart';
import 'recurring.dart';
import 'salary_calculator.dart';
import 'tax_calculator.dart';
import 'thirteenth_calculator.dart';
import 'shell.dart';

// The bottom tabs a lesson action can jump to (same indexes as Home's map).
// A lesson's call to action can land the reader on a tab. Named, for the same
// reason as overview.dart's _routeTabs: 'budget-tab': 1 was only true while
// Budget happened to be second, and a reorder would have sent every lesson
// button somewhere else without failing anything.
const Map<String, Destination> _tabRoutes = {
  'budget-tab': Destination.budget,
  'utang-tab': Destination.utang,
  'insights-tab': Destination.insights,
};

class LearnScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Optional lesson id to open straight away (e.g. from a coach nudge).
  final String? focusId;

  /// Lets a lesson action jump to a bottom tab (Budget, Utang, Insights).
  /// When absent, those actions fall back to hidden; every push action still
  /// works.
  final void Function(Destination)? onSwitchTab;
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
    if (id == null) return;
    final l = lessonById(id);
    if (l != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open2(context, l));
      return;
    }
    // Not one of the core 22: try the expansion paths (Grow Your Money and
    // whatever comes after) before giving up. An id that matches neither is
    // a safe no-op, the same fails-safe convention lessonById itself
    // already follows, never a crash.
    final expansion = expansionLessonById(id);
    if (expansion != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            _openExpansionLesson(context, expansion.pathId, expansion.lesson),
      );
    }
  }

  void _openExpansionLesson(
    BuildContext context,
    String pathId,
    MoneyLesson lesson, {
    // Same contract as _open2's own flag: a lesson reached from the previous
    // lesson's Next button replaces it, so a long path does not build a back
    // stack the depth of the course.
    bool replace = false,
  }) {
    final route = MaterialPageRoute<void>(
      // The paged reader (Phase 3): one idea per screen instead of one long
      // scroll. ExpansionLessonReader is still the scrolling implementation
      // and still fully tested; it stays until this has been confirmed on a
      // real phone, so there is always a working reader to fall back to.
      builder: (context) => PagedLessonReader(
        pathId: pathId,
        lesson: lesson,
        store: widget.store,
        resolveSalapifyRoute: (r) =>
            resolveExpansionActionRoute(context, widget.store, r),
        onOpenLesson: (id) {
          final next = expansionLessonById(id);
          if (next != null) {
            _openExpansionLesson(
              context,
              next.pathId,
              next.lesson,
              replace: true,
            );
          }
        },
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
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

  void _open2(
    BuildContext context,
    Map<String, dynamic> lesson, {
    // True when this lesson was reached from the previous lesson's own
    // "Next" button. It REPLACES that route rather than stacking on it, so
    // reading ten lessons in a row leaves one back step to the hub instead
    // of ten, and the back button keeps meaning "leave the lesson".
    bool replace = false,
  }) {
    final typed = lessonFromMap(lesson);
    // What the store already knows, read BEFORE the viewed write below, so a
    // lesson finished on an earlier visit opens in its finished state
    // instead of presenting as unread (the reader's own _finished flag used
    // to start false for everyone).
    final existing =
        widget.store.lessonProgress[typed.id] ?? LessonState.notStarted;
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
    final route = MaterialPageRoute<void>(
      builder: (_) => _LessonReader(
        lesson: typed,
        onAction: _resolveAction(
          context,
          (lesson['action'] as Map?)?.cast<String, dynamic>(),
        ),
        store: widget.store,
        initialState: existing,
        sequence: coreFlowSequence(),
        onOpenLesson: (id) {
          final next = lessonById(id);
          if (next != null) _open2(context, next, replace: true);
        },
        onState: widget.store.canWrite
            ? (s) => widget.store.setLessonState(typed.id, s)
            : null,
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
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
      appBar: AppBar(title: Text('Money courses')),
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
            // The resume target for the hero: the same deterministic pick
            // Home makes. anyStarted decides Continue vs Start here, read off
            // the core progress directly so an untouched catalog reads as the
            // blank slate it is.
            final next = nextCoreLesson(
              data: widget.store.data,
              progress: progress,
              now: DateTime.now(),
            );
            final anyStarted = lessons.any(
              (l) =>
                  (progress[l['id']] ?? LessonState.notStarted) !=
                  LessonState.notStarted,
            );

            // Ordered for display (Batch C1B): Protect first as the most
            // everyday tier, then Grow, then Business under Advanced. This is
            // presentation order only; the underlying path ids and progress
            // are untouched.
            final paths = [...publishedLearningPaths]
              ..sort(
                (a, b) =>
                    expansionPathRank(a.id).compareTo(expansionPathRank(b.id)),
              );
            // One primary recommendation across every path, or null for the
            // neutral discovery state (no reliable signal yet, or every
            // started path is already finished). See
            // money/expansion_recommendation.dart for the deterministic rule.
            final pathRec = recommendedExpansionCourse(paths, {
              for (final p in paths)
                p.id: widget.store.expansionProgressFor(p.id),
            });
            // Progress across the WHOLE catalog. Every published path's own
            // lessons and courses count too, so the headline figure can no
            // longer ignore three quarters of what this screen offers.
            var allDone = doneCount;
            var allTotal = lessons.length;
            var coursesDone = tracksDone;
            var coursesTotal = courseTracks.length;
            for (final p in paths) {
              final pathProgress = widget.store.expansionProgressFor(p.id);
              allTotal += p.lessonIds.length;
              coursesTotal += p.groups.length;
              for (final g in p.groups) {
                final ids = g.lessonIds;
                final gDone = ids
                    .where(
                      (id) =>
                          isDone(pathProgress[id] ?? LessonState.notStarted),
                    )
                    .length;
                allDone += gDone;
                if (ids.isNotEmpty && gDone >= ids.length) coursesDone++;
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _journeyHero(
                  next: next,
                  anyStarted: anyStarted,
                  doneCount: doneCount,
                  total: lessons.length,
                ),
                const SizedBox(height: 16),
                _header(
                  allDone,
                  allTotal,
                  coursesDone,
                  coursesTotal,
                  minutesLeft,
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text('CORE MONEY SKILLS', style: Barako.kickerStyle),
                ),
                const SizedBox(height: 10),
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
                if (paths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      'CHOOSE YOUR NEXT PATH',
                      style: Barako.kickerStyle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The expansion recommender is deliberately mute until a
                  // path has real progress (money/expansion_recommendation
                  // .dart's own rule 1), which is correct but left this
                  // whole section with no way in for a brand new learner.
                  // One neutral line, shown only while nothing here is
                  // started, and it names a real starting point rather than
                  // pretending to know anything about the reader.
                  if (pathRec == null) ...[
                    Text(
                      // With the hero now naming one clear place to start, this
                      // line no longer competes by sending a beginner into an
                      // investing course. It points back to the core journey
                      // first, then frames the paths as what comes after.
                      'New here? Start with the core lessons above. These paths '
                      'go deeper once you are ready.',
                      style: AppText.caption
                          .tint(Barako.muted)
                          .copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final path in paths) ...[
                    _pathCard(
                      path,
                      recommendedReason: pathRec?.pathId == path.id
                          ? pathRec?.reason
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The header.
  ///
  /// The figures count the WHOLE catalog: the core 22 plus every published
  /// path's lessons and courses. They used to count only the core 22, so a
  /// learner who finished all 18 lessons of Protect Your Future still read
  /// "0 of 22 lessons" at the top of the screen, which the experience audit
  /// filed as H2.
  ///
  /// That change was made once, reverted, and then made again deliberately,
  /// and the reason is worth keeping. Reverting it the first time was right:
  /// content/learning_path.dart calls the core figure "load-bearing", and
  /// four tests asserted that finishing an entire expansion path never moves
  /// it. But those tests were guarding the number ON SCREEN as a proxy for
  /// the thing that actually matters, which is that the two progress stores
  /// never write into each other. The founder chose the audit's reading, so
  /// the number now reflects everything a learner has done, and those tests
  /// were rewritten to assert the isolation directly against the store
  /// instead of through a rendered string. The invariant is unchanged and
  /// better guarded; only the proxy is gone.
  ///
  /// The first impression is also handled here: a warm line about what the
  /// lessons are, and no running total of minutes left until the learner has
  /// actually started something. A first visit that opens with a bill for 43
  /// minutes is answering "how much work is left" when the only useful
  /// question is "what do I do next".
  /// The one card that answers "what do I do next" before anything else on
  /// the screen, so a returning learner never hunts for their active lesson
  /// and a first visitor is never handed 22 lessons and asked to choose.
  ///
  /// It reuses [nextCoreLesson], the same deterministic pick Home already
  /// makes (recommended track first, then the first unfinished lesson
  /// anywhere), so this is a surface for that decision, never a second
  /// recommendation engine. A null [next] means every core lesson is done:
  /// the card says so and points down to the paths rather than sitting empty.
  Widget _journeyHero({
    required FlowLesson? next,
    required bool anyStarted,
    required int doneCount,
    required int total,
  }) {
    if (next == null) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: Barako.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              SalapifyGlyph('celebrate', size: 22),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All core lessons done', style: AppText.subtitle),
                    const SizedBox(height: 3),
                    Text(
                      'You have read all $total. Pick a path below to keep '
                      'going.',
                      style: AppText.small
                          .tint(Barako.muted)
                          .copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    // START HERE for a blank slate, CONTINUE once anything has been opened.
    // The distinction is what a first visitor needs (permission to begin at
    // one place) versus what a returning one needs (their thread back).
    final kicker = anyStarted ? 'CONTINUE' : 'START HERE';
    final sub = anyStarted
        ? '${next.groupTitle} · $doneCount of $total done'
        : '${next.groupTitle} · your first lesson';
    return Semantics(
      button: true,
      label: '$kicker. ${next.title}. ${next.minutes} minute lesson. $sub.',
      child: PressableScale(
        child: Card(
          color: Barako.primary,
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              final l = lessonById(next.id);
              if (l != null) _open2(context, l);
            },
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  Expanded(
                    // The label is already spoken by the Semantics wrapper as
                    // one button, so the visible text is excluded to avoid a
                    // second, fragmented reading of the same target.
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kicker,
                            style: Barako.kickerStyle.copyWith(
                              color: Barako.onPrimary.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            next.title,
                            style: AppText.subtitle.w8.tint(Barako.onPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${next.minutes} min · $sub',
                            style: AppText.small.tint(
                              Barako.onPrimary.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Icon(
                    salapifyIcon('forward'),
                    color: Barako.onPrimary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    int doneCount,
    int total,
    int coursesDone,
    int coursesTotal,
    int minutesLeft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn one money skill, then use it in Salapify.',
          style: AppText.title.w7,
        ),
        if (doneCount == 0) ...[
          const SizedBox(height: 8),
          Text(
            'Short lessons, and every one ends with something you can '
            'actually do here.',
            style: AppText.small.tint(Barako.muted).copyWith(height: 1.45),
          ),
        ],
        const SizedBox(height: 14),
        SalapifyProgressBar(
          value: total == 0 ? 0 : doneCount / total,
          semanticsLabel: 'Overall course progress',
        ),
        const SizedBox(height: 8),
        // Wrap, not Row: three facts at a large font scale would overflow.
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            Text('$doneCount of $total lessons', style: AppText.smallStrong),
            Text(
              '$coursesDone of $coursesTotal courses',
              style: AppText.small.tint(Barako.muted),
            ),
            // Suppressed until something is started: see this method's own
            // doc comment. Nothing asserts this figure, so unlike the two
            // counts above it is free to go.
            if (minutesLeft > 0 && doneCount > 0)
              Text(
                'about $minutesLeft min left',
                style: AppText.small.tint(Barako.muted),
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
                  Icon(salapifyIcon('star'), size: 15, color: Barako.primary),
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
                SalapifyGlyph(track['icon'] as String, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track['title'] as String, style: AppText.subtitle),
                      const SizedBox(height: 3),
                      Text(
                        track['outcome'] as String,
                        style: AppText.small
                            .tint(Barako.muted)
                            .copyWith(height: 1.4),
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
                style: AppText.caption
                    .tint(Barako.primaryText)
                    .copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            SalapifyProgressBar(
              value: stat.fraction,
              size: ProgressBarSize.micro,
              semanticsLabel: '${track['title']} progress',
              color: stat.isComplete ? Barako.celebrate : Barako.primary,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${stat.done} of ${stat.total} done',
                  style: AppText.caption.w7.tint(
                    stat.isComplete ? Barako.primaryText : Barako.muted,
                  ),
                ),
                Text(stat.status, style: AppText.caption.tint(Barako.faint)),
                if (stat.minutesLeft > 0)
                  Text(
                    '${stat.minutesLeft} min left',
                    style: AppText.caption.tint(Barako.faint),
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
    // One announcement per row, with the state as a WORD. The tick, the
    // pause glyph, and the empty circle carried the whole meaning, so every
    // lesson sounded identical to a screen reader whether it was finished or
    // untouched. MergeSemantics also stops the row reading out as four
    // separate swipe stops.
    return Semantics(
      button: true,
      label: [
        l['title'] as String,
        done
            ? 'Completed'
            : started
            ? 'In progress'
            : 'Not started',
        l['summary'] as String,
        '$position of $outOf',
        '${l['minutes']} min',
        if (isPH) 'Philippine rules',
      ].join(', '),
      child: ExcludeSemantics(
        child: _lessonRowBody(l, position, outOf, done, started, isPH),
      ),
    );
  }

  Widget _lessonRowBody(
    Map<String, dynamic> l,
    int position,
    int outOf,
    bool done,
    bool started,
    bool isPH,
  ) {
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
                  ? salapifyIcon('selected')
                  : started
                  ? salapifyIcon('paused')
                  : salapifyIcon('unselected'),
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
                  Text(l['title'] as String, style: AppText.label),
                  const SizedBox(height: 2),
                  Text(
                    l['summary'] as String,
                    style: AppText.caption.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$position of $outOf',
                        style: AppText.micro.w4.tint(Barako.faint),
                      ),
                      Text(
                        '${l['minutes']} min',
                        style: AppText.micro.w4.tint(Barako.faint),
                      ),
                      if (started)
                        Text(
                          'Continue',
                          style: AppText.micro.w7.tint(Barako.primaryText),
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
                            // Was fontSize 9, below the type ladder's own
                            // floor of 10. This tag is not decoration, it
                            // tells a reader whether the tax rules in the
                            // lesson apply to them at all.
                            style: AppText.micro.w7.copyWith(letterSpacing: 1),
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

  // An expansion learning path (Money Courses Phase 6: Grow Your Money),
  // shown below the four core tracks. Structurally close to _trackCard, but
  // simpler: no core "recommended" star (that engine is core-specific by
  // design, see money/course_plan.dart), a PathProgress instead of a
  // TrackProgress, and prerequisites shown as advisory "Recommended first"
  // text rather than anything that blocks opening a lesson.
  Widget _pathCard(LearningPath path, {String? recommendedReason}) {
    final pathLessons = lessonsForPath(path.id);
    final progress = widget.store.expansionProgressFor(path.id);
    final stat = widget.store.expansionPathProgress(
      pathId: path.id,
      lessonIds: path.lessonIds,
    );
    final prereqTitles = [
      for (final id in path.prerequisiteLessonIds)
        lessonById(id)?['title'] as String?,
    ].whereType<String>().toList();
    final recommended = recommendedReason != null;

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
            if (isAdvancedPath(path.id)) ...[
              // A quiet tier marker, not a warning. Business is useful but
              // sits above the everyday journey, so it reads as advanced
              // through a muted label rather than any alarming treatment, and
              // it stays fully discoverable (C1B, STEP 6).
              Semantics(
                header: true,
                child: Text(
                  'ADVANCED',
                  style: Barako.kickerStyle.copyWith(color: Barako.muted),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (recommended) ...[
              Row(
                children: [
                  Icon(salapifyIcon('star'), size: 15, color: Barako.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      // Distinct wording from the core tracks' own
                      // "RECOMMENDED" badge above (a separate, always-on
                      // engine): a user who has touched both a core lesson
                      // and a path lesson would otherwise see two
                      // identically-labelled badges on screen with no way to
                      // tell them apart, per the Phase 16 specialist review.
                      'CONTINUE THIS PATH',
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
                SalapifyGlyph(path.icon, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(path.title, style: AppText.subtitle),
                      const SizedBox(height: 3),
                      Text(
                        path.shortDescription,
                        style: AppText.small
                            .tint(Barako.muted)
                            .copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (recommended) ...[
              const SizedBox(height: 8),
              // The reason is always visible, same rule the core track
              // recommendation follows: a suggestion nobody can see the
              // basis for is just the app being bossy.
              Text(
                recommendedReason,
                style: AppText.caption
                    .tint(Barako.primaryText)
                    .copyWith(height: 1.4),
              ),
            ],
            if (prereqTitles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Barako.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(salapifyIcon('help'), size: 14, color: Barako.faint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recommended first: ${prereqTitles.join(", ")}',
                        style: AppText.caption.tint(Barako.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SalapifyProgressBar(
              value: stat.fraction,
              size: ProgressBarSize.micro,
              semanticsLabel: '${path.title} progress',
              color: stat.isComplete ? Barako.celebrate : Barako.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '${stat.done} of ${stat.total} lessons in this path',
              style: AppText.caption.w7.tint(
                stat.isComplete ? Barako.primaryText : Barako.muted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: pathLessons.isEmpty
                        ? null
                        : () {
                            final next = pathLessons.firstWhere(
                              (l) => !isDone(
                                progress[l.id] ?? LessonState.notStarted,
                              ),
                              orElse: () => pathLessons.first,
                            );
                            _openExpansionLesson(context, path.id, next);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      stat.isStarted ? 'Continue' : 'Start',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pushes a real screen instead of expanding up to thirty rows
                // into the middle of this scroll (audit H3). The accordion was
                // right at six rows and broken at thirty: the collapse control
                // scrolled away from under the reader, the scroll position
                // jumped when it closed, and there was no way to reach a
                // single course at all.
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PathScreen(
                        path: path,
                        store: widget.store,
                        onOpenLesson: (ctx, id, l) =>
                            _openExpansionLesson(ctx, id, l),
                      ),
                    ),
                  ),
                  child: const Text('All courses'),
                ),
              ],
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

  /// What the store already knew about this lesson when it was opened, so a
  /// lesson finished on a previous visit opens finished.
  final LessonState initialState;

  /// The whole core reading order, for deciding what finishing this lesson
  /// completed and which lesson to offer next (money/lesson_flow.dart).
  final List<FlowLesson> sequence;

  /// Opens another lesson in place of this one.
  final void Function(String lessonId) onOpenLesson;

  const _LessonReader({
    required this.lesson,
    required this.store,
    required this.sequence,
    required this.onOpenLesson,
    this.initialState = LessonState.notStarted,
    this.onAction,
    this.onState,
  });

  @override
  State<_LessonReader> createState() => _LessonReaderState();
}

class _LessonReaderState extends State<_LessonReader> {
  int? _picked;
  bool _understood = false;
  late bool _finished = isDone(widget.initialState);
  FinishOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    // A lesson reopened after it was already finished shows its finish card
    // immediately, complete with the next-lesson button, rather than asking
    // the learner to finish something they finished last week. Computed
    // without celebrating: the celebration belongs to the moment it was
    // earned, not to every later reread.
    if (_finished) _outcome = _computeOutcome();
  }

  // Understanding is earned by engaging with the thinking: revealing a
  // discovery answer or answering the check. Not by scrolling.
  void _markUnderstood() {
    if (_understood) return;
    _understood = true;
    widget.onState?.call(LessonState.understood);
  }

  void _answer(int i) {
    // A confirmation the hands can feel, the same selectionClick the rest of
    // the app already uses for a pick.
    Haptics.select();
    setState(() => _picked = i);
    _markUnderstood();
  }

  /// The outcome of finishing this lesson, computed against the store's
  /// progress with THIS lesson forced to completed.
  ///
  /// Overlaid rather than re-read after the write, for two reasons: the
  /// store write is a Future that may not have landed yet, and on a
  /// read-only store it never lands at all. Either way the learner has
  /// finished the lesson on screen and the finish card must agree with what
  /// they just did.
  FinishOutcome _computeOutcome() => finishOutcome(
    finishedId: widget.lesson.id,
    sequence: widget.sequence,
    progress: {
      ...widget.store.lessonProgress,
      widget.lesson.id: LessonState.completed,
    },
  );

  void _finish() {
    if (_finished) return;
    final outcome = _computeOutcome();
    setState(() {
      _finished = true;
      _outcome = outcome;
    });
    widget.onState?.call(LessonState.completed);
    // Confetti is reserved for finishing a whole course or the whole set.
    // Firing it on each of 93 lessons would spend the app's happiest
    // animation on its most ordinary event, and one panelist called a party
    // for reading 200 words condescending. A finished lesson still gets a
    // real card, just not fireworks.
    final message = switch (outcome.scope) {
      FinishScope.path => 'Every core lesson done. All 22.',
      FinishScope.course =>
        'Course finished: ${outcome.completedCourseTitle ?? ''}'.trim(),
      FinishScope.lesson => null,
    };
    if (message != null) showCelebration(context, message);
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

    // Same split the expansion reader makes: a warning teaches, a citation
    // proves, so citations and the boundary statement gather into one line
    // at the end instead of interrupting the lesson. None of the core 22
    // carry these blocks today, so this changes nothing for them and is
    // here so the two readers cannot drift apart the moment one does.
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

    if (reference.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LessonReferenceFooter(reference),
        ),
      );
    }

    children.add(RiseIn(index: step, child: _finishCard()));

    final position = _positionLabel();
    return Scaffold(
      appBar: AppBar(
        // Where am I, and in what. An empty bar left a reader who had
        // scrolled past the hero with no idea which lesson or course they
        // were inside.
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

  // Small on purpose: icon, kicker, title, one line on why it matters.
  Widget _hero(MoneyLesson l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SalapifyGlyph(l.icon, size: 28),
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
      // The named cover tier: one point up from the old off-ladder 27, and
      // the face now has exactly one definition, in screen_header.dart.
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

  Widget _phTag() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'PHILIPPINES',
      style: AppText.micro.w7.copyWith(letterSpacing: 1),
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
      style: AppText.caption.copyWith(height: 1.4),
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
                // The answer key existed only for people who could see the
                // border colour. Now it is spoken.
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
                      onTap: answered ? null : () => _answer(i),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Only the correct answer is ever highlighted. A
                          // wrong pick is not stained red: being wrong is how
                          // this works.
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
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: answered
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      // Spoken the moment it appears. This was silent, so a
                      // blind learner tapped an answer and heard nothing at
                      // all.
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          correct
                              ? 'That is it.'
                              : 'Close. Here is the thinking.',
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
                      // The expansion reader has always offered this. Two
                      // readers with the same-looking card and different
                      // rules is the drift this batch exists to stop: a
                      // mis-tap used to lock the wrong answer on screen for
                      // the rest of the visit.
                      if (!correct) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _picked = null),
                          icon: Icon(salapifyIcon('startOver'), size: 16),
                          label: const Text('Try again'),
                        ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// "3 of 6 in Your first cushion", or null for a lesson that is somehow
  /// not in the sequence (never in practice, but a missing id must not
  /// crash a reader).
  String? _positionLabel() {
    final i = widget.sequence.indexWhere((l) => l.id == widget.lesson.id);
    if (i < 0) return null;
    final me = widget.sequence[i];
    final inCourse = widget.sequence
        .where((l) => l.groupId == me.groupId)
        .toList();
    final pos = inCourse.indexWhere((l) => l.id == me.id) + 1;
    return '$pos of ${inCourse.length} · ${me.groupTitle}';
  }

  /// The moment a lesson ends.
  ///
  /// This used to be one quiet row and a back button, which made every
  /// lesson boundary an exit. It now closes the loop it opened: what you
  /// finished, the sentence worth keeping, where you are in the course, and
  /// the next lesson as a single tap.
  Widget _finishCard() {
    if (!_finished) {
      return OutlinedButton(
        onPressed: _finish,
        child: const Text('Finish this lesson'),
      );
    }
    final outcome = _outcome;
    final headline = switch (outcome?.scope) {
      FinishScope.path => 'Every core lesson done.',
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
          // Announced, because the payoff moment was silent to a screen
          // reader and the button that was focused disappeared on tap.
          Semantics(
            liveRegion: true,
            header: true,
            child: Row(
              children: [
                Icon(salapifyIcon('selected'), size: 18, color: Barako.primary),
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
          if (next != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onOpenLesson(next.id),
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                // Two lines by design. As one run the minutes wrapped onto
                // their own line anyway and left "min" stranded there,
                // which reads like a layout bug rather than a choice.
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
            // Always as reachable as the next lesson. Momentum is an offer,
            // never a corridor.
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
}
