// LockGate covers the whole app with a lock screen when App lock is on in
// Settings. Unlocking uses the phone's own biometrics (fingerprint or face)
// through expo-local-authentication. Quick hops to another app do not lock
// it; it locks again only after being away for over a minute. The lock is
// drawn OVER the app instead of replacing it, so a re-lock never throws
// away what you were in the middle of. If the phone has no biometrics set
// up (for example after restoring a backup onto a new phone), the gate
// turns the lock off instead of locking you out forever. On web the gate
// does nothing.

import { useEffect, useMemo, useRef, useState } from 'react';
import { AppState, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import * as LocalAuthentication from 'expo-local-authentication';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';

export default function LockGate({ children }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, loaded, loadFailed, updateSettings } = useAppData();

  const isNative = Platform.OS !== 'web';
  const lockOn = isNative && loaded && !!(data.settings && data.settings.appLock);
  const [unlocked, setUnlocked] = useState(false);
  const [checking, setChecking] = useState(false);
  const locked = lockOn && !unlocked;

  async function unlock() {
    if (checking) return;
    setChecking(true);
    try {
      // No biometrics enrolled on this phone? Then a lock can only ever
      // lock the owner out. Turn it off and let them back in.
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const enrolled = hasHardware && (await LocalAuthentication.isEnrolledAsync());
      if (!enrolled) {
        updateSettings({ appLock: false });
        setUnlocked(true);
        return;
      }
      const res = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Unlock Salapify',
        cancelLabel: 'Cancel',
      });
      if (res.success) setUnlocked(true);
    } catch (e) {
      // If biometrics fail unexpectedly, the Unlock button lets you retry.
    } finally {
      setChecking(false);
    }
  }

  // Ask for the fingerprint automatically whenever the gate closes, both on
  // cold start and after a background re-lock.
  useEffect(() => {
    if (locked) unlock();
  }, [locked]);

  // Lock again only after the app has been in the background for over a
  // minute. Switching to another app for a few seconds (checking a message,
  // copying a number from GCash) should not demand a fingerprint again.
  const awaySince = useRef(null);
  useEffect(() => {
    if (!lockOn) return undefined;
    const GRACE_MS = 60 * 1000;
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background' || state === 'inactive') {
        if (awaySince.current === null) awaySince.current = Date.now();
      } else if (state === 'active') {
        if (awaySince.current !== null && Date.now() - awaySince.current > GRACE_MS) {
          setUnlocked(false);
        }
        awaySince.current = null;
      }
    });
    return () => sub.remove();
  }, [lockOn]);

  if (!isNative) return children;

  // Until the saved settings are read we do not yet know whether the app
  // should be locked, so show a blank screen instead of flashing data.
  // If the read failed outright, let the app render so the storage error
  // message can be shown instead of a silent blank screen forever.
  if (!loaded && !loadFailed) {
    return <View style={styles.blank} />;
  }

  return (
    <View style={styles.wrap}>
      {children}
      {locked ? (
        <View style={[StyleSheet.absoluteFill, styles.screen]}>
          <View style={styles.badge}>
            <Ionicons name="finger-print" size={44} color={colors.primary} />
          </View>
          <Text style={styles.title}>Salapify is locked</Text>
          <Text style={styles.sub}>Your money stays private.</Text>
          <Pressable onPress={unlock} style={({ pressed }) => [styles.btn, pressed && styles.pressed]}>
            <Text style={styles.btnText}>{checking ? 'Checking...' : 'Unlock'}</Text>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    wrap: { flex: 1 },
    blank: { flex: 1, backgroundColor: colors.background },
    screen: {
      backgroundColor: colors.background,
      alignItems: 'center',
      justifyContent: 'center',
      padding: spacing.xl,
    },
    badge: {
      width: 88,
      height: 88,
      borderRadius: radius.pill,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      alignItems: 'center',
      justifyContent: 'center',
      marginBottom: spacing.lg,
    },
    title: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold },
    sub: { color: colors.muted, fontSize: fontSize.body, marginTop: spacing.xs, marginBottom: spacing.xl },
    btn: {
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      paddingVertical: spacing.md,
      paddingHorizontal: spacing.xxl,
      minHeight: 48,
      justifyContent: 'center',
    },
    pressed: { opacity: 0.7 },
    btnText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
