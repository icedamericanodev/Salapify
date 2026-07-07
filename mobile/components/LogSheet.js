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
  Alert,
  Animated,
  BackHandler,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import Reanimated, { useAnimatedKeyboard, useAnimatedStyle } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Haptics from 'expo-haptics';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, todayISO } from '../lib/format';
import { pickReceipt, deleteReceipt } from '../lib/receipts';
import { scanReceiptText } from '../lib/ocr';
import { parseReceipt } from '../lib/receipt-parse';

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
  const { data, addTransaction, removeTransaction, updateSettings } = useAppData();

  const [type, setType] = useState('expense');
  const [label, setLabel] = useState('');
  const [amount, setAmount] = useState('');
  const [when, setWhen] = useState('today'); // 'today' | 'yesterday' | 'other'
  const [otherDate, setOtherDate] = useState('');
  const [accountId, setAccountId] = useState('');
  const [receiptUri, setReceiptUri] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [err, setErr] = useState('');
  const [scanning, setScanning] = useState(false);
  const [scanNote, setScanNote] = useState('');

  // Fresh form every time the sheet opens. The account chip starts on the
  // last one used (settings.defaultAccountId), so regulars never re-pick.
  useEffect(() => {
    if (visible) {
      setType('expense');
      setLabel('');
      setAmount('');
      setWhen('today');
      setOtherDate('');
      const def = data.settings.defaultAccountId;
      setAccountId(def && data.accounts.some((a) => a.id === def) ? def : '');
      setReceiptUri('');
      setCategoryId('');
      setErr('');
      setScanning(false);
      setScanNote('');
    }
  }, [visible]);

  // Tracks whether the sheet is open, so a photo pick that finishes after
  // the sheet closed gets cleaned up instead of leaking a file.
  const openRef = useRef(false);
  useEffect(() => {
    openRef.current = !!visible;
  }, [visible]);

  // As an in-window overlay rather than a native Modal, the hardware back
  // button must close the sheet (routing through cancel so an attached receipt
  // is still cleaned up) instead of leaving the screen behind it.
  useEffect(() => {
    if (!visible) return undefined;
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      cancel();
      return true;
    });
    return () => sub.remove();
  }, [visible, receiptUri]);

  // Closing without saving must not leave an orphan photo behind, and a
  // camera shot has exactly one copy, so discarding it asks first.
  const discardAskRef = useRef(false);
  function cancel() {
    if (!receiptUri) {
      onClose();
      return;
    }
    // A second back press (or tap) while the discard dialog is up must not
    // stack another identical dialog.
    if (discardAskRef.current) return;
    const discard = () => {
      discardAskRef.current = false;
      deleteReceipt(receiptUri);
      setReceiptUri('');
      onClose();
    };
    if (Platform.OS === 'web') {
      discard();
      return;
    }
    discardAskRef.current = true;
    Alert.alert('Discard this entry?', 'The attached receipt photo will be deleted.', [
      { text: 'Keep editing', style: 'cancel', onPress: () => { discardAskRef.current = false; } },
      { text: 'Discard', style: 'destructive', onPress: discard },
    ]);
  }

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
    if (toast) removeTransaction(toast.id);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast(null);
  }

  // Save an entry through the store, remember the account choice for next
  // time, close, and celebrate.
  function logEntry(entry, catId = categoryId) {
    const withExtras = {
      ...entry,
      ...(accountId ? { accountId } : {}),
      ...(receiptUri ? { receiptUri } : {}),
      ...(catId && entry.type === 'expense' ? { categoryId: catId } : {}),
    };
    const id = addTransaction(withExtras);
    if ((data.settings.defaultAccountId || '') !== accountId) {
      updateSettings({ defaultAccountId: accountId });
    }
    onClose();
    celebrate(entry.label, entry.amount, id);
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
    // A quick add whose label matches a category gets tagged with it, so
    // Food from the quick row and Food from the chips count together.
    const match = (data.categories || []).find((c) => c.name === item.label);
    logEntry({ type: 'expense', label: item.label, amount: item.amount, date }, match ? match.id : '');
  }

  // Read a freshly attached receipt with on-device OCR and prefill only the
  // fields the user has not filled themselves, so a scan never overwrites what
  // they typed. Everything is a suggestion they can correct before saving.
  async function scanAndPrefill(uri) {
    setScanNote('');
    setScanning(true);
    const text = await scanReceiptText(uri);
    if (!openRef.current) return; // sheet closed while scanning
    setScanning(false);
    if (!text) {
      setScanNote('Could not read this receipt. Type the amount in.');
      return;
    }
    const parsed = parseReceipt(text);
    if (parsed.total && !String(amount).trim()) setAmount(String(parsed.total));
    if (parsed.merchant && !label.trim()) setLabel(parsed.merchant);
    if (parsed.date && parsed.date !== todayISO()) {
      setWhen('other');
      setOtherDate(parsed.date);
    }
    if (!parsed.total) {
      setScanNote('Read the receipt, but not the total. Type the amount in.');
    } else if (parsed.totalConfidence === 'low') {
      setScanNote('Filled in what I found. Double check the amount, I was not sure.');
    } else {
      setScanNote('Filled in from the receipt. Check it before saving.');
    }
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
    logEntry({ type, label: entryLabel, amount: amt, date });
  }

  const quickAdds = data.settings.quickAdds || [];

  return (
    <>
      {visible ? (
        <SheetOverlay styles={styles} onBackdrop={cancel}>
          <ScrollView keyboardShouldPersistTaps="handled">
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
            {type === 'expense' && (data.categories || []).length > 0 ? (
              <View style={[styles.chips, { marginBottom: spacing.xs }]}>
                {(data.categories || []).map((c) => {
                  const on = categoryId === c.id;
                  return (
                    <Pressable
                      key={c.id}
                      onPress={() => {
                        // Tapping again unpicks. Picking fills the label
                        // unless the user already typed their own.
                        if (on) {
                          setCategoryId('');
                          return;
                        }
                        setCategoryId(c.id);
                        const names = (data.categories || []).map((x) => x.name);
                        if (!label.trim() || names.includes(label.trim())) setLabel(c.name);
                      }}
                      style={[styles.chip, on && styles.chipOn]}
                    >
                      <Text style={[styles.chipText, on && styles.chipTextOn]}>
                        {c.icon} {c.name}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            ) : null}
            <TextInput
              style={styles.input}
              value={label}
              onChangeText={setLabel}
              placeholder={type === 'income' ? 'e.g. Salary' : 'or type your own label'}
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

            {data.accounts.length > 0 ? (
              <>
                <Text style={styles.fieldLabel}>
                  {type === 'income' ? 'Into which account?' : 'From which account?'}
                </Text>
                <View style={styles.chips}>
                  <Pressable
                    onPress={() => setAccountId('')}
                    style={[styles.chip, accountId === '' && styles.chipOn]}
                  >
                    <Text style={[styles.chipText, accountId === '' && styles.chipTextOn]}>Not linked</Text>
                  </Pressable>
                  {data.accounts.map((a) => {
                    const on = accountId === a.id;
                    return (
                      <Pressable key={a.id} onPress={() => setAccountId(a.id)} style={[styles.chip, on && styles.chipOn]}>
                        <Text style={[styles.chipText, on && styles.chipTextOn]}>
                          {a.icon ? `${a.icon} ` : ''}{a.name}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </>
            ) : null}

            {Platform.OS !== 'web' ? (
              <Pressable
                onPress={async () => {
                  if (receiptUri) {
                    // The camera shot has one copy; removing it asks first.
                    Alert.alert('Remove the receipt photo?', 'The photo will be deleted.', [
                      { text: 'Keep it', style: 'cancel' },
                      {
                        text: 'Remove',
                        style: 'destructive',
                        onPress: () => {
                          deleteReceipt(receiptUri);
                          setReceiptUri('');
                          setScanNote('');
                        },
                      },
                    ]);
                    return;
                  }
                  const uri = await pickReceipt().catch(() => null);
                  if (!uri) return;
                  // The sheet may have been closed while the picker was
                  // open; a late arrival gets deleted, not leaked.
                  if (!openRef.current) {
                    deleteReceipt(uri);
                    return;
                  }
                  setReceiptUri(uri);
                  scanAndPrefill(uri);
                }}
                style={[styles.receiptBtn, receiptUri ? styles.receiptOn : null]}
              >
                <Text style={[styles.receiptText, receiptUri ? styles.receiptTextOn : null]}>
                  {receiptUri ? '🧾 Receipt attached. Tap to remove' : '🧾 Attach a receipt (optional)'}
                </Text>
              </Pressable>
            ) : null}
            {scanning ? <Text style={styles.scanNote}>Reading the receipt...</Text> : scanNote ? <Text style={styles.scanNote}>{scanNote}</Text> : null}

            {err ? <Text style={styles.err}>{err}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={cancel} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={save} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Add</Text>
              </Pressable>
            </View>
          </ScrollView>
        </SheetOverlay>
      ) : null}

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

// The lifting overlay lives in its own component so useAnimatedKeyboard, which
// installs a window keyboard listener, mounts only while the sheet is open
// rather than for the whole session (LogSheet itself is always mounted at the
// tab root).
function SheetOverlay({ styles, onBackdrop, children }) {
  const insets = useSafeAreaInsets();
  const keyboard = useAnimatedKeyboard();
  const lift = useAnimatedStyle(() => ({ paddingBottom: Math.max(keyboard.height.value, insets.bottom) }));
  return (
    <Reanimated.View style={[styles.overlay, lift]}>
      <Pressable style={styles.backdrop} onPress={onBackdrop} />
      <View style={styles.sheet}>{children}</View>
    </Reanimated.View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    // elevation and zIndex must beat the tab bar (elevation 8) and the FAB
    // (elevation 6), or on Android those siblings draw on top of the overlay
    // and its buttons become untappable and the tabs stay live behind it.
    overlay: { ...StyleSheet.absoluteFillObject, backgroundColor: colors.overlay, justifyContent: 'flex-end', elevation: 32, zIndex: 100 },
    backdrop: { ...StyleSheet.absoluteFillObject },
    sheet: {
      backgroundColor: colors.background,
      borderTopLeftRadius: radius.lg,
      borderTopRightRadius: radius.lg,
      borderColor: colors.border,
      borderWidth: 1,
      padding: spacing.xl,
      maxHeight: '90%',
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
    receiptBtn: {
      marginTop: spacing.md,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.md,
      paddingVertical: spacing.sm,
      alignItems: 'center',
      backgroundColor: colors.card,
    },
    receiptOn: { borderColor: colors.primary, backgroundColor: colors.positiveSurface },
    receiptText: { color: colors.muted, fontSize: fontSize.small },
    receiptTextOn: { color: colors.text, fontWeight: fontWeight.medium },
    scanNote: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.sm },
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
