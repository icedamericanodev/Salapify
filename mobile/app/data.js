// Backup and data screen (reached from More > Backup and data). It holds the
// backup, restore, CSV export, v1 import, and "Start fresh" tools that used to
// sit inline in the More tab. These are the destructive, data-loss-capable
// actions, so nothing about how they work changed, this only moves the UI here.
// Every confirmation dialog is byte-for-byte the same as before. Reads live
// theme colors through useTheme(), so all 8 palettes and both light and dark
// render correctly.

import { useMemo, useState } from 'react';
import { Alert, Modal, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { buildBackup, parseBackup, toCSV, parseV1 } from '../lib/backup';
import { SIZE_NUDGE, SIZE_WARN } from '../lib/storage';
import { saveTextFile, saveToDevice, pickTextFile, pickBackupFolder } from '../lib/files';
import { todayISO } from '../lib/format';
import SectionHeader from '../components/SectionHeader';

const DATA_ACTIONS = [
  { mode: 'backup', label: 'Back up to a file' },
  { mode: 'restore', label: 'Restore from a file' },
  { mode: 'csv', label: 'Export to CSV' },
  { mode: 'importv1', label: 'Import v1 backup' },
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

export default function Data() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, replaceAll, updateSettings, storageSize } = useAppData();

  const [tool, setTool] = useState(null); // data tools modal
  const [msg, setMsg] = useState('');

  const settings = data.settings;

  // ---- Automatic backups (Pro, Android only) ----
  // Only the AUTOMATIC backup is Pro. The manual tools above (backup, restore,
  // CSV, v1 import) stay free forever: data portability is never locked.
  const isAndroid = Platform.OS === 'android';
  const isPro = !!settings.pro;
  const KEEP_OPTIONS = [3, 7, 14];

  async function chooseBackupFolder({ enableOnPick = false } = {}) {
    try {
      const uri = await pickBackupFolder();
      if (uri) {
        // A fresh folder clears the broken flag; the next resume or cold start
        // writes here. If we were turning the feature on, enable it now that a
        // folder exists.
        updateSettings({ autoBackupUri: uri, autoBackupBroken: false, ...(enableOnPick ? { autoBackup: true } : {}) });
        Alert.alert(
          'Folder connected',
          'Automatic backups will be saved here. Pick a Google Drive or Dropbox synced folder and the copies land in the cloud, no account linking needed.'
        );
      } else if (enableOnPick) {
        // Picker cancelled while turning it on: leave the switch off, so it
        // never reads on with no folder actually connected.
        updateSettings({ autoBackup: false });
      }
    } catch (e) {
      if (enableOnPick) updateSettings({ autoBackup: false });
      Alert.alert('Could not open the folder picker', e.message || 'Try again.');
    }
  }

  function toggleAutoBackup(on) {
    if (!isPro) return; // gated: a non-Pro user sees the upsell row instead
    if (on && !settings.autoBackupUri) {
      // Turning it on with no folder yet: ask for the folder first, and only
      // flip the switch on if one is actually picked.
      chooseBackupFolder({ enableOnPick: true });
      return;
    }
    updateSettings({ autoBackup: on });
  }

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
            'Receipt photos stay on this phone. The backup covers your money data, not the photos. Tip: on Save to my device you can pick a Google Drive or Dropbox folder, that keeps a copy in the cloud with no account linking.',
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
        <Text style={styles.headerTitle} accessibilityRole="header">Backup and data</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <SectionHeader title="ON THIS DEVICE" />
        <View style={styles.card}>
          {/* The disaster-plan message leads: an offline first finance app has
              exactly one way back, the backup file, so it anchors the top of
              the actions instead of trailing under them. */}
          {(() => {
            const last = settings.lastBackupAt;
            const days = last
              ? Math.max(0, Math.floor((new Date() - new Date(`${last}T00:00:00`)) / 86400000))
              : null;
            const stale = days === null || days > 30;
            return (
              <Text style={[styles.leadNote, stale && { color: colors.warning }]}>
                {days === null
                  ? 'No backup file yet. Right now this phone holds the only copy of your data.'
                  : `Last backup: ${days === 0 ? 'today' : `${days} day${days === 1 ? '' : 's'} ago`}.${days > 30 ? ' Time for a fresh one.' : ''}`}
              </Text>
            );
          })()}
          {storageSize > SIZE_WARN ? (
            <Text style={[styles.leadNote, { color: colors.warning }]}>
              Your data is {Math.round(storageSize / 1024)} KB, close to the phone storage limit.
              Back up to a file now.
            </Text>
          ) : storageSize > SIZE_NUDGE ? (
            <Text style={styles.leadNote}>
              Your history is growing ({Math.round(storageSize / 1024)} KB). Back up to a file
              regularly.
            </Text>
          ) : null}
          {DATA_ACTIONS.map((a) => (
            <Pressable key={a.mode} onPress={() => openTool(a.mode)} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
              <Text style={styles.rowLabel}>{a.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </Pressable>
          ))}
        </View>

        {/* Automatic backups: the only Pro part of this screen. On foreground
            resume the app writes a dated backup into the folder you pick, at
            most once a day, and keeps the newest few. Hidden work on iOS and
            web (no SAF), so the section shows an "Available on Android" note. */}
        <SectionHeader title="AUTOMATIC BACKUPS" style={styles.autoHeader} />
        <View style={styles.card}>
          {!isAndroid ? (
            <View style={styles.row}>
              <Text style={styles.rowLabel}>Available on Android</Text>
            </View>
          ) : (
            <>
              {settings.autoBackupBroken ? (
                <View style={styles.banner} accessibilityRole="alert">
                  <Text style={styles.bannerText}>
                    Your backup folder needs reconnecting. The last automatic backup could not be
                    saved, so no copies are being made right now.
                  </Text>
                  <Pressable
                    onPress={() => chooseBackupFolder()}
                    style={({ pressed }) => [styles.bannerBtn, pressed && styles.pressed]}
                    accessibilityRole="button"
                    accessibilityLabel="Reconnect backup folder"
                  >
                    <Text style={styles.bannerBtnText}>Reconnect folder</Text>
                  </Pressable>
                </View>
              ) : null}

              {!isPro ? (
                <Pressable
                  onPress={() => router.push('/insights')}
                  style={({ pressed }) => [styles.row, pressed && styles.pressed]}
                  accessibilityRole="button"
                  accessibilityLabel="Unlock Pro to turn on automatic backups"
                >
                  <View style={{ flex: 1, paddingRight: spacing.md }}>
                    <Text style={styles.rowLabel}>
                      Back up automatically <Text style={styles.proBadge}>PRO</Text>
                    </Text>
                    <Text style={styles.rowHint}>
                      Unlock Pro on the Insights tab to save a dated backup to your folder every day,
                      hands free. Manual backup and restore stay free.
                    </Text>
                  </View>
                  <Ionicons name="chevron-forward" size={18} color={colors.faint} />
                </Pressable>
              ) : (
                <View style={styles.row}>
                  <View style={{ flex: 1, paddingRight: spacing.md }}>
                    <Text style={styles.rowLabel}>Back up automatically</Text>
                    <Text style={styles.rowHint}>
                      When you open the app, a dated backup is saved to your folder, at most once a
                      day.
                    </Text>
                  </View>
                  <Switch
                    value={!!settings.autoBackup}
                    onValueChange={toggleAutoBackup}
                    trackColor={{ false: colors.border, true: colors.primary }}
                    thumbColor={colors.onPrimary}
                    accessibilityLabel="Back up automatically"
                  />
                </View>
              )}

              {isPro ? (
                <>
                  <Pressable
                    onPress={() => chooseBackupFolder()}
                    style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
                    accessibilityRole="button"
                    accessibilityLabel="Choose backup folder"
                  >
                    <View style={{ flex: 1, paddingRight: spacing.md }}>
                      <Text style={styles.rowLabel}>Choose backup folder</Text>
                      <Text style={styles.rowHint}>
                        {settings.autoBackupUri
                          ? 'Folder connected. Tip: a Google Drive or Dropbox folder keeps copies in the cloud.'
                          : 'Not set yet. Pick a Google Drive or Dropbox folder for cloud copies.'}
                      </Text>
                    </View>
                    <Ionicons name="chevron-forward" size={18} color={colors.faint} />
                  </Pressable>

                  <View style={[styles.keepBlock, styles.rowDivider]}>
                    <Text style={styles.rowLabel}>Number of backups to keep</Text>
                    <Text style={styles.keepHint}>Older backups are deleted automatically, so they never pile up in your folder.</Text>
                    <View style={[styles.keepRow, { marginTop: spacing.sm }]}>
                      {KEEP_OPTIONS.map((n) => {
                        const active = (Number(settings.autoBackupKeep) || 7) === n;
                        return (
                          <Pressable
                            key={n}
                            onPress={() => updateSettings({ autoBackupKeep: n })}
                            style={({ pressed }) => [
                              styles.keepPill,
                              active && styles.keepPillActive,
                              pressed && styles.pressed,
                            ]}
                            accessibilityRole="button"
                            accessibilityState={{ selected: active }}
                            accessibilityLabel={`Keep last ${n} backups`}
                          >
                            <Text style={[styles.keepText, active && styles.keepTextActive]}>{n}</Text>
                          </Pressable>
                        );
                      })}
                    </View>
                  </View>

                  <View style={[styles.row, styles.rowDivider]}>
                    <Text style={styles.rowLabel}>Last automatic backup</Text>
                    <Text style={styles.rowValue}>{settings.lastAutoBackupAt || 'not yet'}</Text>
                  </View>
                </>
              ) : null}
            </>
          )}
        </View>

        {/* Erase lives in its own separated card, not a hairline under the
            everyday actions, so an accidental tap is far less likely. It keeps
            the stronger warning hue (reserved here for the one irreversible
            control) plus the two-step confirm. */}
        <SectionHeader title="DANGER ZONE" style={styles.dangerHeader} />
        <View style={styles.card}>
          <Pressable onPress={resetAll} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={[styles.rowLabel, styles.dangerLabel]}>Start fresh (erase everything)</Text>
            <Ionicons name="trash-outline" size={18} color={colors.warningStrong} />
          </Pressable>
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
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium, flexShrink: 1, paddingRight: spacing.md },
    // The leading backup-status note, sitting above the actions.
    leadNote: { color: colors.muted, fontSize: fontSize.small, paddingTop: spacing.md, paddingBottom: spacing.sm },
    dangerHeader: { marginTop: spacing.xl },
    dangerLabel: { color: colors.warningStrong },

    // Automatic backups section.
    autoHeader: { marginTop: spacing.xl },
    rowHint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xxs },
    rowValue: { color: colors.muted, fontSize: fontSize.small },
    proBadge: { color: colors.celebrate, fontSize: fontSize.caption, fontWeight: fontWeight.heavy },
    banner: {
      backgroundColor: colors.positiveSurface,
      borderColor: colors.warning,
      borderWidth: 1,
      borderRadius: radius.md,
      padding: spacing.md,
      marginTop: spacing.md,
      marginBottom: spacing.xs,
    },
    bannerText: { color: colors.text, fontSize: fontSize.small },
    bannerBtn: {
      alignSelf: 'flex-start',
      marginTop: spacing.sm,
      paddingVertical: spacing.sm,
      paddingHorizontal: spacing.lg,
      borderRadius: radius.pill,
      backgroundColor: colors.primary,
    },
    bannerBtnText: { color: colors.onPrimary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    keepBlock: { paddingVertical: spacing.md },
    keepHint: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2, lineHeight: 16 },
    keepRow: { flexDirection: 'row', gap: spacing.xs },
    keepPill: {
      minWidth: 44,
      minHeight: 36,
      alignItems: 'center',
      justifyContent: 'center',
      paddingHorizontal: spacing.md,
      borderRadius: radius.pill,
      borderColor: colors.border,
      borderWidth: 1,
    },
    keepPillActive: { backgroundColor: colors.primary, borderColor: colors.primary },
    keepText: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    keepTextActive: { color: colors.onPrimary, fontWeight: fontWeight.bold },

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
