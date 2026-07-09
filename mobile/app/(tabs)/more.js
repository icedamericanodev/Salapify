// Settings screen (reached from the More tab). This tab is kept short: the
// MY MONEY tools sit in an icon grid, and the look, reminders, and preferences
// each open their own sub-screen (Appearance, Notifications and security,
// Preferences). The Data tools (backup/restore/CSV/v1 import, start fresh) and
// Feedback still live inline here. Everything is web-preview compatible (no
// native libraries in the always-rendered path).

import { useMemo, useState } from 'react';
import {
  Alert,
  Linking,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { spacing, radius, fontSize, fontWeight, PALETTE_OPTIONS, APPEARANCE_MODES } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { buildBackup, parseBackup, toCSV, parseV1 } from '../../lib/backup';
import { SIZE_NUDGE, SIZE_WARN } from '../../lib/storage';
import Mascot from '../../components/Mascot';
import { saveTextFile, saveToDevice, pickTextFile } from '../../lib/files';
import * as Updates from 'expo-updates';
import { todayISO } from '../../lib/format';

const DATA_ACTIONS = [
  { mode: 'backup', label: 'Back up to a file' },
  { mode: 'restore', label: 'Restore from a file' },
  { mode: 'csv', label: 'Export to CSV' },
  { mode: 'importv1', label: 'Import v1 backup' },
];

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
  { route: '/reports', label: 'Reports', icon: 'bar-chart-outline' },
  { route: '/notes', label: 'Notes with calculator', icon: 'document-text-outline' },
  { route: '/recurring', label: 'Recurring', icon: 'repeat-outline' },
  { route: '/history', label: 'All transactions', icon: 'list-outline' },
];

function downloadFile(filename, text) {
  if (Platform.OS !== 'web') return;
  const blob = new Blob([text], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function More() {
  const { colors, palette, mode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, replaceAll, updateSettings, storageSize } = useAppData();
  const router = useRouter();

  const [tool, setTool] = useState(null); // data tools modal
  const [msg, setMsg] = useState('');

  const settings = data.settings;

  // ---- Data tools ----
  // On the phone these are real files: backup and CSV ask whether to save
  // into a folder on the device (like Downloads) or open the share sheet,
  // restore and import open the file picker. The web preview keeps the
  // older text box flow.
  function offerSave(filename, text, mime, note, onDone) {
    Alert.alert('Where should it go?', note ? `${filename}\n\n${note}` : filename, [
      {
        text: 'Save to my device',
        onPress: async () => {
          try {
            const ok = await saveToDevice(filename, text, mime);
            if (ok) {
              Alert.alert('Saved', `${filename} is in the folder you picked.`);
              if (onDone) onDone();
            }
          } catch (e) {
            Alert.alert('Could not save there', e.message || 'Try Share or send instead.');
          }
        },
      },
      {
        text: 'Share or send',
        onPress: async () => {
          const ok = await saveTextFile(filename, text, mime).catch(() => false);
          if (!ok) Alert.alert('Sharing is not available', 'Try Save to my device instead.');
          else if (onDone) onDone();
        },
      },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }
  async function openTool(m) {
    setMsg('');
    if (Platform.OS !== 'web') {
      try {
        if (m === 'backup') {
          offerSave(
            `salapify-backup-${todayISO()}.json`,
            buildBackup(data),
            'application/json',
            'Receipt photos stay on this phone. The backup covers your money data, not the photos.',
            // Remember when the last backup happened, so the reminder in
            // the DATA section can tell the truth.
            () => updateSettings({ lastBackupAt: todayISO() })
          );
          return;
        }
        if (m === 'csv') {
          offerSave(`salapify-${todayISO()}.csv`, toCSV(data), 'text/csv');
          return;
        }
        const text = await pickTextFile();
        if (text == null) return;
        const parsed = m === 'importv1' ? parseV1(text) : parseBackup(text);
        Alert.alert(
          'Replace your data?',
          'Everything currently in the app will be replaced by this file.',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Replace', style: 'destructive', onPress: () => replaceAll(parsed) },
          ]
        );
      } catch (e) {
        Alert.alert('Could not read that file', e.message || 'Pick a Salapify backup file and try again.');
      }
      return;
    }
    if (m === 'backup') setTool({ mode: m, text: buildBackup(data) });
    else if (m === 'csv') setTool({ mode: m, text: toCSV(data) });
    else setTool({ mode: m, text: '' });
  }
  // Erase everything and start over, with two explicit confirmations. The
  // wipe keeps the app usable (default quick adds, fresh welcome flow) and
  // clears the remembered net worth peak so no ghost of the old data stays.
  function resetAll() {
    const wipe = () => {
      // snapshot: false, so the erase clears the hidden safety copy too.
      // Cannot be undone must be literally true.
      replaceAll(
        {
          settings: {
            quickAdds: [
              { label: 'Food', amount: 150 },
              { label: 'Transport', amount: 50 },
              { label: 'Coffee', amount: 120 },
              { label: 'Load', amount: 100 },
            ],
          },
        },
        { snapshot: false }
      );
      AsyncStorage.removeItem('salapify_peak_networth').catch(() => {});
    };
    const first = 'This erases every account, debt, transaction, goal, utang, note, and recurring item on this phone. A backup file is the only way back.';
    const second = 'Last check. This cannot be undone.';
    if (Platform.OS === 'web') {
      if (window.confirm(`Start fresh? ${first}`) && window.confirm(second)) wipe();
      return;
    }
    Alert.alert('Start fresh?', first, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Continue',
        style: 'destructive',
        onPress: () =>
          Alert.alert('Really erase everything?', second, [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Erase everything', style: 'destructive', onPress: wipe },
          ]),
      },
    ]);
  }

  function runImport() {
    try {
      const parsed = tool.mode === 'importv1' ? parseV1(tool.text) : parseBackup(tool.text);
      // The native path confirms via Alert; the web path must too, one
      // stray tap should never replace everything without asking.
      if (Platform.OS === 'web' && !window.confirm('Replace everything currently in the app with this file? This cannot be undone.')) {
        return;
      }
      replaceAll(parsed);
      setMsg('Imported. Your data has been replaced.');
    } catch (e) {
      setMsg(e.message || 'Could not read that text.');
    }
  }
  const isReadOnly = tool && (tool.mode === 'backup' || tool.mode === 'csv');
  const titleByMode = { backup: 'Back up', restore: 'Restore from a file', csv: 'Export to CSV', importv1: 'Import v1 backup' };

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
        {/* A compact 2-column icon grid instead of ten tall rows, so the tab
            scans fast. Even count means five clean rows, no orphan tile. */}
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
        </View>

        <Text style={styles.sectionTitle}>DATA</Text>
        <View style={styles.card}>
          {DATA_ACTIONS.map((a, i) => (
            <Pressable key={a.mode} onPress={() => openTool(a.mode)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
              <Text style={styles.rowLabel}>{a.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </Pressable>
          ))}
          <Pressable onPress={resetAll} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={[styles.rowLabel, { color: colors.warning }]}>Start fresh (erase everything)</Text>
            <Ionicons name="trash-outline" size={18} color={colors.warning} />
          </Pressable>
          {(() => {
            // An offline first finance app has exactly one disaster plan:
            // the backup file. Say when the last one happened, plainly.
            const last = settings.lastBackupAt;
            const days = last
              ? Math.max(0, Math.floor((new Date() - new Date(`${last}T00:00:00`)) / 86400000))
              : null;
            const stale = days === null || days > 30;
            return (
              <Text style={[styles.sizeNote, stale && { color: colors.warning }]}>
                {days === null
                  ? 'No backup file yet. Right now this phone holds the only copy of your data.'
                  : `Last backup: ${days === 0 ? 'today' : `${days} day${days === 1 ? '' : 's'} ago`}.${days > 30 ? ' Time for a fresh one.' : ''}`}
              </Text>
            );
          })()}
          {storageSize > SIZE_WARN ? (
            <Text style={[styles.sizeNote, { color: colors.warning }]}>
              Your data is {Math.round(storageSize / 1024)} KB, close to the phone storage limit.
              Back up to a file now.
            </Text>
          ) : storageSize > SIZE_NUDGE ? (
            <Text style={styles.sizeNote}>
              Your history is growing ({Math.round(storageSize / 1024)} KB). Back up to a file
              regularly.
            </Text>
          ) : null}
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
            <Text style={styles.rowValue}>1.3.1</Text>
          </View>
          {/* This stamp changes with every over the air update, so you can
              always tell at a glance whether the latest code has arrived. */}
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Update stamp</Text>
            <Text style={styles.rowValue}>v3.69: Notifications and Preferences moved to their own screens, More is now a short list</Text>
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

      {/* Data tool modal. */}
      <Modal visible={!!tool} transparent animationType="slide" onRequestClose={() => setTool(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet} accessibilityViewIsModal={true}>
            <Text style={styles.sheetTitle}>{tool ? titleByMode[tool.mode] : ''}</Text>
            <Text style={styles.sheetHint}>
              {isReadOnly
                ? Platform.OS === 'web'
                  ? 'Copy this text, or use Download to save a file.'
                  : 'Copy this text and keep it safe. That is your backup.'
                : tool?.mode === 'importv1'
                ? 'Paste your Peso Smart (v1) backup here, then Import. This replaces current data.'
                : 'Paste a Salapify backup here, then Restore. This replaces current data.'}
            </Text>
            <TextInput
              style={styles.textArea}
              value={tool?.text}
              editable={!isReadOnly}
              onChangeText={(t) => setTool((s) => ({ ...s, text: t }))}
              multiline
              placeholder={isReadOnly ? '' : 'Paste here'}
              placeholderTextColor={colors.faint}
            />
            {msg ? <Text style={styles.msg}>{msg}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setTool(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Close</Text>
              </Pressable>
              {isReadOnly && Platform.OS === 'web' ? (
                <Pressable onPress={() => downloadFile(tool.mode === 'csv' ? 'salapify.csv' : 'salapify-backup.json', tool.text)} style={[styles.sheetBtn, styles.saveBtn]}>
                  <Text style={styles.saveText}>Download</Text>
                </Pressable>
              ) : null}
              {!isReadOnly ? (
                <Pressable onPress={runImport} style={[styles.sheetBtn, styles.saveBtn]}>
                  <Text style={styles.saveText}>{tool?.mode === 'importv1' ? 'Import' : 'Restore'}</Text>
                </Pressable>
              ) : null}
            </View>
          </View>
        </View>
      </Modal>
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
    rowRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    rowHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },
    sizeNote: { color: colors.muted, fontSize: fontSize.small, paddingVertical: spacing.md },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    sheetHint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs, marginBottom: spacing.md },
    textArea: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.md, color: colors.text, fontSize: fontSize.small, minHeight: 140, maxHeight: 280, textAlignVertical: 'top' },
    msg: { color: colors.primary, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.lg },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
