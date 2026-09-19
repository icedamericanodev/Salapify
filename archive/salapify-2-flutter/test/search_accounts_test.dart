// Accounts in global Search. The shared search logic always found accounts,
// but the screen HID them with a note that the Accounts screen "is not ported
// to Flutter yet". It has been ported for a long time, so an account match
// simply vanished. These cover the four states that matter: nothing found, one
// account, several accounts, and, the one a race can produce, an account
// deleted between the result rendering and the tap.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _boot(
  WidgetTester tester,
  List<Map<String, Object?>> accounts,
) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': accounts,
    }),
  });
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.tap(find.byTooltip('Search'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

// Scope a finder to the Search screen, so a result row is never confused with
// the same account name drawn on the Home card underneath the pushed route.
Finder _inSearch(Finder f) =>
    find.descendant(of: find.byType(SearchScreen), matching: f);

void main() {
  testWidgets('a query matching no account shows the no-match state', (
    tester,
  ) async {
    await _boot(tester, [
      {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1000},
    ]);
    await _search(tester, 'zzznope');
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('one matching account shows the group and opens Accounts', (
    tester,
  ) async {
    await _boot(tester, [
      {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1000},
    ]);
    await _search(tester, 'gcash');
    expect(_inSearch(find.text('ACCOUNTS')), findsOneWidget);

    final row = _inSearch(find.text('GCash'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    // It opened the Accounts screen, focused on the matched account.
    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AccountsScreen),
        matching: find.text('GCash'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('several matching accounts all appear under the group', (
    tester,
  ) async {
    await _boot(tester, [
      {'id': 'a1', 'name': 'BPI Savings', 'kind': 'savings', 'balance': 1000},
      {'id': 'a2', 'name': 'BPI Checking', 'kind': 'checking', 'balance': 2000},
    ]);
    await _search(tester, 'bpi');
    expect(_inSearch(find.text('ACCOUNTS')), findsOneWidget);
    expect(_inSearch(find.text('BPI Savings')), findsOneWidget);
    expect(_inSearch(find.text('BPI Checking')), findsOneWidget);
  });

  testWidgets('an account deleted before the tap is handled gently', (
    tester,
  ) async {
    // The race, tested where it actually lands: Search hands Accounts an id,
    // and by the time Accounts opens, the account is gone. This is exactly the
    // state AccountsScreen receives, so it is pumped with a focus id that is
    // not in the store. It must say so, not crash on the stale id.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1000},
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    await store.deleteAccount('a1');

    await tester.pumpWidget(
      MaterialApp(
        home: AccountsScreen(store: store, focusAccountId: 'a1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(find.textContaining('was just removed'), findsOneWidget);
  });
}
