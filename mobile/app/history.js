// History: every transaction ever logged, by month, with edit and delete.
// Budget's Recent list shows only the newest twelve; this screen is where
// the full record lives, because people must be able to see and correct
// their own money history. Editing goes through updateTransaction in the
// store, which reverses the old entry's effect on its linked account and
// applies the new one, so balances never drift.

import { useMemo, useState } from 'react';
import {
  Alert,
  Image,
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
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, todayISO } from '../lib/format';
import { resolveReceipt } from '../lib/receipts';
import EmptyState from '../components/EmptyState';

const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// "2026-07" -> "Jul 2026"
function monthTitle(key) {
  const [y, m] = String(key).split('-').map(Number);
  if (!y || !m) return key;
  return `${MONTHS_SHORT[m - 1]} ${y}`;
}

function isRealDate(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s).trim());
  if (!m) return false;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return d.getFullYear() === Number(m[1]) && d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3]);
}

export default function History() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateTransaction, removeTransaction } = useAppData();

  // Which months exist in the data, newest first. "all" shows everything.
  const monthKeys = useMemo(() => {
    const keys = new Set();
    for (const t of data.transactions || []) {
      if (t && typeof t.date === 'string' && t.date.length >= 7) keys.add(t.date.slice(0, 7));
    }
    return [...keys].sort().reverse();
  }, [data.transactions]);

  const [month, setMonth] = useState('all');
  const [form, setForm] = useState(null); // the edit sheet
  const [err, setErr] = useState('');
  const [receiptView, setReceiptView] = useState('');
  const [receiptDead, setReceiptDead] = useState(false);

  const shown = useMemo(() => {
    const list = (data.transactions || []).filter(
      (t) => t && (month === 'all' || String(t.date || '').slice(0, 7) === month)
    );
    return [...list].sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
  }, [data.transactions, month]);

  const totalIn = shown.filter((t) => t.type === 'income').reduce((s, t) => s + (Number(t.amount) || 0), 0);
  const totalOut = shown.filter((t) => t.type === 'expense').reduce((s, t) => s + (Number(t.amount) || 0), 0);

  function openEdit(t) {
    setForm({
      id: t.id,
      type: t.type === 'income' ? 'income' : 'expense',
      label: String(t.label || ''),
      amount: String(t.amount),
      date: String(t.date || todayISO()),
      accountId: typeof t.accountId === 'string' ? t.accountId : '',
    });
    setErr('');
  }
  function saveEdit() {
    const amount = Number(String(form.amount).replace(/[, ]/g, ''));
    if (!Number.isFinite(amount) || amount <= 0) {
      setErr('Enter an amount greater than 0.');
      return;
    }
    if (!isRealDate(form.date)) {
      setErr('Type the date as YYYY-MM-DD, like 2026-06-28.');
      return;
    }
    if (form.date.trim() > todayISO()) {
      setErr('That date is in the future.');
      return;
    }
    updateTransaction(form.id, {
      type: form.type,
      label: form.label.trim() || (form.type === 'income' ? 'Income' : 'Expense'),
      amount,
      date: form.date.trim(),
      accountId: form.accountId || undefined,
    });
    setForm(null);
  }
  function confirmDelete(t) {
    const doIt = () => removeTransaction(t.id);
    if (Platform.OS === 'web') {
      if (window.confirm(`Delete ${t.label} ${formatMoney(t.amount)}?`)) doIt();
      return;
    }
    Alert.alert('Delete this entry?', `${t.label}, ${formatMoney(t.amount)}. A linked account gets its money back.`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: doIt },
    ]);
  }

  const accountName = (id) => {
    const a = data.accounts.find((x) => x.id === id);
    return a ? a.name : '';
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>History</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.monthBar} contentContainerStyle={styles.monthRow}>
        <Pressable onPress={() => setMonth('all')} style={[styles.chip, month === 'all' && styles.chipOn]}>
          <Text style={[styles.chipText, month === 'all' && styles.chipTextOn]}>All</Text>
        </Pressable>
        {monthKeys.map((k) => (
          <Pressable key={k} onPress={() => setMonth(k)} style={[styles.chip, month === k && styles.chipOn]}>
            <Text style={[styles.chipText, month === k && styles.chipTextOn]}>{monthTitle(k)}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.totalsCard}>
          <View>
            <Text style={styles.totalsLabel}>Money in</Text>
            <Text style={[styles.totalsValue, { color: colors.primary }]}>{formatMoney(totalIn)}</Text>
          </View>
          <View>
            <Text style={styles.totalsLabel}>Money out</Text>
            <Text style={styles.totalsValue}>{formatMoney(totalOut)}</Text>
          </View>
          <View>
            <Text style={styles.totalsLabel}>Entries</Text>
            <Text style={styles.totalsValue}>{shown.length}</Text>
          </View>
        </View>

        {shown.length === 0 ? (
          <EmptyState icon="🧾" title="Nothing here" subtitle="Entries you log will show up here." />
        ) : (
          <View style={styles.card}>
            {shown.map((t) => (
              <View key={t.id} style={styles.row}>
                <Pressable onPress={() => openEdit(t)} style={styles.rowMain}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.rowName}>{t.label}</Text>
                    <Text style={styles.rowSub}>
                      {t.date}
                      {t.accountId && accountName(t.accountId) ? ` · ${accountName(t.accountId)}` : ''}
                    </Text>
                  </View>
                  <Text style={[styles.rowAmount, { color: t.type === 'income' ? colors.primary : colors.text }]}>
                    {t.type === 'income' ? '+' : '-'} {formatMoney(t.amount)}
                  </Text>
                </Pressable>
                {t.receiptUri ? (
                  <Pressable
                    onPress={() => {
                      setReceiptDead(false);
                      setReceiptView(resolveReceipt(t.receiptUri));
                    }}
                    hitSlop={8}
                    style={styles.rowIconBtn}
                  >
                    <Text style={{ fontSize: 15 }}>🧾</Text>
                  </Pressable>
                ) : null}
                <Pressable onPress={() => confirmDelete(t)} hitSlop={8} style={styles.rowIconBtn}>
                  <Ionicons name="close" size={16} color={colors.faint} />
                </Pressable>
              </View>
            ))}
          </View>
        )}
      </ScrollView>

      {/* Edit sheet. */}
      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Edit entry</Text>

            <View style={styles.typeRow}>
              {['expense', 'income'].map((ty) => {
                const on = form?.type === ty;
                return (
                  <Pressable key={ty} onPress={() => setForm((f) => ({ ...f, type: ty }))} style={[styles.typeBtn, on && styles.typeOn]}>
                    <Text style={[styles.typeText, on && styles.typeTextOn]}>{ty === 'expense' ? 'Expense' : 'Income'}</Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>{form?.type === 'income' ? 'Source' : 'Category'}</Text>
            <TextInput style={styles.input} value={form?.label} onChangeText={(t) => setForm((f) => ({ ...f, label: t }))} placeholderTextColor={colors.faint} />
            <Text style={styles.fieldLabel}>Amount</Text>
            <TextInput style={styles.input} value={form?.amount} onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))} keyboardType="numeric" placeholderTextColor={colors.faint} />
            <Text style={styles.fieldLabel}>Date</Text>
            <TextInput style={styles.input} value={form?.date} onChangeText={(t) => setForm((f) => ({ ...f, date: t }))} placeholder="YYYY-MM-DD" placeholderTextColor={colors.faint} autoCapitalize="none" />

            {data.accounts.length > 0 ? (
              <>
                <Text style={styles.fieldLabel}>{form?.type === 'income' ? 'Into which account?' : 'From which account?'}</Text>
                <View style={styles.chips}>
                  <Pressable onPress={() => setForm((f) => ({ ...f, accountId: '' }))} style={[styles.chip, !form?.accountId && styles.chipOn]}>
                    <Text style={[styles.chipText, !form?.accountId && styles.chipTextOn]}>Not linked</Text>
                  </Pressable>
                  {data.accounts.map((a) => {
                    const on = form?.accountId === a.id;
                    return (
                      <Pressable key={a.id} onPress={() => setForm((f) => ({ ...f, accountId: a.id }))} style={[styles.chip, on && styles.chipOn]}>
                        <Text style={[styles.chipText, on && styles.chipTextOn]}>
                          {a.icon ? `${a.icon} ` : ''}{a.name}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </>
            ) : null}

            {err ? <Text style={styles.err}>{err}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setForm(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={saveEdit} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Save</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Receipt viewer, same behavior as Budget's. */}
      <Modal visible={!!receiptView} transparent animationType="fade" onRequestClose={() => setReceiptView('')}>
        <Pressable style={styles.receiptOverlay} onPress={() => setReceiptView('')}>
          {receiptView && !receiptDead ? (
            <Image source={{ uri: receiptView }} style={styles.receiptImage} resizeMode="contain" onError={() => setReceiptDead(true)} />
          ) : null}
          {receiptDead ? (
            <Text style={styles.receiptDeadText}>
              This photo is not on this phone. Receipt photos stay on the phone that took them.
            </Text>
          ) : null}
          <Text style={styles.receiptClose}>Tap anywhere to close</Text>
        </Pressable>
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

    monthBar: { flexGrow: 0 },
    monthRow: { gap: spacing.sm, paddingHorizontal: spacing.lg, paddingBottom: spacing.sm },
    chip: { paddingVertical: spacing.sm, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.medium },

    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    totalsCard: { flexDirection: 'row', justifyContent: 'space-between', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    totalsLabel: { color: colors.muted, fontSize: fontSize.caption },
    totalsValue: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginTop: 2 },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, gap: spacing.sm },
    rowMain: { flex: 1, flexDirection: 'row', alignItems: 'center' },
    rowName: { color: colors.text, fontSize: fontSize.body },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { fontSize: fontSize.body, fontWeight: fontWeight.bold },
    rowIconBtn: { padding: 2 },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    typeRow: { flexDirection: 'row', gap: spacing.sm },
    typeBtn: { flex: 1, paddingVertical: spacing.sm + 2, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, alignItems: 'center' },
    typeOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    typeText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    typeTextOn: { color: colors.onPrimary },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    receiptOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.92)', alignItems: 'center', justifyContent: 'center', padding: spacing.lg },
    receiptImage: { width: '100%', height: '85%' },
    receiptDeadText: { color: '#FFFFFF', fontSize: fontSize.body, textAlign: 'center', paddingHorizontal: spacing.xl },
    receiptClose: { color: '#FFFFFF', fontSize: fontSize.small, opacity: 0.7, marginTop: spacing.md },
  });
}
