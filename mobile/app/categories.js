// Categories: manage the spending categories and, for Pro, a monthly cap
// per category. Categories keep labels consistent (chips in the entry
// sheet), and caps turn the budget from one big number into per area
// guardrails, the thing people actually overspend on is one category,
// not everything at once.

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
import { formatMoney, isThisMonth } from '../lib/format';

export default function Categories() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem, updateSettings } = useAppData();

  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);

  const list = data.categories || [];
  const pro = !!data.settings.pro;

  // This month's spending per category: tagged entries count by id, and
  // untagged entries count by matching label, so history still shows up.
  const spentFor = (c) =>
    (data.transactions || [])
      .filter(
        (t) =>
          t.type === 'expense' &&
          isThisMonth(t.date) &&
          (t.categoryId === c.id || (!t.categoryId && t.label === c.name))
      )
      .reduce((s, t) => s + (Number(t.amount) || 0), 0);

  function openAdd() {
    setForm({ id: null, name: '', icon: '', cap: '' });
    setErr('');
    setConfirmDel(false);
  }
  function openEdit(c) {
    setForm({ id: c.id, name: String(c.name || ''), icon: String(c.icon || ''), cap: c.monthlyCap ? String(c.monthlyCap) : '' });
    setErr('');
    setConfirmDel(false);
  }
  function save() {
    const name = form.name.trim();
    if (!name) {
      setErr('Give the category a name.');
      return;
    }
    const dup = list.some((c) => c.id !== form.id && c.name.trim().toLowerCase() === name.toLowerCase());
    if (dup) {
      setErr('That category already exists.');
      return;
    }
    const capText = String(form.cap || '').trim().replace(/[, ]/g, '');
    const cap = capText === '' ? 0 : Number(capText);
    if (capText !== '' && (!Number.isFinite(cap) || cap < 0)) {
      setErr('Enter a valid monthly cap, or leave it empty.');
      return;
    }
    if (cap > 0 && !pro) {
      setErr('Monthly caps are a Pro feature. Unlock Pro below, free during early access.');
      return;
    }
    const payload = { name, icon: form.icon.trim() || '🏷️', monthlyCap: cap };
    if (form.id) updateItem('categories', form.id, payload);
    else addItem('categories', payload);
    setForm(null);
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    // Entries keep their categoryId; readers fall back to the label, so
    // nothing crashes and history stays intact.
    if (form.id) removeItem('categories', form.id);
    setForm(null);
  }

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
        <Text style={styles.headerTitle}>Categories</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.intro}>
          Categories keep your entries consistent. Pro adds a monthly cap per category, so Food
          can have its own limit before the whole budget blows.
        </Text>

        <View style={styles.card}>
          {list.map((c, i) => {
            const spent = spentFor(c);
            const over = c.monthlyCap > 0 && spent > c.monthlyCap;
            return (
              <Pressable
                key={c.id}
                onPress={() => openEdit(c)}
                style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}
              >
                <Text style={styles.rowIcon}>{c.icon}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.rowName}>{c.name}</Text>
                  <Text style={[styles.rowSub, over && { color: colors.warning }]}>
                    {formatMoney(spent)} this month
                    {c.monthlyCap > 0 ? ` of ${formatMoney(c.monthlyCap)} cap` : ''}
                    {over ? '. Over the cap.' : ''}
                  </Text>
                  {c.monthlyCap > 0 ? (
                    <View style={styles.track}>
                      <View
                        style={[
                          styles.fill,
                          {
                            width: `${Math.min(Math.round((spent / c.monthlyCap) * 100), 100)}%`,
                            backgroundColor: over ? colors.warning : colors.primary,
                          },
                        ]}
                      />
                    </View>
                  ) : null}
                </View>
                <Ionicons name="chevron-forward" size={18} color={colors.faint} />
              </Pressable>
            );
          })}
        </View>

        {!pro ? (
          <Pressable
            onPress={() => updateSettings({ pro: true })}
            style={({ pressed }) => [styles.proCard, pressed && styles.pressed]}
          >
            <Text style={styles.proTitle}>Unlock per category caps</Text>
            <Text style={styles.proBody}>
              Pro will be a one time purchase at launch. Early users unlock it free today and
              keep it. Tap to unlock.
            </Text>
          </Pressable>
        ) : null}
      </ScrollView>

      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>{form?.id ? 'Edit' : 'Add'} category</Text>

            <Text style={styles.fieldLabel}>Name</Text>
            <TextInput style={styles.input} value={form?.name} onChangeText={(t) => setForm((f) => ({ ...f, name: t }))} placeholder="e.g. Coffee" placeholderTextColor={colors.faint} />
            <Text style={styles.fieldLabel}>Emoji icon</Text>
            <TextInput style={styles.input} value={form?.icon} onChangeText={(t) => setForm((f) => ({ ...f, icon: t }))} placeholder="☕" placeholderTextColor={colors.faint} />
            <Text style={styles.fieldLabel}>Monthly cap (Pro, optional)</Text>
            <TextInput style={styles.input} value={form?.cap} onChangeText={(t) => setForm((f) => ({ ...f, cap: t }))} placeholder="e.g. 3000, empty for none" placeholderTextColor={colors.faint} keyboardType="numeric" />

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
    intro: { color: colors.muted, fontSize: fontSize.small, lineHeight: 20, marginBottom: spacing.lg },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, gap: spacing.md },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowIcon: { fontSize: 26 },
    rowName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    track: { height: 6, borderRadius: radius.pill, backgroundColor: colors.border, overflow: 'hidden', marginTop: spacing.xs, maxWidth: 240 },
    fill: { height: '100%', borderRadius: radius.pill },

    proCard: { backgroundColor: colors.positiveSurface, borderColor: colors.positiveBorder, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginTop: spacing.lg },
    proTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    proBody: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs, lineHeight: 20 },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
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
