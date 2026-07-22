// The Salapify theme system. Ported to match the live React Native app: each
// THEME carries a light and a dark palette, and a separate appearance mode
// (light | dark | system) picks which one shows. system follows the phone, so
// the app goes dark at night on its own. The eight themes and their exact hex
// values come straight from mobile/theme.js (generated, so the colors match the
// AA-checked RN values to the byte).
//
// Barako stays the color namespace every screen reads (Barako.text and so on),
// but the members are getters over the ACTIVE palette, resolved from the chosen
// theme and the effective brightness and rebuilt from the app root. That is why
// the screens avoid const on color-bearing widgets: const would freeze the
// palette, and now the palette can change with no tap at all (the OS flipping to
// dark at night repaints the whole tree). See analysis_options.yaml.

import 'package:flutter/material.dart';

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
  BarakoPalette resolve(Brightness b) =>
      b == Brightness.dark ? dark : light;
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
  warningStrong: Color(0xFFF5384F),
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
  celebrate: Color(0xFFFFD24A),
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
  celebrate: Color(0xFF8A6400),
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
  celebrate: Color(0xFFC6FF4A),
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
  celebrate: Color(0xFF526E00),
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
  celebrate: Color(0xFFFF5CA8),
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
  celebrate: Color(0xFFB01C6E),
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
  warningStrong: Color(0xFFF53A57),
  onPrimary: Color(0xFF2A0E04),
  celebrate: Color(0xFFFFB020),
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
  celebrate: Color(0xFFF7C64B),
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
  celebrate: Color(0xFF8A6000),
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
  celebrate: Color(0xFFA8E85C),
  positiveSurface: Color(0xFF243424),
  positiveBorder: Color(0xFF4A6247),
  overlay: Color.fromRGBO(8, 14, 9, 0.62),
);
const _forestLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF6F1E7),
  card: Color(0xFFFFFCF5),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFE3DBC9),
  // Darkened from RN's #B4581E, which was 4.28 on this background (below AA)
  // as small money text. #A85018 clears it (about 4.88 on bg, 5.36 on card).
  // RN has the same too-light value; tracked as a separate RN follow-up.
  primary: Color(0xFFA85018),
  primaryText: Color(0xFFA85018),
  caramel: Color(0xFF7A5A2E),
  text: Color(0xFF221E15),
  textSecondary: Color(0xFF4A443A),
  muted: Color(0xFF6E675C),
  faint: Color(0xFF726B60),
  warning: Color(0xFFB01E38),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A6200),
  positiveSurface: Color(0xFFEFE9D3),
  positiveBorder: Color(0xFFD8CCA8),
  overlay: Color.fromRGBO(30, 24, 12, 0.45),
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
  celebrate: Color(0xFFFFD166),
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
  celebrate: Color(0xFF946300),
  positiveSurface: Color(0xFFE4F3EB),
  positiveBorder: Color(0xFFBFE0D0),
  overlay: Color.fromRGBO(10, 20, 15, 0.45),
);

/// Every theme, brand first (trust and fun trio next, greens last). Each
/// carries a light and a dark palette. Generated from mobile/theme.js.
const List<BarakoTheme> barakoThemes = [
  BarakoTheme(key: 'barako', label: '☕ Barako', hint: 'Roasted orange on dark-roast coffee. The Salapify look.',
      light: _barakoLight, dark: _barakoDark),
  BarakoTheme(key: 'tidal', label: '🌊 Tidal', hint: 'Deep navy with a vivid aqua pop.',
      light: _tidalLight, dark: _tidalDark),
  BarakoTheme(key: 'ultraviolet', label: '🔮 Ultraviolet', hint: 'Midnight violet with an electric-lime glow.',
      light: _ultravioletLight, dark: _ultravioletDark),
  BarakoTheme(key: 'voltage', label: '⚡ Voltage', hint: 'Ink black with an electric-blue current.',
      light: _voltageLight, dark: _voltageDark),
  BarakoTheme(key: 'ember', label: '🔥 Ember', hint: 'Warm charcoal with a sunrise coral.',
      light: _emberLight, dark: _emberDark),
  BarakoTheme(key: 'orchidgold', label: '🏆 Orchid Gold', hint: 'Berry plum with gold trophies.',
      light: _orchidgoldLight, dark: _orchidgoldDark),
  BarakoTheme(key: 'forest', label: '🌲 Forest', hint: 'Warm orange on deep green.',
      light: _forestLight, dark: _forestDark),
  BarakoTheme(key: 'mint', label: '🌿 Mint', hint: 'Fresh spring green with a honey-gold win.',
      light: _mintLight, dark: _mintDark),
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

  /// The display serif for big peso amounts (Fraunces).
  static const displayFont = 'Fraunces';

  /// The one section-label style for the little uppercase kicker above a
  /// card's content. Not const: it carries the mood-driven muted color.
  static TextStyle get kickerStyle => TextStyle(
        color: current.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      );
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
    splashColor: p.primary.withValues(alpha: 0.08),
    highlightColor: p.primary.withValues(alpha: 0.05),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: p.border),
      ),
    ),
    dividerColor: p.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.primary,
      // Six tabs share the width, so the label type is a touch smaller and
      // tighter than the old five-tab bar to keep every label (even "Insights"
      // at w800) on one line down to a 320dp phone.
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          letterSpacing: 0.1,
          color: states.contains(WidgetState.selected) ? p.text : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color:
              states.contains(WidgetState.selected) ? p.onPrimary : p.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight ? p.text : p.surfaceRaised,
      contentTextStyle: TextStyle(
          fontFamily: 'Jakarta',
          color: isLight ? p.card : p.text,
          fontSize: 14),
      // The default action color is the brand primary. celebrate is passed
      // explicitly only on win/streak snackbars, so the gold stays earned.
      actionTextColor: p.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isLight ? BorderSide.none : BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Jakarta',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: p.border),
        foregroundColor: p.textSecondary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: const TextStyle(
            fontFamily: 'Jakarta', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.background,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(
          fontFamily: 'Jakarta',
          color: p.textSecondary,
          fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.background,
      hintStyle: TextStyle(fontFamily: 'Jakarta', color: p.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.4),
      ),
    ),
  );
}

/// Kept for callers and tests that want the brand light theme explicitly.
ThemeData kapeLatteTheme() => salapifyTheme(themeForKey('barako').light);
