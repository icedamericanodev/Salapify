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
import '../widgets/salapify_icon.dart';
import 'budget.dart';
import 'history.dart';
import 'insights.dart';
import 'log_sheet.dart';
import 'menu.dart';
import 'money.dart';
import 'overview.dart';

enum Destination {
  home(label: 'Home', icon: 'home'),
  history(label: 'Activity', icon: 'activity'),
  budget(label: 'Budget', icon: 'budget'),
  utang(label: 'Utang', icon: 'utang'),
  insights(label: 'Insights', icon: 'insights');

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

  /// Reaches into the Money tab for the two things only it knows: which
  /// segment is active (for scroll-to-top) and how to show a specific one
  /// (for taps that mean receivables in particular).
  final _moneyKey = GlobalKey<MoneyScreenState>();

  /// Destinations that have ever been shown.
  ///
  /// A plain IndexedStack builds every child on the first frame, which would
  /// mean the eleven engine calls in Insights, plus Budget, plus Utang, all
  /// running before the user sees Home. That is a cold start cost paid by a
  /// cheap Android phone for screens the user may never open. A destination
  /// joins this set the first time it is selected and never leaves, so state
  /// is preserved from first visit onward, which is all "preserve across tab
  /// switches" ever meant.
  final Set<Destination> _visited = {Destination.home};

  /// One scroll controller per destination, so each remembers its own place.
  ///
  /// Handed down through PrimaryScrollController rather than passed as an
  /// argument: a vertical ListView with no explicit controller attaches to the
  /// ambient primary controller on its own, and not one of the six destinations
  /// sets a controller. So this preserves every scroll position in the app
  /// without touching a single screen file.
  late final Map<Destination, ScrollController> _controllers = {
    for (final d in Destination.values) d: ScrollController(),
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
    if (d != tab) {
      setState(() {
        tab = d;
        _visited.add(d);
      });
      return;
    }
    // Tapping the tab you are already on scrolls it back to the top, the
    // convention every phone user already knows from other apps. The Money
    // tab owns its own controllers (its two segments cannot share the
    // ambient one), so it is asked rather than assumed.
    final c = d == Destination.utang
        ? _moneyKey.currentState?.activeController
        : _controllers[d];
    if (c == null || !c.hasClients || c.offset <= 0) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      c.jumpTo(0);
    } else {
      c.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  /// Land on the Utang tab with the "Owed to me" segment showing.
  ///
  /// A check-in like "Follow up Migs" is about money owed TO the user, and
  /// landing it on the default "I owe" segment would open a screen with no
  /// Migs anywhere on it. The segment flip happens after the frame so the
  /// Money tab exists even when this is its first visit.
  void _openReceivables() {
    _select(Destination.utang);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moneyKey.currentState?.showSegment(MoneySegment.owed);
    });
  }

  /// Land on the Utang tab with the "I owe" segment showing.
  ///
  /// The mirror of _openReceivables, for taps that mean the user's own debts:
  /// a due-soon check-in, a Pan "Open debts" reply, a search hit on a debt.
  /// Before this existed those pushed a standalone DebtsScreen over the shell,
  /// stranding the user on a copy of the tab with no bottom bar.
  void _openPayables() {
    _select(Destination.utang);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moneyKey.currentState?.showSegment(MoneySegment.owe);
    });
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

  Widget _bodyFor(Destination d) => switch (d) {
    Destination.home => OverviewScreen(
      store: widget.store,
      onSwitchTab: _select,
      onOpenReceivables: _openReceivables,
      onOpenPayables: _openPayables,
      onMenu: _openMenu,
    ),
    Destination.budget => BudgetScreen(store: widget.store, onMenu: _openMenu),
    Destination.history => HistoryScreen(
      store: widget.store,
      onMenu: _openMenu,
    ),
    Destination.utang => MoneyScreen(
      key: _moneyKey,
      store: widget.store,
      onMenu: _openMenu,
    ),
    Destination.insights => InsightsScreen(
      store: widget.store,
      onSwitchTab: _select,
      onOpenReceivables: _openReceivables,
      onOpenPayables: _openPayables,
      onMenu: _openMenu,
    ),
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
      floatingActionButton: widget.store.canWrite
          ? FloatingActionButton.extended(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              onPressed: () => showLogSheet(context, widget.store),
              icon: const Icon(Icons.add),
              label: Text('Log', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: IndexedStack(
        index: tab.index,
        children: [
          for (final d in Destination.values)
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) => _select(Destination.values[i]),
        backgroundColor: Barako.card,
        indicatorColor: Barako.primary,
        // Every glyph resolves by NAME through salapify_icon.dart, the same as
        // the rest of the app's own icons.
        destinations: [
          for (final d in Destination.values)
            NavigationDestination(
              icon: Icon(salapifyIcon(d.icon)),
              selectedIcon: Icon(
                salapifyIconSelected(d.icon),
                color: Barako.onPrimary,
              ),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
