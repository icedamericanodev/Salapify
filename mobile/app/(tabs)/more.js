// Settings screen (reached from the More tab). Appearance (Light/Dark/System)
// and the Data tools (back up, restore, export CSV, import v1) work now. The
// Data tools are text based so they work on web and phone with no native file
// libraries; on web there is also a Download button.

import { useMemo, useState } from 'react';
import {
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { buildBackup, parseBackup, toCSV, parseV1 } from '../../lib/backup';

const APPEARANCE = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

const DATA_ACTIONS = [
  { mode: 'backup', label: 'Back up to a file' },
  { mode: 'restore', label: 'Restore from a file' },
  { mode: 'csv', label: 'Export to CSV' },
  { mode: 'importv1', label: 'Import v1 backup' },
];

const PREFERENCES = [
  { label: 'Currency', value: 'PHP ₱' },
  { label: 'Categories and income' },
  { label: 'Quick add buttons' },
  { label: 'Logging preference' },
];

// Web-only file download. On the phone this does nothing (you copy the text).
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
  const { colors, mode, setMode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, replaceAll } = useAppData();

  // The data tool modal: { mode, text } or null.
  const [tool, setTool] = useState(null);
  const [msg, setMsg] = useState('');

  function openTool(m) {
    setMsg('');
    if (m === 'backup') setTool({ mode: m, text: buildBackup(data) });
    else if (m === 'csv') setTool({ mode: m, text: toCSV(data) });
    else setTool({ mode: m, text: '' }); // restore / importv1: paste in
  }
  function runImport() {
    try {
      const parsed = tool.mode === 'importv1' ? parseV1(tool.text) : parseBackup(tool.text);
      replaceAll(parsed);
      setMsg('Imported. Your data has been replaced.');
    } catch (e) {
      setMsg(e.message || 'Could not read that text.');
    }
  }

  const isReadOnly = tool && (tool.mode === 'backup' || tool.mode === 'csv');
  const titleByMode = {
    backup: 'Back up',
    restore: 'Restore from a file',
    csv: 'Export to CSV',
    importv1: 'Import v1 backup',
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Settings</Text>

        {/* Appearance. */}
        <Text style={styles.sectionTitle}>APPEARANCE</Text>
        <View style={styles.card}>
          {APPEARANCE.map((opt, i) => {
            const selected = mode === opt.key;
            return (
              <Pressable
                key={opt.key}
                onPress={() => setMode(opt.key)}
                style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}
              >
                <Text style={styles.rowLabel}>{opt.label}</Text>
                {selected ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>
        <Text style={styles.hint}>System follows your phone's light or dark setting.</Text>

        {/* Data tools (working). */}
        <Text style={styles.sectionTitle}>DATA</Text>
        <View style={styles.card}>
          {DATA_ACTIONS.map((a, i) => (
            <Pressable
              key={a.mode}
              onPress={() => openTool(a.mode)}
              style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}
            >
              <Text style={styles.rowLabel}>{a.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </Pressable>
          ))}
        </View>

        {/* Preferences (not wired yet). */}
        <Text style={styles.sectionTitle}>PREFERENCES</Text>
        <View style={styles.card}>
          {PREFERENCES.map((row, i) => (
            <View key={row.label} style={[styles.row, i > 0 && styles.rowDivider]}>
              <Text style={styles.rowLabel}>{row.label}</Text>
              {row.value ? <Text style={styles.rowValue}>{row.value}</Text> : <Text style={styles.soon}>Soon</Text>}
            </View>
          ))}
        </View>

        {/* About. */}
        <Text style={styles.sectionTitle}>ABOUT</Text>
        <View style={styles.card}>
          <View style={styles.row}>
            <Text style={styles.rowLabel}>Version</Text>
            <Text style={styles.rowValue}>0.1.0</Text>
          </View>
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Salapify</Text>
            <Text style={styles.rowValue}>v2</Text>
          </View>
        </View>
      </ScrollView>

      {/* Data tool modal. */}
      <Modal visible={!!tool} transparent animationType="slide" onRequestClose={() => setTool(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>{tool ? titleByMode[tool.mode] : ''}</Text>
            <Text style={styles.sheetHint}>
              {isReadOnly
                ? Platform.OS === 'web'
                  ? 'Copy this text, or use Download to save a file.'
                  : 'Copy this text and keep it safe. That is your backup.'
                : tool?.mode === 'importv1'
                ? 'Paste your Peso Smart (v1) backup text here, then Import. This replaces current data.'
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
                <Pressable
                  onPress={() => downloadFile(tool.mode === 'csv' ? 'salapify.csv' : 'salapify-backup.json', tool.text)}
                  style={[styles.sheetBtn, styles.saveBtn]}
                >
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
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginBottom: spacing.lg },
    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowValue: { color: colors.muted, fontSize: fontSize.body },
    soon: {
      color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium,
      borderColor: colors.border, borderWidth: 1, borderRadius: radius.pill,
      paddingHorizontal: spacing.sm, paddingVertical: 2, overflow: 'hidden',
    },
    hint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.sm, paddingHorizontal: spacing.xs },

    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    sheetHint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs, marginBottom: spacing.md },
    textArea: {
      backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md,
      padding: spacing.md, color: colors.text, fontSize: fontSize.small, minHeight: 140, maxHeight: 280,
      textAlignVertical: 'top',
    },
    msg: { color: colors.primary, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.lg },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
