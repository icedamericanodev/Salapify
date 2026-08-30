// The f4.72 design-system lift, guarded.
//
// Three presentation primitives, each with a way to regress silently:
//   - SectionTitle must stay a DISTINCT tier above the card kicker, or the
//     page bands melt back into the quiet kicker they were promoted out of.
//   - SalapifyCard must apply the one card decoration and the one kicker gap,
//     or a card that adopts it drifts back to a hand-rolled Container.
//   - The money heroes must roll up when visible and stay plain (no roll) when
//     masked, or the privacy eye ends up animating dots.
// A picture proves none of these; these deterministic tests do.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/count_up_text.dart';
import 'package:salapify/widgets/safe_to_spend_card.dart';
import 'package:salapify/widgets/salapify_card.dart';
import 'package:salapify/widgets/section.dart';

Widget _host(Widget child) {
  Barako.currentTheme = themeForKey('palawan');
  Barako.current = themeForKey('palawan').resolve(Brightness.dark);
  return MaterialApp(
    theme: salapifyTheme(Barako.current),
    home: Scaffold(backgroundColor: Barako.background, body: child),
  );
}

Map<String, dynamic> _buffer({double buffer = 18700}) => {
  'liquid': 38000.0,
  'cardDue': 7300.0,
  'billsDue': 12000.0,
  'committed': 19300.0,
  'buffer': buffer,
  'dueCount': 4,
  'minsUnset': 0,
  'windowDays': 14,
};

void main() {
  testWidgets('SectionTitle is a heavier, distinct tier above the card kicker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(SectionTitle('DO NEXT')));
    final style = tester.widget<Text>(find.text('DO NEXT')).style!;

    // Heavy weight is what sets a page band apart from the medium card kicker.
    expect(style.fontWeight, TypeWeight.heavy);
    // And it must actually differ from the kicker, not just happen to look it.
    expect(style.fontWeight, isNot(Barako.kickerStyle.fontWeight));
    expect(style.fontSize, greaterThan(Barako.kickerStyle.fontSize!));
    // Full ink, not the muted kicker colour.
    expect(style.color, Barako.text);
    expect(style.color, isNot(Barako.kickerStyle.color));
  });

  testWidgets(
    'SalapifyCard applies the one card decoration and one kicker gap',
    (tester) async {
      await tester.pumpWidget(
        _host(SalapifyCard(kicker: 'SUMMARY', child: const Text('body'))),
      );

      // The kicker and the body both render.
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);

      // The card decoration: card fill, card radius, a border. Found on the
      // DecoratedBox the primitive builds (scoped under the SalapifyCard so a
      // MaterialApp ancestor DecoratedBox cannot answer for it).
      final decoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SalapifyCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == Barako.card);
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(Radii.card));

      // Exactly one standard gap (Gap.sm) sits between the kicker and the body.
      final gap = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(SalapifyCard),
          matching: find.byType(SizedBox),
        ),
      );
      expect(gap.height, Gap.sm);
    },
  );

  testWidgets('SalapifyCard onTap makes the whole card tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SalapifyCard(onTap: () => taps++, child: const Text('tap me'))),
    );
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('the safe-to-spend figure rolls up when visible', (tester) async {
    await tester.pumpWidget(
      _host(
        SafeToSpendCard(
          view: SafeToSpendView.buffer,
          onView: (_) {},
          buffer: _buffer(),
          netWorth: 228545,
          money: (v) => 'P${v.toStringAsFixed(0)}',
          hideBalances: false,
          onOpenTrend: () {},
        ),
      ),
    );
    // Frame zero: the roll starts at zero, so the destination figure is NOT on
    // screen yet. This is what makes the test bite if the roll ever degrades to
    // a static value, which would show P18700 immediately here.
    await tester.pump();
    expect(find.byType(CountUpText), findsWidgets);
    expect(find.text('P18700'), findsNothing);
    // After it settles the destination figure is shown.
    await tester.pumpAndSettle();
    expect(find.text('P18700'), findsOneWidget);
  });

  testWidgets(
    'CountUpText honors reduce-motion: no roll, figure shown at once',
    (tester) async {
      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CountUpText(
              value: 1000,
              format: (v) => 'P${v.toStringAsFixed(0)}',
            ),
          ),
        ),
      );
      // Frame zero, no settle: with reduce-motion on, the destination figure is
      // already there instead of rolling from zero.
      await tester.pump();
      expect(find.text('P1000'), findsOneWidget);
    },
  );

  testWidgets('CountUpText does not roll a negative figure up from zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CountUpText(value: -500, format: (v) => 'P${v.toStringAsFixed(0)}'),
      ),
    );
    // Frame zero: a negative figure is shown at its true value immediately, so
    // a red shortfall never animates up from an innocent-looking near-zero.
    await tester.pump();
    expect(find.text('P-500'), findsOneWidget);
  });

  testWidgets('the safe-to-spend figure does NOT roll when masked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SafeToSpendCard(
          view: SafeToSpendView.buffer,
          onView: (_) {},
          buffer: _buffer(),
          netWorth: 228545,
          money: (v) => '••••',
          hideBalances: true,
          onOpenTrend: () {},
        ),
      ),
    );
    await tester.pump();
    // A masked figure is dots, which cannot roll: no CountUpText at all.
    expect(find.byType(CountUpText), findsNothing);
    expect(find.text('••••'), findsWidgets);
  });
}
