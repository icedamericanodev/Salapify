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
import 'upcoming_rows.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _segment = 0;

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
          onPick: (i) => setState(() => _segment = i),
        ),
        const SizedBox(height: 20),
        switch (_segment) {
          0 => const _Budget(),
          1 => const _Upcoming(),
          _ => const _NotYet(
            icon: Icons.flag_outlined,
            title: 'Goals are coming',
            body:
                'One row per goal, what you have saved against the target, and '
                'what it takes each month to make it by the date you picked.',
          ),
        },
      ],
    );
  }
}

/// A segment that is honestly empty.
///
/// Not a dead control: it responds to the tap and says what will be there. The
/// alternative, leaving the segment out until it is built, moves the other two
/// every time one lands, and the alternative to THAT is a tap that appears to
/// do nothing, which is the defect that had to be fixed on Home.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, title: title, body: body);
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
      return const EmptyState(
        icon: Icons.event_outlined,
        title: 'Nothing scheduled yet',
        body:
            'Add a bill that repeats, or set your payday, and everything due '
            'between now and the payday after next lands here.',
      );
    }

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
        Head(title: 'Between now and ${prettyDay(up.horizonEnd)}'),
        const SizedBox(height: 8),
        Group(
          inset: 0,
          children: [
            for (final d in up.days)
              _UpcomingDayRow(day: d, lowestDate: up.lowestDate),
          ],
        ),
      ],
    );
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
        : 'The tightest day is ${prettyDay(up.lowestDate)}. '
              '${formatMoney(up.totalOut)} is due to go out before '
              '${prettyDay(up.horizonEnd)}, and this is as low as it gets.';

    return HeroPanel(
      kicker: 'LOWEST IN THE NEXT ${up.horizonDays} DAYS',
      whole: wholePesos(up.lowest),
      cents: centsOf(up.lowest),
      sentence: sentence,
    );
  }
}

/// One day: what happens, and what is left afterwards.
class _UpcomingDayRow extends StatelessWidget {
  const _UpcomingDayRow({required this.day, required this.lowestDate});
  final UpcomingDay day;

  /// So the row the hero named can mark itself. Passed in rather than read
  /// again, because two derivations of "the tightest day" is one more than
  /// this screen is allowed to have.
  final String lowestDate;

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
                    Text(
                      formatMoney(day.balanceAfter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TypeScale.rowAmount(
                        day.balanceAfter < 0 ? skin.bad : skin.text2,
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
              hasIncome
                  ? 'Payday'
                  // Explains the thing that otherwise looks broken: with no
                  // salary, the balance is unchanged across the payday and the
                  // projection appears frozen. No "set it up in Settings",
                  // because there is no payday or income editor in this build
                  // and pointing at a control that does not exist is the defect
                  // this whole batch started from.
                  : 'Payday. No salary set up yet, so nothing is added here.',
              style: TypeScale.caption(skin.text3),
            ),
          ],
          // The day the hero named, findable once the hero has scrolled away.
          if (day.date == lowestDate) ...[
            const SizedBox(height: 4),
            Text('The tightest day', style: TypeScale.caption(skin.text3)),
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
            Group(
              children: [for (final r in rows) _CategoryRow(row: r)],
            ),
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
      final r when r.remaining == 0 => ('all of it spent', skin.text3, skin.accent),
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
