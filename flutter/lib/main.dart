// Salapify Flutter preview. The from-scratch Flutter rebuild, growing next
// to the live React Native app in mobile/ until it reaches parity. Every
// push that touches flutter/ builds an APK to the fixed flutter-preview
// release link and deploys the web preview. The Update stamp below bumps on
// every push so the founder can verify which build arrived.

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/overview.dart';
import 'theme.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
const String updateStamp =
    'f0.07 · You can now log an expense or income, and it moves your balances';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salapify Preview',
      theme: barakoDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => OverviewScreen(store: widget.store),
      ),
    );
  }
}
