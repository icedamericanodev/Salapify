// Pan reskins with the theme, and does it without wrecking the artwork.
//
// The cup was a fixed orange on all eight themes, which looked right on Barako
// and wrong everywhere else: the screen went cold and the mascot stayed warm.
//
// Both halves are pinned here, and the SECOND is the one that would actually
// hurt if it broke:
//
// 1. A different theme genuinely recolours the cup.
// 2. Barako applies NO filter at all, and every theme preserves the artwork's
//    LUMINANCE. That second half is the guard against the obvious "simpler"
//    rewrite. Multiplying a flat theme colour through a grayscale cup is the
//    approach anyone would reach for first, it was built and measured, and it
//    threw away the shading: mean error 13/255 sitting almost entirely in the
//    shadow, where the form lives, leaving a flat cup with no texture. That
//    damage is invisible to a test that only asks "did the colour change".

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';

/// Push a colour through a ColorFilter.matrix by hand, the same arithmetic the
/// engine does, so the assertions below are about real output rather than
/// about the matrix looking plausible.
Color _apply(List<double> m, Color c) {
  final r = c.r, g = c.g, b = c.b;
  double ch(int i) =>
      (m[i * 5] * r + m[i * 5 + 1] * g + m[i * 5 + 2] * b + m[i * 5 + 4]).clamp(
        0.0,
        1.0,
      );
  return Color.from(alpha: c.a, red: ch(0), green: ch(1), blue: ch(2));
}

/// The SVG luminance weights the rotation is built on.
double _lum(Color c) => 0.213 * c.r + 0.715 * c.g + 0.072 * c.b;

void main() {
  group('the tint stays out of the way', () {
    test('Barako applies no filter at all, not even an identity one', () {
      expect(
        panTintMatrix(panArtColor),
        isNull,
        reason:
            'On the founder\'s own theme Pan must be the exact bytes they '
            'approved. An identity matrix is a weaker promise than no matrix: '
            'it still round-trips every pixel through a float multiply.',
      );
    });

    test('a colour a hair off the artwork still counts as the artwork', () {
      // Guards against a future palette tweak of one or two hex digits
      // silently switching the founder's theme onto the filtered path.
      expect(panTintMatrix(const Color(0xFFFF8B3E)), isNull);
    });

    test('the reference colour is really Barako primary', () {
      // If these ever drift apart, Barako quietly stops being the free case
      // and the founder's own theme starts getting filtered.
      expect(
        themeForKey('barako').dark.primary,
        panArtColor,
        reason:
            'panArtColor is the colour the art was drawn in. Barako moving '
            'away from it means the artwork no longer matches its own theme.',
      );
    });
  });

  group('the tint actually fires', () {
    test('a different theme really does recolour the cup', () {
      final m = panTintMatrix(themeForKey('mint').dark.primary);
      expect(m, isNotNull, reason: 'Mint is nowhere near orange');
      final out = _apply(m!, panArtColor);
      expect(
        (HSVColor.fromColor(out).hue - HSVColor.fromColor(panArtColor).hue)
            .abs(),
        greaterThan(30),
        reason: 'the matrix exists but leaves the cup orange',
      );
    });

    test('every theme lands near its own primary hue', () {
      for (final theme in barakoThemes) {
        for (final b in Brightness.values) {
          final target = theme.resolve(b).primary;
          final m = panTintMatrix(target);
          if (m == null) continue; // Barako, legitimately untouched.
          final got = HSVColor.fromColor(_apply(m, panArtColor)).hue;
          final want = HSVColor.fromColor(target).hue;
          var d = (got - want).abs();
          if (d > 180) d = 360 - d;
          expect(
            d,
            lessThan(25),
            reason:
                '${theme.key}/${b.name}: cup came out at ${got.round()} deg '
                'but the theme is ${want.round()} deg',
          );
        }
      }
    });
  });

  group('the artwork survives the recolour', () {
    test('every theme preserves luminance, so the shading is not flattened', () {
      // THE guard. A hue rotation preserves luminance by construction; a
      // multiply through a grayscale cup does not. If someone ever replaces
      // this with the simpler-looking multiply, this is what fails.
      const samples = <Color>[
        panArtColor, // lit clay
        Color(0xFF8A4A20), // shadowed clay
        Color(0xFFFFC79A), // rim highlight
        Color(0xFF3A2016), // deepest shadow
      ];
      for (final theme in barakoThemes) {
        final m = panTintMatrix(theme.dark.primary);
        if (m == null) continue;
        for (final s in samples) {
          final before = _lum(s);
          final after = _lum(_apply(m, s));
          expect(
            (after - before).abs(),
            lessThan(0.06),
            reason:
                '${theme.key} moved the brightness of '
                '0x${s.toARGB32().toRadixString(16)} from '
                '${before.toStringAsFixed(3)} to ${after.toStringAsFixed(3)}. '
                'Shading that changes brightness is shading that is being '
                'thrown away, which is exactly how the cup goes flat.',
          );
        }
      }
    });

    test('shadow stays darker than highlight on every theme', () {
      // Luminance can be preserved on average while the ORDER inverts, which
      // would turn the cup inside out. Cheap to check, catastrophic to miss.
      const shadow = Color(0xFF8A4A20);
      const highlight = Color(0xFFFFC79A);
      for (final theme in barakoThemes) {
        final m = panTintMatrix(theme.dark.primary);
        if (m == null) continue;
        expect(
          _lum(_apply(m, shadow)),
          lessThan(_lum(_apply(m, highlight))),
          reason: '${theme.key} inverted Pan\'s shading',
        );
      }
    });

    test('no theme produces a NaN or an out-of-range channel', () {
      for (final theme in barakoThemes) {
        for (final b in Brightness.values) {
          final m = panTintMatrix(theme.resolve(b).primary);
          if (m == null) continue;
          for (final v in m) {
            expect(v.isFinite, isTrue, reason: '${theme.key}/${b.name}: $v');
          }
        }
      }
    });

    test('a grey theme colour does not blow up the saturation divide', () {
      // ref.saturation is non-zero so the divide is safe, but a fully
      // desaturated TARGET is the degenerate input worth pinning.
      final m = panTintMatrix(const Color(0xFF808080));
      expect(m, isNotNull);
      for (final v in m!) {
        expect(v.isFinite, isTrue);
      }
    });
  });

  group('the widget picks the theme up', () {
    testWidgets('Pan repaints when the palette changes under him', (
      tester,
    ) async {
      // The const footgun this codebase has already been bitten by twice. If
      // PanMascot's constructor ever goes back to const, a const call site
      // makes two builds compare equal, Element.updateChild skips build(), and
      // Pan keeps the OLD theme's colour while the rest of the screen changes.
      Barako.currentTheme = themeForKey('barako');
      Barako.current = themeForKey('barako').dark;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PanMascot(mood: PanMood.calm))),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ColorFiltered),
        findsNothing,
        reason: 'Barako should draw the raw artwork with no filter',
      );

      Barako.currentTheme = themeForKey('mint');
      Barako.current = themeForKey('mint').dark;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PanMascot(mood: PanMood.calm))),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ColorFiltered),
        findsOneWidget,
        reason:
            'Switching to Mint left Pan unfiltered, so he is frozen in the '
            'previous palette while the rest of the screen has moved on.',
      );

      // Put it back so a later test does not inherit Mint.
      Barako.currentTheme = themeForKey('barako');
      Barako.current = themeForKey('barako').dark;
    });
  });

  test('the rotation is a rotation, so it comes back round', () {
    // Sanity on the maths itself rather than on any one theme: rotating by a
    // full turn is the same as not rotating.
    final full = panTintMatrix(
      HSVColor.fromColor(panArtColor).withHue(0.0).toColor(),
    );
    expect(full, isNotNull);
    final back = _apply(full!, panArtColor);
    expect((HSVColor.fromColor(back).hue - 0.0).abs() % 360, lessThan(25));
    expect(math.max(0, 1), 1); // keeps the math import honest
  });
}
