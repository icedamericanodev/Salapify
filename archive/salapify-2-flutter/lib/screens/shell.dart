// The primary destinations, named.
//
// They used to be bare ints. `onSwitchTab(3)` meant Utang, `onSwitchTab(4)`
// meant Insights, and the only place that mapping existed was the order of the
// arms in a switch statement in main.dart. Eight call sites across six files
// depended on it, none of them said which tab they meant, and nothing would
// have failed if the tabs were reordered: every tap would simply have landed
// somewhere else, forever, in silence.
//
// The bottom bar is about to go from six destinations to five, which is exactly
// the reshuffle that class of bug waits for. Naming them first means the
// analyzer finds every site, and means a future reorder is a one-line change to
// the order below rather than an archaeology exercise.
//
// The order here IS the left-to-right order of the bar, because `index` is what
// NavigationBar's selectedIndex wants. Changing the order changes the bar.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/home_tile.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/salapify_icon.dart';
import '../money/pan_tips.dart';
import '../widgets/pan_helper_bubble.dart';
import 'accounts.dart';
import 'budget.dart';
import 'history.dart';
import 'insights.dart';
import 'log_sheet.dart';
import 'menu.dart';
import 'money.dart';
import 'overview.dart';
import 'pan.dart' show PanScreen;

enum Destination {
  // The four bottom-bar destinations, in bar order (see [bar]).
  home(label: 'Home', icon: 'home'),
  history(label: 'Activity', icon: 'activity'),
  insights(label: 'Insights', icon: 'insights'),
  accounts(label: 'Accounts', icon: 'wallet'),
  // Budget and Utang are NO LONGER tabs (founder direction, matching the
  // mockup's Home / Activity / Insights / Accounts bar). They stay enum
  // members because Home, the Menu, Pan, Search, Insights and the course
  // deep-links all name them, and _select now PUSHES them as full screens
  // instead of switching a tab. Reachable from Home and the Menu, never walled
  // off.
  budget(label: 'Budget', icon: 'budget'),
  utang(label: 'Utang', icon: 'utang');

  const Destination({required this.label, required this.icon});

  /// The bottom bar label. Sentence case, matching ScreenHeader, because a
  /// tab reading "Budget" under a header reading "BUDGET" was the busy feeling
  /// the header refresh already fixed everywhere else.
  final String label;

  /// A semantic icon NAME resolved through salapify_icon.dart, never a raw
  /// IconData. Same rule as NavTile: one file decides how Salapify's icons are
  /// drawn, and a typo here hits a visible fallback marker that a test catches
  /// rather than a blank space that nobody notices.
  final String icon;

  /// The destinations that get a bottom-bar button and an IndexedStack body,
  /// in left-to-right order. The current [tab] is always one of these; Budget
  /// and Utang are pushed screens, never the resident tab, so they are not
  /// here. Changing this list changes the bar.
  static const List<Destination> bar = [home, history, insights, accounts];
}

/// The one Scaffold the primary destinations live in.
///
/// Before this, main.dart held a Scaffold whose body was a switch expression,
/// and each of the six destinations returned a Scaffold of its OWN inside it.
/// So the tree already had two Scaffolds; this removes a level rather than
/// adding one. It also fixes what that arrangement cost:
///
///   State was thrown away on every tab change. Switching tabs replaced the
///   body's widget type, so Flutter unmounted the old screen and disposed its
///   State. Activity's search text and filter chip reset to empty, and every
///   scroll position in the app went back to the top. Nothing was saving them,
///   because nothing was keeping them.
///
///   Log lived on Home only. It is the most frequent action in a money app and
///   it was reachable from one of six tabs.
///
/// The FAB, the nav bar and the scroll controllers now belong here, once, and
/// the destinations are plain bodies.
class ShellScreen extends StatefulWidget {
  final SalapifyStore store;

  // ignore: prefer_const_constructors_in_immutables
  ShellScreen({super.key, required this.store});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  Destination tab = Destination.home;

  @override
  void initState() {
    super.initState();
    // The first-log prompt: onboarding just finished (the settings patch set
    // firstLogPrompt and the gate flipped to this shell), so open the log
    // sheet once, unasked, on the day the habit should start. Cleared BEFORE
    // showing, so a crash mid-sheet can never turn it into a nag. Guarded on
    // onboarded too: a restored backup carrying a stray true from a phone
    // that died mid-onboarding should not open a sheet over a stranger.
    // ONE callback, deliberately, handling both reasons a sheet might open on
    // the first frame. They used to be two, and two callbacks meant two
    // sheets: on a fresh install where the tile was tapped before the app had
    // ever run, the parked tap and the first-log prompt both fired, stacking a
    // second log sheet under the welcome one. Both reasons want the same
    // sheet, so wanting it twice is still once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Taken FIRST and unconditionally, before any guard can return. Reading
      // clears it, so a tap this mount cannot serve is dropped here instead of
      // waiting in a static field to detonate on the next mount, minutes later,
      // over whatever sheet that mount opens.
      final tapWantsLog = HomeTile.takeLogRequest();
      if (!mounted || !widget.store.canWrite) return;
      final s = widget.store.data['settings'];
      if (s is! Map || s['onboarded'] != true) return;
      // The first-log prompt: onboarding just finished, so open the log sheet
      // once, unasked, on the day the habit should start. Cleared BEFORE
      // showing, so a crash mid-sheet can never turn it into a nag.
      final prompt = s['firstLogPrompt'] == true;
      if (prompt) widget.store.clearFirstLogPrompt();
      if (prompt || tapWantsLog) _openLogSheetOnce();
    });
    // The WARM tap, which is most taps. The app is already running, the tap
    // arrives through the plugin's stream, and no initState is ever going to
    // run again to notice it: this shell is built inside a ListenableBuilder
    // with no key, so its Element is reused on every store change. Registering
    // a live consumer is the only thing that makes the tile's Log button work
    // more than once per app process.
    HomeTile.onLogTap = _openLogSheetFromTile;
  }

  /// True while a sheet this shell opened is on screen.
  ///
  /// Two taps in a row would otherwise stack two identical log sheets, and the
  /// person dismisses one and finds another underneath.
  bool _sheetOpen = false;

  void _openLogSheetOnce() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showLogSheet(context, widget.store).whenComplete(() => _sheetOpen = false);
  }

  /// A tile tap on a running app. Same guards the cold path uses, because the
  /// same things are true: a sheet must not open over a store that cannot be
  /// written, or over somebody who has not finished onboarding.
  ///
  /// The lock gate draws OVER the shell, so a sheet opened underneath waits
  /// behind the fingerprint rather than leaking anything.
  void _openLogSheetFromTile() {
    if (!mounted || !widget.store.canWrite) return;
    final s = widget.store.data['settings'];
    if (s is! Map || s['onboarded'] != true) return;
    _openLogSheetOnce();
  }

  /// Destinations that have ever been shown.
  ///
  /// A plain IndexedStack builds every child on the first frame, which would
  /// mean the eleven engine calls in Insights all running before the user sees
  /// Home. That is a cold start cost paid by a cheap Android phone for screens
  /// the user may never open. A destination joins this set the first time it is
  /// selected and never leaves, so state is preserved from first visit onward,
  /// which is all "preserve across tab switches" ever meant.
  final Set<Destination> _visited = {Destination.home};

  /// One scroll controller per BAR destination, so each remembers its own
  /// place. Handed down through PrimaryScrollController rather than passed as an
  /// argument: a vertical ListView with no explicit controller attaches to the
  /// ambient primary controller on its own, and not one of the tabs sets a
  /// controller. So this preserves every scroll position without touching a
  /// single screen file. Only bar tabs get one; Budget and Utang are pushed
  /// routes now and carry their own scrollables.
  late final Map<Destination, ScrollController> _controllers = {
    for (final d in Destination.bar) d: ScrollController(),
  };

  @override
  void dispose() {
    // Release the tile's consumer, or a tap arriving after this shell is torn
    // down calls into a dead State and the mounted check inside is the only
    // thing between that and a crash. Compared first so a shell that was
    // replaced by a newer one cannot unregister the newer one's handler.
    if (HomeTile.onLogTap == _openLogSheetFromTile) HomeTile.onLogTap = null;
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _select(Destination d) {
    // Budget and Utang are not tabs any more: switching to them means PUSHING
    // the screen over the shell, so every existing onSwitchTab(Destination.x)
    // caller (Home, Menu, Pan, Search, Insights, the course deep-links) keeps
    // working without knowing the bar changed. Utang opens on "I owe" by
    // default; the receivables and payables entry points below name the side.
    if (d == Destination.budget) {
      _pushRoute(BudgetScreen(store: widget.store, onBack: _popTop));
      return;
    }
    if (d == Destination.utang) {
      _openPayables();
      return;
    }
    if (d != tab) {
      // A position change clicks, per the Phase 1 vocabulary. Change only:
      // re-tapping the current tab is a no-op selection and stays silent,
      // the same rule the choice chip enforces.
      Haptics.select();
      setState(() {
        tab = d;
        _visited.add(d);
      });
      return;
    }
    // Tapping the tab you are already on scrolls it back to the top, the
    // convention every phone user already knows from other apps.
    final c = _controllers[d];
    if (c == null || !c.hasClients || c.offset <= 0) return;
    // Motion.of collapses to zero under the OS reduce-motion setting, and
    // reads only that aspect, so the shell does not rebuild on keyboard opens.
    final d240 = Motion.of(context, Motion.move);
    if (d240 == Duration.zero) {
      c.jumpTo(0);
    } else {
      c.animateTo(0, duration: d240, curve: Motion.curve);
    }
  }

  /// Push a screen over the shell, so it appears full-screen with no bottom bar.
  /// The single door Budget and Utang now use.
  ///
  /// Wrapped in a Scaffold because Budget and MoneyScreen were tab BODIES: they
  /// render a bare SafeArea and lean on the shell's Scaffold for their Material
  /// ancestor and their ScaffoldMessenger. Pushed on their own they had
  /// neither, so a header IconButton would assert "No Material widget found" and
  /// a snackbar would have nowhere to land. The back arrow is the screen's own
  /// ScreenHeader.onBack, so no AppBar is needed here.
  void _pushRoute(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => Scaffold(body: screen)));
  }

  /// Pop the topmost pushed screen. Handed to Budget and Utang as their back
  /// arrow: they are pushes now, so backing out is a plain route pop.
  void _popTop() => Navigator.of(context).pop();

  /// Open Utang on the "Owed to me" side.
  ///
  /// A check-in like "Follow up Migs" is about money owed TO the user, so
  /// landing it on "I owe" would open a screen with no Migs anywhere on it.
  /// Utang is a pushed screen now, so the side is chosen at construction rather
  /// than flipped on a persistent tab after the frame.
  void _openReceivables() {
    _pushRoute(
      MoneyScreen(
        store: widget.store,
        onBack: _popTop,
        initialSegment: MoneySegment.owed,
      ),
    );
  }

  /// Open Utang on the "I owe" side: a due-soon check-in, a Pan "Open debts"
  /// reply, a search hit on a debt, or a plain tap on Utang.
  void _openPayables() {
    _pushRoute(
      MoneyScreen(
        store: widget.store,
        onBack: _popTop,
        initialSegment: MoneySegment.owe,
      ),
    );
  }

  void _openMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          store: widget.store,
          onSwitchTab: _select,
          onOpenReceivables: _openReceivables,
          onOpenPayables: _openPayables,
        ),
      ),
    );
  }

  /// Open Pan's plain-words Q&A, optionally seeded with a question. Wired with
  /// the same navigation callbacks Menu hands it, so Pan's own CTAs keep working.
  void _openPan([String? question]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanScreen(
          store: widget.store,
          onSwitchTab: _select,
          onOpenReceivables: _openReceivables,
          onOpenPayables: _openPayables,
          initialQuestion: question,
        ),
      ),
    );
  }

  /// Whether Pan's floating helper is shown. On by default; turned off in
  /// Appearance. Read live so the toggle takes effect on the next frame.
  bool get _panHelperEnabled =>
      (widget.store.data['settings'] as Map?)?['panHelperEnabled'] != false;

  /// Map a tapped tip to real navigation. The bubble owns no routes; this is the
  /// one place a tip target becomes a screen.
  void _onPanTip(PanTip tip) {
    switch (tip.target) {
      case PanTipTarget.home:
        _select(Destination.home);
      case PanTipTarget.activity:
        _select(Destination.history);
      case PanTipTarget.insights:
        _select(Destination.insights);
      case PanTipTarget.accounts:
        _select(Destination.accounts);
      case PanTipTarget.debts:
        _openPayables();
      case PanTipTarget.askPan:
        _openPan(tip.panQuestion);
    }
  }

  /// The body for a BAR destination. Budget and Utang are never asked for here:
  /// they are pushed routes, not resident tabs, so this switch only covers the
  /// four bar tabs. The default is unreachable (tab is always a bar member) and
  /// exists only to keep the switch exhaustive over the enum.
  Widget _bodyFor(Destination d) => switch (d) {
    Destination.home => OverviewScreen(
      store: widget.store,
      onSwitchTab: _select,
      onOpenReceivables: _openReceivables,
      onOpenPayables: _openPayables,
      onMenu: _openMenu,
    ),
    Destination.history => HistoryScreen(store: widget.store, onMenu: _openMenu),
    Destination.insights => InsightsScreen(
      store: widget.store,
      onSwitchTab: _select,
      onOpenReceivables: _openReceivables,
      onOpenPayables: _openPayables,
      onMenu: _openMenu,
    ),
    Destination.accounts => AccountsScreen(
      store: widget.store,
      onOpenPayables: _openPayables,
      onMenu: _openMenu,
    ),
    Destination.budget || Destination.utang => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // One Log button, on every destination. It was on Home only, which is
      // where it was invented rather than where it belongs: logging is the
      // thing people open this app to do, and it should not require finding
      // the right tab first.
      //
      // Hidden, not disabled, after a failed read: saving would overwrite data
      // we could not read, so the write path stays shut. The store enforces it
      // too; this hides the door.
      // The most tapped control in the app gets the house press dip. Colors
      // and the label weight come from floatingActionButtonTheme now, not the
      // call site; a theme change must reach the Log button too. Haptically
      // silent on purpose: opening a sheet is neither a selection nor money
      // written, and the save itself buzzes at the moment that matters.
      floatingActionButton: widget.store.canWrite
          ? PressableScale(
              child: FloatingActionButton.extended(
                onPressed: () => showLogSheet(context, widget.store),
                icon: Icon(salapifyIcon('add')),
                label: const Text('Log'),
              ),
            )
          : null,
      // The tab body, with Pan's floating helper riding over it. The helper is
      // in the SAME Stack as the body so it sits above the screens but below the
      // Log FAB and the nav bar (which the Scaffold paints on top). It is only
      // mounted when enabled and only over the resident bar tabs; a pushed
      // screen (Budget, Utang, a detail) covers it, which is the right behaviour
      // (Pan is a home-surface helper, not an overlay on a focused task).
      body: Stack(
        children: [
          IndexedStack(
            // Indexed over the BAR list, not the enum: Budget and Utang are not
            // bodies here, so tab.index (an enum index) would point past the
            // children. tab is always a bar member, so this always resolves.
            index: Destination.bar.indexOf(tab),
            children: [
              for (final d in Destination.bar)
                // An unvisited destination is an empty box until it is first
                // opened. IndexedStack keeps every child it is given, so this is
                // what makes the laziness real rather than nominal.
                _visited.contains(d)
                    ? PrimaryScrollController(
                        controller: _controllers[d]!,
                        child: _bodyFor(d),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
          if (_panHelperEnabled)
            Positioned.fill(
              child: PanHelperBubble(
                store: widget.store,
                onTipTap: _onPanTip,
                onOpenChat: _openPan,
              ),
            ),
        ],
      ),
      // No inline colors: navigationBarTheme owns the bar's background, the
      // indicator, and the per-state icon color. Re-passing them here is how a
      // theme change ships everywhere except the nav bar.
      bottomNavigationBar: NavigationBar(
        selectedIndex: Destination.bar.indexOf(tab),
        onDestinationSelected: (i) => _select(Destination.bar[i]),
        // Every glyph resolves by NAME through salapify_icon.dart, the same as
        // the rest of the app's own icons.
        destinations: [
          for (final d in Destination.bar)
            NavigationDestination(
              icon: Icon(salapifyIcon(d.icon)),
              selectedIcon: Icon(salapifyIconSelected(d.icon)),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
