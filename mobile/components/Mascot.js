// Pan: Salapify's coffee cup mascot. A friendly, big eyed character drawn
// entirely from plain views and geometry (no image, no drawing library), so
// it ships over the air and stays crisp at any size.
//
// The whole cup is the character. Big round eyes with a shine, soft blush
// cheeks, and an open smile give it a face you actually want to look at.
// Rising steam and a side handle keep it unmistakably a mug of kape. The cup
// takes the ACTIVE theme's accent, so Pan looks at home on Barako orange,
// Tidal aqua, or any other theme.
//
// Three behavioral states via the `state` prop:
//   idle    gentle float, steam rising, a calm smile
//   happy   a quick squash and stretch pop and a wider grin (on a save)
//   worried worried brows, a small straight mouth, cheeks fade, steam stops,
//           and a fast horizontal shiver (use when the budget goes negative)

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, StyleSheet, View } from 'react-native';
import { useTheme } from '../context/Theme';

const INK = '#3A2317'; // soft espresso, kinder than pure black for eyes/mouth
const WHITE = '#FFFFFF';
const CHEEK = 'rgba(255,120,80,0.38)'; // warm blush

export default function Mascot({ size = 110, state = 'idle', style }) {
  const { colors } = useTheme();
  const H = size;
  const styles = useMemo(() => makeStyles(H, colors), [H, colors]);
  const worried = state === 'worried';
  const happy = state === 'happy';

  const floatY = useRef(new Animated.Value(0)).current;
  const shiverX = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(1)).current;
  const blink = useRef(new Animated.Value(1)).current;
  const cheek = useRef(new Animated.Value(1)).current;
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

  // Cheeks fade out when worried, back in otherwise.
  useEffect(() => {
    Animated.timing(cheek, { toValue: worried ? 0 : 1, duration: 220, useNativeDriver: true }).start();
  }, [worried, cheek]);

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

  const translateY = floatY.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.1] });
  const translateX = shiverX.interpolate({ inputRange: [-1, 1], outputRange: [-H * 0.035, H * 0.035] });
  const shadowOpacity = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.6] });
  const shadowScale = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.88] });

  // One eye: white ball, dark pupil low and centered for a sweet look, a
  // bright shine on top. The whole eye scales on the Y axis to blink.
  const Eye = () => (
    <Animated.View style={[styles.eye, { transform: [{ scaleY: blink }] }]}>
      <View style={styles.pupil}>
        <View style={styles.shine} />
      </View>
    </Animated.View>
  );

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
          {/* A soft rim sheen so the cup reads as an open mug, not a brow. */}
          <View style={styles.rim} />

          {/* Worried brows: two short bars angled up at the inner ends. */}
          {worried ? (
            <>
              <View style={[styles.brow, styles.browLeft]} />
              <View style={[styles.brow, styles.browRight]} />
            </>
          ) : null}

          <View style={styles.eyeRow}>
            <Eye />
            <Eye />
          </View>

          <Animated.View style={[styles.cheek, styles.cheekLeft, { opacity: cheek }]} />
          <Animated.View style={[styles.cheek, styles.cheekRight, { opacity: cheek }]} />

          {/* Mouth: an open grin normally, a wider grin when happy, a small
              straight line when worried. */}
          <View style={[styles.mouth, happy && styles.mouthHappy, worried && styles.mouthWorried]} />
        </View>
      </Animated.View>
    </View>
  );
}

function makeStyles(H, colors) {
  const ED = H * 0.26; // eye diameter
  const PD = H * 0.15; // pupil diameter
  const SH = H * 0.055; // shine diameter
  const CH = H * 0.15; // cheek diameter
  return StyleSheet.create({
    container: { width: H * 1.5, height: H * 1.75, alignItems: 'center', justifyContent: 'flex-end' },
    halo: {
      position: 'absolute',
      bottom: H * 0.16,
      width: H * 1.4,
      height: H * 1.4,
      borderRadius: H * 0.7,
      backgroundColor: colors.positiveSurface,
      opacity: 0.7,
    },
    steamWrap: { position: 'absolute', top: H * 0.02, width: H, height: H * 0.7 },
    steam: { position: 'absolute', top: H * 0.34, width: H * 0.09, height: H * 0.26, borderRadius: H * 0.045, backgroundColor: colors.muted },
    steam0: { left: H * 0.29 },
    steam1: { left: H * 0.455 },
    steam2: { left: H * 0.62 },
    shadow: { position: 'absolute', bottom: H * 0.08, width: H * 0.7, height: H * 0.12, borderRadius: H * 0.06, backgroundColor: 'rgba(20,10,5,0.18)' },

    mugGroup: { alignItems: 'center', justifyContent: 'center' },
    handle: {
      position: 'absolute',
      right: -H * 0.04,
      top: H * 0.32,
      width: H * 0.4,
      height: H * 0.4,
      borderRadius: H * 0.2,
      borderWidth: H * 0.1,
      borderColor: colors.primary,
      backgroundColor: 'transparent',
    },
    body: {
      width: H,
      height: H * 0.95,
      borderTopLeftRadius: H * 0.34,
      borderTopRightRadius: H * 0.34,
      borderBottomLeftRadius: H * 0.44,
      borderBottomRightRadius: H * 0.44,
      backgroundColor: colors.primary,
      overflow: 'hidden',
    },
    rim: {
      position: 'absolute',
      top: H * 0.08,
      alignSelf: 'center',
      width: H * 0.62,
      height: H * 0.1,
      borderRadius: H * 0.05,
      backgroundColor: 'rgba(255,255,255,0.16)',
    },

    brow: { position: 'absolute', top: H * 0.26, width: H * 0.15, height: H * 0.05, borderRadius: H * 0.025, backgroundColor: INK },
    browLeft: { left: H * 0.2, transform: [{ rotate: '16deg' }] },
    browRight: { right: H * 0.2, transform: [{ rotate: '-16deg' }] },

    eyeRow: { position: 'absolute', top: H * 0.34, left: 0, right: 0, flexDirection: 'row', justifyContent: 'center', gap: H * 0.14 },
    eye: { width: ED, height: ED, borderRadius: ED / 2, backgroundColor: WHITE, alignItems: 'center', justifyContent: 'flex-end', paddingBottom: H * 0.02 },
    pupil: { width: PD, height: PD, borderRadius: PD / 2, backgroundColor: INK, alignItems: 'flex-start', justifyContent: 'flex-start' },
    shine: { width: SH, height: SH, borderRadius: SH / 2, backgroundColor: WHITE, marginTop: H * 0.02, marginLeft: H * 0.025 },

    cheek: { position: 'absolute', top: H * 0.6, width: CH, height: CH * 0.72, borderRadius: CH / 2, backgroundColor: CHEEK },
    cheekLeft: { left: H * 0.14 },
    cheekRight: { right: H * 0.14 },

    mouth: {
      position: 'absolute',
      top: H * 0.62,
      alignSelf: 'center',
      width: H * 0.24,
      height: H * 0.13,
      backgroundColor: INK,
      borderBottomLeftRadius: H * 0.12,
      borderBottomRightRadius: H * 0.12,
      borderTopLeftRadius: H * 0.03,
      borderTopRightRadius: H * 0.03,
    },
    mouthHappy: { top: H * 0.6, width: H * 0.3, height: H * 0.18, borderBottomLeftRadius: H * 0.15, borderBottomRightRadius: H * 0.15 },
    mouthWorried: {
      top: H * 0.66,
      width: H * 0.16,
      height: H * 0.055,
      borderRadius: H * 0.03,
      borderTopLeftRadius: H * 0.03,
      borderTopRightRadius: H * 0.03,
    },
  });
}
