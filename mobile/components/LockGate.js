// LockGate covers the whole app with a lock screen when App lock is on in
// Settings. Unlocking uses the phone's own biometrics (fingerprint or face)
// through expo-local-authentication. The app locks again whenever it goes to
// the background. On web the gate does nothing, since browsers have no
// biometrics and the web preview is for development only.

import { useEffect, useMemo, useState } from 'react';
import { AppState, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import * as LocalAuthentication from 'expo-local-authentication';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';

export default function LockGate({ children }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, loaded } = useAppData();

  const lockOn = Platform.OS !== 'web' && loaded && !!(data.settings && data.settings.appLock);
  const [unlocked, setUnlocked] = useState(false);
  const [checking, setChecking] = useState(false);

  async function unlock() {
    if (checking) return;
    setChecking(true);
    try {
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

  // Ask for the fingerprint right away when the app opens locked.
  useEffect(() => {
    if (lockOn && !unlocked) unlock();
  }, [lockOn]);

  // Lock again when the app is sent to the background.
  useEffect(() => {
    if (!lockOn) return undefined;
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background') setUnlocked(false);
    });
    return () => sub.remove();
  }, [lockOn]);

  if (!lockOn || unlocked) return children;

  return (
    <View style={styles.screen}>
      <View style={styles.badge}>
        <Ionicons name="finger-print" size={44} color={colors.primary} />
      </View>
      <Text style={styles.title}>Salapify is locked</Text>
      <Text style={styles.sub}>Your money stays private.</Text>
      <Pressable onPress={unlock} style={({ pressed }) => [styles.btn, pressed && styles.pressed]}>
        <Text style={styles.btnText}>{checking ? 'Checking...' : 'Unlock'}</Text>
      </Pressable>
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: {
      flex: 1,
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
    btnText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
