// Salapify 3, the chosen skin.
//
// ONE theme. Hapon is the light primary, Gabi is the dark option derived from
// exactly the same hues. There is no picker and there is no third option.
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
// Every colour below was measured before it was chosen, never after. The
// numbers in the comments come from scratchpad/measure/*.py, not from memory.
import 'package:flutter/material.dart';

@immutable
class Skin {
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
    required this.radius,
  });

  final String key, name, gloss;
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

  final Color text, text2, text3;

  /// The single saturated colour in the app. Links, the Log pill, and the
  /// "you owe" half of the debt beam. Nothing else.
  final Color accent, onAccent;

  /// Direction, and only direction. good is money coming to you.
  final Color good, bad;

  /// An icon disc sitting on the page, and one sitting inside a card. Two
  /// fields rather than one guess, because the right answer flips in dark.
  final Color discOnPage, discOnCard;

  /// Three stops, top left to bottom right. The signature device: a LIGHT
  /// panel carrying DARK ink, which is the opposite of what every dark
  /// fintech hero does.
  final List<Color> heroGradient;

  /// Ink on the panel. Measured against the panel's DARKEST stop, because
  /// text over a gradient has to pass against the worst pixel behind it.
  final Color onHero, onHeroQuiet;

  final double radius;
}

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
  radius: 20,
);

const allSkins = [hapon, gabi];

/// Set before building. A plain global keeps the preview simple.
Skin skin = hapon;

/// Renders the Latest group at real length instead of three tidy rows.
/// A design that only works at three transactions is not a design.
bool dense = false;
