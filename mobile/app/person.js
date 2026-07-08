// Person detail: one place for everything about a single person's utang. Shows
// what they still owe, every utang from them, the full payment history with a
// running total, and their contact note. From here you can remind them once for
// everything, share a plain text Statement of Account, or edit the person.
// Editing individual utang and logging payments still happen in the ledger, one
// tap back. All saved on the device. No dashes.

import { useMemo, useState } from 'react';
import {
  Alert,
  Linking,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney } from '../lib/format';
import { buildPersonStatement, buildPersonReminder } from '../lib/statement';
import EmptyState from '../components/EmptyState';

export default function Person() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const params = useLocalSearchParams();
  const { data, updateItem } = useAppData();

  const idParam = typeof params.id === 'string' ? params.id : '';
  const nameParam = typeof params.name === 'string' ? params.name : '';

  const people = data.people || [];
  const allRec = data.receivables || [];

  // Resolve the person: a real record by id, else a synthetic name only one
  // for a legacy receivable logged before person records existed. When opened
  // by id, this person's receivables are found by personId directly, so the
  // name can fall back to what those rows carry even if the person record is
  // missing (a partial or hand edited backup), never a bare "Someone".
  const personRecord = people.find((p) => p.id === idParam) || null;
  const byId = idParam ? allRec.filter((r) => r.personId === idParam) : [];
  const displayName =
    (personRecord && personRecord.name) || (byId[0] && byId[0].person) || nameParam || 'Someone';
  const nameKey = displayName.trim().toLowerCase();

  // This person's receivables: by personId when we have one, else by name for
  // legacy rows that never got linked.
  const receivables = idParam
    ? byId
    : allRec.filter((r) => String(r.person || '').trim().toLowerCase() === nameKey && !r.personId);

  const paidSum = (r) => (r.payments || []).reduce((t, p) => t + (Number(p.amount) || 0), 0);
  const remainingOf = (r) => Math.max(0, (Number(r.amount) || 0) - paidSum(r));
  const owed = receivables.filter((r) => !r.paid).reduce((t, r) => t + remainingOf(r), 0);
  const totalPaidAll = receivables.reduce((t, r) => t + paidSum(r), 0);

  // Flat payment history across all this person's utang, with a running
  // received total. Sort oldest first to build the running figure, then show
  // newest first.
  const flat = [];
  receivables.forEach((r) => {
    (r.payments || []).forEach((p) =>
      // rid keeps the key unique: a restored backup can give two payments on
      // two different utang the same id, and this list flattens across utang.
      flat.push({ id: p.id, rid: r.id, amount: Number(p.amount) || 0, date: p.date || '', from: r.note || 'Utang' })
    );
  });
  flat.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  let run = 0;
  const paymentRows = flat.map((p) => ({ ...p, running: (run += p.amount) })).reverse();

  const notFound = receivables.length === 0 && !personRecord;
  const phone = personRecord && typeof personRecord.phone === 'string' ? personRecord.phone.trim() : '';
  const note = personRecord && typeof personRecord.note === 'string' ? personRecord.note.trim() : '';

  const [edit, setEdit] = useState(null); // { name, phone, note }
  const [err, setErr] = useState('');

  function openEdit() {
    if (!personRecord) return;
    setEdit({ name: personRecord.name || '', phone: personRecord.phone || '', note: personRecord.note || '' });
    setErr('');
  }
  function saveEdit() {
    if (!edit.name.trim()) {
      setErr('Please enter a name.');
      return;
    }
    updateItem('people', personRecord.id, {
      name: edit.name.trim(),
      phone: edit.phone.trim(),
      note: edit.note.trim(),
    });
    setEdit(null);
  }

  // Pick a language, then hand the built text to the OS share sheet, exactly
  // like the ledger's reminder does.
  function pickLang(title, make) {
    const send = (lang) => Share.share({ message: make(lang) }).catch(() => {});
    if (Platform.OS === 'web') {
      send('en');
      return;
    }
    Alert.alert(title, `Choose the language for ${displayName}.`, [
      { text: 'English', onPress: () => send('en') },
      { text: 'Tagalog', onPress: () => send('tl') },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }
  const shareStatement = () =>
    pickLang('Share statement', (lang) =>
      buildPersonStatement(personRecord || { name: displayName }, receivables, { lang })
    );
  const remindAll = () =>
    pickLang('Send a reminder', (lang) =>
      buildPersonReminder(personRecord || { name: displayName }, owed, { lang })
    );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back} accessibilityRole="button" accessibilityLabel="Go back">
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle} numberOfLines={1}>{displayName}</Text>
        {personRecord ? (
          <Pressable onPress={openEdit} hitSlop={10} accessibilityRole="button" accessibilityLabel="Edit person">
            <Text style={styles.edit}>Edit</Text>
          </Pressable>
        ) : (
          <View style={{ width: 40 }} />
        )}
      </View>

      {notFound ? (
        <EmptyState
          icon="🔎"
          title="Person not found"
          subtitle="This ledger entry may have been deleted. Go back to see who owes you."
        />
      ) : (
        <>
          <ScrollView contentContainerStyle={styles.content}>
            <View style={styles.totalCard}>
              <Text style={styles.kicker}>{owed > 0 ? 'STILL OWES YOU' : 'ALL SETTLED'}</Text>
              <Text
                style={[styles.total, owed === 0 && styles.totalSettled]}
                accessibilityLabel={`${formatMoney(owed)} pesos`}
              >
                {formatMoney(owed)}
              </Text>
              <Text style={styles.totalSub}>
                {receivables.length} utang
                {owed > 0
                  ? totalPaidAll > 0
                    ? ` · ${formatMoney(totalPaidAll)} paid so far`
                    : ''
                  : ' · all paid'}
              </Text>
            </View>

            {phone || note ? (
              <View style={styles.card}>
                {phone ? (
                  <Pressable
                    onPress={() => Linking.openURL(`tel:${phone}`).catch(() => {})}
                    style={({ pressed }) => [styles.contactRow, pressed && styles.pressed]}
                    accessibilityRole="button"
                    accessibilityLabel={`Call ${displayName} at ${phone}`}
                  >
                    <Ionicons name="call-outline" size={16} color={colors.primary} />
                    <Text style={styles.contactText}>{phone}</Text>
                  </Pressable>
                ) : null}
                {note ? <Text style={styles.noteText}>{note}</Text> : null}
              </View>
            ) : null}

            <Text style={styles.section}>UTANG</Text>
            {receivables.map((r) => {
              const remaining = remainingOf(r);
              const partial = !r.paid && paidSum(r) > 0;
              return (
                <View
                  key={r.id}
                  style={[styles.card, r.paid && styles.cardPaid]}
                  accessible={true}
                  accessibilityLabel={`${r.note || 'Utang'}, ${
                    r.paid
                      ? 'paid'
                      : partial
                      ? `${formatMoney(paidSum(r))} of ${formatMoney(r.amount)} paid`
                      : `${formatMoney(remaining)} pesos`
                  }, ${r.dueDate ? `due ${r.dueDate}` : 'no due date'}`}
                >
                  <View style={styles.utangRow}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.utangName}>
                        {r.note || 'Utang'} {r.paid ? <Text style={styles.paidTag}>· paid</Text> : partial ? <Text style={styles.paidTag}>· partial</Text> : null}
                      </Text>
                      <Text style={styles.sub}>
                        {r.dueDate ? `Due ${r.dueDate}` : 'No due date'}
                        {partial ? ` · ${formatMoney(paidSum(r))} of ${formatMoney(r.amount)} paid` : ''}
                      </Text>
                    </View>
                    <Text
                      style={[styles.utangAmt, r.paid && styles.amtPaid]}
                      accessibilityLabel={`${formatMoney(r.paid ? r.amount : remaining)} pesos`}
                    >
                      {formatMoney(r.paid ? r.amount : remaining)}
                    </Text>
                  </View>
                </View>
              );
            })}
            <Text style={styles.hint}>Add utang, log payments, or mark paid back in the ledger.</Text>

            <Text style={styles.section}>PAYMENT HISTORY</Text>
            {paymentRows.length === 0 ? (
              <EmptyState icon="🧾" title="No payments yet" subtitle="Log a payment from the ledger and it shows up here." />
            ) : (
              paymentRows.map((p) => (
                <View
                  key={`${p.rid}-${p.id}`}
                  style={styles.payRow}
                  accessible={true}
                  accessibilityLabel={`${formatMoney(p.amount)} pesos received${p.date ? ` ${p.date}` : ''} for ${p.from}. ${formatMoney(p.running)} received in total.`}
                >
                  <Text style={styles.payLeft}>
                    {formatMoney(p.amount)} <Text style={styles.payMeta}>· {p.date ? `${p.date} · ` : ''}{p.from}</Text>
                  </Text>
                  <Text style={styles.payRunning}>{formatMoney(p.running)} received</Text>
                </View>
              ))
            )}
          </ScrollView>

          <View style={styles.actionBar}>
            {owed > 0 ? (
              <Pressable
                onPress={remindAll}
                style={({ pressed }) => [styles.remindBtn, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityLabel={`Remind ${displayName}`}
              >
                <Ionicons name="paper-plane-outline" size={16} color={colors.primary} />
                <Text style={styles.remindText}>Remind</Text>
              </Pressable>
            ) : null}
            <Pressable
              onPress={shareStatement}
              style={({ pressed }) => [styles.shareBtn, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel={`Share statement for ${displayName}`}
            >
              <Ionicons name="share-outline" size={16} color={colors.onPrimary} />
              <Text style={styles.shareText}>Share statement</Text>
            </Pressable>
          </View>
        </>
      )}

      <Modal visible={!!edit} transparent animationType="slide" onRequestClose={() => setEdit(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet} accessibilityViewIsModal={true}>
            <Text style={styles.sheetTitle}>Edit person</Text>
            <Text style={styles.fieldLabel}>Name</Text>
            <TextInput style={styles.input} value={edit?.name} onChangeText={(t) => setEdit((e) => ({ ...e, name: t }))} placeholder="Name" placeholderTextColor={colors.faint} />
            <Text style={styles.fieldLabel}>Phone (optional)</Text>
            <TextInput style={styles.input} value={edit?.phone} onChangeText={(t) => setEdit((e) => ({ ...e, phone: t }))} placeholder="09xx xxx xxxx" placeholderTextColor={colors.faint} keyboardType="phone-pad" />
            <Text style={styles.fieldLabel}>Note (optional)</Text>
            <TextInput style={styles.input} value={edit?.note} onChangeText={(t) => setEdit((e) => ({ ...e, note: t }))} placeholder="e.g. officemate" placeholderTextColor={colors.faint} />
            {err ? (
              <Text style={styles.err} accessibilityRole="alert" accessibilityLiveRegion="assertive">
                Error: {err}
              </Text>
            ) : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setEdit(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={saveEdit} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Save</Text>
              </Pressable>
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
    headerTitle: { flex: 1, textAlign: 'center', color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginHorizontal: spacing.sm },
    edit: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: 96 },

    totalCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    total: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.bold, marginTop: spacing.xs },
    totalSettled: { color: colors.muted },
    totalSub: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    cardPaid: { opacity: 0.6 },
    contactRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, minHeight: 44 },
    contactText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    noteText: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs },

    section: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2, marginBottom: spacing.sm, marginTop: spacing.xs },
    utangRow: { flexDirection: 'row', alignItems: 'center' },
    utangName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    paidTag: { color: colors.muted, fontWeight: fontWeight.regular, fontSize: fontSize.small },
    sub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    utangAmt: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginLeft: spacing.md },
    amtPaid: { color: colors.muted },
    hint: { color: colors.faint, fontSize: fontSize.caption, marginBottom: spacing.lg },

    payRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm, borderBottomWidth: 1, borderBottomColor: colors.border },
    payLeft: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium, flex: 1 },
    payMeta: { color: colors.muted, fontWeight: fontWeight.regular, fontSize: fontSize.caption },
    payRunning: { color: colors.muted, fontSize: fontSize.caption, marginLeft: spacing.sm },

    actionBar: { position: 'absolute', left: 0, right: 0, bottom: 0, flexDirection: 'row', gap: spacing.md, padding: spacing.lg, backgroundColor: colors.card, borderTopColor: colors.border, borderTopWidth: 1 },
    remindBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.md, minHeight: 48, paddingHorizontal: spacing.lg },
    remindText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    shareBtn: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, backgroundColor: colors.primary, borderRadius: radius.md, minHeight: 48 },
    shareText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.6 },
  });
}
