// BankCard: the three variants the founder actually sees, plus the promise the
// card makes about contrast (white text stays readable on every bank color).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/debtmath.dart' show formatMoneyText;
import 'package:salapify/money/institutions.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/pan_mask_widget.dart' show CardNumberMask;

import 'screens_shot.dart' show loadRealFonts;

// The width the carousel gives a card on a normal phone. Measuring layout in
// the shipped font (Plus Jakarta Sans, narrower and shorter than the default
// test font) is the repo rule: the default font would overflow a card that
// fits fine on the phone.
Widget _host(Widget card) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 340, child: card)),
  ),
);

LinearProgressIndicator? _bar(WidgetTester t) {
  final found = t.widgetList<LinearProgressIndicator>(
    find.byType(LinearProgressIndicator),
  );
  return found.isEmpty ? null : found.first;
}

void main() {
  setUp(() {
    // A fixed palette so Barako.warning is deterministic in the credit tests.
    Barako.currentTheme = barakoThemes.first;
    Barako.current = barakoThemes.first.dark;
  });

  testWidgets('savings variant shows the balance and no utilization bar', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'BPI Savings',
          accountType: 'Savings',
          brandColor: institutionBrandColor('bpi'),
          last4: '1234',
          balance: 48500.55,
        ),
      ),
    );

    expect(find.text('BPI Savings'), findsOneWidget);
    expect(find.text('SAVINGS'), findsOneWidget);
    // The number line is the geometric mask now, not a bullet string: the
    // stored last four show as their own tabular digits, the rest as dots.
    expect(find.byType(CardNumberMask), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text(formatMoneyText(48500.55)), findsOneWidget);
    // Savings is just the balance: no bar.
    expect(_bar(tester), isNull);
  });

  testWidgets('credit variant shows outstanding, limit, and a warning bar '
      'when utilization is above 70 percent', (tester) async {
    await loadRealFonts(tester);
    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          brandColor: institutionBrandColor('bpi'),
          last4: '9012',
          balance: 42000,
          creditLimit: 50000,
          variant: BankCardVariant.credit,
        ),
      ),
    );

    expect(find.text('CREDIT'), findsOneWidget);
    expect(find.text(formatMoneyText(42000)), findsOneWidget);
    expect(find.text('of ${formatMoneyText(50000)}'), findsOneWidget);

    final bar = _bar(tester);
    expect(bar, isNotNull);
    // 42000 / 50000 = 0.84, above 0.70.
    expect(bar!.value, closeTo(0.84, 0.001));
    expect(bar.color, Barako.warning);
  });

  testWidgets('credit variant below 70 percent uses white, not warning', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          brandColor: institutionBrandColor('bpi'),
          last4: '9012',
          balance: 25000,
          creditLimit: 50000,
          variant: BankCardVariant.credit,
        ),
      ),
    );

    final bar = _bar(tester);
    expect(bar, isNotNull);
    expect(bar!.value, closeTo(0.50, 0.001));
    // Silent when it should be: the bar must not warn at half full.
    expect(bar.color, Colors.white);
    expect(bar.color, isNot(Barako.warning));
  });

  testWidgets(
    'no stored card number falls back to masked dots with no digits',
    (tester) async {
      await loadRealFonts(tester);
      await tester.pumpWidget(
        _host(
          BankCard(
            bankName: 'Cash',
            accountType: 'Cash',
            brandColor: null,
            last4: null,
            balance: 2340,
          ),
        ),
      );

      // No stored number: the mask is present but shows only dots, no digit
      // run at all. The mask widget's own test proves null renders dots; here
      // we prove the card draws the mask and no bare four digit text leaks.
      expect(find.byType(CardNumberMask), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) {
          return w is Text &&
              w.data != null &&
              RegExp(r'^\d{4}$').hasMatch(w.data!);
        }),
        findsNothing,
      );
    },
  );

  test('white text clears WCAG AA on every bank gradient, light and dark stop', () {
    // The lightest point of a card is the first gradient stop, the darkest is
    // the second. Both must clear 4.5:1 against white, for every brand color in
    // the catalog and for the neutral fallback.
    final colors = <Color?>[
      null, // the neutral fallback
      for (final i in institutions)
        if (i.brandColor != null) i.brandColor,
    ];
    for (final base in colors) {
      final g = bankCardGradient(base);
      for (final stop in g) {
        expect(
          whiteContrastOf(stop),
          greaterThanOrEqualTo(4.5),
          reason:
              'White text on $stop measured ${whiteContrastOf(stop).toStringAsFixed(2)}, '
              'below the 4.5:1 AA bar. Base was $base.',
        );
      }
    }
  });
}
