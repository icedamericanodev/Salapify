import 'package:flutter/material.dart';

import '../../features/shared/pan_empty_card.dart';
import '../../design/pan_art.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../data/store.dart' show LoadStatus;
import '../../core/money/format.dart';
import '../../core/money/health_check.dart';
import '../../core/money/money.dart';
import '../../features/debt/add_debt_sheet.dart';
import '../../features/accounts/move_money_sheet.dart';
import '../../features/bills/bills_sheet.dart';
import '../../features/debt/split_bill_sheet.dart';
import '../../features/health/health_check_sheet.dart';
import '../../features/info/info_sheet.dart';
import '../../features/pan/pan_hero_card.dart';
import '../../features/payday/payday_sheet.dart';
import '../../features/pan/pan_history.dart';
import '../../features/pan/pan_sheet.dart';
import '../../features/reminders/reminders_sheet.dart';
import '../../features/settings/privacy_sheet.dart';
import '../../features/settings/sample_data_sheet.dart';
import '../../features/safe_to_spend/safe_to_spend_sheet.dart';
import '../../features/toolkit/toolkit_sheet.dart';
import '../../models/models.dart';
import '../../features/settings/settings_sheet.dart';
import '../../state/financial_state.dart';
import '../plan/budget_sheets.dart';
import 'ask_pan_button.dart';
import 'budget_pulse_card.dart';
import 'coming_up_card.dart';
import 'debt_beam_card.dart';
import 'hero_panel.dart';
import 'home_header.dart';
import 'latest_transactions.dart';
import 'quick_actions.dart';
import 'reminders_banner.dart';
import 'runway_row.dart';

/// Home, the prototype's first tab.
///
/// The card order is App.tsx's, not a preference: hero, budget pulse, quick
/// actions, reminders, debts, coming up, latest. An earlier pass reordered it
/// The tab indices Home points at.
///
/// Plain ints rather than the shell's `SalapifyTab` enum, which is the
/// separation the `onOpenTab` comment below already describes: Home does not
/// import the shell that builds it. Naming them here keeps the call sites
/// readable without a bare 1 and 3 in the middle of a widget tree.
///
/// `main_wiring_test.dart` reads the shell and asserts these still match the
/// enum, so the two cannot drift apart silently.
const int kActivityTab = 1;
const int kPlanTab = 3;

/// by guesswork and the founder spotted it against the real screens.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    required this.onOpenLog,
    required this.onOpenDebt,
    required this.onOpenTab,
  });

  final FinancialState state;

  /// Switches the bottom tab, by its index in `SalapifyTab`.
  ///
  /// An int rather than the enum, so Home does not have to import the shell
  /// that builds it. The shell owns which tab is showing; Home only knows
  /// that an answer pointed at Reports.
  final ValueChanged<int> onOpenTab;

  /// Opening the debt register belongs to the shell too: it is a whole screen
  /// pushed over the tabs rather than a sheet, so the thing that owns the
  /// navigator has to own the push.
  final VoidCallback onOpenDebt;

  /// Opening the Log sheet belongs to the shell, not to Home: the shell owns
  /// the store write AND the tab switch that lands somebody on the entry they
  /// just made. Home only needs to say the button was pressed.
  ///
  /// REQUIRED, as of P1.1. All three of these used to be optional with a
  /// "not migrated yet" snack bar behind them, which meant forgetting one
  /// produced an apology at runtime instead of an error at compile time. The
  /// shell has always passed all three; the fallbacks only ever fired in a
  /// harness that forgot, and then said the feature did not exist.
  final VoidCallback onOpenLog;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            // Clears the floating Ask Pan button, so the last card is never
            // stuck underneath it.
            88,
          ),
          children: <Widget>[
            HomeHeader(
              state: state,
              onOpenToolkit: () => ToolkitSheet.show(context, state),
              onOpenReminders: () => RemindersSheet.show(context, state),
              // The one real destination behind this button so far. The
              // sample data control lives here because that is where somebody
              // goes looking for it, and because the header already calls this
              // "Settings and backup".
              onOpenSettings: () => SettingsSheet.show(context, state),
              onOpenPrivacy: () => PrivacySheet.show(context, palette),
            ),
            // THE ONE BANNER ON HOME, and it appears in exactly one state.
            //
            // The founder removed the standing banners on 2026-09-19 because
            // they sat in front of every screen on every visit. This is not
            // that: it shows only when Salapify could not read the data file,
            // which means the figures below it are the SAMPLE ledger and
            // nothing typed now is being saved.
            //
            // It is on the screen rather than behind the info dot under that
            // rule's own exception: anything somebody needs in order to avoid
            // a WRONG CONCLUSION stays visible, however long. Two wrong
            // conclusions are available here and both cost money. Believing
            // eleven demo accounts are yours is the first. Entering a week of
            // real spending into a ledger that will not be saved is the
            // second, and it is the one that wastes somebody's effort.
            if (state.loadStatus == LoadStatus.unreadable) ...<Widget>[
              const SizedBox(height: Spacing.md),
              _CannotReadBanner(
                palette: palette,
                onOpenSettings: () => SettingsSheet.show(context, state),
              ),
            ],
            const SizedBox(height: Spacing.md),
            HeroPanel(
              state: state,
              onOpenDetails: () => SafeToSpendSheet.show(context, state),
              onSetPayday: () => PaydaySheet.show(context, state),
              onOpenHealthCheck: () => HealthCheckSheet.show(
                context,
                palette,
                state,
                onAct: (HealthNeed need) => _healthAction(context, need),
              ),
              // Both the Details button and the small info glyph open the same
              // sheet. The prototype does the same: the explainer IS the
              // breakdown, and a second lighter screen saying "this is your
              // safe amount" would only delay the numbers that answer it.
              onInfo: () => SafeToSpendSheet.show(context, state),
            ),

            // TODAY, directly under the hero, and it is the door into the one
            // action that matters in a first session.
            //
            // Safe to Spend answers "what can I spend", which is a plan.
            // Budget Pulse answers "how is the month going", which is a
            // review. Neither answers "what have I spent since I woke up",
            // which is the question a person actually has while standing at a
            // counter, and nothing on this screen answered it.
            //
            // It carries a FIGURE, so it belongs on the screen under the house
            // rule rather than behind a dot. Its empty state is the exception
            // the rule allows and the reason it sits this high: the habit the
            // whole app depends on is logging, and the only thing in a first
            // session that moves a number somebody recognises as theirs is
            // their own first entry.
            const SizedBox(height: Spacing.md),
            // A BOOK WITH NOTHING IN IT gets Pan waving instead of the Today
            // row (D30). Both are the same door, into the first entry; this
            // one is simply the version that says hello to somebody who
            // installed the app a minute ago. The moment one entry exists the
            // Today row is back, because from then on it carries a figure.
            if (state.transactions.isEmpty)
              PanEmptyCard(
                palette: palette,
                mood: PanMood.wave,
                title: 'Nothing logged yet',
                body:
                    'Tap Log to record your first expense, and this screen '
                    'starts tracking what you spend.',
                actionLabel: 'Log your first entry',
                onAction: onOpenLog,
                ring: true,
              )
            else
              _TodayRow(
                palette: palette,
                state: state,
                onLog: onOpenLog,
                onSeeAll: () => onOpenTab(kActivityTab),
              ),

            // THE RUNWAY, and it sits HERE for a reason. The reading order
            // becomes hero (how much), Today (what has gone today), Runway
            // (which day gets tight), Budget Pulse (how the month is going).
            // That is now, today, ahead, month, which is a sentence rather
            // than a pile.
            //
            // Deliberately NOT above the Today row, which is tempting because
            // the runway is the forward-looking twin of the hero. The Today
            // row sits directly under the hero as the door into the only
            // action a first session has, and demoting it to make room for a
            // card that is useless in a first session is a regression dressed
            // as a layout tweak.
            const SizedBox(height: Spacing.md),
            RunwayRow(
              state: state,
              onSeeDue: () => _bills(context, palette),
              onSetPayday: () => PaydaySheet.show(context, state),
              onInfo: () => InfoSheet.show(context, palette, InfoTopic.runway),
            ),

            const SizedBox(height: Spacing.md),
            BudgetPulseCard(
              state: state,
              // P1.1: was a "not migrated yet" snack bar. Budget Pulse summarises
              // the Plan tab's budgets, so its See all opens that tab.
              onSeeAll: () => onOpenTab(kPlanTab),
            ),
            const SizedBox(height: Spacing.lg),
            QuickActions(
              palette: palette,
              onLog: onOpenLog,
              onDebt: () => _addDebt(context, palette),
              onBills: () => _bills(context, palette),
              onMove: () => _moveMoney(context, palette),
              onSplit: () => _splitBill(context, palette),
            ),

            // THE WAY OUT OF THE EXAMPLE DATA, and it sits HERE rather than
            // above the hero, which is where the first draft put it.
            //
            // Moving it down is a design correction, not a convenience. The
            // only person who sees this chose "Look around with example data
            // first" on the welcome, so the figures being examples is not
            // news to them: they asked. A full width warning block above the
            // app's main figure, on every visit, for somebody who asked, is
            // precisely the standing banner the founder removed on
            // 2026-09-19. The user panel's complaint was about people who
            // never chose it, and the welcome means that can no longer
            // happen.
            //
            // It is still ON Home and still one tap from gone, which was the
            // panel's actual ask: the honest sentence in
            // sample_data_sheet.dart had been two taps and a scroll behind a
            // gear icon that their least technical archetype said plainly
            // she would never open.
            //
            // The first draft also pushed Home's own shortcut row out of the
            // built range in a short viewport, so eleven journeys could not
            // find the Log button. A banner that displaces the controls it
            // sits above is a wall, not a warning.
            if (state.hasSampleData &&
                state.loadStatus != LoadStatus.unreadable) ...<Widget>[
              const SizedBox(height: Spacing.lg),
              _ExampleDataBanner(
                palette: palette,
                onOpen: () => SampleDataSheet.show(context, state),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            PanHeroCard(
              palette: palette,
              facts: state.panFacts,
              onAsk: (String? question) => PanSheet.show(
                context,
                state,
                openWith: question,
                onAction: (String id) => _panAction(context, palette, id),
                history: FilePanHistoryStore(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            RemindersBanner(
              state: state,
              onOpen: () => RemindersSheet.show(context, state),
            ),
            const SizedBox(height: Spacing.lg),
            DebtBeamCard(
              state: state,
              onSeeAll: onOpenDebt,
              onInfo: () =>
                  InfoSheet.show(context, palette, InfoTopic.debtBothWays),
            ),
            const SizedBox(height: Spacing.lg),
            ComingUpCard(
              state: state,
              onManage: () => _bills(context, palette),
              onInfo: () =>
                  InfoSheet.show(context, palette, InfoTopic.comingUp),
              onAddItem: () =>
                  // P1.1: scheduling an item is what the Bills sheet now does, so this
                  // opens it rather than apologising.
                  _bills(context, palette),
            ),
            const SizedBox(height: Spacing.lg),
            LatestTransactions(
              state: state,
              // P1.1: Latest is the first few ledger rows, so its See all opens
              // the screen that holds all of them.
              onSeeAll: () => onOpenTab(kActivityTab),
            ),
          ],
        ),
        Positioned(
          right: Spacing.lg,
          bottom: Spacing.lg,
          child: AskPanButton(
            palette: palette,
            onTap: () => PanSheet.show(
              context,
              state,
              onAction: (String id) => _panAction(context, palette, id),
              history: FilePanHistoryStore(),
            ),
          ),
        ),
      ],
    );
  }

  /// Takes an answer's action somewhere real.
  ///
  /// Every id in `panActionIds` has a case, and the default does NOTHING on
  /// purpose. A button whose id nobody recognised is a bug in the engine, and
  /// the right behaviour on a chat screen is to be inert rather than to throw
  /// in front of somebody who was asking about their electricity bill.
  /// `pan_journey_test.dart` walks every id so an inert one cannot ship
  /// quietly.
  void _panAction(BuildContext context, Palette palette, String id) {
    switch (id) {
      case 'log':
        onOpenLog();
      case 'safeToSpend':
        SafeToSpendSheet.show(context, state);
      // Pan answers "how am I doing" FROM the Health Check engine now
      // (founder decision F9), so the button beside that answer opens the
      // screen those figures came from rather than a second reading of them.
      case 'healthCheck':
        HealthCheckSheet.show(
          context,
          palette,
          state,
          onAct: (HealthNeed need) => _healthAction(context, need),
        );
      case 'debts':
        onOpenDebt();
      case 'privacy':
        PrivacySheet.show(context, palette);
      case 'reminders':
        RemindersSheet.show(context, state);
      case 'reports':
        onOpenTab(2);
      case 'accounts':
        onOpenTab(4);
      case 'bills':
      case 'academy':
        onOpenTab(3);
    }
  }

  /// Takes an unmeasured Health Check indicator to the thing that would fix
  /// it.
  ///
  /// EVERY ONE GOES SOMEWHERE REAL. An indicator that names a missing input
  /// and then offers a button doing nothing is worse than one that offers no
  /// button, because the first time somebody taps it they learn the screen
  /// is decorative. `health_check_journey_test.dart` taps all of them.
  ///
  /// The sheet is popped first, so the destination is not buried underneath
  /// it: a person who lands on Plan with Health Check still covering it
  /// concludes the tap did nothing.
  void _healthAction(BuildContext context, HealthNeed need) {
    Navigator.of(context).pop();
    switch (need) {
      case HealthNeed.logSpending:
        onOpenLog();
      case HealthNeed.setPayday:
        // Its own sheet now. This case used to fall through to Plan with a
        // comment claiming "the payday lives in its Budgets segment", and it
        // did not: Plan's "Payday and income" is a read-only caption on a
        // figure, and nothing anywhere in the app could set a payday at all.
        // So the offer to tell Salapify when you get paid led to a tab that
        // could not accept the answer.
        PaydaySheet.show(context, state);
      case HealthNeed.setBudget:
        // Straight to the new budget sheet. It used to land on Plan's hub,
        // two taps short of the Budgets screen, and until 2026-10-08 there
        // was nowhere a budget could be set at all.
        AddBudgetSheet.show(context, state);
      case HealthNeed.addBill:
      case HealthNeed.startCushion:
        // Plan owns these: budgets live in its Budgets segment, bills
        // in Bills, and a goal in Goals. One destination beats three
        // half-wired ones, and the hub is one tap from each.
        onOpenTab(3);
    }
  }

  /// Splitting a bill, from the Home shortcut row.
  ///
  /// THIS USED TO BE A ONE LINE CALL THAT THREW THE RESULT AWAY, and the doc
  /// above it argued that was correct: the sheet writes through the store,
  /// the store is a ChangeNotifier, so the figures redraw on their own and
  /// there is nothing to hand back. Every word of that was true about the
  /// FIGURES and it missed the person. One tap here can take the whole bill
  /// out of a real account, and the only screen in a position to say so said
  /// nothing at all, while every ordinary logged entry got "Saved to this
  /// phone" and an Undo.
  ///
  /// So it now does what the Log sheet does, for the same reasons written at
  /// `app_shell.dart:181`: confirm what happened, and offer five seconds to
  /// take it back. The undo goes through [FinancialState.undoSplitBill]
  /// rather than being assembled here, because a split is several records
  /// and they have to come out together or not at all.
  ///
  /// The messenger is captured BEFORE the await. The sheet can be dismissed
  /// long after this context is gone, and reaching for ScaffoldMessenger.of
  /// on the far side of an await is the usual way that turns into a crash.
  Future<void> _splitBill(BuildContext context, Palette palette) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SplitBillResult? saved = await SplitBillSheet.show(
      context,
      palette: palette,
      state: state,
    );
    // Dismissed without saving. Nothing was written, so there is nothing to
    // confirm and nothing to offer back.
    if (saved == null) return;

    final int n = saved.debts.length;
    final String debts = n == 1 ? '1 debt' : '$n debts';
    final Transaction? tx = saved.transaction;

    // WHAT ACTUALLY HAPPENED, not a generic success. "Saved" on its own
    // leaves somebody checking their balance to find out which account paid.
    final String what = tx == null
        ? 'Split recorded. $debts created, no money moved. Saved to this '
              'phone.'
        : 'Split recorded. ${formatPeso(tx.amount.pesos)} out of '
              '${saved.accountName ?? 'your account'}, $debts created. '
              'Saved to this phone.';

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(what, style: TextStyle(color: palette.onAccent)),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: palette.onAccent,
            onPressed: () {
              final bool done = state.undoSplitBill(tx: tx, debts: saved.debts);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    // TWO OUTCOMES, AND THEY ARE NOT THE SAME SENTENCE. The
                    // undo refuses whole if one of the split's debts has
                    // already been paid against, and a refusal that looked
                    // like a success would leave somebody believing their
                    // balance went back when it did not.
                    content: Text(
                      done
                          ? 'Taken back out. Your balance and your debts are '
                                'where they were.'
                          : 'Not taken back. Somebody has already paid '
                                'against one of these debts, so the split '
                                'stays. Remove what you do not need from the '
                                'Debts tab.',
                      style: TextStyle(color: palette.onAccent),
                    ),
                    backgroundColor: palette.accent,
                    duration: Duration(seconds: done ? 3 : 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
          ),
        ),
      );
  }

  /// Moving money between the person's own accounts.
  ///
  /// Same shape as _splitBill: the sheet writes through the store, which is a
  /// ChangeNotifier the shell listens to, so there is nothing to redraw here.
  Future<void> _moveMoney(BuildContext context, Palette palette) =>
      MoveMoneySheet.show(context, palette: palette, state: state);

  /// Bills and scheduled payments.
  Future<void> _bills(BuildContext context, Palette palette) =>
      BillsSheet.show(context, palette: palette, state: state);

  Future<void> _addDebt(BuildContext context, Palette palette) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Debt? saved = await AddDebtSheet.show(context, palette);
    if (saved == null) {
      return;
    }
    state.addDebt(saved);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            // This used to warn that the debt would not survive a restart,
            // which was true and honest right up until storage landed. Saying
            // it now would be the same lie in the other direction.
            'Added and saved to this phone.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Shown on Home ONLY when the data file could not be read.
///
/// Deliberately plain and deliberately not dismissible. A person in this state
/// is looking at somebody else's money and does not know it, and anything they
/// type is going nowhere. A banner they can wave away is a banner they will
/// wave away on the one occasion it mattered.
class _CannotReadBanner extends StatelessWidget {
  const _CannotReadBanner({
    required this.palette,
    required this.onOpenSettings,
  });

  final Palette palette;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.lg),
        // FILLED, not merely outlined, and the reason is measurable rather
        // than aesthetic: in the dark palette `negative` and `accent` are the
        // SAME colour (0xFFFF9A52), so an orange border on the ordinary
        // surface is indistinguishable from every other orange element on
        // Home. The one banner that has to be noticed would have read as
        // decoration. negativeSoft gives it its own block without changing a
        // colour token, which would move every negative figure in the app.
        decoration: BoxDecoration(
          color: palette.negativeSoft,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: palette.negative),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.error_outline, size: 18, color: palette.negative),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    'These figures are not yours',
                    style: AppType.rowTitle(
                      palette,
                    ).copyWith(color: palette.negative),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Salapify could not read your data file, so it is showing its '
              'own example figures. Nothing you type now is being saved, and '
              'nothing of yours has been deleted or written over.',
              style: AppType.caption(palette),
            ),
            const SizedBox(height: Spacing.sm),
            // A real control rather than a sentence telling somebody to go
            // and find one. The route out of this state lives in Settings.
            InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: palette.negative),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'What I can do about it',
                    style: AppType.rowTitle(
                      palette,
                    ).copyWith(color: palette.negative),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on Home while any of Salapify's own demo records are still present.
///
/// ## Why this one is allowed on Home
///
/// The founder removed the standing banners on 2026-09-19 because they sat in
/// front of every screen on every visit. This is the opposite shape. It
/// describes a state the person can end in one tap, it says so, and once
/// ended it cannot come back: the sweep is one way and the put-it-back
/// control is gated on a stored key, so a ledger that never had demo data
/// cannot be given any.
///
/// ## Why it is a banner and not an info dot
///
/// The rule is that figures stay on screen and teaching goes behind the dot.
/// Its stated exception is anything somebody needs in order not to reach a
/// WRONG CONCLUSION, and this is the most expensive wrong conclusion the app
/// can produce. Every figure above and below it belongs to nobody.
///
/// ## Why warning and not negative
///
/// `_CannotReadBanner` uses negative because it reports a fault. Nothing is
/// broken here. Somebody chose to look around with example data and this is
/// the way back out, so it reads as a note rather than an alarm, and a red
/// block on a screen with nothing wrong with it would teach people to ignore
/// the red block that matters.
class _ExampleDataBanner extends StatelessWidget {
  const _ExampleDataBanner({required this.palette, required this.onOpen});

  final Palette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    return Material(
      color: p.warningSoft,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: p.warning),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.science_outlined, size: 18, color: p.warning),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'These figures are examples, not yours',
                      style: AppType.rowTitle(p).copyWith(color: p.warning),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      // NAMES THE RISK IN ONE LINE, because the risk is the
                      // point and the room is not free. The panel's worst
                      // moment was a real entry landing beside a fake one,
                      // and somebody who has not typed anything yet is
                      // exactly who can still avoid it.
                      //
                      // Deliberately short. The first draft was a three line
                      // card with its own button, and it pushed Home's
                      // shortcut row far enough down that eleven journey
                      // tests could no longer find the Log button at all. A
                      // banner that displaces the app's own controls is not
                      // a warning, it is a wall. The full explanation lives
                      // in the sheet this opens, which has carried it for
                      // weeks.
                      'Clear them before you start, or your entries will sit '
                      'beside them.',
                      style: AppType.caption(p),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.warning),
            ],
          ),
        ),
      ),
    );
  }
}

/// What today holds, and the way to add to it.
///
/// ## Two states, and the empty one is the point
///
/// With nothing logged it reads "Nothing logged yet today" and the whole row
/// is a door into the Log sheet. That is the first real action a new person
/// can take, and it is the only one in a first session that changes a figure
/// they recognise as their own: a balance moving because of something they
/// typed. Every other screen in the app is a report on data that does not
/// exist yet.
///
/// With something logged it reads the figure, which is a plain answer to a
/// question no other card on Home answers. Safe to Spend is a plan and Budget
/// Pulse is a month. Neither says what has left today.
///
/// ## Why it is not a nag
///
/// It never asks, congratulates, or counts a streak. It states a figure and
/// stops, and on a day somebody has not spent anything it says so rather than
/// implying they should. An empty state that reads as a reproach is how a
/// money app becomes one more thing to avoid opening.
class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.palette,
    required this.state,
    required this.onLog,
    required this.onSeeAll,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback onLog;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    final int count = state.loggedTodayCount;
    final bool empty = count == 0;
    final Money spent = state.spentToday;

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        // The empty row goes to Log, because there is nothing to look at. A
        // row with figures on it goes to the list those figures came from,
        // which is where somebody who just read a number wants to go next.
        onTap: empty ? onLog : onSeeAll,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.iconTile,
                  // Concentric: the card is 24 and this sits inside 16 of
                  // padding, so it takes the small radius rather than
                  // repeating the card's.
                  borderRadius: BorderRadius.circular(Radii.tile),
                ),
                child: Icon(
                  empty ? Icons.add : Icons.today_outlined,
                  size: 18,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('TODAY', style: AppType.kicker(p)),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      empty ? 'Nothing logged yet' : formatPeso(spent.pesos),
                      style: empty
                          ? AppType.rowTitle(p)
                          : AppType.amount(p).copyWith(color: p.textPrimary),
                    ),
                  ],
                ),
              ),
              if (empty)
                Text('Log one', style: AppType.button(p, color: p.accent))
              else
                Text(
                  count == 1 ? '1 entry' : '$count entries',
                  style: AppType.caption(p),
                ),
              const SizedBox(width: Spacing.xs),
              Icon(Icons.chevron_right, size: 18, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
