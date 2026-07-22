// Reports screen: the empty state, and the three statements rendering from the
// golden-locked engine with the plain-language headlines, reached from Menu.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _thisMonth(int day) {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

Future<void> _openReports(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Reports'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Reports'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reports'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state invites the first log', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReports(tester);
    expect(find.text('Your reports build themselves'), findsOneWidget);
    expect(find.text('YOUR NET WORTH'), findsNothing);
  });

  testWidgets('renders the three statements with headlines', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
        ],
        'transactions': [
          {'id': 'i1', 'date': _thisMonth(15), 'type': 'income', 'label': 'Sweldo', 'amount': 20000, 'accountId': 'c'},
          {'id': 'e1', 'date': _thisMonth(5), 'type': 'expense', 'label': 'Food', 'amount': 5000, 'accountId': 'c'},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReports(tester);

    // Net worth hero and the segmented control.
    expect(find.text('YOUR NET WORTH'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Cash flow'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    // Income is the default tab; net income is positive, so the headline reads
    // "... kept".
    expect(find.textContaining('kept'), findsWidgets);
    // The spending trend section rides under the income statement.
    expect(find.text('SPENDING TREND'), findsOneWidget);
    // The category drilldown lists the month's biggest spend (Food here).
    expect(find.text('WHERE IT WENT'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);

    // Switch to Position: net worth is positive, so "to your name".
    await tester.tap(find.text('Position'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to your name'), findsWidgets);

    // Switch to Cash flow: renders without error.
    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('cash'), findsWidgets);
  });
}
