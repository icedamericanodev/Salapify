// Bar. One shared horizontal progress/track bar so every chart in the app speaks
// the same bar language. Before this, several screens hand-rolled their own track
// and fill Views at inconsistent heights (6, 8, 10, 12, 16 px), so the same idea,
// "a bar that is this full", looked slightly different on every screen. Now one
// component owns the look, so one edit here restyles every bar at once.
//
// It is a single-fraction bar: a rounded track with one fill sized by `fraction`.
// It is deliberately NOT a multi-segment proportion bar (a spending pie drawn as a
// stacked bar) and NOT a vertical column chart. Those are different primitives and
// stay hand-built where they are used.
//
// Decorative by design: the number a bar represents is always announced by the
// text right next to it, so the bar carries no value of its own and is hidden from
// screen readers. That keeps the reader on the real number instead of an empty
// element.
//
// Reads live theme colors through useTheme(), so all 8 palettes and both light and
// dark just work with no per-screen code.
//
// Props:
//  - fraction: 0..1, clamped. How full the fill is. A bad value (negative, NaN,
//    over 1) can never draw outside the track.
//  - color: the fill color. Defaults to colors.primary.
//  - trackColor: the empty track color. Defaults to colors.border. Pass
//    'transparent' for a bar that floats with no visible track.
//  - height: 'sm' (8), 'md' (10, the default), or 'lg' (16). The bar's thickness.
//  - rounded: pill caps on the track and fill. Default true.
//  - animate: grow the fill in from empty on mount and glide to a new fraction
//    when it changes. Default true. The growth is a GPU composited scaleX from
//    the left edge, so it stays smooth on budget phones, and it respects the OS
//    reduce motion setting (then the fill just shows at its final width).
//  - style: extra styles on the track, applied last, so a caller can add flex or a
//    margin (for example a bar that sits in a row next to a label and a value).

import { useMemo, useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
  ReduceMotion,
} from 'react-native-reanimated';
import { radius, duration } from '../theme';
import { useTheme } from '../context/Theme';
import { useReduceMotion } from '../context/Motion';

const HEIGHTS = { sm: 8, md: 10, lg: 16 };

export default function Bar({
  fraction = 0,
  color,
  trackColor,
  height = 'md',
  rounded = true,
  animate = true,
  style,
}) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const reduce = useReduceMotion();

  // Clamp so a bad ratio can never overflow the track or go negative.
  const f = Number.isFinite(fraction) ? Math.max(0, Math.min(1, fraction)) : 0;
  const h = HEIGHTS[height] || HEIGHTS.md;
  const cap = rounded ? radius.pill : 0;

  const on = animate && !reduce;
  // The fill is full width and we scaleX it to the fraction from the left edge,
  // which composites on the UI thread. Start empty when animating so it grows in;
  // start at the final fraction otherwise so there is no flash.
  const progress = useSharedValue(on ? 0 : f);
  useEffect(() => {
    if (on) {
      progress.value = withTiming(f, {
        duration: duration.slow,
        easing: Easing.out(Easing.cubic),
        reduceMotion: ReduceMotion.System,
      });
    } else {
      progress.value = f;
    }
  }, [f, on]);

  const fillStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: progress.value }],
  }));

  return (
    <View
      style={[
        styles.track,
        { height: h, borderRadius: cap, backgroundColor: trackColor || colors.border },
        style,
      ]}
      // Decorative: the adjacent text announces the real value, so the reader
      // skips the bar itself on both platforms.
      accessibilityElementsHidden={true}
      importantForAccessibility="no-hide-descendants"
    >
      <Animated.View
        style={[
          {
            width: '100%',
            height: '100%',
            borderRadius: cap,
            backgroundColor: color || colors.primary,
            transformOrigin: 'left',
          },
          fillStyle,
        ]}
      />
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    // No width here: in a column (a card) the track stretches to full width on its
    // own, and in a row a caller passes style={{ flex: 1 }} to make it grow.
    track: { overflow: 'hidden' },
  });
}
