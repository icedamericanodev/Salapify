// CardNumberMask: the steady masked number line. The point of the widget is
// that it cannot jitter and cannot leak, so that is what these prove: the last
// four show only when revealed AND valid, everything in front is always dots,
// and a null or malformed value never renders a digit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mask_widget.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

// A dot is a Container with a circular BoxDecoration, which is all the mask
// draws besides the optional digit Text.
int _dotCount(WidgetTester t) =>
    t.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle;
    }).length;

Finder _fourDigits() => find.byWidgetPredicate(
  (w) => w is Text && w.data != null && RegExp(r'^\d{4}$').hasMatch(w.data!),
);

void main() {
  setUp(() {
    Barako.currentTheme = barakoThemes.first;
    Barako.current = barakoThemes.first.dark;
  });

  testWidgets('masked by default: no digits, all dots', (tester) async {
    await tester.pumpWidget(
      _host(const CardNumberMask(last4: '4821', groups: 3)),
    );
    expect(_fourDigits(), findsNothing);
    // Three leading groups plus the last four slot, all dots: sixteen dots.
    expect(_dotCount(tester), 16);
  });

  testWidgets('revealed with a valid last four shows exactly those four', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const CardNumberMask(last4: '4821', revealed: true, groups: 3)),
    );
    expect(find.text('4821'), findsOneWidget);
    // The three masked groups remain dots; only the last group became digits.
    expect(_dotCount(tester), 12);
  });

  testWidgets('a malformed value is treated as no number, never shown raw', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const CardNumberMask(last4: '12', revealed: true, groups: 3)),
    );
    // Not four digits, so it stays masked even when revealed.
    expect(find.text('12'), findsNothing);
    expect(_fourDigits(), findsNothing);
    expect(_dotCount(tester), 16);
  });

  testWidgets('a null number renders dots and no digit run', (tester) async {
    await tester.pumpWidget(
      _host(const CardNumberMask(last4: null, revealed: true, groups: 1)),
    );
    expect(_fourDigits(), findsNothing);
    // One leading group plus the last four slot: eight dots.
    expect(_dotCount(tester), 8);
  });

  testWidgets('groups: 0 draws only the last four slot', (tester) async {
    await tester.pumpWidget(
      _host(const CardNumberMask(last4: null, groups: 0)),
    );
    expect(_dotCount(tester), 4);
  });
}
