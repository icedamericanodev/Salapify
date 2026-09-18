import 'package:flutter/material.dart';

import '../core/money/format.dart';
import '../design/tokens.dart';
import '../features/log/log_sheet.dart';
import '../models/models.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/placeholder/placeholder_screen.dart';
import '../screens/plan/plan_screen.dart';
import '../screens/reports/reports_screen.dart';
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
      body: SafeArea(bottom: false, child: _bodyFor(_current, palette)),
      bottomNavigationBar: _SalapifyTabBar(
        palette: palette,
        current: _current,
        onSelect: (SalapifyTab tab) => setState(() => _current = tab),
        onOpenLog: () => _openLog(context, palette),
      ),
    );
  }

  String _isoToday() {
    final DateTime d = widget.state.now;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Widget _bodyFor(SalapifyTab tab, Palette palette) {
    switch (tab) {
      case SalapifyTab.home:
        return HomeScreen(
          state: widget.state,
          onOpenLog: () => _openLog(context, palette),
        );
      case SalapifyTab.activity:
        return ActivityScreen(state: widget.state);
      case SalapifyTab.reports:
        return ReportsScreen(state: widget.state);
      case SalapifyTab.plan:
        return PlanScreen(state: widget.state);
      case SalapifyTab.accounts:
        return PlaceholderScreen(
          palette: palette,
          title: 'Accounts',
          note: 'Every wallet, bank, card and loan lands here.',
        );
    }
  }

  /// Opens the Log sheet and records what comes back.
  ///
  /// The messenger is captured BEFORE the await: the sheet can be dismissed
  /// long after this context is gone, and reaching for ScaffoldMessenger.of on
  /// the far side of an await is the usual way that becomes a crash.
  Future<void> _openLog(BuildContext context, Palette palette) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Transaction? logged = await LogSheet.show(context, widget.state);
    if (logged == null) return;

    widget.state.logTransaction(logged);

    // Land on Activity, where the entry now is. Saving something and being
    // left on the screen that does not show it is how somebody concludes it
    // did not save.
    setState(() => _current = SalapifyTab.activity);

    // A BACKDATED entry is not at the top of Activity, because the list is
    // grouped by day and newest day first. Landing on a screen whose first
    // rows are today's, with yours further down, reads exactly like it did not
    // save. So the confirmation says which day it went under, and only when
    // that is not today, because "Logged under Today" is noise.
    final String whereItWent = logged.date == _isoToday()
        ? 'Logged.'
        : 'Logged under ${formatDateLabel(logged.date, now: widget.state.now)},'
              ' further down the list.';

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$whereItWent Entries are not saved to the phone yet, so this '
            'clears when the app is closed.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
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

  static const Map<SalapifyTab, ({String label, IconData icon})>
  _items = <SalapifyTab, ({String label, IconData icon})>{
    SalapifyTab.home: (label: 'Home', icon: Icons.home_outlined),
    SalapifyTab.activity: (label: 'Activity', icon: Icons.menu_book_outlined),
    SalapifyTab.reports: (label: 'Reports', icon: Icons.insert_chart_outlined),
    SalapifyTab.plan: (label: 'Plan', icon: Icons.track_changes_outlined),
    SalapifyTab.accounts: (
      label: 'Accounts',
      icon: Icons.account_balance_wallet_outlined,
    ),
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
              for (final MapEntry<SalapifyTab, ({String label, IconData icon})>
                  entry
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
