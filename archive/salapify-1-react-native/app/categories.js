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
import { categoryTree } from '../lib/categories';

export default function Categories() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, updateSettings, deleteCategory } = useAppData();

  const [form, setForm] = useState(null);
  const [err, setErr] = useState('');
  // The delete flow: null when closed, otherwise { cat, used, choosing } where
  // cat is the category being deleted, used is how many entries are tagged with
  // it, and choosing is true while the user picks a category to move them to.
  const [del, setDel] = useState(null);

  const list = data.categories || [];
  const pro = !!data.settings.pro;

  // This month's spending per category: tagged entries count by id, and
  // entries whose tag no longer exists (deleted category) or that were
  // never tagged fall back to label matching, so history keeps counting.
  const validIds = new Set(list.map((c) => c.id));
  const spentFor = (c) =>
    (data.transactions || [])
      .filter(
        (t) =>
          t.type === 'expense' &&
          isThisMonth(t.date) &&
          (t.categoryId === c.id ||
            ((!t.categoryId || !validIds.has(t.categoryId)) && t.label === c.name))
      )
      .reduce((s, t) => s + (Number(t.amount) || 0), 0);

  function openAdd() {
    setForm({ id: null, name: '', icon: '', cap: '', parentId: '' });
    setErr('');
    setDel(null);
  }
  function openEdit(c) {
    setForm({ id: c.id, name: String(c.name || ''), icon: String(c.icon || ''), cap: c.monthlyCap ? String(c.monthlyCap) : '', parentId: c.parentId || '' });
    setErr('');
    setDel(null);
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
    // parentId set to undefined (not omitted) when top level, so editing a
    // subcategory back to top level actually clears the old parent through the
    // updateItem merge instead of leaving it stuck.
    const payload = { name, icon: form.icon.trim() || '🏷️', monthlyCap: cap, parentId: form.parentId || undefined };
    if (form.id) updateItem('categories', form.id, payload);
    else addItem('categories', payload);
    setForm(null);
  }
  // Start deleting: count how many entries are tagged with this category, then
  // open the delete sheet. The edit form closes so the two sheets never stack.
  function startDelete() {
    if (!form.id) return;
    const cat = { id: form.id, name: form.name.trim() || 'Category' };
    const used = (data.transactions || []).filter((t) => t && t.categoryId === cat.id).length;
    setForm(null);
    setDel({ cat, used, choosing: false });
  }
  // Finish the delete: move tagged entries to toId (or clear the tag when toId is
  // null so they become uncategorized), then remove the category.
  function finishDelete(toId) {
    if (!del) return;
    // One atomic store move: reassign or clear tagged entries, promote any
    // children to top level, and remove the category.
    deleteCategory(del.cat.id, del.used > 0 ? toId || null : null);
    setDel(null);
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
          {categoryTree(list).map(({ cat: c, depth }, i) => {
            const spent = spentFor(c);
            const over = c.monthlyCap > 0 && spent > c.monthlyCap;
            return (
              <Pressable
                key={c.id}
                onPress={() => openEdit(c)}
                style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, depth === 1 && styles.childRow, pressed && styles.pressed]}
              >
                {depth === 1 ? <Text style={styles.childMark}>↳</Text> : null}
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

            {/* Parent: a category can sit under one top level category (two levels
                max). A category that already has its own subcategories must stay
                top level, so the picker is hidden for it. */}
            {form && list.some((c) => c.parentId === form.id) ? (
              <Text style={styles.fieldHint}>This has subcategories, so it stays a top level category.</Text>
            ) : (
              <>
                <Text style={styles.fieldLabel}>Parent category (optional)</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.parentRow}>
                  <Pressable onPress={() => setForm((f) => ({ ...f, parentId: '' }))} style={[styles.chip, !form?.parentId && styles.chipOn]}>
                    <Text style={[styles.chipText, !form?.parentId && styles.chipTextOn]}>Top level</Text>
                  </Pressable>
                  {list
                    .filter((c) => c.id !== form?.id && !c.parentId)
                    .map((c) => {
                      const on = form?.parentId === c.id;
                      return (
                        <Pressable key={c.id} onPress={() => setForm((f) => ({ ...f, parentId: c.id }))} style={[styles.chip, on && styles.chipOn]}>
                          <Text style={[styles.chipText, on && styles.chipTextOn]}>{c.icon} {c.name}</Text>
                        </Pressable>
                      );
                    })}
                </ScrollView>
              </>
            )}

            {err ? <Text style={styles.err}>{err}</Text> : null}
            <View style={styles.sheetButtons}>
              {form?.id ? (
                <Pressable onPress={startDelete} style={[styles.sheetBtn, styles.deleteBtn]}>
                  <Text style={styles.deleteText}>Delete</Text>
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

      {/* Delete flow: choose what happens to this category's entries. */}
      <Modal visible={!!del} transparent animationType="slide" onRequestClose={() => setDel(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            {del && del.choosing ? (
              <>
                <Text style={styles.sheetTitle}>Move entries to</Text>
                <Text style={styles.delBody}>Pick where the {del.used} {del.used === 1 ? 'entry' : 'entries'} in {del.cat.name} should go.</Text>
                <ScrollView style={{ maxHeight: 320 }}>
                  {list
                    .filter((c) => c.id !== del.cat.id)
                    .map((c) => (
                      <Pressable key={c.id} onPress={() => finishDelete(c.id)} style={({ pressed }) => [styles.delRow, pressed && styles.pressed]}>
                        <Text style={styles.rowIcon}>{c.icon || '🏷️'}</Text>
                        <Text style={styles.rowName}>{c.name}</Text>
                      </Pressable>
                    ))}
                  {list.filter((c) => c.id !== del.cat.id).length === 0 ? (
                    <Text style={styles.delBody}>No other category to move to. Go back and leave them uncategorized instead.</Text>
                  ) : null}
                </ScrollView>
                <View style={styles.sheetButtons}>
                  <View />
                  <Pressable onPress={() => setDel((d) => ({ ...d, choosing: false }))} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Back</Text>
                  </Pressable>
                </View>
              </>
            ) : del ? (
              <>
                <Text style={styles.sheetTitle}>Delete {del.cat.name}?</Text>
                {del.used > 0 ? (
                  <Text style={styles.delBody}>
                    {del.used} {del.used === 1 ? 'entry uses' : 'entries use'} this category. Choose what happens to {del.used === 1 ? 'it' : 'them'}. Your history and totals stay intact either way.
                  </Text>
                ) : list.some((c) => c.parentId === del.cat.id) ? (
                  <Text style={styles.delBody}>No entries use this category. Its subcategories will become top level categories.</Text>
                ) : (
                  <Text style={styles.delBody}>No entries use this category, so nothing else changes.</Text>
                )}
                {del.used > 0 ? (
                  <>
                    {list.some((c) => c.id !== del.cat.id) ? (
                      <Pressable onPress={() => setDel((d) => ({ ...d, choosing: true }))} style={({ pressed }) => [styles.delChoice, pressed && styles.pressed]}>
                        <Text style={styles.delChoiceTitle}>Move them to another category</Text>
                        <Text style={styles.delChoiceSub}>Keep them counted, just under a different name.</Text>
                      </Pressable>
                    ) : null}
                    <Pressable onPress={() => finishDelete(null)} style={({ pressed }) => [styles.delChoice, pressed && styles.pressed]}>
                      <Text style={styles.delChoiceTitle}>Leave them uncategorized</Text>
                      <Text style={styles.delChoiceSub}>They stay in your history without a category.</Text>
                    </Pressable>
                  </>
                ) : (
                  <Pressable onPress={() => finishDelete(null)} style={[styles.sheetBtn, styles.deleteBtnSolid]}>
                    <Text style={styles.saveText}>Delete</Text>
                  </Pressable>
                )}
                <View style={styles.sheetButtons}>
                  <View />
                  <Pressable onPress={() => setDel(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
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
    add: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    intro: { color: colors.muted, fontSize: fontSize.small, lineHeight: 20, marginBottom: spacing.lg },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, gap: spacing.md },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    childRow: { paddingLeft: spacing.lg },
    childMark: { color: colors.faint, fontSize: fontSize.body, marginRight: -spacing.xs },
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
    fieldHint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.md, lineHeight: 16 },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    parentRow: { flexDirection: 'row', gap: spacing.sm, paddingVertical: 2 },
    chip: { paddingVertical: spacing.xs, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },
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

    delBody: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 20, marginBottom: spacing.md },
    delChoice: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.lg, marginBottom: spacing.sm },
    delChoiceTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    delChoiceSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    delRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth },
    deleteBtnSolid: { backgroundColor: colors.warning, alignItems: 'center', marginTop: spacing.sm },
  });
}
