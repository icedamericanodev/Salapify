// The Salapify theme system. Each THEME carries a light and a dark palette, and
// a separate appearance mode (light | dark | system) picks which one shows.
// system follows the phone, so the app goes dark at night on its own. The app
// ships FOUR curated themes (barakoThemes below); a longer list was trimmed to
// four by founder direction so the picker is a quick choice between distinct
// moods, not a scroll through near twins. Retired theme keys still resolve
// safely, falling back to the default (see themeForKey).
//
// Barako stays the color namespace every screen reads (Barako.text and so on),
// but the members are getters over the ACTIVE palette, resolved from the chosen
// theme and the effective brightness and rebuilt from the app root. That is why
// the screens avoid const on color-bearing widgets: const would freeze the
// palette, and now the palette can change with no tap at all (the OS flipping to
// dark at night repaints the whole tree). See analysis_options.yaml.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'theme/salapify_theme.dart';

export 'theme/salapify_theme.dart' show SalapifyColors, SalapifyThemePreset;

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

/// The four looks the app ships, curated down from a longer list by founder
/// direction: a person choosing between four distinct moods decides faster and
/// trusts the picker more than one scrolling a dozen near twins. Palawan Lagoon
/// is first because first position reads as "recommended", and it is the modern
/// default the whole app falls back to (themeForKey and Barako.current both key
/// off barakoThemes.first, so making Palawan first makes it the default and the
/// safe fallback for any retired theme a backup still names).
///
/// The four are visibly different by construction, not by luck: three dark
/// looks with distinct accents (emerald, coral, neon cyan) plus one light look
/// (Pearl). appearance_test proves no two are the same theme in either
/// brightness, and palette_contrast_test proves every pair clears WCAG AA.
///
/// Labels carry NO emoji. An emoji cannot be recolored by the palette, so on
/// the SELECTED tile the label flips to onPrimary while the emoji keeps its own
/// colors and the tile reads half broken; it also draws as a box in the review
/// harness, so the row could never be looked at. The color preview is the icon.
///
/// Hints are short enough to sit on two lines in a tile column, and each one
/// answers "how is this different from the others" rather than trying to sound
/// nice.
// --- f4.59 modern looks. Designed from the SalapifyColors presets
// (theme/salapify_theme.dart) and tuned so every pair clears WCAG AA in
// palette_contrast_test; the win gold stays theme-invariant (dark FFC24D, light
// 8A5A00), same rule as every other theme. Each carries both brightnesses so
// the picker and the system light/dark switch always have a coherent answer.

const _palawanDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF0B131F),
  card: Color(0xFF131F30),
  surfaceRaised: Color(0xFF1B2C44),
  border: Color(0xFF1E3A5F),
  primary: Color(0xFF00E5A3),
  primaryText: Color(0xFF34E7B0),
  caramel: Color(0xFF66E6C6),
  text: Color(0xFFF8FAFC),
  textSecondary: Color(0xFFC4D2E0),
  muted: Color(0xFF9FB2C6),
  faint: Color(0xFF93A6BB),
  warning: Color(0xFFF87086),
  warningStrong: Color(0xFFFB8D9D),
  onPrimary: Color(0xFF04231A),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF10241C),
  positiveBorder: Color(0xFF1E4034),
  overlay: Color.fromRGBO(4, 9, 15, 0.64),
);
const _palawanLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF4FAF8),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFD9E7E1),
  primary: Color(0xFF04795E),
  primaryText: Color(0xFF04795E),
  caramel: Color(0xFF0E6E86),
  text: Color(0xFF0B2A24),
  textSecondary: Color(0xFF3F6B60),
  muted: Color(0xFF4A6B63),
  faint: Color(0xFF557067),
  warning: Color(0xFFB0243C),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE2F3EC),
  positiveBorder: Color(0xFFCFE6DB),
  overlay: Color.fromRGBO(8, 28, 24, 0.42),
);

const _mayonDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF140E1B),
  card: Color(0xFF22172C),
  surfaceRaised: Color(0xFF31223E),
  border: Color(0xFF3A2A45),
  primary: Color(0xFFF27457),
  primaryText: Color(0xFFFF8A6E),
  caramel: Color(0xFFFFB27A),
  text: Color(0xFFFFF1F2),
  textSecondary: Color(0xFFFDA4AF),
  muted: Color(0xFFE7B4BE),
  faint: Color(0xFFDFA9B4),
  warning: Color(0xFFF87086),
  warningStrong: Color(0xFFFF9AAA),
  onPrimary: Color(0xFF2A0F08),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF15251C),
  positiveBorder: Color(0xFF2C4030),
  overlay: Color.fromRGBO(10, 7, 14, 0.64),
);
const _mayonLight = BarakoPalette(
  brightness: Brightness.light,
  // A warmer sunset peach, deep enough to read apart from Ember's cream page
  // (appearance_test's distinguishability floor); every text pair still clears
  // AA on it.
  background: Color(0xFFFFE8DC),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFF0DDD5),
  primary: Color(0xFFB3402A),
  primaryText: Color(0xFFB3402A),
  caramel: Color(0xFF8A4B20),
  text: Color(0xFF2A1712),
  textSecondary: Color(0xFF7A5348),
  muted: Color(0xFF6E4C42),
  faint: Color(0xFF795750),
  warning: Color(0xFFB0243C),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFF2E7E1),
  positiveBorder: Color(0xFFE7D3C8),
  overlay: Color.fromRGBO(28, 16, 10, 0.42),
);

const _obsidianDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF07090E),
  card: Color(0xFF0F141C),
  surfaceRaised: Color(0xFF171F2C),
  border: Color(0xFF1E293B),
  primary: Color(0xFF00F0FF),
  primaryText: Color(0xFF3DE0EC),
  caramel: Color(0xFF8FB4D9),
  text: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFAEBAC9),
  muted: Color(0xFF9DB0C4),
  faint: Color(0xFF8CA0B6),
  warning: Color(0xFFFF6B81),
  warningStrong: Color(0xFFFF8EA0),
  onPrimary: Color(0xFF03181C),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF0C2620),
  positiveBorder: Color(0xFF16463C),
  overlay: Color.fromRGBO(3, 4, 8, 0.66),
);
const _obsidianLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF6F8FB),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFFFFFFF),
  border: Color(0xFFE2E8F0),
  primary: Color(0xFF0E6E9E),
  primaryText: Color(0xFF0E6E9E),
  caramel: Color(0xFF0E6E86),
  text: Color(0xFF0B1622),
  textSecondary: Color(0xFF46586B),
  muted: Color(0xFF4E5E70),
  faint: Color(0xFF5A6A7C),
  warning: Color(0xFFB0243C),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE6F0F5),
  positiveBorder: Color(0xFFD3E3EC),
  overlay: Color.fromRGBO(7, 13, 22, 0.42),
);

const _pearlLight = BarakoPalette(
  brightness: Brightness.light,
  background: Color(0xFFF8FAFC),
  card: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFF1F5F9),
  border: Color(0xFFE2E8F0),
  primary: Color(0xFF005CEE),
  primaryText: Color(0xFF005CEE),
  caramel: Color(0xFF0D7A6E),
  text: Color(0xFF0F172A),
  textSecondary: Color(0xFF55606E),
  muted: Color(0xFF5B6472),
  faint: Color(0xFF64748B),
  warning: Color(0xFFC81E1E),
  warningStrong: Color(0xFF8C1329),
  onPrimary: Color(0xFFFFFFFF),
  celebrate: Color(0xFF8A5A00),
  positiveSurface: Color(0xFFE7F3EC),
  positiveBorder: Color(0xFFD3E7DA),
  overlay: Color.fromRGBO(15, 23, 42, 0.34),
);
const _pearlDark = BarakoPalette(
  brightness: Brightness.dark,
  background: Color(0xFF0B1220),
  card: Color(0xFF121A2A),
  surfaceRaised: Color(0xFF1B2536),
  border: Color(0xFF26334A),
  primary: Color(0xFF4D9AFF),
  primaryText: Color(0xFF6FB0FF),
  caramel: Color(0xFF8FB4D9),
  text: Color(0xFFF1F5F9),
  textSecondary: Color(0xFFC2CCD9),
  muted: Color(0xFFA7B4C4),
  faint: Color(0xFF98A6B8),
  warning: Color(0xFFFF6B81),
  warningStrong: Color(0xFFFF8EA0),
  onPrimary: Color(0xFF06121F),
  celebrate: Color(0xFFFFC24D),
  positiveSurface: Color(0xFF10241C),
  positiveBorder: Color(0xFF1E4034),
  overlay: Color.fromRGBO(5, 9, 16, 0.64),
);

const List<BarakoTheme> barakoThemes = [
  BarakoTheme(
    key: 'palawan',
    label: 'Palawan Lagoon',
    hint: 'Emerald and cyan on lagoon navy.',
    light: _palawanLight,
    dark: _palawanDark,
  ),
  BarakoTheme(
    key: 'mayon',
    label: 'Mayon Sunset',
    hint: 'Warm coral over a dusk plum.',
    light: _mayonLight,
    dark: _mayonDark,
  ),
  BarakoTheme(
    key: 'obsidian',
    label: 'BGC Obsidian',
    hint: 'Neon cyan on near-black titanium.',
    light: _obsidianLight,
    dark: _obsidianDark,
  ),
  BarakoTheme(
    key: 'pearl',
    label: 'Pearl',
    hint: 'Clean blue on a soft pearl white.',
    light: _pearlLight,
    dark: _pearlDark,
  ),
];

/// The appearance modes, matching the RN app.
const List<String> appearanceModes = ['system', 'light', 'dark'];

/// The theme for a key, falling back to the default (Palawan Lagoon, the first
/// theme) for anything unknown: a retired theme a backup still names (the eight
/// that were removed when the picker was curated to four, or the older milktea),
/// or a newer backup's theme this build does not have yet.
BarakoTheme themeForKey(dynamic key) {
  for (final t in barakoThemes) {
    if (t.key == key) return t;
  }
  return barakoThemes.first;
}

/// The stored (themeKey, themeMode) choice, backward compatible with the old
/// single settings.themeMood value so existing installs and backups still theme
/// sensibly. The new keys win when present; a retired themeKey still resolves,
/// falling back to the default at render (themeForKey). Otherwise the legacy
/// mood maps on, preserving only its brightness: latte was a light theme, barako
/// and milktea were dark, and all three now open on the default (Palawan). A
/// fresh install with neither follows the system.
(String, String) resolveThemeChoice(dynamic settings) {
  final s = settings is Map ? settings : const {};
  final k = s['themeKey'];
  final m = s['themeMode'];
  if (k is String || m is String) {
    return (k is String ? k : 'palawan', m is String ? m : 'system');
  }
  switch (s['themeMood']) {
    case 'latte':
      return ('palawan', 'light');
    case 'barako':
      return ('palawan', 'dark');
    case 'milktea':
      return ('palawan', 'dark');
  }
  return ('palawan', 'system');
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

  /// The one hero warmth, the coffee glow the Accounts hero wears where the
  /// mockup put a latte. A soft top-right wash of the brand accent over
  /// surfaceRaised, fading to plain surfaceRaised. ONE recipe, read live off
  /// the getters, so every hero that ever wants warmth pulls the same gradient
  /// and a mood switch cannot warm one screen and leave another cold.
  ///
  /// NOT const, the same rule as every colour getter: a const gradient would
  /// freeze the palette and go cold on a theme or night-mode flip. It never
  /// darkens below surfaceRaised, so it adds warmth without inventing a new
  /// elevation; hierarchy still comes from the fill and the border. The hot
  /// stop is [BarakoAlpha.tint] (0.12) rather than wash (0.06) because at 6%
  /// the orange was imperceptible over the near-black dark surface the founder
  /// runs, and only one corner ever reaches full strength.
  static LinearGradient get heroWash => LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color.alphaBlend(
        current.primary.withValues(alpha: BarakoAlpha.tint),
        current.surfaceRaised,
      ),
      current.surfaceRaised,
    ],
  );

  /// Categorical data colours for charts and category breakdowns: donut slices,
  /// legend dots, per-category bars. THEME-INVARIANT by rule, the same reasoning
  /// as the win gold and Pan's orange. A category should read as the same colour
  /// in every theme, so a screenshot of Food spending is Food spending whatever
  /// palette is chosen. These are the founder's "dopamine" palette. They are
  /// DATA colours, used only as fills and dots beside a printed label and
  /// amount, never as body text, so meaning never rides on colour alone. On a
  /// light card the brighter hues carry a hairline stroke for definition; on the
  /// near-black dark card they are already crisp. Distinctness and dark-surface
  /// visibility are enforced by data_palette_test.dart, not by this comment.
  static const List<Color> dataSeries = [
    Color(0xFFFF7A45), // dopamine orange
    Color(0xFF14B8A6), // dopamine teal
    Color(0xFF60A5FA), // soft blue
    Color(0xFF22C55E), // dopamine green
    Color(0xFFA78BFA), // soft violet
    Color(0xFFF472B6), // soft rose
  ];

  /// Positive money: income, a gain, a surplus, where the founder's spec wants
  /// green. Per-brightness because a single green cannot pass WCAG AA as small
  /// text on BOTH a white card and a near-black one: light needs a deep green,
  /// dark a bright one. Direction is still carried by the sign (a '+' or a real
  /// negative), never by colour alone, so a colour-blind reader keeps the
  /// meaning. Contrast is guarded by data_palette_test.
  static const Color _incomeLight = Color(0xFF15803D);
  static const Color _incomeDark = Color(0xFF34D058);
  static Color get income =>
      current.brightness == Brightness.dark ? _incomeDark : _incomeLight;

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
    // The forward-facing ThemeExtension, sourced from the SAME active palette
    // the screens read through Barako, so SalapifyColors.of(context) and Barako
    // can never disagree. New widgets may read this; existing ones keep reading
    // Barako. See theme/salapify_theme.dart.
    extensions: [
      SalapifyColors(
        primary: p.primary,
        secondary: p.caramel,
        background: p.background,
        surface: p.card,
        surfaceSubtle: p.surfaceRaised,
        textPrimary: p.text,
        textSecondary: p.textSecondary,
        cardBorder: p.border,
        accentSuccess: p.celebrate,
        accentDanger: p.warningStrong,
      ),
    ],
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
      // Four tabs share the width now (Home, Activity, Insights, Accounts),
      // down from five when Budget and Utang left the bar. The 10px labels date
      // from the six-tab era; with more room per tab they still keep every
      // label on one line down to a 320dp phone, and raising them is a
      // separate, sweep-verified decision.
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

/// Kept for callers and tests that want the default light theme explicitly.
ThemeData kapeLatteTheme() => salapifyTheme(barakoThemes.first.light);
