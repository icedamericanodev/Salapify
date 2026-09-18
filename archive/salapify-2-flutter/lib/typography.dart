// The one place typography lives, so the app reads as one app.
//
// Before this file, type was scattered: a thousand-odd hand typed TextStyle
// literals across the screens, sizes that drifted off any ladder (8.5, 10.5,
// 13.5, 19, 27), and ten uses of a 500 weight, one Plus Jakarta Sans ships no
// file for, so it rendered as a synthetic in between the real 400 and 600. One
// label could read two different ways on two screens and nothing
// failed, because a private TextStyle is invisible to every test and to every
// reader not diffing two files side by side.
//
// The scale is ANCHORED ON THE REACT NATIVE APP. mobile/theme.js is the source
// of truth for the hierarchy the two apps share: its fontSize tokens (caption
// 12, small 13, body 15, subtitle 17, title 22, big 28, huge 34, display 42)
// and its fontWeight roles (regular 400, medium 600, bold 700, heavy 800,
// where heavy is reserved for money numbers and page titles so the numbers own
// the hierarchy). The RN app loads no custom font and renders in the system
// face; Flutter deliberately ships Plus Jakarta Sans (see Barako.displayFont in
// theme.dart), so this file mirrors RN's SCALE onto Jakarta rather than copying
// its font. Every weight here maps to a real Jakarta file (400/600/700/800),
// which is the whole reason w500 is gone: no synthetic weights.
//
// The styles are GETTERS, never const, for the same reason the color namespace
// is: they read the live Barako palette during build, so a theme or light and
// dark switch repaints every label. A const TextStyle would freeze the color.

import 'package:flutter/material.dart';

import 'theme.dart';

/// The size ladder. One rung per real role.
///
/// The eight named after RN (caption, small, body, subtitle, title, big, huge,
/// display) match mobile/theme.js to the point. The rest (nav, micro, label,
/// bodyLg, heading, lg, hero, xl) are steps the Flutter app already leaned on;
/// naming them here gives every size in the app a home so a raw literal is a
/// bug, not a normal thing to type. Anything off this ladder (8.5, 10.5, 13.5,
/// 19, 27) snaps to the nearest rung.
abstract final class TypeScale {
  /// Bottom navigation labels only. Six tabs share the width.
  static const double nav = 10;

  /// Dense meta: footnotes, chip counters, the smallest a phone should show.
  static const double micro = 11;

  /// RN caption. Also the uppercase kicker size.
  static const double caption = 12;

  /// RN small. Secondary rows, hints, timestamps.
  static const double small = 13;

  /// Dense labels and list rows that want a touch more than small.
  static const double label = 14;

  /// RN body. The default sentence.
  static const double body = 15;

  /// Emphasised body and primary list titles.
  static const double bodyLg = 16;

  /// RN subtitle. Card titles.
  static const double subtitle = 17;

  /// Section headings inside a screen.
  static const double heading = 18;

  /// Small hero labels above a big number.
  static const double lg = 20;

  /// RN title. Page and AppBar titles.
  static const double title = 22;

  /// Large statement figures below the hero.
  static const double xl = 24;

  /// RN big.
  static const double big = 28;

  /// The one hero number on a busier screen.
  static const double hero = 30;

  /// RN huge.
  static const double huge = 34;

  /// RN display. The net worth hero only.
  static const double display = 42;
}

/// The four weights, and only these four, because these are the four Jakarta
/// files. Named after RN's roles so nothing has to memorise numbers, and so the
/// rule "heavy is money and titles" reads at the call site.
abstract final class TypeWeight {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Reserved for money numbers and page titles, so the numbers own the
  /// hierarchy. Do not spend it on ordinary labels.
  static const FontWeight heavy = FontWeight.w800;
}

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The semantic styles. A screen names the ROLE ("this is a subtitle", "this
/// is the hero amount") and this file decides how it draws, so restyling the
/// whole app is one edit here.
///
/// Color is the natural one for each role and is meant to be overridden freely
/// at the call site, where a warning amount goes red or a value goes accent.
/// Use `.tint(color)` for that, and `.w6` / `.w7` / `.w8` to shift weight,
/// rather than spelling out a fresh TextStyle.
abstract final class AppText {
  // Money, in two deliberate faces (founder direction, 2026-08-22). The DISPLAY
  // numbers (the hero, the card figure, the metric tiles) stay Jakarta; the
  // LEDGER numbers (row and reference amounts, the working money in a list or a
  // table) draw in IBM Plex Sans, so a dense column of figures reads as a
  // ledger rather than a wall of hero type. Both carry tabular figures so a
  // changing figure holds its column instead of jittering, which is why neither
  // is Fraunces (it ships no tnum table). The families live on Barako
  // (displayFont / ledgerFont), so a face change is one edit, not a call-site
  // sweep.

  /// The net worth hero, the one biggest number on the app.
  static TextStyle get amountHero => TextStyle(
    fontFamily: Barako.displayFont,
    fontSize: TypeScale.display,
    fontWeight: TypeWeight.heavy,
    height: 1.05,
    color: Barako.text,
    fontFeatures: _tabular,
  );

  /// A hero number one step down (34).
  static TextStyle get amountXl =>
      amountHero.copyWith(fontSize: TypeScale.huge);

  /// A hero number on a busier screen (30).
  static TextStyle get amountLg =>
      amountHero.copyWith(fontSize: TypeScale.hero);

  /// A card's headline figure (28). Also the amount INPUT size in the log and
  /// edit sheets, so entering a figure and reading it back feel like one act.
  static TextStyle get amount => amountHero.copyWith(fontSize: TypeScale.big);

  /// A labelled metric figure (17, heavy, tabular): the StatPair columns and
  /// any amount standing beside a twin. Named here so the metric face lives
  /// on the ladder instead of being composed in two widget files.
  static TextStyle get amountMetric => TextStyle(
    fontFamily: Barako.bodyFont,
    fontSize: TypeScale.subtitle,
    fontWeight: TypeWeight.heavy,
    height: 1.25,
    color: Barako.text,
    fontFeatures: _tabular,
  );

  /// Money inline in a list row: body size, bold, tabular, so a column of
  /// amounts lines up on the decimal. Drawn in the LEDGER face (IBM Plex Sans),
  /// the working-money face that the display hero (Jakarta) deliberately does
  /// not share, so a dense list of figures reads as a ledger.
  ///
  /// STRICT, deliberately. A row amount read five different ways in five
  /// screens before this rule: never resize it, never reweight it. The only
  /// permitted modifier is `.tint(color)`, for direction or warning color.
  /// A screen that wants a bigger figure wants [amount], not a resized row.
  static TextStyle get amountRow => TextStyle(
    fontFamily: Barako.ledgerFont,
    fontSize: TypeScale.body,
    fontWeight: TypeWeight.bold,
    height: 1.2,
    color: Barako.text,
    fontFeatures: _tabular,
  );

  /// A supporting money figure, subordinate to a primary amount. Same body
  /// size and tabular figures as [amountRow], one weight lighter (medium, not
  /// bold) and in the secondary ink, so a reference amount still reads as
  /// money and lines up in a column without competing with the row, metric or
  /// hero beside it. The colour is the natural one to override at the call
  /// site, exactly like amountRow: pass Barako.text where it sits on full ink
  /// beside a tinted primary, or Barako.muted on a surface that allows it.
  static TextStyle get amountReference => TextStyle(
    fontFamily: Barako.ledgerFont,
    fontSize: TypeScale.body,
    fontWeight: TypeWeight.medium,
    height: 1.2,
    color: Barako.textSecondary,
    fontFeatures: _tabular,
  );

  // Headings.

  /// Page and AppBar title. Heavy, because a page title is one of the two
  /// things heavy is for.
  static TextStyle get title => TextStyle(
    fontSize: TypeScale.title,
    fontWeight: TypeWeight.heavy,
    height: 1.2,
    color: Barako.text,
  );

  /// An oversized page moment (24): onboarding steps, lesson covers. The
  /// screens kept inventing raw 24s for exactly this role; now it has a name,
  /// a fresh literal 24 is drift and not a normal thing to type.
  static TextStyle get titleLg => TextStyle(
    fontSize: TypeScale.xl,
    fontWeight: TypeWeight.heavy,
    height: 1.2,
    color: Barako.text,
  );

  /// The rare non-money statement at hero size (30): the onboarding welcome,
  /// a full-screen moment. For a NUMBER this big, use [amountLg] instead,
  /// which carries the tabular figures a money hero needs.
  static TextStyle get hero => TextStyle(
    fontSize: TypeScale.hero,
    fontWeight: TypeWeight.heavy,
    height: 1.15,
    color: Barako.text,
  );

  /// A section heading inside a screen.
  static TextStyle get heading => TextStyle(
    fontSize: TypeScale.heading,
    fontWeight: TypeWeight.bold,
    height: 1.25,
    color: Barako.text,
  );

  /// A card title.
  static TextStyle get subtitle => TextStyle(
    fontSize: TypeScale.subtitle,
    fontWeight: TypeWeight.bold,
    height: 1.25,
    color: Barako.text,
  );

  // Body.

  /// Emphasised body, primary list titles (16).
  static TextStyle get bodyLg => TextStyle(
    fontSize: TypeScale.bodyLg,
    fontWeight: TypeWeight.regular,
    height: 1.4,
    color: Barako.text,
  );

  /// The default sentence (15).
  static TextStyle get body => TextStyle(
    fontSize: TypeScale.body,
    fontWeight: TypeWeight.regular,
    height: 1.4,
    color: Barako.text,
  );

  /// Body in the secondary ink, for supporting prose.
  static TextStyle get bodyMuted => body.copyWith(color: Barako.textSecondary);

  /// Body turned bold, for a value or an emphasised word in a row.
  static TextStyle get bodyStrong => body.copyWith(fontWeight: TypeWeight.bold);

  // Labels and captions.

  /// A dense label or list row (14).
  static TextStyle get label => TextStyle(
    fontSize: TypeScale.label,
    fontWeight: TypeWeight.medium,
    height: 1.3,
    color: Barako.text,
  );

  /// RN small (13), secondary ink.
  static TextStyle get small => TextStyle(
    fontSize: TypeScale.small,
    fontWeight: TypeWeight.regular,
    height: 1.3,
    color: Barako.textSecondary,
  );

  /// Small turned bold, for a strong 13px value.
  static TextStyle get smallStrong =>
      small.copyWith(fontWeight: TypeWeight.bold, color: Barako.text);

  /// RN caption (12), muted.
  static TextStyle get caption => TextStyle(
    fontSize: TypeScale.caption,
    fontWeight: TypeWeight.regular,
    height: 1.3,
    color: Barako.muted,
  );

  /// The smallest meta (11), muted.
  static TextStyle get micro => TextStyle(
    fontSize: TypeScale.micro,
    fontWeight: TypeWeight.medium,
    height: 1.2,
    color: Barako.muted,
  );

  /// The uppercase overline above a card or section. Delegated to
  /// Barako.kickerStyle so the one kicker definition cannot fork again.
  static TextStyle get kicker => Barako.kickerStyle;

  /// A PAGE-level section band title, one clear tier above the card kicker.
  ///
  /// The kicker (12, medium, muted) is a card's own quiet overline; a screen
  /// that stacks several bands ("DO NEXT", "THIS MONTH", "THE BIGGER PICTURE")
  /// was drawing those bands in that same quiet kicker, so the page had no
  /// rhythm and every band read at the weight of a card's inner label. This is
  /// the band: still an uppercase overline so it pairs with the kickers beneath
  /// it, but heavy and on full ink (heavy is the weight reserved for money and
  /// titles, and a page section earns it), with tighter tracking so the heavier
  /// letters do not smear. One rung, named, so a band stops being a hand-rolled
  /// Text and a second screen gets the exact same heading.
  static TextStyle get sectionTitle => TextStyle(
    fontSize: TypeScale.small,
    fontWeight: TypeWeight.heavy,
    height: 1.2,
    letterSpacing: 0.6,
    color: Barako.text,
  );
}

/// Terse, exact tweaks at the call site, so a variant is a modifier rather than
/// a fresh literal. `AppText.small.w7.tint(Barako.warning)` reads as "small,
/// bold, in the warning color" and stays anchored to the small role.
extension AppTextStyleX on TextStyle {
  /// Regular (400).
  TextStyle get w4 => copyWith(fontWeight: TypeWeight.regular);

  /// Medium (600).
  TextStyle get w6 => copyWith(fontWeight: TypeWeight.medium);

  /// Bold (700).
  TextStyle get w7 => copyWith(fontWeight: TypeWeight.bold);

  /// Heavy (800). Money and titles only.
  TextStyle get w8 => copyWith(fontWeight: TypeWeight.heavy);

  /// Recolor, keeping every other field.
  TextStyle tint(Color color) => copyWith(color: color);

  /// Turn on tabular figures for a lined up column of numbers.
  TextStyle get tabular => copyWith(fontFeatures: _tabular);
}
