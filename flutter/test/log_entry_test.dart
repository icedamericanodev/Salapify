// The first write path: logging an entry must move balances through the
// golden-verified engine, persist across a store reload, and update the UI.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> seedBlob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
        {'id': 'bank', 'name': 'Bank', 'kind': 'bank', 'balance': 5000},
      ],
      'transactions': <Map<String, dynamic>>[],
    };

void main() {
  testWidgets('logging an expense moves the account and this month',
      (tester) async {
    // Tall viewport so the whole Home column (net worth, accounts, and the this
    // month income statement) renders; the lazy ListView would otherwise skip
    // building rows below the fold. Same pattern as reports_screen_test.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(seedBlob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    // Net worth starts at 6,000 and Cash shows 1,000.
    expect(find.text('₱6,000'), findsOneWidget);
    expect(find.text('₱1,000'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pump();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    // Cash 1,000 - 250 = 750; net worth 5,750; this month spending 250.
    expect(find.text('₱750'), findsOneWidget);
    expect(find.text('₱5,750'), findsOneWidget);
    expect(find.text('₱250'), findsWidgets);

    // And it persisted: a brand new store instance reads the same state.
    final fresh = SalapifyStore();
    await fresh.load();
    final txs = (fresh.data['transactions'] as List);
    expect(txs.length, 1);
    expect((txs.first as Map)['label'], 'Groceries');
    final cash = (fresh.data['accounts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['id'] == 'cash');
    expect(cash['balance'], 750);
  });

  testWidgets('junk, non-finite, and comma-decimal amounts are refused',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(seedBlob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    // Empty, Infinity (would poison every later save), NaN, exponent, and a
    // comma decimal must all refuse and save nothing.
    for (final bad in ['', 'Infinity', 'NaN', '1e5', '2,50', '-5']) {
      await tester.enterText(find.byType(TextField).at(0), bad);
      await tester.tap(find.text('Save entry'));
      await tester.pump();
      expect((store.data['transactions'] as List), isEmpty,
          reason: 'input "$bad" must not save');
    }

    // And the sheet is not poisoned: a good amount still saves cleanly.
    await tester.enterText(find.byType(TextField).at(0), '100');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect((store.data['transactions'] as List).length, 1);
    final fresh = SalapifyStore();
    await fresh.load();
    expect((fresh.data['transactions'] as List).length, 1);
  });

  test('the store refuses a non-finite amount even if the UI missed it', () async {
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(seedBlob())});
    final store = SalapifyStore();
    await store.load();
    await expectLater(
        store.addEntry({'id': 'x', 'type': 'expense', 'amount': double.infinity}),
        throwsArgumentError);
    expect((store.data['transactions'] as List), isEmpty);
    // Later saves are NOT poisoned.
    await store.addEntry(
        {'id': 'y', 'type': 'expense', 'amount': 10, 'date': '2026-07-13'});
    final fresh = SalapifyStore();
    await fresh.load();
    expect((fresh.data['transactions'] as List).length, 1);
  });

  testWidgets('after a failed read the Log button is gone and writes refuse',
      (tester) async {
    // Unreadable stored data: the one state where saving would destroy it.
    SharedPreferences.setMockInitialValues({storageKey: 'not json at all {'});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(store.loadError, isNotNull);
    expect(find.text('Log'), findsNothing);
    await expectLater(
        store.addEntry(
            {'id': 'x', 'type': 'expense', 'amount': 50, 'date': '2026-07-13'}),
        throwsStateError);
    // The unreadable blob is still on disk, untouched.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(storageKey), 'not json at all {');
  });

  testWidgets('an account with a non-string id cannot crash the sheet',
      (tester) async {
    final blob = seedBlob();
    (blob['accounts'] as List).add({'id': 123, 'name': 'Weird', 'balance': 10});
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    // The store boundary now repairs the numeric id into its string form
    // (ensureEntityIds), so the account is a normal, linkable chip instead
    // of an untouchable ghost.
    expect(find.text('Save entry'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cash'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Weird'), findsOneWidget);
    final weird = (store.data['accounts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['name'] == 'Weird');
    expect(weird['id'], '123');
  });

  test('two ids minted in the same millisecond never collide', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1752600000000);
    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      seen.add(newEntryId(now));
    }
    expect(seen.length, 200);
  });

  test('parseAmount accepts thousands commas, rejects everything shady', () {
    expect(parseAmount('1,250'), 1250);
    expect(parseAmount('12,345.60'), 12345.60);
    expect(parseAmount('99.50'), 99.50);
    expect(parseAmount('.50'), 0.50);
    expect(parseAmount('2,50'), isNull);
    expect(parseAmount('1e5'), isNull);
    expect(parseAmount('Infinity'), isNull);
    expect(parseAmount('NaN'), isNull);
    expect(parseAmount('-5'), isNull);
    expect(parseAmount('0'), isNull);
    expect(parseAmount(' '), isNull);
  });

  testWidgets('importing a backup after a failed read restores writability',
      (tester) async {
    // The recovery flow the failed-read message promises: import, then log.
    SharedPreferences.setMockInitialValues({storageKey: 'not json at all {'});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(store.canWrite, isFalse);
    expect(find.text('Log'), findsNothing);

    await store.importBackupText(jsonEncode({
      'app': 'salapify',
      'schemaVersion': 12,
      'data': seedBlob(),
    }));
    await tester.pumpAndSettle();

    // Writable again: the error card is gone, the Log button is back, and a
    // real entry saves.
    expect(store.canWrite, isTrue);
    expect(store.loadError, isNull);
    expect(find.text('Log'), findsOneWidget);
    await store.addEntry(
        {'id': 'x', 'type': 'expense', 'amount': 50, 'date': '2026-07-13'});
    final fresh = SalapifyStore();
    await fresh.load();
    expect((fresh.data['transactions'] as List).length, 1);
  });
}
