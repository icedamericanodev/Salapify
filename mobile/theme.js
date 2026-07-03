// theme.js holds all of our design tokens in one place: colors, spacing,
// corner radius, and font sizes. Every screen imports from here, so the look
// stays consistent and we can restyle the whole app by editing this one file.
//
// Brand: Kalma. Kinang. Kakampi. (Calm. Shine. On your side.)
// A calm deep green base so the mint primary glows, gold only for earned
// celebration moments, and warning orange reserved for debt and over limit
// states, never for ordinary spending.

// Dark palette. This is our flagship look.
export const darkColors = {
  background: '#0B1210', // app background, deep near black green
  card: '#141F1A', // card surface
  border: '#23372E', // card and input borders
  primary: '#2FD48F', // brand mint: buttons, positive numbers
  softGreen: '#86C7A8', // kicker labels
  text: '#F2FBF6', // mint tinted white, primary text
  textSecondary: '#C6D6CD', // secondary text
  muted: '#8FA39A', // small labels
  faint: '#5C6F66', // decorative hints only
  warning: '#F2A05F', // debt and over limit only
  warningStrong: '#E0633A', // destructive emphasis
  onPrimary: '#04261A', // text on primary fills (dark green on mint)
  celebrate: '#FFD166', // milestone gold, earned moments only
  positiveSurface: '#12291E', // tinted card fill for wins and payday energy
  positiveBorder: '#1F4A36', // border for tinted cards
  overlay: 'rgba(5,12,9,0.62)', // modal scrim
};

// Light palette.
export const lightColors = {
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
};

// The active palette is no longer fixed here. Screens get their colors from
// the Theme context (see context/Theme.js) using the useTheme() hook, so the
// whole app can switch between light and dark at runtime.

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
