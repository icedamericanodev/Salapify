// Recurring bills and income. Rent, internet, Netflix, salary, allowance:
// set it once and the app logs it automatically every month on its day,
// into the chosen account. Free covers up to 5 recurring items; Pro is
// unlimited. Posting happens in AppData when the app opens on or after
// the day, so nothing here needs background tasks.

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
import { formatMoney } from '../lib/format';
import EmptyState from '../components/EmptyState';

const FREE_LIMIT = 5;

export default function Recurring() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem, updateSettings } = useAppData();

  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);

  const list = data.recurring || [];
  const pro = !!data.settings.pro;
  const monthlyOut = list.filter((r) => r.type === 'expense').reduce((t, r) => t + (Number(r.amount) || 0), 0);
  const monthlyIn = list.filter((r) => r.type === 'income').reduce((t, r) => t + (Number(r.amount) || 0), 0);

  function openAdd() {
    if (!pro && list.length >= FREE_LIMIT) {
      setForm({ proWall: true });
      return;
    }
    setForm({ id: null, type: 'expense', label: '', amount: '', dayOfMonth: '', accountId: '' });
    setErr('');
    setConfirmDel(false);
  }
  function openEdit(r) {
    setForm({
      id: r.id,
      type: r.type,
      label: String(r.label || ''),
      amount: String(r.amount),
      dayOfMonth: String(r.dayOfMonth),
      accountId: typeof r.accountId === 'string' ? r.accountId : '',
    });
    setErr('');
    setConfirmDel(false);
  }
  function save() {
    if (!form.label.trim()) {
      setErr('Give it a name, like Rent or Netflix.');
      return;
    }
    const amount = Number(String(form.amount).replace(/[, ]/g, ''));
    if (!Number.isFinite(amount) || amount <= 0) {
      setErr('Enter an amount greater than 0.');
      return;
    }
    const day = Number(String(form.dayOfMonth).trim());
    if (!Number.isInteger(day) || day < 1 || day > 31) {
      setErr('The day should be from 1 to 31.');
      return;
    }
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    // Compare against the same clamped day the posting engine uses, so a
    // day 31 item added on April 30 behaves exactly like the engine will.
    const effectiveDay = Math.min(day, daysInMonth);
    // A day on or before today does NOT post retroactively, on add OR on
    // edit; the user has usually paid that one already. Editing the day
    // must never turn into a surprise back dated expense.
    const skipThisMonth = effectiveDay <= now.getDate();
    const payload = {
      type: form.type,
      label: form.label.trim(),
      amount,
      dayOfMonth: day,
      accountId: form.accountId || '',
    };
    if (form.id) {
      const existing = list.find((r) => r.id === form.id);
      const kept = existing && typeof existing.lastPosted === 'string' ? existing.lastPosted : '';
      updateItem('recurring', form.id, {
        ...payload,
        lastPosted: skipThisMonth && kept < monthKey ? monthKey : kept,
      });
    } else {
      addItem('recurring', {
        ...payload,
        lastPosted: skipThisMonth ? monthKey : '',
      });
    }
    setForm(null);
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) removeItem('recurring', form.id);
    setForm(null);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Recurring</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.totalCard}>
          <Text style={styles.kicker}>EVERY MONTH</Text>
          <Text style={styles.total}>{formatMoney(monthlyOut)} out</Text>
          {monthlyIn > 0 ? <Text style={styles.totalIn}>{formatMoney(monthlyIn)} in</Text> : null}
          <Text style={styles.hint}>
            Each one logs itself on its day. You just live your life.
          </Text>
        </View>

        {list.length === 0 ? (
          <EmptyState
            icon="🔁"
            title="Nothing recurring yet"
            subtitle="Add rent, internet, subscriptions, or your salary, and the app logs them for you every month."
          />
        ) : (
          list.map((r) => {
            const acct = data.accounts.find((a) => a.id === r.accountId);
            return (
              <Pressable key={r.id} onPress={() => openEdit(r)} style={({ pressed }) => [styles.card, pressed && styles.pressed]}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.itemName}>{r.label}</Text>
                  <Text style={styles.itemSub}>
                    Day {r.dayOfMonth} each month{acct ? ` . ${acct.name}` : ''}
                  </Text>
                </View>
                <Text style={[styles.itemAmount, r.type === 'income' && { color: colors.primary }]}>
                  {r.type === 'income' ? '+' : '-'} {formatMoney(r.amount)}
                </Text>
              </Pressable>
            );
          })
        )}
        {!pro ? (
          <Text style={styles.limitNote}>
            {list.length} of {FREE_LIMIT} free recurring items used. Pro is unlimited.
          </Text>
        ) : null}
      </ScrollView>

      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            {form?.proWall ? (
              <>
                <Text style={styles.sheetTitle}>That is 5 of 5 on free</Text>
                <Text style={styles.wallText}>
                  Pro removes the limit. Pro will be a one time purchase at launch, and early
                  users unlock it free today and keep it.
                </Text>
                <View style={styles.sheetButtons}>
                  <View />
                  <View style={styles.sheetRight}>
                    <Pressable onPress={() => setForm(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                      <Text style={styles.cancelText}>Not now</Text>
                    </Pressable>
                    <Pressable
                      onPress={() => {
                        updateSettings({ pro: true });
                        setForm(null);
                      }}
                      style={[styles.sheetBtn, styles.saveBtn]}
                    >
                      <Text style={styles.saveText}>Unlock Pro free</Text>
                    </Pressable>
                  </View>
                </View>
              </>
            ) : (
              <ScrollView>
                <Text style={styles.sheetTitle}>{form?.id ? 'Edit' : 'Add'} recurring</Text>

                <View style={styles.typeRow}>
                  {['expense', 'income'].map((t) => {
                    const on = form?.type === t;
                    return (
                      <Pressable key={t} onPress={() => setForm((f) => ({ ...f, type: t }))} style={[styles.typeBtn, on && styles.typeOn]}>
                        <Text style={[styles.typeText, on && styles.typeTextOn]}>
                          {t === 'expense' ? 'Bill' : 'Income'}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>

                <Text style={styles.fieldLabel}>Name</Text>
                <TextInput
                  style={styles.input}
                  value={form?.label}
                  onChangeText={(t) => setForm((f) => ({ ...f, label: t }))}
                  placeholder={form?.type === 'income' ? 'e.g. Salary' : 'e.g. Rent, Netflix, Internet'}
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
                <Text style={styles.fieldLabel}>Day of the month</Text>
                <TextInput
                  style={styles.input}
                  value={form?.dayOfMonth}
                  onChangeText={(t) => setForm((f) => ({ ...f, dayOfMonth: t }))}
                  placeholder="e.g. 15"
                  placeholderTextColor={colors.faint}
                  keyboardType="numeric"
                />

                {data.accounts.length > 0 ? (
                  <>
                    <Text style={styles.fieldLabel}>
                      {form?.type === 'income' ? 'Into which account?' : 'From which account?'}
                    </Text>
                    <View style={styles.chips}>
                      <Pressable
                        onPress={() => setForm((f) => ({ ...f, accountId: '' }))}
                        style={[styles.chip, !form?.accountId && styles.chipOn]}
                      >
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
                  {form?.id ? (
                    <Pressable onPress={del} style={[styles.sheetBtn, styles.deleteBtn]}>
                      <Text style={styles.deleteText}>{confirmDel ? 'Tap to confirm' : 'Delete'}</Text>
                    </Pressable>
                  ) : (
                    <View />
                  )}
                  <View style={styles.sheetRight}>
                    <Pressable onPress={() => setForm(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                      <Text style={styles.cancelText}>Cancel</Text>
                    </Pressable>
                    <Pressable onPress={save} style={[styles.sheetBtn, styles.saveBtn]}>
                      <Text style={styles.saveText}>Save</Text>
                    </Pressable>
                  </View>
                </View>
              </ScrollView>
            )}
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
    add: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    totalCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    total: { color: colors.text, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: spacing.xs },
    totalIn: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },
    hint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md, flexDirection: 'row', alignItems: 'center' },
    pressed: { opacity: 0.6 },
    itemName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    itemSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    itemAmount: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    limitNote: { color: colors.faint, fontSize: fontSize.small, textAlign: 'center', marginTop: spacing.md },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    wallText: { color: colors.textSecondary, fontSize: fontSize.body, lineHeight: 22 },

    typeRow: { flexDirection: 'row', gap: spacing.sm },
    typeBtn: { flex: 1, paddingVertical: spacing.sm + 2, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, alignItems: 'center' },
    typeOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    typeText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    typeTextOn: { color: colors.onPrimary },

    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: { paddingVertical: spacing.sm, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.medium },

    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.xl },
    sheetRight: { flexDirection: 'row', gap: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    deleteBtn: { backgroundColor: 'transparent' },
    deleteText: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
