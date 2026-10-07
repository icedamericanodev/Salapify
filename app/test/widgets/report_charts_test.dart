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

import '../shots/screens_shot.dart' show loadRealFonts;

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

    test(
      'a part below zero hides the bars rather than contradict the total',
      () {
        // The case a design review found: a new user who logged spending from a
        // zero opening balance. Cash -3,000, owed to you 5,000, owed 4,000. The
        // headline says "Still to pay off 2,000", but a bar can only draw the
        // positive parts, so the own bar would draw 5,000 and outrun the owe
        // bar of 4,000: the picture says the opposite of the figure above it.
        // Scale 0 hides both bars and their dots; the rows still print every
        // signed figure.
        final FinancialPosition p = computePosition(<Account>[
          _account('w', AccountKind.cash, const Money.pesos(-3000)),
          _account('r', AccountKind.receivable, const Money.pesos(5000)),
          _account('c', AccountKind.credit, const Money.pesos(4000)),
        ], null);
        expect(p.netWorth, const Money.pesos(-2000));
        final bars = positionSegments(palette, p);
        expect(
          bars.scale,
          0,
          reason:
              'the bars would show owning more than owing, under a headline '
              'that says the reverse',
        );
        // DIRECTIONAL: the parts are still all there for the rows to print.
        expect(bars.own.map((ChartSegment s) => s.value), contains(-3000));
      },
    );

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

    testWidgets('a label stays whole at 320dp and the largest system text', (
      WidgetTester tester,
    ) async {
      // MEASURED IN THE SHIPPED FONT, because the default test font is wider
      // than Plus Jakarta Sans and would judge a layout the phone never
      // draws. The label used to sit in an Expanded beside a figure that
      // cannot shrink, and at 2.0x it was squeezed to a letter per line.
      await tester.runAsync(loadRealFonts);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PlusJakartaSans'),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: CashFlowChart(
                  palette: palette,
                  cashFlow: _flow(op: 12345678.90, fin: -6450),
                ),
              ),
            ),
          ),
        ),
      );
      final Size word = tester.getSize(find.text('Operating'));
      final double oneLine = tester.getSize(find.text('Investing')).height;
      expect(
        word.height,
        lessThanOrEqualTo(oneLine * 1.01),
        reason: 'the label broke onto more than one line',
      );
      // And really one line, not two equally squeezed labels.
      expect(word.width, greaterThan(word.height * 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a period with no cash movement draws no chart', (
      WidgetTester tester,
    ) async {
      await _pump(tester, CashFlowChart(palette: palette, cashFlow: _flow()));
      expect(find.byType(BarChart), findsNothing);
    });
  });
}
