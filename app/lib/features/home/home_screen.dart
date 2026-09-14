// Home. Question 1 of the five in 01-vision.md: am I okay right now?
//
// The order of this screen is the answer to that question, and it is not
// negotiable per 04-screens.md: the day, then SAFE TO SPEND with its rail,
// then four actions, then debt both ways, then what is coming, then what just
// happened. Everything above the fold answers "am I okay"; everything below it
// answers "why".
//
// NO NET WORTH HERE. 04-screens.md: "Two of three panel users read a big net
// worth as 'somebody else's phone'." It lives on Accounts.
//
// Every figure comes from the golden locked engine. `safeToSpend` gives the
// amount, the daily pace and the days left; `upcomingCommitments` gives the
// bills; `prevPayday` and `nextPayday` give the rail's two ends. This file
// arranges and paints.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../app/shell.dart';
import '../../core/money/commitments.dart'
    show safeToSpend, upcomingCommitments, upcomingDues;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/schedule.dart' show nextPayday, prevPayday;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../accounts/accounts_screen.dart' show DebtTotals, debtTotals;
import '../ledger/entry_presentation.dart';
import '../ledger/ledger_screen.dart' show signedAmount;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;
    final latest = latestEntries(data);

    if (latest.isEmpty && (data['accounts'] as List? ?? const []).isEmpty) {
      return Screen(
        children: [
          TopBar(date: longDay(now)),
          const SizedBox(height: 18),
          const ScreenTitle(
            title: 'Home',
            sub: 'Safe to spend, what is due, and what just happened.',
          ),
          const SizedBox(height: 20),
          const EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Nothing logged yet',
            body:
                'Tap Log to record your first expense. Once there is money in '
                'here, this screen leads with what is safe to spend before '
                'payday.',
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Log your first entry',
            icon: Icons.add_rounded,
            onTap: () => context.push(logRoutePath),
          ),
        ],
      );
    }

    final sts = safeToSpend(data, now);
    final debt = debtTotals(data);
    final coming = upcomingBills(data, now);

    return Screen(
      children: [
        TopBar(date: longDay(now)),
        const SizedBox(height: 16),

        _SafeToSpend(sts: sts, now: now, schedule: scheduleOf(data)),
        const SizedBox(height: 20),

        const _QuickActions(),
        const SizedBox(height: 24),

        if (debt.any) ...[
          const Head(title: 'Debt, both ways', action: 'See all'),
          const SizedBox(height: 8),
          Group(
            inset: 0,
            children: [_DebtBeam(debt: debt, next: nextDebtPayment(data, now))],
          ),
          const SizedBox(height: 22),
        ],

        if (coming.isNotEmpty) ...[
          const Head(title: 'Coming up', action: 'See all'),
          const SizedBox(height: 8),
          Group(
            children: [
              for (final b in coming)
                ItemRow(
                  icon: Icons.event_outlined,
                  title: (b['name'] ?? '').toString(),
                  sub: dueWhen(b['date'], now),
                  amount: formatMoney(amountOf(b['amount'])),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],

        if (latest.isNotEmpty) ...[
          const Head(title: 'Latest', action: 'See all'),
          const SizedBox(height: 8),
          Group(
            children: [
              for (final t in latest)
                ItemRow(
                  icon: entryIcon(t),
                  title: (t['label'] ?? '').toString(),
                  sub: entrySubtitle(data, t),
                  amount: formatMoney(signedAmount(t)),
                  // Ordinary amounts sit bare in text colour; only money
                  // coming in is green. 04-screens.md, and it is what keeps a
                  // fourteen row list calm.
                  tone: signedAmount(t) > 0 ? Tone.good : Tone.plain,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // One sentence with a number, no card. The screen ends on something
        // that means something rather than on a list running out.
        _Insight(sts: sts),
      ],
    );
  }
}

/// The hero panel: what is safe to spend, and how long it has to last.
class _SafeToSpend extends StatelessWidget {
  const _SafeToSpend({
    required this.sts,
    required this.now,
    required this.schedule,
  });
  final Map<String, dynamic> sts;
  final DateTime now;
  final dynamic schedule;

  @override
  Widget build(BuildContext context) {
    final available = amountOf(sts['available']);
    final perDay = amountOf(sts['perDay']);
    final daysLeft = sts['daysLeft'] as int;

    final start = prevPayday(now, schedule);
    final end = nextPayday(now, schedule);
    final span = end.difference(start).inDays;
    final gone = now.difference(start).inDays;

    return HeroPanel(
      kicker: 'SAFE TO SPEND',
      whole: wholePesos(available),
      cents: centsOf(available),
      // ONE phrasing, not three. 04-screens.md is explicit about that, and the
      // reason is that a sentence which changes shape every day stops being
      // read at all.
      sentence:
          '${formatMoney(perDay)} a day until payday on ${shortDay(end)}.',
      rail: HeroRail(
        // Guarded, because a span of zero is not hypothetical: it is what a
        // weekly schedule gives on payday itself, and dividing by it would put
        // NaN on the one screen that must never look broken.
        fraction: span <= 0 ? 1.0 : (gone / span).clamp(0.0, 1.0),
        left: daysLeft == 1 ? 'Payday tomorrow' : '$daysLeft days to payday',
        right: '${shortDate(start)} to ${shortDate(end)}',
      ),
    );
  }
}

/// Four, in one row, and never a grid.
///
/// 04-screens.md: "Four is the ceiling and it is never a grid. That is the
/// GCash convention with the GCash mistake removed." The mistake is the grid:
/// twenty tiles of equal weight, which is a menu rather than a shortcut.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final actions = <(String, IconData, VoidCallback?)>[
      ('Log', Icons.add_rounded, () => context.push(logRoutePath)),
      ('Debt', Icons.handshake_outlined, null),
      ('Bills', Icons.event_outlined, null),
      ('Move', Icons.swap_horiz_rounded, null),
    ];

    return Row(
      children: [
        for (final (label, icon, onTap) in actions)
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: skin.card,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 21, color: skin.text2),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: TypeScale.caption(skin.text2)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Both directions of debt, as one bar split between them.
///
/// The split is the point. Two numbers side by side are two facts; one bar
/// divided between them is a relationship, and the relationship is the product.
class _DebtBeam extends StatelessWidget {
  const _DebtBeam({required this.debt, this.next});
  final DebtTotals debt;

  /// The next payment due, whenever it falls. Null when nothing is scheduled,
  /// and the line is then left out rather than drawn empty.
  final Map<String, dynamic>? next;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final total = debt.owed + debt.due;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Owed to you', style: TypeScale.caption(skin.text3)),
                    const SizedBox(height: 3),
                    Text(
                      formatMoney(debt.due),
                      style: TypeScale.rowAmount(skin.good),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('You owe', style: TypeScale.caption(skin.text3)),
                  const SizedBox(height: 3),
                  Text(
                    formatMoney(debt.owed),
                    style: TypeScale.rowAmount(skin.accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Green on the left for what is owed to you, accent on the right for
          // what you owe, in the same order as the two figures above them. A
          // bar whose halves swap sides from the labels is worse than no bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Row(
                // STRETCH, and this is not a style choice. A ColoredBox with
                // no child has no intrinsic height, so under the default
                // centre alignment both halves laid out at zero and the bar
                // rendered as nothing at all. Every test passed; the card just
                // had a blank strip where the split should be.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: total <= 0
                        ? 1
                        : (debt.due * 1000).round().clamp(1, 1 << 30),
                    child: ColoredBox(color: skin.good),
                  ),
                  Expanded(
                    flex: total <= 0
                        ? 1
                        : (debt.owed * 1000).round().clamp(1, 1 << 30),
                    child: ColoredBox(color: skin.accent),
                  ),
                ],
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${next!['name']}, next ${next!['when']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.caption(skin.text3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMoney(amountOf(next!['amount'])),
                  style: TypeScale.caption(skin.text2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One sentence with a number in it, and no card around it.
class _Insight extends StatelessWidget {
  const _Insight({required this.sts});
  final Map<String, dynamic> sts;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final committed = amountOf(sts['committed']);
    final billCount = sts['billCount'] as int;

    final text = committed <= 0
        ? 'Nothing is set aside for bills this cycle.'
        : '${formatMoney(committed)} of that is already spoken for by '
              '$billCount ${billCount == 1 ? 'bill' : 'bills'} before payday.';

    return Text(text, style: TypeScale.subtitle(skin.text2));
  }
}

// The icon and the caption live in ../ledger/entry_presentation.dart. Latest
// and the Ledger draw the same stored entry, so they read one rule, not two.

/// How many entries "Latest" shows before "See all".
///
/// Five, because the section is a glance and not the Ledger. The dense render
/// exists precisely because this list is what turns a calm screen busy.
const int latestCount = 5;

/// The most recent entries, newest first.
///
/// Stored dates are yyyy-mm-dd, so a string sort IS a date sort, which is a
/// property of the format rather than luck. Within one day the later entry in
/// the list is the later one in time, so the list is reversed before slicing.
List<Map<String, dynamic>> latestEntries(Map<String, dynamic> state) {
  final rows = [
    for (final t in (state['transactions'] as List? ?? const []))
      if (t is Map) t.cast<String, dynamic>(),
  ];
  rows.sort((a, b) {
    final d = (b['date'] ?? '').toString().compareTo(
      (a['date'] ?? '').toString(),
    );
    return d;
  });
  return rows.take(latestCount).toList();
}

/// The bills between now and payday, soonest first.
///
/// Straight from `upcomingCommitments`, which is golden locked and already
/// knows the rules that matter: a credit card counts for its MINIMUM due and
/// never its balance, and a recurring bill already posted this cycle does not
/// count twice.
List<Map<String, dynamic>> upcomingBills(
  Map<String, dynamic> state,
  DateTime now, {
  int limit = 3,
}) {
  final bills = upcomingCommitments(state, now)['bills'] as List;
  return [
    for (final b in bills.take(limit))
      if (b is Map) b.cast<String, dynamic>(),
  ];
}

/// The next debt payment due, whenever it falls, or null if none is scheduled.
///
/// A WIDER window than payday on purpose. `upcomingCommitments` stops at the
/// next payday, which is right for "Coming up" (what has to be paid out of
/// THIS cycle's money) and wrong here: the debt card's job is to name the next
/// payment even when it lands after payday, and a card that says nothing
/// because the bill is eighteen days out is a card that goes quiet exactly
/// when somebody is planning.
///
/// Sixty days, and it is `upcomingDues` doing the work: that function already
/// knows a credit card counts for its MINIMUM and never its balance, and it
/// already moves a due date off a weekend the way a bank does.
Map<String, dynamic>? nextDebtPayment(
  Map<String, dynamic> state,
  DateTime now, {
  int windowDays = 60,
}) {
  final dues = upcomingDues(state['debts'], windowDays, now);
  if (dues.isEmpty) return null;
  final first = dues.first;
  final debt = first['debt'];
  final name = debt is Map ? (debt['name'] ?? 'Debt').toString() : 'Debt';
  final iso = first['dueISO'];
  final d = iso is String ? DateTime.tryParse(iso) : null;
  return {
    'name': name,
    'when': d == null ? '' : shortDate(d),
    'amount': first['amount'],
  };
}

/// The stored payday schedule, or null to let the engine use its default.
dynamic scheduleOf(Map<String, dynamic> state) => state['settings'] is Map
    ? (state['settings'] as Map)['paydaySchedule']
    : null;

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Friday, Sep 11", the line at the top of Home.
String longDay(DateTime d) =>
    '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// "Tuesday", for the payday sentence.
String shortDay(DateTime d) => _days[d.weekday - 1];

/// "Aug 30", for the rail's two ends.
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// "today", "tomorrow", or "Sep 13", for a bill's caption.
///
/// A date the reader has to subtract from today is a date they do not read.
String dueWhen(dynamic iso, DateTime now) {
  final s = iso is String ? iso : '';
  final parts = s.split('-');
  if (parts.length != 3) return '';
  final d = DateTime.tryParse(s);
  if (d == null) return '';
  final days = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 1 && days < 7) return _days[d.weekday - 1];
  return shortDate(d);
}

/// "6,240" from 6240.50. The panel draws pesos and centavos at different
/// sizes, so it needs them apart.
///
/// Both halves come from `formatMoney`, the golden locked formatter, rather
/// than from arithmetic here. Splitting its OUTPUT keeps the grouping, the
/// rounding and the sign exactly as every other screen writes them; computing
/// the pesos separately would be a second money rule living on one screen.
String wholePesos(num value) {
  final s = formatMoney(value).replaceAll('₱', '');
  final dot = s.indexOf('.');
  return dot < 0 ? s : s.substring(0, dot);
}

/// ".50", or an empty string when the figure is whole.
String centsOf(num value) {
  final s = formatMoney(value);
  final dot = s.indexOf('.');
  return dot < 0 ? '' : s.substring(dot);
}
