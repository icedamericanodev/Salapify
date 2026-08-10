import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/insights_overview_v2.dart';

Map<String, dynamic> _data({
  required List<Map<String, dynamic>> transactions,
  List<Map<String, dynamic>> payments = const [],
}) => {
  'transactions': transactions,
  'payments': payments,
};

Widget _app(Map<String, dynamic> data) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: InsightsOverviewV2(
        data: data,
        ref: DateTime(2026, 7, 16, 12),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders the canonical current-month summary and chart labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _data(
          transactions: [
            {
              'id': 'income',
              'type': 'income',
              'label': 'Salary',
              'amount': 10000,
              'date': '2026-07-01',
            },
            {
              'id': 'expense',
              'type': 'expense',
              'label': 'Rent',
              'amount': 4000,
              'date': '2026-07-03',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial snapshot'), findsOneWidget);
    expect(find.text('Net cash flow'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Savings rate'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Cash flow trend'), findsOneWidget);
    expect(find.text('Positive this month'), findsOneWidget);
  });

  testWidgets('says when savings rate has no income denominator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _data(
          transactions: [
            {
              'id': 'expense',
              'type': 'expense',
              'label': 'Rent',
              'amount': 4000,
              'date': '2026-07-03',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not enough income data yet'), findsOneWidget);
    expect(find.text('Negative this month'), findsOneWidget);
  });

  testWidgets('net cash-flow direction is available to semantics, not color only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _data(
          transactions: [
            {
              'id': 'expense',
              'type': 'expense',
              'label': 'Rent',
              'amount': 4000,
              'date': '2026-07-03',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Net cash flow. Negative this month.'),
      findsOneWidget,
    );
  });
}
