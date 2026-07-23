// Regression test for the Afford-This card's stay-alive contract: an absurd
// pasted amount must never crash the Insights tab. QA found that a finite amount
// big enough to overflow a later multiply (share*100, months*10) would throw in
// round() and take down the whole screen; these pumps prove the guards hold in
// both modes, with a small income/expense base so the products actually overflow.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _mAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - n, 15);
}

void main() {
  testWidgets('an absurd amount never crashes the Insights tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Tiny income and expense so a huge amount overflows newShare*100 and
    // cushionMonths*10; three income months make hasIncomeBase true so the
    // installment path actually computes a share.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 50},
        ],
        'transactions': [
          {'id': 'i1', 'date': _iso(_mAgo(1)), 'type': 'income', 'label': 'x', 'amount': 50},
          {'id': 'i2', 'date': _iso(_mAgo(2)), 'type': 'income', 'label': 'x', 'amount': 50},
          {'id': 'i3', 'date': _iso(_mAgo(3)), 'type': 'income', 'label': 'x', 'amount': 50},
          {'id': 'e1', 'date': _iso(_mAgo(1)), 'type': 'expense', 'label': 'y', 'amount': 5},
          {'id': 'e2', 'date': _iso(_mAgo(2)), 'type': 'expense', 'label': 'y', 'amount': 5},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CAN YOU AFFORD IT?'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // A finite ~1e300 amount (300 digits), not coerced to 0.
    final huge = '1${'0' * 300}';

    // One-time mode: exercises the cushion-months formatter.
    await tester.enterText(find.byType(TextField).last, huge);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Pay monthly: exercises the spoken-for percent formatter with tiny income.
    await tester.tap(find.text('Pay monthly'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, huge);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The card is still on screen, not replaced by a red error box.
    expect(find.text('CAN YOU AFFORD IT?'), findsOneWidget);
  });
}
