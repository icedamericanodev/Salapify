import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/placeholder/placeholder_screen.dart';
import '../state/financial_state.dart';

/// The five destinations, in the prototype's own order. Changing this order
/// changes muscle memory, so it stays as TabBar.tsx declares it.
enum SalapifyTab { home, activity, reports, plan, accounts }

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});

  final FinancialState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  SalapifyTab _current = SalapifyTab.home;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(widget.state.theme);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: _bodyFor(_current, palette),
      ),
      bottomNavigationBar: _SalapifyTabBar(
        palette: palette,
        current: _current,
        onSelect: (SalapifyTab tab) => setState(() => _current = tab),
        onOpenLog: () => _openLog(context, palette),
      ),
    );
  }

  Widget _bodyFor(SalapifyTab tab, Palette palette) {
    switch (tab) {
      case SalapifyTab.home:
        return HomeScreen(state: widget.state);
      case SalapifyTab.activity:
        return ActivityScreen(state: widget.state);
      case SalapifyTab.reports:
        return PlaceholderScreen(
          palette: palette,
          title: 'Reports',
          note: 'Migrates after Activity, following the prototype tab order.',
        );
      case SalapifyTab.plan:
        return PlaceholderScreen(
          palette: palette,
          title: 'Plan',
          note: 'Budgets, goals and upcoming move here.',
        );
      case SalapifyTab.accounts:
        return PlaceholderScreen(
          palette: palette,
          title: 'Accounts',
          note: 'Every wallet, bank, card and loan lands here.',
        );
    }
  }

  void _openLog(BuildContext context, Palette palette) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Log',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'The fast log sheet is part of the Activity migration step. '
              'This sheet is here so the button it hangs off is real.',
              style: TextStyle(fontSize: 14, color: palette.textMuted),
            ),
            const SizedBox(height: Spacing.xl),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar: five equal destinations plus the accent Log pill, the same
/// arrangement the prototype uses.
class _SalapifyTabBar extends StatelessWidget {
  const _SalapifyTabBar({
    required this.palette,
    required this.current,
    required this.onSelect,
    required this.onOpenLog,
  });

  final Palette palette;
  final SalapifyTab current;
  final ValueChanged<SalapifyTab> onSelect;
  final VoidCallback onOpenLog;

  static const Map<SalapifyTab, ({String label, IconData icon})> _items =
      <SalapifyTab, ({String label, IconData icon})>{
    SalapifyTab.home: (label: 'Home', icon: Icons.home_outlined),
    SalapifyTab.activity: (label: 'Activity', icon: Icons.menu_book_outlined),
    SalapifyTab.reports: (label: 'Reports', icon: Icons.insert_chart_outlined),
    SalapifyTab.plan: (label: 'Plan', icon: Icons.track_changes_outlined),
    SalapifyTab.accounts: (label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              for (final MapEntry<SalapifyTab, ({String label, IconData icon})> entry
                  in _items.entries)
                Expanded(
                  child: _TabButton(
                    palette: palette,
                    label: entry.value.label,
                    icon: entry.value.icon,
                    isActive: current == entry.key,
                    onTap: () => onSelect(entry.key),
                  ),
                ),
              const SizedBox(width: Spacing.xs),
              _LogPill(palette: palette, onTap: onOpenLog),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.palette,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? palette.accent : palette.textMuted;

    return Semantics(
      selected: isActive,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        // 44 logical pixels is the floor for a tappable control.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            // mainAxisSize.min is load-bearing, not tidiness. A Scaffold gives
            // its bottomNavigationBar LOOSE vertical constraints, so a Column
            // left on its default (max) grows to the full screen height, the
            // bar swallows the whole window and the body is laid out at zero
            // height. The screens then render nothing while every test that
            // only looks at the bar still passes.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogPill extends StatelessWidget {
  const _LogPill({required this.palette, required this.onTap});

  final Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log a transaction',
      child: Material(
        color: palette.accent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.add, size: 16, color: palette.onAccent),
                const SizedBox(width: 2),
                Text(
                  'Log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.onAccent,
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
