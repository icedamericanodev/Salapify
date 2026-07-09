// Preferences screen (reached from More > Preferences). It holds the currency,
// monthly budget, payday schedule, and quick add buttons that used to sit inline
// in the More tab and made it a very long scroll, plus the links to Categories
// and Earn your treats. Nothing about how the settings are stored or applied
// changed, this only moves the UI here. Reads live theme colors through
// useTheme(), so all 8 palettes and both light and dark render correctly.

import { useMemo, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, normalizeSchedule, scheduleLabel } from '../lib/format';

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

export default function Preferences() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateSettings } = useAppData();

  const [pref, setPref] = useState(null); // preferences modal: {mode, text}
  const [qaLabel, setQaLabel] = useState('');
  const [qaAmount, setQaAmount] = useState('');

  const settings = data.settings;

  // ---- Preferences ----
  function openPref(m) {
    if (m === 'limit') setPref({ mode: m, text: String(settings.monthlyLimit || 0) });
    else if (m === 'payday') {
      const sch = normalizeSchedule(settings.paydaySchedule);
      setPref({
        mode: m,
        payMode: sch.mode,
        d1: String(sch.mode === 'semimonthly' ? sch.days[0] : 15),
        d2: String(sch.mode === 'semimonthly' ? sch.days[1] : 31),
        day: String(sch.mode === 'monthly' ? sch.day : 30),
        weekday: sch.mode === 'weekly' ? sch.weekday : 5,
        err: '',
      });
    }
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
  function savePayday() {
    const dayOk = (t) => {
      const n = Math.trunc(Number(String(t).trim()));
      return Number.isFinite(n) && n >= 1 && n <= 31 ? n : null;
    };
    let schedule;
    if (pref.payMode === 'monthly') {
      const d = dayOk(pref.day);
      if (d === null) {
        setPref((p) => ({ ...p, err: 'Pick a day from 1 to 31. 31 means the last day of the month.' }));
        return;
      }
      schedule = { mode: 'monthly', day: d };
    } else if (pref.payMode === 'weekly') {
      schedule = { mode: 'weekly', weekday: pref.weekday };
    } else {
      const a = dayOk(pref.d1);
      const b = dayOk(pref.d2);
      if (a === null || b === null) {
        setPref((p) => ({ ...p, err: 'Both days should be from 1 to 31. 31 means the last day of the month.' }));
        return;
      }
      schedule = { mode: 'semimonthly', days: [a, b] };
    }
    updateSettings({ paydaySchedule: normalizeSchedule(schedule) });
    setPref(null);
  }
  function addQuickAdd() {
    const amount = Number(qaAmount);
    const label = qaLabel.trim();
    if (!label || !Number.isFinite(amount) || amount <= 0) return;
    // No duplicate labels: the Budget screen uses the label as its key.
    const exists = (settings.quickAdds || []).some(
      (q) => q.label.toLowerCase() === label.toLowerCase()
    );
    if (exists) return;
    updateSettings({ quickAdds: [...(settings.quickAdds || []), { label, amount }] });
    setQaLabel('');
    setQaAmount('');
  }
  function removeQuickAdd(i) {
    updateSettings({ quickAdds: (settings.quickAdds || []).filter((_, idx) => idx !== i) });
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
        <Text style={styles.headerTitle} accessibilityRole="header">Preferences</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.card}>
          <Pressable onPress={() => openPref('currency')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Currency</Text>
            <Text style={styles.rowValue} numberOfLines={1}>{(settings.currencyCode || '') + ' ' + settings.currency}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('limit')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Monthly budget</Text>
            <Text style={styles.rowValue} numberOfLines={1}>{formatMoney(settings.monthlyLimit)}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('payday')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Payday schedule</Text>
            <Text style={styles.rowValue} numberOfLines={1}>{scheduleLabel(settings.paydaySchedule)}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('quickadds')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Quick add buttons</Text>
            <Text style={styles.rowValue}>{(settings.quickAdds || []).length}</Text>
          </Pressable>
          <Pressable onPress={() => router.push('/categories')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Categories and caps</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/treats')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Earn your treats</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
        </View>
      </ScrollView>

      {/* Preferences modal. */}
      <Modal visible={!!pref} transparent animationType="slide" onRequestClose={() => setPref(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet} accessibilityViewIsModal={true}>
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

            {pref?.mode === 'payday' ? (
              <>
                <Text style={styles.sheetTitle}>Payday schedule</Text>
                <Text style={styles.fieldLabel}>How often does your sweldo arrive?</Text>
                <View style={styles.chips}>
                  {[
                    { k: 'semimonthly', label: 'Twice a month' },
                    { k: 'monthly', label: 'Once a month' },
                    { k: 'weekly', label: 'Weekly' },
                  ].map((opt) => {
                    const on = pref.payMode === opt.k;
                    return (
                      <Pressable key={opt.k} onPress={() => setPref((p) => ({ ...p, payMode: opt.k, err: '' }))} style={[styles.chip, on && styles.chipOn]}>
                        <Text style={[styles.chipText, on && styles.chipTextOn]}>{opt.label}</Text>
                      </Pressable>
                    );
                  })}
                </View>
                {pref.payMode === 'semimonthly' ? (
                  <>
                    <Text style={styles.fieldLabel}>First payday (day of the month)</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.d1}
                      onChangeText={(t) => setPref((p) => ({ ...p, d1: t, err: '' }))}
                      placeholder="15"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.fieldLabel}>Second payday</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.d2}
                      onChangeText={(t) => setPref((p) => ({ ...p, d2: t, err: '' }))}
                      placeholder="31"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.sizeNote}>Type 31 for the last day of the month, it adjusts to short months by itself.</Text>
                  </>
                ) : null}
                {pref.payMode === 'monthly' ? (
                  <>
                    <Text style={styles.fieldLabel}>Payday (day of the month)</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.day}
                      onChangeText={(t) => setPref((p) => ({ ...p, day: t, err: '' }))}
                      placeholder="30"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.sizeNote}>Type 31 for the last day of the month, it adjusts to short months by itself.</Text>
                  </>
                ) : null}
                {pref.payMode === 'weekly' ? (
                  <>
                    <Text style={styles.fieldLabel}>Which day?</Text>
                    <View style={styles.chips}>
                      {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((name, i) => {
                        const on = pref.weekday === i;
                        return (
                          <Pressable key={name} onPress={() => setPref((p) => ({ ...p, weekday: i, err: '' }))} style={[styles.chip, on && styles.chipOn]}>
                            <Text style={[styles.chipText, on && styles.chipTextOn]}>{name}</Text>
                          </Pressable>
                        );
                      })}
                    </View>
                  </>
                ) : null}
                {pref.err ? (
                  <Text
                    style={styles.prefErr}
                    accessibilityRole="alert"
                    accessibilityLiveRegion="assertive"
                  >
                    Error: {pref.err}
                  </Text>
                ) : null}
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={savePayday} style={[styles.sheetBtn, styles.saveBtn]}>
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
                        <Pressable
                          onPress={() => removeQuickAdd(i)}
                          hitSlop={14}
                          accessibilityRole="button"
                          accessibilityLabel="Remove quick add button"
                        >
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
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    // flexShrink lets a long value (a big budget, a wordy payday label) shrink
    // and stay on one line instead of shoving the label or wrapping awkwardly.
    rowValue: { color: colors.muted, fontSize: fontSize.body, flexShrink: 1, textAlign: 'right', marginLeft: spacing.md },
    sizeNote: { color: colors.muted, fontSize: fontSize.small, paddingVertical: spacing.md },
    qaRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    qaAddRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center', marginBottom: spacing.md },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.lg },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.xs },
    chip: { paddingVertical: spacing.sm, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.textSecondary, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },
    prefErr: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
