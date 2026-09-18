import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../features/debt/add_debt_sheet.dart';
import '../../features/info/info_sheet.dart';
import '../../features/safe_to_spend/safe_to_spend_sheet.dart';
import '../../features/toolkit/toolkit_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'ask_pan_button.dart';
import 'budget_pulse_card.dart';
import 'coming_up_card.dart';
import 'debt_beam_card.dart';
import 'hero_panel.dart';
import 'home_header.dart';
import 'latest_transactions.dart';
import 'quick_actions.dart';
import 'reminders_banner.dart';

/// Home, the prototype's first tab.
///
/// The card order is App.tsx's, not a preference: hero, budget pulse, quick
/// actions, reminders, debts, coming up, latest. An earlier pass reordered it
/// by guesswork and the founder spotted it against the real screens.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.state,
    this.onOpenLog,
    this.onOpenDebt,
  });

  final FinancialState state;

  /// Opening the debt register belongs to the shell too: it is a whole screen
  /// pushed over the tabs rather than a sheet, so the thing that owns the
  /// navigator has to own the push.
  final VoidCallback? onOpenDebt;

  /// Opening the Log sheet belongs to the shell, not to Home: the shell owns
  /// the store write AND the tab switch that lands somebody on the entry they
  /// just made. Home only needs to say the button was pressed.
  final VoidCallback? onOpenLog;

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
              onOpenCollaboration: () =>
                  _soon(context, palette, 'Collaboration'),
              onOpenReminders: () => _soon(context, palette, 'Reminders'),
              onOpenSettings: () => _soon(context, palette, 'Settings'),
            ),
            const SizedBox(height: Spacing.md),
            HeroPanel(
              state: state,
              onOpenDetails: () => SafeToSpendSheet.show(context, state),
              onOpenHealthCheck: () => _soon(context, palette, 'Health Check'),
              // Both the Details button and the small info glyph open the same
              // sheet. The prototype does the same: the explainer IS the
              // breakdown, and a second lighter screen saying "this is your
              // safe amount" would only delay the numbers that answer it.
              onInfo: () => SafeToSpendSheet.show(context, state),
            ),
            const SizedBox(height: Spacing.md),
            BudgetPulseCard(
              state: state,
              onSeeAll: () => _soon(context, palette, 'The Plan tab'),
            ),
            const SizedBox(height: Spacing.lg),
            QuickActions(
              palette: palette,
              onLog:
                  onOpenLog ?? () => _soon(context, palette, 'The Log sheet'),
              onDebt: () => _addDebt(context, palette),
              onBills: () => _soon(context, palette, 'Bills'),
              onMove: () => _soon(context, palette, 'Move'),
            ),
            const SizedBox(height: Spacing.lg),
            RemindersBanner(
              palette: palette,
              onTest: () => _soon(context, palette, 'Alert testing'),
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
              onManage: () => _soon(context, palette, 'Bills'),
              onInfo: () =>
                  InfoSheet.show(context, palette, InfoTopic.comingUp),
              onAddItem: () =>
                  _soon(context, palette, 'Adding an upcoming item'),
            ),
            const SizedBox(height: Spacing.lg),
            LatestTransactions(
              state: state,
              onSeeAll: () => _soon(context, palette, 'The Activity tab'),
            ),
          ],
        ),
        Positioned(
          right: Spacing.lg,
          bottom: Spacing.lg,
          child: AskPanButton(
            palette: palette,
            onTap: () => _soon(context, palette, 'Pan'),
          ),
        ),
      ],
    );
  }

  /// Opens the Add Debt sheet and records what comes back.
  ///
  /// The messenger is captured BEFORE the await. The sheet can be dismissed
  /// long after this context is gone, and reaching for ScaffoldMessenger.of
  /// on the far side of an await is the usual way that turns into a crash.
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
            // Says out loud that this does not survive a restart. Storage is a
            // later step, and somebody who types a real debt deserves to know
            // it is not saved yet rather than finding out tomorrow.
            'Added. Debts are not saved to the phone yet, so this clears when '
            'the app is closed.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Every control on this screen is real and reachable. The destinations
  /// behind most of them are later migration steps, so a tap says so rather
  /// than doing nothing: a dead button is indistinguishable from a bug.
  void _soon(BuildContext context, Palette palette, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$what is not migrated yet.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
