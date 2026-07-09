// theme.js holds all of our design tokens in one place: colors, spacing,
// corner radius, and font sizes. Every screen imports from here, so the look
// stays consistent and we can restyle the whole app by editing this one file.
//
// Color themes, each with dark and light variants. barako is the brand
// default; the rest are options users can switch to in More, so the app can
// match anyone's taste:
//  - barako: the Salapify brand. Dark-roast espresso base (oat-milk latte in
//    light), roasted orange doing the dopamine work. Warm café energy.
//  - ultraviolet: midnight violet with an electric-lime win glow.
//  - tidal: deep navy with a vivid aqua pop, the most bank-trustworthy.
//  - voltage: ink black with an electric-blue current and magenta sparks.
//  - ember: warm charcoal with a sunrise coral.
//  - orchidgold: berry plum with gold trophies, the boldest look.
//  - forest: warm orange on deep green.
//  - mint: a glowing green.
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
      surfaceRaised: '#2E211A', // one step lighter than card, for lifted hero surfaces
      border: '#3A2A20',
      primary: '#FF8A3D', // roasted orange: buttons, positive numbers, streaks
      softGreen: '#E9BC8E', // warm caramel kicker (legacy name, not green)
      text: '#FBF3E9', // steamed-milk cream
      textSecondary: '#E0CEBB',
      muted: '#A99182',
      faint: '#97806F',
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
      surfaceRaised: '#FFFFFF', // pure white lifts above the cream background
      border: '#E7DCC9',
      primary: '#AE5019', // deep roasted orange, passes AA as money text on cream
      softGreen: '#8A5A2E', // warm brown kicker
      text: '#241812',
      textSecondary: '#4A382E',
      muted: '#6E5A4C',
      faint: '#867162',
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
      surfaceRaised: '#22382A',
      border: '#33503D',
      primary: '#FFA45C', // light orange: buttons, positive numbers
      softGreen: '#E8B98B', // kicker labels, soft peach
      text: '#FBF7EF', // warm cream white
      textSecondary: '#D9D6C5',
      muted: '#9DAF9D',
      faint: '#83947F',
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
      surfaceRaised: '#FFFFFF',
      border: '#E3DBC9',
      primary: '#B4581E', // burnt orange, passes AA as text on cream
      softGreen: '#7A5A2E', // warm brown kickers
      text: '#221E15',
      textSecondary: '#4A443A',
      muted: '#6E675C',
      faint: '#7B7367',
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
      surfaceRaised: '#1C2A23',
      border: '#23372E',
      primary: '#2FD48F',
      softGreen: '#86C7A8',
      text: '#F2FBF6',
      textSecondary: '#C6D6CD',
      muted: '#8FA39A',
      faint: '#768980',
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
      surfaceRaised: '#FFFFFF',
      border: '#DCE7E0',
      primary: '#157A5B',
      softGreen: '#2E7357',
      text: '#101B16',
      textSecondary: '#33443D',
      muted: '#5D6E66',
      faint: '#687A72',
      warning: '#B84A22',
      warningStrong: '#93381A',
      onPrimary: '#FFFFFF',
      celebrate: '#946300',
      positiveSurface: '#E4F3EB',
      positiveBorder: '#BFE0D0',
      overlay: 'rgba(10,20,15,0.45)',
    },
  },
  // ultraviolet: midnight violet with an electric-lime win glow. The lime
  // only fires on earned moments. All pairings pass WCAG AA.
  ultraviolet: {
    dark: {
      background: '#14102A',
      card: '#1E1840',
      surfaceRaised: '#28214F',
      border: '#372C63',
      primary: '#A98BFF',
      softGreen: '#C9B7FF',
      text: '#F4F1FF',
      textSecondary: '#CFC6EE',
      muted: '#9A90C4',
      faint: '#897FB2',
      warning: '#FF8A4C',
      warningStrong: '#FF6A3D',
      onPrimary: '#1A0F33',
      celebrate: '#C6FF4A',
      positiveSurface: '#24204C',
      positiveBorder: '#443B7A',
      overlay: 'rgba(10,7,24,0.64)',
    },
    light: {
      background: '#F5F2FF',
      card: '#FFFFFF',
      surfaceRaised: '#FFFFFF',
      border: '#E4DEF7',
      primary: '#6A34D6',
      softGreen: '#6E4FB0',
      text: '#1C1633',
      textSecondary: '#443C63',
      muted: '#655C82',
      faint: '#7A7196',
      warning: '#C23A1B',
      warningStrong: '#9C2C12',
      onPrimary: '#FFFFFF',
      celebrate: '#526E00',
      positiveSurface: '#EEEAFB',
      positiveBorder: '#D6CCF4',
      overlay: 'rgba(26,16,48,0.42)',
    },
  },
  // tidal: deep navy with a vivid aqua pop. The most bank-trustworthy look,
  // and its warm-amber warning is the cleanest split from the cool primary.
  tidal: {
    dark: {
      background: '#0A121F',
      card: '#131F30',
      surfaceRaised: '#1B2A3E',
      border: '#24374F',
      primary: '#2DD4E8',
      softGreen: '#7FC5D6',
      text: '#EFF6FB',
      textSecondary: '#C6D6E2',
      muted: '#8598A8',
      faint: '#758898',
      warning: '#FF9F45',
      warningStrong: '#FF7A38',
      onPrimary: '#052730',
      celebrate: '#FFD24A',
      positiveSurface: '#122A33',
      positiveBorder: '#1E4C57',
      overlay: 'rgba(4,9,16,0.64)',
    },
    light: {
      background: '#F1F6FA',
      card: '#FFFFFF',
      surfaceRaised: '#FFFFFF',
      border: '#D8E4EC',
      primary: '#0A6E82',
      softGreen: '#2C6076',
      text: '#0F1C28',
      textSecondary: '#32475A',
      muted: '#5A6E7E',
      faint: '#647988',
      warning: '#B4551A',
      warningStrong: '#924213',
      onPrimary: '#FFFFFF',
      celebrate: '#8A6400',
      positiveSurface: '#E1F0F2',
      positiveBorder: '#BCDDE0',
      overlay: 'rgba(8,20,28,0.42)',
    },
  },
  // voltage: near-black ink with an electric-blue current and magenta win
  // sparks. The sleekest, most premium dark-first feel.
  voltage: {
    dark: {
      background: '#0A0B10',
      card: '#14161F',
      surfaceRaised: '#1C1F2B',
      border: '#272B39',
      primary: '#4C8DFF',
      softGreen: '#94B5F2',
      text: '#F1F4FB',
      textSecondary: '#C7CFDE',
      muted: '#858FA3',
      faint: '#768093',
      warning: '#FFA13D',
      warningStrong: '#FF7E33',
      onPrimary: '#04122B',
      celebrate: '#FF5CA8',
      positiveSurface: '#111C30',
      positiveBorder: '#1E3355',
      overlay: 'rgba(3,4,8,0.66)',
    },
    light: {
      background: '#F3F5FA',
      card: '#FFFFFF',
      surfaceRaised: '#FFFFFF',
      border: '#DCE1EC',
      primary: '#1F5AD6',
      softGreen: '#3A5AA8',
      text: '#111521',
      textSecondary: '#333B4E',
      muted: '#586074',
      faint: '#6E768B',
      warning: '#B4551A',
      warningStrong: '#924213',
      onPrimary: '#FFFFFF',
      celebrate: '#B01C6E',
      positiveSurface: '#E3ECF9',
      positiveBorder: '#C2D3F0',
      overlay: 'rgba(8,12,22,0.42)',
    },
  },
  // ember: warm charcoal with a sunrise-coral pulse. The coziest option, a
  // cooler rose warning keeps debt clear of the happy coral.
  ember: {
    dark: {
      background: '#1B1613',
      card: '#271F1B',
      surfaceRaised: '#322824',
      border: '#403129',
      primary: '#FF7A54',
      softGreen: '#F0B48A',
      text: '#FBF3EC',
      textSecondary: '#E0D2C6',
      muted: '#AC9A8C',
      faint: '#958578',
      warning: '#FF556E',
      warningStrong: '#F53A57',
      onPrimary: '#2A0E04',
      celebrate: '#FFB020',
      positiveSurface: '#2E2016',
      positiveBorder: '#55402C',
      overlay: 'rgba(12,8,6,0.64)',
    },
    light: {
      background: '#FBF4EE',
      card: '#FFFFFF',
      surfaceRaised: '#FFFFFF',
      border: '#EBDDD1',
      primary: '#C1401C',
      softGreen: '#9A5A2C',
      text: '#241812',
      textSecondary: '#4A382E',
      muted: '#6E5A4C',
      faint: '#877262',
      warning: '#B41F3C',
      warningStrong: '#911730',
      onPrimary: '#FFFFFF',
      celebrate: '#8A5A00',
      positiveSurface: '#F3E7D8',
      positiveBorder: '#E2CBAF',
      overlay: 'rgba(28,16,8,0.42)',
    },
  },
  // orchidgold: berry-plum base with gold trophies. The boldest, most
  // fashion-forward option; gold celebrate makes wins feel like medals.
  orchidgold: {
    dark: {
      background: '#180E22',
      card: '#241634',
      surfaceRaised: '#2E1D42',
      border: '#3D2755',
      primary: '#F268B0',
      softGreen: '#E0A8D6',
      text: '#F8EFF6',
      textSecondary: '#DCCAD8',
      muted: '#A891AA',
      faint: '#937D97',
      warning: '#FF7A45',
      warningStrong: '#F55A2C',
      onPrimary: '#2B0A1E',
      celebrate: '#F7C64B',
      positiveSurface: '#28193A',
      positiveBorder: '#4A2F63',
      overlay: 'rgba(10,5,16,0.64)',
    },
    light: {
      background: '#FAF2F8',
      card: '#FFFFFF',
      surfaceRaised: '#FFFFFF',
      border: '#EBD9E8',
      primary: '#B01C6E',
      softGreen: '#8A3A78',
      text: '#241020',
      textSecondary: '#483042',
      muted: '#6E566A',
      faint: '#886E86',
      warning: '#BC3A16',
      warningStrong: '#992C0F',
      onPrimary: '#FFFFFF',
      celebrate: '#8A6000',
      positiveSurface: '#F3E4F0',
      positiveBorder: '#E1C6DC',
      overlay: 'rgba(26,10,22,0.42)',
    },
  },
};

// Categorical chart hues, for telling distinct series/categories apart (not
// magnitude). Validated colorblind-safe on our light and dark card surfaces
// (worst adjacent CVD dE 24.2 light / 17.6 dark; the chart legends + segment
// gaps are the required secondary encoding). Slot ORDER is CVD-optimized for
// adjacency, so assign in fixed order and never cycle. A 8th+ category folds
// into a neutral "more", never a generated hue. Dark slot 3 is a brighter
// green (#37A84E, not the light deck's #008300) so it clears >=3:1 on the dark
// cards and never reads as dim green-on-green on the mint/forest dark themes.
export const CHART_CATEGORICAL = {
  light: ['#2a78d6','#1baf7a','#eda100','#008300','#4a3aa7','#e34948','#e87ba4','#eb6834'],
  dark:  ['#3987e5','#199e70','#c98500','#37A84E','#9085e9','#e66767','#d55181','#d95926'],
};

// The brand default.
export const DEFAULT_PALETTE = 'barako';

// The light/dark/system choices, shared by the More tab entry row and the
// Appearance screen so both read from one source of truth.
export const APPEARANCE_MODES = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

// The color themes, with a short hint each. Barako is the Salapify brand;
// Forest and Mint are alternates kept for anyone who prefers green. Shared by
// the More tab (for the current theme label) and the Appearance screen grid.
export const PALETTE_OPTIONS = [
  { key: 'barako', label: 'Barako', hint: 'Roasted orange on dark-roast coffee. The Salapify look.' },
  { key: 'ultraviolet', label: 'Ultraviolet', hint: 'Midnight violet with an electric-lime glow.' },
  { key: 'tidal', label: 'Tidal', hint: 'Deep navy with a vivid aqua pop.' },
  { key: 'voltage', label: 'Voltage', hint: 'Ink black with an electric-blue current.' },
  { key: 'ember', label: 'Ember', hint: 'Warm charcoal with a sunrise coral.' },
  { key: 'orchidgold', label: 'Orchid Gold', hint: 'Berry plum with gold trophies.' },
  { key: 'forest', label: 'Forest', hint: 'Warm orange on deep green.' },
  { key: 'mint', label: 'Mint', hint: 'A glowing green.' },
];

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

// Elevation: three named, cross-platform depth levels. iOS reads the shadow*
// fields, Android reads elevation, so one object covers both. shadowColor is a
// dark, palette-neutral warm black so the soft shadow never tints a theme.
// Note: shadows barely show on the dark espresso backgrounds, so on dark
// themes real layering comes from surfaceRaised (a lighter card surface), not
// from the shadow. The Card component pairs these together.
//  - flat: no shadow at all, the surface leans on its border to separate.
//  - raised: soft lift for cards and hero money panels.
//  - overlay: a stronger lift for sheets and floating layers.
export const elevation = {
  flat: {},
  raised: {
    // Tuned so the lift is visible even in light mode on a mid range Android,
    // where a fainter shadow reads as flat. Still soft, never a heavy drop.
    shadowColor: '#0B0705',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.16,
    shadowRadius: 12,
    elevation: 5,
  },
  overlay: {
    shadowColor: '#0B0705',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.22,
    shadowRadius: 20,
    elevation: 12,
  },
};
