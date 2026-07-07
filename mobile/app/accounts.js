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
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, todayISO } from '../lib/format';
import { BANK_BRANDS, findBrand } from '../lib/banks';
import BankBadge from '../components/BankBadge';

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
  const router = useRouter();
  const { data, addItem, updateItem, removeItem, updateSettings, addTransaction } = useAppData();

  // The form modal. null when closed; otherwise holds the fields being edited.
  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);

  // The transfer modal. Moves money between two accounts in one step, so
  // "moved 5,000 from BPI to GCash" never needs two manual balance edits.
  const [transfer, setTransfer] = useState(null);
  const [transferErr, setTransferErr] = useState('');

  function openTransfer() {
    const first = data.accounts[0];
    const second = data.accounts[1];
    setTransfer({ fromId: first ? first.id : '', toId: second ? second.id : '', amount: '' });
    setTransferErr('');
  }
  function saveTransfer() {
    // Round to centavos so repeated transfers never leave float residue
    // like 0.30000000000000004 in a balance.
    const amount = Math.round(Number(String(transfer.amount).replace(/[, ]/g, '')) * 100) / 100;
    if (!Number.isFinite(amount) || amount <= 0) {
      setTransferErr('Enter an amount greater than 0.');
      return;
    }
    if (!transfer.fromId || !transfer.toId || transfer.fromId === transfer.toId) {
      setTransferErr('Pick two different accounts.');
      return;
    }
    const from = data.accounts.find((a) => a.id === transfer.fromId);
    const to = data.accounts.find((a) => a.id === transfer.toId);
    if (!from || !to) {
      setTransferErr('Pick two different accounts.');
      return;
    }
    const fromBal = Number(from.balance) || 0;
    // No overdrafts: a transfer can only move money that is really there,
    // and the edit form refuses negative balances anyway.
    if (amount > fromBal) {
      setTransferErr(`${from.name} only has ${formatMoney(fromBal)}.`);
      return;
    }
    // A transfer is not income or spending, so it never touches the budget
    // or cash flow. It only moves the balances.
    updateItem('accounts', from.id, { balance: Math.round((fromBal - amount) * 100) / 100 });
    updateItem('accounts', to.id, { balance: Math.round(((Number(to.balance) || 0) + amount) * 100) / 100 });
    // Leave a record row in the stream so History explains why both
    // balances changed. type "transfer" is skipped by every income and
    // expense calculation, and it carries no accountId on purpose: the
    // balances moved right here, and deleting the record from History
    // later must never move them again.
    addTransaction({
      type: 'transfer',
      label: `Transfer: ${from.name} to ${to.name}`,
      amount,
      date: todayISO(),
      transferFromId: from.id,
      transferToId: to.id,
    });
    setTransfer(null);
  }

  function openAdd(type) {
    setForm({
      type, // 'account' or 'asset'
      id: null,
      name: '',
      kind: type === 'account' ? 'cash' : 'crypto',
      brand: '',
      icon: '',
      amount: '',
      target: '',
    });
    setErr('');
    setConfirmDel(false);
  }
  function openEdit(type, item) {
    // Everything becomes a string here: a restored backup can carry odd
    // types, and a non string in these fields would crash Save later.
    setForm({
      type,
      id: item.id,
      name: String(item.name ?? ''),
      kind: item.kind,
      brand: typeof item.brand === 'string' ? item.brand : '',
      icon: typeof item.icon === 'string' ? item.icon : '',
      amount: String(type === 'account' ? item.balance : item.value),
      target: item.target ? String(item.target) : '',
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
      // A savings target is optional. When set, the account row shows a
      // progress bar toward it.
      const target = Number(form.target);
      if (form.target.trim() !== '' && (!Number.isFinite(target) || target < 0)) {
        setErr('Enter a valid target amount, or leave it empty.');
        return;
      }
      const payload = {
        name: form.name.trim() || 'Account',
        kind: form.kind,
        brand: form.brand.trim(),
        icon: form.icon.trim() || '💵',
        balance: amount,
        target: form.target.trim() === '' ? 0 : target,
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
    if (form.id) {
      removeItem(form.type === 'account' ? 'accounts' : 'assets', form.id);
      // Settings that point at the deleted account must not keep pointing
      // at a ghost: quick adds and sweldo would silently stop linking.
      if (form.type === 'account') {
        updateSettings((s) => ({
          defaultAccountId: s.defaultAccountId === form.id ? '' : s.defaultAccountId,
          salaryAccountId: s.salaryAccountId === form.id ? '' : s.salaryAccountId,
        }));
      }
    }
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

  const Row = ({ icon, brand, name, sub, amount, amountColor, onPress, progress }) => (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, pressed && onPress && styles.pressed]}
    >
      <View style={styles.rowIconWrap}>
        <BankBadge brand={brand} fallback={icon || '💵'} size={34} />
      </View>
      <View style={styles.rowMiddle}>
        <Text style={styles.rowName}>{name}</Text>
        {sub ? <Text style={styles.rowSub}>{sub}</Text> : null}
        {typeof progress === 'number' ? (
          <View style={styles.targetTrack}>
            <View style={[styles.targetFill, { width: `${Math.min(Math.round(progress * 100), 100)}%` }]} />
          </View>
        ) : null}
      </View>
      <Text style={[styles.rowAmount, amountColor ? { color: amountColor } : null]}>{amount}</Text>
    </Pressable>
  );

  // Progress toward a savings target, or undefined when no target is set.
  const targetProgress = (a) => (a.target > 0 ? Math.max(0, (a.balance || 0) / a.target) : undefined);
  const targetSub = (a) =>
    a.target > 0
      ? `${a.brand ? a.brand + ' . ' : ''}${Math.min(Math.max(0, Math.round(((a.balance || 0) / a.target) * 100)), 999)}% of ${formatMoney(a.target)}`
      : a.brand;

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
        <Text style={styles.headerTitle}>Accounts</Text>
        <View style={{ width: 24 }} />
      </View>
      <ScrollView contentContainerStyle={styles.content}>

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
          {data.accounts.length >= 2 ? (
            <Pressable
              onPress={openTransfer}
              style={({ pressed }) => [styles.addBtn, pressed && styles.pressed]}
            >
              <Text style={styles.addBtnText}>⇄ Transfer</Text>
            </Pressable>
          ) : null}
        </View>

        <Section title="CASH" subtotal={formatMoney(sum(cash, 'balance'))} styles={styles}>
          {cash.map((a) => (
            <Row
              key={a.id}
              icon={a.icon}
              brand={a.brand}
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
              brand={a.brand}
              name={a.name}
              sub={targetSub(a)}
              amount={formatMoney(a.balance)}
              onPress={() => openEdit('account', a)}
              progress={targetProgress(a)}
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
                  <Text style={styles.fieldLabel}>Your bank or e-wallet (optional)</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.brandRow}>
                    <Pressable
                      onPress={() => setForm((f) => ({ ...f, brand: '' }))}
                      style={styles.brandItem}
                    >
                      <View style={[styles.brandNone, !findBrand(form?.brand) && styles.brandPicked]}>
                        <Text style={styles.brandNoneText}>None</Text>
                      </View>
                      <Text style={styles.brandLabel}>Plain</Text>
                    </Pressable>
                    {BANK_BRANDS.map((b) => {
                      const on = findBrand(form?.brand)?.key === b.key;
                      return (
                        <Pressable
                          key={b.key}
                          onPress={() =>
                            setForm((f) => ({
                              ...f,
                              brand: b.name,
                              // The brand sets a sensible type: wallets are
                              // e-wallets, banks lift cash or wallet types to
                              // savings, and a hand picked checking survives.
                              kind:
                                b.kind === 'ewallet'
                                  ? 'ewallet'
                                  : f.kind === 'cash' || f.kind === 'ewallet'
                                    ? 'savings'
                                    : f.kind,
                            }))
                          }
                          style={styles.brandItem}
                        >
                          <View style={[styles.brandBadgeWrap, on && styles.brandPicked]}>
                            <BankBadge brand={b.key} size={44} />
                          </View>
                          <Text style={[styles.brandLabel, on && styles.brandLabelOn]} numberOfLines={1}>
                            {b.name}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </ScrollView>
                  <Text style={styles.fieldLabel}>Or type another bank (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.brand}
                    onChangeText={(t) => setForm((f) => ({ ...f, brand: t }))}
                    placeholder="e.g. HSBC"
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
                  <Text style={styles.fieldLabel}>Savings target (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.target}
                    onChangeText={(t) => setForm((f) => ({ ...f, target: t }))}
                    placeholder="e.g. 100000 for an emergency fund"
                    placeholderTextColor={colors.faint}
                    keyboardType="numeric"
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

      {/* Transfer between accounts. */}
      <Modal visible={!!transfer} transparent animationType="slide" onRequestClose={() => setTransfer(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView>
            <Text style={styles.sheetTitle}>Transfer</Text>

            <Text style={styles.fieldLabel}>From</Text>
            <View style={styles.chips}>
              {data.accounts.map((a) => {
                const on = transfer?.fromId === a.id;
                return (
                  <Pressable key={a.id} onPress={() => setTransfer((t) => ({ ...t, fromId: a.id }))} style={[styles.chip, on && styles.chipOn]}>
                    <Text style={[styles.chipText, on && styles.chipTextOn]}>
                      {a.icon ? `${a.icon} ` : ''}{a.name}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>To</Text>
            <View style={styles.chips}>
              {data.accounts.map((a) => {
                const on = transfer?.toId === a.id;
                return (
                  <Pressable key={a.id} onPress={() => setTransfer((t) => ({ ...t, toId: a.id }))} style={[styles.chip, on && styles.chipOn]}>
                    <Text style={[styles.chipText, on && styles.chipTextOn]}>
                      {a.icon ? `${a.icon} ` : ''}{a.name}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>Amount</Text>
            <TextInput
              style={styles.input}
              value={transfer?.amount}
              onChangeText={(t) => setTransfer((f) => ({ ...f, amount: t }))}
              placeholder="0"
              placeholderTextColor={colors.faint}
              keyboardType="numeric"
            />
            <Text style={styles.note}>
              Transfers only move balances. They never count as income or spending.
            </Text>

            {transferErr ? <Text style={styles.err}>{transferErr}</Text> : null}
            <View style={styles.sheetButtons}>
              <View />
              <View style={styles.sheetRight}>
                <Pressable onPress={() => setTransfer(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                  <Text style={styles.cancelText}>Cancel</Text>
                </Pressable>
                <Pressable onPress={saveTransfer} style={[styles.sheetBtn, styles.saveBtn]}>
                  <Text style={styles.saveText}>Move it</Text>
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
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.heavy,
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
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    netWorth: { color: colors.text, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: spacing.xs, marginBottom: spacing.lg },
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
    rowIconWrap: { marginRight: spacing.md },
    rowMiddle: { flex: 1 },

    // The bank and e-wallet picker in the form.
    brandRow: { gap: spacing.md, paddingVertical: spacing.xs },
    brandItem: { alignItems: 'center', width: 64 },
    brandBadgeWrap: { borderRadius: 14, borderWidth: 2, borderColor: 'transparent', padding: 2 },
    brandNone: {
      width: 44,
      height: 44,
      borderRadius: 12,
      borderWidth: 1,
      borderColor: colors.border,
      backgroundColor: colors.card,
      alignItems: 'center',
      justifyContent: 'center',
      margin: 2,
    },
    brandNoneText: { color: colors.muted, fontSize: fontSize.caption },
    brandPicked: { borderColor: colors.primary, borderWidth: 2, borderRadius: 14, margin: 0 },
    brandLabel: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.xs },
    brandLabelOn: { color: colors.text, fontWeight: fontWeight.medium },
    rowName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    targetTrack: { height: 5, borderRadius: radius.pill, backgroundColor: colors.border, overflow: 'hidden', marginTop: spacing.xs, maxWidth: 180 },
    targetFill: { height: '100%', borderRadius: radius.pill, backgroundColor: colors.primary },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    note: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },
    empty: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },

    // Modal form.
    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
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
    chipTextOn: { color: colors.onPrimary },

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
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
