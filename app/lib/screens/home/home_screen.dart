import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../state/financial_state.dart';
import 'hero_panel.dart';
import 'home_cards.dart';

/// Home, the prototype's first tab. The card order follows App.tsx: hero,
/// quick actions, debts, coming up, budget pulse, latest.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.xxl,
      ),
      children: <Widget>[
        _Header(state: state),
        const SizedBox(height: Spacing.lg),
        HeroPanel(state: state),
        const SizedBox(height: Spacing.md),
        _QuickActions(palette: palette),
        const SizedBox(height: Spacing.md),
        DebtBeamCard(state: state),
        const SizedBox(height: Spacing.md),
        ComingUpCard(state: state),
        const SizedBox(height: Spacing.md),
        BudgetPulseCard(state: state),
        const SizedBox(height: Spacing.md),
        LatestTransactionsCard(state: state),
      ],
    );
  }
}

/// The greeting row, with the theme switch on the right.
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final bool isNight = state.theme == ThemeMode2.gabi;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Salapify',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                isNight ? 'Gabi' : 'Hapon',
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: isNight ? 'Switch to the Hapon theme' : 'Switch to the Gabi theme',
          child: IconButton(
            // IconButton already reserves a 48dp target.
            onPressed: state.toggleTheme,
            icon: Icon(
              isNight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: palette.accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// The four shortcuts under the hero.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.palette});

  final Palette palette;

  static const List<({String label, IconData icon})> _actions =
      <({String label, IconData icon})>[
    (label: 'Transfer', icon: Icons.swap_horiz),
    (label: 'Bills', icon: Icons.receipt_long_outlined),
    (label: 'Split', icon: Icons.call_split),
    (label: 'Debt', icon: Icons.handshake_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final ({String label, IconData icon}) action in _actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Semantics(
                button: true,
                child: Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: InkWell(
                    // Wired up as each feature lands, following the tab order.
                    onTap: () {},
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.control),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(action.icon, size: 18, color: palette.accent),
                          const SizedBox(height: 4),
                          Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.textSecondary,
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
      ],
    );
  }
}
