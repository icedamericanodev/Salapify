// Pan: Salapify's coffee mug mascot. A minimalist cup with a handle, a dark
// liquid line, rising steam, and two glowing capsule eyes, drawn entirely from
// plain views and geometry (no image, no drawing library), so it ships over
// the air and stays crisp at any size.
//
// Unlike a fixed logo, Pan's cup swaps colors to match the ACTIVE theme (the
// mug takes the theme's primary accent, the halo its positive surface), so
// Pan looks at home whether you are on Barako orange, Tidal aqua, or any
// other theme.
//
// Three behavioral states via the `state` prop:
//   idle    gentle float, steam rising continuously
//   happy   a quick squash and stretch pop (use when something is saved)
//   worried eyes turn red, steam stops (the coffee went cold), and the cup
//           does a fast horizontal shiver (use when the budget goes negative)

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, StyleSheet, View } from 'react-native';
import { useTheme } from '../context/Theme';

const LIQUID = '#241207'; // coffee is coffee colored in every theme
const EYE = '#FFF3E4'; // warm cream glow
const EYE_WORRIED = '#FF3B3B'; // alarmed red

export default function Mascot({ size = 110, state = 'idle', style }) {
  const { colors } = useTheme();
  const H = size;
  const styles = useMemo(() => makeStyles(H, colors), [H, colors]);
  const worried = state === 'worried';

  const floatY = useRef(new Animated.Value(0)).current;
  const shiverX = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(1)).current;
  const blink = useRef(new Animated.Value(1)).current;
  // Three steam wisps, created once so their identity is stable across renders.
  const steamRef = useRef(null);
  if (!steamRef.current) {
    steamRef.current = [new Animated.Value(0), new Animated.Value(0), new Animated.Value(0)];
  }
  const steam = steamRef.current;

  // The cup floats gently, or shivers fast when worried (never both).
  useEffect(() => {
    let loop;
    if (worried) {
      floatY.setValue(0);
      loop = Animated.loop(
        Animated.sequence([
          Animated.timing(shiverX, { toValue: 1, duration: 55, useNativeDriver: true }),
          Animated.timing(shiverX, { toValue: -1, duration: 55, useNativeDriver: true }),
        ])
      );
    } else {
      shiverX.setValue(0);
      loop = Animated.loop(
        Animated.sequence([
          Animated.timing(floatY, { toValue: 1, duration: 1800, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
          Animated.timing(floatY, { toValue: 0, duration: 1800, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        ])
      );
    }
    loop.start();
    return () => loop.stop();
  }, [worried, floatY, shiverX]);

  // Steam rises continuously, unless the coffee has gone cold (worried).
  useEffect(() => {
    if (worried) {
      steam.forEach((s) => s.stopAnimation(() => s.setValue(0)));
      return undefined;
    }
    const loops = steam.map((s, i) => {
      const l = Animated.loop(
        Animated.sequence([
          Animated.delay(i * 520),
          Animated.timing(s, { toValue: 1, duration: 2300, easing: Easing.out(Easing.ease), useNativeDriver: true }),
        ])
      );
      l.start();
      return l;
    });
    return () => loops.forEach((l) => l.stop());
  }, [worried, steam]);

  // A squash and stretch pop each time we enter the happy state.
  useEffect(() => {
    if (state !== 'happy') return;
    scale.setValue(1);
    Animated.sequence([
      Animated.timing(scale, { toValue: 1.18, duration: 130, easing: Easing.out(Easing.ease), useNativeDriver: true }),
      Animated.spring(scale, { toValue: 1, friction: 3, tension: 150, useNativeDriver: true }),
    ]).start();
  }, [state, scale]);

  // Eyes blink every few seconds no matter the state.
  useEffect(() => {
    const l = Animated.loop(
      Animated.sequence([
        Animated.delay(2800),
        Animated.timing(blink, { toValue: 0.1, duration: 80, useNativeDriver: true }),
        Animated.timing(blink, { toValue: 1, duration: 110, useNativeDriver: true }),
      ])
    );
    l.start();
    return () => l.stop();
  }, [blink]);

  const translateY = floatY.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.12] });
  const translateX = shiverX.interpolate({ inputRange: [-1, 1], outputRange: [-H * 0.035, H * 0.035] });
  const shadowOpacity = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.6] });
  const shadowScale = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.88] });
  const eyeColor = worried ? EYE_WORRIED : EYE;

  return (
    <View style={[styles.container, style]} accessibilityRole="image" accessibilityLabel="Pan, the Salapify coffee mascot">
      <View style={styles.halo} />

      {/* Steam wisps rising from the cup. */}
      <View style={styles.steamWrap} pointerEvents="none">
        {steam.map((s, i) => (
          <Animated.View
            key={i}
            style={[
              styles.steam,
              styles[`steam${i}`],
              {
                opacity: s.interpolate({ inputRange: [0, 0.2, 0.8, 1], outputRange: [0, 0.5, 0.35, 0] }),
                transform: [
                  { translateY: s.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.5] }) },
                  { scale: s.interpolate({ inputRange: [0, 1], outputRange: [0.7, 1.15] }) },
                ],
              },
            ]}
          />
        ))}
      </View>

      {/* Ground shadow, grounded (does not float with the cup). */}
      <Animated.View style={[styles.shadow, { opacity: shadowOpacity, transform: [{ scaleX: shadowScale }] }]} />

      {/* The cup itself floats / shivers / pops. */}
      <Animated.View style={[styles.mugGroup, { transform: [{ translateY }, { translateX }, { scale }] }]}>
        <View style={styles.handle} />
        <View style={styles.body}>
          <View style={styles.liquid} />
          <View style={styles.face}>
            <Animated.View style={[styles.eye, { backgroundColor: eyeColor, transform: [{ scaleY: blink }] }]} />
            <Animated.View style={[styles.eye, { backgroundColor: eyeColor, transform: [{ scaleY: blink }] }]} />
          </View>
        </View>
      </Animated.View>
    </View>
  );
}

function makeStyles(H, colors) {
  return StyleSheet.create({
    container: { width: H * 1.5, height: H * 1.9, alignItems: 'center', justifyContent: 'flex-end' },
    halo: {
      position: 'absolute',
      bottom: H * 0.2,
      width: H * 1.42,
      height: H * 1.42,
      borderRadius: H * 0.71,
      backgroundColor: colors.positiveSurface,
      opacity: 0.7,
    },
    steamWrap: { position: 'absolute', top: H * 0.02, width: H, height: H * 0.7 },
    steam: { position: 'absolute', top: H * 0.36, width: H * 0.09, height: H * 0.26, borderRadius: H * 0.045, backgroundColor: colors.muted },
    steam0: { left: H * 0.29 },
    steam1: { left: H * 0.455 },
    steam2: { left: H * 0.62 },
    shadow: { position: 'absolute', bottom: H * 0.1, width: H * 0.7, height: H * 0.12, borderRadius: H * 0.06, backgroundColor: 'rgba(20,10,5,0.18)' },
    mugGroup: { alignItems: 'center', justifyContent: 'center' },
    handle: {
      position: 'absolute',
      right: -H * 0.05,
      top: H * 0.26,
      width: H * 0.44,
      height: H * 0.44,
      borderRadius: H * 0.22,
      borderWidth: H * 0.1,
      borderColor: colors.primary,
      backgroundColor: 'transparent',
    },
    body: {
      width: H,
      height: H * 0.92,
      borderTopLeftRadius: H * 0.14,
      borderTopRightRadius: H * 0.14,
      borderBottomLeftRadius: H * 0.42,
      borderBottomRightRadius: H * 0.42,
      backgroundColor: colors.primary,
      overflow: 'hidden',
      alignItems: 'center',
    },
    liquid: { position: 'absolute', top: H * 0.09, width: H * 0.78, height: H * 0.15, borderRadius: H * 0.075, backgroundColor: LIQUID },
    face: { position: 'absolute', top: H * 0.42, flexDirection: 'row', gap: H * 0.14 },
    eye: {
      width: H * 0.13,
      height: H * 0.24,
      borderRadius: H * 0.065,
      shadowColor: '#FFC24D',
      shadowOpacity: 0.9,
      shadowRadius: H * 0.05,
      shadowOffset: { width: 0, height: 0 },
    },
  });
}
