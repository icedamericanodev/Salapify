// The Road Ahead sparkline can no longer degenerate into a flat block.
//
// P0-2 in the 2026-08-07 design audit: the painter scaled its y-axis to the
// data's raw min and max, so a steady week (the healthiest state a user can
// be in) drew a line riding the card's top edge over one solid rectangle of
// fill. The most prominent visual on Home read as a rendering bug precisely
// when nothing was wrong. These tests pin the domain math that fixes it:
// the ceiling always sits a nice step ABOVE the peak, and zero stays inside
// the frame so the baseline can ground the shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/timeline_sparkline.dart';

void main() {
  test('a steady balance never rides the top edge', () {
    // Fourteen days of 20,000, the exact degenerate case from the audit's
    // overview-dark.png: low variance, comfortably positive.
    final (lo, hi) = sparkDomain(List.filled(14, 20000.0));
    expect(lo, 0);
    expect(
      hi,
      greaterThanOrEqualTo(20000 * 1.15),
      reason:
          'The ceiling must clear the peak with headroom, or the line '
          'draws at the frame edge and the fill below it is one block.',
    );
    // Where the line actually lands, normalized: 0 is the top edge.
    final t = (hi - 20000) / (hi - lo);
    expect(
      t,
      greaterThan(0.1),
      reason: 'The peak must sit visibly inside the frame, not on its edge.',
    );
  });

  test('a peak exactly on a nice number still gets a ceiling above it', () {
    final (_, hi) = sparkDomain([10000.0, 25000.0, 25000.0]);
    expect(hi, greaterThan(25000));
  });

  test('a negative dip keeps both the dip and zero inside the domain', () {
    final (lo, hi) = sparkDomain([1500.0, -800.0, 200.0]);
    expect(lo, lessThanOrEqualTo(-800));
    expect(hi, greaterThan(1500));
  });

  test('an all-zero window still spans a drawable range', () {
    final (lo, hi) = sparkDomain(List.filled(5, 0.0));
    expect(hi, greaterThan(lo), reason: 'A zero span divides by zero.');
  });

  test('a window that never goes positive keeps zero off the top edge', () {
    final (lo, hi) = sparkDomain([-2000.0, -3500.0, -1000.0]);
    expect(lo, lessThanOrEqualTo(-3500));
    expect(hi, greaterThan(0), reason: 'Zero needs air above it to be seen.');
  });
}
