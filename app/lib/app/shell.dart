// The shell: the four tabs, the Log pill, and ONE nav bar that outlives all of
// them.
//
// The bar is here rather than inside each screen because it must not rebuild
// when the tab changes. A bar that is part of the screen is a different widget
// on every tab, so it re-enters the tree, re-animates and loses any state it
// holds. One bar, four bodies.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/kit.dart';
import '../design/tokens.dart';

/// Wraps whichever tab go_router is currently showing.
///
/// [navigationShell] is go_router's own widget: it keeps a separate Navigator
/// per tab, so backing out of a pushed screen on Ledger does not disturb where
/// you were on Home. That is the part that is genuinely painful to retrofit,
/// which is why the shell route goes in now rather than an IndexedStack.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.skin.bg,
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavBar(
              active: navigationShell.currentIndex,
              // initialLocation: true means tapping the tab you are already on
              // pops back to that tab's first screen, which is what every
              // phone user expects and what go_router does not do by default.
              onTab: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
              onLog: () => context.push(logRoutePath),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Log sheet's path. One constant, so the pill in the bar and the button
/// on an empty Home cannot drift apart.
const String logRoutePath = '/log';
