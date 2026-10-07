// The two charts that show change. The figures come from trends.dart and are
// tested there; this pins what a person can DO with the charts and read off
// them: tap a month and get that month, and get the right answer about pace.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/trends.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/reports/trend_charts.dart';

MonthTotals _m(int month, double income, double expenses) => MonthTotals(
  year: 2026,
  month: month,
  income: income,
  expenses: expenses,
  keptRate: income > 0 ? (income - expenses) / income * 100 : null,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

void main() {
  const Palette palette = Palette.gabi;

  group('month by month', () {
    final List<MonthTotals> months = <MonthTotals>[
      _m(7, 30000, 41000),
      _m(8, 40000, 12000),
      _m(9, 51000, 25774.75),
    ];

    testWidgets('opens on the current month', (WidgetTester tester) async {
      await _pump(tester, MonthlyInOutChart(palette: palette, months: months));
      await tester.pumpAndSettle();
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('₱25,774.75'), findsOneWidget);
    });

    testWidgets('tapping a month shows THAT month', (
      WidgetTester tester,
    ) async {
      await _pump(tester, MonthlyInOutChart(palette: palette, months: months));
      await tester.pumpAndSettle();

      // The first of three evenly spaced columns.
      final Rect chart = tester.getRect(find.byType(BarChart));
      await tester.tapAt(
        Offset(chart.left + chart.width / 6, chart.bottom - 40),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('JULY 2026'),
        findsOneWidget,
        reason: 'the tap did not select the month it landed on',
      );
      // DIRECTIONAL: July overspent, so the figures really moved with it.
      expect(find.text('Overspent'), findsOneWidget);
      expect(find.text('₱11,000.00'), findsOneWidget);
    });
  });

  group('spending pace', () {
    SpendingPace pace(List<double> thisMonth, List<double> lastMonth) =>
        SpendingPace(
          thisMonth: thisMonth,
          lastMonth: lastMonth,
          daysInThisMonth: 30,
        );

    testWidgets('says when spending is ahead of last month', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SpendingPaceChart(
          palette: palette,
          pace: pace(<double>[100, 900, 1500], <double>[200, 400, 600, 2000]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₱900.00 more than last month by day 3.'), findsOne);
    });

    testWidgets('and when it is behind', (WidgetTester tester) async {
      await _pump(
        tester,
        SpendingPaceChart(
          palette: palette,
          pace: pace(<double>[100, 200], <double>[300, 700, 900]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₱500.00 less than last month by day 2.'), findsOne);
    });

    testWidgets('claims nothing in a first month', (WidgetTester tester) async {
      await _pump(
        tester,
        SpendingPaceChart(
          palette: palette,
          pace: pace(<double>[100, 200], const <double>[]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('than last month'), findsNothing);
      expect(find.text('Last month'), findsNothing);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('draws at once when the phone asks for less motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: SpendingPaceChart(
                  palette: palette,
                  pace: pace(<double>[100, 900], <double>[200, 400]),
                ),
              ),
            ),
          ),
        ),
      );
      // ONE frame, no settling: the line is already at full height.
      final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData[1].spots.last.y, 900);
    });
  });
}
