// Budget and logging screen, wired to the store. The monthly limit and quick
// add buttons come from settings. Tapping a quick add, or adding a custom
// entry, saves a real transaction that persists. Recent shows live data and
// each row can be removed.

import { useMemo, useRef, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, todayISO, isThisMonth, monthLabel } from '../../lib/format';
import EmptyState from '../../components/EmptyState';
import WeekChain from '../../components/WeekChain';

const today = todayISO;

export default function Budget() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, addItem, removeItem } = useAppData();

  const [form, setForm] = useState(null); // custom entry modal
  const [err, setErr] = useState('');
  const [toast, setToast] = useState(null); // {text, id} after logging
  const toastTimer = useRef(null);

  const limit = data.settings.monthlyLimit || 0;
  const quickAdds = data.settings.quickAdds || [];

  // Only this month's expenses count toward the limit, so the budget bar
  // resets automatically when a new month starts.
  const expenses = data.transactions.filter((t) => t.type === 'expense' && isThisMonth(t.date));
  const spent = expenses.reduce((total, e) => total + e.amount, 0);
  const remaining = limit - spent;
  const pct = limit ? Math.min(Math.round((spent / limit) * 100), 100) : 0;
  const over = spent > limit;

  // Newest first.
  const recent = [...data.transactions].reverse();

  // A little celebration after every log: a light buzz and a toast with
  // Undo, so double taps and slips are one tap to fix. The habit being
  // rewarded is logging itself, never the amount.
  function celebrate(label, amount, id) {
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    } catch (e) {
      // Haptics are not available on web. That is fine.
    }
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast({ text: `Logged ${label} ${formatMoney(amount)}.`, id });
    toastTimer.current = setTimeout(() => setToast(null), 4000);
  }
  function undoLog() {
    if (toast) removeItem('transactions', toast.id);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast(null);
  }

  function quickAdd(item) {
    const id = addItem('transactions', { type: 'expense', label: item.label, amount: item.amount, date: today() });
    celebrate(item.label, item.amount, id);
  }
  function openCustom() {
    setForm({ type: 'expense', label: '', amount: '' });
    setErr('');
  }
  function saveCustom() {
    const amount = Number(form.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      setErr('Enter an amount greater than 0.');
      return;
    }
    const label = form.label.trim() || (form.type === 'income' ? 'Income' : 'Expense');
    const id = addItem('transactions', { type: form.type, label, amount, date: today() });
    setForm(null);
    celebrate(label, amount, id);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Budget</Text>

        <View style={styles.card}>
          <Text style={styles.kicker}>{monthLabel().toUpperCase()}</Text>
          <Text style={styles.spent}>
            {formatMoney(spent)} <Text style={styles.ofLimit}>of {formatMoney(limit)}</Text>
          </Text>
          <View style={styles.track}>
            <View
              style={[styles.fill, { width: `${pct}%`, backgroundColor: over ? colors.warning : colors.primary }]}
            />
          </View>
          <Text style={[styles.remaining, { color: over ? colors.warning : colors.muted }]}>
            {over ? `${formatMoney(-remaining)} over your limit` : `${formatMoney(remaining)} left to spend`}
          </Text>
        </View>

        <WeekChain transactions={data.transactions} />

        <Text style={styles.sectionTitle}>QUICK ADD</Text>
        <View style={styles.quickRow}>
          {quickAdds.map((item) => (
            <Pressable
              key={`${item.label}_${item.amount}`}
              onPress={() => quickAdd(item)}
              style={({ pressed }) => [styles.quick, pressed && styles.pressed]}
            >
              <Text style={styles.quickLabel}>{item.label}</Text>
              <Text style={styles.quickAmount}>{formatMoney(item.amount)}</Text>
            </Pressable>
          ))}
          <Pressable
            onPress={openCustom}
            style={({ pressed }) => [styles.quick, styles.custom, pressed && styles.pressed]}
          >
            <Text style={styles.customText}>+ Custom</Text>
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>RECENT</Text>
        <View style={styles.card}>
          {recent.length === 0 ? (
            <EmptyState icon="🧾" title="Nothing logged yet" subtitle="Tap a quick add or + Custom to start." />
          ) : (
            recent.slice(0, 12).map((e) => (
              <View key={e.id} style={styles.row}>
                <Text style={styles.rowName}>{e.label}</Text>
                <View style={styles.rowRight}>
                  <Text style={[styles.rowAmount, { color: e.type === 'income' ? colors.primary : colors.warning }]}>
                    {e.type === 'income' ? '+' : '-'} {formatMoney(e.amount)}
                  </Text>
                  <Pressable onPress={() => removeItem('transactions', e.id)} hitSlop={8} style={styles.trash}>
                    <Ionicons name="close" size={16} color={colors.faint} />
                  </Pressable>
                </View>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      {/* Logged toast with Undo. */}
      {toast ? (
        <View style={styles.toast}>
          <Text style={styles.toastText} numberOfLines={1}>
            {toast.text}
          </Text>
          <Pressable onPress={undoLog} hitSlop={12} style={styles.toastBtn}>
            <Text style={styles.toastUndo}>Undo</Text>
          </Pressable>
        </View>
      ) : null}

      {/* Custom entry modal. */}
      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Add entry</Text>

            <View style={styles.typeRow}>
              {['expense', 'income'].map((t) => {
                const on = form?.type === t;
                return (
                  <Pressable key={t} onPress={() => setForm((f) => ({ ...f, type: t }))} style={[styles.typeBtn, on && styles.typeOn]}>
                    <Text style={[styles.typeText, on && styles.typeTextOn]}>
                      {t === 'expense' ? 'Expense' : 'Income'}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>{form?.type === 'income' ? 'Source' : 'Category'}</Text>
            <TextInput
              style={styles.input}
              value={form?.label}
              onChangeText={(t) => setForm((f) => ({ ...f, label: t }))}
              placeholder={form?.type === 'income' ? 'e.g. Salary' : 'e.g. Groceries'}
              placeholderTextColor={colors.faint}
            />
            <Text style={styles.fieldLabel}>Amount</Text>
            <TextInput
              style={styles.input}
              value={form?.amount}
              onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))}
              placeholder="0"
              placeholderTextColor={colors.faint}
              keyboardType="numeric"
            />

            {err ? <Text style={styles.err}>{err}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setForm(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={saveCustom} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Add</Text>
              </Pressable>
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
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginBottom: spacing.md },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 2 },
    spent: { color: colors.text, fontSize: fontSize.big, fontWeight: fontWeight.bold, marginTop: spacing.xs, marginBottom: spacing.md },
    ofLimit: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.regular },
    track: { height: 10, borderRadius: radius.pill, backgroundColor: colors.border, overflow: 'hidden' },
    fill: { height: '100%', borderRadius: radius.pill },
    remaining: { fontSize: fontSize.small, marginTop: spacing.sm },

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    quickRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md, marginBottom: spacing.lg },
    quick: {
      flexGrow: 1, flexBasis: '47%', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1,
      borderRadius: radius.md, paddingVertical: spacing.md, paddingHorizontal: spacing.lg,
      flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    },
    custom: { justifyContent: 'center', borderColor: colors.primary },
    customText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.6 },
    quickLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    quickAmount: { color: colors.softGreen, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth },
    rowName: { color: colors.text, fontSize: fontSize.body, flex: 1 },
    rowRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    rowAmount: { fontSize: fontSize.body, fontWeight: fontWeight.bold },
    trash: { padding: 2 },
    empty: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },

    toast: {
      position: 'absolute',
      left: spacing.lg,
      right: spacing.lg,
      bottom: spacing.lg,
      minHeight: 48,
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      backgroundColor: colors.card,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.lg,
      paddingVertical: spacing.md,
    },
    toastText: { color: colors.text, fontSize: fontSize.body, flex: 1, paddingRight: spacing.md },
    toastBtn: { minHeight: 44, justifyContent: 'center' },
    toastUndo: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    typeRow: { flexDirection: 'row', gap: spacing.sm },
    typeBtn: { flex: 1, paddingVertical: spacing.sm + 2, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, alignItems: 'center' },
    typeOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    typeText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    typeTextOn: { color: '#FFFFFF' },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    err: { color: colors.warning, fontSize: fontSize.small, marginBottom: spacing.sm },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
