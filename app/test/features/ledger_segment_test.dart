// The Ledger's two segments, BUILT.
//
// D23: Insights is the second segment of the Ledger tab, because Home is now,
// Plan is the future, Accounts is the stock, and LEDGER IS THE PAST. Insights
// is the past, shaped, so it belongs beside the raw version of itself.
//
// The old door was one tappable sentence at the very bottom of Home. Measured
// on the lived-in fixture at 320x640 it only became visible after scrolling
// 752 of 752 pixels: the literal last line on the page. That is a hidden
// feature, not a weak affordance, and the tab bar is now the entry point.
//
// THE TRAP THIS FILE EXISTS TO STOP. The Ledger used to return its empty state
// EARLY, header and all. Adding the segment after that return would mean a
// ledger with no entries has no reachable Insights segment at all, which is
// exactly the defect the Accounts screen shipped: its empty branch swallowed
// the Settings action and the backup and restore behind it, on the one ledger
// where restore is what a person most needs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

/// Open the Ledger tab by tapping its icon in the bar.
///
/// BY ICON, not by the word. "Ledger" is now the screen's own title as well as
/// the tab's label, so `find.text('Ledger')` matches two widgets the moment
/// the tab is open and a tap on it is ambiguous.
Future<void> _openLedger(WidgetTester tester, LedgerStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavBar),
      matching: find.byIcon(Icons.article_outlined),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('both segments are there, and Entries is the default', (
    tester,
  ) async {
    await _openLedger(tester, await memoryStore(livedIn()));

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(
      find.text('Jollibee'),
      findsWidgets,
      reason:
          'the Ledger opens on something other than the entries, so the tab '
          'no longer answers the question it is named for',
    );
  });

  testWidgets('tapping Insights shows the charts, in the tab', (tester) async {
    await _openLedger(tester, await memoryStore(livedIn()));
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Where this month went'), findsOneWidget);
    expect(find.textContaining('per cent of what you spent'), findsOneWidget);

    // IN the tab, not over it. A pushed screen would carry a BackBar, and the
    // whole point of the segment is that the tab bar stays visible underneath.
    expect(find.byType(NavBar), findsOneWidget);
    expect(find.byType(BackBar), findsNothing);
  });

  testWidgets('and back to Entries, from the same control', (tester) async {
    await _openLedger(tester, await memoryStore(livedIn()));
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entries'));
    await tester.pumpAndSettle();

    expect(find.text('Jollibee'), findsWidgets);
    expect(find.text('Where this month went'), findsNothing);
  });

  testWidgets('AN EMPTY LEDGER STILL HAS BOTH SEGMENTS', (tester) async {
    // The trap, as an assertion. With the empty state returning early this
    // finds nothing, and a brand new user has no route to Insights at all.
    final store = await memoryStore({
      'accounts': [
        {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 500.0},
      ],
    });
    await _openLedger(tester, store);

    expect(find.text('No entries yet'), findsOneWidget);
    expect(
      find.text('Insights'),
      findsOneWidget,
      reason:
          'a ledger with nothing in it has no reachable Insights segment, so '
          'the feature does not exist for anybody who has not logged yet',
    );

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(
      find.text('Not enough logged yet'),
      findsOneWidget,
      reason: 'the empty Insights state is unreachable on an empty ledger',
    );
  });

  testWidgets('the subtitle describes BOTH segments, not just the entries', (
    tester,
  ) async {
    // Plan learned this the hard way: its subtitle described Upcoming alone
    // and contradicted the list underneath it the moment that segment grew.
    // The subtitle sits ABOVE the segment control, so it cannot be about one
    // side of it.
    await _openLedger(tester, await memoryStore(livedIn()));

    expect(
      find.textContaining('Tap any entry to edit'),
      findsOneWidget,
      reason: 'the edit hint is gone, and nothing says entries are tappable',
    );

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tap any entry to edit'),
      findsNothing,
      reason:
          'the charts are captioned "tap any entry to edit or delete it", '
          'which is false of every one of them',
    );
  });

  testWidgets('the pushed route still works, for deep links', (tester) async {
    // Two doors, one room. A notification or the home screen widget needs
    // somewhere to land that can be backed OUT of, and a tab switch is not
    // that, so /insights stays a real route rather than a redirect.
    await tester.pumpWidget(_app(await memoryStore(livedIn())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('See your insights'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('See your insights'));
    await tester.pumpAndSettle();

    expect(find.byType(BackBar), findsOneWidget);
    expect(find.text('Where this month went'), findsOneWidget);
  });
}
