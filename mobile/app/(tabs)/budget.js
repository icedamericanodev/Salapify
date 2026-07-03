// Budget and logging screen, wired to the store. The monthly limit and quick
// add buttons come from settings. Tapping a quick add, or adding a custom
// entry, saves a real transaction that persists. Recent shows live data and
// each row can be removed.

import { useMemo, useRef, useState } from 'react';
import {
  Animated,
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, todayISO, isThisMonth, monthLabel } from '../../lib/format';
import EmptyState from '../../components/EmptyState';
import WeekChain from '../../components/WeekChain';
import LogSheet from '../../components/LogSheet';
import { resolveReceipt } from '../../lib/receipts';

const today = todayISO;

// The log pop rotates through these so the reward never goes stale. The
// praise celebrates the act of logging, never the amount.
const TOAST_EMOJI = ['✅', '⚡', '🔥', '💚', '✨'];
const TOAST_PRAISE = ['Nakalista na. Ang bilis mo.', 'Logged. Galing.', 'Ayan, updated ka na.'];

export default function Budget() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, addTransaction, removeTransaction } = useAppData();

  const [customOpen, setCustomOpen] = useState(false); // the shared LogSheet
  const [receiptView, setReceiptView] = useState(''); // full screen receipt photo
  const [receiptDead, setReceiptDead] = useState(false); // photo missing on this phone
  const [toast, setToast] = useState(null); // {text, id} after logging
  const toastTimer = useRef(null);

  const limit = data.settings.monthlyLimit || 0;
  const quickAdds = data.settings.quickAdds || [];

  // Only this month's expenses count toward the limit, so the budget bar
  // resets automatically when a new month starts.
  const expenses = data.transactions.filter((t) => t.type === 'expense' && isThisMonth(t.date));
  const spent = expenses.reduce((total, e) => total + e.amount, 0);
  const remaining = limit - spent;
  const pct = limit ? Math.min(Math.round((spent / limit) * 100), 100) : 0;
  const over = spent > limit;

  // Newest first.
  const recent = [...data.transactions].reverse();

  // A little celebration after every log: a light buzz and a toast that
  // springs up from the bottom with Undo, so double taps and slips are one
  // tap to fix. The habit being rewarded is logging itself, never the amount.
  const toastAnim = useRef(new Animated.Value(0)).current;
  const toastCount = useRef(0);
  function celebrate(label, amount, id) {
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    } catch (e) {
      // Haptics are not available on web. That is fine.
    }
    if (toastTimer.current) clearTimeout(toastTimer.current);
    const n = toastCount.current++;
    const emoji = TOAST_EMOJI[n % TOAST_EMOJI.length];
    const praise = TOAST_PRAISE[n % TOAST_PRAISE.length];
    setToast({ text: `${emoji} ${label} ${formatMoney(amount)}. ${praise}`, id });
    toastAnim.setValue(0);
    Animated.spring(toastAnim, { toValue: 1, friction: 6, useNativeDriver: true }).start();
    toastTimer.current = setTimeout(() => {
      Animated.timing(toastAnim, { toValue: 0, duration: 180, useNativeDriver: true }).start(
        () => setToast(null)
      );
    }, 4000);
  }
  function undoLog() {
    if (toast) removeTransaction(toast.id);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast(null);
  }

  function quickAdd(item) {
    // One tap logs use the remembered account (set in the entry sheet), so
    // fast logging still keeps balances honest.
    const def = data.settings.defaultAccountId;
    const accountId = def && data.accounts.some((a) => a.id === def) ? def : '';
    const entry = { type: 'expense', label: item.label, amount: item.amount, date: today() };
    const id = addTransaction(accountId ? { ...entry, accountId } : entry);
    celebrate(item.label, item.amount, id);
  }
  // + Custom opens the same LogSheet as the global floating button, so the
  // entry form (with backdating) exists in exactly one place.
  function openCustom() {
    setCustomOpen(true);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Budget</Text>

        <View style={styles.card}>
          <Text style={styles.kicker}>{monthLabel().toUpperCase()}</Text>
          <Text style={styles.spent}>
            {formatMoney(spent)} <Text style={styles.ofLimit}>of {formatMoney(limit)}</Text>
          </Text>
          <View style={styles.track}>
            <View
              style={[styles.fill, { width: `${pct}%`, backgroundColor: over ? colors.warning : colors.primary }]}
            />
          </View>
          <Text style={[styles.remaining, { color: over ? colors.warning : colors.muted }]}>
            {over ? `${formatMoney(-remaining)} over your limit` : `${formatMoney(remaining)} left to spend`}
          </Text>
        </View>

        <WeekChain transactions={data.transactions} />

        <Text style={styles.sectionTitle}>QUICK ADD</Text>
        <View style={styles.quickRow}>
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
          <Pressable
            onPress={openCustom}
            style={({ pressed }) => [styles.quick, styles.custom, pressed && styles.pressed]}
          >
            <Text style={styles.customText}>+ Custom</Text>
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>RECENT</Text>
        <View style={styles.card}>
          {recent.length === 0 ? (
            <EmptyState icon="🧾" title="Nothing logged yet" subtitle="Tap a quick add or + Custom to start." />
          ) : (
            recent.slice(0, 12).map((e) => (
              <View key={e.id} style={styles.row}>
                <Text style={styles.rowName}>{e.label}</Text>
                <View style={styles.rowRight}>
                  {e.receiptUri ? (
                    <Pressable
                      onPress={() => {
                        setReceiptDead(false);
                        setReceiptView(resolveReceipt(e.receiptUri));
                      }}
                      hitSlop={8}
                    >
                      <Text style={styles.receiptIcon}>🧾</Text>
                    </Pressable>
                  ) : null}
                  <Text style={[styles.rowAmount, { color: e.type === 'income' ? colors.primary : colors.text }]}>
                    {e.type === 'income' ? '+' : '-'} {formatMoney(e.amount)}
                  </Text>
                  <Pressable onPress={() => removeTransaction(e.id)} hitSlop={8} style={styles.trash}>
                    <Ionicons name="close" size={16} color={colors.faint} />
                  </Pressable>
                </View>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      {/* Logged toast with Undo, springs in from the bottom. */}
      {toast ? (
        <Animated.View
          style={[
            styles.toast,
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

      {/* The shared entry sheet, same one the floating add button opens. */}
      <LogSheet visible={customOpen} onClose={() => setCustomOpen(false)} />

      {/* Full screen receipt viewer. */}
      <Modal visible={!!receiptView} transparent animationType="fade" onRequestClose={() => setReceiptView('')}>
        <Pressable style={styles.receiptOverlay} onPress={() => setReceiptView('')}>
          {receiptView && !receiptDead ? (
            <Image
              source={{ uri: receiptView }}
              style={styles.receiptImage}
              resizeMode="contain"
              onError={() => setReceiptDead(true)}
            />
          ) : null}
          {receiptDead ? (
            <Text style={styles.receiptDead}>
              This photo is not on this phone. Receipt photos stay on the phone that took them and
              are not included in backup files.
            </Text>
          ) : null}
          <Text style={styles.receiptClose}>Tap anywhere to close</Text>
        </Pressable>
      </Modal>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginBottom: spacing.md },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    spent: { color: colors.text, fontSize: fontSize.big, fontWeight: fontWeight.heavy, marginTop: spacing.xs, marginBottom: spacing.md },
    ofLimit: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.regular },
    track: { height: 10, borderRadius: radius.pill, backgroundColor: colors.border, overflow: 'hidden' },
    fill: { height: '100%', borderRadius: radius.pill },
    remaining: { fontSize: fontSize.small, marginTop: spacing.sm },

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    quickRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md, marginBottom: spacing.lg },
    quick: {
      flexGrow: 1, flexBasis: '47%', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1,
      borderRadius: radius.md, paddingVertical: spacing.md, paddingHorizontal: spacing.lg,
      flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    },
    custom: { justifyContent: 'center', borderColor: colors.primary },
    customText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.6 },
    quickLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    quickAmount: { color: colors.softGreen, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth },
    rowName: { color: colors.text, fontSize: fontSize.body, flex: 1 },
    rowRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    rowAmount: { fontSize: fontSize.body, fontWeight: fontWeight.bold },
    trash: { padding: 2 },
    receiptIcon: { fontSize: 15 },
    receiptOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.92)', alignItems: 'center', justifyContent: 'center', padding: spacing.lg },
    receiptImage: { width: '100%', height: '85%' },
    receiptClose: { color: '#FFFFFF', fontSize: fontSize.small, opacity: 0.7, marginTop: spacing.md },
    receiptDead: { color: '#FFFFFF', fontSize: fontSize.body, textAlign: 'center', paddingHorizontal: spacing.xl },
    empty: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },

    toast: {
      position: 'absolute',
      left: spacing.lg,
      right: spacing.lg,
      bottom: spacing.lg,
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
