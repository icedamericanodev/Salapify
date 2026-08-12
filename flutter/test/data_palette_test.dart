// The categorical "dopamine" data palette has to do two jobs a screenshot
// nobody opens could otherwise hide: every colour must be tellable apart from
// every other (two near-identical slices read as one), and each must be visible
// on the surface it is drawn on. Dark is the founder's primary mode and a
// near-black card, so the bar there is real (WCAG AA 3.0 for a graphical
// object). Light is a white card where a bright hue can sit at a low edge
// contrast; the donut and dots carry a hairline stroke for that case, and
// meaning never rides on colour alone (every slice has a printed label and
// amount beside it), so the light floor is a sanity bound, not the AA bar.
//
// Pure arithmetic over Barako.dataSeries, so it is fast and total.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';

double _luminance(int argb) {
  double channel(int c) {
    final s = c / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrast(Color a, Color b) {
  final la = _luminance(a.toARGB32());
  final lb = _luminance(b.toARGB32());
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The two primary-theme card colours the slices are drawn on.
  const darkCard = Color(0xFF1C1A17);
  const lightCard = Color(0xFFFFFFFF);

  test('there are enough distinct data colours for a category breakdown', () {
    expect(Barako.dataSeries.length, greaterThanOrEqualTo(5));
    final unique = Barako.dataSeries.map((c) => c.toARGB32()).toSet();
    expect(
      unique.length,
      Barako.dataSeries.length,
      reason: 'two data colours are the exact same value',
    );
  });

  double _rgbDistance(Color a, Color b) {
    final ai = a.toARGB32(), bi = b.toARGB32();
    final dr = ((ai >> 16) & 0xFF) - ((bi >> 16) & 0xFF);
    final dg = ((ai >> 8) & 0xFF) - ((bi >> 8) & 0xFF);
    final db = (ai & 0xFF) - (bi & 0xFF);
    return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
  }

  test('every pair of data colours is tellable apart', () {
    // Categorical colours must differ by HUE, not lightness, so luminance
    // contrast is the wrong tool (teal and green share a lightness but are
    // plainly different colours). Straight RGB distance is a fair proxy for
    // "two slices do not read as one colour"; near-duplicates land near 0, and
    // genuinely distinct hues clear 60 comfortably.
    final failures = <String>[];
    for (var i = 0; i < Barako.dataSeries.length; i++) {
      for (var j = i + 1; j < Barako.dataSeries.length; j++) {
        final d = _rgbDistance(Barako.dataSeries[i], Barako.dataSeries[j]);
        if (d < 60) {
          failures.add(
            'slice $i and $j are ${d.toStringAsFixed(0)} apart in RGB, too close',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every data colour is visible on the near-black dark card (AA 3.0)', () {
    final failures = <String>[];
    for (var i = 0; i < Barako.dataSeries.length; i++) {
      final r = _contrast(Barako.dataSeries[i], darkCard);
      if (r < 3.0) {
        failures.add('slice $i is ${r.toStringAsFixed(2)} to 1 on the dark card');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every data colour clears the light-card sanity floor', () {
    // Bright dopamine hues on white can fall under the 3.0 graphical bar, which
    // is why the widget strokes them; this only catches a colour so pale it
    // would vanish on white even with a hairline.
    final failures = <String>[];
    for (var i = 0; i < Barako.dataSeries.length; i++) {
      final r = _contrast(Barako.dataSeries[i], lightCard);
      if (r < 1.5) {
        failures.add('slice $i is ${r.toStringAsFixed(2)} to 1 on the light card');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
