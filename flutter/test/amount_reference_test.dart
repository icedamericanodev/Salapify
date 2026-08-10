// AmountRole.reference is the supporting money face: subordinate to a primary
// hero, card, metric or row amount beside it, but still money, so it keeps
// tabular figures, scale-down-never-truncate, and the one formatMoney pipeline.
//
// These tests pin the approved contract (15 / w600 / tabular / textSecondary,
// tint overridable) so a drift shows up as a red test rather than a quiet fork,
// and prove the widget behaviours a style test cannot: that a long figure
// scales down instead of clipping, a negative keeps its sign, the tint override
// wins, and 1.5x text does not overflow a tight slot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/amount_text.dart';

void main() {
  group('AmountRole.reference face', () {
    test('holds the approved 15 / w600 / tabular / textSecondary contract', () {
      final s = AppText.amountReference;
      expect(s.fontSize, TypeScale.body); // 15
      expect(s.fontWeight, TypeWeight.medium); // w600
      expect(s.fontFamily, Barako.bodyFont);
      expect(s.color, Barako.textSecondary);
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('styleFor maps the role to the amountReference face', () {
      expect(
        AmountText.styleFor(AmountRole.reference),
        AppText.amountReference,
      );
    });

    test('is subordinate to row: same size, one weight lighter', () {
      expect(AppText.amountReference.fontSize, AppText.amountRow.fontSize);
      expect(AppText.amountReference.fontWeight, TypeWeight.medium);
      expect(AppText.amountRow.fontWeight, TypeWeight.bold);
    });
  });

  group('AmountRole.reference widget behaviour', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      double textScale = 1.0,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the canonical formatMoney string', (tester) async {
      await pump(tester, AmountText(1234.5, role: AmountRole.reference));
      expect(find.text('₱1,234.50'), findsOneWidget);
    });

    testWidgets('preserves a negative sign', (tester) async {
      await pump(tester, AmountText(-2500, role: AmountRole.reference));
      expect(find.text('-₱2,500'), findsOneWidget);
    });

    testWidgets('defaults to secondary ink and honours a tint override', (
      tester,
    ) async {
      await pump(tester, AmountText(10, role: AmountRole.reference));
      expect(
        tester.widget<Text>(find.text('₱10')).style?.color,
        Barako.textSecondary,
      );

      await pump(
        tester,
        AmountText(10, role: AmountRole.reference, tint: Barako.text),
      );
      expect(tester.widget<Text>(find.text('₱10')).style?.color, Barako.text);
    });

    testWidgets('scales a long figure down instead of clipping', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(
          width: 90,
          child: AmountText(999999999.99, role: AmountRole.reference),
        ),
      );
      // No overflow, and the figure is not ellipsized: the whole string is
      // still present, just scaled to fit the 90px slot.
      expect(tester.takeException(), isNull);
      expect(find.text('₱999,999,999.99'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AmountText)).width,
        lessThanOrEqualTo(90.5),
      );
    });

    testWidgets('does not overflow at 1.5x text in a tight slot', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(
          width: 120,
          child: AmountText(1234567.89, role: AmountRole.reference),
        ),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
