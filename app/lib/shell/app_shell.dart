import 'package:flutter/material.dart';

import '../core/money/format.dart';
import '../design/tokens.dart';
import '../features/log/log_sheet.dart';
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

  /// The shell redraws itself whenever the store changes.
  ///
  /// This used to be wired ONLY in main.dart, whose `_onStateChanged` calls
  /// setState on the whole app. That works on a phone and is invisibly wrong
  /// everywhere else: the render harness and every journey test pump
  /// `AppShell(state: state)` directly, with nothing listening, so a screen
  /// stayed frozen on the frame before the change.
  ///
  /// It was not theoretical. The sweep's own shot rendered Health Check
  /// reading "Nothing recorded yet" over a Home card still showing
  /// ₱38,414.00 safe to spend, which was a picture of a contradiction the
  /// app does not actually have. A harness that cannot show the change is a
  /// harness that cannot show a defect in the change.
  ///
  /// Listening here costs nothing on the phone, because the two rebuilds
  /// land in the same frame, and it makes the widget true on its own rather
  /// than true because of how one caller happens to wire it.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final Palette palette = Palette.of(widget.state.theme);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // NO BANNERS ON THE TAB SCREENS. Founder direction, 2026-09-19,
            // after seeing two of them stacked above the header: "remove the
            // 2 banners in the headers and put it inside the settings. So i
            // will not see them in the tab screen because they are
            // distracting."
            //
            // Both now live in Settings and nowhere else. I argued once for
            // keeping a one line storage warning here, the founder said it
            // again, and that is their call to make: it is their app and the
            // banner was in front of every screen they use.
            //
            // What replaces it is NOT a banner. The gear icon carries a dot
            // when Settings has something worth opening, which is a pixel in
            // the header rather than a bar across the screen. Without it, an
            // app that has silently stopped saving looks exactly like an app
            // that is fine, and there is no server holding a copy.
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
          onOpenTab: (int index) =>
              setState(() => _current = SalapifyTab.values[index]),
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

    // AN UNDO, for five seconds.
    //
    // Founder spec, 2026-09-20. This store rejected a snackbar undo twice
    // already, in `undoLastImport` and `restoreSampleData`, and both were
    // right to: those REPLACE the whole ledger and depend on a second file
    // staying in step, so an app killed mid-swap leaves half of one ledger
    // and half of another. This is one row inside a single snapshot written
    // atomically, so the worst case is one extra entry somebody can see and
    // correct. `undoLoggedTransaction` carries the full argument.
    //
    // Five seconds rather than four, because the undo has to be read and
    // then reached for, and the entry it undoes has just landed on a screen
    // the person is still taking in.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            // "SAVED TO THIS PHONE" STAYS, and the amount is added in front
            // of it rather than in place of it. An earlier version of this
            // line dropped the reassurance for the spec's "₱X at Y" wording
            // and log_journey_test.dart caught it: that sentence replaced a
            // stale warning about entries not surviving a restart, and it is
            // the one thing a person needs to hear about money they have
            // just typed into a phone.
            '$whereItWent ${formatPeso(logged.amount)}'
            '${logged.merchant == null ? '' : ' at ${logged.merchant}'}. '
            'Saved to this phone.',
            style: TextStyle(color: palette.onAccent),
          ),
          backgroundColor: palette.accent,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: palette.onAccent,
            onPressed: () {
              widget.state.undoLoggedTransaction(logged);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    // CONFIRMED, rather than silently vanishing. An entry
                    // that disappears with no word is indistinguishable from
                    // one that failed to save, and the person has no way to
                    // tell which happened to their money.
                    content: Text(
                      'Taken back out. Your balance is where it was.',
                      style: TextStyle(color: palette.onAccent),
                    ),
                    backgroundColor: palette.accent,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
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
            horizontal: Spacing.xs,
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
              // CHROME ONLY, capped at 1.3. Five destinations plus the Log
              // pill cannot fit unbounded labels on a 390dp bar, and at the
              // 1.5x an Android user can pick in Settings, "Reports" and
              // "Accounts" were both ellipsised on every screen.
              //
              // 1.3 is not a number somebody liked the look of. It is
              // _kMaxLabelTextScaleFactor from Flutter's own Material
              // NavigationBar (navigation_bar.dart:31 in the pinned SDK),
              // applied to its destination labels for this exact reason. The
              // legacy BottomNavigationBar is harsher still and clamps at
              // 1.0, so its labels do not grow at all. Had Salapify used the
              // stock bar it would have had this behaviour for free and
              // never seen the defect.
              //
              // Wrapping is not an option here and that is a fact about the
              // words, not a preference: "Accounts" and "Reports" are single
              // words with no break opportunity inside them, so maxLines: 2
              // buys the bar's height back and still ellipsises.
              //
              // Capping a scale is a real cost and it is worth naming. It is
              // defensible in THIS place for one specific reason: every
              // destination repeats its own name, unclamped, as the screen's
              // own title (reports_screen.dart:167,
              // accounts_screen.dart:167). The label here is a second copy,
              // so no content and no function is lost at large text, which
              // is the substance WCAG 1.4.4 protects. That reasoning does
              // NOT travel: never clamp body copy, a money figure, a form
              // label or an error.
              //
              // MediaQuery is not a semantics boundary, so TalkBack reads
              // the whole word either way. This was already true of the
              // ellipsis, which is why this is a low-vision defect and not a
              // screen-reader one.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
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
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            // The pill is clamped to the same 1.3 as the tab labels beside
            // it, and leaving it out would have half-fixed the bar: the pill
            // does not sit in an Expanded, so at 1.5x its own text grows and
            // takes back most of the width the five tabs just gained.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
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
      ),
    );
  }
}
