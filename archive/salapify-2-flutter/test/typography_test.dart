// The typography system is a contract, so it gets tests.
//
// Two things this guards, both of which went wrong before it existed:
//
// 1. Synthetic weights. Plus Jakarta Sans ships four weight files (400, 600,
//    700, 800). Ask for any other weight, say w500, and Flutter does not fail:
//    it picks the nearest file or fakes it, so the type quietly goes soft in a
//    way no screen test notices. Ten call sites used w500 before this. The
//    source scan below fails if any weight without a real file comes back.
//
// 2. Drift off the shared scale. The size ladder is ANCHORED on the React
//    Native app (mobile/theme.js): the eight RN sizes must match to the point,
//    or the two apps have silently diverged and "consistent with RN" is no
//    longer true. This pins them.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';

void main() {
  group('the type scale is anchored on the RN app', () {
    // These eight are the fontSize tokens in mobile/theme.js. They are the
    // hierarchy the two apps share, so they are the ones allowed to move only
    // in lockstep. If RN changes one, change it here in the same breath.
    test('the eight RN sizes match to the point', () {
      expect(TypeScale.caption, 12);
      expect(TypeScale.small, 13);
      expect(TypeScale.body, 15);
      expect(TypeScale.subtitle, 17);
      expect(TypeScale.title, 22);
      expect(TypeScale.big, 28);
      expect(TypeScale.huge, 34);
      expect(TypeScale.display, 42);
    });
  });

  group('weights map to real font files, never synthetics', () {
    // The four weights the app is allowed to use, because these are the four
    // Jakarta files. w500 is deliberately NOT here.
    const allowed = {400, 600, 700, 800};

    test('every TypeWeight is one of the four shipped weights', () {
      // FontWeight.value is the numeric weight (w400 -> 400).
      int numeric(FontWeight w) => w.value;
      expect(numeric(TypeWeight.regular), 400);
      expect(numeric(TypeWeight.medium), 600);
      expect(numeric(TypeWeight.bold), 700);
      expect(numeric(TypeWeight.heavy), 800);
      for (final w in [
        TypeWeight.regular,
        TypeWeight.medium,
        TypeWeight.bold,
        TypeWeight.heavy,
      ]) {
        expect(allowed.contains(numeric(w)), isTrue);
      }
    });

    test('the body font ships every weight the app names', () {
      // Read the weights Jakarta actually bundles, straight from the pubspec,
      // and confirm each TypeWeight has a file behind it. A weight without a
      // file is exactly the synthetic this test exists to stop.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final block = RegExp(
        '- family: ${Barako.bodyFont}(.*?)(?=\n    - family:|\$)',
        dotAll: true,
      ).firstMatch(pubspec);
      expect(
        block,
        isNotNull,
        reason: 'no ${Barako.bodyFont} block in pubspec',
      );
      final shipped = RegExp(
        r'weight:\s*(\d+)',
      ).allMatches(block!.group(1)!).map((m) => int.parse(m.group(1)!)).toSet();
      int numeric(FontWeight w) => w.value;
      for (final w in [
        TypeWeight.regular,
        TypeWeight.medium,
        TypeWeight.bold,
        TypeWeight.heavy,
      ]) {
        expect(
          shipped,
          contains(numeric(w)),
          reason:
              '${Barako.bodyFont} ships $shipped but the app asks for '
              '${numeric(w)}, which would render as a synthetic weight',
        );
      }
    });

    test('no source file asks for a weight the font cannot draw', () {
      // The real guard. Any FontWeight.w<n> in lib/ whose <n> is not a shipped
      // Jakarta weight is a synthetic. w500 was the whole reason this is here.
      final offenders = <String>[];
      final weightRef = RegExp(r'FontWeight\.w(\d00)');
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final m in weightRef.allMatches(lines[i])) {
            final w = int.parse(m.group(1)!);
            if (!allowed.contains(w)) {
              offenders.add('${f.path}:${i + 1} -> w$w');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these ask Jakarta for a weight it ships no file for, so the glyphs '
            'render as a synthetic and the type goes soft:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the weight scan would actually catch one', () {
      // A scanner that matched nothing passes on a clean lib and on a broken
      // pattern alike, and reads like a clean bill of health either way.
      final weightRef = RegExp(r'FontWeight\.w(\d00)');
      final bad = weightRef.firstMatch('fontWeight: FontWeight.w500');
      expect(bad, isNotNull);
      expect(int.parse(bad!.group(1)!), 500);
      expect(allowed.contains(500), isFalse);
      expect(weightRef.hasMatch('fontWeight: FontWeight.w700'), isTrue);
    });
  });

  group('the semantic roles carry the sizes and weights they promise', () {
    test('titles are heavy, the RN rule that numbers and titles own w800', () {
      expect(AppText.title.fontSize, TypeScale.title);
      expect(AppText.title.fontWeight, TypeWeight.heavy);
    });

    test('body is RN body at regular weight', () {
      expect(AppText.body.fontSize, TypeScale.body);
      expect(AppText.body.fontWeight, TypeWeight.regular);
    });

    test('the hero amount uses the display font with tabular figures', () {
      expect(AppText.amountHero.fontSize, TypeScale.display);
      expect(AppText.amountHero.fontFamily, Barako.displayFont);
      expect(
        AppText.amountHero.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('the kicker is the one shared definition, not a fork', () {
      // Same object shape as Barako.kickerStyle, so the tuned 12/w600/1.2 can
      // never drift into a second copy.
      expect(AppText.kicker.fontSize, Barako.kickerStyle.fontSize);
      expect(AppText.kicker.letterSpacing, Barako.kickerStyle.letterSpacing);
      expect(AppText.kicker.fontWeight, Barako.kickerStyle.fontWeight);
    });

    test('the modifiers change exactly one field each', () {
      const base = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
      expect(base.w7.fontWeight, FontWeight.w700);
      expect(base.w7.fontSize, 15);
      expect(base.tint(Barako.warning).color, Barako.warning);
      expect(
        base.tabular.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
