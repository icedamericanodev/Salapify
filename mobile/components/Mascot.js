// Salapify's mascot: a little coffee colored robot with a round head, a dark
// visor holding two glowing digital eyes that blink, a pulsing antenna, and a
// gentle continuous float. Drawn entirely from plain views and geometry (no
// image asset, no drawing library), so it ships over the air and scales to
// any size crisply.
//
// The mascot keeps its own fixed Barako brand colors on purpose, the way a
// logo does, so it stays recognizably Salapify no matter which color theme
// the user picks. Give it a `size` (the head diameter, default 120).

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Easing, StyleSheet, View } from 'react-native';

// The mascot's own identity palette. Not theme reactive on purpose.
const C = {
  head: '#FF8A3D', // roasted Barako orange
  headEdge: '#E9701F', // a slightly deeper rim for a touch of form
  visor: '#2A1305', // espresso screen the eyes glow against
  eye: '#FFE9C7', // warm cream glow
  antenna: '#FFC24D', // amber
  cheek: '#FF6B57', // soft coral blush
  smile: '#FFE9C7',
  shadow: 'rgba(20,10,5,0.20)',
};

export default function Mascot({ size = 120, style }) {
  const H = size;
  const styles = useMemo(() => makeStyles(H), [H]);

  // One value bobs the whole body up and down; the shadow reads from it too.
  const float = useRef(new Animated.Value(0)).current;
  // Eyes squash to a line on blink; antenna dot breathes.
  const blink = useRef(new Animated.Value(1)).current;
  const pulse = useRef(new Animated.Value(0.5)).current;

  useEffect(() => {
    const floatLoop = Animated.loop(
      Animated.sequence([
        Animated.timing(float, { toValue: 1, duration: 1900, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(float, { toValue: 0, duration: 1900, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    );
    // A blink is a quick squash and release, spaced out so it feels alive,
    // not twitchy.
    const blinkLoop = Animated.loop(
      Animated.sequence([
        Animated.delay(2600),
        Animated.timing(blink, { toValue: 0.08, duration: 80, useNativeDriver: true }),
        Animated.timing(blink, { toValue: 1, duration: 120, useNativeDriver: true }),
      ])
    );
    const pulseLoop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 900, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0.4, duration: 900, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    );
    floatLoop.start();
    blinkLoop.start();
    pulseLoop.start();
    return () => {
      floatLoop.stop();
      blinkLoop.stop();
      pulseLoop.stop();
    };
  }, [float, blink, pulse]);

  const translateY = float.interpolate({ inputRange: [0, 1], outputRange: [0, -H * 0.1] });
  const shadowOpacity = float.interpolate({ inputRange: [0, 1], outputRange: [1, 0.55] });
  const shadowScale = float.interpolate({ inputRange: [0, 1], outputRange: [1, 0.86] });

  return (
    <View style={[styles.container, style]} accessibilityRole="image" accessibilityLabel="Salapify mascot">
      {/* Ground shadow shrinks as the body lifts, so the float reads as height. */}
      <Animated.View style={[styles.shadow, { opacity: shadowOpacity, transform: [{ scaleX: shadowScale }] }]} />

      <Animated.View style={[styles.body, { transform: [{ translateY }] }]}>
        {/* Antenna: a breathing amber dot on a thin stem. */}
        <Animated.View style={[styles.antennaDot, { opacity: pulse }]} />
        <View style={styles.antennaStem} />

        {/* Head */}
        <View style={styles.head}>
          {/* Visor with two glowing eyes. */}
          <View style={styles.visor}>
            <Animated.View style={[styles.eye, { transform: [{ scaleY: blink }] }]} />
            <Animated.View style={[styles.eye, { transform: [{ scaleY: blink }] }]} />
          </View>
          {/* Blush and a small smile for warmth. */}
          <View style={[styles.cheek, styles.cheekLeft]} />
          <View style={[styles.cheek, styles.cheekRight]} />
          <View style={styles.smile} />
        </View>
      </Animated.View>
    </View>
  );
}

function makeStyles(H) {
  const eyeW = H * 0.13;
  const eyeH = H * 0.24;
  return StyleSheet.create({
    container: { width: H, height: H * 1.4, alignItems: 'center', justifyContent: 'flex-end' },
    shadow: {
      position: 'absolute',
      bottom: H * 0.04,
      width: H * 0.58,
      height: H * 0.12,
      borderRadius: H * 0.06,
      backgroundColor: C.shadow,
    },
    body: { alignItems: 'center' },
    antennaDot: { width: H * 0.1, height: H * 0.1, borderRadius: H * 0.05, backgroundColor: C.antenna },
    antennaStem: { width: H * 0.03, height: H * 0.12, backgroundColor: C.antenna, marginBottom: -H * 0.02, borderRadius: H * 0.015 },
    head: {
      width: H,
      height: H,
      borderRadius: H / 2,
      backgroundColor: C.head,
      borderBottomWidth: H * 0.03,
      borderBottomColor: C.headEdge,
    },
    visor: {
      position: 'absolute',
      top: H * 0.27,
      left: H * 0.14,
      width: H * 0.72,
      height: H * 0.36,
      borderRadius: H * 0.18,
      backgroundColor: C.visor,
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      gap: H * 0.12,
    },
    eye: {
      width: eyeW,
      height: eyeH,
      borderRadius: eyeW / 2,
      backgroundColor: C.eye,
      // A soft amber glow around the eyes (renders on iOS; harmless on Android).
      shadowColor: C.antenna,
      shadowOpacity: 0.9,
      shadowRadius: H * 0.05,
      shadowOffset: { width: 0, height: 0 },
    },
    cheek: {
      position: 'absolute',
      top: H * 0.6,
      width: H * 0.11,
      height: H * 0.11,
      borderRadius: H * 0.055,
      backgroundColor: C.cheek,
      opacity: 0.5,
    },
    cheekLeft: { left: H * 0.14 },
    cheekRight: { right: H * 0.14 },
    smile: {
      position: 'absolute',
      top: H * 0.66,
      alignSelf: 'center',
      width: H * 0.24,
      height: H * 0.13,
      borderBottomWidth: H * 0.028,
      borderBottomColor: C.smile,
      borderBottomLeftRadius: H * 0.12,
      borderBottomRightRadius: H * 0.12,
      backgroundColor: 'transparent',
    },
  });
}
