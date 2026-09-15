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
import 'package:salapify/design/kit.dart';
import 'package:salapify/features/log/log_sheet.dart';
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

/// The Log TAB, not any other way in.
///
/// Home now carries a "Log" quick action of its own, so a bare find.text('Log')
/// matches two widgets and the tap fails as ambiguous. That ambiguity is the
/// screen working as intended: there are genuinely two doors to the same room.
/// A journey has to say which door it walked through, so this one names the
/// nav bar, the route that exists from every tab.
final _logTab = find.descendant(
  of: find.byType(NavBar),
  matching: find.text('Log'),
);

/// Type into the fast log field and save.
Future<void> _log(WidgetTester tester, String line, {String? account}) async {
  await tester.tap(_logTab);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), line);
  await tester.pumpAndSettle();
  if (account != null) {
    // The chip INSIDE the sheet. The Log route is deliberately not opaque, so
    // the screen behind it stays in the tree, and Home's latest entries name
    // the account they moved. Two widgets then say "BPI" and only one of them
    // is a control. Scoping to the sheet is the journey saying which.
    await tester.tap(
      find.descendant(of: find.byType(LogSheet), matching: find.text(account)),
    );
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

    await tester.tap(_logTab);
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

    await tester.tap(_logTab);
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

  testWidgets('paying a debt: the money moves, and every screen can SHOW it', (
    tester,
  ) async {
    // THE JOURNEY THE FOUNDER WALKED, and the one my own tests did not.
    //
    // The Debt batch shipped with tests that proved the arithmetic: net worth
    // unchanged, the account down by exactly the payment, the debt down. All
    // green. The founder then paid 1,500 off a loan, opened the account it came
    // out of, and found NOTHING in its history. The balance had moved and
    // nothing on the screen said why.
    //
    // Every one of those tests asked "is the money right". Not one asked "can
    // the person FOLLOW the money", which is the question an account screen
    // exists to answer, and the first question somebody who keeps books asks.
    //
    // So this journey does not stop at the store. It taps through to the
    // account and reads what is actually on it.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final netBefore = _netWorth(store);
    final bpiBefore = _balance(store, 'a_bpi');

    await tester.tap(find.text('Debt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('BPI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The invariant. Paying a debt lowers an asset and a liability by the same
    // amount, so it cannot change what you are worth.
    //
    // `_netWorth` here sums ACCOUNTS only, so on its own it would fall by the
    // payment. The pair below is what actually pins the double entry: the cash
    // went down by exactly 1,500 and the debt went down too.
    expect(
      _balance(store, 'a_bpi'),
      closeTo(bpiBefore - 1500, 0.005),
      reason: 'the money did not leave the account that was picked',
    );
    expect(
      _netWorth(store),
      closeTo(netBefore - 1500, 0.005),
      reason: 'more or less than the payment left the books',
    );

    var owed = 0.0;
    for (final d in (store.data['debts'] as List)) {
      if (d is Map && d['id'] == 'd_lola') owed = amountOf(d['remaining']);
    }
    expect(
      owed,
      lessThan(6000),
      reason: 'the cash left but the debt did not fall, so it went nowhere',
    );

    // AND NOW THE PART THAT WAS MISSING. Walk to the account the money came out
    // of, the way the founder did, and look.
    //
    // Back twice first. Debt detail and the Debt list are both pushed OVER the
    // shell, so the tab bar is not on screen at all while they are open: the
    // first version of this journey tapped straight for "Accounts" and failed
    // with "Found 0 widgets", which is the journey correctly refusing to
    // pretend it can teleport.
    // The back ARROW, by icon. `find.bySemanticsLabel('Back')` reads the
    // semantics tree, which is not built unless a test asks for it, so it
    // silently matched nothing and the taps did nothing at all.
    //
    // Popped WHILE there is one rather than a fixed number of times, so the
    // journey does not encode how many screens deep Debt happens to be today.
    var guard = 0;
    while (find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      if (++guard > 4) fail('could not get back to the tabs');
    }

    // The Accounts tab by its ICON, not by the word. NavBar draws the LABEL
    // only for the tab you are on, so from Home there is no "Accounts" text
    // inside the bar at all. A `find.text` there matched something elsewhere on
    // the page, and the descendant finder then came back empty and surfaced as
    // a bare "Bad state: No element" out of tap's own internals.
    await tester.tap(
      find.descendant(
        of: find.byType(NavBar),
        matching: find.byIcon(Icons.account_balance_wallet_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BPI').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Debt payment'),
      findsWidgets,
      reason:
          'BPI lost 1,500 and its history does not say why. A balance that '
          'moves with no entry behind it cannot be reconciled, and it is the '
          'first place somebody who keeps books looks',
    );
  });
}
