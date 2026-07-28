// Reports screen: the empty state, and the three statements rendering from the
// golden-locked engine with the plain-language headlines, reached from Menu.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

String _thisMonth(int day) {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

String _monthsAgo(int months, int day) {
  final n = DateTime.now();
  final d = DateTime(n.year, n.month - months, day);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<void> _openReports(WidgetTester tester) async {
  await openFromMenu(tester, 'Reports');
}

void main() {
  testWidgets('tapping a category row carries the month you were reading', (
    tester,
  ) async {
    // Session 15: this fix SHIPPED WITH NO TEST. Removing the initialPeriod
    // argument left all 982 tests green, so a future tidy-up could quietly
    // undo it and nothing would say so.
    //
    // The harm it prevents: Reports says "Food ₱4,200" under LAST MONTH, you
    // tap it to see where the money went, and Activity lists Food from every
    // month. The rows visibly do not add up to the number you tapped, and
    // nothing on screen explains the difference.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'transactions': [
          {
            'id': 'now',
            'type': 'expense',
            'label': 'Food',
            'amount': 500,
            'date': _thisMonth(5),
          },
          {
            'id': 'then',
            'type': 'expense',
            'label': 'Food',
            'amount': 4200,
            'date': _monthsAgo(1, 5),
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReports(tester);

    // Step back a month, so the number on screen is last month's.
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').first);
    await tester.pumpAndSettle();

    // Activity opened on THAT month: last month's row is there, this
    // month's is not.
    // Scoped to the LIST. A bare textContaining('500') matched the filter
    // box's own placeholder, "Filter entries, like jollibee or 1500", which
    // would have made this pass or fail for a reason that has nothing to do
    // with the period.
    Finder row(String text) => find.descendant(
      of: find.byType(ListView),
      matching: find.textContaining(text),
    );
    expect(row('4,200'), findsWidgets);
    expect(
      row('₱500'),
      findsNothing,
      reason: 'a row from a month the person was not reading',
    );
  });

  testWidgets('empty state invites the first log', (tester) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
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
          {
            'id': 'i1',
            'date': _thisMonth(15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'accountId': 'c',
          },
          {
            'id': 'e1',
            'date': _thisMonth(5),
            'type': 'expense',
            'label': 'Food',
            'amount': 5000,
            'accountId': 'c',
          },
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

    // Back to Income, then tap a category: it opens History filtered to it.
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    final foodRow = find
        .ancestor(of: find.text('Food').last, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(foodRow);
    await tester.pumpAndSettle();
    await tester.tap(foodRow);
    await tester.pumpAndSettle();
    // The pushed History route shows its back-capable app bar and pre-fills
    // the filter with the category name.
    expect(find.widgetWithText(AppBar, 'Activity'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Food'), findsOneWidget);
  });

  testWidgets('the new decision graphs render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 12000},
        ],
        'transactions': [
          // This month: income plus expenses on five different weekdays, so the
          // weekday pattern has a real peak to draw.
          {
            'id': 'i0',
            'date': _thisMonth(15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'accountId': 'c',
          },
          {
            'id': 'e1',
            'date': _thisMonth(2),
            'type': 'expense',
            'label': 'Food',
            'amount': 400,
            'accountId': 'c',
          },
          {
            'id': 'e2',
            'date': _thisMonth(3),
            'type': 'expense',
            'label': 'Grab',
            'amount': 300,
            'accountId': 'c',
          },
          {
            'id': 'e3',
            'date': _thisMonth(4),
            'type': 'expense',
            'label': 'Food',
            'amount': 900,
            'accountId': 'c',
          },
          {
            'id': 'e4',
            'date': _thisMonth(5),
            'type': 'expense',
            'label': 'Bills',
            'amount': 200,
            'accountId': 'c',
          },
          {
            'id': 'e5',
            'date': _thisMonth(6),
            'type': 'expense',
            'label': 'Food',
            'amount': 600,
            'accountId': 'c',
          },
          // Prior months so the net cash flow trend has a positive and a
          // negative month.
          {
            'id': 'i1',
            'date': _monthsAgo(1, 15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'accountId': 'c',
          },
          {
            'id': 'e6',
            'date': _monthsAgo(1, 10),
            'type': 'expense',
            'label': 'Rent',
            'amount': 25000,
            'accountId': 'c',
          },
          {
            'id': 'i2',
            'date': _monthsAgo(2, 15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'accountId': 'c',
          },
          {
            'id': 'e7',
            'date': _monthsAgo(2, 10),
            'type': 'expense',
            'label': 'Food',
            'amount': 8000,
            'accountId': 'c',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReports(tester);

    // Income tab: the weekday pattern card renders.
    expect(find.text('WHEN YOU SPEND'), findsOneWidget);
    expect(find.textContaining('You spend the most on'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Cash flow tab: the net saved-or-spent trend renders above the statement.
    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();
    expect(find.text('SAVED OR SPENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
