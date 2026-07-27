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

  void _openMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          store: widget.store,
          onSwitchTab: _select,
          onOpenReceivables: _openReceivables,
        ),
      ),
    );
  }

  Widget _bodyFor(Destination d) => switch (d) {
    Destination.home => OverviewScreen(
      store: widget.store,
      onSwitchTab: _select,
      onOpenReceivables: _openReceivables,
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
