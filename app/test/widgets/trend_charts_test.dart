// The two charts that show change. The figures come from trends.dart and are
// tested there; this pins what a person can DO with the charts and read off
// them: tap a month and get that month, and get the right answer about pace.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/net_worth_history.dart';
import 'package:salapify/core/money/trends.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/reports/trend_charts.dart';

MonthTotals _m(int month, double income, double expenses) => MonthTotals(
  year: 2026,
  month: month,
  income: income,
  expenses: expenses,
  keptRate: income > 0 ? (income - expenses) / income * 100 : null,
  cashChange: income - expenses,
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

  group('scrolling is not choosing', () {
    final List<MonthTotals> months = <MonthTotals>[
      _m(4, 30000, 41000),
      _m(5, 40000, 12000),
      _m(9, 51000, 25774.75),
    ];

    testWidgets('a scroll that starts on a month does not select it', (
      WidgetTester tester,
    ) async {
      // A page that really scrolls, with the chart in it, the way Reports
      // has it. fl_chart reports the finger landing before the page knows
      // it is a scroll, and selecting on that swapped the figures below for
      // whichever month the scroll happened to start on.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                SizedBox(
                  width: 360,
                  child: MonthlyInOutChart(palette: palette, months: months),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect chart = tester.getRect(find.byType(BarChart));
      await tester.dragFrom(
        Offset(chart.left + chart.width / 6, chart.bottom - 40),
        // Short enough that the card stays built, long enough to be a
        // scroll rather than a tap.
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      // DIRECTIONAL: the page really did scroll, or "nothing changed" would
      // pass just as well for a gesture that never happened.
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      expect(
        find.text('SEPTEMBER 2026'),
        findsOneWidget,
        reason: 'scrolling past the chart changed the selected month',
      );
    });

    testWidgets('it can open on another month', (WidgetTester tester) async {
      await _pump(
        tester,
        MonthlyInOutChart(palette: palette, months: months, initialIndex: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('MAY 2026'), findsOneWidget);
    });
  });

  group('net worth, month by month', () {
    NetWorthPoint p(int m, double a, double l) => NetWorthPoint(
      year: 2026,
      month: m,
      assets: Money.fromDouble(a),
      liabilities: Money.fromDouble(l),
    );

    testWidgets('a first month is one dot, and says so', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        NetWorthChart(
          palette: palette,
          points: <NetWorthPoint>[p(10, 20000, 5000)],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your first month here. A new point is added each month.'),
        findsOneWidget,
      );
      // No readout: it would repeat the Position headline word for word.
      expect(find.textContaining('What is really yours'), findsNothing);
    });

    testWidgets('opens on last month, and names a debt the headline way', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        NetWorthChart(
          palette: palette,
          points: <NetWorthPoint>[p(8, 200000, 460000), p(9, 250000, 463000)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('Still to pay off ₱260,000.00'), findsOneWidget);
      expect(
        find.text('You owned ₱200,000.00 and owed ₱460,000.00.'),
        findsOne,
      );
    });

    testWidgets('tapping a point selects that month', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        NetWorthChart(
          palette: palette,
          points: <NetWorthPoint>[p(7, 100, 0), p(8, 200, 0), p(9, 300, 0)],
        ),
      );
      await tester.pumpAndSettle();
      final Rect chart = tester.getRect(find.byType(LineChart));
      // The x range runs from -0.3 to 2.3, so July sits 0.3/2.6 across.
      await tester.tapAt(
        Offset(chart.left + chart.width * 0.3 / 2.6, chart.center.dy),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('JULY 2026'),
        findsOneWidget,
        reason: 'the tap did not select the month it landed on',
      );
    });
  });

  group('the unreadable date note', () {
    testWidgets('says the amount, so two figures can be reconciled', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UndatedNote(
          palette: palette,
          trends: TrendSet(
            months: <MonthTotals>[],
            pace: SpendingPace(
              thisMonth: <double>[],
              lastMonth: <double>[],
              daysInThisMonth: 30,
            ),
            undated: 2,
            undatedAmount: 1500,
          ),
        ),
      );
      expect(
        find.text(
          '2 entries with an unreadable date (₱1,500.00) are counted in the '
          'figures above but not in this chart.',
        ),
        findsOneWidget,
      );
    });
  });

  group('cash, month by month', () {
    final List<MonthTotals> months = <MonthTotals>[
      _m(6, 51000, 20000),
      // 30,000 into an investment: cash went DOWN though income beat
      // spending, which is why this reads cashChange and not in less out.
      MonthTotals(
        year: 2026,
        month: 7,
        income: 51000,
        expenses: 62000,
        keptRate: null,
        cashChange: -11000,
      ),
      _m(9, 51000, 25774.75),
    ];

    testWidgets('opens where it is told, and says which way cash went', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        MonthlyCashChart(palette: palette, months: months, initialIndex: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('JULY 2026'), findsOneWidget);
      expect(find.text('Your cash went down by ₱11,000.00'), findsOneWidget);
    });

    testWidgets('a tap selects, a scroll does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                SizedBox(
                  width: 360,
                  child: MonthlyCashChart(palette: palette, months: months),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect chart = tester.getRect(find.byType(BarChart));
      final Offset june = Offset(chart.left + chart.width / 6, chart.center.dy);

      await tester.dragFrom(june, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      expect(
        find.text('SEPTEMBER 2026'),
        findsOneWidget,
        reason: 'scrolling past the chart changed the selected month',
      );

      await tester.tapAt(
        Offset(
          chart.left + chart.width / 6,
          tester.getRect(find.byType(BarChart)).center.dy,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('JUNE 2026'), findsOneWidget);
      expect(find.text('Your cash grew by ₱31,000.00'), findsOneWidget);
    });
  });

  group('spending pace', () {
    testWidgets('the readout shows today, then the day you tap', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SpendingPaceChart(
          palette: palette,
          pace: SpendingPace(
            thisMonth: <double>[100, 200, 300, 400, 500],
            lastMonth: <double>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
            daysInThisMonth: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TODAY, DAY 5'), findsOneWidget);
      expect(find.text('This month ₱500.00'), findsOneWidget);

      // Day 8 of 10: past today, so this month has no figure yet.
      final Rect chart = tester.getRect(find.byType(LineChart));
      await tester.tapAt(
        Offset(chart.left + chart.width * 7 / 9, chart.top + 40),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('DAY 8'),
        findsOneWidget,
        reason: 'the tap did not move the readout',
      );
      expect(find.text('Last month ₱80.00'), findsOneWidget);
      expect(find.text('This month, not yet'), findsOneWidget);
    });

    testWidgets('says what is dated later and so not on the line', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        SpendingPaceChart(
          palette: palette,
          pace: SpendingPace(
            thisMonth: <double>[100, 200],
            lastMonth: <double>[300, 700],
            daysInThisMonth: 30,
            scheduledLater: 12000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('₱12,000.00 dated later this month is not on the line yet.'),
        findsOneWidget,
      );
    });
  });

  group('spending pace verdict', () {
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
