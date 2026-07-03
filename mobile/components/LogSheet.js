// LogSheet: the one global "add entry" sheet, opened from the floating add
// button on every tab and from Budget's + Custom. One place to log an
// expense or income from anywhere in the app, with the user's quick add
// buttons for one tap logging and a date row for backdating (Today,
// Yesterday, or any past date typed as YYYY-MM-DD). Forgetting to log for
// two days should never mean the history is wrong forever.
//
// It saves through the shared store and celebrates with the same toast and
// Undo as Budget, so logging feels identical wherever it starts.

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, todayISO } from '../lib/format';

const TOAST_EMOJI = ['✅', '⚡', '🔥', '💚', '✨'];
const TOAST_PRAISE = ['Nakalista na. Ang bilis mo.', 'Logged. Galing.', 'Ayan, updated ka na.'];

// True only for a text like "2026-07-03" that is a real calendar date.
function isRealDate(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s).trim());
  if (!m) return false;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const day = Number(m[3]);
  const d = new Date(y, mo - 1, day);
  return d.getFullYear() === y && d.getMonth() === mo - 1 && d.getDate() === day;
}

export default function LogSheet({ visible, onClose, toastBottom = spacing.lg }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, addItem, removeItem } = useAppData();

  const [type, setType] = useState('expense');
  const [label, setLabel] = useState('');
  const [amount, setAmount] = useState('');
  const [when, setWhen] = useState('today'); // 'today' | 'yesterday' | 'other'
  const [otherDate, setOtherDate] = useState('');
  const [err, setErr] = useState('');

  // Fresh form every time the sheet opens.
  useEffect(() => {
    if (visible) {
      setType('expense');
      setLabel('');
      setAmount('');
      setWhen('today');
      setOtherDate('');
      setErr('');
    }
  }, [visible]);

  // The toast lives outside the modal so it stays on screen after closing.
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);
  const toastAnim = useRef(new Animated.Value(0)).current;
  const toastCount = useRef(0);

  function celebrate(entryLabel, entryAmount, id) {
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    } catch (e) {
      // Haptics are not available on web. That is fine.
    }
    if (toastTimer.current) clearTimeout(toastTimer.current);
    const n = toastCount.current++;
    const emoji = TOAST_EMOJI[n % TOAST_EMOJI.length];
    const praise = TOAST_PRAISE[n % TOAST_PRAISE.length];
    setToast({ text: `${emoji} ${entryLabel} ${formatMoney(entryAmount)}. ${praise}`, id });
    toastAnim.setValue(0);
    Animated.spring(toastAnim, { toValue: 1, friction: 6, useNativeDriver: true }).start();
    toastTimer.current = setTimeout(() => {
      Animated.timing(toastAnim, { toValue: 0, duration: 180, useNativeDriver: true }).start(() =>
        setToast(null)
      );
    }, 4000);
  }

  function undoLog() {
    if (toast) removeItem('transactions', toast.id);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast(null);
  }

  // The date the entry lands on, or null when the typed date is unusable.
  function chosenDate() {
    if (when === 'yesterday') {
      const d = new Date();
      return todayISO(new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1));
    }
    if (when === 'other') {
      const t = otherDate.trim();
      if (!isRealDate(t)) return null;
      if (t > todayISO()) return 'future';
      return t;
    }
    return todayISO();
  }

  function quickAdd(item) {
    const date = chosenDate();
    if (date === null || date === 'future') {
      setErr(date === 'future' ? 'That date is in the future.' : 'Type the date as YYYY-MM-DD, like 2026-06-28.');
      return;
    }
    const id = addItem('transactions', { type: 'expense', label: item.label, amount: item.amount, date });
    onClose();
    celebrate(item.label, item.amount, id);
  }

  function save() {
    const amt = Number(String(amount).replace(/[, ]/g, ''));
    if (!Number.isFinite(amt) || amt <= 0) {
      setErr('Enter an amount greater than 0.');
      return;
    }
    const date = chosenDate();
    if (date === null) {
      setErr('Type the date as YYYY-MM-DD, like 2026-06-28.');
      return;
    }
    if (date === 'future') {
      setErr('That date is in the future.');
      return;
    }
    const entryLabel = label.trim() || (type === 'income' ? 'Income' : 'Expense');
    const id = addItem('transactions', { type, label: entryLabel, amount: amt, date });
    onClose();
    celebrate(entryLabel, amt, id);
  }

  const quickAdds = data.settings.quickAdds || [];

  return (
    <>
      <Modal visible={!!visible} transparent animationType="slide" onRequestClose={onClose}>
        <View style={styles.overlay}>
          <Pressable style={styles.backdrop} onPress={onClose} />
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Add entry</Text>

            <View style={styles.typeRow}>
              {['expense', 'income'].map((t) => {
                const on = type === t;
                return (
                  <Pressable key={t} onPress={() => setType(t)} style={[styles.typeBtn, on && styles.typeOn]}>
                    <Text style={[styles.typeText, on && styles.typeTextOn]}>
                      {t === 'expense' ? 'Expense' : 'Income'}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <Text style={styles.fieldLabel}>When</Text>
            <View style={styles.chips}>
              {[
                { key: 'today', text: 'Today' },
                { key: 'yesterday', text: 'Yesterday' },
                { key: 'other', text: 'Another day' },
              ].map((c) => {
                const on = when === c.key;
                return (
                  <Pressable key={c.key} onPress={() => setWhen(c.key)} style={[styles.chip, on && styles.chipOn]}>
                    <Text style={[styles.chipText, on && styles.chipTextOn]}>{c.text}</Text>
                  </Pressable>
                );
              })}
            </View>
            {when === 'other' ? (
              <TextInput
                style={styles.input}
                value={otherDate}
                onChangeText={setOtherDate}
                placeholder="YYYY-MM-DD, like 2026-06-28"
                placeholderTextColor={colors.faint}
                keyboardType="numbers-and-punctuation"
                autoCapitalize="none"
              />
            ) : null}

            {type === 'expense' && quickAdds.length > 0 ? (
              <>
                <Text style={styles.fieldLabel}>Quick add</Text>
                <View style={styles.chips}>
                  {quickAdds.map((item) => (
                    <Pressable
                      key={`${item.label}_${item.amount}`}
                      onPress={() => quickAdd(item)}
                      style={({ pressed }) => [styles.quick, pressed && styles.pressed]}
                    >
                      <Text style={styles.quickLabel}>{item.label}</Text>
                      <Text style={styles.quickAmount}>{formatMoney(item.amount)}</Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : null}

            <Text style={styles.fieldLabel}>{type === 'income' ? 'Source' : 'Category'}</Text>
            <TextInput
              style={styles.input}
              value={label}
              onChangeText={setLabel}
              placeholder={type === 'income' ? 'e.g. Salary' : 'e.g. Groceries'}
              placeholderTextColor={colors.faint}
            />
            <Text style={styles.fieldLabel}>Amount</Text>
            <TextInput
              style={styles.input}
              value={amount}
              onChangeText={setAmount}
              placeholder="0"
              placeholderTextColor={colors.faint}
              keyboardType="numeric"
            />

            {err ? <Text style={styles.err}>{err}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={onClose} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={save} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Add</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {toast ? (
        <Animated.View
          style={[
            styles.toast,
            { bottom: toastBottom },
            {
              transform: [
                { translateY: toastAnim.interpolate({ inputRange: [0, 1], outputRange: [80, 0] }) },
                { scale: toastAnim.interpolate({ inputRange: [0, 1], outputRange: [0.95, 1] }) },
              ],
            },
          ]}
        >
          <Text style={styles.toastText} numberOfLines={1}>
            {toast.text}
          </Text>
          <Pressable onPress={undoLog} hitSlop={12} style={styles.toastBtn}>
            <Text style={styles.toastUndo}>Undo</Text>
          </Pressable>
        </Animated.View>
      ) : null}
    </>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    backdrop: { ...StyleSheet.absoluteFillObject },
    sheet: {
      backgroundColor: colors.background,
      borderTopLeftRadius: radius.lg,
      borderTopRightRadius: radius.lg,
      borderColor: colors.border,
      borderWidth: 1,
      padding: spacing.xl,
    },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },

    typeRow: { flexDirection: 'row', gap: spacing.sm },
    typeBtn: { flex: 1, paddingVertical: spacing.sm + 2, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, alignItems: 'center' },
    typeOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    typeText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    typeTextOn: { color: colors.onPrimary },

    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: { paddingVertical: spacing.sm, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.medium },

    quick: {
      flexDirection: 'row',
      gap: spacing.sm,
      alignItems: 'center',
      paddingVertical: spacing.sm,
      paddingHorizontal: spacing.md,
      borderRadius: radius.pill,
      borderWidth: 1,
      borderColor: colors.border,
      backgroundColor: colors.card,
    },
    pressed: { opacity: 0.6 },
    quickLabel: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    quickAmount: { color: colors.softGreen, fontSize: fontSize.small, fontWeight: fontWeight.bold },

    input: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.md,
      color: colors.text,
      fontSize: fontSize.body,
      marginTop: spacing.xs,
    },
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    toast: {
      position: 'absolute',
      left: spacing.lg,
      right: spacing.lg,
      minHeight: 48,
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      backgroundColor: colors.positiveSurface,
      borderColor: colors.positiveBorder,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.lg,
      paddingVertical: spacing.md,
    },
    toastText: { color: colors.text, fontSize: fontSize.body, flex: 1, paddingRight: spacing.md },
    toastBtn: { minHeight: 44, justifyContent: 'center' },
    toastUndo: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
