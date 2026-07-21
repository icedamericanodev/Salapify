// The Debts screen end to end: open from the Overview tools row, add a
// debt through the form (validation included), log a payment from an
// account, mark paid off behind the confirm showing the true payoff, and
// delete keeping history.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'acct1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 10000},
      ],
      'transactions': [],
      'debts': [
        {
          'id': 'debt1',
          'name': 'Salary Loan',
          'type': 'personal loan',
          'remaining': 5000,
          'monthlyRate': 0,
          'minPayment': 500,
          'dueDay': 0,
          'statementDay': 0,
          'graceDays': 0,
          'creditLimit': 0,
          'interestThroughISO': '2026-01-01',
        },
      ],
      'payments': [],
    };

Future<void> openDebts(WidgetTester tester, SalapifyStore store) async {
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Debts'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Debts'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  testWidgets('totals render and a payment flows through the account',
      (tester) async {
    final store = SalapifyStore();
    await openDebts(tester, store);

    expect(find.text('TOTAL DEBT'), findsOneWidget);
    expect(find.text('₱5,000'), findsWidgets);
    expect(find.text('Salary Loan'), findsOneWidget);

    await tester.tap(find.text('Salary Loan'));
    await tester.pumpAndSettle();

    // The payment box is prefilled with the minimum; pay from GCash.
    expect(find.text('LOG A PAYMENT'), findsOneWidget);
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log payment'));
    await tester.pumpAndSettle();

    expect(find.text('Logged ₱500 from GCash. New balance ₱4,500.'),
        findsOneWidget);
    final acct =
        (store.data['accounts'] as List).cast<Map<String, dynamic>>().single;
    expect(acct['balance'], 9500.0);
    final txs =
        (store.data['transactions'] as List).cast<Map<String, dynamic>>();
    expect(txs.single['label'], 'Debt payment: Salary Loan');
  });

  testWidgets('mark paid off confirms with the true payoff and celebrates',
      (tester) async {
    final store = SalapifyStore();
    await openDebts(tester, store);
    await tester.tap(find.text('Salary Loan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark paid off'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Log ₱5,000 as a real payment'),
        findsOneWidget);
    await tester.tap(find.text('Pay it off'));
    await tester.pumpAndSettle();

    expect(find.textContaining('paid off! Utang free.'), findsOneWidget);
    final debt =
        (store.data['debts'] as List).cast<Map<String, dynamic>>().single;
    expect(debt['remaining'], 0.0);
    expect(
        ((store.data['accounts'] as List).cast<Map<String, dynamic>>())
            .single['balance'],
        10000.0); // Outside the app by default: no account was picked.
  });

  testWidgets('the add form validates with the exact RN sentence',
      (tester) async {
    final store = SalapifyStore();
    await openDebts(tester, store);

    await tester.tap(find.text('Add debt'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Name, like BPI card or Utang kay Kuya'),
        'Metrobank');
    await tester.enterText(
        find.widgetWithText(TextField, 'Remaining balance'), '8,000');
    await tester.enterText(
        find.widgetWithText(TextField, 'Statement day (optional)'), '3');
    await tester.ensureVisible(find.text('Add debt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add debt').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Add the days after statement until due'),
        findsOneWidget);

    await tester.enterText(
        find.widgetWithText(
            TextField, 'Days after statement until due (optional)'),
        '21');
    await tester.ensureVisible(find.text('Add debt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add debt').last);
    await tester.pumpAndSettle();

    final debts = (store.data['debts'] as List).cast<Map<String, dynamic>>();
    expect(debts.length, 2);
    expect(debts.last['name'], 'Metrobank');
    expect(debts.last['remaining'], 8000.0);
    expect(debts.last['graceDays'], 21);
  });

  testWidgets('a no-op edit round trips a huge balance unchanged',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [],
        'debts': [
          {
            'id': 'huge',
            'name': 'Huge Loan',
            'type': 'other',
            'remaining': 1e21,
            'monthlyRate': 0,
            'minPayment': 0,
            'dueDay': 0,
            'statementDay': 0,
            'graceDays': 0,
            'creditLimit': 0,
            'interestThroughISO': '2026-01-01',
          },
        ],
      })
    });
    final store = SalapifyStore();
    await openDebts(tester, store);
    await tester.tap(find.text('Huge Loan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // The prefill used to clamp 1e21 to 2^63-1, silently rewriting the
    // balance and resetting the interest clock on a save-without-changes.
    final debt =
        (store.data['debts'] as List).cast<Map<String, dynamic>>().single;
    expect(debt['remaining'], 1e21);
    expect(debt['interestThroughISO'], '2026-01-01');
  });

  testWidgets('delete keeps the payment history', (tester) async {
    final store = SalapifyStore();
    await openDebts(tester, store);
    await tester.tap(find.text('Salary Loan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GCash'));
    await tester.tap(find.text('Log payment'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this debt?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect((store.data['debts'] as List), isEmpty);
    expect((store.data['payments'] as List).length, 1);
    expect((store.data['transactions'] as List).length, 1);
    expect(find.text('No debts tracked'), findsOneWidget);
  });
}
