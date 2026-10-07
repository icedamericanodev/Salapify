// PressableScale. A drop in replacement for Pressable that adds the one bit of
// feel almost every tappable surface in the app was missing: a quick spring
// dip on press and a light haptic, so a tap feels physical instead of just
// changing color. Because the shared Card and the add button both route through
// this, one file makes most of the app feel alive.
//
// Props: everything Pressable takes (onPress, accessibilityRole,
// accessibilityLabel, hitSlop, disabled, children, and a style that may be a
// plain style or an array), plus:
//   - haptic: which buzz to fire on press in ('light' by default, pass null to
//     stay silent). See useHaptic for the kinds.
//   - scaleTo: how far the press dips (defaults to the shared pressScale token).
//
// Reduce motion aware: when the user has reduce motion on we skip the scale and
// fall back to a gentle opacity dip, and the haptic is silenced by useHaptic.

import { useCallback } from 'react';
import { Pressable } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  ReduceMotion,
} from 'react-native-reanimated';
import { spring, pressScale, duration } from '../../theme';
import { useReduceMotion } from '../../context/Motion';
import { useHaptic } from '../../hooks/useHaptic';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export default function PressableScale({
  onPress,
  onPressIn,
  onPressOut,
  haptic = 'light',
  scaleTo = pressScale,
  style,
  children,
  disabled,
  ...rest
}) {
  const reduce = useReduceMotion();
  const fireHaptic = useHaptic();
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const handleIn = useCallback(
    (e) => {
      // Visual only on press in. The haptic waits for a confirmed onPress
      // (handlePress) so scrolling past a card, which fires press in then
      // cancels, never buzzes for a tap that did not happen.
      if (reduce) {
        // A crossfade is not vestibular, so we keep this gentle dip even under
        // reduce motion (ReduceMotion.Never), instead of a hard opacity jump.
        opacity.value = withTiming(0.9, { duration: duration.instant, reduceMotion: ReduceMotion.Never });
      } else {
        scale.value = withSpring(scaleTo, { ...spring.press, reduceMotion: ReduceMotion.System });
      }
      onPressIn?.(e);
    },
    [reduce, scaleTo, onPressIn]
  );

  const handlePress = useCallback(
    (e) => {
      // Buzz only when the tap actually registers, which also matches intent:
      // the haptic means "done", not "you touched the screen".
      if (haptic) fireHaptic(haptic);
      onPress?.(e);
    },
    [haptic, fireHaptic, onPress]
  );

  const handleOut = useCallback(
    (e) => {
      if (reduce) {
        opacity.value = withTiming(1, { duration: duration.instant, reduceMotion: ReduceMotion.Never });
      } else {
        scale.value = withSpring(1, { ...spring.press, reduceMotion: ReduceMotion.System });
      }
      onPressOut?.(e);
    },
    [reduce, onPressOut]
  );

  // A caller may pass style as a function ({ pressed }) => style (the old
  // Pressable idiom) or a plain style. We resolve both, ignoring the pressed
  // flag since we animate the press ourselves.
  const resolvedStyle = typeof style === 'function' ? style({ pressed: false }) : style;

  return (
    <AnimatedPressable
      onPress={handlePress}
      onPressIn={handleIn}
      onPressOut={handleOut}
      disabled={disabled}
      style={[resolvedStyle, animStyle]}
      {...rest}
    >
      {children}
    </AnimatedPressable>
  );
}
