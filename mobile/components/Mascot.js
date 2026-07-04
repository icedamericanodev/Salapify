// Pan: Salapify's coffee cup mascot, built as independent layers that move on
// staggered timelines so the character feels like it has weight and momentum
// instead of sliding around as one flat block. Drawn entirely from plain
// views and geometry (no image, no drawing library), so it ships over the air
// and stays crisp at any size, and it can never crash the app the way a
// misconfigured native animation library could.
//
// MULTI LAYER ARCHITECTURE (back to front, each its own animation track):
//   Layer 1  Shadow   scales and fades inversely to Pan's height
//   Layer 2  Body     the mug and handle, the main anchor that floats first
//   Layer 3  Face     eyes, cheeks, mouth, riding ~80ms behind the body
//   Layer 3b Brows    ride ~120ms behind, the last thing to catch up
//   Layer 4  Steam    2 wavy wisps on their own continuous async loop
//
// The lag between layers is real: each float track is a separate looping
// oscillator with the SAME period but a staggered START delay (0ms, 80ms,
// 120ms). Because they never resync, the face and brows sit at a fixed phase
// behind the body forever, which reads as the face riding on the curved
// surface of the cup. A position linked squash and stretch on the body adds
// the jello feel: wider and shorter at the bottom, taller and narrower at the
// top of each float.
//
// States via the `state` prop:
//   idle    organic float with the layered lag, steam rising
//   happy   a scale burst plus a quick eyebrow bounce
//   worried eyes go red, steam stops (coffee went cold), brows furrow, and
//           the body does a high frequency horizontal jitter

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, StyleSheet, View } from 'react-native';
import { useTheme } from '../context/Theme';

const INK = '#3A2317'; // soft espresso, kinder than pure black for eyes/mouth
const WHITE = '#FFFFFF';
const RED = '#FF3B3B'; // worried eyes
const CHEEK = 'rgba(255,120,80,0.38)'; // warm blush
const FLOAT_MS = 1800; // one half of a float cycle, shared by every layer

export default function Mascot({ size = 110, state = 'idle', style }) {
  const { colors } = useTheme();
  const H = size;
  const styles = useMemo(() => makeStyles(H, colors), [H, colors]);
  const worried = state === 'worried';
  const happy = state === 'happy';

  // Layer tracks. Body, face, and brows share a period but start staggered.
  const bodyFloat = useRef(new Animated.Value(0)).current;
  const faceFloat = useRef(new Animated.Value(0)).current;
  const browFloat = useRef(new Animated.Value(0)).current;
  const jitterX = useRef(new Animated.Value(0)).current; // worried shake
  const pop = useRef(new Animated.Value(1)).current; // happy scale burst
  const browBounce = useRef(new Animated.Value(0)).current; // happy brow bounce
  const blink = useRef(new Animated.Value(1)).current;
  const cheek = useRef(new Animated.Value(1)).current;
  // Two steam wisps, created once so their identity is stable across renders.
  const steamRef = useRef(null);
  if (!steamRef.current) {
    steamRef.current = [new Animated.Value(0), new Animated.Value(0)];
  }
  const steam = steamRef.current;

  // Layer 2/3/3b float, or the whole thing jitters when worried (never both).
  useEffect(() => {
    const tracks = [];
    // A looping oscillator that starts after `delay` ms, so a set of them run
    // at a fixed phase lag from each other: the essence of the momentum look.
    const floatLoop = (val, delay) =>
      Animated.sequence([
        Animated.delay(delay),
        Animated.loop(
          Animated.sequence([
            Animated.timing(val, { toValue: 1, duration: FLOAT_MS, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
            Animated.timing(val, { toValue: 0, duration: FLOAT_MS, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
          ])
        ),
      ]);

    if (worried) {
      [bodyFloat, faceFloat, browFloat].forEach((v) => v.stopAnimation(() => v.setValue(0)));
      const shake = Animated.loop(
        Animated.sequence([
          Animated.timing(jitterX, { toValue: 1, duration: 55, useNativeDriver: true }),
          Animated.timing(jitterX, { toValue: -1, duration: 55, useNativeDriver: true }),
        ])
      );
      shake.start();
      tracks.push(shake);
    } else {
      jitterX.stopAnimation(() => jitterX.setValue(0));
      // Body leads, face trails 80ms, brows trail 120ms.
      const b = floatLoop(bodyFloat, 0);
      const f = floatLoop(faceFloat, 80);
      const w = floatLoop(browFloat, 120);
      [b, f, w].forEach((t) => t.start());
      tracks.push(b, f, w);
    }
    return () => tracks.forEach((t) => t.stop());
  }, [worried, bodyFloat, faceFloat, browFloat, jitterX]);

  // Cheeks fade out when worried, back in otherwise.
  useEffect(() => {
    Animated.timing(cheek, { toValue: worried ? 0 : 1, duration: 220, useNativeDriver: true }).start();
  }, [worried, cheek]);

  // Steam rises continuously on its own async loop, unless the coffee is cold.
  useEffect(() => {
    if (worried) {
      steam.forEach((s) => s.stopAnimation(() => s.setValue(0)));
      return undefined;
    }
    const loops = steam.map((s, i) => {
      const l = Animated.loop(
        Animated.sequence([
          Animated.delay(i * 640),
          Animated.timing(s, { toValue: 1, duration: 2300, easing: Easing.out(Easing.ease), useNativeDriver: true }),
        ])
      );
      l.start();
      return l;
    });
    return () => loops.forEach((l) => l.stop());
  }, [worried, steam]);

  // Happy: a scale burst on the body and a quick double bounce of the brows.
  useEffect(() => {
    if (state !== 'happy') return;
    pop.setValue(1);
    browBounce.setValue(0);
    Animated.parallel([
      Animated.sequence([
        Animated.timing(pop, { toValue: 1.18, duration: 130, easing: Easing.out(Easing.ease), useNativeDriver: true }),
        Animated.spring(pop, { toValue: 1, friction: 3, tension: 150, useNativeDriver: true }),
      ]),
      Animated.sequence([
        Animated.timing(browBounce, { toValue: 1, duration: 90, useNativeDriver: true }),
        Animated.timing(browBounce, { toValue: 0, duration: 90, useNativeDriver: true }),
        Animated.timing(browBounce, { toValue: 1, duration: 90, useNativeDriver: true }),
        Animated.timing(browBounce, { toValue: 0, duration: 120, useNativeDriver: true }),
      ]),
    ]).start();
  }, [state, pop, browBounce]);

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

  // ---- Derived transforms ----
  // Layer 2: body lifts, plus a squash and stretch keyed to its height.
  const bodyY = bodyFloat.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.1] });
  const bodySX = bodyFloat.interpolate({ inputRange: [0, 1], outputRange: [1.03, 0.98] });
  const bodySY = bodyFloat.interpolate({ inputRange: [0, 1], outputRange: [0.98, 1.03] });
  const jitter = jitterX.interpolate({ inputRange: [-1, 1], outputRange: [-H * 0.035, H * 0.035] });
  // Layer 3: the face adds a small, phase lagged lift on top of the body, so
  // it appears to ride the surface a beat behind. The happy bounce perks the
  // whole face up quickly (there are no brows in the happy state to bounce).
  const faceY = Animated.add(
    faceFloat.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.03] }),
    browBounce.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.06] })
  );
  // Layer 3b: the brows (worried only) lag the most.
  const browY = browFloat.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.05] });
  // Layer 1: shadow tightens and fades as Pan rises.
  const shadowOpacity = bodyFloat.interpolate({ inputRange: [0, 1], outputRange: [1, 0.55] });
  const shadowScale = bodyFloat.interpolate({ inputRange: [0, 1], outputRange: [1, 0.84] });
  const pupilColor = worried ? RED : INK;

  // One eye: white ball, dark (or red) pupil low and centered for a sweet
  // look, a bright shine on top. The whole eye scales on Y to blink.
  const Eye = () => (
    <Animated.View style={[styles.eye, { transform: [{ scaleY: blink }] }]}>
      <View style={[styles.pupil, { backgroundColor: pupilColor }]}>
        <View style={styles.shine} />
      </View>
    </Animated.View>
  );

  return (
    <View style={[styles.container, style]} accessibilityRole="image" accessibilityLabel="Pan, the Salapify coffee mascot">
      <View style={styles.halo} />

      {/* Layer 4: steam, its own async loop. */}
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
                  // A gentle sideways weave so the wisp is wavy, not a straight bar.
                  { translateX: s.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0, H * 0.05, -H * 0.02] }) },
                  { scale: s.interpolate({ inputRange: [0, 1], outputRange: [0.7, 1.15] }) },
                ],
              },
            ]}
          />
        ))}
      </View>

      {/* Layer 1: ground shadow, grounded (does not float with the cup). */}
      <Animated.View style={[styles.shadow, { opacity: shadowOpacity, transform: [{ scaleX: shadowScale }] }]} />

      {/* Layer 2: the body group. Floats, squashes, and jitters when worried. */}
      <Animated.View
        style={[
          styles.mugGroup,
          { transform: [{ translateY: bodyY }, { translateX: jitter }, { scaleX: bodySX }, { scaleY: bodySY }, { scale: pop }] },
        ]}
      >
        <View style={styles.handle} />
        <View style={styles.body}>
          {/* A soft rim sheen so the cup reads as an open mug, not a brow. */}
          <View style={styles.rim} />

          {/* Layer 3: the face rides a beat behind the body. */}
          <Animated.View style={[styles.face, { transform: [{ translateY: faceY }] }]}>
            {/* Layer 3b: brows lag the most and furrow when worried. */}
            <Animated.View style={[styles.browGroup, { transform: [{ translateY: browY }] }]}>
              {worried ? (
                <>
                  <View style={[styles.brow, styles.browLeftWorried]} />
                  <View style={[styles.brow, styles.browRightWorried]} />
                </>
              ) : null}
            </Animated.View>

            <View style={styles.eyeRow}>
              <Eye />
              <Eye />
            </View>

            <Animated.View style={[styles.cheek, styles.cheekLeft, { opacity: cheek }]} />
            <Animated.View style={[styles.cheek, styles.cheekRight, { opacity: cheek }]} />

            <View style={[styles.mouth, happy && styles.mouthHappy, worried && styles.mouthWorried]} />
          </Animated.View>
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
    steam0: { left: H * 0.36 },
    steam1: { left: H * 0.55 },
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

    // The face layer fills the body so its children keep absolute positions
    // while the whole group rides up and down a beat behind.
    face: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
    browGroup: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
    brow: { position: 'absolute', top: H * 0.26, width: H * 0.15, height: H * 0.05, borderRadius: H * 0.025, backgroundColor: INK },
    // Worried brows furrow: angled harder and pulled down toward the eyes.
    browLeftWorried: { left: H * 0.2, top: H * 0.28, transform: [{ rotate: '22deg' }] },
    browRightWorried: { right: H * 0.2, top: H * 0.28, transform: [{ rotate: '-22deg' }] },

    eyeRow: { position: 'absolute', top: H * 0.34, left: 0, right: 0, flexDirection: 'row', justifyContent: 'center', gap: H * 0.14 },
    eye: { width: ED, height: ED, borderRadius: ED / 2, backgroundColor: WHITE, alignItems: 'center', justifyContent: 'flex-end', paddingBottom: H * 0.02 },
    pupil: { width: PD, height: PD, borderRadius: PD / 2, alignItems: 'flex-start', justifyContent: 'flex-start' },
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
