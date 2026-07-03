// Goals screen. Savings goals with progress bars. Reached from the More tab.
// You can add and edit goals, add money to a goal, and delete one. Saved data.

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

export default function Goals() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem } = useAppData();

  const [form, setForm] = useState(null);
  const [addFunds, setAddFunds] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);

  function openAdd() {
    setForm({ id: null, name: '', target: '', saved: '', targetDate: '' });
    setAddFunds('');
    setConfirmDel(false);
  }
  function openEdit(g) {
    setForm({ id: g.id, name: g.name, target: String(g.target), saved: String(g.saved), targetDate: g.targetDate || '' });
    setAddFunds('');
    setConfirmDel(false);
  }
  function save() {
    const payload = {
      name: form.name.trim() || 'Goal',
      target: Math.max(0, Number(form.target) || 0),
      saved: Math.max(0, Number(form.saved) || 0),
      targetDate: form.targetDate.trim(),
    };
    if (form.id) updateItem('goals', form.id, payload);
    else addItem('goals', payload);
    setForm(null);
  }
  function applyFunds() {
    const amt = Number(addFunds) || 0;
    if (!form.id || amt === 0) return;
    const newSaved = Math.max(0, (Number(form.saved) || 0) + amt);
    updateItem('goals', form.id, { saved: newSaved });
    setForm((f) => ({ ...f, saved: String(newSaved) }));
    setAddFunds('');
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) removeItem('goals', form.id);
    setForm(null);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Goals</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {data.goals.length === 0 ? (
          <EmptyState icon="🎯" title="No goals yet" subtitle="Tap + Add to set your first savings goal." />
        ) : (
          data.goals.map((g) => {
            const pct = g.target ? Math.min(Math.round((g.saved / g.target) * 100), 100) : 0;
            return (
              <Pressable
                key={g.id}
                onPress={() => openEdit(g)}
                style={({ pressed }) => [styles.card, pressed && styles.pressed]}
              >
                <View style={styles.cardTop}>
                  <Text style={styles.goalName}>{g.name}</Text>
                  <Text style={styles.goalPct}>{pct}%</Text>
                </View>
                <View style={styles.track}>
                  <View style={[styles.fill, { width: `${pct}%` }]} />
                </View>
                <Text style={styles.goalSub}>
                  {formatMoney(g.saved)} of {formatMoney(g.target)}
                  {g.targetDate ? ` . by ${g.targetDate}` : ''}
                </Text>
              </Pressable>
            );
          })
        )}
      </ScrollView>

      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView>
              <Text style={styles.sheetTitle}>{form?.id ? 'Edit goal' : 'Add goal'}</Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput style={styles.input} value={form?.name} onChangeText={(t) => setForm((f) => ({ ...f, name: t }))} placeholder="e.g. Emergency fund" placeholderTextColor={colors.faint} />
              <Text style={styles.fieldLabel}>Target amount</Text>
              <TextInput style={styles.input} value={form?.target} onChangeText={(t) => setForm((f) => ({ ...f, target: t }))} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
              <Text style={styles.fieldLabel}>Saved so far</Text>
              <TextInput style={styles.input} value={form?.saved} onChangeText={(t) => setForm((f) => ({ ...f, saved: t }))} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
              <Text style={styles.fieldLabel}>Target date (optional)</Text>
              <TextInput style={styles.input} value={form?.targetDate} onChangeText={(t) => setForm((f) => ({ ...f, targetDate: t }))} placeholder="e.g. 2026-12-31" placeholderTextColor={colors.faint} />

              {form?.id ? (
                <View style={styles.payBox}>
                  <Text style={styles.fieldLabel}>Add to savings</Text>
                  <View style={styles.payRow}>
                    <TextInput style={[styles.input, styles.payInput]} value={addFunds} onChangeText={setAddFunds} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
                    <Pressable onPress={applyFunds} style={[styles.sheetBtn, styles.saveBtn]}>
                      <Text style={styles.saveText}>Add</Text>
                    </Pressable>
                  </View>
                </View>
              ) : null}

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

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    pressed: { opacity: 0.7 },
    cardTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.md },
    goalName: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    goalPct: { color: colors.softGreen, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    track: { height: 10, borderRadius: radius.pill, backgroundColor: colors.border, overflow: 'hidden' },
    fill: { height: '100%', borderRadius: radius.pill, backgroundColor: colors.primary },
    goalSub: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    payBox: { marginTop: spacing.lg, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: spacing.sm },
    payRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center' },
    payInput: { flex: 1 },
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
