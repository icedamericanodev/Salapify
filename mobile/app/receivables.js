// People who owe me (receivables). Track who owes you, how much, and when it
// is due. One-tap "Remind" opens your messaging apps with a polite message
// ready to send. Mark paid, edit, delete. All saved on the device.

import { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Switch,
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
import EmptyState from '../components/EmptyState';

// Quick due date choices, so nobody has to type a date by hand. Next sweldo
// is the 15th or the end of the month, whichever comes first.
function quickDates() {
  const now = new Date();
  const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  let payday;
  if (now.getDate() < 15) payday = new Date(now.getFullYear(), now.getMonth(), 15);
  else if (now.getDate() < lastDay) payday = new Date(now.getFullYear(), now.getMonth(), lastDay);
  else payday = new Date(now.getFullYear(), now.getMonth() + 1, 15);
  const in1w = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7);
  const in2w = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 14);
  return [
    { label: 'Next sweldo', value: todayISO(payday) },
    { label: 'In 1 week', value: todayISO(in1w) },
    { label: 'In 2 weeks', value: todayISO(in2w) },
    { label: 'No due date', value: '' },
  ];
}

export default function Receivables() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem } = useAppData();

  const [form, setForm] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);
  const [err, setErr] = useState('');

  const list = data.receivables || [];
  const owedTotal = list.filter((r) => !r.paid).reduce((t, r) => t + r.amount, 0);

  function openAdd() {
    setForm({ id: null, person: '', amount: '', dueDate: '', phone: '', note: '', paid: false });
    setErr('');
    setConfirmDel(false);
  }
  function openEdit(r) {
    setForm({
      id: r.id,
      person: r.person,
      amount: String(r.amount),
      dueDate: r.dueDate || '',
      phone: r.phone || '',
      note: r.note || '',
      paid: !!r.paid,
    });
    setErr('');
    setConfirmDel(false);
  }
  function save() {
    if (!form.person.trim()) {
      setErr('Please enter a name.');
      return;
    }
    const amount = Number(form.amount);
    if (form.amount === '' || !Number.isFinite(amount) || amount < 0) {
      setErr('Enter a valid amount.');
      return;
    }
    const dd = form.dueDate.trim();
    if (dd && !/^\d{4}-\d{2}-\d{2}$/.test(dd)) {
      setErr('Tap a quick date above, or type it like 2026-07-15.');
      return;
    }
    const payload = {
      person: form.person.trim(),
      amount,
      dueDate: form.dueDate.trim(),
      phone: form.phone.trim(),
      note: form.note.trim(),
      paid: form.paid,
    };
    if (form.id) updateItem('receivables', form.id, payload);
    else addItem('receivables', payload);
    setForm(null);
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) removeItem('receivables', form.id);
    setForm(null);
  }

  // Opens the share sheet (SMS, WhatsApp, Messenger, email...) with a polite
  // reminder already written. You choose the app and tap send.
  function remind(r) {
    const due = r.dueDate ? `, due ${r.dueDate}` : '';
    const message = `Hi ${r.person}, friendly reminder about ${formatMoney(r.amount)} you owe me${due}. Thank you! (sent via Salapify)`;
    Share.share({ message }).catch(() => {});
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>People who owe me</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.totalCard}>
          <Text style={styles.kicker}>TOTAL OWED TO YOU</Text>
          <Text style={styles.total}>{formatMoney(owedTotal)}</Text>
        </View>

        {list.length === 0 ? (
          <EmptyState icon="🤝" title="No one owes you" subtitle="Tap + Add to track money owed to you." />
        ) : (
          list.map((r) => (
            <View key={r.id} style={[styles.card, r.paid && styles.cardPaid]}>
              <Pressable onPress={() => openEdit(r)} style={styles.cardMain}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.person}>
                    {r.person} {r.paid ? <Text style={styles.paidTag}>· paid</Text> : null}
                  </Text>
                  <Text style={styles.sub}>
                    {r.dueDate ? `Due ${r.dueDate}` : 'No due date'}
                    {r.note ? ` · ${r.note}` : ''}
                  </Text>
                </View>
                <Text style={[styles.amount, r.paid && styles.amountPaid]}>{formatMoney(r.amount)}</Text>
              </Pressable>
              {!r.paid ? (
                <View style={styles.actions}>
                  <Pressable onPress={() => remind(r)} style={({ pressed }) => [styles.remindBtn, pressed && styles.pressed]}>
                    <Ionicons name="paper-plane-outline" size={15} color={colors.primary} />
                    <Text style={styles.remindText}>Remind</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => updateItem('receivables', r.id, { paid: true })}
                    style={({ pressed }) => [styles.paidBtn, pressed && styles.pressed]}
                  >
                    <Text style={styles.paidBtnText}>Mark paid</Text>
                  </Pressable>
                </View>
              ) : null}
            </View>
          ))
        )}
      </ScrollView>

      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView>
              <Text style={styles.sheetTitle}>{form?.id ? 'Edit' : 'Add'} person</Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput style={styles.input} value={form?.person} onChangeText={(t) => setForm((f) => ({ ...f, person: t }))} placeholder="e.g. Juan" placeholderTextColor={colors.faint} />
              <Text style={styles.fieldLabel}>Amount owed</Text>
              <TextInput style={styles.input} value={form?.amount} onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
              <Text style={styles.fieldLabel}>Due date (optional)</Text>
              <View style={styles.chips}>
                {quickDates().map((q) => {
                  const on = form?.dueDate === q.value;
                  return (
                    <Pressable key={q.label} onPress={() => setForm((f) => ({ ...f, dueDate: q.value }))} style={[styles.chip, on && styles.chipOn]}>
                      <Text style={[styles.chipText, on && styles.chipTextOn]}>{q.label}</Text>
                    </Pressable>
                  );
                })}
              </View>
              <TextInput style={styles.input} value={form?.dueDate} onChangeText={(t) => setForm((f) => ({ ...f, dueDate: t }))} placeholder="or type it, like 2026-07-15" placeholderTextColor={colors.faint} />
              <Text style={styles.fieldLabel}>Note (optional)</Text>
              <TextInput style={styles.input} value={form?.note} onChangeText={(t) => setForm((f) => ({ ...f, note: t }))} placeholder="e.g. Lunch" placeholderTextColor={colors.faint} />

              <View style={styles.paidRow}>
                <Text style={styles.rowLabel}>Marked as paid</Text>
                <Switch
                  value={form?.paid}
                  onValueChange={(v) => setForm((f) => ({ ...f, paid: v }))}
                  trackColor={{ true: colors.primary, false: colors.border }}
                />
              </View>

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
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 2 },
    total: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    cardPaid: { opacity: 0.6 },
    cardMain: { flexDirection: 'row', alignItems: 'center' },
    person: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    paidTag: { color: colors.muted, fontWeight: fontWeight.regular, fontSize: fontSize.small },
    sub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    amount: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    amountPaid: { color: colors.muted },
    actions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.md },
    pressed: { opacity: 0.6 },
    remindBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.sm, paddingHorizontal: spacing.md },
    remindText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    paidBtn: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, paddingVertical: spacing.sm, paddingHorizontal: spacing.md },
    paidBtnText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    chipTextOn: { color: '#FFFFFF' },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    paidRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.lg },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.xl },
    sheetRight: { flexDirection: 'row', gap: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    deleteBtn: { backgroundColor: 'transparent' },
    deleteText: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
