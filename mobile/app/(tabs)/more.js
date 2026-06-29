// Settings screen (reached from the More tab). Working now: Appearance,
// the Data tools (backup/restore/CSV/v1 import), and Preferences (currency,
// monthly budget, and quick add buttons). Categories and Logging are still
// marked "Soon". Everything is web-preview compatible (no native libraries).

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
import { useRouter } from 'expo-router';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney } from '../../lib/format';
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

// A short list of common currencies. "relabel" only changes the symbol shown.
const CURRENCIES = [
  { code: 'PHP', symbol: '₱' },
  { code: 'USD', symbol: '$' },
  { code: 'EUR', symbol: '€' },
  { code: 'GBP', symbol: '£' },
  { code: 'JPY', symbol: '¥' },
  { code: 'CNY', symbol: '¥' },
  { code: 'KRW', symbol: '₩' },
  { code: 'INR', symbol: '₹' },
  { code: 'IDR', symbol: 'Rp' },
  { code: 'MYR', symbol: 'RM' },
  { code: 'SGD', symbol: 'S$' },
  { code: 'THB', symbol: '฿' },
  { code: 'VND', symbol: '₫' },
  { code: 'HKD', symbol: 'HK$' },
  { code: 'AUD', symbol: 'A$' },
  { code: 'CAD', symbol: 'C$' },
  { code: 'AED', symbol: 'AED' },
  { code: 'SAR', symbol: 'SAR' },
  { code: 'CHF', symbol: 'CHF' },
  { code: 'NZD', symbol: 'NZ$' },
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
  const { colors, mode, setMode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, replaceAll, updateSettings } = useAppData();
  const router = useRouter();

  const [tool, setTool] = useState(null); // data tools modal
  const [msg, setMsg] = useState('');
  const [pref, setPref] = useState(null); // preferences modal: {mode, text}
  const [qaLabel, setQaLabel] = useState('');
  const [qaAmount, setQaAmount] = useState('');

  const settings = data.settings;

  // ---- Data tools ----
  function openTool(m) {
    setMsg('');
    if (m === 'backup') setTool({ mode: m, text: buildBackup(data) });
    else if (m === 'csv') setTool({ mode: m, text: toCSV(data) });
    else setTool({ mode: m, text: '' });
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
  const titleByMode = { backup: 'Back up', restore: 'Restore from a file', csv: 'Export to CSV', importv1: 'Import v1 backup' };

  // ---- Preferences ----
  function openPref(m) {
    if (m === 'limit') setPref({ mode: m, text: String(settings.monthlyLimit || 0) });
    else setPref({ mode: m });
    setQaLabel('');
    setQaAmount('');
  }
  function pickCurrency(c) {
    updateSettings({ currency: c.symbol, currencyCode: c.code });
    setPref(null);
  }
  function saveLimit() {
    const n = Number(pref.text);
    if (!Number.isFinite(n) || n < 0) return;
    updateSettings({ monthlyLimit: n });
    setPref(null);
  }
  function addQuickAdd() {
    const amount = Number(qaAmount);
    if (!qaLabel.trim() || !Number.isFinite(amount) || amount <= 0) return;
    updateSettings({ quickAdds: [...(settings.quickAdds || []), { label: qaLabel.trim(), amount }] });
    setQaLabel('');
    setQaAmount('');
  }
  function removeQuickAdd(i) {
    updateSettings({ quickAdds: (settings.quickAdds || []).filter((_, idx) => idx !== i) });
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Settings</Text>

        <Text style={styles.sectionTitle}>MY MONEY</Text>
        <View style={styles.card}>
          <Pressable onPress={() => router.push('/goals')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Goals</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/mindset')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Money mindset</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>APPEARANCE</Text>
        <View style={styles.card}>
          {APPEARANCE.map((opt, i) => {
            const selected = mode === opt.key;
            return (
              <Pressable key={opt.key} onPress={() => setMode(opt.key)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
                <Text style={styles.rowLabel}>{opt.label}</Text>
                {selected ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.sectionTitle}>PREFERENCES</Text>
        <View style={styles.card}>
          <Pressable onPress={() => openPref('currency')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Currency</Text>
            <Text style={styles.rowValue}>{(settings.currencyCode || '') + ' ' + settings.currency}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('limit')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Monthly budget</Text>
            <Text style={styles.rowValue}>{formatMoney(settings.monthlyLimit)}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('quickadds')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Quick add buttons</Text>
            <Text style={styles.rowValue}>{(settings.quickAdds || []).length}</Text>
          </Pressable>
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Categories and income</Text>
            <Text style={styles.soon}>Soon</Text>
          </View>
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Logging preference</Text>
            <Text style={styles.soon}>Soon</Text>
          </View>
        </View>

        <Text style={styles.sectionTitle}>DATA</Text>
        <View style={styles.card}>
          {DATA_ACTIONS.map((a, i) => (
            <Pressable key={a.mode} onPress={() => openTool(a.mode)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
              <Text style={styles.rowLabel}>{a.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </Pressable>
          ))}
        </View>

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

      {/* Preferences modal. */}
      <Modal visible={!!pref} transparent animationType="slide" onRequestClose={() => setPref(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            {pref?.mode === 'currency' ? (
              <>
                <Text style={styles.sheetTitle}>Currency</Text>
                <ScrollView style={{ maxHeight: 360 }}>
                  {CURRENCIES.map((c, i) => {
                    const on = settings.currency === c.symbol && settings.currencyCode === c.code;
                    return (
                      <Pressable key={c.code} onPress={() => pickCurrency(c)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
                        <Text style={styles.rowLabel}>{c.code} {c.symbol}</Text>
                        {on ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
                      </Pressable>
                    );
                  })}
                </ScrollView>
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Close</Text>
                  </Pressable>
                </View>
              </>
            ) : null}

            {pref?.mode === 'limit' ? (
              <>
                <Text style={styles.sheetTitle}>Monthly budget</Text>
                <Text style={styles.fieldLabel}>Spending limit per month</Text>
                <TextInput
                  style={styles.input}
                  value={pref.text}
                  onChangeText={(t) => setPref((p) => ({ ...p, text: t }))}
                  placeholder="0"
                  placeholderTextColor={colors.faint}
                  keyboardType="numeric"
                />
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={saveLimit} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Save</Text>
                  </Pressable>
                </View>
              </>
            ) : null}

            {pref?.mode === 'quickadds' ? (
              <>
                <Text style={styles.sheetTitle}>Quick add buttons</Text>
                <ScrollView style={{ maxHeight: 240 }}>
                  {(settings.quickAdds || []).map((q, i) => (
                    <View key={i} style={[styles.row, i > 0 && styles.rowDivider]}>
                      <Text style={styles.rowLabel}>{q.label}</Text>
                      <View style={styles.qaRight}>
                        <Text style={styles.rowValue}>{formatMoney(q.amount)}</Text>
                        <Pressable onPress={() => removeQuickAdd(i)} hitSlop={8}>
                          <Ionicons name="close" size={16} color={colors.faint} />
                        </Pressable>
                      </View>
                    </View>
                  ))}
                </ScrollView>
                <Text style={styles.fieldLabel}>Add a button</Text>
                <View style={styles.qaAddRow}>
                  <TextInput style={[styles.input, { flex: 1 }]} value={qaLabel} onChangeText={setQaLabel} placeholder="Label" placeholderTextColor={colors.faint} />
                  <TextInput style={[styles.input, { width: 90 }]} value={qaAmount} onChangeText={setQaAmount} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
                  <Pressable onPress={addQuickAdd} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Add</Text>
                  </Pressable>
                </View>
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Done</Text>
                  </Pressable>
                </View>
              </>
            ) : null}
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
    soon: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, borderColor: colors.border, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: spacing.sm, paddingVertical: 2, overflow: 'hidden' },
    qaRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    qaAddRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center', marginBottom: spacing.md },

    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    sheetHint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs, marginBottom: spacing.md },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    textArea: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.md, color: colors.text, fontSize: fontSize.small, minHeight: 140, maxHeight: 280, textAlignVertical: 'top' },
    msg: { color: colors.primary, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.lg },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
