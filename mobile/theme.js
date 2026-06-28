// theme.js holds all of our design tokens in one place: colors, spacing,
// corner radius, and font sizes. Every screen imports from here, so the look
// stays consistent and we can restyle the whole app by editing this one file.

// Dark palette. This is our default look.
export const darkColors = {
  background: '#0E1512', // app background
  card: '#16211C', // card surface
  border: '#244034', // card border
  primary: '#1D9E75', // primary green (buttons, active items)
  softGreen: '#7FB89E', // soft green text (small labels)
  text: '#FFFFFF', // primary text
  textSecondary: '#D7E0DB', // secondary text
  muted: '#8A9690', // muted text
  faint: '#5A6B63', // faint text (hints)
  warning: '#E8895A', // debt or warning accent
  warningStrong: '#D85A30', // stronger warning
};

// Light palette. Used later when we add light and system theme options.
// These are sensible starting values; we can fine tune them then.
export const lightColors = {
  background: '#F4F7F5',
  card: '#FFFFFF',
  border: '#DCE6E0',
  primary: '#1D9E75',
  softGreen: '#3E8E6E',
  text: '#0E1512',
  textSecondary: '#3A4742',
  muted: '#6B7771',
  faint: '#9AA8A1',
  warning: '#D85A30',
  warningStrong: '#B8431F',
};

// For now the app always uses the dark palette. In a later step we will let
// the user switch this to light or follow the phone's system setting.
export const colors = darkColors;

// Spacing scale. Use these instead of typing random numbers, so padding and
// gaps stay consistent everywhere.
export const spacing = {
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
  lg: 18,
  pill: 999, // fully rounded
};

// Font sizes, from small captions up to the big balance numbers.
export const fontSize = {
  caption: 12,
  small: 13,
  body: 15,
  subtitle: 18,
  title: 22,
  big: 28,
  huge: 34,
};

// Font weights, named so we do not memorize numbers.
export const fontWeight = {
  regular: '400',
  medium: '600',
  bold: '800',
};
