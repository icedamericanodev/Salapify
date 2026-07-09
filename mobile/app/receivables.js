// People who owe me (receivables). Track who owes you, how much, and when it
// is due. One-tap "Remind" opens your messaging apps with a polite message
// ready to send. Mark paid, edit, delete. All saved on the device.

import { useMemo, useRef, useState } from 'react';
import {
  Alert,
  Modal,
  Platform,
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
import { useAppData, genId } from '../context/AppData';
import { formatMoney, todayISO } from '../lib/format';
import EmptyState from '../components/EmptyState';
import Card from '../components/Card';
import Celebration from '../components/motion/Celebration';
import SectionHeader from '../components/SectionHeader';

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
  const { data, addItem, updateItem, removeItem, addTransaction, removeTransaction } = useAppData();

  const [form, setForm] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);
  const [err, setErr] = useState('');
  // Inline partial payment: which receivable is taking a payment, and the
  // amount being typed.
  const [payFor, setPayFor] = useState(null);
  const [payAmt, setPayAmt] = useState('');
  // The win overlay shown when an utang is fully collected.
  const [celebrate, setCelebrate] = useState(null);

  const list = data.receivables || [];
  const people = data.people || [];

  // Partial payments: what is still owed on one receivable.
  const paidSum = (r) => (r.payments || []).reduce((t, p) => t + (Number(p.amount) || 0), 0);
  const remainingOf = (r) => Math.max(0, (Number(r.amount) || 0) - paidSum(r));
  const owedTotal = list.filter((r) => !r.paid).reduce((t, r) => t + remainingOf(r), 0);

  // The display name for a receivable: the person record wins (it follows
  // renames), the legacy person string is the fallback.
  const nameOf = (r) => {
    const p = people.find((x) => x.id === r.personId);
    return (p && p.name) || r.person || 'Someone';
  };

  // Group by person for the ledger view: every group has a name, the
  // receivables newest first, and how much that person still owes in total.
  const groups = [];
  const groupIndex = new Map();
  for (const r of list) {
    const key = r.personId || `name:${String(r.person || '').trim().toLowerCase()}`;
    let g = groupIndex.get(key);
    if (!g) {
      g = { key, name: nameOf(r), personId: r.personId || '', items: [], owed: 0 };
      groupIndex.set(key, g);
      groups.push(g);
    }
    g.items.push(r);
    if (!r.paid) g.owed += remainingOf(r);
  }
  groups.sort((a, b) => b.owed - a.owed);

  function openAdd() {
    // fromAccount: which account the lent money leaves (optional). When set, the
    // receivable gets a real cash leg and counts in net worth; when left null it
    // behaves like before (money not tracked leaving, excluded from net worth).
    setForm({ id: null, person: '', amount: '', dueDate: '', phone: '', note: '', paid: false, fromAccount: null });
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
      // Tracked utang carries a cash leg tied to this exact amount. The edit
      // form locks the amount so it cannot drift the recorded cash move.
      cashLeg: !!r.cashLeg,
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
    // Editing the total below what is already paid would make "paid of
    // total" read as nonsense and drop the utang out of the totals while
    // still owing. Refuse it, and point at the real fix.
    if (form.id) {
      const existing = list.find((x) => x.id === form.id);
      const already = existing ? paidSum(existing) : 0;
      if (amount < already) {
        setErr(`Already ${formatMoney(already)} paid on this. The amount cannot be lower than that. Remove a payment first if you need to.`);
        return;
      }
    }
    // The date must be real, not just shaped right: 2026-02-30 rolls over
    // to March in JavaScript and reminders would fire on the wrong day.
    const dd = form.dueDate.trim();
    if (dd) {
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dd);
      const real =
        m &&
        (() => {
          const dt = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
          return dt.getMonth() === Number(m[2]) - 1 && dt.getDate() === Number(m[3]);
        })();
      if (!real) {
        setErr('That date does not exist. Tap a quick date above, or type it like 2026-07-15.');
        return;
      }
    }
    // Everything below mutates: it creates people, writes the utang, and can
    // post a settling income. A double tap must run it exactly once. All the
    // early returns above are pure validation, so the guard sits here, after
    // the last of them, and clears on the next beat like settleOnce does.
    if (saveBusy.current) return;
    saveBusy.current = true;
    setTimeout(() => { saveBusy.current = false; }, 400);
    // Find or create the person record so "Juan" is one ledger entry no
    // matter how many utang he racks up. Case and spacing insensitive.
    const name = form.person.trim();
    const key = name.toLowerCase();
    let person = people.find((p) => String(p.name || '').trim().toLowerCase() === key);
    if (!person) {
      const personId = addItem('people', { name, phone: form.phone.trim(), note: '' });
      person = { id: personId };
    } else if (form.phone.trim()) {
      updateItem('people', person.id, { phone: form.phone.trim() });
    }
    const existing = form.id ? list.find((x) => x.id === form.id) : null;
    const wasPaid = !!(existing && existing.paid);
    // A lending cash leg is recorded only for a NEW receivable where the user
    // named the source account. It deducts the lent money (a transfer out) and
    // marks the receivable tracked, so it counts in net worth and collecting it
    // later returns the cash instead of posting phantom income.
    const lendAcctId =
      !form.id && form.fromAccount && data.accounts.some((a) => a.id === form.fromAccount)
        ? form.fromAccount
        : '';
    // Write the fields first, then reconcile the paid toggle below. The paid
    // state is deliberately NOT part of this payload: flipping it has to move
    // money the same way the Mark paid button does, never just flip a flag.
    const payload = {
      person: name,
      personId: person.id,
      amount,
      dueDate: form.dueDate.trim(),
      phone: form.phone.trim(),
      note: form.note.trim(),
    };
    let id = form.id;
    if (form.id) updateItem('receivables', form.id, payload);
    else id = addItem('receivables', { ...payload, payments: [], paid: false });

    // Record the lending outflow and mark the receivable tracked.
    if (lendAcctId) {
      const lendTxnId = addTransaction({
        type: 'transfer',
        flow: 'out',
        label: `Lent to ${name}`,
        amount,
        date: todayISO(),
        accountId: lendAcctId,
        source: 'receivable',
      });
      updateItem('receivables', id, { cashLeg: true, accountId: lendAcctId, lendTxnId });
    }
    // What postIncome needs to route collection correctly for a brand new item
    // (the stored item is not in `list` yet within this synchronous save).
    const collectRef = { person: name, personId: person.id, cashLeg: !!lendAcctId, accountId: lendAcctId };

    // Reconcile the "Marked as paid" toggle through the same money path as the
    // Mark paid button, so it can never leave an utang shown as paid with no
    // income recorded, or reopened with phantom income left behind. The
    // settling payment is tagged settled so turning the toggle back off knows
    // exactly which entries to reverse, while genuine partial payments stay.
    const priorPayments = existing ? (existing.payments || []) : [];
    if (form.paid) {
      // Post income for whatever is still owed and record it as a settling
      // payment. This one branch covers a fresh paid utang, flipping an unpaid
      // one to paid, AND raising the amount of an already paid one (the top up
      // is posted too), so the recorded income always matches the paid total.
      const priorPaid = priorPayments.reduce((t, p) => t + (Number(p.amount) || 0), 0);
      const remaining = Math.max(0, amount - priorPaid);
      let payments = priorPayments;
      if (remaining > 0) {
        const txnId = postIncome(collectRef, remaining);
        payments = [...priorPayments, { id: genId('rpay'), amount: remaining, date: todayISO(), txnId, settled: true }];
      }
      updateItem('receivables', id, { paid: true, payments });
    } else if (wasPaid) {
      // Reopening. Reverse ONLY the entries we tagged as settling when the
      // utang was closed, and drop them. If none are tagged, the utang was
      // closed by an older build or paid off entirely through genuine partial
      // payments (logPartial marks paid without tagging), so we keep every
      // payment and its transaction untouched and just flip paid back to false.
      // That can leave a legacy row reading "0 owed but reopened", which is
      // honest (the money really moved, and the user can delete a specific
      // payment from the history), and it never deletes money the user logged.
      const settledTagged = priorPayments.filter((p) => p.settled);
      let payments = priorPayments;
      if (settledTagged.length) {
        settledTagged.forEach((p) => { if (p.txnId) removeTransaction(p.txnId); });
        payments = priorPayments.filter((p) => !p.settled);
      }
      updateItem('receivables', id, { paid: false, payments });
    }
    setForm(null);
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) {
      // Reverse every income entry this utang's payments posted, so a
      // deleted receivable never leaves phantom income and an inflated
      // balance behind. Payments logged before payment tracking carry no
      // link, so there is nothing to reverse for those, which is honest.
      const r = list.find((x) => x.id === form.id);
      (r?.payments || []).forEach((p) => {
        if (p.txnId) removeTransaction(p.txnId);
      });
      // If this receivable recorded a lending outflow, reverse it too so the
      // lent money returns to the account (deleting the utang undoes the lend).
      if (r?.lendTxnId) removeTransaction(r.lendTxnId);
      removeItem('receivables', form.id);
    }
    setForm(null);
  }

  // Record money coming back. Returns the transaction id so the payment can
  // remember it and reverse it later.
  //
  // Two honest cases:
  //  - Tracked utang (r.cashLeg): the cash left a real account when you lent, so
  //    collecting is a TRANSFER back into that same account, not income. Net
  //    worth is unchanged by the round trip (the receivable shrinks, cash grows).
  //  - Legacy/untracked utang: no cash leg was recorded when you lent, so the
  //    money returning reads as a real inflow. Post it as income (tagged
  //    source: 'receivable' so the savings rate still leaves it out of earnings).
  function postIncome(r, amount) {
    if (amount <= 0) return '';
    if (r.cashLeg) {
      const acctId = r.accountId && data.accounts.some((a) => a.id === r.accountId) ? r.accountId : '';
      const entry = { type: 'transfer', flow: 'in', label: `${nameOf(r)} paid you back`, amount, date: todayISO(), source: 'receivable' };
      return addTransaction(acctId ? { ...entry, accountId: acctId } : entry);
    }
    const def = data.settings.defaultAccountId;
    const accountId = def && data.accounts.some((a) => a.id === def) ? def : '';
    const entry = { type: 'income', label: `${nameOf(r)} paid you back`, amount, date: todayISO(), source: 'receivable' };
    return addTransaction(accountId ? { ...entry, accountId } : entry);
  }

  // A double tap on Save must not run the money reconcile twice: both taps
  // would see the same pre-save state, post two settling incomes, and create a
  // duplicate item. One beat of quiet, same idea as settleOnce below.
  const saveBusy = useRef(false);
  // Stacked confirm dialogs or a double tap must not post a payment twice
  // while both reads saw the same pre-payment state. One beat of quiet.
  const settleBusy = useRef(false);
  function settleOnce(fn) {
    if (settleBusy.current) return;
    settleBusy.current = true;
    setTimeout(() => {
      settleBusy.current = false;
    }, 400);
    fn();
  }

  // Mark paid settles whatever is STILL owed after partial payments. One
  // tap writes a payment and an income entry, so it confirms first; a
  // slip of the finger must not invent money received. The settling
  // payment remembers its income entry (txnId) so it can be reversed.
  function markPaid(r) {
    const remaining = remainingOf(r);
    const doIt = () => settleOnce(() => {
      let payments = r.payments || [];
      if (remaining > 0) {
        const txnId = postIncome(r, remaining);
        payments = [...payments, { id: genId('rpay'), amount: remaining, date: todayISO(), txnId, settled: true }];
      }
      updateItem('receivables', r.id, { paid: true, payments });
      // The happy moment: money actually came back. Only celebrate when there
      // was something to collect, not when closing an already settled utang.
      if (remaining > 0) {
        setCelebrate({ message: `Ayos! ${nameOf(r)} paid you back.`, id: Date.now() });
      }
    });
    const message =
      remaining > 0
        ? `Log ${formatMoney(remaining)} from ${nameOf(r)} as received and close this utang?`
        : 'Close this utang? Everything is already paid.';
    if (Platform.OS === 'web') {
      // Alert buttons are a no-op in browsers, so confirm the web way.
      if (typeof window !== 'undefined' && window.confirm(message)) doIt();
      return;
    }
    Alert.alert('Mark as paid?', message, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Mark paid', onPress: doIt },
    ]);
  }

  // A partial payment: "Juan gave me 200 of the 500." Records the payment
  // on the receivable, posts the income, and settles the utang by itself
  // when the last peso arrives.
  function logPartial(r) {
    const amount = Number(String(payAmt).replace(/[, ]/g, ''));
    const remaining = remainingOf(r);
    if (!Number.isFinite(amount) || amount <= 0) return;
    const applied = Math.min(amount, remaining);
    // Nothing left to pay means nothing to record: no phantom zero
    // payment rows on an already covered utang.
    if (applied <= 0) return;
    settleOnce(() => {
      // Post the income first so the payment can remember its entry and
      // reverse it if the user removes the payment later.
      const txnId = postIncome(r, applied);
      const payment = { id: genId('rpay'), amount: applied, date: todayISO(), txnId };
      const settles = applied >= remaining;
      updateItem('receivables', r.id, {
        payments: [...(r.payments || []), payment],
        paid: settles,
      });
      setPayFor(null);
      setPayAmt('');
      // If this partial was the last peso, the utang is collected in full.
      // Celebrate it here too, matching payables' settling partial.
      if (settles) {
        setCelebrate({ message: `Ayos! ${nameOf(r)} paid you back.`, id: Date.now() });
      }
    });
  }

  // Remove one logged payment: reverse its income entry (so the balance
  // and cash flow correct themselves), drop the payment row, and reopen
  // the utang if it was fully paid. This is the fix for a fat fingered
  // amount, which used to be permanent.
  function removePayment(r, payment) {
    const doIt = () => settleOnce(() => {
      if (payment.txnId) removeTransaction(payment.txnId);
      const payments = (r.payments || []).filter((p) => p.id !== payment.id);
      const newPaidSum = payments.reduce((t, p) => t + (Number(p.amount) || 0), 0);
      // Fully covered stays paid; otherwise removing a payment reopens it.
      const stillPaid = r.paid && newPaidSum >= (Number(r.amount) || 0);
      updateItem('receivables', r.id, { payments, paid: stillPaid });
    });
    const message = payment.txnId
      ? `Remove this ${formatMoney(payment.amount)} payment? Its income entry will be reversed too.`
      : `Remove this ${formatMoney(payment.amount)} payment? It was logged before payment tracking, so no income entry is linked to reverse.`;
    if (Platform.OS === 'web') {
      if (typeof window !== 'undefined' && window.confirm(message)) doIt();
      return;
    }
    Alert.alert('Remove payment?', message, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: doIt },
    ]);
  }

  // Opens the share sheet (SMS, WhatsApp, Messenger, email...) with a
  // friendly reminder already written, in English or Tagalog. You pick the
  // language, then the app, then tap send.
  function remind(r) {
    // Remind for what is STILL owed after partial payments, never the
    // original amount, so nobody gets dunned for money they already paid.
    const remaining = remainingOf(r);
    const amount = formatMoney(remaining > 0 ? remaining : r.amount);
    const english = `Hi ${r.person}! Friendly reminder about the ${amount} I lent you${
      r.dueDate ? ` (due ${r.dueDate})` : ''
    }. No rush, just don't forget me ha. Thank you!`;
    const tagalog = `Hi ${r.person}! Paalala lang sa ${amount} na hiniram mo${
      r.dueDate ? ` (due sa ${r.dueDate})` : ''
    }. Walang pressure, wag mo lang kalimutan ha. Salamat!`;
    const send = (message) => Share.share({ message }).catch(() => {});
    if (Platform.OS === 'web') {
      send(english);
      return;
    }
    Alert.alert('Send a reminder', `Choose the language for ${r.person}.`, [
      { text: 'English', onPress: () => send(english) },
      { text: 'Tagalog', onPress: () => send(tagalog) },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable
          onPress={() => router.back()}
          hitSlop={10}
          style={styles.back}
          accessibilityRole="button"
          accessibilityLabel="Go back"
        >
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>People who owe me</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <Card variant="hero" style={styles.totalCard}>
          <Text style={styles.kicker}>TOTAL OWED TO YOU</Text>
          <Text style={styles.total} accessibilityLabel={`${formatMoney(owedTotal)} pesos`}>{formatMoney(owedTotal)}</Text>
        </Card>

        {/* The barkada flow: split one bill into your expense plus an utang
            per friend, all in one pass. */}
        <Pressable
          onPress={() => router.push('/split')}
          style={({ pressed }) => [styles.splitBtn, pressed && styles.pressed]}
        >
          <Ionicons name="people-outline" size={18} color={colors.onPrimary} />
          <Text style={styles.splitText}>Split a bill with friends</Text>
        </Pressable>

        {list.length === 0 ? (
          <EmptyState icon="🤝" title="No one owes you" subtitle="Tap + Add to track money owed to you." />
        ) : (
          <>
          <SectionHeader title="WHO OWES YOU" />
          {groups.map((g) => (
            <View key={g.key} style={styles.group}>
              <Pressable
                onPress={() =>
                  router.push({
                    pathname: '/person',
                    params: g.personId ? { id: g.personId } : { name: g.name },
                  })
                }
                style={({ pressed }) => [styles.groupHeader, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityLabel={`${g.name}, ${g.owed > 0 ? `owes ${formatMoney(g.owed)} pesos` : 'all settled'}`}
                accessibilityHint="Opens this person's full ledger"
              >
                <Text style={styles.groupName} numberOfLines={1}>{g.name}</Text>
                <View style={styles.groupRight}>
                  <Text style={[styles.groupOwed, g.owed === 0 && styles.groupSettled]}>
                    {g.owed > 0 ? `owes ${formatMoney(g.owed)}` : 'all settled'}
                  </Text>
                  <Ionicons name="chevron-forward" size={18} color={colors.muted} />
                </View>
              </Pressable>
              {g.items.map((r) => {
                const remaining = remainingOf(r);
                const partial = !r.paid && paidSum(r) > 0;
                return (
                  <Card key={r.id} variant="flat" style={[styles.cardGap, r.paid && styles.cardPaid]}>
                    <Pressable onPress={() => openEdit(r)} style={styles.cardMain}>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.person}>
                          {r.note || 'Utang'} {r.paid ? <Text style={styles.paidTag}>· paid</Text> : null}
                        </Text>
                        <Text style={styles.sub}>
                          {r.dueDate ? `Due ${r.dueDate}` : 'No due date'}
                          {partial ? ` · ${formatMoney(paidSum(r))} of ${formatMoney(r.amount)} paid` : ''}
                        </Text>
                      </View>
                      <Text style={[styles.amount, r.paid && styles.amountPaid]}>
                        {formatMoney(r.paid ? r.amount : remaining)}
                      </Text>
                    </Pressable>
                    {!r.paid ? (
                      <>
                        <View style={styles.actions}>
                          <Pressable onPress={() => remind(r)} hitSlop={{ top: 8, bottom: 8, left: 6, right: 6 }} style={({ pressed }) => [styles.remindBtn, pressed && styles.pressed]}>
                            <Ionicons name="paper-plane-outline" size={15} color={colors.primary} />
                            <Text style={styles.remindText}>Remind</Text>
                          </Pressable>
                          <Pressable
                            onPress={() => {
                              setPayFor(payFor === r.id ? null : r.id);
                              setPayAmt('');
                            }}
                            hitSlop={{ top: 8, bottom: 8, left: 6, right: 6 }}
                            style={({ pressed }) => [styles.remindBtn, pressed && styles.pressed]}
                          >
                            <Text style={styles.remindText}>+ Payment</Text>
                          </Pressable>
                          <Pressable
                            onPress={() => markPaid(r)}
                            hitSlop={{ top: 8, bottom: 8, left: 6, right: 6 }}
                            style={({ pressed }) => [styles.paidBtn, pressed && styles.pressed]}
                          >
                            <Text style={styles.paidBtnText}>Mark paid</Text>
                          </Pressable>
                        </View>
                        {payFor === r.id ? (
                          <View style={styles.payRow}>
                            <TextInput
                              style={[styles.input, styles.payInput]}
                              value={payAmt}
                              onChangeText={setPayAmt}
                              placeholder={`up to ${formatMoney(remaining)}`}
                              placeholderTextColor={colors.faint}
                              keyboardType="numeric"
                              autoFocus
                            />
                            <Pressable onPress={() => logPartial(r)} style={[styles.logBtn]}>
                              <Text style={styles.logBtnText}>Log</Text>
                            </Pressable>
                          </View>
                        ) : null}
                      </>
                    ) : null}
                    {(r.payments || []).length > 0 ? (
                      <View style={styles.payHistory}>
                        <Text style={styles.payHistHead}>Payments</Text>
                        {r.payments.map((p) => (
                          <View key={p.id} style={styles.payHistRow}>
                            <Text style={styles.payHistText}>
                              {formatMoney(p.amount)} <Text style={styles.payHistDate}>· {p.date}</Text>
                            </Text>
                            <Pressable
                              onPress={() => removePayment(r, p)}
                              hitSlop={14}
                              accessibilityRole="button"
                              accessibilityLabel={`Remove ${formatMoney(p.amount)} payment`}
                            >
                              <Ionicons name="close-circle-outline" size={18} color={colors.muted} />
                            </Pressable>
                          </View>
                        ))}
                      </View>
                    ) : null}
                  </Card>
                );
              })}
            </View>
          ))}
          </>
        )}
      </ScrollView>

      <Modal visible={!!form} transparent animationType="slide" onRequestClose={() => setForm(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet} accessibilityViewIsModal={true}>
            <ScrollView>
              <Text style={styles.sheetTitle}>{form?.id ? 'Edit' : 'Add'} person</Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput style={styles.input} value={form?.person} onChangeText={(t) => setForm((f) => ({ ...f, person: t }))} placeholder="e.g. Juan" placeholderTextColor={colors.faint} />
              <Text style={styles.fieldLabel}>Amount owed</Text>
              <TextInput style={[styles.input, form?.id && form?.cashLeg && styles.inputLocked]} value={form?.amount} onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" editable={!(form?.id && form?.cashLeg)} />
              {form?.id && form?.cashLeg ? (
                <Text style={styles.lockNote}>This utang tracked a real cash move, so its amount is locked. To change it, delete and add it again.</Text>
              ) : null}
              {/* Where the lent money left from. Optional: pick an account to
                  track it (it lowers that balance now and counts in net worth,
                  and collecting later returns it), or leave it not tracked. Only
                  offered when adding, since editing must not re-move money. */}
              {!form?.id && (data.accounts || []).length > 0 ? (
                <>
                  <Text style={styles.fieldLabel}>Money came from (optional)</Text>
                  <View style={styles.chips}>
                    <Pressable onPress={() => setForm((f) => ({ ...f, fromAccount: null }))} style={[styles.chip, !form?.fromAccount && styles.chipOn]}>
                      <Text style={[styles.chipText, !form?.fromAccount && styles.chipTextOn]}>Not tracked</Text>
                    </Pressable>
                    {data.accounts.map((a) => {
                      const on = form?.fromAccount === a.id;
                      return (
                        <Pressable key={a.id} onPress={() => setForm((f) => ({ ...f, fromAccount: a.id }))} style={[styles.chip, on && styles.chipOn]}>
                          <Text style={[styles.chipText, on && styles.chipTextOn]}>{a.name}</Text>
                        </Pressable>
                      );
                    })}
                  </View>
                </>
              ) : null}
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

              {err ? (
                <Text
                  style={styles.err}
                  accessibilityRole="alert"
                  accessibilityLiveRegion="assertive"
                >
                  Error: {err}
                </Text>
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

      <Celebration
        key={celebrate?.id}
        visible={!!celebrate}
        message={celebrate?.message}
        onDone={() => setCelebrate(null)}
      />
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

    // The hero surface (radius, border, padding, lift) is owned by <Card variant="hero">; this only sets the gap below it.
    totalCard: { marginBottom: spacing.lg },
    splitBtn: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      gap: spacing.sm,
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      minHeight: 48,
      marginBottom: spacing.lg,
    },
    splitText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    total: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    group: { marginBottom: spacing.lg },
    groupHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', minHeight: 44, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    groupRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
    groupName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, flex: 1 },
    groupOwed: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    groupSettled: { color: colors.muted, fontWeight: fontWeight.regular },
    payHistory: { marginTop: spacing.md, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: spacing.sm },
    payHistHead: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1, marginBottom: spacing.xs },
    payHistRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.xs },
    payHistText: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    payHistDate: { color: colors.muted, fontWeight: fontWeight.regular },
    payRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm, alignItems: 'center' },
    payInput: { flex: 1 },
    logBtn: { backgroundColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.md, paddingHorizontal: spacing.lg },
    logBtnText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    // The card surface is owned by <Card variant="flat">; this only sets the gap below each utang card.
    cardGap: { marginBottom: spacing.md },
    cardPaid: { opacity: 0.6 },
    cardMain: { flexDirection: 'row', alignItems: 'center' },
    person: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    paidTag: { color: colors.muted, fontWeight: fontWeight.regular, fontSize: fontSize.small },
    sub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    amount: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    amountPaid: { color: colors.muted },
    actions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.md },
    pressed: { opacity: 0.6 },
    remindBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.md, paddingHorizontal: spacing.md },
    remindText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    paidBtn: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, paddingVertical: spacing.sm, paddingHorizontal: spacing.md },
    paidBtnText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    chipTextOn: { color: colors.onPrimary },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    inputLocked: { opacity: 0.6 },
    lockNote: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs, lineHeight: 16 },
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
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
