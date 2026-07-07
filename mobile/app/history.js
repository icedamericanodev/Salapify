// History: every transaction ever logged, by month, with edit and delete.
// Budget's Recent list shows only the newest twelve; this screen is where
// the full record lives, because people must be able to see and correct
// their own money history. Built to stay smooth at thousands of rows: the
// list is a virtualized FlatList with memoized rows, the totals are
// memoized, and the edit sheet keeps its typing state to itself so a
// keystroke never re-renders the list. Editing goes through
// updateTransaction in the store, which reverses the old entry's effect
// on its linked account and applies the new one, so balances never drift.

import { memo, useCallback, useMemo, useState } from 'react';
import {
  Alert,
  FlatList,
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
import { useRouter, useLocalSearchParams } from 'expo-router';
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
  if (!y || !m || m < 1 || m > 12) return key;
  return `${MONTHS_SHORT[m - 1]} ${y}`;
}

function isRealDate(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s).trim());
  if (!m) return false;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return d.getFullYear() === Number(m[1]) && d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3]);
}

// One list row, memoized so scrolling and unrelated state changes never
// re-render the whole history.
const Row = memo(function Row({ t, accountName, colors, styles, onEdit, onDelete, onReceipt }) {
  return (
    <View style={styles.row}>
      <Pressable onPress={() => onEdit(t)} style={styles.rowMain}>
        <View style={{ flex: 1 }}>
          <Text style={styles.rowName}>{t.label}</Text>
          <Text style={styles.rowSub}>
            {t.date}
            {accountName ? ` · ${accountName}` : ''}
          </Text>
        </View>
        <Text style={[styles.rowAmount, { color: t.type === 'income' ? colors.primary : t.type === 'expense' ? colors.text : colors.muted }]}>
          {t.type === 'income' ? '+' : t.type === 'transfer' ? '⇄' : '-'} {formatMoney(t.amount)}
        </Text>
      </Pressable>
      {t.receiptUri && Platform.OS !== 'web' ? (
        <Pressable onPress={() => onReceipt(t.receiptUri)} hitSlop={8} style={styles.rowIconBtn}>
          <Text style={{ fontSize: 15 }}>🧾</Text>
        </Pressable>
      ) : null}
      <Pressable onPress={() => onDelete(t)} hitSlop={8} style={styles.rowIconBtn}>
        <Ionicons name="close" size={16} color={colors.faint} />
      </Pressable>
    </View>
  );
});

// The edit sheet owns its form state, so typing re-renders only this
// small component, never the list behind it.
function EditSheet({ tx, accounts, colors, styles, onClose, onSave }) {
  // Transfer and debt payment rows are records of something that already
  // moved balances when it happened. Editing one would let the story and
  // the balances disagree, so records open read only.
  const isRecord = tx.type === 'transfer' || tx.type === 'debt';
  const [form, setForm] = useState(() => ({
    type: tx.type === 'income' ? 'income' : 'expense',
    label: String(tx.label || ''),
    amount: String(tx.amount),
    date: String(tx.date || todayISO()),
    // A pointer at a deleted account reads as unlinked, so the chips
    // always show a true selection.
    accountId:
      typeof tx.accountId === 'string' && accounts.some((a) => a.id === tx.accountId)
        ? tx.accountId
        : '',
  }));
  const [err, setErr] = useState('');

  function save() {
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
    onSave({
      type: form.type,
      label: form.label.trim() || (form.type === 'income' ? 'Income' : 'Expense'),
      amount,
      date: form.date.trim(),
      accountId: form.accountId || undefined,
    });
  }

  if (isRecord) {
    return (
      <Modal visible transparent animationType="slide" onRequestClose={onClose}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>{tx.label}</Text>
            <Text style={styles.recordNote}>
              {formatMoney(tx.amount)} on {tx.date}.{'\n\n'}
              This row is a record of {tx.type === 'transfer' ? 'a transfer between accounts' : 'a debt payment'},
              written the moment it happened. The balances already moved then, so the record
              cannot be edited. Deleting it with the x only removes this history row, it does
              not undo the {tx.type === 'transfer' ? 'transfer' : 'payment'}.
            </Text>
            <View style={styles.sheetButtons}>
              <View />
              <Pressable onPress={onClose} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    );
  }

  return (
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <Text style={styles.sheetTitle}>Edit entry</Text>

          <View style={styles.typeRow}>
            {['expense', 'income'].map((ty) => {
              const on = form.type === ty;
              return (
                <Pressable key={ty} onPress={() => setForm((f) => ({ ...f, type: ty }))} style={[styles.typeBtn, on && styles.typeOn]}>
                  <Text style={[styles.typeText, on && styles.typeTextOn]}>{ty === 'expense' ? 'Expense' : 'Income'}</Text>
                </Pressable>
              );
            })}
          </View>

          <Text style={styles.fieldLabel}>{form.type === 'income' ? 'Source' : 'Category'}</Text>
          <TextInput style={styles.input} value={form.label} onChangeText={(t) => setForm((f) => ({ ...f, label: t }))} placeholderTextColor={colors.faint} />
          <Text style={styles.fieldLabel}>Amount</Text>
          <TextInput style={styles.input} value={form.amount} onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))} keyboardType="numeric" placeholderTextColor={colors.faint} />
          <Text style={styles.fieldLabel}>Date</Text>
          <TextInput style={styles.input} value={form.date} onChangeText={(t) => setForm((f) => ({ ...f, date: t }))} placeholder="YYYY-MM-DD" placeholderTextColor={colors.faint} autoCapitalize="none" />

          {accounts.length > 0 ? (
            <>
              <Text style={styles.fieldLabel}>{form.type === 'income' ? 'Into which account?' : 'From which account?'}</Text>
              <View style={styles.chips}>
                <Pressable onPress={() => setForm((f) => ({ ...f, accountId: '' }))} style={[styles.chip, !form.accountId && styles.chipOn]}>
                  <Text style={[styles.chipText, !form.accountId && styles.chipTextOn]}>Not linked</Text>
                </Pressable>
                {accounts.map((a) => {
                  const on = form.accountId === a.id;
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
            <Pressable onPress={onClose} style={[styles.sheetBtn, styles.cancelBtn]}>
              <Text style={styles.cancelText}>Cancel</Text>
            </Pressable>
            <Pressable onPress={save} style={[styles.sheetBtn, styles.saveBtn]}>
              <Text style={styles.saveText}>Save</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

export default function History() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const params = useLocalSearchParams();
  const { data, updateTransaction, removeTransaction } = useAppData();

  const [month, setMonth] = useState('all');
  // Opened from global Search? Start filtered to the same words.
  const [query, setQuery] = useState(() => (typeof params.q === 'string' ? params.q : ''));
  const [editTx, setEditTx] = useState(null);
  const [receiptView, setReceiptView] = useState('');
  const [receiptDead, setReceiptDead] = useState(false);

  // Which months exist in the data, newest first.
  const monthKeys = useMemo(() => {
    const keys = new Set();
    for (const t of data.transactions || []) {
      if (t && typeof t.date === 'string' && /^\d{4}-\d{2}/.test(t.date)) keys.add(t.date.slice(0, 7));
    }
    return [...keys].sort().reverse();
  }, [data.transactions]);

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    const list = (data.transactions || []).filter((t) => {
      if (!t) return false;
      if (month !== 'all' && String(t.date || '').slice(0, 7) !== month) return false;
      if (q && !String(t.label || '').toLowerCase().includes(q)) return false;
      return true;
    });
    return [...list].sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
  }, [data.transactions, month, query]);

  const totals = useMemo(() => {
    // Only real income and expenses. Transfer and debt payment records are
    // visible as rows but never enter money math: a 5,000 transfer between
    // your own accounts is not 5,000 spent.
    let tin = 0;
    let tout = 0;
    for (const t of shown) {
      if (t.type === 'income') tin += Number(t.amount) || 0;
      else if (t.type === 'expense') tout += Number(t.amount) || 0;
    }
    return { tin, tout };
  }, [shown]);

  // One lookup map instead of a linear find per row per render.
  const accountNames = useMemo(() => {
    const m = new Map();
    for (const a of data.accounts || []) m.set(a.id, a.name);
    return m;
  }, [data.accounts]);

  const onEdit = useCallback((t) => setEditTx(t), []);
  const onReceipt = useCallback((uri) => {
    setReceiptDead(false);
    setReceiptView(resolveReceipt(uri));
  }, []);
  const onDelete = useCallback(
    (t) => {
      const doIt = () => removeTransaction(t.id);
      // Record rows move nothing when deleted, so their confirm must not
      // promise a refund the way the normal entry confirm does.
      const isRecord = t.type === 'transfer' || t.type === 'debt';
      const detail = isRecord
        ? 'This only removes the history row. It does not undo the money move.'
        : 'A linked account gets its money back.';
      if (Platform.OS === 'web') {
        if (window.confirm(`Delete ${t.label} ${formatMoney(t.amount)}? ${detail}`)) doIt();
        return;
      }
      Alert.alert('Delete this entry?', `${t.label}, ${formatMoney(t.amount)}. ${detail}`, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: doIt },
      ]);
    },
    [removeTransaction]
  );

  const renderItem = useCallback(
    ({ item }) => (
      <Row
        t={item}
        accountName={item.accountId ? accountNames.get(item.accountId) || '' : ''}
        colors={colors}
        styles={styles}
        onEdit={onEdit}
        onDelete={onDelete}
        onReceipt={onReceipt}
      />
    ),
    [accountNames, colors, styles, onEdit, onDelete, onReceipt]
  );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable
          onPress={() => (router.canGoBack && router.canGoBack() ? router.back() : router.replace('/(tabs)'))}
          hitSlop={10}
          style={styles.back}
        >
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>History</Text>
        <View style={{ width: 24 }} />
      </View>

      <View style={styles.searchWrap}>
        <Ionicons name="search" size={18} color={colors.faint} />
        <TextInput
          style={styles.searchInput}
          value={query}
          onChangeText={setQuery}
          placeholder="Search entries, like jollibee or load"
          placeholderTextColor={colors.faint}
          autoCapitalize="none"
        />
        {query ? (
          <Pressable onPress={() => setQuery('')} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={colors.faint} />
          </Pressable>
        ) : null}
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

      <FlatList
        data={shown}
        keyExtractor={(t) => t.id}
        renderItem={renderItem}
        contentContainerStyle={styles.content}
        initialNumToRender={20}
        windowSize={7}
        ListHeaderComponent={
          <View style={styles.totalsCard}>
            <View>
              <Text style={styles.totalsLabel}>Money in</Text>
              <Text style={[styles.totalsValue, { color: colors.primary }]}>{formatMoney(totals.tin)}</Text>
            </View>
            <View>
              <Text style={styles.totalsLabel}>Money out</Text>
              <Text style={styles.totalsValue}>{formatMoney(totals.tout)}</Text>
            </View>
            <View>
              <Text style={styles.totalsLabel}>Entries</Text>
              <Text style={styles.totalsValue}>{shown.length}</Text>
            </View>
          </View>
        }
        ListEmptyComponent={
          <EmptyState icon="🧾" title="Nothing here" subtitle="Entries you log will show up here." />
        }
      />

      {editTx ? (
        <EditSheet
          key={editTx.id}
          tx={editTx}
          accounts={data.accounts || []}
          colors={colors}
          styles={styles}
          onClose={() => setEditTx(null)}
          onSave={(patch) => {
            // Keep the category tag honest after an edit: the tag follows
            // the new label (matching category name), otherwise it clears,
            // so caps and charts can never disagree about a relabeled peso.
            const cat = (data.categories || []).find((c) => c.name === patch.label);
            updateTransaction(editTx.id, { ...patch, categoryId: cat ? cat.id : undefined });
            setEditTx(null);
          }}
        />
      ) : null}

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

    searchWrap: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.sm,
      marginHorizontal: spacing.lg,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.md,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
    },
    searchInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
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

    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, gap: spacing.sm, backgroundColor: colors.background },
    rowMain: { flex: 1, flexDirection: 'row', alignItems: 'center' },
    rowName: { color: colors.text, fontSize: fontSize.body },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { fontSize: fontSize.body, fontWeight: fontWeight.bold },
    rowIconBtn: { padding: 2 },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    recordNote: { color: colors.textSecondary, fontSize: fontSize.body, lineHeight: 20 },
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
