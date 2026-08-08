// Phase 4 batch 5: the stored debt type renders as words a person reads,
// never the lowercase machine string ("bnpl · 3.5% monthly").

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/debts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a bnpl debt row speaks English', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'debts': [
          {
            'id': 'd1',
            'name': 'Phone installment',
            'type': 'bnpl',
            'remaining': 6000,
            'monthlyRate': 0,
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DebtsScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BNPL (pay later)'), findsOneWidget);
    expect(
      find.text('bnpl'),
      findsNothing,
      reason: 'the machine string must never reach the screen',
    );
  });
}
