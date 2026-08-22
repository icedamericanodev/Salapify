// The font decision lives in ONE place.
//
// It used to live in forty. `Barako.displayFont` existed and most screens used
// it, but five files named 'Fraunces' directly, so switching the display face
// was five edits nobody would remember to make and two of them were in share
// images the founder never sees in a normal render.
//
// Why it mattered: Fraunces draws ₱ with a long crossbar, and beside a minus
// sign the two run together into what reads as a line STRUCK THROUGH the
// number. "-₱720" looked like a crossed-out ₱720, on every negative figure in
// the app. The founder found it on their phone.
//
// So this file guards two things. That nobody hardcodes a family again, and
// that the display face still has the properties the choice was made on,
// because the second one is what makes the first one worth having.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';

void main() {
  test('no screen names a font family directly', () {
    // theme.dart is where the decision belongs, so it is the one file allowed
    // to hold a family name. Everything else asks it.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('theme.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = RegExp(r"fontFamily:\s*'(\w+)'").firstMatch(lines[i]);
        // No exception for 'monospace' any more. Salapify now ships a real mono
        // face (Barako.monoFont, IBM Plex Mono), so the receipt-style blocks
        // that used to name the platform generic route through the theme like
        // everything else, and a raw 'monospace' is once again a family named
        // outside the one place families live.
        if (m != null) {
          offenders.add('${f.path}:${i + 1} -> ${m.group(1)}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these name a font family instead of asking the theme, so changing '
          'the app\'s type is that many edits and the ones in share images '
          'are invisible until somebody shares:\n${offenders.join('\n')}',
    );
  });

  test('the scan would actually find one', () {
    // A scanner that matched nothing would pass on an empty lib/ and on a typo
    // in the pattern, and would read exactly like a clean bill of health.
    const bad = "  style: TextStyle(fontFamily: 'Fraunces', fontSize: 30),";
    const good = '  style: TextStyle(fontFamily: Barako.displayFont),';
    expect(RegExp(r"fontFamily:\s*'(\w+)'").hasMatch(bad), isTrue);
    expect(RegExp(r"fontFamily:\s*'(\w+)'").hasMatch(good), isFalse);
  });

  test('the display face is a family the app actually ships', () {
    // A typo here is invisible: Flutter silently falls back to the platform
    // font, so the app keeps working and simply stops looking like itself.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final families = RegExp(
      r'- family:\s*(\w+)',
    ).allMatches(pubspec).map((m) => m.group(1)).toSet();
    expect(families, isNotEmpty, reason: 'the pubspec scan found no fonts');
    expect(
      families,
      contains(Barako.displayFont),
      reason:
          '"${Barako.displayFont}" is not a bundled family, so every hero '
          'number silently falls back to the platform font',
    );
  });

  test('the display face can reach the weight the hero numbers ask for', () {
    // The old face shipped only w600 and w700. A face that cannot reach the
    // weight a call site requests does not fail; it synthesises or picks the
    // nearest, which is how type quietly goes soft.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final block = RegExp(
      '- family: ${Barako.displayFont}(.*?)(?=\n    - family:|\$)',
      dotAll: true,
    ).firstMatch(pubspec);
    expect(block, isNotNull);
    final weights = RegExp(
      r'weight:\s*(\d+)',
    ).allMatches(block!.group(1)!).map((m) => int.parse(m.group(1)!)).toSet();
    expect(
      weights,
      contains(700),
      reason: 'hero numbers are drawn at w700 and this face has $weights',
    );
  });

  test('a negative peso figure is not one glyph short of a strikethrough', () {
    // The actual bug, as close as a headless test can get to it. The rendered
    // width of "-₱720" must be meaningfully wider than "₱720": if the minus
    // adds almost nothing, it is sitting ON the peso crossbar rather than
    // beside it, which is exactly what it did in the old face.
    double widthOf(String s) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: Barako.displayFont,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    // Without the real font loaded this measures the test fallback, which
    // proves nothing about Jakarta. So it asserts the RULE, and the render in
    // test/font_compare.dart is what proves the glyphs. Kept because the rule
    // is the thing a future font swap has to satisfy.
    final gap = widthOf('-₱720') - widthOf('₱720');
    expect(
      gap,
      greaterThan(0),
      reason:
          'the minus sign takes no width at all, so it is drawn on top of the '
          'peso sign rather than before it',
    );
  });
}
