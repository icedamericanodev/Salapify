// The Reports charts: what they draw, on what scale, and when they stay away.
//
// The money in these charts is all computed elsewhere and tested there. What
// can go wrong HERE is the drawing: two bars on different scales, a bar that
// runs off its own end, a chart that appears over a period with nothing in it,
// or a figure that loses its sign on the way to the screen.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/reports/report_charts.dart';

Account _account(String id, AccountKind kind, Money balance) => Account(
  id: id,
  name: id,
  kind: kind,
  institution: 'Test',
  balance: balance,
  monogram: 'T',
);

CashFlow _flow({double op = 0, double inv = 0, double fin = 0}) => CashFlow(
  operatingInflows: 0,
  operatingOutflows: 0,
  netOperating: op,
  investingInflows: 0,
  investingOutflows: 0,
  netInvesting: inv,
  financingInflows: 0,
  financingOutflows: 0,
  netFinancing: fin,
  transfersCount: 0,
  transfersVolume: 0,
  netCashChange: op + inv + fin,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  const Palette palette = Palette.gabi;

  group('Position, one scale for both bars', () {
    test('the scale is the longer of the two bars', () {
      // 12,000 owned against 460,000 owed. On separate scales both bars
      // would be full length, which is the one thing this chart exists to
      // prevent.
      final FinancialPosition p = computePosition(<Account>[
        _account('w', AccountKind.cash, const Money.pesos(12000)),
        _account('m', AccountKind.mortgage, const Money.pesos(460000)),
      ], null);
      final bars = positionSegments(palette, p);
      expect(bars.scale, 460000);
    });

    test('a part below zero cannot push the bar off its own end', () {
      // A WHOLE PART below zero, not one account: an overdrawn wallet is
      // netted against the bank inside "Cash and e-wallets" and never reaches
      // here. An investment account entered at a loss does. Owned parts are
      // then 10,000 cash and -1,500 investments, the total is 8,500, and the
      // bar DRAWS 10,000, because a negative part has no length. A scale
      // taken from the total would be shorter than the bar it holds.
      final FinancialPosition p = computePosition(<Account>[
        _account('b', AccountKind.bank, const Money.pesos(10000)),
        _account('i', AccountKind.investment, const Money.pesos(-1500)),
      ], null);
      expect(p.totalAssets, const Money.pesos(8500));
      final bars = positionSegments(palette, p);
      expect(
        bars.scale,
        10000,
        reason: 'the scale must hold everything the bar draws',
      );
    });

    test('a home is its own part of what you own', () {
      final FinancialPosition p = computePosition(<Account>[
        _account('h', AccountKind.property, const Money.pesos(2000000)),
      ], null);
      final bars = positionSegments(palette, p);
      final ChartSegment home = bars.own.singleWhere(
        (ChartSegment s) => s.label == 'Property',
      );
      expect(home.value, 2000000);
    });
  });

  group('Performance, in against out', () {
    testWidgets('both figures are printed, on one scale', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InOutChart(palette: palette, moneyIn: 51000, moneyOut: 25774.75),
      );
      expect(find.text('₱51,000.00'), findsOneWidget);
      expect(find.text('₱25,774.75'), findsOneWidget);

      final List<BarChart> charts = tester
          .widgetList<BarChart>(find.byType(BarChart))
          .toList();
      expect(charts, hasLength(2));
      expect(charts.map((BarChart c) => c.data.maxY).toSet(), <double>{
        51000,
      }, reason: 'the two bars must share one scale to be compared by length');
    });
  });

  group('Cash flow, from one zero line', () {
    testWidgets('a negative section keeps its minus sign', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        CashFlowChart(
          palette: palette,
          cashFlow: _flow(op: 31675.25, fin: -6450),
        ),
      );
      expect(find.text('-₱6,450.00'), findsOneWidget);
      expect(find.text('₱31,675.25'), findsOneWidget);

      // Symmetric around zero and the same on every row, so the zero line
      // sits in one place down the card.
      final Set<(double, double)> ranges = tester
          .widgetList<BarChart>(find.byType(BarChart))
          .map((BarChart c) => (c.data.minY, c.data.maxY))
          .toSet();
      expect(ranges, <(double, double)>{(-31675.25, 31675.25)});
    });

    testWidgets('a period with no cash movement draws no chart', (
      WidgetTester tester,
    ) async {
      await _pump(tester, CashFlowChart(palette: palette, cashFlow: _flow()));
      expect(find.byType(BarChart), findsNothing);
    });
  });
}
