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
import 'screens/overview.dart';
import 'screens/utang.dart';
import 'theme.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
const String updateStamp =
    'f0.59 · Polish: contrast completed, honest delete copy, real tap targets';

void main() {
  runApp(SalapifyApp(store: SalapifyStore()));
}

class SalapifyApp extends StatefulWidget {
  final SalapifyStore store;
  const SalapifyApp({super.key, required this.store});

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // The mood lives in settings so it survives backups. The palette is
        // set BEFORE anything below reads a Barako color, and the whole tree
        // rebuilds on every store notify, so a mood switch repaints the app.
        final settings = widget.store.data['settings'];
        Barako.current =
            paletteForMood(settings is Map ? settings['themeMood'] : null);
        return MaterialApp(
          title: 'Salapify Preview',
          theme: salapifyTheme(Barako.current),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: switch (tab) {
              1 => BudgetScreen(store: widget.store),
              2 => HistoryScreen(store: widget.store),
              3 => UtangScreen(store: widget.store),
              4 => InsightsScreen(
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
                    label: 'Overview'),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
