// The transfer sheet on the Accounts screen: that it reaches the golden-locked
// engine, that both balances land, that the record row is written once and
// carries no account link, and that every refusal is shown as a sentence
// rather than swallowed.
//
// The money itself is proven in transfer_golden_test.dart against the real RN
// engine. What is proven HERE is the wiring, which is the half a golden file
// cannot see: a screen can format a perfect number into the wrong field.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/transfers.dart' show TransferRefusal;
import 'package:salapify/screens/accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({List<Map<String, dynamic>>? accounts}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'accounts':
      accounts ??
      [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3200},
        {'id': 'bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 48500.55},
      ],
  'transactions': <Map<String, dynamic>>[],
};

Future<SalapifyStore> _open(
  WidgetTester tester, {
  Map<String, dynamic>? blob,
}) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? _blob()),
  });
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(MaterialApp(home: AccountsScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Move money between accounts'));
  await tester.pumpAndSettle();
}

/// Open the Accounts screen on a chosen viewport and system text scale, so the
/// transfer sheet can be tested where it is hardest to lay out: a short phone
/// with the text turned up. The builder injects the scale ABOVE the navigator
/// so the pushed modal inherits it too.
Future<SalapifyStore> _openScaled(
  WidgetTester tester, {
  Map<String, dynamic>? blob,
  double scale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? _blob()),
  });
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      home: AccountsScreen(store: store),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

List<Map<String, dynamic>> _manyLongAccounts() => [
  for (var i = 0; i < 8; i++)
    {
      'id': 'acct$i',
      'name': 'My Very Long Everyday Bank Account Name Number $i',
      'kind': 'cash',
      'balance': 5000.0 + i,
    },
];

List<Map<String, dynamic>> _accounts(SalapifyStore s) =>
    (s.data['accounts'] as List).cast<Map<String, dynamic>>();

double _balanceOf(SalapifyStore s, String id) =>
    (_accounts(s).firstWhere((a) => a['id'] == id)['balance'] as num)
        .toDouble();

void main() {
  testWidgets('a transfer moves both balances and leaves one record row', (
    tester,
  ) async {
    final store = await _open(tester);
    await _openSheet(tester);

    // Defaults are the first two accounts, so this is amount-only.
    await tester.enterText(find.byType(TextField), '1,000');
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();

    expect(_balanceOf(store, 'cash'), 2200);
    expect(_balanceOf(store, 'bpi'), 49500.55);

    final txs = (store.data['transactions'] as List)
        .cast<Map<String, dynamic>>();
    expect(txs, hasLength(1));
    expect(txs.single['type'], 'transfer');
    expect(txs.single['label'], 'Transfer: Cash to BPI');
    expect(txs.single['amount'], 1000);
    expect(txs.single['transferFromId'], 'cash');
    expect(txs.single['transferToId'], 'bpi');
    // No accountId, ever: the balances moved here, so a linked row would move
    // them again the day someone deletes it from History.
    expect(txs.single.containsKey('accountId'), isFalse);
    // The sheet closed on success.
    expect(find.text('Move it'), findsNothing);
  });

  testWidgets('an overdraft is refused in words, and nothing moves', (
    tester,
  ) async {
    final store = await _open(tester);
    await _openSheet(tester);
    await tester.enterText(find.byType(TextField), '99999');
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();

    expect(find.text('Cash only has ₱3,200.'), findsOneWidget);
    expect(_balanceOf(store, 'cash'), 3200);
    expect(_balanceOf(store, 'bpi'), 48500.55);
    expect(store.data['transactions'], isEmpty);
    // Still open, so the amount can be corrected without starting over.
    expect(find.text('Move it'), findsOneWidget);
  });

  testWidgets('a blank amount is refused, and nothing moves', (tester) async {
    final store = await _open(tester);
    await _openSheet(tester);
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
    expect(store.data['transactions'], isEmpty);
  });

  testWidgets('the same account twice is refused', (tester) async {
    final store = await _open(tester);
    await _openSheet(tester);
    // Pick Cash on BOTH sides: the second chip row is the destination.
    final cashChips = find.textContaining('Cash');
    await tester.tap(cashChips.last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();
    expect(find.text('Pick two different accounts.'), findsOneWidget);
    expect(store.data['transactions'], isEmpty);
  });

  testWidgets('the picker shows the balance the refusal will use', (
    tester,
  ) async {
    // The render caught this one: an account holding 48,500.55 displayed as
    // "48,501", and moving 48,501 out of it is refused. A screen must not
    // print a number the next tap contradicts.
    await _open(tester);
    await _openSheet(tester);
    expect(find.textContaining('BPI  ₱48,500.55'), findsWidgets);
    expect(find.textContaining('BPI  ₱48,501'), findsNothing);
    // A whole balance still reads whole, with no decorative centavos.
    expect(find.textContaining('Cash  ₱3,200'), findsWidgets);
    expect(find.textContaining('Cash  ₱3,200.00'), findsNothing);
  });

  testWidgets('a giant balance never takes the sheet down', (tester) async {
    // QA MUST FIX: balanceLabel multiplied by 100 first, so any balance past
    // ~1.79e306 overflowed to Infinity, NaN.toInt() threw, and the sheet
    // failed to build. Every later tap of the button threw too, with nothing
    // on screen to explain it. Reachable from a restored backup or a long
    // typed number.
    await _open(
      tester,
      blob: _blob(
        accounts: [
          {'id': 'whale', 'name': 'Whale', 'kind': 'cash', 'balance': 1e307},
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 100},
        ],
      ),
    );
    await _openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Move money'), findsOneWidget);
  });

  testWidgets('the refusal never claims more than the account holds', (
    tester,
  ) async {
    // QA MUST FIX: rounding the display moved the lie rather than removing
    // it. An account holding 0.999 showed "1", and moving 1 was refused by a
    // message that ALSO said "only has 1". The screen and the sentence agreed
    // with each other and both contradicted the behaviour.
    final store = await _open(
      tester,
      blob: _blob(
        accounts: [
          {'id': 'w', 'name': 'Wallet', 'kind': 'cash', 'balance': 0.999},
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 100},
        ],
      ),
    );
    await _openSheet(tester);
    expect(find.textContaining('Wallet  ₱0.99'), findsWidgets);
    expect(find.textContaining('Wallet  ₱1'), findsNothing);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet only has ₱0.99.'), findsOneWidget);
    expect(store.data['transactions'], isEmpty);
  });

  testWidgets('writes shut means the transfer door is not there', (
    tester,
  ) async {
    // QA raised that a THROWN store failure left the button disabled forever
    // with nothing on screen. The sheet now catches and says so, but the
    // reachable half of that hazard is this: after an unreadable load the
    // door is not offered at all, so nobody can try to move money the app
    // cannot save.
    //
    // The catch itself stays as defense in depth for a failed disk write,
    // which this suite cannot reach without mocking the platform channel.
    // Saying that plainly beats a test that pretends to cover it.
    SharedPreferences.setMockInitialValues({storageKey: '{broken'});
    final store = SalapifyStore();
    await store.load();
    expect(store.canWrite, isFalse);
    store.data['accounts'] = [
      {'id': 'a', 'name': 'A', 'kind': 'cash', 'balance': 500},
      {'id': 'b', 'name': 'B', 'kind': 'cash', 'balance': 100},
    ];
    await tester.pumpWidget(MaterialApp(home: AccountsScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Move money between accounts'), findsNothing);
  });

  testWidgets('a write landing mid-transfer refuses instead of crashing', (
    tester,
  ) async {
    // The QA fix that made transferBetweenAccounts a single run inside the
    // write queue shipped with no test, which the session 11 retrospective
    // caught. This is that test.
    //
    // The old shape validated against the data as it was, then applied
    // against the data as it had become, and threw "the transfer became
    // invalid mid-write" when they disagreed, leaving the sheet dead. The
    // write queue defers through Future.then, so queueing a spend first and
    // asking to move the whole balance second is enough to land one write
    // between the two runs.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(
        _blob(
          accounts: [
            {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
            {'id': 'bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 0},
          ],
        ),
      ),
    });
    final store = SalapifyStore();
    await store.load();

    final spending = store.addEntry({
      'type': 'expense',
      'label': 'Groceries',
      'amount': 1000.0,
      'accountId': 'cash',
      'date': '2026-07-28',
    });
    final moving = store.transferBetweenAccounts(
      fromId: 'cash',
      toId: 'bpi',
      amountText: '1000',
    );
    await spending;
    final refusal = await moving;

    // Refused as an ordinary answer, not thrown as a crash.
    expect(refusal, isNotNull);
    expect(refusal!.refusal, TransferRefusal.overdraft);
    // And the money is where the spend left it: no half-applied transfer.
    expect(_balanceOf(store, 'cash'), 0);
    expect(_balanceOf(store, 'bpi'), 0);
  });

  testWidgets('one account means no transfer button at all', (tester) async {
    // Offering it would be offering a dead end: there is nowhere to move to.
    await _open(
      tester,
      blob: _blob(
        accounts: [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3200},
        ],
      ),
    );
    expect(find.text('Move money between accounts'), findsNothing);
  });

  testWidgets('a transfer is invisible to income and spending', (tester) async {
    // The whole point of the type: it must not read as money earned or spent
    // anywhere. Checked through the same statement engine Home and Budget use.
    final store = await _open(tester);
    await _openSheet(tester);
    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.text('Move it'));
    await tester.pumpAndSettle();

    final txs = (store.data['transactions'] as List)
        .cast<Map<String, dynamic>>();
    expect(txs.single['type'], 'transfer');
    // Net worth is unchanged: money moved, none appeared or vanished.
    final total = _accounts(
      store,
    ).fold<double>(0, (t, a) => t + (a['balance'] as num).toDouble());
    expect(total, closeTo(3200 + 48500.55, 0.0001));
  });

  testWidgets(
    'the primary action stays on screen at small height and large text',
    (tester) async {
      // A short phone with the text turned up is where the old all-in-one
      // scroll view could push "Move it" off the bottom. It is pinned now, so
      // it must render within the viewport without scrolling.
      await _openScaled(tester, scale: 1.5, size: const Size(360, 600));
      await _openSheet(tester);
      expect(tester.takeException(), isNull);

      final moveIt = find.text('Move it');
      expect(moveIt, findsOneWidget);
      final screenH =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getRect(moveIt).bottom,
        lessThanOrEqualTo(screenH + 0.5),
        reason:
            'the pinned primary action must sit within the viewport, not be '
            'scrolled off the bottom of the sheet',
      );
    },
  );

  testWidgets(
    'with many long-named accounts the fields scroll and Move it still commits',
    (tester) async {
      final store = await _openScaled(
        tester,
        blob: _blob(accounts: _manyLongAccounts()),
        scale: 1.3,
        size: const Size(360, 600),
      );
      await _openSheet(tester);
      expect(tester.takeException(), isNull);
      // The action is pinned and present even though the pickers are tall.
      expect(find.text('Move it'), findsOneWidget);

      // Defaults are the first two accounts. Enter an amount, scroll the field
      // area (dragging on a field label scrolls the sheet's inner scroll view),
      // then activate the pinned action.
      await tester.enterText(find.byType(TextField), '10');
      // The sheet's own scroll view is the last one pumped (above the Accounts
      // list). Dragging it up proves the fields scroll under the pinned action.
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Move it'));
      await tester.pumpAndSettle();

      // acct0 -> acct1 by 10.
      expect(_balanceOf(store, 'acct0'), 4990.0);
      expect(_balanceOf(store, 'acct1'), 5011.0);
    },
  );

  testWidgets('double-tapping Move it commits exactly one transfer', (
    tester,
  ) async {
    // The re-entrancy guard (_saving) sets synchronously inside _save before
    // the await, so a second tap that lands before the first save settles is
    // dropped. Two taps must not move the money twice.
    final store = await _open(tester);
    await _openSheet(tester);
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Move it'));
    // Second tap before the async save settles; the sheet may already be
    // closing, so do not warn if it misses.
    await tester.tap(find.text('Move it'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final transfers = (store.data['transactions'] as List)
        .cast<Map<String, dynamic>>()
        .where((t) => t['type'] == 'transfer');
    expect(transfers, hasLength(1));
    expect(_balanceOf(store, 'cash'), 3100);
    expect(_balanceOf(store, 'bpi'), 48600.55);
  });
}
