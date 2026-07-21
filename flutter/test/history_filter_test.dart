// The History text filter: typing narrows the list with the golden-locked
// txMatches, and a global-search Entries result opens History pre-filtered
// (pushed mode with a back-capable app bar).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _seed() async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode({
      'transactions': [
        {
          'id': 't1',
          'label': 'Jollibee lunch',
          'amount': 150.0,
          'type': 'expense',
          'date': '2026-07-03',
        },
        {
          'id': 't2',
          'label': 'Grab home',
          'amount': 220.0,
          'type': 'expense',
          'date': '2026-07-02',
        },
      ],
    }),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  testWidgets('typing in History narrows the list', (tester) async {
    final store = await _seed();
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Jollibee lunch'), findsOneWidget);
    expect(find.text('Grab home'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jollibee');
    await tester.pumpAndSettle();
    expect(find.text('Jollibee lunch'), findsOneWidget);
    expect(find.text('Grab home'), findsNothing);
  });

  testWidgets('pushed History seeds the filter and shows a back app bar',
      (tester) async {
    final store = await _seed();
    await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(store: store, initialQuery: 'grab', pushed: true)));
    await tester.pumpAndSettle();

    // Only the matching row shows, and the pushed app bar title is present.
    expect(find.text('Grab home'), findsOneWidget);
    expect(find.text('Jollibee lunch'), findsNothing);
    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);
  });

  testWidgets('swipe delete in pushed History rebuilds the list, no ghost',
      (tester) async {
    // Regression: the pushed route is not under main's ListenableBuilder, so
    // without its own the dismissed row would stay in the tree (assert/ghost).
    final store = await _seed();
    await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(store: store, pushed: true)));
    await tester.pumpAndSettle();

    expect(find.text('Jollibee lunch'), findsOneWidget);
    await tester.drag(
        find.text('Jollibee lunch'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jollibee lunch'), findsNothing);
    expect(
        (store.data['transactions'] as List)
            .any((t) => t is Map && t['id'] == 't1'),
        isFalse);
  });
}
