// Plan. Questions 4 and 5 of the five in 01-vision.md: what is coming, and
// where does it go?
//
// 04-screens.md: "Plan holds Budget, Upcoming and Goals as three segments in
// one screen." Budget is built here (Phase 3 step 5). Upcoming and Goals are
// steps 6 and 8, and until then their segments say so plainly rather than
// drawing an empty screen that looks broken.
//
// The hero is the golden locked `budgetSummary`, unchanged: one monthly limit,
// what is spent against it, what is left. The per category rows underneath
// come from `budget_rows.dart`, which derives them from the caps the user set
// and this month's tagged expenses, and invents no money.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/state/financial_state.dart';
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../home/home_screen.dart' show shortDate;
import 'budget_editor.dart';
import 'budget_rows.dart';
import 'goal_editor.dart';
import 'goal_rows.dart';
import 'recurring_editor.dart';
import 'recurring_rows.dart';
import 'upcoming_rows.dart';

/// Which segment Plan shows, so another screen can send somebody to the right
/// one.
///
/// A plain notifier rather than a route parameter, and that is not laziness.
/// Plan is a branch of a `StatefulShellRoute`, which KEEPS each branch alive by
/// design: navigating to `/plan?seg=upcoming` switches to a Plan that is
/// already built, so `initState` never runs again and the query would be read
/// once and then ignored forever. Home's Bills action would work exactly once,
/// on the first visit, which is worse than not working at all because it would
/// look fixed.
///
/// It holds no money and no stored data, only which of three tabs is showing.
final planSegment = ValueNotifier<int>(0);

const int planBudget = 0;
const int planUpcoming = 1;
const int planGoals = 2;

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    planSegment.addListener(_onSegment);
  }

  @override
  void dispose() {
    planSegment.removeListener(_onSegment);
    super.dispose();
  }

  void _onSegment() {
    if (mounted) setState(() {});
  }

  int get _segment => planSegment.value;

  @override
  Widget build(BuildContext context) {
    return Screen(
      children: [
        const SizedBox(height: 14),
        // Covers all three segments, because it sits above all three. It used
        // to say "what is due before the next payday", which was true when
        // Upcoming was a placeholder and became wrong the moment Upcoming
        // started reaching to the payday AFTER next: a sentence contradicting
        // the list directly underneath it.
        const ScreenTitle(
          title: 'Plan',
          sub: 'Your budget, what is coming, and what you are saving for.',
        ),
        const SizedBox(height: 16),
        Segmented(
          options: const ['Budget', 'Upcoming', 'Goals'],
          index: _segment,
          // Writes the notifier, and the listener above turns that into the
          // rebuild. Tapping a segment and arriving from Home's Bills action
          // therefore travel the same path, so the two can never disagree about
          // which segment is showing.
          onPick: (i) => planSegment.value = i,
        ),
        const SizedBox(height: 20),
        switch (_segment) {
          0 => const _Budget(),
          1 => const _Upcoming(),
          _ => const _Goals(),
        },
      ],
    );
  }
}

// `_NotYet` lived here, the placeholder every unbuilt segment used. It is gone
// because all three segments are built: Goals was the last one holding a
// promise instead of a screen. Nothing else in the app referenced it, so it
// went with the promise rather than sitting here waiting for a fourth segment
// that is not on the roadmap.

/// Goals: what you are saving for, and whether you will make it.
///
/// 04-screens.md gives this segment one paragraph, and every figure in it
/// comes from `goal_rows.dart`, which composes the golden locked `goalPace`.
/// Nothing here computes money.
///
/// NOTHING ON THIS SEGMENT IS AN ASSET. A goal's money is a number the user
/// tracks, not a balance, so it appears in no total anywhere else in the app
/// and is never subtracted from safe to spend. See goal_rows.dart's header for
/// why, and the funding sheet says it out loud where somebody is about to
/// assume otherwise.
class _Goals extends StatelessWidget {
  const _Goals();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final data = context.ledger.data;
    final rows = goalRows(data, context.now);

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EmptyState(
            icon: Icons.flag_outlined,
            title: 'Nothing saved for yet',
            body:
                'Name one thing you are putting money aside for, give it an '
                'amount, and this shows what it takes each month to get there.',
          ),
          const SizedBox(height: 14),
          // The button the instruction asks for. An empty state whose
          // instruction cannot be followed is the defect this app has already
          // shipped twice, once on Accounts and once on Budget.
          PillButton(
            label: 'Add your first goal',
            icon: Icons.add_rounded,
            onTap: () => showGoalEditor(context),
          ),
        ],
      );
    }

    final summary = goalsSummary(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) ...[
          Text(summary, style: TypeScale.subtitle(skin.text2)),
          const SizedBox(height: 14),
        ],
        Group(inset: 0, children: [for (final r in rows) _GoalRowTile(row: r)]),
        const SizedBox(height: 14),
        PillButton(
          label: 'Add a goal',
          icon: Icons.add_rounded,
          onTap: () => showGoalEditor(context),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// One goal row: name, saved of target, the bar, and the caption.
class _GoalRowTile extends StatelessWidget {
  const _GoalRowTile({required this.row});
  final GoalRow row;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Pressable(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: TypeScale.rowTitle(
                      // A reached goal clears like a settled debt, which on a
                      // debt row means struck through and green. Struck
                      // through is wrong here: a paid debt is finished with,
                      // and a reached goal is an achievement. Same green, no
                      // strike.
                      row.reached ? skin.good : skin.text,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  // Saved OF TARGET, both figures, because one on its own
                  // cannot be read as progress. 04-screens.md asks for exactly
                  // this pair.
                  '${formatMoney(row.saved)} of ${formatMoney(row.target)}',
                  style: TypeScale.rowAmount(
                    row.reached ? skin.good : skin.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            // GREEN WHEN IT IS DONE, and this came out of looking at the
            // render rather than out of a test. The name and the amount both
            // turned green on a reached goal and the bar underneath them
            // stayed accent, so the one row that is finished was drawn in two
            // colours arguing with each other: green saying "done" and the
            // app's "in progress" orange right below it.
            ThinBar(
              fraction: row.fraction,
              fill: row.reached ? skin.good : null,
            ),
            const SizedBox(height: 7),
            Text(goalRowCaption(row), style: TypeScale.caption(skin.text3)),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final data = context.ledger.data;
    final goal = [
      for (final g in (data['goals'] as List? ?? const []))
        if (g is Map && g['id'] == row.id) g.cast<String, dynamic>(),
    ].firstOrNull;
    if (goal == null) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _GoalActions(goal: goal, row: row, parent: context),
    );
  }
}

/// What you can do to a goal, once you have tapped it.
///
/// A sheet rather than three controls on the row, for the reason the account
/// Options sheet gives: the row's job is showing progress, and a list where
/// every row carries three buttons stops being a list.
class _GoalActions extends StatelessWidget {
  const _GoalActions({
    required this.goal,
    required this.row,
    required this.parent,
  });

  final Map<String, dynamic> goal;
  final GoalRow row;

  /// The screen's context, not the sheet's. Opening the next sheet from the
  /// sheet's own context after popping it uses a dead element.
  final BuildContext parent;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(row.name, style: TypeScale.sheetTitle(skin.text)),
          const SizedBox(height: 4),
          Text(goalRowCaption(row), style: TypeScale.caption(skin.text3)),
          const SizedBox(height: 18),

          // Adding money stays offered on a reached goal. People overshoot on
          // purpose, and an app that refuses the last deposit because its own
          // arithmetic says you are finished is arguing with the user about
          // their own savings.
          PillButton(
            label: 'Add money',
            icon: Icons.add_rounded,
            onTap: () {
              Navigator.of(context).pop();
              showGoalFunding(parent, goal: goal);
            },
          ),
          const SizedBox(height: 10),
          _TextAction(
            label: 'Edit this goal',
            onTap: () {
              Navigator.of(context).pop();
              showGoalEditor(parent, existing: goal);
            },
          ),
          _TextAction(
            label: row.paused ? 'Resume this goal' : 'Pause this goal',
            onTap: () {
              final paused = row.paused;
              final id = row.id;
              Navigator.of(context).pop();
              parent.ledger.mutate((draft) {
                for (final g
                    in (draft['goals'] is List
                        ? draft['goals'] as List
                        : const [])) {
                  if (g is Map && g['id'] == id) g['paused'] = !paused;
                }
              });
            },
          ),
          const SizedBox(height: 10),
          // PAUSING IS NOT DELETING, and the difference is worth a sentence.
          // Nothing in this app deletes a goal yet, deliberately: a goal
          // carries its whole contribution history and there is no undo for
          // losing it. Pausing stops the pacing and keeps the record.
          Text(
            'Pausing keeps everything you have saved and stops asking for a '
            'monthly amount.',
            style: TypeScale.caption(skin.text3),
          ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TypeScale.action(context.skin.accent),
      ),
    ),
  );
}

/// Upcoming: every bill and payday out to the payday AFTER next.
///
/// Home answers "what is due before THIS payday". This answers the next
/// question a semimonthly earner actually asks, which is whether the sweldo
/// about to arrive covers what is coming before the one after it. Both read
/// their bills from the same ledger and a test asserts they agree on every
/// bill they both hold, because two screens describing one month differently
/// is a defect this app has already had to fix once.
class _Upcoming extends StatelessWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;
    final up = upcomingFrom(data, now);

    if (up.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EmptyState(
            icon: Icons.event_outlined,
            title: 'Nothing scheduled yet',
            body:
                'Tell Salapify what repeats every month, the rent, Meralco, '
                'your sweldo, and everything due between now and the payday '
                'after next lands here.',
          ),
          const SizedBox(height: 14),
          // THE BUTTON THE INSTRUCTION ASKS FOR. This empty state said "Add a
          // bill that repeats" on a screen where that could not be done, for
          // as long as the screen existed. An instruction nobody can follow is
          // the same defect Accounts and Budget both shipped.
          PillButton(
            label: 'Add the first one',
            icon: Icons.add_rounded,
            onTap: () => showRecurringEditor(context),
          ),
        ],
      );
    }

    // THE ONE DAY THE HERO NAMES, derived here so the hero and the list
    // cannot name two different days.
    //
    // They did. The hero's negative branch names `firstNegativeDate`, which is
    // correct and is NOT `lowestDate` (see the comment inside `_LowPoint`), and
    // the list marked `lowestDate` unconditionally. So an overcommitted month
    // said "You go below zero on Oct 3" while the Oct 3 row carried no mark at
    // all and a row on Oct 14 was labelled "The tightest day", a phrase the
    // hero never used in that branch. The screen named one day and highlighted
    // another, which is the hero-versus-list contradiction this file has now
    // had to fix three times.
    final heroDate = up.goesNegative && up.firstNegativeDate != up.todayIso
        ? up.firstNegativeDate
        : up.lowestDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LowPoint(up: up),
        const SizedBox(height: 22),
        // Names the end date rather than saying "then". A head with no action
        // has to earn its line by saying something, and "Between now and then"
        // left the screen's entire defining idea, the payday after next,
        // undefined: the hero says 19 days and nothing said whether that
        // reaches past the rent.
        //
        // IT ALSO CARRIES THE TOTAL NOW, which used to sit in the hero's
        // sentence. Two reasons it moved. A whole-window sum inside a sentence
        // whose subject is one day reads as that day's cost, which is wrong in
        // a money-shaped way. And a panel built around one figure at 47 points
        // cannot hold a second, larger figure without making the reader decide
        // which one is the headline.
        //
        // "Going out before" rather than a bare amount, for the same reason
        // every day row says "left": an unlabelled peso figure above a column
        // of running balances is read as another running balance. Tone stays
        // plain, because the accent means owed or tappable and this is neither.
        Head(
          title: 'Going out before ${prettyDay(up.horizonEnd)}',
          amount: formatMoney(up.totalOut),
        ),
        const SizedBox(height: 8),
        Group(
          inset: 0,
          children: [
            for (final d in up.days)
              _UpcomingDayRow(
                day: d,
                heroDate: heroDate,
                goesNegative: up.goesNegative,
                anyIncome: up.anyIncome,
              ),
          ],
        ),
        const SizedBox(height: 22),

        // WHAT GENERATES THE LIST ABOVE, which until now a person could
        // neither see nor change. The days are occurrences; these are the
        // things that produce them, and editing one is the only way to correct
        // a bill whose amount went up.
        const _Repeating(),

        // THE DISCLOSURE, and it is deliberately NOT on the hero.
        //
        // The founder asked whether an "i" belonged on the low point card. It
        // does not. The hero carries the one figure the screen exists for, and
        // an "i" on the biggest text on a screen is an admission that the
        // biggest text does not say what it means. The answer to a sentence
        // nobody can parse is a shorter sentence, not a footnote behind a tap.
        //
        // What IS genuinely unsayable in a hero sentence is the machinery: why
        // the window ends where it does, what the low point is a minimum OF,
        // and why a debt already paid can still be counted. Those govern the
        // whole segment rather than the card, so the door sits at the bottom of
        // the segment, in the shape this file already uses for a text action.
        const SizedBox(height: 6),
        _TextAction(
          label: 'How this projection works',
          onTap: () => _showUpcomingHelp(context),
        ),
      ],
    );
  }
}

/// What the projection is doing, for somebody who wants to check it.
///
/// Four entries and not one more, the same cap the budget sheet keeps. Every
/// one of them is a rule a person cannot work out by looking at the screen,
/// and every one is true of the code as written rather than of the code we
/// wish were there.
const _upcomingHelp = <(String, String)>[
  (
    'Where the window ends',
    'It runs to the payday after the next one, because that is the stretch '
        'your sweldo actually has to cover. With no payday set yet, we use 30 '
        'days instead.',
  ),
  (
    'What the low point means',
    'We walk the days one at a time, take out every bill and put in every '
        'salary, and keep the smallest figure we see. It is the worst moment '
        'in the window, not the figure you end on.',
  ),
  (
    'Why a debt can show even if you paid it',
    'A debt has no record of which months you have already paid, so every '
        'cycle inside the window is counted as still due. That makes this '
        'careful rather than optimistic.',
  ),
  (
    'None of this has happened yet',
    'These are scheduled amounts, not entries. Nothing on this list has '
        'touched your balances, and logging it is what makes it real.',
  ),
];

void _showUpcomingHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Without this the sheet lands UNDER the nav bar, which is the one bug
    // every sheet in this app has shipped at least once.
    //
    // AND IT IS WHY THE CONTEXT BELOW MATTERS. This pushes the sheet onto the
    // ROOT navigator, while the Plan screen's own context resolves to the tab
    // shell's inner one. The first version of this closed on
    // `Navigator.of(context).pop()` with the outer context, so Done did not
    // close the sheet at all: it popped the PLAN PAGE off the shell stack and
    // left the shell with nothing to draw. The founder tapped Done and got a
    // black screen. Every context below is the SHEET's.
    useRootNavigator: true,
    // The skin is read INSIDE the builder, not captured from the caller, so
    // flipping the system theme with the sheet open repaints it.
    builder: (sheetContext) {
      final skin = sheetContext.skin;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        decoration: BoxDecoration(
          color: skin.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'How this projection works',
                    style: TypeScale.sheetTitle(skin.text),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  child: Text('Done', style: TypeScale.action(skin.text2)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (title, body) in _upcomingHelp) ...[
                      Text(title, style: TypeScale.fieldLabel(skin.text2)),
                      const SizedBox(height: 5),
                      Text(body, style: TypeScale.caption(skin.text3)),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The repeating items themselves: rent, Meralco, the sweldo.
class _Repeating extends StatelessWidget {
  const _Repeating();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final data = context.ledger.data;
    final now = context.now;
    final rows = recurringRows(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Head(title: 'What repeats'),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            // Named as the gap it is. Safe to spend is liquid MINUS what is
            // committed, so with nothing here the figure counts the rent as
            // spendable. Saying so is the difference between a quiet empty
            // list and a reason to fill it.
            'Nothing recorded yet, so what you can spend still counts your '
            'bills as available.',
            style: TypeScale.subtitle(skin.text2),
          )
        else ...[
          Text(recurringSummary(rows), style: TypeScale.subtitle(skin.text2)),
          // WHY YOUR NUMBER DID NOT MOVE. Safe to spend runs to the next
          // payday, so a bill falling after it is correctly left out, and
          // without this line the screen gives no way to tell that from the
          // app having ignored what you typed. Renders only when there IS
          // something outside the cycle.
          if (outsideCycleNote(rows, data, now).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              outsideCycleNote(rows, data, now),
              style: TypeScale.caption(skin.text3),
            ),
          ],
          const SizedBox(height: 12),
          Group(
            children: [
              for (final r in rows)
                ItemRow(
                  icon: r.income
                      ? Icons.savings_outlined
                      : Icons.event_repeat_outlined,
                  title: r.label,
                  sub: recurringCaption(r, now),
                  amount: formatMoney(r.amount),
                  // Income is the only thing coloured, the same rule the
                  // Ledger uses: colour means direction, and colouring every
                  // amount would leave colour meaning nothing.
                  tone: r.income ? Tone.good : Tone.plain,
                  onTap: () => _edit(context, r.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        PillButton(
          label: rows.isEmpty ? 'Add the first one' : 'Add another',
          icon: Icons.add_rounded,
          onTap: () => showRecurringEditor(context),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  void _edit(BuildContext context, String id) {
    final existing = [
      for (final r in (context.ledger.data['recurring'] as List? ?? const []))
        if (r is Map && r['id'] == id) r.cast<String, dynamic>(),
    ].firstOrNull;
    if (existing == null) return;
    showRecurringEditor(context, existing: existing);
  }
}

/// The one number this screen exists for: the lowest the money gets.
///
/// A list of dates says what is coming. It does not say whether you make it,
/// and that is the question. `sweldoTimeline` already walks the window day by
/// day and reports its own low point, so nothing is recomputed here.
class _LowPoint extends StatelessWidget {
  const _LowPoint({required this.up});
  final Upcoming up;

  @override
  Widget build(BuildContext context) {
    // Two sentences, and which one shows is the whole point. Going under is
    // not a smaller version of staying above: it is a different event and it
    // gets said in words, not left for somebody to read off a colour.
    //
    // THE DATE IN THE SHORT CASE IS firstNegativeDate, NOT lowestDate, and the
    // first version got this wrong. They are different days and can be far
    // apart: dip under on the 13th, keep sinking to the minimum on the 25th,
    // and "your money runs out around the 25th" is twelve days late on the one
    // sentence in this app somebody actually has to act on.
    final sentence = up.goesNegative
        ? (up.firstNegativeDate == up.todayIso
              ? 'You are already below zero. Something has to move.'
              : 'You go below zero on ${prettyDay(up.firstNegativeDate)}. '
                    'Something has to move before then.')
        // "Is due to go out", never "goes out". The engine counts a debt
        // cycle while the balance is above zero even if it was already paid
        // early, because debts carry no per-cycle paid marker. Safe and
        // correct for a schedule, wrong as a claim about what has left.
        //
        // And no clause attributing the recovery to income. The data
        // supports "nothing takes you lower inside this window" and does not
        // support "everything after it is covered by what comes in", which
        // the first version said and which reads as open ended on a window
        // that ends at the payday after next.
        // ONE CLAUSE OF FACT, ONE OF VERDICT, and everything else cut. The
        // founder read this card and asked what it meant, which is the only
        // review that counts on the one figure a screen exists for.
        //
        // Three clauses went. "The tightest day is" restated the kicker's own
        // adjective, so only the DATE was new. The total moved to the section
        // head, where the rows that add up to it live. And "this is as low as
        // it gets" said LOWEST a second time.
        //
        // The window end date went too: it was printed here and again twenty
        // two points below, on the head. Two dates one day apart, meaning the
        // tightest day and the edge of the window, sitting in one sentence,
        // reads as a typo rather than as two ideas.
        //
        // "You stay above zero" is safe to assert here and is not a guess.
        // `goesNegative` is set on any day-END balance below zero, and the
        // figure above is the minimum of those same day-end balances, so a
        // false `goesNegative` and a negative hero figure cannot coexist.
        : 'Your tightest day is ${prettyDay(up.lowestDate)}, and you stay '
              'above zero.';

    return HeroPanel(
      // NAMES ITS SUBJECT. "LOWEST IN THE NEXT 30 DAYS" is an adjective with
      // the noun missing, over a peso figure, on a screen whose list underneath
      // is full of bills: the available readings included the smallest bill and
      // the least spent. Home says SAFE TO SPEND and the Budget hero says LEFT
      // TO SPEND THIS MONTH, both complete phrases. This one was the outlier.
      kicker: 'LOWEST BALANCE, NEXT ${up.horizonDays} DAYS',
      whole: wholePesos(up.lowest),
      cents: centsOf(up.lowest),
      sentence: sentence,
    );
  }
}

/// One day: what happens, and what is left afterwards.
class _UpcomingDayRow extends StatelessWidget {
  const _UpcomingDayRow({
    required this.day,
    required this.heroDate,
    required this.goesNegative,
    required this.anyIncome,
  });
  final UpcomingDay day;

  /// So the row the hero named can mark itself. Passed in rather than read
  /// again, because two derivations of "the day this screen is about" is one
  /// more than this screen is allowed to have.
  ///
  /// It used to be `lowestDate`, which was the WRONG day in the branch that
  /// matters most: on an overcommitted month the hero names the day you go
  /// below zero and the list highlighted the day you bottom out, which can be
  /// weeks apart. `_Upcoming` now derives one date for both.
  final String heroDate;

  /// Which sentence the hero used, so this row's caption says the same thing.
  final bool goesNegative;

  /// Whether any money arrives anywhere in the window, so the payday copy
  /// can stop making an account-wide claim from a per-day fact.
  final bool anyIncome;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    final hasIncome = day.events.any((e) => e.isIncome);

    return Padding(
      // 13, the same beat as ItemRow, so days and entries line up when you
      // flick between Ledger and Plan.
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The DATE is short and fixed and the money is the variable width
              // thing, so the money is what flexes. With Expanded on the date,
              // a seven figure balance at 2.0x text squeezed "Sep 11" into
              // three lines while the amount sat comfortably. Now the amount
              // ellipsizes at the extreme, which is the sanctioned failure.
              Text(prettyDay(day.date), style: TypeScale.rowTitle(skin.text)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // What is LEFT after the day, not what the day cost. The
                    // cost is on the rows underneath; this column is the
                    // running answer to "am I still fine", which is the only
                    // reason to read a projection rather than a calendar.
                    // The hero's day gets FULL ink, and it is the only row in
                    // the column that does. The hero's figure and this row's
                    // balance are literally the same double printed twice,
                    // and until now nothing on screen said so: the eye came
                    // down off a 47 point number and landed on a column where
                    // every row looked identical.
                    Text(
                      formatMoney(day.balanceAfter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TypeScale.rowAmount(
                        day.balanceAfter < 0
                            ? skin.bad
                            : (day.date == heroDate ? skin.text : skin.text2),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // ONE QUIET WORD, and it is doing real work. Without it the
                    // right column is two meanings in one ink: a running
                    // balance and, three points below, what a bill costs. The
                    // most available reading of "Sep 11 ₱6,460.50" with
                    // "Meralco ₱3,200" under it is "Sep 11 costs ₱6,460.50",
                    // which is wrong in a money-shaped way, so it gets
                    // confirmed on some rows and contradicted on others rather
                    // than caught. "left" is already the app's word for this,
                    // on Budget rows and on the other Plan hero. It also fixes
                    // the screen reader, which otherwise says an
                    // undifferentiated run of pesos.
                    Text('left', style: TypeScale.captionSm(skin.text3)),
                  ],
                ),
              ),
            ],
          ),
          // A payday earns its row even with nothing attached, because the DATE
          // is the information. It is marked with the WORD rather than a green
          // date: green means money coming in, and on a payday with no salary
          // set up a green date promises money that the caption underneath
          // then denies. A colour that means two things means neither.
          if (day.isPayday) ...[
            const SizedBox(height: 4),
            Text(
              // THREE CASES, because two could not tell the truth. The first
              // version asked a per-DAY question ("does income land today")
              // and answered with an account-wide claim ("no salary set up
              // yet"). A recurring row carries one dayOfMonth and a
              // semimonthly schedule has two paydays, so every semimonthly
              // earner read "no salary set up yet" on half their payday rows
              // with their sweldo printed two rows above it.
              //
              // No "set it up in Settings" on the last one, because there is
              // no payday or income editor in this build, and pointing at a
              // control that does not exist is the defect this batch started
              // from.
              hasIncome
                  ? 'Payday'
                  : anyIncome
                  ? 'Payday. Nothing lands on this one.'
                  : 'Payday. No salary set up yet, so nothing is added here.',
              style: TypeScale.caption(skin.text3),
            ),
          ],
          // The day the hero named, findable once the hero has scrolled away,
          // and saying the SAME WORDS the hero used.
          //
          // It is one weight and one size above the captions around it, which
          // is the point: the most important row in the list was marked in the
          // quietest ink in the palette, the same token as the payday line four
          // lines up and the event labels below. Not accent, because accent is
          // the tappable colour and this is not a control.
          if (day.date == heroDate) ...[
            const SizedBox(height: 4),
            Text(
              goesNegative ? 'You go below zero here' : 'The tightest day',
              style: TypeScale.hintStrong(
                day.balanceAfter < 0 ? skin.bad : skin.text2,
              ),
            ),
          ],
          for (final e in day.events) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  e.isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 16,
                  color: e.isIncome ? skin.good : skin.text3,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    e.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // text3, matching ItemRow's ink ladder: two primary things
                    // dark, the secondary pair quiet. Three of the four were
                    // text2, which is why the right column read flat.
                    style: TypeScale.caption(skin.text3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMoney(e.amount),
                  // Only money coming in is green, the rule Home and Ledger
                  // already follow. An ordinary bill sits in the quiet ink.
                  style: TypeScale.captionSm(
                    e.isIncome ? skin.good : skin.text3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Budget extends StatelessWidget {
  const _Budget();

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;
    // The SAME composed truth Home reads. Not a second reading of the engine.
    final state = FinancialState.of(data, now);
    final rows = categoryBudgets(data, now);
    final limit = state.budgetLimit;

    // Nothing set AND nothing tagged. A screen that draws a zero budget hero
    // over an empty list is telling somebody they have ₱0 to spend, which is
    // a different statement from "you have not set this up".
    if (limit <= 0 && rows.isEmpty) {
      return Column(
        children: [
          const EmptyState(
            icon: Icons.donut_small_outlined,
            title: 'No budget set',
            body:
                'Set a monthly amount and a cap per category, and this screen '
                'shows what is LEFT rather than only what is spent.',
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Set your budget',
            icon: Icons.add_rounded,
            onTap: () => showBudgetEditor(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (limit > 0) ...[
          _LeftToSpend(state: state, needing: needALook(rows)),
          const SizedBox(height: 22),
        ],
        // The heading shows whenever EITHER half of the budget exists, not
        // only when there are rows, and that is a bug fix rather than a
        // preference. The two doors into the editor used to be the empty state
        // (limit <= 0 AND no rows) and this heading (rows not empty). Set a
        // monthly limit and leave every cap blank, which the sheet explicitly
        // invites you to do, and BOTH doors close: the limit kills the empty
        // state, the missing rows kill the heading, and the hero renders alone
        // with no control anywhere in the app that can change it. Four taps
        // from a fresh install to a number the user can never edit again,
        // which is the exact defect class this whole change set exists to fix.
        if (limit > 0 || rows.isNotEmpty) ...[
          Head(
            title: 'By category',
            action: limit > 0 ? 'Edit' : 'Set limits',
            onAction: () => showBudgetEditor(context),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const EmptyState(
              icon: Icons.donut_small_outlined,
              title: 'No category limits yet',
              body:
                  'Your monthly limit is set. Add a cap to a category and this '
                  'screen shows what is left in it, not only what is spent.',
            )
          else
            Group(children: [for (final r in rows) _CategoryRow(row: r)]),
        ],
      ],
    );
  }
}

/// The hero: what is left of the monthly limit.
///
/// It does NOT pace. That is the whole point of this class now.
///
/// It used to say "₱697.73 a day for the 20 days left this month" while Home,
/// on the same ledger at the same moment, said "₱1,566.63 a day until payday".
/// Both were right on their own terms: one divided by days to month end, the
/// other by days to the next payday. Two periods, two denominators, two numbers
/// that can never agree, and no test caught it because neither was wrong.
///
/// The app now has exactly ONE pacing figure and it belongs to the payday
/// cycle, on Home, because that is the span a semimonthly earner actually
/// lives in. A monthly budget is still a real and useful thing to keep: people
/// think in monthly rent and monthly salary, and `budgetSummary` is golden
/// locked to a calendar month. It answers "am I within my limit", which is a
/// different question from "what can I spend today", and this panel now only
/// answers the one it can.
class _LeftToSpend extends StatelessWidget {
  const _LeftToSpend({required this.state, required this.needing});
  final FinancialState state;
  final int needing;

  @override
  Widget build(BuildContext context) {
    final remaining = state.budgetRemaining;
    final limit = state.budgetLimit;
    final spent = state.budgetSpent;
    final over = state.budgetOver;

    final String sentence;
    if (over) {
      sentence =
          'You are ${formatMoney(spent - limit)} over your monthly limit.';
    } else {
      // Names the CYCLE, the same one Home names, so the two screens describe
      // one period even though they answer different questions about it.
      sentence = state.cycle.explicit
          ? 'Your limit for the month, with payday on '
                '${shortDate(state.cycle.end)}.'
          : 'Your limit for the month.';
    }

    return HeroPanel(
      kicker: 'LEFT TO SPEND THIS MONTH',
      whole: wholePesos(remaining),
      cents: centsOf(remaining),
      sentence: sentence,
      rail: HeroRail(
        // Spent against the limit, so the bar fills as the month is used up,
        // the same direction the payday rail on Home runs.
        fraction: limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0),
        left: needing == 0
            ? 'Every category has room'
            : '$needing ${needing == 1 ? 'category needs' : 'categories need'} '
                  'a look',
        right: '${formatMoney(spent)} of ${formatMoney(limit)}',
      ),
    );
  }
}

/// One category: the emoji, the name, what is left, and a bar.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.row});
  final BudgetRow row;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // Three states, and each says the word as well as taking the colour.
    // Somebody reading a bar in orange has to already know the rule; the
    // caption does not ask them to.
    final (String caption, Color captionInk, Color barInk) = switch (row) {
      final r when !r.capped => ('No limit set', skin.text3, skin.line),
      final r when r.over => (
        'over by ${formatMoney(r.spent - r.cap)}',
        skin.bad,
        skin.bad,
      ),
      final r when r.remaining == 0 => (
        'all of it spent',
        skin.text3,
        skin.accent,
      ),
      final r when r.needsALook => (
        '${formatMoney(r.remaining)} left of ${formatMoney(r.cap)}',
        skin.accent,
        skin.accent,
      ),
      final r => (
        '${formatMoney(r.remaining)} left of ${formatMoney(r.cap)}',
        skin.text3,
        skin.good,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The user's emoji, untouched. Category icons are their data,
              // not ours to restyle.
              if (row.icon.isNotEmpty) ...[
                Text(row.icon, style: TypeScale.rowTitle(skin.text)),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.rowTitle(skin.text),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatMoney(row.spent),
                style: TypeScale.rowAmount(skin.text),
              ),
            ],
          ),
          // No bar without a limit. An empty track is a promise that something
          // will fill it, and nothing can: there is no limit for the spend to
          // be a fraction OF. The first render drew two of them and they read
          // as rows still loading.
          if (row.capped) ...[
            const SizedBox(height: 9),
            ThinBar(fraction: row.fraction, fill: barInk),
          ],
          const SizedBox(height: 7),
          Text(caption, style: TypeScale.caption(captionInk)),
        ],
      ),
    );
  }
}
