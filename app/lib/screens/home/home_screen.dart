import 'package:flutter/material.dart';

import '../../design/tokens.dart';
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
  const HomeScreen({super.key, required this.state});

  final FinancialState state;

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
              onOpenToolkit: () =>
                  _soon(context, palette, 'The Philippine toolkit'),
              onOpenCollaboration: () =>
                  _soon(context, palette, 'Collaboration'),
              onOpenReminders: () => _soon(context, palette, 'Reminders'),
              onOpenSettings: () => _soon(context, palette, 'Settings'),
            ),
            const SizedBox(height: Spacing.md),
            HeroPanel(
              state: state,
              onOpenDetails: () =>
                  _soon(context, palette, 'Safe to Spend details'),
              onOpenHealthCheck: () => _soon(context, palette, 'Health Check'),
              onInfo: () =>
                  _soon(context, palette, 'The Safe to Spend explainer'),
            ),
            const SizedBox(height: Spacing.md),
            BudgetPulseCard(
              state: state,
              onSeeAll: () => _soon(context, palette, 'The Plan tab'),
            ),
            const SizedBox(height: Spacing.lg),
            QuickActions(
              palette: palette,
              onLog: () => _soon(context, palette, 'The Log sheet'),
              onDebt: () => _soon(context, palette, 'Debts'),
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
              onSeeAll: () => _soon(context, palette, 'Debts'),
              onInfo: () => _soon(context, palette, 'The debt explainer'),
            ),
            const SizedBox(height: Spacing.lg),
            ComingUpCard(
              state: state,
              onManage: () => _soon(context, palette, 'Bills'),
              onInfo: () => _soon(context, palette, 'The Coming Up explainer'),
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
