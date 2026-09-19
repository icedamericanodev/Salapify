// MascotClay: Pan as the 3D clay render, brought to life with motion. The mug
// is a transparent PNG (assets/pan-clay.png); everything around it (a soft
// brand halo, rising steam, a grounded shadow) is drawn in code and animated,
// so a single still image reads as a living character. Pure Image plus core
// Animated, so it ships over the air and cannot crash the app.
//
// The face is fixed (one render), so interactivity here is body language, not
// expression: gentle breathing float when idle, a happy pop, and a worried
// shiver with the halo flushing warning red and the steam going cold. Swap in
// extra render frames later for real blink and wink, still over the air.

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, Image, StyleSheet, View } from 'react-native';
import { useTheme } from '../context/Theme';

const PAN = require('../assets/pan-clay.png');

export default function MascotClay({ size = 110, state = 'idle', style }) {
  const { colors } = useTheme();
  const H = size;
  const styles = useMemo(() => makeStyles(H, colors), [H, colors]);
  const worried = state === 'worried';

  const floatY = useRef(new Animated.Value(0)).current;
  const shiverX = useRef(new Animated.Value(0)).current;
  const pop = useRef(new Animated.Value(1)).current;
  const steamRef = useRef(null);
  if (!steamRef.current) {
    steamRef.current = [new Animated.Value(0), new Animated.Value(0), new Animated.Value(0)];
  }
  const steam = steamRef.current;

  // Breathing float, or a worried shiver (never both).
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
          Animated.timing(floatY, { toValue: 1, duration: 2000, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
          Animated.timing(floatY, { toValue: 0, duration: 2000, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
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
          Animated.delay(i * 620),
          Animated.timing(s, { toValue: 1, duration: 2400, easing: Easing.out(Easing.ease), useNativeDriver: true }),
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
    pop.setValue(1);
    Animated.sequence([
      Animated.timing(pop, { toValue: 1.16, duration: 130, easing: Easing.out(Easing.ease), useNativeDriver: true }),
      Animated.spring(pop, { toValue: 1, friction: 3, tension: 150, useNativeDriver: true }),
    ]).start();
  }, [state, pop]);

  const translateY = floatY.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.06] });
  const translateX = shiverX.interpolate({ inputRange: [-1, 1], outputRange: [-H * 0.03, H * 0.03] });
  const breathe = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 1.02] });
  const shadowOpacity = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.6] });
  const shadowScale = floatY.interpolate({ inputRange: [0, 1], outputRange: [1, 0.9] });

  return (
    <View style={[styles.container, style]} accessibilityRole="image" accessibilityLabel="Pan, the Salapify coffee mascot">
      {/* Soft brand halo, flushing warning red when worried. */}
      <View style={[styles.halo, worried && { backgroundColor: colors.warning, opacity: 0.28 }]} />

      {/* Steam rising from the mug, drawn and animated in code. */}
      <View style={styles.steamWrap} pointerEvents="none">
        {steam.map((s, i) => (
          <Animated.View
            key={i}
            style={[
              styles.steam,
              styles[`steam${i}`],
              {
                opacity: s.interpolate({ inputRange: [0, 0.2, 0.8, 1], outputRange: [0, 0.45, 0.3, 0] }),
                transform: [
                  { translateY: s.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.42] }) },
                  { translateX: s.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0, H * 0.04, -H * 0.02] }) },
                  { scale: s.interpolate({ inputRange: [0, 1], outputRange: [0.7, 1.1] }) },
                ],
              },
            ]}
          />
        ))}
      </View>

      {/* Grounded shadow. */}
      <Animated.View style={[styles.shadow, { opacity: shadowOpacity, transform: [{ scaleX: shadowScale }] }]} />

      {/* The clay mug itself, floating, breathing, popping, shivering. */}
      <Animated.View style={{ transform: [{ translateY }, { translateX }, { scale: pop }, { scaleX: breathe }, { scaleY: breathe }] }}>
        <Image source={PAN} style={styles.pan} resizeMode="contain" />
      </Animated.View>
    </View>
  );
}

function makeStyles(H, colors) {
  return StyleSheet.create({
    container: { width: H * 1.5, height: H * 1.7, alignItems: 'center', justifyContent: 'flex-end' },
    halo: {
      position: 'absolute',
      bottom: H * 0.22,
      width: H * 1.34,
      height: H * 1.34,
      borderRadius: H * 0.67,
      backgroundColor: colors.positiveSurface,
      opacity: 0.7,
    },
    steamWrap: { position: 'absolute', top: H * 0.02, width: H, height: H * 0.5, alignItems: 'center' },
    steam: { position: 'absolute', top: H * 0.2, width: H * 0.07, height: H * 0.22, borderRadius: H * 0.035, backgroundColor: colors.muted },
    steam0: { left: H * 0.36 },
    steam1: { left: H * 0.47 },
    steam2: { left: H * 0.58 },
    shadow: { position: 'absolute', bottom: H * 0.12, width: H * 0.66, height: H * 0.11, borderRadius: H * 0.06, backgroundColor: 'rgba(20,10,5,0.16)' },
    pan: { width: H * 1.15, height: H * 1.15 },
  });
}
