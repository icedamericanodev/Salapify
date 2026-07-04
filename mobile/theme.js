// theme.js holds all of our design tokens in one place: colors, spacing,
// corner radius, and font sizes. Every screen imports from here, so the look
// stays consistent and we can restyle the whole app by editing this one file.
//
// Color themes, each with dark and light variants:
//  - barako: the Salapify brand. Dark-roast espresso base (oat-milk latte in
//    light), roasted orange doing the dopamine work, caramel and amber for
//    kickers and wins. Warm café energy, never green.
//  - forest: an alternate theme. Deep forest green base with light orange.
//  - mint: an alternate theme. Near black green base with a glowing mint.
// Rules every theme shares: warning is reserved for debt and over limit
// states (never ordinary spending) and is a clearly different hue from the
// positive primary, celebrate appears only during earned moments, and every
// text pairing passes WCAG AA.

export const palettes = {
  // barako: the Salapify brand. Dark-roast espresso base, oat-milk latte in
  // light, roasted orange doing the dopamine work, warm caramel and amber
  // for kickers and wins. Warning is deliberately pushed to crimson (about
  // a 32 degree hue gap from the orange primary) so debt and over limit
  // never blur with positive money, which is warm orange. Every pairing
  // passes WCAG AA; the tightest is burnt orange as money text on the light
  // cream at 4.72, which is why the light primary is this deep.
  barako: {
    dark: {
      background: '#1A130E',
      card: '#251A13',
      border: '#3A2A20',
      primary: '#FF8A3D', // roasted orange: buttons, positive numbers, streaks
      softGreen: '#E9BC8E', // warm caramel kicker (legacy name, not green)
      text: '#FBF3E9', // steamed-milk cream
      textSecondary: '#E0CEBB',
      muted: '#A99182',
      faint: '#77624F',
      warning: '#FF5D73', // rose-crimson, distinct from the happy orange
      warningStrong: '#F5384F',
      onPrimary: '#2A1305', // espresso brown on orange fills
      celebrate: '#FFC24D', // amber gold
      positiveSurface: '#2E2114',
      positiveBorder: '#55402C',
      overlay: 'rgba(10,7,5,0.64)',
    },
    light: {
      background: '#F7F1E7', // oat-milk latte cream
      card: '#FFFDF7',
      border: '#E7DCC9',
      primary: '#AE5019', // deep roasted orange, passes AA as money text on cream
      softGreen: '#8A5A2E', // warm brown kicker
      text: '#241812',
      textSecondary: '#4A382E',
      muted: '#6E5A4C',
      faint: '#9A8574',
      warning: '#B01E38', // brick-crimson
      warningStrong: '#8C1329',
      onPrimary: '#FFFFFF',
      celebrate: '#8A5A00',
      positiveSurface: '#F3E7D5',
      positiveBorder: '#E2CBAF',
      overlay: 'rgba(28,16,8,0.42)',
    },
  },
  forest: {
    dark: {
      background: '#101E15',
      card: '#1A2C20',
      border: '#33503D',
      primary: '#FFA45C', // light orange: buttons, positive numbers
      softGreen: '#E8B98B', // kicker labels, soft peach
      text: '#FBF7EF', // warm cream white
      textSecondary: '#D9D6C5',
      muted: '#9DAF9D',
      faint: '#6A7A63',
      warning: '#E8785A', // coral, distinct from the happy orange
      warningStrong: '#D95B3C',
      onPrimary: '#3A1E07', // deep warm brown on orange fills
      celebrate: '#FFE3C2', // warm cream gold
      positiveSurface: '#243424',
      positiveBorder: '#4A6247',
      overlay: 'rgba(8,14,9,0.62)',
    },
    light: {
      background: '#F6F1E7', // warm cream
      card: '#FFFCF5',
      border: '#E3DBC9',
      primary: '#B4581E', // burnt orange, passes AA as text on cream
      softGreen: '#7A5A2E', // warm brown kickers
      text: '#221E15',
      textSecondary: '#4A443A',
      muted: '#6E675C',
      faint: '#948C7E',
      warning: '#A6402C',
      warningStrong: '#86311F',
      onPrimary: '#FFFFFF',
      celebrate: '#8A6200',
      positiveSurface: '#EFE9D3',
      positiveBorder: '#D8CCA8',
      overlay: 'rgba(30,24,12,0.45)',
    },
  },
  mint: {
    dark: {
      background: '#0B1210',
      card: '#141F1A',
      border: '#23372E',
      primary: '#2FD48F',
      softGreen: '#86C7A8',
      text: '#F2FBF6',
      textSecondary: '#C6D6CD',
      muted: '#8FA39A',
      faint: '#5C6F66',
      warning: '#F2A05F',
      warningStrong: '#E0633A',
      onPrimary: '#04261A',
      celebrate: '#FFD166',
      positiveSurface: '#12291E',
      positiveBorder: '#1F4A36',
      overlay: 'rgba(5,12,9,0.62)',
    },
    light: {
      background: '#F2F7F4',
      card: '#FFFFFF',
      border: '#DCE7E0',
      primary: '#157A5B',
      softGreen: '#2E7357',
      text: '#101B16',
      textSecondary: '#33443D',
      muted: '#5D6E66',
      faint: '#7E948A',
      warning: '#B84A22',
      warningStrong: '#93381A',
      onPrimary: '#FFFFFF',
      celebrate: '#946300',
      positiveSurface: '#E4F3EB',
      positiveBorder: '#BFE0D0',
      overlay: 'rgba(10,20,15,0.45)',
    },
  },
};

// The brand default.
export const DEFAULT_PALETTE = 'barako';

// Kept for anything still importing the old names; they point at the brand.
export const darkColors = palettes.barako.dark;
export const lightColors = palettes.barako.light;

// Spacing scale. Use these instead of typing random numbers, so padding and
// gaps stay consistent everywhere.
export const spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
};

// Corner roundness for cards, buttons, and pills.
export const radius = {
  sm: 10,
  md: 14,
  lg: 20,
  xl: 26, // hero cards and sheets
  pill: 999, // fully rounded
};

// Font sizes, from small captions up to the big balance numbers.
export const fontSize = {
  caption: 12,
  small: 13,
  body: 15,
  subtitle: 17,
  title: 22,
  big: 28,
  huge: 34,
  display: 42, // the net worth hero only
};

// Font weights, named so we do not memorize numbers. heavy is reserved for
// money numbers and page titles, so the numbers own the hierarchy.
export const fontWeight = {
  regular: '400',
  medium: '600',
  bold: '700',
  heavy: '800',
};
