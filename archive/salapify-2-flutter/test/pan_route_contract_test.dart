// The contract between Pan's brain and its destinations.
//
// Pan's brain emits RN-style route strings on its CTAs. The screen turns each
// into navigation through the PanRoute registry. For a long time four routes
// the brain genuinely emits, /accounts, /reports, /goals, and /(tabs)/more,
// fell into a `default: return null` and rendered a reply whose button was
// simply absent: "See accounts" with nothing to tap.
//
// The source-scan test below is the guard that makes that impossible to
// reintroduce: it reads the brain's own files, pulls every 'route' literal out
// of them, and fails if any one does not resolve in PanRoute. A new responder
// route with no home reddens this test instead of shipping as a dead button.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/screens/pan_routes.dart';
import 'package:salapify/screens/payday.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every 'route': '...' literal the Pan brain contains, read from its source so
/// the set can never drift from what the code actually emits.
Set<String> _brainRoutes() {
  final dir = Directory('lib/money/pan');
  final re = RegExp(r"'route'\s*:\s*'([^']+)'");
  final found = <String>{};
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      found.add(m.group(1)!);
    }
  }
  return found;
}

void main() {
  test('every CTA route the Pan brain emits resolves to a destination', () {
    final routes = _brainRoutes();
    // A sanity check on the scan itself: if the regex or the folder drifts and
    // finds nothing, the "all resolve" assertion below would pass vacuously.
    expect(
      routes,
      isNotEmpty,
      reason:
          'Scanned lib/money/pan and found no route literals. The scan '
          'drifted, so this test would pass without checking anything.',
    );
    final unknown = [
      for (final r in routes)
        if (PanRoute.forPath(r) == null) r,
    ];
    expect(
      unknown,
      isEmpty,
      reason:
          'Pan emits these routes with no destination in PanRoute, so each '
          'renders a reply whose button is missing: $unknown. Add them to the '
          'PanRoute registry (lib/screens/pan_routes.dart).',
    );
  });

  test('an unknown route resolves to null, which renders no button', () {
    expect(PanRoute.forPath('/not-a-real-route'), isNull);
  });

  test('the once-dropped Accounts and Payday routes are now known', () {
    // These are the two the task named explicitly; both used to fall through.
    expect(PanRoute.forPath('/accounts'), PanRoute.accounts);
    expect(PanRoute.forPath('/(tabs)/more'), PanRoute.setPayday);
  });

  testWidgets('a balances question with no accounts opens Accounts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: PanScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'my balance');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    final cta = find.widgetWithText(OutlinedButton, 'Add accounts');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(AccountsScreen), findsOneWidget);
  });

  testWidgets('a payday question with no schedule opens the Payday screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: PanScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'when is payday');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    final cta = find.widgetWithText(OutlinedButton, 'Set payday');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(PaydayScreen), findsOneWidget);
  });
}
