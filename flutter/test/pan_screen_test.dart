// Ask Pan end to end: the greeting with starter chips, a data-grounded
// answer computed from the seeded store, the copyable utang reminder, a
// guardrail decline, and a CTA that switches tabs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 4000},
  ],
  'transactions': [],
  'receivables': [
    {
      'id': 'r1',
      'person': 'Migs',
      'amount': 2000,
      'dueDate': '2020-01-05',
      'payments': [],
      'paid': false,
    },
  ],
};

Future<void> openPan(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Ask Pan'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ask Pan'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
  });

  testWidgets('greeting, grounded utang answer, and copyable reminder', (
    tester,
  ) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openPan(tester);

    expect(
      find.text(
        "Hi, I'm Pan. I read only what is on your phone. Ask me things like:",
      ),
      findsOneWidget,
    );
    expect(find.text('Safe to spend'), findsOneWidget); // starter chip

    await tester.enterText(find.byType(TextField), 'who owes me money');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // Grounded in the seeded receivable: 1 person, 2000, long overdue.
    expect(
      find.textContaining('1 person owes you ₱2,000 total'),
      findsOneWidget,
    );
    expect(find.textContaining('Hi Migs, gentle reminder'), findsOneWidget);
    expect(find.text('Copy reminder'), findsOneWidget);
  });

  testWidgets('a guardrail declines and never reads data', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openPan(tester);

    await tester.enterText(find.byType(TextField), 'where should I invest?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('I do not give investment advice'),
      findsOneWidget,
    );
  });

  testWidgets('a chip asks its example and the CTA can switch tabs', (
    tester,
  ) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await openPan(tester);

    await tester.tap(find.text('Who owes me'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('people owe you').evaluate().isNotEmpty ||
          find.textContaining('person owes you').evaluate().isNotEmpty,
      isTrue,
    );

    // The utang CTA pops Pan and lands on the Utang tab.
    await tester.tap(find.text('Open Utang'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your money…'), findsNothing);
    expect(find.textContaining('Migs'), findsWidgets);
  });
}
