// MascotSkia: the high fidelity Pan, drawn on a Skia canvas and animated with
// Reanimated shared values running on the UI thread. Rendered behind an error
// boundary (see Mascot.js) that falls back to the plain Animated version if
// Skia ever fails, so this can push visual fidelity without risking the app.
//
// MULTI LAYER DYNAMIC BLENDING. Each structural layer is its own Reanimated
// track, and the tracks run on staggered offsets so the character moves with
// weight and inertia rather than as one flat block:
//   Layer 1  Shadow   a blurred oval that tightens and fades as Pan rises
//   Layer 2  Body     the mug and handle, the anchor, floats first + squashes
//   Layer 3  Face     eyes, cheeks, mouth, ride ~80ms behind the body
//   Layer 3b Brows    ride ~120ms behind, the last to catch up
//   Layer 4  Steam    two wavy stroked paths on their own async rising loop
//
// The lag is real: body, face, and brows share one float period but start at
// 0ms, 80ms, 120ms, so they hold a fixed phase behind each other forever.
// A position linked squash and stretch on the body (anchored at its base)
// adds the jello feel. State blending: happy bursts the scale and perks the
// face; worried reddens the eyes, furrows the brows, freezes the steam, and
// jitters the body.

import { useEffect, useMemo } from 'react';
import { View } from 'react-native';
import { Canvas, Group, RoundedRect, Oval, Circle, Path, Skia, BlurMask } from '@shopify/react-native-skia';
import {
  useSharedValue,
  useDerivedValue,
  withRepeat,
  withTiming,
  withSequence,
  withDelay,
  withSpring,
  cancelAnimation,
  interpolate,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../context/Theme';

const INK = '#3A2317';
const WHITE = '#FFFFFF';
const RED = '#FF3B3B';
const CHEEK = 'rgba(255,120,80,0.55)';
const FLOAT_MS = 1800;

export default function MascotSkia({ size = 110, state = 'idle', style }) {
  const { colors } = useTheme();
  const H = size;
  const worried = state === 'worried';
  const primary = colors.primary;
  const halo = colors.positiveSurface;
  const muted = colors.muted;

  // Canvas and geometry, all relative to H so Pan stays crisp at any size.
  const W = H * 1.5;
  const CH = H * 1.75;
  const cx = W / 2;
  const bodyTop = H * 0.6;
  const bodyH = H * 0.95;
  const bodyX = cx - H / 2;
  const bodyBottom = bodyTop + bodyH;
  const ED = H * 0.26; // eye diameter
  const PD = H * 0.15; // pupil diameter
  const SH = H * 0.055; // shine diameter
  const eyeCy = bodyTop + H * 0.42;
  const eyeLx = cx - H * 0.17;
  const eyeRx = cx + H * 0.17;
  const pupilCy = eyeCy + H * 0.03;
  const cheekY = bodyTop + H * 0.6;
  const mouthY = bodyTop + H * 0.6;
  const shadowY = bodyBottom + H * 0.06;

  // ---- Reanimated tracks ----
  const bodyFloat = useSharedValue(0);
  const faceFloat = useSharedValue(0);
  const browFloat = useSharedValue(0);
  const jitter = useSharedValue(0);
  const pop = useSharedValue(1);
  const browBounce = useSharedValue(0);
  const blink = useSharedValue(1);
  const cheek = useSharedValue(1);
  const steamA = useSharedValue(0);
  const steamB = useSharedValue(0);

  // Blink runs forever regardless of mood.
  useEffect(() => {
    blink.value = withRepeat(
      withSequence(withDelay(2800, withTiming(0.12, { duration: 80 })), withTiming(1, { duration: 110 })),
      -1,
      false
    );
    return () => cancelAnimation(blink);
  }, [blink]);

  // The float / jitter / steam state machine.
  useEffect(() => {
    if (worried) {
      // Freeze the floats at rest, shake the body, kill the steam.
      cancelAnimation(bodyFloat);
      cancelAnimation(faceFloat);
      cancelAnimation(browFloat);
      bodyFloat.value = withTiming(0, { duration: 200 });
      faceFloat.value = withTiming(0, { duration: 200 });
      browFloat.value = withTiming(0, { duration: 200 });
      jitter.value = withRepeat(withSequence(withTiming(1, { duration: 55 }), withTiming(-1, { duration: 55 })), -1, false);
      cancelAnimation(steamA);
      cancelAnimation(steamB);
      steamA.value = withTiming(0, { duration: 120 });
      steamB.value = withTiming(0, { duration: 120 });
      cheek.value = withTiming(0, { duration: 220 });
    } else {
      cancelAnimation(jitter);
      jitter.value = withTiming(0, { duration: 120 });
      // Same period, staggered starts: body leads, face +80ms, brows +120ms.
      const osc = () => withRepeat(withTiming(1, { duration: FLOAT_MS, easing: Easing.inOut(Easing.ease) }), -1, true);
      bodyFloat.value = osc();
      faceFloat.value = withDelay(80, osc());
      browFloat.value = withDelay(120, osc());
      // Steam rises and resets (reverse false), the two wisps offset in time.
      const rise = () => withRepeat(withTiming(1, { duration: 2300, easing: Easing.out(Easing.ease) }), -1, false);
      steamA.value = rise();
      steamB.value = withDelay(640, rise());
      cheek.value = withTiming(1, { duration: 220 });
    }
  }, [worried, bodyFloat, faceFloat, browFloat, jitter, steamA, steamB, cheek]);

  // Happy: a scale burst on the body and a quick perk of the face.
  useEffect(() => {
    if (state !== 'happy') return;
    pop.value = withSequence(withTiming(1.18, { duration: 130, easing: Easing.out(Easing.ease) }), withSpring(1, { damping: 6, stiffness: 180 }));
    browBounce.value = withSequence(
      withTiming(1, { duration: 90 }),
      withTiming(0, { duration: 90 }),
      withTiming(1, { duration: 90 }),
      withTiming(0, { duration: 120 })
    );
  }, [state, pop, browBounce]);

  // ---- Derived transforms (worklets on the UI thread) ----
  const bodyTransform = useDerivedValue(() => {
    const ty = -bodyFloat.value * H * 0.1;
    const tx = jitter.value * H * 0.035;
    const sx = interpolate(bodyFloat.value, [0, 1], [1.03, 0.98]);
    const sy = interpolate(bodyFloat.value, [0, 1], [0.98, 1.03]);
    return [{ translateX: tx }, { translateY: ty }, { scale: pop.value }, { scaleX: sx }, { scaleY: sy }];
  });
  const faceTransform = useDerivedValue(() => [
    { translateY: -faceFloat.value * H * 0.03 - browBounce.value * H * 0.06 },
  ]);
  const browTransform = useDerivedValue(() => [{ translateY: -browFloat.value * H * 0.05 }]);
  const eyeLTransform = useDerivedValue(() => [{ scaleY: blink.value }]);
  const eyeRTransform = useDerivedValue(() => [{ scaleY: blink.value }]);
  const shadowTransform = useDerivedValue(() => {
    const s = interpolate(bodyFloat.value, [0, 1], [1, 0.84]);
    return [{ scaleX: s }, { scaleY: s }];
  });
  const shadowOpacity = useDerivedValue(() => interpolate(bodyFloat.value, [0, 1], [0.22, 0.12]));
  const steamATransform = useDerivedValue(() => [{ translateY: -steamA.value * H * 0.4 }]);
  const steamBTransform = useDerivedValue(() => [{ translateY: -steamB.value * H * 0.4 }]);
  const steamAOpacity = useDerivedValue(() => interpolate(steamA.value, [0, 0.2, 0.8, 1], [0, 0.5, 0.3, 0]));
  const steamBOpacity = useDerivedValue(() => interpolate(steamB.value, [0, 0.2, 0.8, 1], [0, 0.5, 0.3, 0]));

  // ---- Static Skia paths, rebuilt only when size or mood changes ----
  const handlePath = useMemo(() => {
    const p = Skia.Path.Make();
    p.addArc({ x: cx + H * 0.24, y: bodyTop + H * 0.24, width: H * 0.42, height: H * 0.42 }, -70, 150);
    return p;
  }, [H, cx, bodyTop]);

  const steamPathA = useMemo(() => wavyPath(cx - H * 0.12, bodyTop, H), [H, cx, bodyTop]);
  const steamPathB = useMemo(() => wavyPath(cx + H * 0.12, bodyTop, H), [H, cx, bodyTop]);

  const mouthPath = useMemo(() => {
    const p = Skia.Path.Make();
    if (worried) {
      // A small straight worried line.
      p.moveTo(cx - H * 0.08, mouthY + H * 0.05);
      p.lineTo(cx + H * 0.08, mouthY + H * 0.05);
      return p;
    }
    const w = state === 'happy' ? H * 0.15 : H * 0.12;
    const d = state === 'happy' ? H * 0.18 : H * 0.13;
    // An open grin: down curve for the smile, shallow curve back for the top.
    p.moveTo(cx - w, mouthY);
    p.quadTo(cx, mouthY + d, cx + w, mouthY);
    p.quadTo(cx, mouthY + d * 0.35, cx - w, mouthY);
    p.close();
    return p;
  }, [H, cx, mouthY, worried, state]);

  const pupilColor = worried ? RED : INK;

  return (
    <View style={[{ width: W, height: CH }, style]} accessibilityRole="image" accessibilityLabel="Pan, the Salapify coffee mascot">
      <Canvas style={{ flex: 1 }}>
        {/* Soft brand halo behind everything. */}
        <Circle cx={cx} cy={bodyTop + H * 0.5} r={H * 0.72} color={halo} opacity={0.7} />

        {/* Layer 1: blurred ground shadow, tightens and fades as Pan rises. */}
        <Group origin={{ x: cx, y: shadowY }} transform={shadowTransform} opacity={shadowOpacity}>
          <Oval x={cx - H * 0.32} y={shadowY - H * 0.05} width={H * 0.64} height={H * 0.11} color="#140A05">
            <BlurMask blur={H * 0.05} style="normal" />
          </Oval>
        </Group>

        {/* Layer 4: two wavy steam wisps rising on their own loop. */}
        <Group transform={steamATransform} opacity={steamAOpacity}>
          <Path path={steamPathA} style="stroke" strokeWidth={H * 0.05} strokeCap="round" color={muted} />
        </Group>
        <Group transform={steamBTransform} opacity={steamBOpacity}>
          <Path path={steamPathB} style="stroke" strokeWidth={H * 0.05} strokeCap="round" color={muted} />
        </Group>

        {/* Layer 2: the body group. Floats, squashes from its base, jitters. */}
        <Group origin={{ x: cx, y: bodyBottom }} transform={bodyTransform}>
          {/* Handle behind the cup. */}
          <Path path={handlePath} style="stroke" strokeWidth={H * 0.1} strokeCap="round" color={primary} />
          {/* Cup body. */}
          <RoundedRect x={bodyX} y={bodyTop} width={H} height={bodyH} r={H * 0.34} color={primary} />
          {/* Rim sheen so it reads as an open mug. */}
          <RoundedRect x={cx - H * 0.31} y={bodyTop + H * 0.08} width={H * 0.62} height={H * 0.1} r={H * 0.05} color="rgba(255,255,255,0.16)" />

          {/* Layer 3: the face, riding a beat behind. */}
          <Group transform={faceTransform}>
            {/* Layer 3b: brows (worried only), furrowed and lagging most. */}
            {worried ? (
              <Group transform={browTransform}>
                <Path path={browPath(cx - H * 0.2, bodyTop + H * 0.3, H, 1)} style="stroke" strokeWidth={H * 0.05} strokeCap="round" color={INK} />
                <Path path={browPath(cx + H * 0.2, bodyTop + H * 0.3, H, -1)} style="stroke" strokeWidth={H * 0.05} strokeCap="round" color={INK} />
              </Group>
            ) : null}

            {/* Left eye. */}
            <Group origin={{ x: eyeLx, y: eyeCy }} transform={eyeLTransform}>
              <Circle cx={eyeLx} cy={eyeCy} r={ED / 2} color={WHITE} />
              <Circle cx={eyeLx} cy={pupilCy} r={PD / 2} color={pupilColor} />
              <Circle cx={eyeLx - PD * 0.18} cy={pupilCy - PD * 0.22} r={SH / 2} color={WHITE} />
            </Group>
            {/* Right eye. */}
            <Group origin={{ x: eyeRx, y: eyeCy }} transform={eyeRTransform}>
              <Circle cx={eyeRx} cy={eyeCy} r={ED / 2} color={WHITE} />
              <Circle cx={eyeRx} cy={pupilCy} r={PD / 2} color={pupilColor} />
              <Circle cx={eyeRx - PD * 0.18} cy={pupilCy - PD * 0.22} r={SH / 2} color={WHITE} />
            </Group>

            {/* Blush cheeks, softened, fading out when worried. */}
            <Group opacity={cheek}>
              <Circle cx={cx - H * 0.28} cy={cheekY} r={H * 0.075} color={CHEEK}>
                <BlurMask blur={H * 0.03} style="normal" />
              </Circle>
              <Circle cx={cx + H * 0.28} cy={cheekY} r={H * 0.075} color={CHEEK}>
                <BlurMask blur={H * 0.03} style="normal" />
              </Circle>
            </Group>

            {/* Mouth: a real curved grin, or a worried line. */}
            <Path path={mouthPath} style={worried ? 'stroke' : 'fill'} strokeWidth={H * 0.045} strokeCap="round" color={INK} />
          </Group>
        </Group>
      </Canvas>
    </View>
  );
}

// A gentle S curve for a rising steam wisp, from (x0, top) upward.
function wavyPath(x0, top, H) {
  const p = Skia.Path.Make();
  p.moveTo(x0, top);
  p.cubicTo(x0 - H * 0.07, top - H * 0.12, x0 + H * 0.07, top - H * 0.24, x0, top - H * 0.36);
  return p;
}

// One worried brow: a short bar angled up at its inner end. dir +1 for the
// left brow (inner end on the right), -1 for the right brow.
function browPath(cxb, cyb, H, dir) {
  const p = Skia.Path.Make();
  p.moveTo(cxb - dir * H * 0.07, cyb + H * 0.02);
  p.lineTo(cxb + dir * H * 0.07, cyb - H * 0.03);
  return p;
}
