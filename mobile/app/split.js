// Split a bill. The barkada flow: one person pays the whole bill, everyone
// owes their share. Enter the total, add the people, adjust shares if
// someone ordered extra, and confirm. Your share is logged as your real
// expense; every friend's share becomes an utang receivable on their ledger,
// so the aging card, reminders, and partial payments all just work.
//
// Money math rules:
// - Shares always sum to the total. Equal split rounds friends' shares to
//   whole centavos and YOU absorb the rounding difference, so no one is
//   ever charged a phantom centavo.
// - Editing a friend's share recomputes your share as the remainder, which
//   keeps the sum exact and matches how splitting works at a real table:
//   the payer covers what is left.
// - Confirm writes everything in one pass: one expense (your share) and one
//   receivable per friend. No schema change, only existing collections.

import { useMemo, useState } from 'react';
import {
  Alert,
  Platform,
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

const toNum = (t) => Number(String(t).replace(/[, ]/g, ''));
const round2 = (n) => Math.round(n * 100) / 100;

export default function SplitBill() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, addTransaction } = useAppData();
  const people = data.people || [];

  const [label, setLabel] = useState('');
  const [total, setTotal] = useState('');
  // Friends in this split: { name, override } where override is a manual
  // share as a string, or null when the friend just takes the equal share.
  const [friends, setFriends] = useState([]);
  const [nameInput, setNameInput] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const totalNum = toNum(total);
  const totalOk = total !== '' && Number.isFinite(totalNum) && totalNum > 0;

  // Suggestions from the existing ledger, minus people already added.
  const suggestions = people
    .map((p) => String(p.name || '').trim())
    .filter(
      (n) =>
        n &&
        !friends.some((f) => f.name.toLowerCase() === n.toLowerCase()) &&
        (!nameInput.trim() || n.toLowerCase().includes(nameInput.trim().toLowerCase()))
    )
    .slice(0, 6);

  function addFriend(rawName) {
    const name = String(rawName || '').trim();
    if (!name) return;
    if (name.toLowerCase() === 'you' || name.toLowerCase() === 'me' || name.toLowerCase() === 'ako') {
      setErr('You are already part of the split.');
      return;
    }
    if (friends.some((f) => f.name.toLowerCase() === name.toLowerCase())) {
      setErr(`${name} is already in the split.`);
      return;
    }
    setErr('');
    setFriends((f) => [...f, { name, override: null }]);
    setNameInput('');
  }
  function removeFriend(name) {
    setFriends((f) => f.filter((x) => x.name !== name));
  }

  // The share math. Friends without an override take the equal share of
  // whatever the overrides left behind; you get the exact remainder.
  const shares = useMemo(() => {
    if (!totalOk || friends.length === 0) return null;
    const headCount = friends.length + 1; // you included
    const overridden = friends.filter((f) => f.override !== null);
    const overrideSum = overridden.reduce((t, f) => {
      const v = toNum(f.override);
      return t + (Number.isFinite(v) && v >= 0 ? v : 0);
    }, 0);
    if (overrideSum > totalNum + 1e-9) return { invalid: `Custom shares add up to more than the bill.` };
    const flexCount = friends.length - overridden.length + 1; // flexible friends plus you
    const equalShare = round2((totalNum - overrideSum) / flexCount);
    const rows = friends.map((f) => ({
      name: f.name,
      override: f.override,
      amount: f.override !== null ? round2(Math.max(0, toNum(f.override) || 0)) : equalShare,
    }));
    const friendsSum = rows.reduce((t, r) => t + r.amount, 0);
    // You absorb the rounding so the sum is exact to the centavo.
    const yours = round2(totalNum - friendsSum);
    if (yours < 0) return { invalid: 'Shares add up to more than the bill.' };
    return { rows, yours };
  }, [totalOk, totalNum, friends]);

  function confirm() {
    if (busy) return;
    if (!totalOk) {
      setErr('Enter the bill total first.');
      return;
    }
    if (friends.length === 0) {
      setErr('Add at least one person to split with.');
      return;
    }
    if (!shares || shares.invalid) {
      setErr((shares && shares.invalid) || 'Check the shares.');
      return;
    }
    const billLabel = label.trim() || 'Split bill';
    const doIt = () => {
      setBusy(true);
      try {
        // Your share is your real spending today.
        if (shares.yours > 0) {
          const def = data.settings.defaultAccountId;
          const accountId = def && data.accounts.some((a) => a.id === def) ? def : '';
          const entry = { type: 'expense', label: billLabel, amount: shares.yours, date: todayISO() };
          addTransaction(accountId ? { ...entry, accountId } : entry);
        }
        // Each friend's share becomes an utang on their ledger, reusing the
        // same find-or-create person logic as the receivables screen.
        for (const row of shares.rows) {
          if (row.amount <= 0) continue;
          const key = row.name.toLowerCase();
          let person = (data.people || []).find(
            (p) => String(p.name || '').trim().toLowerCase() === key
          );
          let personId;
          if (person) {
            personId = person.id;
          } else {
            personId = addItem('people', { name: row.name, phone: '', note: '' });
          }
          addItem('receivables', {
            person: row.name,
            personId,
            amount: row.amount,
            dueDate: '',
            phone: (person && person.phone) || '',
            note: `${billLabel} (split)`,
            paid: false,
            payments: [],
          });
        }
        router.back();
      } finally {
        setBusy(false);
      }
    };
    const summary =
      `${billLabel}: ${formatMoney(totalNum)} total.\n` +
      `Your share ${formatMoney(shares.yours)} is logged as an expense.\n` +
      shares.rows.map((r) => `${r.name} owes you ${formatMoney(r.amount)}.`).join('\n');
    if (Platform.OS === 'web') {
      if (typeof window !== 'undefined' && window.confirm(summary)) doIt();
      return;
    }
    Alert.alert('Split this bill?', summary, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Split it', onPress: doIt },
    ]);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Split a bill</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.fieldLabel}>What was it?</Text>
        <TextInput
          style={styles.input}
          value={label}
          onChangeText={setLabel}
          placeholder="e.g. Samgyup night"
          placeholderTextColor={colors.faint}
        />

        <Text style={styles.fieldLabel}>Bill total</Text>
        <TextInput
          style={styles.input}
          value={total}
          onChangeText={setTotal}
          placeholder="0"
          placeholderTextColor={colors.faint}
          keyboardType="numeric"
        />

        <Text style={styles.fieldLabel}>Who shared it? (besides you)</Text>
        <View style={styles.addRow}>
          <TextInput
            style={[styles.input, { flex: 1 }]}
            value={nameInput}
            onChangeText={(t) => {
              setNameInput(t);
              setErr('');
            }}
            placeholder="Type a name"
            placeholderTextColor={colors.faint}
            onSubmitEditing={() => addFriend(nameInput)}
            returnKeyType="done"
          />
          <Pressable onPress={() => addFriend(nameInput)} style={({ pressed }) => [styles.addBtn, pressed && styles.pressed]}>
            <Text style={styles.addBtnText}>Add</Text>
          </Pressable>
        </View>
        {suggestions.length > 0 ? (
          <View style={styles.chips}>
            {suggestions.map((n) => (
              <Pressable key={n} onPress={() => addFriend(n)} style={styles.chip}>
                <Text style={styles.chipText}>{n}</Text>
              </Pressable>
            ))}
          </View>
        ) : null}

        {friends.length > 0 && totalOk ? (
          <View style={styles.card}>
            <Text style={styles.kicker}>THE SPLIT</Text>
            {shares && !shares.invalid ? (
              <>
                <View style={styles.shareRow}>
                  <Text style={styles.shareName}>You (paid the bill)</Text>
                  <Text style={styles.shareAmt}>{formatMoney(shares.yours)}</Text>
                </View>
                {shares.rows.map((r) => (
                  <View key={r.name} style={styles.shareRow}>
                    <View style={styles.shareLeft}>
                      <Pressable onPress={() => removeFriend(r.name)} hitSlop={8}>
                        <Ionicons name="close-circle" size={18} color={colors.faint} />
                      </Pressable>
                      <Text style={styles.shareName} numberOfLines={1}>
                        {r.name}
                      </Text>
                    </View>
                    <TextInput
                      style={styles.shareInput}
                      value={r.override !== null ? String(r.override) : String(r.amount)}
                      onChangeText={(t) =>
                        setFriends((fs) =>
                          fs.map((f) => (f.name === r.name ? { ...f, override: t } : f))
                        )
                      }
                      keyboardType="numeric"
                    />
                  </View>
                ))}
                <Text style={styles.hint}>
                  Equal split by default. Change anyone's share and your share becomes the remainder,
                  so the total always matches the bill.
                </Text>
              </>
            ) : (
              <Text style={styles.err}>{(shares && shares.invalid) || ''}</Text>
            )}
          </View>
        ) : null}

        {err ? <Text style={styles.err}>{err}</Text> : null}

        <Pressable
          onPress={confirm}
          disabled={busy}
          style={({ pressed }) => [styles.primaryBtn, (pressed || busy) && styles.pressed]}
        >
          <Text style={styles.primaryText}>{busy ? 'Saving...' : 'Split it'}</Text>
        </Pressable>
        <Text style={styles.hint}>
          Your share is logged as your expense. Each friend's share is added to People who owe me,
          where you can remind them and log payments.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingHorizontal: spacing.lg,
      paddingTop: spacing.md,
      paddingBottom: spacing.sm,
    },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

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
    addRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center' },
    addBtn: {
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      paddingVertical: spacing.md,
      paddingHorizontal: spacing.lg,
    },
    addBtnText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.sm },
    chip: {
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
    },
    chipText: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginTop: spacing.lg,
    },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2, marginBottom: spacing.sm },
    shareRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.sm, gap: spacing.md },
    shareLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, flex: 1, minWidth: 0 },
    shareName: { color: colors.text, fontSize: fontSize.body, flexShrink: 1 },
    shareAmt: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    shareInput: {
      backgroundColor: colors.background,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
      color: colors.text,
      fontSize: fontSize.body,
      minWidth: 96,
      textAlign: 'right',
    },
    hint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.md, lineHeight: 18 },
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },

    primaryBtn: {
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      minHeight: 52,
      alignItems: 'center',
      justifyContent: 'center',
      marginTop: spacing.xl,
    },
    primaryText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.7 },
  });
}
