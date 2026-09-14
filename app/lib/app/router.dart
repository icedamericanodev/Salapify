// Every route in Salapify 3, in one file.
//
// go_router rather than plain Navigator, per 02-architecture.md, for one
// reason that will not be optional later: the home screen widget and a
// notification both have to open a specific screen from outside the app, and
// with go_router they resolve through the same route table as a tap.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/account_detail_screen.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ledger/ledger_screen.dart';
import '../features/log/log_sheet.dart';
import '../features/plan/plan_screen.dart';
import 'shell.dart';

/// The four tab paths, in the same order as [NavBar.tabs]. A test asserts the
/// two lists line up, because a shell whose branch order disagrees with its bar
/// lights the wrong tab and nothing else notices.
const tabPaths = <String>['/home', '/ledger', '/plan', '/accounts'];

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: tabPaths.first,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ledger',
                builder: (context, state) => const LedgerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (context, state) => const AccountsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Outside the shell too, and for the reason 04-screens.md gives:
      // "Everything else (Insights, Settings, details, editors) is pushed over
      // the shell." A detail screen is not a fifth tab.
      //
      // The id travels in the PATH rather than in an object handed to the
      // constructor, so the home screen widget and a notification can open
      // this exact screen from outside the app through the same route table a
      // tap uses. That is the whole reason go_router is here (02-architecture).
      GoRoute(
        path: '/account/:id',
        builder: (context, state) =>
            AccountDetailScreen(id: state.pathParameters['id']!),
      ),

      // Outside the shell, deliberately. The Log sheet covers the tab bar and
      // the screen behind it stays visible through the scrim, which is what
      // `opaque: false` buys and what a shell branch could not do.
      GoRoute(
        path: logRoutePath,
        pageBuilder: (context, state) => const _SheetPage(child: LogSheet()),
      ),
    ],
  );
}

/// A route that does not paint over what is underneath it, and slides up.
class _SheetPage extends Page<void> {
  const _SheetPage({required this.child});
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, page) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: page,
      ),
    );
  }
}
