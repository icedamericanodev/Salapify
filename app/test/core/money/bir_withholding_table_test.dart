import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ph_tax.dart';

/// P1.6: the monthly withholding function matches the PUBLISHED BIR table.
///
/// Source: BIR Annex E of RR 11-2018, effective 1 January 2023 and still in
/// force. Every figure below was worked out from the printed brackets by hand
/// and then compared against what the function returns, so this file is an
/// independent statement of the table rather than a recording of the code.
///
/// ## Why it exists separately from ph_tax_golden_test.dart
///
/// Those vectors run the whole employee calculation, so a withholding figure
/// in them is tangled with SSS, PhilHealth and Pag-IBIG. When the table moved,
/// seven of them moved with it and there was no single place that said what
/// the table itself is. This is that place.
///
/// ## What the October review got half right
///
/// It reported the three constants as typos: 8,541.67 where the table says
/// 8,541.80. They were not typos, and changing only them would have made the
/// function WRONG.
///
/// The old constants were coherent with the old bracket EDGES, which were the
/// prototype's decimals: 1,875 + (66,666.67 - 33,333.33) x 0.20 is 8,541.67
/// exactly. The published 8,541.80 is what the table's own integer edges give:
/// 1,875 + (66,667 - 33,333) x 0.20. Mixing a .80 constant with a .67 edge
/// double counts a sliver of a bracket. Both had to move together.
void main() {
  // The brackets as printed, so a reader can check this file against the PDF
  // without reading any Dart:
  //
  //     up to 20,833            nil
  //     20,833 to 33,332        15% of the excess over 20,833
  //     33,333 to 66,666        1,875.00 + 20% of the excess over 33,333
  //     66,667 to 166,666       8,541.80 + 25% of the excess over 66,667
  //     166,667 to 666,666     33,541.80 + 30% of the excess over 166,667
  //     666,667 and over      183,541.80 + 35% of the excess over 666,667
  const double eps = 1e-9;

  group('the exempt band', () {
    test('nothing is withheld at or below 20,833', () {
      expect(monthlyWithholdingTax(0), 0);
      expect(monthlyWithholdingTax(20000), 0);
      expect(monthlyWithholdingTax(20833), 0);
    });
  });

  group('each bracket, at its floor and one step in', () {
    // At a floor the fixed constant is the whole answer, with no excess, so
    // these four assertions are the three published constants stated plainly.
    test('15% band', () {
      expect(monthlyWithholdingTax(20834), closeTo(0.15, eps));
      // 1,000 into the band: 1,000 x 15%.
      expect(monthlyWithholdingTax(21833), closeTo(150, eps));
    });

    test('20% band starts at 1,875.00', () {
      expect(monthlyWithholdingTax(33333), closeTo(1875.00, eps));
      // 10,000 in: 1,875 + 2,000.
      expect(monthlyWithholdingTax(43333), closeTo(3875.00, eps));
    });

    test('25% band starts at 8,541.80', () {
      expect(monthlyWithholdingTax(66667), closeTo(8541.80, eps));
      // 10,000 in: 8,541.80 + 2,500.
      expect(monthlyWithholdingTax(76667), closeTo(11041.80, eps));
    });

    test('30% band starts at 33,541.80', () {
      expect(monthlyWithholdingTax(166667), closeTo(33541.80, eps));
      // 10,000 in: 33,541.80 + 3,000.
      expect(monthlyWithholdingTax(176667), closeTo(36541.80, eps));
    });

    test('35% band starts at 183,541.80', () {
      expect(monthlyWithholdingTax(666667), closeTo(183541.80, eps));
      // 10,000 in: 183,541.80 + 3,500.
      expect(monthlyWithholdingTax(676667), closeTo(187041.80, eps));
    });
  });

  group('the table is coherent across its own joins', () {
    // The property the old mixed convention broke. Each constant must equal
    // what the bracket BELOW it charges at its ceiling, or the tax jumps or
    // dips by a few centavos for somebody who earned one peso more.
    test('each constant is what the band below ends at', () {
      expect(
        1875.00 + (66667 - 33333) * 0.20,
        closeTo(8541.80, eps),
        reason: 'the 25% constant does not continue the 20% band',
      );
      expect(
        8541.80 + (166667 - 66667) * 0.25,
        closeTo(33541.80, eps),
        reason: 'the 30% constant does not continue the 25% band',
      );
      expect(
        33541.80 + (666667 - 166667) * 0.30,
        closeTo(183541.80, eps),
        reason: 'the 35% constant does not continue the 30% band',
      );
    });

    test('and the function never jumps at a boundary', () {
      for (final int edge in <int>[33333, 66667, 166667, 666667]) {
        final double below = monthlyWithholdingTax(edge - 1);
        final double at = monthlyWithholdingTax(edge.toDouble());
        expect(
          at - below,
          lessThan(1),
          reason: 'the tax leaps at $edge, so one peso of salary costs a lot',
        );
        expect(at, greaterThanOrEqualTo(below));
      }
    });
  });
}
