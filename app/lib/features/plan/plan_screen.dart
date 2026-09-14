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
import '../../core/money/budget.dart' show budgetSummary, dailyRoom;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'budget_rows.dart';

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
        const ScreenTitle(
          title: 'Plan',
          sub: 'Your budget, and what is due before the next payday.',
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
          1 => const _NotYet(
            icon: Icons.event_outlined,
            title: 'Upcoming is next',
            body:
                'Every bill and payday between now and the payday after next, '
                'as a list. Home already shows what is due before this payday.',
          ),
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

class _Budget extends StatelessWidget {
  const _Budget();

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;
    final summary = budgetSummary(data, now);
    final rows = categoryBudgets(data, now);
    final limit = amountOf(summary['limit']);

    // Nothing set AND nothing tagged. A screen that draws a zero budget hero
    // over an empty list is telling somebody they have ₱0 to spend, which is
    // a different statement from "you have not set this up".
    if (limit <= 0 && rows.isEmpty) {
      return const EmptyState(
        icon: Icons.donut_small_outlined,
        title: 'No budget set',
        body:
            'Set a monthly amount per category and this screen shows what is '
            'left, not just what is spent.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (limit > 0) ...[
          _LeftToSpend(summary: summary, now: now, needing: needALook(rows)),
          const SizedBox(height: 22),
        ],
        if (rows.isNotEmpty) ...[
          const Head(title: 'By category'),
          const SizedBox(height: 8),
          Group(
            children: [for (final r in rows) _CategoryRow(row: r)],
          ),
        ],
      ],
    );
  }
}

/// The hero: what is left of the monthly limit, and how it is pacing.
class _LeftToSpend extends StatelessWidget {
  const _LeftToSpend({
    required this.summary,
    required this.now,
    required this.needing,
  });
  final Map<String, dynamic> summary;
  final DateTime now;
  final int needing;

  @override
  Widget build(BuildContext context) {
    final remaining = amountOf(summary['remaining']);
    final limit = amountOf(summary['limit']);
    final spent = amountOf(summary['spent']);
    final over = summary['over'] == true;

    // `dailyRoom` returns null on purpose when the sentence cannot be said
    // honestly, which is no limit set or nothing left to spread. Its own doc
    // says so, so a null is a signal rather than a missing value to paper over.
    final perDay = dailyRoom(summary, now);
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = lastDay - now.day + 1;

    final String sentence;
    if (over) {
      sentence = 'You are ${formatMoney(spent - limit)} over your monthly '
          'limit with ${_days(daysLeft)} to go.';
    } else if (perDay != null) {
      sentence =
          '${formatMoney(perDay)} a day for the ${_days(daysLeft)} left '
          'this month.';
    } else {
      sentence = 'Nothing left to spread over the ${_days(daysLeft)} left '
          'this month.';
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

String _days(int n) => n == 1 ? '1 day' : '$n days';

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
