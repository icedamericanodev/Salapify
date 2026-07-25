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
import '../money/lesson_progress.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(context, l));
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

  void _open(BuildContext context, Map<String, dynamic> lesson) {
    final typed = lessonFromMap(lesson);
    // Opening is NOT finishing. This used to mark the lesson read here, so
    // tapping a card and backing straight out counted as learned forever and
    // the progress figure measured taps. Opening now records inProgress; only
    // reaching the end of the lesson earns learned.
    //
    // Recording is best effort and never blocks reading: a read-only store
    // (after a failed load) must still let the user read.
    if (widget.store.canWrite) {
      widget.store.setLessonState(typed.id, LessonState.inProgress);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LessonReader(
          lesson: typed,
          onAction: _resolveAction(
            context,
            (lesson['action'] as Map?)?.cast<String, dynamic>(),
          ),
          onLearned: widget.store.canWrite
              ? () => widget.store.setLessonState(typed.id, LessonState.learned)
              : null,
        ),
      ),
    );
  }

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
            final read = {
              for (final e in progress.entries)
                if (e.value == LessonState.learned) e.key,
            };
            final readCount = read.length;
            final featured = lessonOfTheDay(DateTime.now());
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR PROGRESS', style: Barako.kickerStyle),
                        const SizedBox(height: 6),
                        Text(
                          '$readCount of ${lessons.length} lessons done',
                          style: TextStyle(
                            color: Barako.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: lessons.isEmpty
                                ? 0
                                : readCount / lessons.length,
                            minHeight: 8,
                            backgroundColor: Barako.border,
                            color: Barako.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Four short courses. Every lesson ends with one '
                          'real step in the app. Always free.',
                          style: TextStyle(color: Barako.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('LESSON OF THE DAY', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                _lessonCard(
                  featured,
                  read.contains(featured['id']),
                  featured: true,
                ),
                for (final track in courseTracks) ...[
                  const SizedBox(height: 20),
                  _trackHeader(track, read),
                  const SizedBox(height: 8),
                  for (final l in lessonsForTrack(track['key'] as String))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _lessonCard(l, read.contains(l['id'])),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _trackHeader(Map<String, dynamic> track, Set<String> read) {
    final all = lessonsForTrack(track['key'] as String);
    final done = all.where((l) => read.contains(l['id'])).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              track['emoji'] as String,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (track['title'] as String).toUpperCase(),
                style: Barako.kickerStyle,
              ),
            ),
            Text(
              '$done of ${all.length}',
              style: TextStyle(
                color: done == all.length ? Barako.primaryText : Barako.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          track['outcome'] as String,
          style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: all.isEmpty ? 0 : done / all.length,
            minHeight: 4,
            backgroundColor: Barako.border,
            color: Barako.primary,
          ),
        ),
      ],
    );
  }

  Widget _lessonCard(
    Map<String, dynamic> l,
    bool isRead, {
    bool featured = false,
  }) {
    final isPH = l['region'] == 'PH';
    return PressableScale(
      child: Card(
        color: featured ? Barako.surfaceRaised : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(context, l),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  l['emoji'] as String,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (featured) ...[
                        Text(
                          'TODAY',
                          style: Barako.kickerStyle.copyWith(
                            color: Barako.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        l['title'] as String,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l['summary'] as String,
                        style: TextStyle(color: Barako.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Flexible so the PHILIPPINES chip can never push
                          // this row into an overflow on a narrow phone.
                          Flexible(
                            child: Text(
                              '${l['minutes']} min read',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Barako.faint,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (isPH) ...[
                            const SizedBox(width: 8),
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    isRead ? Icons.check_circle : Icons.chevron_right,
                    key: ValueKey<bool>(isRead),
                    color: isRead ? Barako.primary : Barako.faint,
                    size: isRead ? 20 : 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reading view for one lesson: the objective, the body in its real
/// sections, the knowledge check, the takeaway, and the one action that turns
/// the lesson into a step.
///
/// This screen owns completion. A lesson becomes learned when the reader
/// reaches the end: by answering the knowledge check where one exists, or by
/// confirming they have read it where one does not yet. The in-app action is
/// never required, because requiring it would push people to invent financial
/// records just to finish a lesson.
class _LessonReader extends StatefulWidget {
  final MoneyLesson lesson;
  final VoidCallback? onAction;
  final VoidCallback? onLearned;
  const _LessonReader({required this.lesson, this.onAction, this.onLearned});

  @override
  State<_LessonReader> createState() => _LessonReaderState();
}

class _LessonReaderState extends State<_LessonReader> {
  int? _picked;
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onLearned?.call();
  }

  void _answer(int i) {
    setState(() => _picked = i);
    // Right or wrong, the learner has engaged with the decision, which is what
    // the check is for. Being wrong never costs progress.
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
      ),
      body: SafeArea(
        // Cap the reading measure so paragraphs never run edge to edge on a
        // tablet or landscape phone (flutter-ui-polish typography rule).
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(l.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  l.title,
                  style: TextStyle(
                    fontFamily: Barako.displayFont,
                    color: Barako.text,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${l.minutes} min read',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Barako.muted, fontSize: 12),
                      ),
                    ),
                    if (l.isPhilippines) ...[
                      const SizedBox(width: 8),
                      _phTag(),
                    ],
                  ],
                ),
                if (l.isPhilippines) ...[
                  const SizedBox(height: 10),
                  _scopeNote(l),
                ],
                if (l.objective.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _objectiveBox(l.objective),
                ],
                const SizedBox(height: 20),
                for (final section in l.sections) ..._section(section),
                if (l.commonMistake.isNotEmpty) ...[
                  _mistakeBox(l.commonMistake),
                  const SizedBox(height: 16),
                ],
                if (l.check != null) _checkBox(l.check!),
                if (l.keyTakeaway.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _takeawayBox(l.keyTakeaway),
                ],
                // No check yet on this lesson, so the end of the reading is
                // the completion point. Without this, a lesson with no check
                // could never be finished at all.
                if (l.check == null) ...[
                  const SizedBox(height: 16),
                  _doneButton(),
                ],
                if (l.action != null && widget.onAction != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: widget.onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l.action!.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  // The regional scope goes near the TOP, never buried at the end, so a reader
  // outside the Philippines knows before acting on any of it.
  Widget _scopeNote(MoneyLesson l) {
    final checked = l.factCheckedOn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Barako.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'The rules in this lesson are Philippine rules. The idea behind them '
        'works anywhere, but the rates and deadlines do not. Always confirm '
        'with the agency or a licensed professional before you act.'
        '${checked != null ? ' Facts last checked $checked.' : ''}',
        style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _objectiveBox(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.flag_outlined, size: 16, color: Barako.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: Barako.text,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  List<Widget> _section(LessonSection s) {
    final heading = s.heading.isNotEmpty ? s.heading : _defaultHeading(s.kind);
    return [
      if (heading.isNotEmpty) ...[
        Text(heading.toUpperCase(), style: Barako.kickerStyle),
        const SizedBox(height: 8),
      ],
      if (s.kind == SectionKind.steps)
        for (var i = 0; i < s.body.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      color: Barako.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.body[i],
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )
      else if (s.kind == SectionKind.example)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Barako.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in s.body)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    p,
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        )
      else
        for (final p in s.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              p,
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
      const SizedBox(height: 4),
    ];
  }

  String _defaultHeading(SectionKind k) => switch (k) {
    SectionKind.context => 'Why it matters',
    SectionKind.concept => '',
    SectionKind.steps => 'How to do it',
    SectionKind.example => 'For example',
    SectionKind.warning => 'Watch out for',
    SectionKind.takeaway => 'Remember',
  };

  Widget _mistakeBox(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 18, color: Barako.warningStrong),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A COMMON MISTAKE', style: Barako.kickerStyle),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _checkBox(KnowledgeCheck c) {
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
              fontWeight: FontWeight.w600,
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
                    border: Border.all(
                      // Only the CORRECT answer is ever highlighted. A wrong
                      // pick is not stained red: being wrong here is how the
                      // lesson works, not a failure to punish.
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
          if (answered) ...[
            const SizedBox(height: 4),
            Text(
              correct ? 'That is it.' : 'Close. Here is the thinking.',
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
        ],
      ),
    );
  }

  Widget _takeawayBox(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.positiveSurface,
      border: Border.all(color: Barako.positiveBorder),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WORTH REMEMBERING', style: Barako.kickerStyle),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            color: Barako.text,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _doneButton() => _done
      ? Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: Barako.primary),
            const SizedBox(width: 8),
            Text(
              'Marked as done',
              style: TextStyle(
                color: Barako.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        )
      : OutlinedButton(
          onPressed: () => setState(_finish),
          child: const Text('I have read this'),
        );
}
