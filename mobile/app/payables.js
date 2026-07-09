// People I owe (payables). Track who you owe, how much, and when it is due.
// Mark paid, log partial payments, edit, delete. All saved on the device.
//
// This is the exact mirror of receivables (People who owe me), just the other
// direction. Paying an utang here records it on the payable (payments list and
// paid flag) AND posts a REAL EXPENSE that lowers your default account
// balance, the mirror of how receivables posts income when someone pays you
// back. Every payment path both posts an expense and, on remove or delete,
// reverses it, so balances can never drift. There is no Remind action and no
// split a bill entry, because those do not fit money you owe, and there is no
// borrow or lender affordance of any kind.

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Modal,
  Platform,
  Pressable,
  ScrollView,
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

export default function Payables() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem, addTransaction, removeTransaction } = useAppData();

  const [form, setForm] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);
  const [err, setErr] = useState('');
  // Inline partial payment: which payable is taking a payment, and the amount
  // being typed.
  const [payFor, setPayFor] = useState(null);
  const [payAmt, setPayAmt] = useState('');
  // A warm, transient affirmation shown after an utang is fully paid. It is
  // plain text, so it delights without blocking input or animating anything.
  const [praise, setPraise] = useState('');
  const praiseTimer = useRef(null);
  // Clear the affirmation timer on unmount, so tapping back within 3.5s of
  // paying off an utang does not set state on an unmounted screen.
  useEffect(() => () => clearTimeout(praiseTimer.current), []);

  const list = data.payables || [];
  const people = data.people || [];

  // Partial payments: what is still owed on one payable.
  const paidSum = (r) => (r.payments || []).reduce((t, p) => t + (Number(p.amount) || 0), 0);
  const remainingOf = (r) => Math.max(0, (Number(r.amount) || 0) - paidSum(r));
  const owedTotal = list.filter((r) => !r.paid).reduce((t, r) => t + remainingOf(r), 0);

  // The encouraging progress line: how much of everything you owe you have
  // already paid off. A settled utang counts as fully paid even when it was
  // marked paid from the form without logging individual payments, so the line
  // never reads "paid 0" for an utang the card already shows as paid.
  const paidAcross = list.reduce((t, r) => t + (r.paid ? (Number(r.amount) || 0) : paidSum(r)), 0);
  const totalAcross = list.reduce((t, r) => t + (Number(r.amount) || 0), 0);

  // The display name for a payable: the person record wins (it follows
  // renames), the legacy person string is the fallback.
  const nameOf = (r) => {
    const p = people.find((x) => x.id === r.personId);
    return (p && p.name) || r.person || 'Someone';
  };

  // Group by person for the ledger view: every group has a name, the payables
  // newest first, and how much you still owe that person in total.
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

  function praiseNow() {
    setPraise('Bayad na! One less utang. 🎉');
    if (praiseTimer.current) clearTimeout(praiseTimer.current);
    praiseTimer.current = setTimeout(() => setPraise(''), 3500);
  }

  function openAdd() {
    setForm({ id: null, person: '', amount: '', dueDate: '', phone: '', note: '', paid: false });
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
    // Editing the total below what is already paid would make "paid of total"
    // read as nonsense and drop the utang out of the totals while still owing.
    // Refuse it, and point at the real fix.
    if (form.id) {
      const existing = list.find((x) => x.id === form.id);
      const already = existing ? paidSum(existing) : 0;
      if (amount < already) {
        setErr(`Already ${formatMoney(already)} paid on this. The amount cannot be lower than that. Remove a payment first if you need to.`);
        return;
      }
    }
    // The date must be real, not just shaped right: 2026-02-30 rolls over to
    // March in JavaScript and reminders would fire on the wrong day.
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
    // post a settling expense. A double tap must run it exactly once. All the
    // early returns above are pure validation, so the guard sits here, after
    // the last of them, and clears on the next beat like settleOnce does.
    if (saveBusy.current) return;
    saveBusy.current = true;
    setTimeout(() => { saveBusy.current = false; }, 400);
    // Find or create the person record so "Nanay" is one ledger entry no
    // matter how many utang you rack up with them. This reuses the SHARED
    // people collection, so a person can be both someone who owes you and
    // someone you owe. Case and spacing insensitive.
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
    if (form.id) updateItem('payables', form.id, payload);
    else id = addItem('payables', { ...payload, payments: [], paid: false });

    // Reconcile the "Marked as paid" toggle through the same money path as the
    // Mark paid button, so it can never leave an utang shown as paid with no
    // expense recorded, or reopened with a phantom expense left behind. The
    // settling payment is tagged settled so turning the toggle back off knows
    // exactly which entries to reverse, while genuine partial payments stay.
    const priorPayments = existing ? (existing.payments || []) : [];
    if (form.paid) {
      // Post expense for whatever is still owed and record it as a settling
      // payment. This one branch covers a fresh paid utang, flipping an unpaid
      // one to paid, AND raising the amount of an already paid one (the top up
      // is posted too), so the recorded expense always matches the paid total.
      const priorPaid = priorPayments.reduce((t, p) => t + (Number(p.amount) || 0), 0);
      const remaining = Math.max(0, amount - priorPaid);
      let payments = priorPayments;
      if (remaining > 0) {
        const txnId = postExpense({ person: name, personId: person.id }, remaining);
        payments = [...priorPayments, { id: genId('ppay'), amount: remaining, date: todayISO(), txnId, settled: true }];
      }
      updateItem('payables', id, { paid: true, payments });
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
      updateItem('payables', id, { paid: false, payments });
    }
    setForm(null);
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) {
      // Reverse every expense entry this utang's payments posted, so a
      // deleted payable never leaves a phantom expense and a deflated
      // balance behind. Payments logged before expense posting carry no
      // link, so there is nothing to reverse for those, which is honest.
      const r = list.find((x) => x.id === form.id);
      (r?.payments || []).forEach((p) => {
        if (p.txnId) removeTransaction(p.txnId);
      });
      removeItem('payables', form.id);
    }
    setForm(null);
  }

  // The account a payment comes out of, for honest confirm copy. Null when no
  // default is set: the expense still records, it just does not move a specific
  // balance (mirror of how postIncome falls back to an unlinked entry).
  const payAccount = () => {
    const def = data.settings.defaultAccountId;
    return (def && data.accounts.find((a) => a.id === def)) || null;
  };

  // Paying an utang is a real expense: money leaves the remembered account when
  // one is set, so cash flow and balances agree with what happened instead of
  // the utang just silently vanishing. This is the exact mirror of receivables'
  // postIncome, expense not income. Returns the new transaction id so the
  // payment can remember it and reverse it later.
  function postExpense(r, amount) {
    if (amount <= 0) return '';
    const def = data.settings.defaultAccountId;
    const accountId = def && data.accounts.some((a) => a.id === def) ? def : '';
    const entry = { type: 'expense', label: `You paid ${nameOf(r)}`, amount, date: todayISO() };
    return addTransaction(accountId ? { ...entry, accountId } : entry);
  }

  // A double tap on Save must not run the money reconcile twice: both taps
  // would see the same pre-save state, post two settling expenses, and create a
  // duplicate item. One beat of quiet, same idea as settleOnce below.
  const saveBusy = useRef(false);
  // Stacked confirm dialogs or a double tap must not record a payment twice
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

  // Mark paid settles whatever is STILL owed after partial payments. It
  // confirms first so a slip of the finger does not invent an expense, then
  // records the settling payment AND posts a real expense for the remaining
  // amount. The settling payment remembers its expense entry (txnId) so it can
  // be reversed. This mirrors receivables' markPaid exactly, expense not income.
  function markPaid(r) {
    const remaining = remainingOf(r);
    const doIt = () => settleOnce(() => {
      let payments = r.payments || [];
      if (remaining > 0) {
        const txnId = postExpense(r, remaining);
        payments = [...payments, { id: genId('ppay'), amount: remaining, date: todayISO(), txnId, settled: true }];
      }
      updateItem('payables', r.id, { paid: true, payments });
      praiseNow();
    });
    const acct = payAccount();
    const message =
      remaining > 0
        ? (acct
            ? `Record ${formatMoney(remaining)} paid to ${nameOf(r)} and close this utang? This logs an expense of ${formatMoney(remaining)} from ${acct.name} and lowers your balance, just like real bayad.`
            : `Record ${formatMoney(remaining)} paid to ${nameOf(r)} and close this utang? This logs an expense of ${formatMoney(remaining)}. No default account is set, so no balance moves, set one in Settings to track the cash leaving.`)
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

  // A partial payment: "I gave Nanay 300 of the 800." Records the payment on
  // the payable, posts the expense, and settles the utang by itself when the
  // last peso is paid. Mirror of receivables' logPartial, expense not income.
  function logPartial(r) {
    const amount = Number(String(payAmt).replace(/[, ]/g, ''));
    const remaining = remainingOf(r);
    if (!Number.isFinite(amount) || amount <= 0) return;
    const applied = Math.min(amount, remaining);
    // Nothing left to pay means nothing to record: no phantom zero payment
    // rows on an already covered utang.
    if (applied <= 0) return;
    settleOnce(() => {
      // Post the expense first so the payment can remember its entry and
      // reverse it if the user removes the payment later.
      const txnId = postExpense(r, applied);
      const payment = { id: genId('ppay'), amount: applied, date: todayISO(), txnId };
      const willSettle = applied >= remaining;
      updateItem('payables', r.id, {
        payments: [...(r.payments || []), payment],
        paid: willSettle,
      });
      setPayFor(null);
      setPayAmt('');
      if (willSettle) praiseNow();
    });
  }

  // Remove one logged payment: reverse its expense entry (so the balance and
  // cash flow correct themselves), drop the payment row, and reopen the utang
  // if it was fully paid. Mirror of receivables' removePayment. This is the fix
  // for a fat fingered amount.
  function removePayment(r, payment) {
    const doIt = () => settleOnce(() => {
      if (payment.txnId) removeTransaction(payment.txnId);
      const payments = (r.payments || []).filter((p) => p.id !== payment.id);
      const newPaidSum = payments.reduce((t, p) => t + (Number(p.amount) || 0), 0);
      // Fully covered stays paid; otherwise removing a payment reopens it.
      const stillPaid = r.paid && newPaidSum >= (Number(r.amount) || 0);
      updateItem('payables', r.id, { payments, paid: stillPaid });
    });
    const message = payment.txnId
      ? `Remove this ${formatMoney(payment.amount)} payment? Its expense entry will be reversed too.`
      : `Remove this ${formatMoney(payment.amount)} payment? It was logged before expense tracking, so no expense entry is linked to reverse.`;
    if (Platform.OS === 'web') {
      if (typeof window !== 'undefined' && window.confirm(message)) doIt();
      return;
    }
    Alert.alert('Remove payment?', message, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: doIt },
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
        <Text style={styles.headerTitle}>People I owe</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <Card variant="hero" style={styles.totalCard}>
          <Text style={styles.kicker}>TOTAL UTANG TO PAY</Text>
          <Text style={styles.total} accessibilityLabel={`${formatMoney(owedTotal)} pesos`}>{formatMoney(owedTotal)}</Text>
          {totalAcross > 0 ? (
            <Text style={styles.progress}>
              {paidAcross > 0
                ? `You have paid off ${formatMoney(paidAcross)} of ${formatMoney(totalAcross)} so far. Kaya mo yan.`
                : 'Bayaran natin ito, unti-unti. Kahit maliit na hulog, okay lang.'}
            </Text>
          ) : null}
        </Card>

        {praise ? (
          <View style={styles.praise} accessibilityLiveRegion="polite">
            <Text style={styles.praiseText}>{praise}</Text>
          </View>
        ) : null}

        {list.length === 0 ? (
          <EmptyState icon="🫶" title="You owe no one" subtitle="Tap + Add to track money you owe." />
        ) : (
          <>
          <SectionHeader title="WHO YOU OWE" />
          {groups.map((g) => (
            <View key={g.key} style={styles.group}>
              <View style={styles.groupHeader}>
                <Text style={styles.groupName} numberOfLines={1}>{g.name}</Text>
                <Text style={[styles.groupOwed, g.owed === 0 && styles.groupSettled]}>
                  {g.owed > 0 ? `you owe ${formatMoney(g.owed)}` : 'all settled'}
                </Text>
              </View>
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
                          <Pressable
                            onPress={() => {
                              setPayFor(payFor === r.id ? null : r.id);
                              setPayAmt('');
                            }}
                            hitSlop={{ top: 8, bottom: 8, left: 6, right: 6 }}
                            style={({ pressed }) => [styles.actionBtn, pressed && styles.pressed]}
                          >
                            <Text style={styles.actionText}>+ Payment</Text>
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
                          <>
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
                            <Text style={styles.payHint}>
                              {payAccount()
                                ? `This logs an expense from ${payAccount().name} and lowers your balance.`
                                : 'This logs an expense. No default account is set yet, so no balance changes. Set one in Settings to track the cash leaving.'}
                            </Text>
                          </>
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
              <Text style={styles.sheetTitle}>{form?.id ? 'Edit' : 'Add'} utang</Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput style={styles.input} value={form?.person} onChangeText={(t) => setForm((f) => ({ ...f, person: t }))} placeholder="e.g. Nanay" placeholderTextColor={colors.faint} />
              <Text style={styles.fieldLabel}>Amount you owe</Text>
              <TextInput style={styles.input} value={form?.amount} onChangeText={(t) => setForm((f) => ({ ...f, amount: t }))} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
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
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    total: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.bold, marginTop: spacing.xs },
    progress: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.sm, lineHeight: 19 },

    praise: {
      alignSelf: 'flex-start',
      backgroundColor: colors.positiveSurface,
      borderColor: colors.positiveBorder,
      borderWidth: 1,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
      marginBottom: spacing.lg,
    },
    praiseText: { color: colors.celebrate, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    group: { marginBottom: spacing.lg },
    groupHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', minHeight: 44, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
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
    payHint: { color: colors.faint, fontSize: fontSize.caption, marginTop: spacing.xs },
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
    actionBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.md, paddingHorizontal: spacing.md },
    actionText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
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
