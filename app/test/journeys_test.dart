// Test the app the way a person uses it, not one screen at a time.
//
// Every other test file drives ONE thing with a fixture built for it, which is
// good and is not this. A defect that is correct where it was written and
// wrong where it is READ has nowhere to be caught by those: three false alarms
// in one afternoon in the shipped app came from two screens seeming to
// disagree, and none could be settled, because no test had ever put two
// screens in front of the same store.
//
// Journeys PREFER invariants, and every literal in here has to justify itself.
//
// And every invariant needs a DIRECTIONAL companion beside it, because an
// invariant also holds when the action silently did nothing. "Net worth is
// unchanged" is unfalsifiable by inaction: a save that saves nothing conserves
// everything perfectly. So each one below names the movement that must have
// happened, on a specific account, by a specific amount.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/design/tokens.dart';

import 'support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: MaterialApp.router(
    theme: salapifyTheme(hapon),
    darkTheme: salapifyTheme(gabi),
    routerConfig: buildRouter(),
  ),
);

double _balance(LedgerStore s, String accountId) {
  for (final a in (s.data['accounts'] as List)) {
    if (a is Map && a['id'] == accountId) return amountOf(a['balance']);
  }
  fail('no account $accountId');
}

double _netWorth(LedgerStore s) {
  var total = 0.0;
  for (final a in (s.data['accounts'] as List)) {
    if (a is Map) total += amountOf(a['balance']);
  }
  return total;
}

/// Type into the fast log field and save.
Future<void> _log(WidgetTester tester, String line, {String? account}) async {
  await tester.tap(find.text('Log'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), line);
  await tester.pumpAndSettle();
  if (account != null) {
    await tester.tap(find.text(account));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Save entry'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logging an expense moves exactly one account, by exactly the '
      'amount, and the Ledger agrees', (tester) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final netBefore = _netWorth(store);
    final gcashBefore = _balance(store, 'a_gcash');
    final bpiBefore = _balance(store, 'a_bpi');

    await _log(tester, 'jollibee 250', account: 'GCash');

    // DIRECTIONAL, and the whole point of this test. A save that silently did
    // nothing would leave every one of these untouched, so this is the
    // assertion that cannot pass on a broken feature.
    expect(
      _balance(store, 'a_gcash'),
      gcashBefore - 250.0,
      reason: 'GCash did not fall by the amount spent',
    );
    // The invariant beside it: spending reduces net worth by exactly what was
    // spent, and touches nothing else.
    expect(_netWorth(store), netBefore - 250.0);
    expect(
      _balance(store, 'a_bpi'),
      bpiBefore,
      reason: 'an unrelated account moved',
    );

    // And the OTHER screen agrees. This is the part no single-screen test can
    // do: the sheet wrote it, the Ledger reads it, and they were never in the
    // same test before.
    //
    // TWO, not one: the lived-in fixture already has a Jollibee from the day
    // before, which is exactly the sort of collision a tidy fixture would have
    // hidden. Asserting the count went UP is the honest check anyway, because
    // findsOneWidget would also pass if the new row replaced the old one.
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Jollibee'), findsNWidgets(2));
  });

  testWidgets('logging income raises net worth by exactly what came in', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final netBefore = _netWorth(store);
    final bpiBefore = _balance(store, 'a_bpi');

    await _log(tester, 'sweldo 18500', account: 'BPI');

    expect(
      _balance(store, 'a_bpi'),
      bpiBefore + 18500.0,
      reason: 'BPI did not rise by the amount received',
    );
    expect(_netWorth(store), netBefore + 18500.0);
  });

  testWidgets('an entry with no account still records, and moves no balance', (
    tester,
  ) async {
    // The fresh-install path, and the one most likely to be got wrong: on day
    // one there are no accounts at all. The entry must still be kept rather
    // than silently dropped, and it must not invent a balance change.
    //
    // An EMPTY store, deliberately. The first version of this ran against the
    // lived-in fixture and failed, correctly: with previous entries the sheet
    // preselects the last account used, so "no account" is not a state that
    // fixture can reach. D4 makes this path the one the founder actually meets
    // first, since v3 installs beside their daily app and starts empty.
    final store = await memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final netBefore = _netWorth(store);
    final countBefore = (store.data['transactions'] as List).length;

    await _log(tester, 'haircut 300');

    expect(
      (store.data['transactions'] as List).length,
      countBefore + 1,
      reason: 'the entry was dropped instead of being kept',
    );
    expect(
      _netWorth(store),
      netBefore,
      reason: 'an entry with no account changed a balance anyway',
    );
  });

  testWidgets('what the sheet promised is what got saved', (tester) async {
    // The "Got it" line is the app telling the founder what it understood
    // BEFORE they commit. If the line and the saved row can disagree, that
    // promise is worse than useless: it is a reassurance that is not true.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'jollibee 250');
    await tester.pumpAndSettle();

    // Read the promise off the screen, exactly as a person would.
    //
    // The money literal is what formatMoney actually renders, which is the
    // app's ONE peso formatter and drops centavos when there are none. The
    // first version of this expected "250.00" because the mockup's hand-typed
    // label said so; the mockup was a picture and formatMoney is the code, and
    // principle 3 says two places showing a peso differently is the bug.
    expect(find.textContaining('Got it:'), findsOneWidget);
    expect(find.textContaining('Jollibee'), findsWidgets);
    expect(find.textContaining('₱250'), findsWidgets);

    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    final saved = (store.data['transactions'] as List).last as Map;
    expect(saved['label'], 'Jollibee');
    expect(saved['amount'], 250.0);
    expect(saved['type'], 'expense');
    expect(
      saved['categoryId'],
      'cat_food',
      reason: 'the sheet showed Food and saved something else',
    );
  });

  testWidgets('a blank line cannot be saved', (tester) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final before = (store.data['transactions'] as List).length;
    final netBefore = _netWorth(store);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect((store.data['transactions'] as List).length, before);
    expect(_netWorth(store), netBefore);
  });

  testWidgets('two entries in a row both land, and the day total adds up', (
    tester,
  ) async {
    // One save working is not the same as the sheet being reusable. This is
    // where a controller that keeps its old text, or a view model that is not
    // rebuilt, shows up.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final netBefore = _netWorth(store);
    final gcashBefore = _balance(store, 'a_gcash');

    await _log(tester, 'jollibee 250', account: 'GCash');
    await _log(tester, 'load 100', account: 'GCash');

    expect(
      _balance(store, 'a_gcash'),
      gcashBefore - 350.0,
      reason: 'the second entry did not land, or landed twice',
    );
    expect(_netWorth(store), netBefore - 350.0);

    // Two of each, because the lived-in fixture already carries a Jollibee and
    // a Load from earlier days. Both new rows are there AND neither replaced
    // what was already in the list.
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Jollibee'), findsNWidgets(2));
    expect(find.text('Load'), findsNWidgets(2));
  });
}
