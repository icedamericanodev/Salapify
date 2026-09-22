// Celebration. A one shot reward overlay for the app's happiest money moment:
// clearing an utang or paying off a debt. It fires a success haptic, drops a
// short burst of confetti, and pops a centered message, then unmounts itself.
//
// Deliberately Reanimated, not Skia: this mounts over live scroll screens and a
// self removing overlay is safer than keeping a Skia canvas around, and it works
// on web too. One shared progress value drives every piece, so it stays light on
// budget Android. Confetti uses the brand chart palette, never a warning hue.
//
// Props:
//  - visible: when it flips true, the celebration plays once.
//  - message: the line shown in the center pill (for example "Utang cleared").
//  - onDone: called after the burst finishes so the parent can reset visible.
//
// Reduce motion aware: with reduce motion on there is no confetti and no
// movement; the message simply appears, it is still announced, and then onDone
// fires. The single success buzz is fired directly (see successBuzz) so it
// survives reduce motion, since a confirmation buzz is feedback, not motion.

import { useEffect, useMemo } from 'react';
import { StyleSheet, View, Text, Dimensions, AccessibilityInfo } from 'react-native';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  withDelay,
  Easing,
  ReduceMotion,
} from 'react-native-reanimated';
import { spacing, radius, fontSize, fontWeight, spring } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useReduceMotion } from '../../context/Motion';

const PIECES = 16; // particle cap: enough to feel like a burst, light on low-end
const FALL_MS = 1400;
// Let the confirm dialog or the debt editor finish dismissing before the burst
// starts, so the reward reads as its own beat instead of colliding with the
// closing dialog.
const ENTER_MS = 260;

// A success buzz for the win. Fired directly (not through useHaptic) so it
// survives reduce motion: a confirmation buzz is a feedback channel, not motion,
// and for a blind user it may be the only non spoken signal. Wrapped so web,
// where haptics do not exist, is a quiet no op.
function successBuzz() {
  try {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
  } catch (e) {
    // no haptics here (for example on web); that is fine
  }
}

// One confetti piece. Reads the shared progress (0..1) and flies from the top
// center out to its own target, spinning and fading near the end.
function Piece({ progress, cfg, color }) {
  const style = useAnimatedStyle(() => {
    const p = progress.value;
    // Ease the fall so it accelerates like gravity; spread sideways linearly.
    const fall = p * p * cfg.fallY;
    const drift = p * cfg.driftX;
    const spin = p * cfg.spin;
    // Hidden until the burst actually starts (progress leaves 0), so the pieces
    // do not sit static at the top during the enter delay; then full opacity,
    // then fade over the last third.
    const opacity = p <= 0.001 ? 0 : p < 0.66 ? 1 : Math.max(0, 1 - (p - 0.66) / 0.34);
    return {
      opacity,
      transform: [
        { translateX: cfg.startX + drift },
        { translateY: cfg.startY + fall },
        { rotate: `${spin}deg` },
        { scale: cfg.scale },
      ],
    };
  });
  return (
    <Animated.View
      style={[
        {
          position: 'absolute',
          top: 0,
          left: 0,
          width: cfg.size,
          height: cfg.size * 0.6,
          borderRadius: 2,
          backgroundColor: color,
        },
        style,
      ]}
    />
  );
}

export default function Celebration({ visible, message, onDone }) {
  const { colors, chartColors } = useTheme();
  const reduce = useReduceMotion();
  const progress = useSharedValue(0);
  const msgScale = useSharedValue(0.8);
  const msgOpacity = useSharedValue(0);

  const { width } = Dimensions.get('window');
  // Precompute each piece's flight once. Fixed randomness still reads as
  // confetti and avoids recomputing on every render.
  const pieces = useMemo(() => {
    const out = [];
    for (let i = 0; i < PIECES; i++) {
      const startX = width / 2 + (Math.random() - 0.5) * 80;
      out.push({
        startX,
        startY: 90 + Math.random() * 40,
        driftX: (Math.random() - 0.5) * width * 0.9,
        fallY: 380 + Math.random() * 260,
        spin: (Math.random() - 0.5) * 720,
        size: 8 + Math.random() * 6,
        scale: 0.8 + Math.random() * 0.6,
        colorIndex: i % (chartColors ? chartColors.length : 8),
      });
    }
    return out;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [width]);

  useEffect(() => {
    if (!visible) return;
    const timers = [];
    // Wait out the dialog/modal dismiss, then play everything in one beat. The
    // parent gives each win a fresh key, so a second payoff during this window
    // remounts this component and replays cleanly (no swallowed second burst).
    timers.push(
      setTimeout(() => {
        successBuzz();
        // The message pill always shows, motion or not.
        if (reduce) {
          msgScale.value = 1;
          msgOpacity.value = 1;
        } else {
          msgScale.value = withSpring(1, { ...spring.bouncy, reduceMotion: ReduceMotion.System });
          msgOpacity.value = withTiming(1, { duration: 160, reduceMotion: ReduceMotion.Never });
          progress.value = 0;
          progress.value = withTiming(1, {
            duration: FALL_MS,
            easing: Easing.linear,
            reduceMotion: ReduceMotion.System,
          });
        }
        // The confetti and pill are hidden from screen readers, so announce the
        // win in words. Delayed a little more so it lands AFTER the dialog
        // dismiss and focus settle, or TalkBack drops it.
        timers.push(
          setTimeout(() => {
            if (message) AccessibilityInfo.announceForAccessibility?.(message);
          }, 340)
        );
        // Hold, then fade the message and finish. Reduce motion holds a beat
        // longer since there is no confetti to watch.
        const holdMs = reduce ? 1100 : FALL_MS - 150;
        msgOpacity.value = withDelay(holdMs, withTiming(0, { duration: 220, reduceMotion: ReduceMotion.Never }));
        timers.push(setTimeout(() => onDone && onDone(), holdMs + 240));
      }, ENTER_MS)
    );
    return () => timers.forEach(clearTimeout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, reduce]);

  const msgStyle = useAnimatedStyle(() => ({
    opacity: msgOpacity.value,
    transform: [{ scale: msgScale.value }],
  }));

  if (!visible) return null;

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none" accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      {!reduce
        ? pieces.map((cfg, i) => (
            <Piece
              key={i}
              progress={progress}
              cfg={cfg}
              color={(chartColors && chartColors[cfg.colorIndex]) || colors.primary}
            />
          ))
        : null}
      <View style={styles.center} pointerEvents="none">
        <Animated.View style={[styles.pill, { backgroundColor: colors.card, borderColor: colors.border }, msgStyle]}>
          <Text style={[styles.emoji]}>🎉</Text>
          <Text style={[styles.msg, { color: colors.text }]} numberOfLines={2}>{message}</Text>
        </Animated.View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { ...StyleSheet.absoluteFillObject, alignItems: 'center', justifyContent: 'center' },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: radius.pill,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    gap: spacing.sm,
    maxWidth: '86%',
  },
  emoji: { fontSize: fontSize.title },
  msg: { fontSize: fontSize.body, fontWeight: fontWeight.heavy, flexShrink: 1 },
});
