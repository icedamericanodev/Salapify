// Can the app be READ, in both skins?
//
// Pure arithmetic over the token set, so it is fast, total, and cannot be
// fooled by which screens somebody thought to render. The renders are still
// required (a picture catches what only an eye can catch) but "is this label
// legible" is not one of those things, and a human should not be asked to
// judge it by squinting.
//
// The bars are WCAG AA and are not negotiable: 4.5 for anything a person reads
// a sentence of, 3.0 for a graphic they have to make out.
//
// AND THEN [headroom] ON TOP, which is decision D8 and is the reason this file
// ended up in the shape it is. The first version checked the bare 4.5, and the
// deliberate break meant to prove it worked (putting the rejected accent
// #C2410C back) sailed straight through, because 4.57 clears 4.5. D8 rejected
// that colour anyway: "when a measurement lands within 0.2 of a bar, treat it
// as failing. Nothing ships that thin." A guard encoding 4.5 where the
// decision says 4.7 would have let the rejected orange walk back in, silently,
// at any point. The break did its job by finding the guard wrong.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';

/// WCAG relative luminance.
double _luminance(int argb) {
  double channel(int c) {
    final s = c / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(Color a, Color b) {
  final la = _luminance(a.toARGB32());
  final lb = _luminance(b.toARGB32());
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// D8's margin. A colour that only just clears a bar is one rounding away from
/// failing it, and the founder ruled that out by name.
///
/// It applies to the WCAG bars and NOT to the grouping edges below, which are
/// a different kind of number: 0.2 is four percent of the 4.5 reading bar and
/// eighteen percent of the 1.1 edge bar, so carrying it across would not be
/// applying the same rule, it would be applying a much harsher one to a
/// measurement D8 was never written about.
const double headroom = 0.2;

/// One pair the app actually draws.
///
/// It holds the token NAMES as well as the accessors, and that is what lets
/// the coverage test at the bottom of this file derive what was swept from the
/// sweep itself rather than from a second list somebody has to remember to
/// update. A derived set is a rule; a typed set is a promise.
class Pair {
  const Pair(this.fgField, this.bgField, this.fg, this.bg, this.bar, this.why);

  final String fgField;
  final String bgField;
  final Color Function(Skin) fg;
  final Color Function(Skin) bg;
  final double bar;

  /// What a person is doing with this pair, in three words.
  final String why;

  String get label => '$fgField on $bgField ($why)';
}

/// Body text, at the full 4.5 plus headroom. Every one of these is a sentence
/// somebody reads.
final _text = <Pair>[
  Pair('text', 'bg', (s) => s.text, (s) => s.bg, 4.5, 'reading'),
  Pair('text', 'card', (s) => s.text, (s) => s.card, 4.5, 'reading'),
  Pair('text2', 'bg', (s) => s.text2, (s) => s.bg, 4.5, 'reading'),
  Pair('text2', 'card', (s) => s.text2, (s) => s.card, 4.5, 'reading'),
  Pair('text3', 'bg', (s) => s.text3, (s) => s.bg, 4.5, 'reading'),
  Pair('text3', 'card', (s) => s.text3, (s) => s.card, 4.5, 'reading'),

  // The accent is ink far more often than it is a fill: every action word,
  // every link, the "you owe" amount. Held to the reading bar, which is the
  // whole reason Hapon's accent is #B03C09 and not the prettier #C2410C.
  Pair('accent', 'bg', (s) => s.accent, (s) => s.bg, 4.5, 'a link'),
  Pair('accent', 'card', (s) => s.accent, (s) => s.card, 4.5, 'a link'),
  Pair(
    'onAccent',
    'accent',
    (s) => s.onAccent,
    (s) => s.accent,
    4.5,
    'a button label',
  ),

  // Direction colours. These carry MEANING, not decoration, so they get the
  // reading bar rather than the graphic one.
  Pair('good', 'bg', (s) => s.good, (s) => s.bg, 4.5, 'money in'),
  Pair('good', 'card', (s) => s.good, (s) => s.card, 4.5, 'money in'),
  Pair('bad', 'bg', (s) => s.bad, (s) => s.bg, 4.5, 'money out'),
  Pair('bad', 'card', (s) => s.bad, (s) => s.card, 4.5, 'money out'),
];

/// Things a person has to make out but does not read: WCAG's non-text bar.
final _graphic = <Pair>[
  Pair(
    'text2',
    'discOnCard',
    (s) => s.text2,
    (s) => s.discOnCard,
    3.0,
    'an icon in a card',
  ),
  Pair(
    'text2',
    'discOnPage',
    (s) => s.text2,
    (s) => s.discOnPage,
    3.0,
    'an icon on the page',
  ),
];

/// Grouping edges: the card against the page, and the hairline between two
/// rows inside a card.
///
/// Held to 1.1, NOT to WCAG's 3.0, and the difference is deliberate rather
/// than a lowered bar. A card edge at 3.0 is not a white card on a peach page,
/// it is a grey box, and the whole look goes with it. What these carry is
/// grouping, not information: every fact on the screen is still fully legible
/// to someone who cannot see the edge at all. Hapon was chosen over Banaag on
/// exactly this number, so it is measured rather than eyeballed. Measured
/// today: card 1.132 light and 1.179 dark, hairline 1.293 light, 1.171 dark.
final _edges = <Pair>[
  Pair('card', 'bg', (s) => s.card, (s) => s.bg, 1.1, 'a card edge'),
  Pair('line', 'card', (s) => s.line, (s) => s.card, 1.1, 'a hairline'),
];

/// The three tokens the gradient loop checks rather than the pair lists, named
/// here so the coverage test below counts them as swept.
const _sweptByTheGradientLoop = {'onHero', 'onHeroQuiet', 'heroGradient'};

/// Tokens with no contrast pair to measure, and why. This set is a HOLE in the
/// coverage rule, so each entry has to earn itself in writing.
const _notAContrastPair = {
  // A 55 percent overlay. What it composites to depends entirely on whatever
  // screen happens to be behind the sheet, so there is no fixed pair here to
  // put a number on. What actually has to be legible is the sheet's own
  // content on the sheet's own surface, and that is measured above like every
  // other screen: text on bg.
  'scrim',
};

void main() {
  // Iterating allSkins rather than naming hapon and gabi: a third skin could
  // never be added without being measured.
  for (final s in allSkins) {
    group('${s.name} (${s.gloss})', () {
      // The WCAG pairs, each held to its bar PLUS D8's margin.
      for (final p in [..._text, ..._graphic]) {
        test(p.label, () {
          final ratio = contrast(p.fg(s), p.bg(s));
          expect(
            ratio,
            greaterThanOrEqualTo(p.bar + headroom),
            reason:
                '${p.label} in ${s.name} measures '
                '${ratio.toStringAsFixed(2)} to 1. The bar is ${p.bar} and D8 '
                'requires $headroom of headroom over it, so anything under '
                '${p.bar + headroom} is too thin to ship.',
          );
        });
      }

      // The grouping edges, at their own bar and with no margin. See _edges.
      for (final p in _edges) {
        test(p.label, () {
          final ratio = contrast(p.fg(s), p.bg(s));
          expect(
            ratio,
            greaterThanOrEqualTo(p.bar),
            reason:
                '${p.label} in ${s.name} measures '
                '${ratio.toStringAsFixed(2)} to 1, under the ${p.bar} bar.',
          );
        });
      }

      // Text over a gradient has to pass against the WORST pixel behind it,
      // not the average. Both inks are checked against all three stops.
      for (var i = 0; i < s.heroGradient.length; i++) {
        test('onHero on heroGradient stop ${i + 1}', () {
          expect(
            contrast(s.onHero, s.heroGradient[i]),
            greaterThanOrEqualTo(4.5 + headroom),
          );
        });
        test('onHeroQuiet on heroGradient stop ${i + 1}', () {
          expect(
            contrast(s.onHeroQuiet, s.heroGradient[i]),
            greaterThanOrEqualTo(4.5 + headroom),
          );
        });
      }
    });
  }

  group('the sweep is total', () {
    test('both skins were actually swept', () {
      // Without this the loops above pass perfectly over an empty list.
      expect(allSkins.map((s) => s.key), ['hapon', 'gabi']);
    });

    // The important one, and the pattern CLAUDE.md names as the right shape:
    // read the token file's SOURCE and prove every colour declared in it is
    // measured somewhere above. A new token cannot slip in unmeasured, because
    // nobody has to remember to add it here. The alternative, a hand-typed
    // list of expected names, is a promise rather than a rule: it goes stale
    // the first time somebody adds a field and does not think of this file.
    test('every colour token in tokens.dart is measured somewhere', () {
      final source = File('lib/design/tokens.dart').readAsStringSync();

      // The Skin class declares one colour per line, each with its own doc
      // comment. If that ever becomes `final Color a, b;` this regex quietly
      // stops seeing b, so the count assertion below is the backstop.
      //
      // The trailing `[;=]` earned itself. The first version ended at `;`
      // alone, and the deliberate break meant to prove this guard works,
      // adding an unmeasured `warning` colour, walked straight through it: the
      // break was written `final Color warning = const Color(0xFFFFE066)`, an
      // INITIALISED field, which the old pattern could not see at all. There
      // are two ways to declare a colour and the guard knew one of them.
      final declared = RegExp(
        r'^\s*final (?:List<Color>|Color)\??\s+(\w+)\s*[;=]',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toSet();

      expect(
        declared.length,
        16,
        reason:
            'Expected 16 colour tokens on Skin. If this changed on purpose, '
            'the new one needs a Pair above before this number moves. If it '
            'did NOT change, the declarations are no longer one per line and '
            'this regex has gone blind.',
      );

      final swept = <String>{
        for (final p in [..._text, ..._graphic, ..._edges]) ...[
          p.fgField,
          p.bgField,
        ],
        ..._sweptByTheGradientLoop,
        ..._notAContrastPair,
      };

      expect(
        declared.difference(swept),
        isEmpty,
        reason:
            'These colour tokens are declared in tokens.dart and never '
            'measured against anything. Add a Pair for each, or a line to '
            '_sweptByTheGradientLoop saying where it is checked instead.',
      );
    });
  });
}
