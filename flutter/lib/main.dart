// Salapify Flutter preview. The from-scratch Flutter rebuild, growing next
// to the live React Native app in mobile/ until it reaches parity. Every
// push that touches flutter/ builds an APK to the fixed flutter-preview
// release link and deploys the web preview. The Update stamp below bumps on
// every push so the founder can verify which build arrived.

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/history.dart';
import 'screens/overview.dart';
import 'screens/utang.dart';
import 'theme.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
const String updateStamp =
    'f0.16 · New base build, icon font fixed so patches always apply';

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
    return MaterialApp(
      title: 'Salapify Preview',
      theme: barakoDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Scaffold(
          body: switch (tab) {
            1 => HistoryScreen(store: widget.store),
            2 => UtangScreen(store: widget.store),
            _ => OverviewScreen(store: widget.store),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            backgroundColor: Barako.card,
            indicatorColor: Barako.primary,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: Barako.onPrimary),
                  label: 'Overview'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon:
                      Icon(Icons.receipt_long, color: Barako.onPrimary),
                  label: 'History'),
              NavigationDestination(
                  icon: Icon(Icons.handshake_outlined),
                  selectedIcon: Icon(Icons.handshake, color: Barako.onPrimary),
                  label: 'Utang'),
            ],
          ),
        ),
      ),
    );
  }
}
