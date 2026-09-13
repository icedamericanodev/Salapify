// Salapify 3 design preview, real Flutter.
//
// One theme: Hapon in light, Gabi in dark. Every screen renders from identical
// layout code in both, so the dark shot is proof that dark is DERIVED and not
// redrawn. Anything that differs between the two pictures except colour is a
// bug.
//
// This is a preview, not the app. It has no data layer, no money engine and no
// state. Its whole job is to be looked at, so the founder settles the design
// before a line of the real app in app/ is written.
import 'package:flutter/material.dart';

import 'home.dart';
import 'log.dart';
import 'screens.dart';

export 'home.dart';
export 'kit.dart';
export 'log.dart';
export 'screens.dart';
export 'skin.dart';

void main() => runApp(const PreviewApp(screen: Pane.home));

/// Which screen the preview shows. The render harness walks all of these.
enum Pane {
  home('home'),
  log('log'),
  ledger('ledger'),
  plan('plan'),
  accounts('accounts'),
  debt('debt');

  const Pane(this.key);
  final String key;
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key, required this.screen});
  final Pane screen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: switch (screen) {
        Pane.home => const HomeScreen(),
        Pane.log => const LogScreen(),
        Pane.ledger => const LedgerScreen(),
        Pane.plan => const PlanScreen(),
        Pane.accounts => const AccountsScreen(),
        Pane.debt => const DebtScreen(),
      },
    );
  }
}
