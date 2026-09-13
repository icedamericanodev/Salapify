// Salapify 3 starts here.
//
// Three jobs and no more: open the encrypted store, build the two themes, hand
// off to the router. Anything that knows what a debt is belongs in a feature.
//
// NO UPDATE STAMP YET, deliberately. 02-architecture.md reserves s3.01 for it
// and .github/workflows/app-check.yml says out loud that the stamp and its
// guards arrive with the publisher in Phase D. A stamp with no guard behind it
// is exactly the stale-stamp failure this repository has hit three times
// (docs/lunch-and-learn.md sessions 25, 32 and 33), so it waits for the
// machinery that keeps it honest.
import 'package:flutter/material.dart';

import 'app/ledger_scope.dart';
import 'app/router.dart';
import 'core/data/ledger_store.dart';
import 'core/data/storage_bootstrap.dart';
import 'design/tokens.dart';

Future<void> main() async {
  // Required before any plugin call, and buildLedgerRepository reaches the
  // Keystore through one.
  WidgetsFlutterBinding.ensureInitialized();

  final store = LedgerStore(await buildLedgerRepository());
  await store.load();

  runApp(SalapifyApp(store: store));
}

class SalapifyApp extends StatelessWidget {
  const SalapifyApp({super.key, required this.store});

  /// Held here and handed down through [LedgerScope]. Each feature owns a view
  /// model that reads from it; no widget reaches into storage directly.
  final LedgerStore store;

  @override
  Widget build(BuildContext context) {
    // The scope wraps the whole app rather than sitting inside the router,
    // because the Log sheet is pushed OUTSIDE the tab shell and would not see
    // a scope placed within it.
    return LedgerScope(
      store: store,
      child: MaterialApp.router(
        title: 'Salapify 3',
        debugShowCheckedModeBanner: false,

        // Hapon light, Gabi dark, and the phone's own setting decides. Both are
        // built from the same tokens, so the only difference between them is
        // colour. See D10.
        theme: salapifyTheme(hapon),
        darkTheme: salapifyTheme(gabi),
        themeMode: ThemeMode.system,

        routerConfig: buildRouter(),
      ),
    );
  }
}
