// The Salapify theme system. Ported to match the live React Native app: each
// THEME carries a light and a dark palette, and a separate appearance mode
// (light | dark | system) picks which one shows. system follows the phone, so
// the app goes dark at night on its own. The eight themes started as a copy of
// mobile/theme.js, so most hex values still match the AA-checked RN ones to the
// byte, but the two files are now siblings rather than generator and output:
// the light Forest palette and the whole label and hint set are fixed here and
// deliberately not carried back to RN, which stays frozen for testers.
//
// Barako stays the color namespace every screen reads (Barako.text and so on),
// but the members are getters over the ACTIVE palette, resolved from the chosen
// theme and the effective brightness and rebuilt from the app root. That is why
// the screens avoid const on color-bearing widgets: const would freeze the
// palette, and now the palette can change with no tap at all (the OS flipping to
// dark at night repaints the whole tree). See analysis_options.yaml.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// One brightness worth of colors. Pure color DATA, so it stays const; identity
/// (key, label) lives on BarakoTheme, not here.
class BarakoPalette {
  final Brightness brightness;
  final Color background;
  final Color card;
  final Color surfaceRaised;
  final Color border;
  final Color primary;
  // A darker roast of the brand color for SMALL text and links. On the RN light
  // variants the primary is already tuned to pass AA as small money text, so
  // here primaryText == primary; the field stays for screens that read it.
  final Color primaryText;
  final Color caramel; // RN's softGreen: warm kicker/label accent
  final Color text;
  final Color textSecondary;
  final Color muted;
  final Color faint;
  final Color warning;
  final Color warningStrong;
  final Color onPrimary;

  /// The win gold. THEME-INVARIANT by rule: every dark palette carries the
  /// same gold and every light palette the same deep gold, the same reasoning
  /// as Pan's fixed orange. The reward signature should read identically in
  /// every screenshot; before this, Voltage celebrated in hot pink and
  /// Ultraviolet in lime, so a win looked like a different app per theme.
  /// The invariance is enforced by palette_contrast_test, not by this comment.
  final Color celebrate;
  final Color positiveSurface;
  final Color positiveBorder;
  final Color overlay;

  const BarakoPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.surfaceRaised,
    required this.border,
    required this.primary,
    required this.primaryText,
    required this.caramel,
    required this.text,
    required this.textSecondary,
    required this.muted,
    required this.faint,
    required this.warning,
    required this.warningStrong,
    required this.onPrimary,
    required this.celebrate,
    required this.positiveSurface,
    required this.positiveBorder,
    required this.overlay,
  });
}

/// A named theme with both brightnesses. resolve() picks one.
class BarakoTheme {
  final String key; // stored in settings.themeKey
  final String label; // shown in the theme picker
  final String hint; // one-line description in the picker
  final BarakoPalette light;
  final BarakoPalette dark;
  const BarakoTheme({
    required this.key,
    required this.label,
    required this.hint,
    required this.light,
    required this.dark,
  });
  BarakoPalette resolve(Brightness b) => b == Brightness.dark ? dark : light;
}

const _barakoDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF1A130E),
  card: Color(0xFF251A13),
  surfaceRaised: Color(0xFF2E211A),
  border: Color(0xFF3A2A20),
  primary: Color(0xFFFF8A3D),
  primaryText: Color(0xFFFF8A3D),
  caramel: Color(0xFFE9BC8E),
  text: Color(0xFFFBF3E9),
  textSecondary: Color(0xFFE0CEBB),
  muted: Color(0xFFA99182),
  faint: Color(0xFF97806F),
  warning: Color(0xFFFF5D73),
  // Lifted two points from F5384F, which measured 4.4996 against this card:
  // under WCAG AA by four ten-thousandths. Not a judgement call about how it
  // looks, a rounding hair on the wrong side of a published bar, found by
  // palette_contrast_test rather than by eye, and invisible at two points.
  // It matters because warningStrong carries the 13pt section subtotals on
  // Accounts, which are small enough that the 4.5 bar genuinely applies.
  warningStrong: Color(0xFFF73A51),
  onPrimary: Color(0xFF2A1305),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF2E2114),
  positiveBorder: Color(0xFF55402C),
  overlay: Color.fromRGBO(10, 7, 5, 0.64),
);
const _barakoLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF7F1E7),
  card: Color(0xFFFFFDF7),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFE7DCC9),
  primary: Color(0xFFAE5019),
  primaryText: Color(0xFFAE5019),
  caramel: Color(0xFF8A5A2E),
  text: Color(0xFF241812),
  textSecondary: Color(0xFF4A382E),
  muted: Color(0xFF6E5A4C),
  faint: Color(0xFF7D695B),
  warning: Color(0xFFB01E38),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFF3E7D5),
  positiveBorder: Color(0xFFE2CBAF),
  overlay: Color.fromRGBO(28, 16, 8, 0.42),
);
const _tidalDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF0A121F),
  card: Color(0xFF131F30),
  surfaceRaised: Color(0xFF1B2A3E),
  border: Color(0xFF24374F),
  primary: Color(0xFF2DD4E8),
  primaryText: Color(0xFF2DD4E8),
  caramel: Color(0xFF7FC5D6),
  text: Color(0xFFEFF6FB),
  textSecondary: Color(0xFFC6D6E2),
  muted: Color(0xFF8598A8),
  faint: Color(0xFF758898),
  warning: Color(0xFFFF9F45),
  warningStrong: Color(0xFFFF7A38),
  onPrimary: Color(0xFF052730),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF122A33),
  positiveBorder: Color(0xFF1E4C57),
  overlay: Color.fromRGBO(4, 9, 16, 0.64),
);
const _tidalLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFEAF3F8),
  card: Color(0xFFFBFDFE),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFD8E4EC),
  primary: Color(0xFF0A6E82),
  primaryText: Color(0xFF0A6E82),
  caramel: Color(0xFF2C6076),
  text: Color(0xFF0F1C28),
  textSecondary: Color(0xFF32475A),
  muted: Color(0xFF5A6E7E),
  faint: Color(0xFF5A6E7C),
  warning: Color(0xFFB4551A),
  warningStrong: Color(0xFF924213),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE1F0F2),
  positiveBorder: Color(0xFFBCDDE0),
  overlay: Color.fromRGBO(8, 20, 28, 0.42),
);
const _ultravioletDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF14102A),
  card: Color(0xFF1E1840),
  surfaceRaised: Color(0xFF28214F),
  border: Color(0xFF372C63),
  primary: Color(0xFFA98BFF),
  primaryText: Color(0xFFA98BFF),
  caramel: Color(0xFFC9B7FF),
  text: Color(0xFFF4F1FF),
  textSecondary: Color(0xFFCFC6EE),
  muted: Color(0xFF9A90C4),
  faint: Color(0xFF897FB2),
  warning: Color(0xFFFF8A4C),
  warningStrong: Color(0xFFFF6A3D),
  onPrimary: Color(0xFF1A0F33),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF24204C),
  positiveBorder: Color(0xFF443B7A),
  overlay: Color.fromRGBO(10, 7, 24, 0.64),
);
const _ultravioletLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF1ECFE),
  card: Color(0xFFFCFBFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFE4DEF7),
  primary: Color(0xFF6A34D6),
  primaryText: Color(0xFF6A34D6),
  caramel: Color(0xFF6E4FB0),
  text: Color(0xFF1C1633),
  textSecondary: Color(0xFF443C63),
  muted: Color(0xFF655C82),
  faint: Color(0xFF6C647F),
  warning: Color(0xFFC23A1B),
  warningStrong: Color(0xFF9C2C12),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFEEEAFB),
  positiveBorder: Color(0xFFD6CCF4),
  overlay: Color.fromRGBO(26, 16, 48, 0.42),
);
const _voltageDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF0A0B10),
  card: Color(0xFF14161F),
  surfaceRaised: Color(0xFF1C1F2B),
  border: Color(0xFF272B39),
  primary: Color(0xFF4C8DFF),
  primaryText: Color(0xFF4C8DFF),
  caramel: Color(0xFF94B5F2),
  text: Color(0xFFF1F4FB),
  textSecondary: Color(0xFFC7CFDE),
  muted: Color(0xFF858FA3),
  faint: Color(0xFF768093),
  warning: Color(0xFFFFA13D),
  warningStrong: Color(0xFFFF7E33),
  onPrimary: Color(0xFF04122B),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF111C30),
  positiveBorder: Color(0xFF1E3355),
  overlay: Color.fromRGBO(3, 4, 8, 0.66),
);
const _voltageLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFEAF0FB),
  card: Color(0xFFFAFBFE),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFDCE1EC),
  primary: Color(0xFF1F5AD6),
  primaryText: Color(0xFF1F5AD6),
  caramel: Color(0xFF3A5AA8),
  text: Color(0xFF111521),
  textSecondary: Color(0xFF333B4E),
  muted: Color(0xFF586074),
  faint: Color(0xFF626A7E),
  warning: Color(0xFFB4551A),
  warningStrong: Color(0xFF924213),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE3ECF9),
  positiveBorder: Color(0xFFC2D3F0),
  overlay: Color.fromRGBO(8, 12, 22, 0.42),
);
const _emberDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF1B1613),
  card: Color(0xFF271F1B),
  surfaceRaised: Color(0xFF322824),
  border: Color(0xFF403129),
  primary: Color(0xFFFF7A54),
  primaryText: Color(0xFFFF7A54),
  caramel: Color(0xFFF0B48A),
  text: Color(0xFFFBF3EC),
  textSecondary: Color(0xFFE0D2C6),
  muted: Color(0xFFAC9A8C),
  faint: Color(0xFF958578),
  warning: Color(0xFFFF556E),
  // Lifted five points from F53A57, which measured 4.33 against Ember's
  // slightly lighter card and was genuinely under AA rather than on the line.
  // Same reason as Barako above: this colour carries 13pt subtotals.
  warningStrong: Color(0xFFFA3F5C),
  onPrimary: Color(0xFF2A0E04),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF2E2016),
  positiveBorder: Color(0xFF55402C),
  overlay: Color.fromRGBO(12, 8, 6, 0.64),
);
const _emberLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFFBF4EE),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFEBDDD1),
  primary: Color(0xFFC1401C),
  primaryText: Color(0xFFC1401C),
  caramel: Color(0xFF9A5A2C),
  text: Color(0xFF241812),
  textSecondary: Color(0xFF4A382E),
  muted: Color(0xFF6E5A4C),
  faint: Color(0xFF7F6B5C),
  warning: Color(0xFFB41F3C),
  warningStrong: Color(0xFF911730),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFF3E7D8),
  positiveBorder: Color(0xFFE2CBAF),
  overlay: Color.fromRGBO(28, 16, 8, 0.42),
);
const _orchidgoldDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF180E22),
  card: Color(0xFF241634),
  surfaceRaised: Color(0xFF2E1D42),
  border: Color(0xFF3D2755),
  primary: Color(0xFFF268B0),
  primaryText: Color(0xFFF268B0),
  caramel: Color(0xFFE0A8D6),
  text: Color(0xFFF8EFF6),
  textSecondary: Color(0xFFDCCAD8),
  muted: Color(0xFFA891AA),
  faint: Color(0xFF937D97),
  warning: Color(0xFFFF7A45),
  warningStrong: Color(0xFFF55A2C),
  onPrimary: Color(0xFF2B0A1E),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF28193A),
  positiveBorder: Color(0xFF4A2F63),
  overlay: Color.fromRGBO(10, 5, 16, 0.64),
);
const _orchidgoldLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF7EDF4),
  card: Color(0xFFFEFAFD),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFEBD9E8),
  primary: Color(0xFFB01C6E),
  primaryText: Color(0xFFB01C6E),
  caramel: Color(0xFF8A3A78),
  text: Color(0xFF241020),
  textSecondary: Color(0xFF483042),
  muted: Color(0xFF6E566A),
  faint: Color(0xFF7E667D),
  warning: Color(0xFFBC3A16),
  warningStrong: Color(0xFF992C0F),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFF3E4F0),
  positiveBorder: Color(0xFFE1C6DC),
  overlay: Color.fromRGBO(26, 10, 22, 0.42),
);
const _forestDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF101E15),
  card: Color(0xFF1A2C20),
  surfaceRaised: Color(0xFF22382A),
  border: Color(0xFF33503D),
  primary: Color(0xFFFFA45C),
  primaryText: Color(0xFFFFA45C),
  caramel: Color(0xFFE8B98B),
  text: Color(0xFFFBF7EF),
  textSecondary: Color(0xFFD9D6C5),
  muted: Color(0xFF9DAF9D),
  faint: Color(0xFF83947F),
  warning: Color(0xFFFF6B7E),
  warningStrong: Color(0xFFFF4D66),
  onPrimary: Color(0xFF3A1E07),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF243424),
  positiveBorder: Color(0xFF4A6247),
  overlay: Color.fromRGBO(8, 14, 9, 0.62),
);
// Retuned 2026-07-26, because Forest in light mode WAS Barako. Thirteen of the
// seventeen tokens differed by 10 or less out of 255, four were identical to
// the byte, and the two backgrounds differed by 1. Nobody could see any of it.
// Forest's identity lived entirely in its dark palette, so a light-mode user
// picked "Warm orange on deep green", got cream, and reasonably concluded the
// picker was broken.
//
// The fix moves the SURFACES green (the tokens that cover most of the screen)
// and the win color to a deep olive, the light-mode answer to the dark
// palette's lime. The orange primary is deliberately unchanged: warm orange on
// green IS the theme, and it is what the name promises.
//
// Distance was checked against every other light palette, not just Barako.
// When the win color went theme-invariant (2026-08-07) it stopped counting
// toward theme identity, and background became the pair's whole distance, so
// it moved two more points green (E9 to E7 in the red channel): 16 away from
// Barako per channel, above the 15 floor appearance_test holds every pair to.
// Every contrast pair still clears AA; primary on background is 4.72 and faint
// on background 4.76, above the 4.50 floor Orchid Gold light already sets.
const _forestLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFE7F1E1),
  card: Color(0xFFFAFDF6),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFD6E1C8),
  // Darkened from RN's #B4581E, which was 4.28 on the old background (below AA)
  // as small money text. #A85018 clears it (4.74 on bg, 5.34 on card).
  // RN has the same too-light value; tracked as a separate RN follow-up.
  primary: Color(0xFFA85018),
  primaryText: Color(0xFFA85018),
  caramel: Color(0xFF5C6B3A),
  text: Color(0xFF1B2116),
  textSecondary: Color(0xFF3E4A34),
  muted: Color(0xFF616B55),
  faint: Color(0xFF626C56),
  warning: Color(0xFFB01E38),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFDFEBD2),
  positiveBorder: Color(0xFFC2D4A8),
  overlay: Color.fromRGBO(16, 26, 14, 0.45),
);
const _mintDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF0B1210),
  card: Color(0xFF141F1A),
  surfaceRaised: Color(0xFF1C2A23),
  border: Color(0xFF23372E),
  primary: Color(0xFF2FD48F),
  primaryText: Color(0xFF2FD48F),
  caramel: Color(0xFF86C7A8),
  text: Color(0xFFF2FBF6),
  textSecondary: Color(0xFFC6D6CD),
  muted: Color(0xFF8FA39A),
  faint: Color(0xFF768980),
  warning: Color(0xFFF2A05F),
  warningStrong: Color(0xFFE0633A),
  onPrimary: Color(0xFF04261A),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF12291E),
  positiveBorder: Color(0xFF1F4A36),
  overlay: Color.fromRGBO(5, 12, 9, 0.62),
);
const _mintLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF2F7F4),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFDCE7E0),
  primary: Color(0xFF157A5B),
  primaryText: Color(0xFF157A5B),
  caramel: Color(0xFF2E7357),
  text: Color(0xFF101B16),
  textSecondary: Color(0xFF33443D),
  muted: Color(0xFF5D6E66),
  faint: Color(0xFF62736B),
  warning: Color(0xFFB84A22),
  warningStrong: Color(0xFF93381A),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE4F3EB),
  positiveBorder: Color(0xFFBFE0D0),
  overlay: Color.fromRGBO(10, 20, 15, 0.45),
);

/// Every theme, ordered as a HUE WALK that starts at the brand and circles back
/// to it: orange, coral, magenta, violet, blue, aqua, green, green with orange.
///
/// The order is not decoration. The eye can only compare swatches that sit next
/// to each other, so the previous order (brand first, then a "trust and fun
/// trio", then greens) hid the very comparisons a picker exists to make: the
/// three warm themes sat at positions 1, 5 and 7, so Ember was never next to
/// Barako and read as "Barako again, I think". Every near twin is now adjacent,
/// which turns a suspicion into a visible difference. First position still
/// reads as "recommended", which is why Barako stays there.
///
/// Labels carry NO emoji. They used to, which broke the icon rule in CLAUDE.md
/// (emoji are for icons the USER picked; a theme name is ours), announced as
/// "hot beverage Barako" to a screen reader, rendered as boxes in the review
/// harness so this row could never be looked at, and, worst, left the emoji at
/// its own fixed colors on the SELECTED chip while the label flipped to
/// onPrimary, so the selected theme read half broken on the one screen whose
/// whole job is being credible about color. The color preview is the icon now.
///
/// Hints are short enough to sit on two lines in a tile column, and each one
/// tries to answer "how is this different from the one beside it" rather than
/// to sound nice. Ember names Barako directly, because that is the only
/// question anyone has about Ember.
///
/// NO LONGER generated from mobile/theme.js. The two drifted (order, and the
/// mint hint) before this change and have now diverged deliberately: the light
/// Forest palette below is fixed here and left alone in RN, which stays frozen
/// for testers. Treat the RN file as a sibling, not a source.
const List<BarakoTheme> barakoThemes = [
  BarakoTheme(
    key: 'barako',
    label: 'Barako',
    hint: 'Roasted orange on dark coffee.',
    light: _barakoLight,
    dark: _barakoDark,
  ),
  BarakoTheme(
    key: 'ember',
    label: 'Ember',
    hint: 'Coral on charcoal. Barako, hotter.',
    light: _emberLight,
    dark: _emberDark,
  ),
  BarakoTheme(
    key: 'orchidgold',
    label: 'Orchid Gold',
    hint: 'Berry plum, gold for wins.',
    light: _orchidgoldLight,
    dark: _orchidgoldDark,
  ),
  BarakoTheme(
    key: 'ultraviolet',
    label: 'Ultraviolet',
    hint: 'Midnight violet, soft lavender.',
    light: _ultravioletLight,
    dark: _ultravioletDark,
  ),
  BarakoTheme(
    key: 'voltage',
    label: 'Voltage',
    hint: 'Ink black, electric blue.',
    light: _voltageLight,
    dark: _voltageDark,
  ),
  BarakoTheme(
    key: 'tidal',
    label: 'Tidal',
    hint: 'Deep navy, vivid aqua.',
    light: _tidalLight,
    dark: _tidalDark,
  ),
  BarakoTheme(
    key: 'mint',
    label: 'Mint',
    hint: 'Spring green, honey gold.',
    light: _mintLight,
    dark: _mintDark,
  ),
  BarakoTheme(
    key: 'forest',
    label: 'Forest',
    hint: 'Deep green, warm orange.',
    light: _forestLight,
    dark: _forestDark,
  ),
];

/// The appearance modes, matching the RN app.
const List<String> appearanceModes = ['system', 'light', 'dark'];

/// The theme for a key, falling back to Barako (the brand) for anything unknown
/// (e.g. the retired milktea, or a newer backup's theme).
BarakoTheme themeForKey(dynamic key) {
  for (final t in barakoThemes) {
    if (t.key == key) return t;
  }
  return barakoThemes.first;
}

/// The stored (themeKey, themeMode) choice, backward compatible with the old
/// single settings.themeMood value so existing installs and backups still theme
/// sensibly. The new keys win when present; otherwise the legacy mood maps on
/// (latte was light Barako, barako was dark Barako, milktea folds into dark
/// Barako). A fresh install with neither follows the system.
(String, String) resolveThemeChoice(dynamic settings) {
  final s = settings is Map ? settings : const {};
  final k = s['themeKey'];
  final m = s['themeMode'];
  if (k is String || m is String) {
    return (k is String ? k : 'barako', m is String ? m : 'system');
  }
  switch (s['themeMood']) {
    case 'latte':
      return ('barako', 'light');
    case 'barako':
      return ('barako', 'dark');
    case 'milktea':
      return ('barako', 'dark');
  }
  return ('barako', 'system');
}

/// Resolve an appearance mode plus the OS brightness to the brightness to show.
Brightness effectiveBrightness(String mode, Brightness os) {
  switch (mode) {
    case 'light':
      return Brightness.light;
    case 'dark':
      return Brightness.dark;
    default:
      return os; // 'system'
  }
}

/// The color namespace every screen reads. Members are getters over the active
/// palette so a theme or mode switch repaints the whole app on rebuild.
class Barako {
  static BarakoTheme currentTheme = barakoThemes.first;
  static BarakoPalette current = barakoThemes.first.light;

  static Color get background => current.background;
  static Color get card => current.card;
  static Color get surfaceRaised => current.surfaceRaised;
  static Color get border => current.border;
  static Color get primary => current.primary;
  static Color get primaryText => current.primaryText;
  static Color get caramel => current.caramel;
  static Color get text => current.text;
  static Color get textSecondary => current.textSecondary;
  static Color get muted => current.muted;
  static Color get faint => current.faint;
  static Color get warning => current.warning;
  static Color get warningStrong => current.warningStrong;
  static Color get onPrimary => current.onPrimary;
  static Color get celebrate => current.celebrate;
  static Color get positiveSurface => current.positiveSurface;
  static Color get positiveBorder => current.positiveBorder;
  static Color get overlay => current.overlay;

  /// The face for THE ONE NUMBER on a screen, at 30 or larger.
  ///
  /// It is Plus Jakarta Sans, the same family as everything else, and the
  /// reason is a bug rather than taste. This used to be Fraunces, a display
  /// serif. Fraunces draws ₱ with a long crossbar, and next to a minus sign
  /// the two run together into what reads as a line STRUCK THROUGH the number:
  /// "-₱720" looked like a crossed-out ₱720, on every negative figure in the
  /// app. The founder saw it on their phone, said the old React Native app
  /// looked better, and was right; the old app loads no custom font at all, so
  /// every screen there is the plain Android system face.
  ///
  /// The choice was made by rendering the same figures in every candidate and
  /// LOOKING (test/font_compare.dart). Jakarta separates the minus cleanly,
  /// keeps the app's own character instead of looking like stock Android, and
  /// unlike Fraunces it ships a real `tnum` table, so a hero number can hold
  /// its column when it changes rather than jittering.
  ///
  /// The old argument for a second family was that a different face says "this
  /// is the headline" without spending size. True, and not worth a struck
  /// through peso figure. Size, weight and colour already say it.
  ///
  /// One constant, deliberately, so this is one edit and not forty. There is a
  /// test that fails on any file naming a font family directly.
  static const displayFont = 'Jakarta';

  /// The workhorse: every sentence, label, heading and row amount.
  ///
  /// Same family as [displayFont] today. They are kept as two constants
  /// anyway, because they answer two different questions ("what does a hero
  /// number look like" and "what does prose look like") and collapsing them
  /// would mean a future decision to give hero numbers their own face again
  /// has to be un-collapsed first.
  ///
  /// It exists mainly for the share images. Those draw off-screen into a
  /// picture and do NOT inherit the app's text theme, so every Text in them
  /// has to name a family, and twelve of them named it as a raw string. That
  /// is exactly how a font change ships everywhere the founder looks and
  /// nowhere they do not, until somebody shares a win and sees the old face.
  static const bodyFont = 'Jakarta';

  /// The section kicker: the small uppercase label above a card's content.
  ///
  /// 12/w600/1.2 rather than the old 11/w700/2. The old tracking was 0.18em,
  /// which shouts; 1.2 at 12 is 0.10em, which is what an overline wants. The
  /// new style is very slightly NARROWER per character (8.6 against 8.8), so
  /// nothing that fitted before can overflow now.
  static TextStyle get kickerStyle => TextStyle(
    color: current.muted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// The kicker for a label INSIDE a card, in the warm accent rather than
  /// muted. Splitting the two is what stops a screen of cards reading
  /// utilitarian: the outside label orients, the inside label belongs to its
  /// card. Contrast was checked across all sixteen palettes; caramel on card
  /// ranges 5.42 to 9.75, so every one clears AA for small text.
  static TextStyle get cardKickerStyle =>
      kickerStyle.copyWith(color: current.caramel);
}

/// The spacing ladder. Anything outside it is a bug.
///
/// Ported from the React Native app's scale so the two stay in step. Before
/// this the Flutter app hand typed 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22
/// and 24, plus a literal 12.5 font size, so there was no rhythm to read.
///
/// The semantic rules, written once so screens stop deciding per file:
/// - Screen edge: [gutter] (20) on the left and right, every screen.
/// - Between cards: [lg] (16), the one vertical rhythm.
/// - Inside a standard card: [lg] (16) padding.
/// - Inside the one raised hero card: [gutter] (20) padding, so the headline
///   surface visibly breathes more than the furniture.
class Gap {
  const Gap._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// The standard gap between cards. Was 12 in 95 places, which is most of
  /// what "the other app feels more generous" actually was. Also the standard
  /// card interior padding.
  static const double lg = 16;

  /// The screen edge, and the hero card's interior padding. The horizontal 20
  /// was already the app's de facto gutter; this names it so a screen cannot
  /// quietly ship 16 on one edge and 20 on the other.
  static const double gutter = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The two scroll paddings a screen body uses, so LTRB literals stop drifting.
class Insets {
  const Insets._();

  /// A plain scrollable screen: gutter sides, room to breathe at the bottom.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(
    Gap.gutter,
    Gap.lg,
    Gap.gutter,
    Gap.xxl,
  );

  /// A tab screen, whose scroll end must clear the floating action button.
  static const EdgeInsets tabScreen = EdgeInsets.fromLTRB(
    Gap.gutter,
    Gap.lg,
    Gap.gutter,
    96,
  );

  /// Standard card interior.
  static const EdgeInsets card = EdgeInsets.all(Gap.lg);

  /// The one raised hero card's interior.
  static const EdgeInsets hero = EdgeInsets.all(Gap.gutter);
}

/// Corner radii, cut around the geometry that actually ships. Heroes get more
/// corner than furniture, so the eye can tell the headline from the supporting
/// cast without reading it.
///
/// Semantic rungs are the system; a screen names what a corner IS (a control,
/// a field, a card) and this class decides the number. One rule rides along:
/// an InkWell that fills a card takes the card's own radius, so the tap ripple
/// clips at the corner the eye already sees.
class Radii {
  const Radii._();

  /// Chips, inline controls, small tiles. This legalizes the 12 the app
  /// already uses in over a hundred places; it was the most used radius in
  /// the app and the only one with no name.
  static const double control = 12;

  /// Inputs and buttons.
  static const double field = 14;

  /// Cards and dialogs. The theme's card shape reads this.
  static const double card = 20;

  /// Bottom sheet top corners, set once in the theme's bottomSheetTheme so
  /// the log and edit sheets stop disagreeing about their own doorway.
  static const double sheet = 24;

  /// The one raised hero surface.
  static const double hero = 26;
  static const double pill = 999;

  // The legacy aliases (sm=10, md, lg, xl) that let the migration move screen
  // by screen are GONE as of Phase 2: every call site now names a semantic
  // rung, and the 10-radius sm sites snapped up to control (12) as their doc
  // always said they would on conversion. A source-scanning guard in
  // design_foundation_test.dart fails if any of the four names comes back, so
  // one number can never carry two names again.
}

/// The opacity ladder. Four names instead of the 23 ad-hoc alpha levels the
/// screens grew, so a wash cannot drift one file at a time.
///
/// The scrim deliberately has no rung here: a modal barrier needs a different
/// strength per palette (dark themes scrim darker), so it stays the palette's
/// own [BarakoPalette.overlay].
class BarakoAlpha {
  const BarakoAlpha._();

  /// The faintest presence of a color: a tinted card background, a hover.
  static const double wash = 0.06;

  /// A visible tint that still reads as background: selected-state fills,
  /// icon discs.
  static const double tint = 0.12;

  /// The strongest wash: a color you notice but never read text against.
  static const double hint = 0.24;
}

// THE SURFACE MODEL, the app's entire elevation story:
//
// - Level 0, the screen: BarakoPalette.background. Nothing sits below it.
// - Level 1, a reading surface: BarakoPalette.card with a border hairline.
//   Identified by FILL, not by shadow.
// - Level 2, the hero: BarakoPalette.surfaceRaised with a border. ONE per
//   screen, the screen's headline. Two raised surfaces is zero heroes.
// - Overlay: the palette's BarakoPalette.overlay scrim behind modals.
//
// Borders over shadows, deliberately. The only shadow in the app is the
// floating action button's elevation 2; cards never cast one. Hierarchy is
// carried by surface contrast, borders, spacing and type, which is why a
// screenshot of any theme still reads as Salapify with the shadows off.

/// Motion tokens: five durations, one curve, and the reduce-motion gate.
///
/// Grounded in the values the app already shipped rather than imported from a
/// spec: tap is the pressable dip, state absorbs the 160/180/200 crossfades,
/// move the 220 to 260 slides, reveal the 300 to 420 fills and flips.
class Motion {
  const Motion._();

  /// A press acknowledging a finger (the pressable dip).
  static const Duration tap = Duration(milliseconds: 120);

  /// A state change in place: fills, crossfades, selection moves.
  static const Duration state = Duration(milliseconds: 160);

  /// Something traveling: page turns, scroll-into-view.
  static const Duration move = Duration(milliseconds: 240);

  /// A reveal that earns a beat: the card flip, a progress fill.
  static const Duration reveal = Duration(milliseconds: 420);

  /// Confetti only. Reserved the way the gold is reserved.
  static const Duration celebrate = Duration(milliseconds: 1400);

  /// The one curve. Thirteen of fourteen animation sites already used it.
  static const Curve curve = Curves.easeOut;

  /// The reduce-motion gate: pass every animation duration through this and
  /// the accessibility setting becomes the system's default behavior instead
  /// of something each screen has to remember. Returns [Duration.zero] when
  /// the user asked the OS to disable animations.
  ///
  /// The aspect-scoped lookup, not MediaQuery.maybeOf: the whole-object read
  /// would rebuild every adopting widget on ANY media change, including each
  /// keyboard open, which matters once Phase 2 spreads this across the app.
  static Duration of(BuildContext context, Duration duration) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : duration;
}

/// The haptic vocabulary. Three words, used for exactly three meanings, so a
/// buzz keeps meaning something:
///
/// - [select]: a choice or position change (a chip, a segment, a scrub step).
/// - [moneyWritten]: a successful financial write. The save moment, felt.
/// - [milestone]: a celebration-grade win. Reserved like the gold.
///
/// NEVER a haptic on a failed, blocked, gated or invalid action. A buzz says
/// "that worked"; buzzing a rejection teaches the hand to distrust every
/// other buzz in the app. Adoption across screens is a later phase; this
/// class exists so that phase adds calls, not decisions.
class Haptics {
  const Haptics._();
  static void select() => HapticFeedback.selectionClick();
  static void moneyWritten() => HapticFeedback.lightImpact();
  static void milestone() => HapticFeedback.mediumImpact();
}

/// Icon sizes, named once. Special artwork (Pan, the bank cards) is art, not
/// iconography, and does not pass through these.
class IconSizes {
  const IconSizes._();

  /// Dense metadata beside small text.
  static const double dense = 16;

  /// The standard inline icon.
  static const double inline = 20;

  /// Bottom navigation glyphs.
  static const double nav = 22;

  /// The major disc icon (salapify_icon's orange disc).
  static const double disc = 40;
}

/// The theme for one palette (one theme in one brightness).
ThemeData salapifyTheme([BarakoPalette? palette]) {
  final p = palette ?? Barako.current;
  final isLight = p.brightness == Brightness.light;
  final scheme = isLight
      ? ColorScheme.light(
          primary: p.primary,
          onPrimary: p.onPrimary,
          surface: p.card,
          onSurface: p.text,
          secondary: p.caramel,
          onSecondary: p.onPrimary,
          error: p.warningStrong,
        )
      : ColorScheme.dark(
          primary: p.primary,
          onPrimary: p.onPrimary,
          surface: p.card,
          onSurface: p.text,
          secondary: p.caramel,
          onSecondary: p.onPrimary,
          error: p.warning,
        );
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    fontFamily: 'Jakarta',
    scaffoldBackgroundColor: p.background,
    colorScheme: scheme,
    splashColor: p.primary.withValues(alpha: BarakoAlpha.wash),
    highlightColor: p.primary.withValues(alpha: BarakoAlpha.wash),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        side: BorderSide(color: p.border),
      ),
    ),
    dividerColor: p.border,
    // The one AppBar. Every screen used to repeat this trio of properties (30
    // copies, one already diverged); the theme owns it now, so a bare AppBar
    // with just a title is already correct.
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: p.text,
      ),
      // No size here: the audit names no AppBar icon size, and setting one
      // would resize every screen's chrome as a side effect. Icons keep the
      // Material 24 until a phase decides otherwise on purpose.
      iconTheme: IconThemeData(color: p.text),
    ),
    // The one bottom-sheet doorway: card surface, Radii.sheet top corners,
    // the palette's own scrim. The log and edit sheets each declared their
    // own surface and radius and disagreed; sheets that stop passing
    // overrides land here.
    // No clipBehavior here, deliberately: thirteen shipped sheets pass a
    // transparent background and draw their own rounded container inside, and
    // a theme-level Clip.antiAlias would shave their corners at the theme's
    // radius instead of their own (QA finding, f3.74). Clipping joins in
    // Phase 2 when those sheets adopt the theme surface.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      modalBackgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: p.overlay,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.primary,
      // Five tabs share the width. The 10px labels date from the six-tab era;
      // they still keep every label on one line down to a 320dp phone, and
      // raising them is a separate, sweep-verified decision.
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 10,
          // w700, not w800: heavy is reserved for money and page titles
          // (typography.dart), and at 10px the two are barely separable
          // anyway. The indicator pill and the filled glyph carry the
          // selected state; the label only assists.
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          letterSpacing: 0.1,
          color: states.contains(WidgetState.selected) ? p.text : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: IconSizes.nav,
          color: states.contains(WidgetState.selected) ? p.onPrimary : p.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight ? p.text : p.surfaceRaised,
      contentTextStyle: TextStyle(
        fontFamily: 'Jakarta',
        color: isLight ? p.card : p.text,
        fontSize: 14,
      ),
      // The default action color is the brand primary. celebrate is passed
      // explicitly only on win/streak snackbars, so the gold stays earned.
      actionTextColor: p.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        side: isLight ? BorderSide.none : BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        // bodyLg, not Material's 14: a filled button IS the primary action,
        // and the app's main CTAs were all hand-raising themselves to 16
        // anyway. One size here beats a size at forty call sites.
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: p.border),
        foregroundColor: p.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    // The one chip: background fill, border, secondary ink at label size,
    // Radii.control corners, selected fill in the accent, and the default
    // MaterialTapTargetSize keeping the touch target at 48.
    //
    // The labelStyle is deliberately a PLAIN TextStyle, not a
    // WidgetStateTextStyle. The chip framework merges the theme style UNDER a
    // chip's own labelStyle (labelStyle.merge(widget.labelStyle)), and a
    // WidgetStateTextStyle carries all its fields inside resolve(), so the
    // merge reads every field as null and the family silently falls off:
    // chips rendered in the fallback face, and the readability sweep caught
    // the widened labels overflowing the loan calculator before it shipped.
    // Until the framework resolves states through that merge, the selected
    // label color stays a call-site concern (every ChoiceChip site already
    // sets it), consolidated in Phase 2's chip adoption.
    chipTheme: ChipThemeData(
      backgroundColor: p.background,
      selectedColor: p.primary,
      disabledColor: p.background,
      side: BorderSide(color: p.border),
      // The COLOR field alone is per-state: the chip framework resolves a
      // WidgetStateColor inside the label style even though it merges the
      // style object itself, so a bare selected chip gets onPrimary ink on
      // the primary fill instead of unreadable textSecondary-on-accent.
      labelStyle: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 14,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onPrimary
              : p.textSecondary,
        ),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      showCheckmark: false,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.border,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      // The extended FAB's label, owned here so the Log button's weight is a
      // theme decision, not a call-site restyle.
      extendedTextStyle: const TextStyle(
        fontFamily: 'Jakarta',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    ),
    // The one input decoration, complete enough that a bare TextField is
    // already right. Fifteen-plus screens grew private _decor helpers because
    // this theme used to define only three of the states; those helpers stay
    // for now (they override this wholesale) and Phase 2 deletes them.
    //
    // Fill is the CARD surface: most inputs sit on the background scaffold,
    // where a card-colored field reads as a place to type. On a card-surfaced
    // sheet the fill matches the sheet and the border alone carries the
    // outline, which is the standard outlined-input look, not a defect.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: TextStyle(fontFamily: 'Jakarta', color: p.faint),
      labelStyle: TextStyle(fontFamily: 'Jakarta', color: p.textSecondary),
      floatingLabelStyle: TextStyle(fontFamily: 'Jakarta', color: p.primary),
      errorStyle: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 12,
        color: scheme.error,
      ),
      // 12 horizontal, not 16: narrow fixed-width fields (the calculators'
      // 110dp term and rate inputs) size their hints against this, and 16
      // ellipsized "e.g. 1.5" in the loan calculator. The readability sweep
      // is the arbiter here, not taste.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: p.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
      // Disabled reads as inert: the same border at the strongest wash the
      // ladder allows, so the outline recedes without inventing a new alpha.
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(
          color: p.border.withValues(alpha: BarakoAlpha.hint),
        ),
      ),
    ),
  );
}

/// Kept for callers and tests that want the brand light theme explicitly.
ThemeData kapeLatteTheme() => salapifyTheme(themeForKey('barako').light);
