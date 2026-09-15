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
    show upcomingCommitments, upcomingDues;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../core/state/financial_state.dart';
import '../../core/state/visibility.dart' show Excluded;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../dev/sample_data_action.dart';
import '../accounts/accounts_screen.dart' show DebtTotals, debtTotals;
import '../debt/debt_screen.dart' show debtRoutePath;
import '../insights/insights_screen.dart' show insightsRoutePath;
import '../ledger/entry_presentation.dart';
import '../accounts/transfer_sheet.dart' show showTransferSheet;
import '../plan/pending_bills.dart' show pendingBills;
import '../plan/plan_screen.dart' show planSegment, planUpcoming;
import '../plan/recurring_editor.dart' show showRecurringEditor;
import 'due_bills_card.dart';

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
          // Debug builds only, and only while the ledger is empty. It renders
          // nothing in a release build because kDebugMode is a compile time
          // constant, so there is no step to remember before the store listing.
          const SampleDataAction(),
        ],
      );
    }

    final state = FinancialState.of(data, now);
    final debt = debtTotals(data);

    // COMING UP MUST NOT REPEAT WHAT IS ALREADY WAITING FOR AN ANSWER.
    //
    // A bill whose day has arrived is in BOTH derivations by construction:
    // `upcomingCommitments` lists every unposted recurring row due on or before
    // payday, and a pending bill is one whose day has already passed. So Home
    // drew Meralco twice, once asking to be confirmed and once as a quiet row
    // under "Coming up", with the same figure. Seeing one bill twice on one
    // screen is how somebody concludes they are paying it twice.
    //
    // Matched on name and amount because the engine's bill rows carry no id
    // (`commitments.dart` is golden locked, so one cannot be added). The cost
    // of that key is narrow and worth naming: two bills sharing a label AND an
    // amount would hide each other from Coming up while both still appear,
    // correctly, in the card above. Nothing is lost, one row is quieter.
    final pending = pendingBills(data, now);
    final coming = [
      for (final b in upcomingBills(data, now))
        if (!pending.any(
          (p) =>
              p.row['label'] == b['name'] &&
              (amountOf(p.row['amount']) - amountOf(b['amount'])).abs() < 0.005,
        ))
          b,
    ];

    return Screen(
      children: [
        TopBar(date: longDay(now)),
        const SizedBox(height: 16),

        _SafeToSpend(state: state),
        // SURFACED HERE TOO, not only on Accounts. The figure above is lower
        // than the user's real cash, and until this line existed nothing on
        // the app's main screen said why: hide an e-wallet and safe to spend
        // silently fell by its whole balance while the hero's own sentence
        // blamed the bills. A figure somebody cannot account for on the screen
        // they open every morning is the defect, not a polish item.
        //
        // It names a destination because there is one. The switches are on the
        // account, and the only route to them is through Accounts.
        if (state.excluded.anySpendable) ...[
          const SizedBox(height: 10),
          Text(
            spendableExcludedSentence(state.excluded),
            style: TypeScale.caption(context.skin.text2),
          ),
        ],
        const SizedBox(height: 20),

        const _QuickActions(),
        const SizedBox(height: 24),

        // ABOVE DEBT, COMING UP AND LATEST, because this is the only block on
        // Home that asks the person to DO something. Everything below it
        // reports. A card that waits for an answer, placed under three cards
        // that do not, is a card nobody answers, and an unanswered pending bill
        // keeps the projection showing a bill the person has already paid.
        //
        // It draws nothing at all when nothing is due, so on most days Home is
        // exactly what it was.
        const DueBillsCard(),

        if (debt.any) ...[
          Head(
            title: 'Debt, both ways',
            action: 'See all',
            // The Debt screen now exists, so this points at it rather than at
            // Accounts. The two figures in the beam below come from the same
            // `debtTotals` that screen puts in its own header, so tapping
            // through never changes the number in front of the founder.
            onAction: () => context.push(debtRoutePath),
          ),
          const SizedBox(height: 8),
          Group(
            inset: 0,
            children: [_DebtBeam(debt: debt, next: nextDebtPayment(data, now))],
          ),
          const SizedBox(height: 22),
        ],

        if (coming.isNotEmpty) ...[
          Head(
            title: 'Coming up',
            action: 'See all',
            // ON THE UPCOMING SEGMENT, not wherever Plan happened to be. "See
            // all" under a list of upcoming bills that lands on the Budget
            // segment is the same wrong turn the founder called out on the
            // Bills action: a link whose destination does not match its word.
            onAction: () {
              planSegment.value = planUpcoming;
              context.go('/plan');
            },
          ),
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
          Head(
            title: 'Latest',
            action: 'See all',
            onAction: () => context.go('/ledger'),
          ),
          const SizedBox(height: 8),
          Group(
            children: [
              for (final t in latest)
                ItemRow(
                  icon: entryIcon(t),
                  title: (t['label'] ?? '').toString(),
                  sub: entrySubtitle(data, t),
                  // entryAmountText, not a bare formatMoney(signedAmount(t)):
                  // a transfer carries no flow by design, so signedAmount
                  // read it as an expense, minus sign and all, directly under
                  // a sheet that had just said "not spending". See
                  // entry_presentation.dart.
                  amount: entryAmountText(t),
                  // Ordinary amounts sit bare in text colour; only money
                  // coming in is green. 04-screens.md, and it is what keeps a
                  // fourteen row list calm. A transfer is neither, and
                  // signedAmount still reads negative for it (that rule is
                  // untouched, only the printed FIGURE changed), so it falls
                  // through to plain on its own.
                  tone: signedAmount(t) > 0 ? Tone.good : Tone.plain,
                  onTap: () => context.push(
                    '/entry/${Uri.encodeComponent((t['id'] ?? '').toString())}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // One sentence with a number, no card. The screen ends on something
        // that means something rather than on a list running out.
        _Insight(state: state),
      ],
    );
  }
}

/// The hero panel: what is safe to spend, and how long it has to last.
class _SafeToSpend extends StatelessWidget {
  const _SafeToSpend({required this.state});

  /// The one composed truth. This panel takes no loose engine output and no
  /// schedule of its own, which is the point: there is nothing here left to
  /// derive differently from the way another screen derives it.
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final available = state.available;
    final perDay = state.perDay;
    final daysLeft = state.cycle.daysLeft;
    final explicit = state.cycle.explicit;

    // NOTHING here may assert a payday the user never set. `schedule.dart` says
    // so in as many words: guessing 15/31 for a forecast is harmless, guessing
    // it for a CLAIM is not, because "payday is Tuesday" is either true or a
    // lie. A fresh install with no schedule was being told its payday, its
    // weekday, its day count and its cycle dates, all four invented.
    if (!explicit) {
      return HeroPanel(
        kicker: 'SAFE TO SPEND',
        whole: wholePesos(available),
        cents: centsOf(available),
        // Does NOT name a screen. It said "Set your payday in Plan" for two
        // commits, and Plan cannot set a payday: nothing in the app can yet.
        // Pointing somebody at a control that does not exist is the same
        // defect as the dead quick actions this screen had already been fixed
        // for once. Name the destination here only when the editor exists.
        sentence: 'Set your payday to see how long this has to last.',
      );
    }

    // The cycle comes from FinancialState, which is the ONLY place it is
    // defined. This screen used to derive its own start and end, and Plan
    // derived a different period entirely, which is how two screens came to
    // state two daily rates that could never agree.
    final start = state.cycle.start;
    final end = state.cycle.end;

    return HeroPanel(
      kicker: 'SAFE TO SPEND',
      whole: wholePesos(available),
      cents: centsOf(available),
      // ONE phrasing, not three. 04-screens.md is explicit about that, and the
      // reason is that a sentence which changes shape every day stops being
      // read at all.
      //
      // The exception is a figure at or below zero, where the engine's own
      // forecast goes deliberately silent because that is the crunch case.
      // Saying "₱0 a day until payday" states a pace as a fact when the truth
      // is that there is nothing left to pace.
      sentence: available <= 0
          ? 'Your bills before payday come to more than this.'
          : '${formatMoney(perDay)} a day until payday '
                '${paydayWhen(end, state.now)}.',
      rail: HeroRail(
        // Zero on payday itself, never one: that is the moment a cycle BEGINS,
        // so none of it is spent. Filling the bar was telling somebody they had
        // used up a cycle that had not started. The rule lives on Cycle now.
        fraction: state.cycle.elapsedFraction(state.now),
        left: daysLeft == 1 ? 'Payday tomorrow' : '$daysLeft days to payday',
        right: '${shortDate(start)} to ${shortDate(end)}',
      ),
    );
  }
}

/// The line under Home's hero that accounts for the money it left out.
///
/// Top level and pure so it can be checked without pumping a screen. It names
/// SPENDING money rather than "accounts", because `liquidKinds` is cash,
/// e-wallets and checking: a hidden savings pot is in [Excluded.hiddenCount]
/// and not in this figure, and a sentence that used the other count would name
/// accounts that had nothing to do with the number it is explaining.
String spendableExcludedSentence(Excluded e) {
  final amount = formatMoney(e.fromSpendable);
  return e.spendableCount == 1
      ? '$amount in 1 account is left out of this, because you hid it or said '
            'it is not yours. Change that in Accounts.'
      : '$amount across ${e.spendableCount} accounts is left out of this, '
            'because you hid them or said they are not yours. Change that in '
            'Accounts.';
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
    // THREE LIVE ACTIONS, NOT FOUR WITH TWO THAT LIE. The founder tapped Bills
    // and Move and reported that nothing happened, which is exactly what this
    // row's old comment claimed was safe: an action with nowhere to go was
    // "announced as DISABLED, not as a button", drawn in text3 instead of
    // text2. That difference is far too quiet to read as unavailable. A person
    // taps, nothing happens, and the reasonable conclusion is that the app is
    // broken, which on the screen they open every morning is the worst place
    // to spend that impression.
    //
    // Bills had a real destination the whole time and simply was not wired to
    // it. Move does not: transfer was REMOVED from the Log sheet because it
    // destroyed money (one account picker, no destination, see
    // test/features/transfer_loss_test.dart), and the sheet with a from and a
    // to that replaces it is not built yet. So Move is off this row until it
    // exists, rather than sitting here greyed out being tapped. Founder
    // decision, 2026-09-15.
    final actions = <(String, IconData, VoidCallback?)>[
      ('Log', Icons.add_rounded, () => context.push(logRoutePath)),
      ('Debt', Icons.handshake_outlined, () => context.push(debtRoutePath)),
      // A WRITE, like the two beside it. The first wiring sent this to the
      // Plan tab, and the founder said it made no sense: a quick action that
      // only switches tabs is a second nav bar. Log writes an entry, Debt opens
      // a thing you pay, so Bills adds a bill, straight into the editor, which
      // is the fastest route to the one input safe to spend depends on most.
      ('Bills', Icons.event_outlined, () => showRecurringEditor(context)),
      // BACK, with a sheet behind it this time. It was taken off this row
      // because the only transfer the app had destroyed money and nothing had
      // replaced it. The sheet is a port of the shipped app's, on the same
      // golden locked engine, so a transfer between your own accounts cannot
      // change your net worth and cannot leave money with no destination.
      ('Move', Icons.swap_horiz_rounded, () => showTransferSheet(context)),
    ];

    return Row(
      children: [
        for (final (label, icon, onTap) in actions)
          Expanded(
            // An action with nowhere to go is announced as DISABLED, not as a
            // button. TalkBack was reading out four buttons, three of which did
            // nothing at all on tap, which is worse than a greyed control: a
            // sighted user sees nothing happen and assumes the app is broken,
            // and a screen reader user is told a lie outright. Debt, Bills and
            // Move get their destinations in later steps.
            child: Semantics(
              button: onTap != null,
              enabled: onTap != null,
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
                      child: Icon(
                        icon,
                        size: 21,
                        color: onTap == null ? skin.text3 : skin.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TypeScale.caption(
                        onTap == null ? skin.text3 : skin.text2,
                      ),
                    ),
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
  const _Insight({required this.state});
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final committed = state.committed;
    final billCount = state.billCount;

    // NOT "of that". The hero figure is liquid MINUS committed, so this money
    // has already been taken out of it. Saying "of that" invited the reader to
    // subtract it a second time and conclude they had half the runway they
    // really had, and under a negative hero it read as nonsense.
    final text = committed <= 0
        ? 'Nothing is set aside for bills this cycle.'
        : '${formatMoney(committed)} is already set aside for '
              '$billCount ${billCount == 1 ? 'bill' : 'bills'} before payday.';

    // TAPPABLE, because 04-screens.md says so in as many words: "One insight
    // sentence with a number, no card. Tap for Insights." It was a bare Text
    // for as long as there was no Insights screen to reach, which was right
    // then and would have quietly stayed wrong afterwards, exactly like the
    // Debt section's action word did.
    //
    // It announces itself as a button and says where it goes, because accent
    // text that is not a control reads as a link and is not one, and a
    // sentence in body colour that IS a control is invisible to somebody who
    // never thinks to try it.
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.push(insightsRoutePath),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // A real target. The sentence is two lines of 15pt text and the
          // padding is what takes the tap area past the platform floor.
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: TypeScale.subtitle(skin.text2)),
              const SizedBox(height: 6),
              Text('See your insights', style: TypeScale.action(skin.accent)),
            ],
          ),
        ),
      ),
    );
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
    for (final t
        in (state['transactions'] is List
            ? state['transactions'] as List
            : const []))
      if (t is Map) t.cast<String, dynamic>(),
  ];

  // Ties break by STORED POSITION, latest first, and that is the whole reason
  // this is not a one line sort. A stored date has no time in it, so every
  // entry logged today ties with every other, and `List.sort` is not stable:
  // below eight elements it happens to preserve order, above that it is
  // quicksort and the order is arbitrary. Sorting on the date alone therefore
  // took the five OLDEST entries of today, oldest first, and put them under a
  // heading that says "Latest". The entry somebody had just saved was the one
  // entry guaranteed to be missing, and on a full ledger the five shown were
  // effectively random.
  //
  // It passed its test, because the test asserted the dates came out
  // descending, which is true of every wrong answer here.
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((a, b) {
    final byDate = (b.$2['date'] ?? '').toString().compareTo(
      (a.$2['date'] ?? '').toString(),
    );
    return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
  });
  return [for (final row in indexed.take(latestCount)) row.$2];
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

/// "on Tuesday", "tomorrow", "today" or "on Sep 30", for the hero sentence.
///
/// A weekday name is only unambiguous INSIDE a week, and the hero sentence was
/// using one for any payday at all. On a monthly schedule that produced "payday
/// on Friday" for a payday twenty nine days out, four lines above a rail
/// truthfully saying "29 days to payday", and a daily pace the reader would
/// then believe was wrong by a factor of twenty nine.
///
/// `dueWhen` two functions down already knew this rule and applied it
/// correctly. The most read line on the screen was the one place that did not.
String paydayWhen(DateTime payday, DateTime now) {
  final days = DateTime(
    payday.year,
    payday.month,
    payday.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return 'on ${shortDay(payday)}';
  return 'on ${shortDate(payday)}';
}

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

// wholePesos and centsOf moved to design/kit.dart, beside the HeroPanel they
// exist to feed. Plan's hero needs the same split, and one rule in two files
// is the drift that Home and the Ledger had already grown once.
