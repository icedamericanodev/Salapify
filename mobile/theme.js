// theme.js holds all of our design tokens in one place: colors, spacing,
// corner radius, and font sizes. Every screen imports from here, so the look
// stays consistent and we can restyle the whole app by editing this one file.
//
// Two color themes, each with dark and light variants:
//  - forest: the Salapify brand. Deep forest green base, warm cream text,
//    and light orange doing the dopamine work. Cozy and warm.
//  - mint: the original look. Near black green base with a glowing mint.
//    Clean and techy.
// Rules both themes share: warning is reserved for debt and over limit
// states (never ordinary spending), celebrate appears only during earned
// moments, and every text pairing passes WCAG AA.

export const palettes = {
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
export const DEFAULT_PALETTE = 'forest';

// Kept for anything still importing the old names; they point at the brand.
export const darkColors = palettes.forest.dark;
export const lightColors = palettes.forest.light;

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
