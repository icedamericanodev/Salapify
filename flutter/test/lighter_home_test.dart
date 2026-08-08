// Phase 3 batch 3c, the lighter Home tail:
//  1. Payday receipt: once the salary is logged AND the fresh number shows,
//     the payday card collapses to one row (title + Savings first). The full
//     explanation only stays when the number is hidden, where it is the only
//     truth on screen.
//  2. Treats mid-journey: the full dots card earns front-page space only when
//     the treat is earned or one check-in away; in between, one quiet line.
//  3. Accounts preview: the tail card lists the top three accounts by balance
//     and folds the rest into "and N more accounts", no peso figure (a
//     widget-side sum is forbidden, engines own totals).
//
// All fixtures are built RELATIVE to the run day (payday = today, check-ins =
// yesterday), so no test here depends on which calendar day the suite runs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart' show SalapifyApp;
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Map<String, Object> _storage({
  Map<String, dynamic>? settingsExtra,
  List<Map<String, dynamic>>? accounts,
  List<Map<String, dynamic>>? transactions,
}) {
  final today = _today;
  final payday = today.add(const Duration(days: 20));
  return {
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {
        'onboarded': true,
        'paydaySchedule': {'mode': 'monthly', 'day': payday.day},
        ...?settingsExtra,
      },
      'accounts':
          accounts ??
          [
            {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
          ],
      'transactions':
          transactions ??
          [
            for (var k = 1; k <= 6; k++)
              {
                'id': 't$k',
                'type': 'expense',
                'label': 'Meals',
                'amount': 60,
                'date': _iso(today.subtract(Duration(days: k))),
                'accountId': 'cash',
              },
          ],
    }),
  };
}

Future<void> _pumpHome(WidgetTester tester, Map<String, Object> storage) async {
  SharedPreferences.setMockInitialValues(storage);
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('payday receipt: logged salary with the number showing '
      'collapses to one row', (tester) async {
    final today = _today;
    await _pumpHome(
      tester,
      _storage(
        settingsExtra: {
          'paydaySchedule': {'mode': 'monthly', 'day': today.day},
        },
        transactions: [
          {
            'id': 'sal',
            'type': 'income',
            'label': 'Salary',
            'amount': 20000,
            'date': _iso(today),
            'accountId': 'cash',
          },
        ],
      ),
    );
    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    expect(find.text('Salary logged. Your cycle is set.'), findsOneWidget);
    expect(find.text('Savings first'), findsOneWidget);
    expect(
      find.textContaining('fresh from the new balance'),
      findsNothing,
      reason:
          'the receipt keeps one row; the long explanation only belongs to '
          'the full card, shown when the number is hidden',
    );
  });

  testWidgets('treats mid-journey: more than one check-in away is one quiet '
      'line, not the dots card', (tester) async {
    final today = _today;
    await _pumpHome(
      tester,
      _storage(
        settingsExtra: {
          'treats': [
            {
              'id': 'tr1',
              'treat': 'Milk tea',
              'action': 'walk',
              'emoji': '',
              'target': 5,
              'windowDays': 7,
              'checkIns': [
                _iso(today.subtract(const Duration(days: 1))),
                _iso(today.subtract(const Duration(days: 2))),
              ],
            },
          ],
        },
      ),
    );
    final slim = find.text('Earn your treats');
    await _scrollTo(tester, slim);
    expect(slim, findsOneWidget);
    expect(find.textContaining('2 of 5 toward milk tea'), findsOneWidget);
    expect(
      find.text('EARN YOUR TREAT'),
      findsNothing,
      reason:
          'mid-journey the treat keeps one quiet line; the dots card is for '
          'earned or one-away',
    );
  });

  testWidgets('treats earned: the win still gets the full card', (
    tester,
  ) async {
    final today = _today;
    await _pumpHome(
      tester,
      _storage(
        settingsExtra: {
          'treats': [
            {
              'id': 'tr1',
              'treat': 'Milk tea',
              'action': 'walk',
              'emoji': '',
              'target': 3,
              'windowDays': 7,
              'checkIns': [
                for (var k = 1; k <= 3; k++)
                  _iso(today.subtract(Duration(days: k))),
              ],
            },
          ],
        },
      ),
    );
    final kicker = find.text('EARN YOUR TREAT');
    await _scrollTo(tester, kicker);
    expect(kicker, findsOneWidget);
    expect(find.text('EARNED'), findsOneWidget);
  });

  testWidgets('five accounts preview as the top three by balance and '
      '"and 2 more accounts"', (tester) async {
    await _pumpHome(
      tester,
      _storage(
        accounts: [
          {'id': 'a', 'name': 'Wallet Alpha', 'kind': 'cash', 'balance': 500},
          {'id': 'b', 'name': 'Bank Bravo', 'kind': 'bank', 'balance': 9000},
          {
            'id': 'c',
            'name': 'Coin Charlie',
            'kind': 'ewallet',
            'balance': 100,
          },
          {'id': 'd', 'name': 'Bank Delta', 'kind': 'bank', 'balance': 7000},
          {'id': 'e', 'name': 'Echo Fund', 'kind': 'bank', 'balance': 3000},
        ],
      ),
    );
    final fold = find.text('and 2 more accounts');
    await _scrollTo(tester, fold);
    expect(fold, findsOneWidget);
    expect(find.text('Bank Bravo'), findsOneWidget);
    expect(find.text('Bank Delta'), findsOneWidget);
    expect(find.text('Echo Fund'), findsOneWidget);
    expect(
      find.text('Wallet Alpha'),
      findsNothing,
      reason: 'the two smallest balances live behind the Accounts screen',
    );
    expect(find.text('Coin Charlie'), findsNothing);
  });

  testWidgets('a foreign account keeps its symbol and ranks by its converted '
      'value', (tester) async {
    await _pumpHome(
      tester,
      _storage(
        settingsExtra: {
          'manualRates': {'USD': 57.0},
        },
        accounts: [
          {'id': 'a', 'name': 'Cash', 'kind': 'cash', 'balance': 2340},
          {'id': 'b', 'name': 'Bank Bravo', 'kind': 'bank', 'balance': 9000},
          {'id': 'c', 'name': 'Bank Delta', 'kind': 'bank', 'balance': 7000},
          {'id': 'd', 'name': 'Echo Fund', 'kind': 'bank', 'balance': 3000},
          {
            'id': 'usd',
            'name': 'Freelance USD',
            'kind': 'savings',
            'balance': 1200,
            'currencyCode': 'USD',
          },
        ],
      ),
    );
    final usdRow = find.text('Freelance USD');
    await _scrollTo(tester, usdRow);
    expect(
      usdRow,
      findsOneWidget,
      reason:
          'at 57 to 1 the dollar account is the biggest balance and must not '
          'hide behind the fold',
    );
    expect(find.text('\$1,200'), findsOneWidget);
    expect(
      find.text('₱1,200'),
      findsNothing,
      reason: 'a dollar balance never wears a peso sign',
    );
    expect(find.text('Echo Fund'), findsNothing);
    expect(find.text('Cash'), findsNothing);
    expect(find.text('and 2 more accounts'), findsOneWidget);
  });

  testWidgets('three accounts or fewer show every row and no fold line', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _storage(
        accounts: [
          {'id': 'a', 'name': 'Wallet Alpha', 'kind': 'cash', 'balance': 500},
          {'id': 'b', 'name': 'Bank Bravo', 'kind': 'bank', 'balance': 9000},
        ],
      ),
    );
    final row = find.text('Wallet Alpha');
    await _scrollTo(tester, row);
    expect(row, findsOneWidget);
    expect(find.text('Bank Bravo'), findsOneWidget);
    expect(find.textContaining('more accounts'), findsNothing);
  });
}
