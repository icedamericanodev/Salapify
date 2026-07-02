// Accounts screen, now wired to the real data store. You can add, edit,
// delete, and change the balance of accounts and assets. Debts are shown here
// for the totals but are managed on the Debts tab. Everything you change is
// saved on the device.

import { useMemo, useState } from 'react';
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
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney } from '../../lib/format';

// The kinds you can pick in the form.
const ACCOUNT_KINDS = [
  { key: 'cash', label: 'Cash' },
  { key: 'savings', label: 'Savings' },
  { key: 'checking', label: 'Checking' },
  { key: 'ewallet', label: 'E-wallet' },
];
const ASSET_KINDS = [
  { key: 'crypto', label: 'Crypto' },
  { key: 'stocks', label: 'Stocks' },
  { key: 'mp2', label: 'MP2' },
  { key: 'real estate', label: 'Real estate' },
  { key: 'vehicle', label: 'Vehicle' },
  { key: 'other', label: 'Other' },
];

export default function Accounts() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, addItem, updateItem, removeItem } = useAppData();

  // The form modal. null when closed; otherwise holds the fields being edited.
  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);

  function openAdd(type) {
    setForm({
      type, // 'account' or 'asset'
      id: null,
      name: '',
      kind: type === 'account' ? 'cash' : 'crypto',
      brand: '',
      icon: '',
      amount: '',
    });
    setErr('');
    setConfirmDel(false);
  }
  function openEdit(type, item) {
    setForm({
      type,
      id: item.id,
      name: item.name,
      kind: item.kind,
      brand: item.brand || '',
      icon: item.icon || '',
      amount: String(type === 'account' ? item.balance : item.value),
    });
    setErr('');
    setConfirmDel(false);
  }
  function close() {
    setForm(null);
  }
  function save() {
    if (!form.name.trim()) {
      setErr('Please enter a name.');
      return;
    }
    const amount = Number(form.amount);
    if (form.amount === '' || !Number.isFinite(amount) || amount < 0) {
      setErr('Enter a valid amount (0 or more).');
      return;
    }
    if (form.type === 'account') {
      const payload = {
        name: form.name.trim() || 'Account',
        kind: form.kind,
        brand: form.brand.trim(),
        icon: form.icon.trim() || '💵',
        balance: amount,
      };
      if (form.id) updateItem('accounts', form.id, payload);
      else addItem('accounts', payload);
    } else {
      const payload = { name: form.name.trim() || 'Asset', kind: form.kind, value: amount };
      if (form.id) updateItem('assets', form.id, payload);
      else addItem('assets', payload);
    }
    close();
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) removeItem(form.type === 'account' ? 'accounts' : 'assets', form.id);
    close();
  }

  // Group the data for display.
  const cash = data.accounts.filter((a) => a.kind === 'cash');
  const bank = data.accounts.filter((a) =>
    ['savings', 'checking', 'ewallet'].includes(a.kind)
  );
  const sum = (list, key) => list.reduce((t, x) => t + (x[key] || 0), 0);
  const totalAssets = sum(data.accounts, 'balance') + sum(data.assets, 'value');
  const totalDebt = sum(data.debts, 'remaining');
  const netWorth = totalAssets - totalDebt;

  const Row = ({ icon, name, sub, amount, amountColor, onPress }) => (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, pressed && onPress && styles.pressed]}
    >
      <Text style={styles.rowIcon}>{icon}</Text>
      <View style={styles.rowMiddle}>
        <Text style={styles.rowName}>{name}</Text>
        {sub ? <Text style={styles.rowSub}>{sub}</Text> : null}
      </View>
      <Text style={[styles.rowAmount, amountColor ? { color: amountColor } : null]}>{amount}</Text>
    </Pressable>
  );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Accounts</Text>

        <View style={styles.summaryCard}>
          <Text style={styles.kicker}>NET WORTH</Text>
          <Text style={styles.netWorth}>{formatMoney(netWorth)}</Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Total assets</Text>
              <Text style={[styles.smallValue, { color: colors.primary }]}>
                {formatMoney(totalAssets)}
              </Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Total debt</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>
                {formatMoney(totalDebt)}
              </Text>
            </View>
          </View>
        </View>

        {/* Add buttons. */}
        <View style={styles.addRow}>
          <Pressable
            onPress={() => openAdd('account')}
            style={({ pressed }) => [styles.addBtn, pressed && styles.pressed]}
          >
            <Text style={styles.addBtnText}>+ Account</Text>
          </Pressable>
          <Pressable
            onPress={() => openAdd('asset')}
            style={({ pressed }) => [styles.addBtn, pressed && styles.pressed]}
          >
            <Text style={styles.addBtnText}>+ Asset</Text>
          </Pressable>
        </View>

        <Section title="CASH" subtotal={formatMoney(sum(cash, 'balance'))} styles={styles}>
          {cash.map((a) => (
            <Row
              key={a.id}
              icon={a.icon}
              name={a.name}
              amount={formatMoney(a.balance)}
              onPress={() => openEdit('account', a)}
            />
          ))}
          {cash.length === 0 ? <Empty styles={styles} text="No cash account yet." /> : null}
        </Section>

        <Section title="SAVINGS AND BANK" subtotal={formatMoney(sum(bank, 'balance'))} styles={styles}>
          {bank.map((a) => (
            <Row
              key={a.id}
              icon={a.icon}
              name={a.name}
              sub={a.brand}
              amount={formatMoney(a.balance)}
              onPress={() => openEdit('account', a)}
            />
          ))}
          {bank.length === 0 ? <Empty styles={styles} text="Nothing here yet." /> : null}
        </Section>

        <Section
          title="INVESTMENTS AND OTHER ASSETS"
          subtotal={formatMoney(sum(data.assets, 'value'))}
          styles={styles}
        >
          {data.assets.map((a) => (
            <Row
              key={a.id}
              icon="📈"
              name={a.name}
              sub={a.kind}
              amount={formatMoney(a.value)}
              onPress={() => openEdit('asset', a)}
            />
          ))}
          {data.assets.length === 0 ? <Empty styles={styles} text="No assets yet." /> : null}
        </Section>

        <Section
          title="DEBTS"
          subtotal={formatMoney(totalDebt)}
          subtotalColor={colors.warning}
          styles={styles}
        >
          {data.debts.map((d) => (
            <Row key={d.id} icon="💳" name={d.name} amount={formatMoney(d.remaining)} amountColor={colors.warning} />
          ))}
          <Text style={styles.note}>Manage debts on the Debts tab.</Text>
        </Section>
      </ScrollView>

      {/* Add / edit form. */}
      <Modal visible={!!form} transparent animationType="slide" onRequestClose={close}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView>
              <Text style={styles.sheetTitle}>
                {form?.id ? 'Edit' : 'Add'} {form?.type}
              </Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput
                style={styles.input}
                value={form?.name}
                onChangeText={(t) => setForm((f) => ({ ...f, name: t }))}
                placeholder="e.g. BPI Savings"
                placeholderTextColor={colors.faint}
              />

              <Text style={styles.fieldLabel}>Type</Text>
              <View style={styles.chips}>
                {(form?.type === 'account' ? ACCOUNT_KINDS : ASSET_KINDS).map((k) => {
                  const on = form?.kind === k.key;
                  return (
                    <Pressable
                      key={k.key}
                      onPress={() => setForm((f) => ({ ...f, kind: k.key }))}
                      style={[styles.chip, on && styles.chipOn]}
                    >
                      <Text style={[styles.chipText, on && styles.chipTextOn]}>{k.label}</Text>
                    </Pressable>
                  );
                })}
              </View>

              {form?.type === 'account' ? (
                <>
                  <Text style={styles.fieldLabel}>Bank or brand (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.brand}
                    onChangeText={(t) => setForm((f) => ({ ...f, brand: t }))}
                    placeholder="e.g. BPI"
                    placeholderTextColor={colors.faint}
                  />
                  <Text style={styles.fieldLabel}>Emoji icon (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.icon}
                    onChangeText={(t) => setForm((f) => ({ ...f, icon: t }))}
                    placeholder="💵"
                    placeholderTextColor={colors.faint}
                  />
                </>
              ) : null}

              <Text style={styles.fieldLabel}>
                {form?.type === 'account' ? 'Balance' : 'Value'}
              </Text>
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
                {form?.id ? (
                  <Pressable onPress={del} style={[styles.sheetBtn, styles.deleteBtn]}>
                    <Text style={styles.deleteText}>{confirmDel ? 'Tap to confirm' : 'Delete'}</Text>
                  </Pressable>
                ) : (
                  <View />
                )}
                <View style={styles.sheetRight}>
                  <Pressable onPress={close} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={save} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Save</Text>
                  </Pressable>
                </View>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

// Small presentational helpers (kept outside; they take styles as a prop).
function Section({ title, subtotal, subtotalColor, styles, children }) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>{title}</Text>
        <Text style={[styles.sectionSubtotal, subtotalColor ? { color: subtotalColor } : null]}>
          {subtotal}
        </Text>
      </View>
      <View style={styles.card}>{children}</View>
    </View>
  );
}
function Empty({ styles, text }) {
  return <Text style={styles.empty}>{text}</Text>;
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.bold,
      marginBottom: spacing.md,
    },
    summaryCard: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 2 },
    netWorth: { color: colors.text, fontSize: fontSize.huge, fontWeight: fontWeight.bold, marginTop: spacing.xs, marginBottom: spacing.lg },
    splitRow: { flexDirection: 'row', justifyContent: 'space-between' },
    smallLabel: { color: colors.muted, fontSize: fontSize.caption },
    smallValue: { fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    addRow: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.lg },
    addBtn: {
      flex: 1,
      backgroundColor: colors.card,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingVertical: spacing.md,
      alignItems: 'center',
    },
    addBtnText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    section: { marginBottom: spacing.lg },
    sectionHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'flex-end',
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5 },
    sectionSubtotal: { color: colors.textSecondary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      paddingHorizontal: spacing.lg,
    },
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingVertical: spacing.md,
      borderBottomColor: colors.border,
      borderBottomWidth: StyleSheet.hairlineWidth,
    },
    pressed: { opacity: 0.6 },
    rowIcon: { fontSize: 22, marginRight: spacing.md },
    rowMiddle: { flex: 1 },
    rowName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    note: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },
    empty: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },

    // Modal form.
    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: {
      backgroundColor: colors.background,
      borderTopLeftRadius: radius.lg,
      borderTopRightRadius: radius.lg,
      borderColor: colors.border,
      borderWidth: 1,
      padding: spacing.xl,
      maxHeight: '90%',
    },
    sheetTitle: {
      color: colors.text,
      fontSize: fontSize.subtitle,
      fontWeight: fontWeight.bold,
      marginBottom: spacing.lg,
      textTransform: 'capitalize',
    },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.md,
      color: colors.text,
      fontSize: fontSize.body,
    },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: {
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
    },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    chipTextOn: { color: '#FFFFFF' },

    sheetButtons: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginTop: spacing.xl,
    },
    sheetRight: { flexDirection: 'row', gap: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    deleteBtn: { backgroundColor: 'transparent' },
    deleteText: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    err: { color: colors.warning, fontSize: fontSize.small, marginBottom: spacing.sm },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
