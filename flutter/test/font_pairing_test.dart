// The f4.61 font pairing is a contract, so it gets guards.
//
// Founder direction (2026-08-22): the working money in a list or table reads in
// IBM Plex Sans (the ledger face), the display hero stays Jakarta, and masked
// card numbers and reference blocks read in IBM Plex Mono. These pin the parts
// a screenshot cannot: that the right roles carry the right face, that both new
// faces are actually bundled at the weights their styles ask for (a missing
// weight is a silent synthetic), and that the ledger face does not reintroduce
// the negative-peso-strikethrough bug that got Fraunces removed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/pan_mask_widget.dart';

import 'screens_shot.dart' show loadRealFonts;

Set<int> _shippedWeights(String pubspec, String family) {
  final block = RegExp(
    '- family: $family(.*?)(?=\n    - family:|\$)',
    dotAll: true,
  ).firstMatch(pubspec);
  expect(block, isNotNull, reason: 'no $family block in pubspec.yaml');
  return RegExp(
    r'weight:\s*(\d+)',
  ).allMatches(block!.group(1)!).map((m) => int.parse(m.group(1)!)).toSet();
}

void main() {
  group('the roles carry the faces the pairing promises', () {
    test('row and reference amounts are the ledger face', () {
      expect(AppText.amountRow.fontFamily, Barako.ledgerFont);
      expect(AppText.amountReference.fontFamily, Barako.ledgerFont);
    });

    test('the display and metric money stay on the display/body face', () {
      // The split is the whole point: heroes and metric tiles are NOT the
      // ledger face, so a big brand number never turns into a ledger figure.
      expect(AppText.amountHero.fontFamily, Barako.displayFont);
      expect(AppText.amount.fontFamily, Barako.displayFont);
      expect(AppText.amountMetric.fontFamily, Barako.bodyFont);
      expect(Barako.ledgerFont, isNot(Barako.displayFont));
    });
  });

  group('both new faces are bundled at the weights their styles use', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('the pubspec bundles the ledger and mono families', () {
      final families = RegExp(
        r'- family:\s*(\w+)',
      ).allMatches(pubspec).map((m) => m.group(1)).toSet();
      expect(families, contains(Barako.ledgerFont));
      expect(families, contains(Barako.monoFont));
    });

    test('the ledger face ships every weight the money rows ask for', () {
      final shipped = _shippedWeights(pubspec, Barako.ledgerFont);
      // amountRow is bold (700), amountReference medium (600). A weight with no
      // file behind it renders as a synthetic and the ledger goes soft.
      expect(shipped, contains(AppText.amountRow.fontWeight!.value));
      expect(shipped, contains(AppText.amountReference.fontWeight!.value));
    });

    test('the mono face ships the weights the PAN and reference blocks use', () {
      final shipped = _shippedWeights(pubspec, Barako.monoFont);
      // The PAN digits are w600; the diagnostics/reference blocks default 400.
      expect(shipped, contains(600));
      expect(shipped, contains(400));
    });
  });

  testWidgets('the masked card number is drawn in the mono face', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CardNumberMask(last4: '4291', revealed: true)),
        ),
      ),
    );
    final digits = tester.widget<Text>(find.text('4291'));
    expect(digits.style?.fontFamily, Barako.monoFont);
    expect(
      digits.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets(
    'a negative peso in the ledger face is not a glyph short of a strikethrough',
    (tester) async {
      // The Fraunces bug, measured against the REAL ledger face this time.
      // Fraunces drew a long peso crossbar that a minus sign ran into, so
      // "-₱720" read as a struck-through ₱720. With the real font loaded, the
      // negative must be meaningfully wider than the positive: if the minus
      // adds almost nothing it is sitting on the peso bar, not beside it.
      await loadRealFonts(tester);
      double widthOf(String s) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: Barako.ledgerFont,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return tp.width;
      }

      final gap = widthOf('-₱720') - widthOf('₱720');
      // A real minus glyph is a few points wide at 34px. Require a clear
      // margin, not just greater-than-zero, so a hairline artefact cannot pass.
      expect(
        gap,
        greaterThan(4),
        reason:
            'the minus adds almost no width in ${Barako.ledgerFont}, so it is '
            'drawn on the peso sign rather than before it',
      );
    },
  );
}
