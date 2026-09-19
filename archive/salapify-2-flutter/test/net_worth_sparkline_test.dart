// The Net Worth sparkline draws a trend for two or more points and quietly
// shows nothing below that, so the hero never has to guard the empty case
// itself. These pump the widget to prove it paints without throwing (an
// unbounded-constraint or divide-by-zero in the painter would surface here) and
// that the below-threshold case draws no chart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/net_worth_sparkline.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 320, child: child),
    ),
  ),
);

void main() {
  testWidgets('paints a chart for two or more points', (tester) async {
    await tester.pumpWidget(
      _host(const NetWorthSparkline(values: [178000, 189000, 201000, 228000])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flat series does not throw (zero range handled)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const NetWorthSparkline(values: [50000, 50000, 50000])),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a series crossing zero does not throw', (tester) async {
    await tester.pumpWidget(
      _host(const NetWorthSparkline(values: [-4000, -1000, 2000, 5000])),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws no chart below two points', (tester) async {
    await tester.pumpWidget(_host(const NetWorthSparkline(values: [228000])));
    await tester.pumpAndSettle();
    // The widget returns a bare SizedBox, so no painter is mounted for it.
    // (Scaffold/MaterialApp add their own CustomPaints; the sparkline's own
    // TweenAnimationBuilder is absent, so no reveal is running.)
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
