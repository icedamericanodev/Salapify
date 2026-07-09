// Settings screen (reached from the More tab). This tab is kept short: the
// MY MONEY tools sit in an icon grid, and the look, reminders, preferences, and
// the Data tools (backup/restore/CSV/v1 import, start fresh) each open their own
// sub-screen (Appearance, Notifications and security, Preferences, Backup and
// data). Feedback still lives inline here. Everything is web-preview compatible
// (no native libraries in the always-rendered path).

import { useMemo, useState } from 'react';
import { Alert, Linking, Platform, Pressable, ScrollView, Share, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { spacing, radius, fontSize, fontWeight, PALETTE_OPTIONS, APPEARANCE_MODES } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import Mascot from '../../components/Mascot';
import * as Updates from 'expo-updates';

// The MY MONEY tools, shown as a compact 2-column icon grid instead of ten
// tall rows so the tab scans faster (five rows of tiles, half the scan
// targets). Each tile just opens the same screen the old row did; nothing
// about the destinations changed. Icons do the wayfinding, the label stays
// clear. Labels are kept short enough to sit on at most two lines in a tile.
const MONEY_LINKS = [
  { route: '/search', label: 'Search everything', icon: 'search-outline' },
  { route: '/accounts', label: 'Accounts', icon: 'wallet-outline' },
  { route: '/goals', label: 'Goals', icon: 'flag-outline' },
  { route: '/learn', label: 'Money lessons', icon: 'school-outline' },
  { route: '/mindset', label: 'Money mindset', icon: 'sparkles-outline' },
  { route: '/receivables', label: 'People who owe me', icon: 'people-outline' },
  { route: '/payables', label: 'People I owe', icon: 'arrow-up-circle-outline' },
  { route: '/reports', label: 'Reports', icon: 'bar-chart-outline' },
  { route: '/notes', label: 'Notes with calculator', icon: 'document-text-outline' },
  { route: '/recurring', label: 'Recurring', icon: 'repeat-outline' },
  { route: '/history', label: 'All transactions', icon: 'list-outline' },
];

export default function More() {
  const { colors, palette, mode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data } = useAppData();
  const router = useRouter();

  const settings = data.settings;

  // ---- Over the air updates ----
  const [updMsg, setUpdMsg] = useState('');
  async function checkUpdates() {
    if (Platform.OS === 'web') return;
    setUpdMsg('Checking...');
    try {
      const res = await Updates.checkForUpdateAsync();
      if (res.isAvailable) {
        setUpdMsg('Downloading...');
        await Updates.fetchUpdateAsync();
        Alert.alert('Update ready', 'Restart the app now to apply it?', [
          {
            text: 'Later',
            style: 'cancel',
            onPress: () => setUpdMsg('Ready. Applies on next open.'),
          },
          { text: 'Restart now', onPress: () => Updates.reloadAsync() },
        ]);
      } else {
        setUpdMsg('Up to date.');
      }
    } catch (e) {
      setUpdMsg(`Failed: ${e.message || 'unknown error'}`);
    }
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Settings</Text>

        <Pressable onPress={() => router.push('/pan')} style={({ pressed }) => [styles.panRow, pressed && styles.pressed]}>
          <Mascot size={40} />
          <View style={{ flex: 1 }}>
            <Text style={styles.panRowTitle}>Ask Pan</Text>
            <Text style={styles.panRowSub}>Your money buddy. Ask about spending, utang, goals, and bills.</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.onPrimary} />
        </Pressable>

        <Text style={styles.sectionTitle}>MY MONEY</Text>
        {/* A compact 2-column icon grid instead of tall rows, so the tab scans
            fast. An odd count leaves one tile alone on the last row, which the
            space-between layout keeps left aligned and tidy. */}
        <View style={styles.moneyGrid}>
          {MONEY_LINKS.map((link) => (
            <Pressable
              key={link.route}
              onPress={() => router.push(link.route)}
              style={({ pressed }) => [styles.moneyTile, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel={link.label}
            >
              <Ionicons name={link.icon} size={26} color={colors.text} style={styles.moneyIcon} />
              <Text style={styles.moneyLabel} numberOfLines={2}>{link.label}</Text>
            </Pressable>
          ))}
        </View>

        <Text style={styles.sectionTitle}>SETTINGS</Text>
        <View style={styles.card}>
          {/* Both the light/dark mode and the 8 color themes now live on their
              own /appearance screen, so this tab stays short. This row shows the
              current theme's name and opens that screen. */}
          <Pressable onPress={() => router.push('/appearance')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Theme and colors</Text>
            <View style={styles.rowRight}>
              <Text style={styles.rowValue}>
                {[
                  (PALETTE_OPTIONS.find((o) => o.key === palette) || {}).label,
                  (APPEARANCE_MODES.find((m) => m.key === mode) || {}).label,
                ].filter(Boolean).join(', ')}
              </Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </View>
          </Pressable>
          {/* Reminders and app lock now live on their own /notifications
              screen, and all the currency/budget/payday/quick add settings live
              on /preferences, so this tab stays short. These two rows just open
              those screens. */}
          <Pressable onPress={() => router.push('/notifications')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Notifications and security</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/preferences')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Preferences</Text>
            <View style={styles.rowRight}>
              <Text style={styles.rowValue} numberOfLines={1}>
                {(settings.currencyCode || '') + ' ' + settings.currency}
              </Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </View>
          </Pressable>
          {/* Backup, restore, CSV, v1 import, and Start fresh now live on their
              own /data screen. It sits here as the fourth settings room; the
              destructive erase is separated inside that screen, not on this tab. */}
          <Pressable onPress={() => router.push('/data')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Backup and data</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>FEEDBACK</Text>
        <View style={styles.card}>
          <Pressable
            onPress={() =>
              Linking.openURL(
                'mailto:dimaguila.carlam@gmail.com?subject=Salapify%20feedback'
              ).catch(() => {})
            }
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
          >
            <View style={{ flex: 1, paddingRight: spacing.md }}>
              <Text style={styles.rowLabel}>Send feedback</Text>
              <Text style={styles.rowHint}>Found a bug or want a feature? Email goes straight to the maker</Text>
            </View>
            <Ionicons name="mail-outline" size={18} color={colors.faint} />
          </Pressable>
          <Pressable
            onPress={() =>
              Share.share({
                message:
                  'I track my budget, utang, and bills with Salapify. Offline, no ads, core features free. https://icedamericanodev.github.io/Salapify/',
              }).catch(() => {})
            }
            style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
          >
            <View style={{ flex: 1, paddingRight: spacing.md }}>
              <Text style={styles.rowLabel}>Share Salapify</Text>
              <Text style={styles.rowHint}>Send it to a friend who keeps asking where the sweldo went</Text>
            </View>
            <Ionicons name="share-social-outline" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <View style={styles.mascotWrap}>
          <Mascot size={104} />
          <Text style={styles.mascotName}>Pan, your kape powered money buddy. ☕</Text>
        </View>

        <Text style={styles.sectionTitle}>ABOUT</Text>
        <View style={styles.card}>
          <View style={styles.row}>
            <Text style={styles.rowLabel}>Version</Text>
            <Text style={styles.rowValue}>1.4.1</Text>
          </View>
          {/* This stamp changes with every over the air update, so you can
              always tell at a glance whether the latest code has arrived. It is
              a stacked block (label on top, value full width below) and kept to
              a short line, so a longer note can never run off the card. */}
          <View style={[styles.stampRow, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Update stamp</Text>
            <Text style={styles.stampValue}>v3.86 · History now views by Month, Year, or a Custom date range</Text>
          </View>
          {Platform.OS !== 'web' ? (
            <>
              <Pressable onPress={checkUpdates} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
                <Text style={styles.rowLabel}>Check for updates</Text>
                <Text style={styles.rowValue}>{updMsg || 'Tap to check'}</Text>
              </Pressable>
              <View style={[styles.row, styles.rowDivider]}>
                <Text style={styles.rowLabel}>Update channel</Text>
                <Text style={styles.rowValue}>{Updates.channel || 'none'}</Text>
              </View>
              <View style={[styles.row, styles.rowDivider]}>
                <Text style={styles.rowLabel}>Runtime</Text>
                <Text style={styles.rowValue}>{String(Updates.runtimeVersion || 'none')}</Text>
              </View>
            </>
          ) : null}
          <Pressable
            onPress={() => Linking.openURL('https://icedamericanodev.github.io/Salapify/privacy.html').catch(() => {})}
            style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
          >
            <Text style={styles.rowLabel}>Privacy policy</Text>
            <Ionicons name="open-outline" size={18} color={colors.faint} />
          </Pressable>
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Salapify</Text>
            <Text style={styles.rowValue}>v2</Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginBottom: spacing.lg },
    panRow: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      backgroundColor: colors.primary,
      borderRadius: radius.lg,
      padding: spacing.lg,
      marginBottom: spacing.lg,
    },
    panRowTitle: { color: colors.onPrimary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    panRowSub: { color: colors.onPrimary, fontSize: fontSize.small, opacity: 0.85, marginTop: 2 },
    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    mascotWrap: { alignItems: 'center', marginTop: spacing.xl, marginBottom: spacing.sm },
    mascotName: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm, textAlign: 'center' },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },

    // MY MONEY icon grid.
    moneyGrid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' },
    moneyTile: {
      width: '48.5%',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      paddingVertical: spacing.lg,
      paddingHorizontal: spacing.md,
      marginBottom: spacing.md,
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: 92,
    },
    moneyIcon: { marginBottom: spacing.sm },
    moneyLabel: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium, textAlign: 'center' },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowValue: { color: colors.muted, fontSize: fontSize.body },
    // The Update stamp stacks its value under the label so a longer line wraps
    // full width inside the card instead of overflowing off the screen.
    stampRow: { paddingVertical: spacing.md + 2 },
    stampValue: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs },
    rowRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    rowHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },
  });
}
