// SETTLE, the rolling peso figure. What it must never do matters more than
// what it does: show a number that is neither the old one nor the new one,
// animate on first paint, or move when the phone asks for less motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/settle_figure.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.reduce = false});

  final String initial;
  final bool reduce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String text = widget.initial;

  void set(String t) => setState(() => text = t);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduce),
      child: Scaffold(
        body: SettleFigure(text, style: const TextStyle(fontSize: 24)),
      ),
    ),
  );
}

/// Every character the figure is drawing at this instant, left to right,
/// taking in each column whichever glyph is more than half visible.
String _visible(WidgetTester tester) {
  final Finder row = find.descendant(
    of: find.byType(SettleFigure),
    matching: find.byType(Row),
  );
  if (row.evaluate().isEmpty) {
    return tester.widget<Text>(find.byType(Text)).data!;
  }
  final StringBuffer out = StringBuffer();
  for (final Widget child in tester.widget<Row>(row).children) {
    if (child is Text) {
      out.write(child.data);
      continue;
    }
    // A rolling column: two Opacity-wrapped glyphs; keep the more opaque.
    final List<Opacity> layers = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byWidget(child),
            matching: find.byType(Opacity),
          ),
        )
        .toList();
    layers.sort((Opacity a, Opacity b) => b.opacity.compareTo(a.opacity));
    out.write((layers.first.child! as Text).data!.trim());
  }
  return out.toString();
}

void main() {
  testWidgets('the first paint is the final figure, one plain Text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: '₱24,332.00'));
    expect(find.text('₱24,332.00'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SettleFigure),
        matching: find.byType(Row),
      ),
      findsNothing,
    );
  });

  testWidgets('only the digits that changed move', (WidgetTester tester) async {
    await tester.pumpWidget(const _Host(initial: '₱24,332.00'));
    tester.state<_HostState>(find.byType(_Host)).set('₱24,082.00');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final Row row = tester.widget<Row>(
      find.descendant(
        of: find.byType(SettleFigure),
        matching: find.byType(Row),
      ),
    );
    final int moving = row.children.where((Widget w) => w is! Text).length;
    expect(
      moving,
      2,
      reason: 'only "33" becomes "08"; nothing else should roll',
    );

    await tester.pumpAndSettle();
    expect(find.text('₱24,082.00'), findsOneWidget);
  });

  testWidgets('at no instant does it read as a third number', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: '₱1,999.00'));
    tester.state<_HostState>(find.byType(_Host)).set('₱2,000.00');
    await tester.pump();
    for (int ms = 0; ms <= 260; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      final String seen = _visible(tester);
      expect(
        seen == '₱1,999.00' || seen == '₱2,000.00',
        isTrue,
        reason: 'mid-roll the figure read as "$seen"',
      );
    }
  });

  testWidgets('with reduced motion it simply changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: '₱500.00', reduce: true));
    tester.state<_HostState>(find.byType(_Host)).set('₱750.00');
    await tester.pump();
    expect(find.text('₱750.00'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SettleFigure),
        matching: find.byType(Row),
      ),
      findsNothing,
    );
  });

  testWidgets('a screen reader hears the new figure once, mid-roll', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Host(initial: '₱500.00'));
    tester.state<_HostState>(find.byType(_Host)).set('₱750.00');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('₱750.00'), findsOneWidget);
    handle.dispose();
  });
}
