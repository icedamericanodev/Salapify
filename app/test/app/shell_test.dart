// The shell actually navigates.
//
// Small, and worth having anyway: the router, the branch order and the nav bar
// are three lists that have to agree, and when they disagree the app lights
// the wrong tab and shows the right screen, which looks like a rendering bug
// and is a wiring bug. analyze cannot see it, because every list is valid on
// its own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';

Widget _app() => MaterialApp.router(
  theme: salapifyTheme(hapon),
  darkTheme: salapifyTheme(gabi),
  routerConfig: buildRouter(),
);

void main() {
  testWidgets('opens on Home with all four tabs in the bar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Home twice, because the tab label and the screen's own title say the
    // same word, and the other three once each. Spelled out per tab rather
    // than "at least one of each", which was the first version of this and
    // could not tell the bar from the screen.
    for (final (label, _) in NavBar.tabs) {
      expect(
        find.text(label),
        label == 'Home' ? findsNWidgets(2) : findsOneWidget,
        reason: 'wrong number of "$label" on the opening screen',
      );
    }
    // The Home screen's own subtitle, which appears nowhere in the bar, so
    // this cannot pass on the tab labels alone.
    expect(find.textContaining('Safe to spend'), findsOneWidget);
  });

  testWidgets('tapping a tab shows that screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (var i = 1; i < NavBar.tabs.length; i++) {
      await tester.tap(find.text(NavBar.tabs[i].$1));
      await tester.pumpAndSettle();

      // Every tab screen has a ScreenTitle carrying its own name. Finding the
      // name twice (bar plus title) is the proof the body changed, because
      // finding it once would just be the tab label sitting there.
      expect(
        find.text(NavBar.tabs[i].$1),
        findsNWidgets(2),
        reason:
            'tapped ${NavBar.tabs[i].$1} and its screen did not come up. '
            'Branch order in router.dart probably disagrees with NavBar.tabs.',
      );
    }
  });

  testWidgets('the Log pill opens the sheet over the screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Save entry'), findsNothing);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Save entry'), findsOneWidget);
    // OVER, not instead of. The sheet is a non-opaque route, so the screen it
    // covers is still mounted behind it, and the scrim is the thing a person
    // taps to get back.
    expect(find.textContaining('Safe to spend'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save entry'), findsNothing);
  });

  test('the bar and the router agree on how many tabs there are', () {
    expect(tabPaths.length, NavBar.tabs.length);
    // And on their order, spelled out, because this is the one place a silent
    // swap would be invisible: '/plan' behind the Accounts icon still renders
    // a perfectly good screen.
    expect(tabPaths, ['/home', '/ledger', '/plan', '/accounts']);
    expect(NavBar.tabs.map((t) => t.$1), [
      'Home',
      'Ledger',
      'Plan',
      'Accounts',
    ]);
  });
}
