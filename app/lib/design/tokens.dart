// Salapify 3, the chosen skin, and the only place a colour is decided.
//
// ONE theme. Hapon is the light primary, Gabi is the dark option derived from
// exactly the same hues. There is no picker and there is no third option.
// Approved by the founder on 2026-09-13 against 24 real renders. See D10.
//
// How the choice was made, so nobody reruns the experiment:
//
//   Banaag, page #FFF6EE. Warm but unnameable, and a white card only sits
//     1.068 to 1 off that page, so at forty transactions the list stops
//     reading as grouped cards and turns into one white sheet.
//   Sikat, page a gradient #FFEBDA to #FFFCFA. Prettiest single screenshot and
//     the worst daily screen. Two measured faults. The accent measures 4.48 to
//     1 on its warmest stop, which FAILS the 4.5 body bar, and the bottom of
//     its page is #FFFCFA where a white card separates by 1.022 to 1, which is
//     invisible. It is warm exactly where the hero already supplies colour and
//     colourless exactly where the lists live.
//   Hapon, page #FFEEDF. Flat, so every screen and every scroll position has
//     the same measured contrast, and it gives the best card separation of the
//     three at 1.132 to 1.
//
// Every colour below was measured before it was chosen, never after, and the
// ratio sits in a comment beside it. test/design/palette_contrast_test.dart
// re-measures all of them on every push, and token_coverage_test.dart reads
// THIS FILE'S SOURCE to prove no colour was added without being measured.
import 'package:flutter/material.dart';

/// The palette, as a Flutter [ThemeExtension].
///
/// The preview these tokens came from used a mutable global, which is fine for
/// a preview that renders one screen at a time and has no user. A real app has
/// to follow the phone's light or dark setting, and a ThemeExtension is what
/// Flutter provides for exactly that: it hangs off [ThemeData], so
/// `MaterialApp.themeMode` picks the skin and the two cross-fade through [lerp]
/// instead of snapping.
///
/// Read it as `context.skin.accent`, never by naming [hapon] or [gabi]
/// directly in a widget. A widget that names a skin cannot follow the setting.
@immutable
class Skin extends ThemeExtension<Skin> {
  const Skin({
    required this.key,
    required this.name,
    required this.gloss,
    required this.dark,
    required this.bg,
    required this.card,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.good,
    required this.bad,
    required this.discOnPage,
    required this.discOnCard,
    required this.heroGradient,
    required this.onHero,
    required this.onHeroQuiet,
    required this.scrim,
    required this.radius,
  });

  final String key;
  final String name;
  final String gloss;
  final bool dark;

  /// The one page colour. Flat on purpose. A page that changes colour as you
  /// scroll changes every contrast ratio as you scroll, and one of Sikat's
  /// failed.
  final Color bg;

  /// The white, or near white, that a group of rows sits on.
  final Color card;

  /// The hairline between two rows inside a group. This is what keeps a
  /// forty row list from reading as one slab.
  final Color line;

  /// Body ink.
  final Color text;

  /// Secondary ink: a subtitle, a date line, an icon inside a disc.
  final Color text2;

  /// The ONE grey for captions. A third grey is how a palette starts to drift.
  final Color text3;

  /// The single saturated colour in the app. Links, the Log pill, and the
  /// "you owe" half of the debt beam. Nothing else.
  final Color accent;

  /// Ink on top of [accent] when the accent becomes a fill.
  final Color onAccent;

  /// Direction, and only direction. good is money coming to you.
  final Color good;

  /// Direction, and only direction. bad is money going out.
  final Color bad;

  /// An icon disc sitting on the page.
  final Color discOnPage;

  /// An icon disc sitting inside a card. Two fields rather than one guess,
  /// because the right answer flips in dark.
  final Color discOnCard;

  /// Ink on the gradient panel. Measured against the panel's DARKEST stop,
  /// because text over a gradient has to pass against the worst pixel behind
  /// it.
  final Color onHero;

  /// The quiet second line on the gradient panel, measured the same way.
  final Color onHeroQuiet;

  /// What dims the screen behind a sheet.
  ///
  /// The SAME dark in both skins, which is the point of it being a token
  /// rather than a per-skin colour: a scrim is a shadow, not a surface, so it
  /// does not flip when the palette does. It carries its own alpha, so a
  /// feature never spells out an opacity either.
  final Color scrim;

  /// Three stops, top left to bottom right. The signature device: a LIGHT
  /// panel carrying DARK ink, which is the opposite of what every dark
  /// fintech hero does.
  final List<Color> heroGradient;

  /// One card radius for the whole app.
  final double radius;

  /// Required by [ThemeExtension]. Nothing in Salapify patches a single token,
  /// because there are exactly two skins and both are compile-time constants,
  /// but the contract is implemented honestly rather than stubbed: a copyWith
  /// that quietly ignores its arguments is a trap for whoever needs it later.
  @override
  Skin copyWith({
    String? key,
    String? name,
    String? gloss,
    bool? dark,
    Color? bg,
    Color? card,
    Color? line,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? onAccent,
    Color? good,
    Color? bad,
    Color? discOnPage,
    Color? discOnCard,
    List<Color>? heroGradient,
    Color? onHero,
    Color? onHeroQuiet,
    Color? scrim,
    double? radius,
  }) {
    return Skin(
      key: key ?? this.key,
      name: name ?? this.name,
      gloss: gloss ?? this.gloss,
      dark: dark ?? this.dark,
      bg: bg ?? this.bg,
      card: card ?? this.card,
      line: line ?? this.line,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      good: good ?? this.good,
      bad: bad ?? this.bad,
      discOnPage: discOnPage ?? this.discOnPage,
      discOnCard: discOnCard ?? this.discOnCard,
      heroGradient: heroGradient ?? this.heroGradient,
      onHero: onHero ?? this.onHero,
      onHeroQuiet: onHeroQuiet ?? this.onHeroQuiet,
      scrim: scrim ?? this.scrim,
      radius: radius ?? this.radius,
    );
  }

  /// The cross-fade between Hapon and Gabi when the phone flips.
  ///
  /// The three non-colour identity fields (key, name, gloss) and [dark] snap at
  /// the halfway point rather than interpolating, because there is no half of
  /// a name. Everything a person SEES moves smoothly.
  @override
  Skin lerp(covariant ThemeExtension<Skin>? other, double t) {
    if (other is! Skin) return this;
    final past = t < 0.5;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Skin(
      key: past ? key : other.key,
      name: past ? name : other.name,
      gloss: past ? gloss : other.gloss,
      dark: past ? dark : other.dark,
      bg: c(bg, other.bg),
      card: c(card, other.card),
      line: c(line, other.line),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      good: c(good, other.good),
      bad: c(bad, other.bad),
      discOnPage: c(discOnPage, other.discOnPage),
      discOnCard: c(discOnCard, other.discOnCard),
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          c(heroGradient[i], other.heroGradient[i]),
      ],
      onHero: c(onHero, other.onHero),
      onHeroQuiet: c(onHeroQuiet, other.onHeroQuiet),
      scrim: c(scrim, other.scrim),
      radius: lerpDouble(radius, other.radius, t),
    );
  }
}

/// [Color.lerp] for a plain double. Written out rather than imported from
/// dart:ui so this file's imports stay to material alone.
double lerpDouble(double a, double b, double t) => a + (b - a) * t;

// ---------------------------------------------------------------- light

/// Hapon, late afternoon. The primary look.
const hapon = Skin(
  key: 'hapon',
  name: 'Hapon',
  gloss: 'late afternoon',
  dark: false,

  // Flat, and clearly orange rather than merely warm. The accent measures
  // 5.30 to 1 here, so there is real headroom over the 4.5 bar.
  bg: Color(0xFFFFEEDF),
  card: Color(0xFFFFFFFF), // 1.132 separation from the page
  line: Color(0xFFF3DFCD), // 1.293 on white, a hairline you can see

  text: Color(0xFF15120F), // 16.48 page, 18.66 card
  text2: Color(0xFF5A5148), // 6.86 page, 7.76 card
  text3: Color(0xFF6B6156), // 5.35 page, 6.05 card, the ONE grey for captions
  // Was #C2410C, which measured 4.57 on this page. That clears the bar by
  // 0.07 and nothing should ship that thin. #B03C09 is the brightest orange
  // in this hue family that still reaches 5.30 on the page and 6.01 on white.
  accent: Color(0xFFB03C09),
  onAccent: Color(0xFFFFFFFF), // 6.01 on the accent
  good: Color(0xFF16643F), // 6.33 page, 7.17 card
  bad: Color(0xFF9E2C1B), // 6.55 page, 7.42 card
  discOnPage: Color(0xFFFFFFFF),
  discOnCard: Color(0xFFFFEEDF),

  // First stop was #FFE2C7, which separates from the page by only 1.094, so
  // the panel's top left corner dissolved into the page. #FFD9B0 lifts that
  // to 1.174 and still holds the quiet ink at 8.59. Last stop deepened from
  // #FDA968 to #FB9C52 for warmth, which is why the quiet ink had to darken
  // from #6B3410 to #5E2C08 to stay over 5.0 down there.
  heroGradient: [Color(0xFFFFD9B0), Color(0xFFFEC078), Color(0xFFFB9C52)],
  onHero: Color(0xFF2A1207), // 13.30 / 10.96 / 8.40 across the three stops
  onHeroQuiet: Color(0xFF5E2C08), // 8.59 / 7.08 / 5.42, worst case 5.42
  // 0x8C is 55 percent. Same value in Gabi: a shadow does not change colour
  // when the lights go out.
  scrim: Color(0x8C15120F),
  radius: 20,
);

// ---------------------------------------------------------------- dark

/// Gabi, night. Same hues, one step over. Not a second design.
const gabi = Skin(
  key: 'gabi',
  name: 'Gabi',
  gloss: 'night',
  dark: true,

  // The page is the light page's own hue driven down to near black, so the
  // dark app is warm brown black and never blue black.
  bg: Color(0xFF14100D),
  card: Color(0xFF27201A), // 1.179 separation, matching the light mode feel
  line: Color(0xFF383029),

  text: Color(0xFFF6EFE8), // 16.61 page, 14.09 card
  text2: Color(0xFFC6B8AC), // 9.78 page, 8.30 card
  text3: Color(0xFFAC9E92), // 7.26 page, 6.16 card
  accent: Color(0xFFFF9A52), // 9.01 page, 7.64 card
  onAccent: Color(0xFF1E0E03), // 8.93 on the accent
  good: Color(0xFF5FCB8E), // 9.39 page, 7.97 card
  bad: Color(0xFFFF8A6E), // 8.21 page, 6.97 card
  discOnPage: Color(0xFF27201A),
  discOnCard: Color(0xFF14100D),

  // The signature survives the mode change: still a light panel with dark
  // ink. One step deeper so it is not a lamp at night. Measured panel
  // luminance drops from 0.601 in light to 0.394 here.
  heroGradient: [Color(0xFFEBB884), Color(0xFFDE9A5B), Color(0xFFCE7D3C)],
  onHero: Color(0xFF1E0E03), // 10.47 / 7.93 / 5.92
  onHeroQuiet: Color(0xFF361701), // 9.16 / 6.94 / 5.17, worst case 5.17
  scrim: Color(0x8C15120F),
  radius: 20,
);

/// Both skins, in the order the review pictures are laid out. The contrast
/// sweep iterates THIS rather than a list it keeps itself, so a third skin
/// could never be added without being measured.
const allSkins = <Skin>[hapon, gabi];

// ---------------------------------------------------------------- space

/// Screen gutter. One number, used everywhere.
///
/// There is deliberately no spacing "scale" here. The approved renders use
/// this gutter and a handful of local gaps chosen by eye against a real
/// screen, and inventing an 8 point ladder after the fact would move pixels
/// the founder has already signed off.
const double gutter = 22;

// ---------------------------------------------------------------- reading it

/// `context.skin.accent`, from anywhere below [MaterialApp].
extension SkinX on BuildContext {
  Skin get skin {
    final s = Theme.of(this).extension<Skin>();
    assert(
      s != null,
      'No Skin on the theme. Build MaterialApp with salapifyTheme(), or this '
      'widget is being pumped outside the app in a test.',
    );
    // Falling back rather than throwing in release, deliberately. A missing
    // extension would be a bug in the theme wiring, and the wrong palette is a
    // far better thing for the founder to meet than a crashed screen. The
    // assert above means it can never reach a release build unnoticed.
    return s ?? hapon;
  }
}

/// The [ThemeData] Salapify hands to MaterialApp, one per skin.
///
/// Almost nothing is configured here on purpose: the app draws its own
/// surfaces out of the kit, so Material's own component themes never get a
/// chance to disagree with the tokens. What IS set is the handful of things
/// Flutter paints for us and would otherwise paint in its default blue.
ThemeData salapifyTheme(Skin s) {
  return ThemeData(
    useMaterial3: true,
    brightness: s.dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: s.bg,
    fontFamily: 'Jakarta',
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: s.accent,
          brightness: s.dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          // The three Material actually reaches for: a text selection handle,
          // a scrollbar, the ripple under a tap.
          primary: s.accent,
          onPrimary: s.onAccent,
          surface: s.bg,
        ),
    extensions: <ThemeExtension<dynamic>>[s],
  );
}
