// Salapify Flutter preview. The from-scratch Flutter rebuild, growing next
// to the live React Native app in mobile/ until it reaches parity. Every
// push that touches flutter/ builds an APK to the fixed flutter-preview
// release link and deploys the web preview. The Update stamp below bumps on
// every push so the founder can verify which build arrived.

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/budget.dart';
import 'screens/history.dart';
import 'screens/insights.dart';
import 'screens/menu.dart';
import 'screens/overview.dart';
import 'screens/utang.dart';
import 'theme.dart';
import 'widgets/lock_gate.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
const String updateStamp =
    'f1.03 · Reports: spending trend, six months of your spending with a "vs your usual" read so you know if a month is normal';

void main() {
  runApp(SalapifyApp(store: SalapifyStore()));
}

class SalapifyApp extends StatefulWidget {
  final SalapifyStore store;
  const SalapifyApp({super.key, required this.store});

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The OS flipped light/dark (auto at night, or the user toggled it). Repaint
  // so a 'system' appearance follows along.
  @override
  void didChangePlatformBrightness() => setState(() {});

  // Back to the foreground: post any recurring bills and income that came due
  // while the app was backgrounded (people keep apps open for weeks). The
  // lastPosted marker makes this idempotent, so an extra call is always safe.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.store.postDueRecurring();
    }
  }

  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // The theme and mode live in settings so they survive backups. The
        // palette is resolved and set BEFORE anything below reads a Barako
        // color; the store's notify and the OS brightness observer both
        // rebuild this tree, so a theme/mode switch or a night-mode flip
        // repaints the whole app.
        final settings = widget.store.data['settings'];
        final (themeKey, mode) = resolveThemeChoice(settings);
        final os =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final theme = themeForKey(themeKey);
        Barako.currentTheme = theme;
        Barako.current = theme.resolve(effectiveBrightness(mode, os));
        return MaterialApp(
          title: 'Salapify Preview',
          theme: salapifyTheme(Barako.current),
          debugShowCheckedModeBanner: false,
          // LockGate wraps the whole navigator (via builder), so the lock
          // overlay covers pushed screens too, not just the home tab.
          builder: (context, child) =>
              LockGate(store: widget.store, child: child ?? const SizedBox()),
          home: Scaffold(
            body: switch (tab) {
              1 => BudgetScreen(store: widget.store),
              2 => HistoryScreen(store: widget.store),
              3 => UtangScreen(store: widget.store),
              4 => InsightsScreen(
                  store: widget.store,
                  onSwitchTab: (i) => setState(() => tab = i)),
              5 => MenuScreen(
                  store: widget.store,
                  onSwitchTab: (i) => setState(() => tab = i)),
              _ => OverviewScreen(
                  store: widget.store,
                  onSwitchTab: (i) => setState(() => tab = i)),
            },
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              backgroundColor: Barako.card,
              indicatorColor: Barako.primary,
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home, color: Barako.onPrimary),
                    label: 'Home'),
                NavigationDestination(
                    icon: const Icon(Icons.savings_outlined),
                    selectedIcon:
                        Icon(Icons.savings, color: Barako.onPrimary),
                    label: 'Budget'),
                NavigationDestination(
                    icon: const Icon(Icons.receipt_long_outlined),
                    selectedIcon:
                        Icon(Icons.receipt_long, color: Barako.onPrimary),
                    label: 'History'),
                NavigationDestination(
                    icon: const Icon(Icons.handshake_outlined),
                    selectedIcon:
                        Icon(Icons.handshake, color: Barako.onPrimary),
                    label: 'Utang'),
                NavigationDestination(
                    icon: const Icon(Icons.insights_outlined),
                    selectedIcon:
                        Icon(Icons.insights, color: Barako.onPrimary),
                    label: 'Insights'),
                NavigationDestination(
                    icon: const Icon(Icons.grid_view_outlined),
                    selectedIcon:
                        Icon(Icons.grid_view, color: Barako.onPrimary),
                    label: 'Menu'),
              ],
            ),
          ),
        );
      },
    );
  }
}
