// Notifications and security screen (reached from More > Notifications and
// security). It holds the reminder toggles and the app lock switch that used to
// sit inline in the More tab and made it a very long scroll. Nothing about how
// the settings are stored or applied changed, this only moves the UI here. Reads
// live theme colors through useTheme(), so all 8 palettes and both light and dark
// render correctly.

import { useMemo } from 'react';
import { Alert, Linking, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import SectionHeader from '../components/SectionHeader';
import { ensureNotifPermission } from '../lib/notifications';
import * as LocalAuthentication from 'expo-local-authentication';

const NOTIF_OPTIONS = [
  { key: 'payday', label: 'Payday reminders', hint: 'Follows your payday schedule in Preferences' },
  { key: 'bills', label: 'Bill due reminders', hint: 'Cards and loans, 3 days before and on the day' },
  { key: 'collect', label: 'Collect money reminders', hint: 'When someone owes you and it is due' },
  { key: 'daily', label: 'Daily log reminder', hint: 'A quick 8pm nudge' },
];

export default function Notifications() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateSettings } = useAppData();

  const settings = data.settings;
  const notifs = settings.notifications || {};

  // ---- Notifications ----
  async function toggleNotif(key, on) {
    if (on) {
      const ok = await ensureNotifPermission();
      if (!ok) {
        Alert.alert(
          'Notifications are off',
          'Salapify is not allowed to send notifications. Allow it in your phone settings, then try again.'
        );
        return;
      }
    }
    // Functional update: two switches flipped while a permission dialog is
    // open must not overwrite each other with stale values.
    updateSettings((s) => ({ notifications: { ...(s.notifications || {}), [key]: on } }));
  }

  // ---- App lock (biometrics) ----
  async function toggleLock(on) {
    if (on) {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const enrolled = hasHardware && (await LocalAuthentication.isEnrolledAsync());
      if (!enrolled) {
        Alert.alert(
          'No fingerprint or face found',
          'Set up fingerprint or face unlock in your phone settings first, then try again.'
        );
        return;
      }
      // Confirm it works right now, so nobody locks themselves out.
      const res = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Confirm to turn on App lock',
      });
      if (!res.success) return;
    }
    updateSettings({ appLock: on });
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable
          onPress={() => router.back()}
          hitSlop={10}
          style={styles.back}
          accessibilityRole="button"
          accessibilityLabel="Go back"
        >
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle} accessibilityRole="header">Notifications and security</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <SectionHeader title="REMINDERS" />
        <View style={styles.card}>
          {Platform.OS === 'web' ? (
            <View style={styles.row}>
              <Text style={styles.rowLabel}>Reminders work on the phone app</Text>
            </View>
          ) : (
            NOTIF_OPTIONS.map((opt, i) => (
              <View key={opt.key} style={[styles.row, i > 0 && styles.rowDivider]}>
                <View style={{ flex: 1, paddingRight: spacing.md }}>
                  <Text style={styles.rowLabel}>{opt.label}</Text>
                  <Text style={styles.rowHint}>{opt.hint}</Text>
                </View>
                <Switch
                  value={!!notifs[opt.key]}
                  onValueChange={(on) => toggleNotif(opt.key, on)}
                  trackColor={{ false: colors.border, true: colors.primary }}
                  thumbColor={colors.onPrimary}
                />
              </View>
            ))
          )}
          {Platform.OS === 'android' ? (
            <Pressable
              onPress={() => Linking.openURL('https://dontkillmyapp.com').catch(() => {})}
              style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
            >
              <View style={{ flex: 1, paddingRight: spacing.md }}>
                <Text style={styles.rowLabel}>Reminders not arriving?</Text>
                <Text style={styles.rowHint}>
                  Some phones (Xiaomi, OPPO, vivo, realme) kill reminders to save battery. Tap for
                  the fix for your phone brand.
                </Text>
              </View>
              <Ionicons name="open-outline" size={18} color={colors.faint} />
            </Pressable>
          ) : null}
        </View>

        <SectionHeader title="SECURITY" style={styles.securityHeader} />
        <View style={styles.card}>
          {Platform.OS === 'web' ? (
            <View style={styles.row}>
              <Text style={styles.rowLabel}>App lock works on the phone app</Text>
            </View>
          ) : (
            <View style={styles.row}>
              <View style={{ flex: 1, paddingRight: spacing.md }}>
                <Text style={styles.rowLabel}>App lock</Text>
                <Text style={styles.rowHint}>Fingerprint or face unlock every time the app opens. Home screen widgets still show your totals, remove them if that matters to you</Text>
              </View>
              <Switch
                value={!!settings.appLock}
                onValueChange={toggleLock}
                trackColor={{ false: colors.border, true: colors.primary }}
                thumbColor={colors.onPrimary}
              />
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    securityHeader: { marginTop: spacing.xl },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },
  });
}
