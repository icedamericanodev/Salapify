// Backdating: the number one reason to abandon a tracker is "I missed a day
// so the numbers are wrong". The Log sheet's date chips give a forgotten
// Tuesday a two-tap fix, and the receipt then names the day so a backdated
// write reports what really happened.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
  ],
  'transactions': <Map<String, dynamic>>[],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  });

  testWidgets('Yesterday logs on yesterday, and the receipt names the day', (
    tester,
  ) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yesterday'));
    await tester.pump();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final txs = (store.data['transactions'] as List).cast<Map>();
    expect(txs, hasLength(1));
    expect(
      txs.single['date'],
      yesterday,
      reason:
          'The Yesterday chip must set the stored date. An entry stamped '
          'with the moment of typing is exactly what backdating exists to '
          'fix.',
    );
    expect(
      find.textContaining('logged for'),
      findsOneWidget,
      reason:
          'A backdated receipt must name the day, or it implies the money '
          'moved today.',
    );
  });

  testWidgets('a today log keeps the plain receipt', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries ₱250 logged.'), findsOneWidget);
    expect(find.textContaining('logged for'), findsNothing);
  });

  testWidgets('the utang due date comes from a picker, never a keyboard', (
    tester,
  ) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await goToOwedToMe(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();

    final due = find.widgetWithText(TextField, 'Due date (optional), tap to pick');
    expect(due, findsOneWidget);
    expect(
      tester.widget<TextField>(due).readOnly,
      isTrue,
      reason:
          'The due date field must be read only. Hand-typed ISO on a phone '
          'keyboard fed typo dates into the overdue math.',
    );
    await tester.tap(due);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final text = tester.widget<TextField>(due).controller!.text;
    expect(
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text),
      isTrue,
      reason: 'The picker must write the exact YYYY-MM-DD shape the store '
          'already expects, got "$text".',
    );
  });
}
