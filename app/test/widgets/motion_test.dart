// The shared motion helpers: a bar that grows on change, the sliding
// segmented thumb, and reduced motion winning everywhere.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/motion.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/shared/sheet_scaffold.dart';

class _BarHost extends StatefulWidget {
  const _BarHost({this.reduce = false});

  final bool reduce;

  @override
  State<_BarHost> createState() => _BarHostState();
}

class _BarHostState extends State<_BarHost> {
  double value = 0.2;

  void set(double v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduce),
      child: Scaffold(
        body: GrowTo(
          value: value,
          builder: (double v) => LinearProgressIndicator(value: v),
        ),
      ),
    ),
  );
}

double _bar(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  group('a bar grows to its new value', () {
    testWidgets('first paint is the value itself, no grow-in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _BarHost());
      expect(_bar(tester), 0.2);
    });

    testWidgets('a change moves through the values between', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _BarHost());
      tester.state<_BarHostState>(find.byType(_BarHost)).set(0.8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final double mid = _bar(tester);
      expect(mid, greaterThan(0.2));
      expect(mid, lessThan(0.8), reason: 'the bar snapped instead of growing');
      await tester.pumpAndSettle();
      expect(_bar(tester), 0.8);
    });

    testWidgets('reduced motion jumps straight there', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _BarHost(reduce: true));
      tester.state<_BarHostState>(find.byType(_BarHost)).set(0.8);
      await tester.pump();
      expect(_bar(tester), 0.8);
    });
  });

  testWidgets('the segmented thumb slides to the chosen option', (
    WidgetTester tester,
  ) async {
    String chosen = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter set) =>
                SegmentedChoice<String>(
                  palette: Palette.gabi,
                  options: const <(String, String)>[
                    ('a', 'All'),
                    ('b', 'In'),
                    ('c', 'Out'),
                  ],
                  selected: chosen,
                  onSelect: (String v) => set(() => chosen = v),
                ),
          ),
        ),
      ),
    );
    Alignment thumb() =>
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
            as Alignment;
    expect(thumb().x, -1);

    await tester.tap(find.text('Out'));
    await tester.pumpAndSettle();
    expect(chosen, 'c');
    expect(thumb().x, 1, reason: 'the thumb did not move to the chosen option');
  });
}
