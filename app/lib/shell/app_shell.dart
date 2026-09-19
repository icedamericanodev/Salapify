import 'package:flutter/material.dart';

import '../core/money/format.dart';
import '../data/store.dart';
import '../design/tokens.dart';
import '../design/type.dart';
import '../features/log/log_sheet.dart';
import '../features/settings/sample_data_sheet.dart';
import '../features/settings/settings_sheet.dart';
import '../models/models.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/debt/debt_screen.dart';
import '../screens/home/home_screen.dart';
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _StorageWarning(
              palette: palette,
              state: widget.state,
              onOpen: () async {
                await SettingsSheet.show(context, widget.state);
                if (mounted) setState(() {});
              },
            ),
            // THE SAMPLE NOTICE IS ON HOME ONLY, and that is a change of mind
            // worth writing down. It was on every tab first, for a good
            // reason: Reports shows a net worth built from demo money. But it
            // is a 44dp tappable strip, and on five tabs it pushed the top of
            // every list down on a phone-height screen.
            //
            // What replaced it is better than what it was: a Sample chip on
            // each demo ROW, in Accounts and in Activity. A banner is read
            // once and scrolled past. A chip is present at the moment somebody
            // looks at the figure, which is where the trap actually springs.
            if (_current == SalapifyTab.home)
              _SampleNotice(
                palette: palette,
                state: widget.state,
                onOpen: () async {
                  await SampleDataSheet.show(context, widget.state);
                  if (mounted) setState(() {});
                },
              ),
            Expanded(child: _bodyFor(_current, palette)),
          ],
        ),
      ),
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
          onOpenDebt: () => _openDebt(context, palette),
        );
      case SalapifyTab.activity:
        return ActivityScreen(state: widget.state);
      case SalapifyTab.reports:
        return ReportsScreen(state: widget.state);
      case SalapifyTab.plan:
        return PlanScreen(
          state: widget.state,
          onOpenDebt: () => _openDebt(context, palette),
        );
      case SalapifyTab.accounts:
        return AccountsScreen(
          state: widget.state,
          onOpenDebt: () => _openDebt(context, palette),
        );
    }
  }

  /// Pushes the debt register over the tabs.
  ///
  /// A pushed SCREEN rather than a sixth tab, matching the prototype: debts
  /// are reached from the Home beam and from the Accounts register, both of
  /// which already show the two figures, so a permanent tab would spend a
  /// fifth of the bottom bar on a destination most people visit rarely.
  ///
  /// setState on return, because the payment path writes to the store and the
  /// tab underneath has to redraw with the new figures.
  Future<void> _openDebt(BuildContext context, Palette palette) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: DebtScreen(
              state: widget.state,
              onBack: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
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
            '$whereItWent Saved to this phone.',
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

/// Says, on every screen, when what you type is NOT being kept.
///
/// This is the piece that was missing, and its absence was worse than the bug
/// that revealed it. `FinancialState` has recorded `loadProblem`, `saveProblem`
/// and `isSaving` since storage landed, and NOTHING in the app read any of
/// them. So when the founder's emulator could not reach path_provider, every
/// save failed silently: the entries went on screen, the file was never
/// written, and the app said nothing at all.
///
/// A banner rather than a dialog, and on every tab rather than one. Somebody
/// who dismisses a dialog at launch and then spends ten minutes typing in real
/// figures needs the warning to still be there while they type.
class _StorageWarning extends StatelessWidget {
  const _StorageWarning({
    required this.palette,
    required this.state,
    required this.onOpen,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String? problem = state.saveProblem ?? state.loadProblem;
    // Saving is on and nothing has failed: the ordinary case, and it gets no
    // pixels. A permanent "your data is safe" strip is the kind of
    // reassurance that stops being read by the second day.
    if (problem == null && state.isSaving) return const SizedBox.shrink();
    if (problem == null) return const SizedBox.shrink();

    final bool recovered = state.loadStatus == LoadStatus.recovered;
    final Color tint = recovered ? palette.accent : palette.negative;

    // ONE LINE, and the detail is in Settings.
    //
    // Founder direction, 2026-09-19, looking at six lines of this on Home:
    // "can you remove/hide that warning box on the simulator screen or put
    // them in the settings?" The detail moved. The LINE did not, and that is
    // a deliberate reading of the request rather than a partial one: a silent
    // save failure is the single defect that costs somebody everything they
    // have typed, on a phone with no server holding a copy. A person who
    // cannot see that their entries are being thrown away has no reason to go
    // looking in Settings for the reason.
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
      child: Material(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(color: tint.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  recovered ? Icons.history : Icons.warning_amber_rounded,
                  size: 16,
                  color: tint,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    recovered
                        ? 'We opened your last saved copy. Tap for details.'
                        : 'Your entries are NOT being saved. Tap for details.',
                    style: AppType.caption(palette).copyWith(color: tint),
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

/// "Some of this money is not yours", on every tab until it is cleared.
///
/// On EVERY tab, deliberately, and for the same reason _StorageWarning is:
/// somebody who reads it on Home and then opens Reports is looking at a net
/// worth built from demo accounts, and a warning they have scrolled past is a
/// warning that is not there. It removes itself the moment they clear the
/// sample data, so it cannot become wallpaper.
class _SampleNotice extends StatelessWidget {
  const _SampleNotice({
    required this.palette,
    required this.state,
    required this.onOpen,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!state.hasSampleData) return const SizedBox.shrink();
    final SampleSummary s = state.sampleSummary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
      child: Material(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            width: double.infinity,
            // 44 minimum because this whole strip is a BUTTON. Shrinking the
            // padding to make it compact took it to 34dp, under the touch
            // target floor, and accounts_test caught it. Compact and tappable
            // is a constraint, not a choice between the two.
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.science_outlined, size: 16, color: palette.accent),
                const SizedBox(width: Spacing.sm),
                // ONE LINE, on purpose, and it took a regression to learn it.
                // The first version carried a three line explanation of why
                // sample data exists. That is teaching, it belongs behind the
                // tap, and on a short screen it pushed the top of every list
                // out of view. The figure and the way out are all that has to
                // be here.
                Expanded(
                  child: Text(
                    '${formatPeso(s.assets)} here is sample money. Tap to '
                    'remove it.',
                    style: AppType.caption(
                      palette,
                    ).copyWith(color: palette.accent),
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
