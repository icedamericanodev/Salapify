// Earn your treats. Temptation bundling: pair a small treat with a healthy
// action you define, tap a check-in when you do it, and the treat is earned
// once enough recent check-ins land. It never blocks a purchase and never
// counts your pesos. State lives in settings.treats. Reached from Overview and
// the More tab. The create and edit form is inline, not a modal, so the
// keyboard never hides it under edge to edge.

import { useMemo, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { treatStatus, toggleCheckIn, newTreat, TREAT_TEMPLATES } from '../lib/treats';

const MAX_TREATS = 3;

export default function Treats() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateSettings } = useAppData();

  const treats = Array.isArray(data.settings && data.settings.treats) ? data.settings.treats : [];
  const [form, setForm] = useState(null); // { id, treat, action, emoji, target, windowDays }
  const [confirmDel, setConfirmDel] = useState(null);
  const [capNote, setCapNote] = useState(false);
  // Guards a double tap on Save from appending the same new treat twice
  // before the form state clears on the next render.
  const saving = useRef(false);

  const openNew = (tpl) => {
    setConfirmDel(null);
    setCapNote(false);
    setForm({
      id: null,
      treat: tpl ? tpl.treat : '',
      action: tpl ? tpl.action : '',
      emoji: tpl ? tpl.emoji : '☕',
      target: String(tpl ? tpl.target : 3),
      windowDays: tpl ? tpl.windowDays : 7,
    });
  };
  const openEdit = (t) => {
    setConfirmDel(null);
    setCapNote(false);
    setForm({ id: t.id, treat: t.treat, action: t.action, emoji: t.emoji || '☕', target: String(t.target), windowDays: t.windowDays });
  };
  const closeForm = () => { setForm(null); setCapNote(false); };

  const save = () => {
    if (!form || saving.current) return;
    // A new treat past the cap keeps the form open with a note, so the
    // user's typed text is never silently thrown away.
    if (!form.id && treats.length >= MAX_TREATS) {
      setCapNote(true);
      return;
    }
    saving.current = true;
    const fields = {
      treat: form.treat,
      action: form.action,
      emoji: form.emoji,
      target: Number(String(form.target).replace(/[^\d]/g, '')) || 3,
      windowDays: form.windowDays,
    };
    if (form.id) {
      updateSettings((s) => ({
        treats: (Array.isArray(s.treats) ? s.treats : []).map((t) =>
          t.id === form.id ? { ...t, treat: fields.treat.trim() || t.treat, action: fields.action.trim() || t.action, emoji: fields.emoji, target: Math.min(Math.max(fields.target, 1), 14), windowDays: fields.windowDays } : t
        ),
      }));
    } else {
      updateSettings((s) => {
        const cur = Array.isArray(s.treats) ? s.treats : [];
        if (cur.length >= MAX_TREATS) return {};
        return { treats: [...cur, newTreat(fields)] };
      });
    }
    setForm(null);
    setCapNote(false);
    saving.current = false;
  };

  const del = (id) => {
    updateSettings((s) => ({ treats: (Array.isArray(s.treats) ? s.treats : []).filter((t) => t.id !== id) }));
    setConfirmDel(null);
    setForm(null);
  };

  const onToggle = (id) => {
    updateSettings((s) => ({
      treats: (Array.isArray(s.treats) ? s.treats : []).map((t) => (t.id === id ? toggleCheckIn(t) : t)),
    }));
  };

  const setField = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Earn your treats</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          Pair a small treat with something healthy. Do the healthy thing, tap one check-in, and the treat is yours guilt free.
        </Text>

        {treats.map((t) => {
          const st = treatStatus(t);
          return (
            <View key={t.id} style={[styles.card, st.earned && styles.cardEarned]}>
              <View style={styles.cardHead}>
                <Text style={styles.cardEmoji}>{st.emoji}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.cardTreat}>{t.treat}</Text>
                  <Text style={styles.cardAction}>{t.action}</Text>
                </View>
                {st.earned ? <Text style={styles.earnedTag}>EARNED</Text> : null}
              </View>

              <View style={styles.dotsRow}>
                {Array.from({ length: st.target }).map((_, i) => (
                  <View key={i} style={[styles.dot, i < st.recent && styles.dotOn]} />
                ))}
              </View>
              <Text style={styles.progressLine}>
                {st.earned
                  ? `Earned. Enjoy your ${t.treat.toLowerCase()}, you paid for it in ${t.action.toLowerCase()}, not regret.`
                  : st.recent === 0
                  ? `Do your ${t.action.toLowerCase()}, then tap below. ${st.target} check ins earns it.`
                  : `${st.recent} of ${st.target} self care check ins. ${st.remaining} more and it is yours.`}
              </Text>

              <Pressable onPress={() => onToggle(t.id)} style={({ pressed }) => [styles.checkBtn, st.doneToday && styles.checkBtnDone, pressed && styles.pressed]}>
                <Ionicons name={st.doneToday ? 'checkmark-circle' : 'ellipse-outline'} size={18} color={st.doneToday ? colors.background : colors.primary} />
                <Text style={[styles.checkBtnText, st.doneToday && styles.checkBtnTextDone]}>
                  {st.doneToday ? 'Done for today, tap to undo' : 'I did it today'}
                </Text>
              </Pressable>

              <View style={styles.cardFooter}>
                <Text style={styles.lifetime}>{st.lifetime} self care check ins in total</Text>
                <View style={styles.footerBtns}>
                  <Pressable onPress={() => openEdit(t)} hitSlop={8}><Text style={styles.linkBtn}>Edit</Text></Pressable>
                  {confirmDel === t.id ? (
                    <Pressable onPress={() => del(t.id)} hitSlop={8}><Text style={styles.delConfirm}>Tap to confirm</Text></Pressable>
                  ) : (
                    <Pressable onPress={() => setConfirmDel(t.id)} hitSlop={8}><Text style={styles.linkBtn}>Delete</Text></Pressable>
                  )}
                </View>
              </View>
            </View>
          );
        })}

        {/* The create / edit form, inline. */}
        {form ? (
          <View style={styles.formCard}>
            <Text style={styles.formTitle}>{form.id ? 'Edit treat' : 'New treat'}</Text>

            <Text style={styles.label}>Treat</Text>
            <TextInput style={styles.input} value={form.treat} onChangeText={(v) => setField('treat', v)} placeholder="e.g. milk tea" placeholderTextColor={colors.faint} />

            <Text style={styles.label}>Healthy action</Text>
            <TextInput style={styles.input} value={form.action} onChangeText={(v) => setField('action', v)} placeholder="e.g. 30-minutong lakad" placeholderTextColor={colors.faint} />

            <Text style={styles.label}>Emoji</Text>
            <TextInput style={[styles.input, styles.emojiInput]} value={form.emoji} onChangeText={(v) => setField('emoji', [...v].slice(0, 1).join('') || '')} placeholder="☕" placeholderTextColor={colors.faint} />

            <Text style={styles.label}>Check-ins to earn it</Text>
            <View style={styles.stepperRow}>
              <Pressable onPress={() => setField('target', String(Math.max(1, (Number(form.target) || 3) - 1)))} style={styles.stepBtn}><Text style={styles.stepBtnText}>-</Text></Pressable>
              <Text style={styles.stepValue}>{Number(form.target) || 3}</Text>
              <Pressable onPress={() => setField('target', String(Math.min(14, (Number(form.target) || 3) + 1)))} style={styles.stepBtn}><Text style={styles.stepBtnText}>+</Text></Pressable>
            </View>

            <Text style={styles.label}>Within</Text>
            <View style={styles.segment}>
              <Pressable style={[styles.segBtn, form.windowDays === 7 && styles.segBtnOn]} onPress={() => setField('windowDays', 7)}>
                <Text style={[styles.segText, form.windowDays === 7 && styles.segTextOn]}>This week</Text>
              </Pressable>
              <Pressable style={[styles.segBtn, form.windowDays === 14 && styles.segBtnOn]} onPress={() => setField('windowDays', 14)}>
                <Text style={[styles.segText, form.windowDays === 14 && styles.segTextOn]}>Two weeks</Text>
              </Pressable>
            </View>

            {capNote ? (
              <Text style={styles.capNote}>You can keep 3 treats at a time. Delete one to add another.</Text>
            ) : null}

            <View style={styles.formBtns}>
              <Pressable onPress={closeForm} style={({ pressed }) => [styles.secondaryBtn, pressed && styles.pressed]}><Text style={styles.secondaryText}>Cancel</Text></Pressable>
              <Pressable onPress={save} style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]}><Text style={styles.primaryText}>Save</Text></Pressable>
            </View>
          </View>
        ) : treats.length === 0 ? (
          <>
            <Text style={styles.templatesKicker}>PICK ONE TO START</Text>
            {TREAT_TEMPLATES.map((tpl) => (
              <Pressable key={tpl.treat} onPress={() => openNew(tpl)} style={({ pressed }) => [styles.templateCard, pressed && styles.pressed]}>
                <Text style={styles.cardEmoji}>{tpl.emoji}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.cardTreat}>{tpl.treat}</Text>
                  <Text style={styles.cardAction}>{tpl.target} x {tpl.action}</Text>
                </View>
                <Ionicons name="add-circle-outline" size={22} color={colors.primary} />
              </Pressable>
            ))}
            <Pressable onPress={() => openNew(null)} style={({ pressed }) => [styles.secondaryBtn, { marginTop: spacing.md }, pressed && styles.pressed]}>
              <Text style={styles.secondaryText}>Make my own</Text>
            </Pressable>
          </>
        ) : treats.length < MAX_TREATS ? (
          <Pressable onPress={() => openNew(null)} style={({ pressed }) => [styles.secondaryBtn, pressed && styles.pressed]}>
            <Text style={styles.secondaryText}>Add another treat</Text>
          </Pressable>
        ) : null}

        <Text style={styles.honestNote}>
          This tracks a habit, not your wallet. It never blocks a purchase and never counts your pesos.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    intro: { color: colors.muted, fontSize: fontSize.small, lineHeight: 19, marginBottom: spacing.lg },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    cardEarned: { borderColor: colors.celebrate || colors.primary },
    cardHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    cardEmoji: { fontSize: 26 },
    cardTreat: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    cardAction: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    earnedTag: { color: colors.celebrate || colors.primary, fontSize: 10, fontWeight: fontWeight.bold, letterSpacing: 1, borderColor: colors.celebrate || colors.primary, borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 6, paddingVertical: 1 },

    dotsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.md },
    dot: { width: 16, height: 16, borderRadius: 8, borderWidth: 1.5, borderColor: colors.border },
    dotOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    progressLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.md },

    checkBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.pill, paddingVertical: spacing.md, marginTop: spacing.md },
    checkBtnDone: { backgroundColor: colors.primary },
    checkBtnText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    checkBtnTextDone: { color: colors.background },

    cardFooter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: spacing.md },
    lifetime: { color: colors.faint, fontSize: fontSize.caption, flexShrink: 1, paddingRight: spacing.md },
    footerBtns: { flexDirection: 'row', gap: spacing.lg },
    linkBtn: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    delConfirm: { color: colors.warning || colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },

    templatesKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    templateCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },

    formCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    formTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    label: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.md, marginBottom: spacing.xs, letterSpacing: 0.3 },
    input: { backgroundColor: colors.background, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    emojiInput: { width: 72, textAlign: 'center', fontSize: fontSize.title },
    stepperRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.lg },
    stepBtn: { width: 40, height: 40, borderRadius: radius.md, borderColor: colors.border, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
    stepBtnText: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold },
    stepValue: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy, minWidth: 28, textAlign: 'center' },
    segment: { flexDirection: 'row', backgroundColor: colors.background, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: 3 },
    segBtn: { flex: 1, paddingVertical: spacing.sm, alignItems: 'center', borderRadius: radius.sm },
    segBtnOn: { backgroundColor: colors.primary },
    segText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    segTextOn: { color: colors.background, fontWeight: fontWeight.bold },
    capNote: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.md },
    formBtns: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.lg },

    primaryBtn: { flex: 1, backgroundColor: colors.primary, borderRadius: radius.pill, paddingVertical: spacing.md, alignItems: 'center' },
    primaryText: { color: colors.background, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    secondaryBtn: { flex: 1, borderColor: colors.border, borderWidth: 1, borderRadius: radius.pill, paddingVertical: spacing.md, alignItems: 'center' },
    secondaryText: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    pressed: { opacity: 0.7 },

    honestNote: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl, textAlign: 'center' },
  });
}
