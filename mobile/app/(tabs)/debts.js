// Debts screen, wired to the data store. Shows total debt, a Snowball vs
// Avalanche strategy switch, the focus debt, and debts grouped by term. You
// can add and edit debts, log a payment (which lowers the balance and is
// recorded), and mark a debt paid off. Everything saves on the device.

import { useMemo, useRef, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, todayISO } from '../../lib/format';
import { cardForecast, buildSOA } from '../../lib/soa';
import { splitDebtPayment } from '../../lib/analytics';
import EmptyState from '../../components/EmptyState';
import Celebration from '../../components/motion/Celebration';

const SHORT_TERM_TYPES = ['credit card', 'bnpl', 'short term', 'insurance'];
const termOf = (type) => (SHORT_TERM_TYPES.includes(type) ? 'short' : 'long');
const monthlyInterest = (d) => Math.round((d.remaining * d.monthlyRate) / 100);
const today = todayISO;

const DEBT_TYPES = [
  'credit card',
  'bnpl',
  'personal loan',
  'mortgage',
  'auto',
  'short term',
  'long term',
  'insurance',
  'other',
];

export default function Debts() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, addItem, updateItem, removeItem, addTransaction } = useAppData();

  const [strategy, setStrategy] = useState('snowball');
  const [form, setForm] = useState(null); // add/edit modal
  const [payAmount, setPayAmount] = useState('');
  const [payFrom, setPayFrom] = useState(null); // account the payment comes from
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [confirmDel, setConfirmDel] = useState(false);
  const [confirmPaidOff, setConfirmPaidOff] = useState(false);
  // The win overlay shown when a debt is cleared to zero.
  const [celebrate, setCelebrate] = useState(null);

  const debts = data.debts;
  const sum = (list, fn) => list.reduce((t, d) => t + fn(d), 0);
  const totalDebt = sum(debts, (d) => d.remaining);
  const totalMin = sum(debts, (d) => d.minPayment);
  const totalInterest = sum(debts, monthlyInterest);

  const ordered = [...debts].sort((a, b) =>
    strategy === 'snowball' ? a.remaining - b.remaining : b.monthlyRate - a.monthlyRate
  );
  const focus = ordered.find((d) => d.remaining > 0) || ordered[0];

  const shortTerm = debts.filter((d) => termOf(d.type) === 'short');
  const longTerm = debts.filter((d) => termOf(d.type) === 'long');

  // Statement forecast and pending payments for the debt being edited.
  const editDebt = form && form.id ? debts.find((d) => d.id === form.id) : null;
  const forecast =
    editDebt && editDebt.type === 'credit card' && (editDebt.dueDay || editDebt.statementDay)
      ? cardForecast(editDebt, data.payments)
      : null;
  const pendingPays = editDebt
    ? (data.payments || []).filter((p) => p.debtId === editDebt.id && p.status === 'pending')
    : [];
  const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const fmtDate = (d) => (d ? `${MONTHS_SHORT[d.getMonth()]} ${d.getDate()}` : '');

  function openAdd() {
    setForm({ id: null, name: '', type: 'credit card', remaining: '', monthlyRate: '', minPayment: '', dueDay: '', statementDay: '', graceDays: '', creditLimit: '' });
    setPayAmount('');
    setMsg('');
    setErr('');
    setConfirmDel(false);
    setConfirmPaidOff(false);
  }
  function openEdit(d) {
    setForm({
      id: d.id,
      name: d.name,
      type: d.type,
      remaining: String(d.remaining),
      monthlyRate: String(d.monthlyRate),
      minPayment: String(d.minPayment),
      dueDay: d.dueDay ? String(d.dueDay) : '',
      statementDay: d.statementDay ? String(d.statementDay) : '',
      graceDays: d.graceDays ? String(d.graceDays) : '',
      creditLimit: d.creditLimit ? String(d.creditLimit) : '',
    });
    setPayAmount(String(d.minPayment));
    // Default to Outside the app: money must only leave an account the
    // user explicitly picked, never whichever account happens to be first.
    setPayFrom(null);
    setMsg('');
    setErr('');
    setConfirmDel(false);
    setConfirmPaidOff(false);
  }
  function close() {
    setForm(null);
    setConfirmPaidOff(false);
  }
  function save() {
    if (!form.name.trim()) {
      setErr('Please enter a name.');
      return;
    }
    // Money fields accept commas, "50,000" is fifty thousand here like in
    // every other money input in the app.
    const numIn = (t) => Number(String(t).replace(/[, ]/g, ''));
    const rem = numIn(form.remaining);
    const rate = numIn(form.monthlyRate);
    const min = numIn(form.minPayment);
    if (form.remaining === '' || !Number.isFinite(rem) || rem < 0) {
      setErr('Enter a valid remaining balance.');
      return;
    }
    if (!Number.isFinite(rate) || rate < 0) {
      setErr('Enter a valid interest %.');
      return;
    }
    if (!Number.isFinite(min) || min < 0) {
      setErr('Enter a valid minimum payment.');
      return;
    }
    // Day-of-month fields are optional, but when present must be 1 to 31.
    const dayField = (text, label) => {
      const t = String(text || '').trim();
      if (!t) return { ok: true, value: 0 };
      const n = Number(t);
      if (!Number.isInteger(n) || n < 1 || n > 31) {
        setErr(`${label} should be a day from 1 to 31.`);
        return { ok: false, value: 0 };
      }
      return { ok: true, value: n };
    };
    const dueRes = dayField(form.dueDay, 'Payment due day');
    if (!dueRes.ok) return;
    // The card only fields are validated and saved ONLY for credit cards.
    // Switching a card to another type clears them, otherwise a hidden
    // field could block Save with an error the user cannot see, or leave
    // statement schedules silently attached to a loan.
    const isCard = form.type === 'credit card';
    const stmtRes = isCard ? dayField(form.statementDay, 'Statement day') : { ok: true, value: 0 };
    if (!stmtRes.ok) return;
    let grace = 0;
    let limit = 0;
    if (isCard) {
      const graceText = String(form.graceDays || '').trim();
      grace = graceText === '' ? 0 : Number(graceText);
      if (graceText !== '' && (!Number.isInteger(grace) || grace < 1 || grace > 60)) {
        setErr('Days before due should be from 1 to 60.');
        return;
      }
      const limitText = String(form.creditLimit || '').trim().replace(/[, ]/g, '');
      limit = limitText === '' ? 0 : Number(limitText);
      if (limitText !== '' && (!Number.isFinite(limit) || limit < 0)) {
        setErr('Enter a valid credit limit, or leave it empty.');
        return;
      }
      // A statement day alone gives no due date, so reminders would stay
      // silent while the user believes they are covered. Ask for the one
      // missing piece instead of failing quietly.
      if (stmtRes.value && !dueRes.value && grace === 0) {
        setErr('Add the days after statement until due (check your SOA, usually about 20), or a fixed due day, so reminders know when payment is due.');
        return;
      }
    }
    const payload = {
      name: form.name.trim(),
      type: form.type,
      remaining: rem,
      monthlyRate: rate,
      minPayment: min,
      dueDay: dueRes.value,
      statementDay: isCard ? stmtRes.value : 0,
      graceDays: grace,
      creditLimit: limit,
    };
    if (form.id) {
      // A typed in balance is current as of today, so reset the interest clock
      // when the remaining balance is edited. Without this the next payment
      // would accrue interest for the gap before a balance you just corrected.
      const existing = data.debts.find((d) => d.id === form.id);
      if (!existing || Number(existing.remaining) !== rem) payload.interestThroughISO = today();
      updateItem('debts', form.id, payload);
    } else {
      // New debt: start the interest clock now, so a first payment does not
      // back accrue interest for time before the debt existed in the app.
      addItem('debts', { ...payload, interestThroughISO: today() });
    }
    close();
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (form.id) removeItem('debts', form.id);
    close();
  }
  // One shared payment path. Logging an amount and Mark paid off both go
  // through here, so every peso that leaves a debt also leaves the chosen
  // account, lands in the payments list, and writes a record row into the
  // transaction stream that History shows. The record row carries no
  // accountId on purpose: the balance move happens right here, and a record
  // deleted later from History must never shift a balance again.
  const payBusy = useRef(false);
  function applyPayment(amt) {
    if (!form.id || amt <= 0) return;
    // A double tap before React re-renders would read the same balances
    // twice and write the payment ledger twice while the money only moved
    // once. Ignore re-entrant taps for a beat.
    if (payBusy.current) return;
    payBusy.current = true;
    setTimeout(() => {
      payBusy.current = false;
    }, 400);
    // Read the balance from the store, never from the edit field: a cleared
    // or half-typed Remaining box must not zero out a real debt.
    const debt = data.debts.find((d) => d.id === form.id);
    const cur = debt ? Number(debt.remaining) || 0 : Number(form.remaining) || 0;
    const rate = debt ? Number(debt.monthlyRate) || 0 : Number(form.monthlyRate) || 0;
    // Split the payment into interest and principal by day-count accrual (see
    // splitDebtPayment). A first payment on a debt with no stamp accrues 0 (we
    // never back accrue history we did not have), then the clock starts, so two
    // payments in one month never book two months of interest. applied is
    // clamped to what is owed, fixing the old overpayment cash-loss.
    const stamp = today();
    const { accrued, applied, interest: interestPortion, principal: principalPortion, newRemaining: newRem, overpay } =
      splitDebtPayment(cur, rate, debt && debt.interestThroughISO, amt, stamp);
    updateItem('debts', form.id, { remaining: newRem, interestThroughISO: stamp });
    // Cash leaves only for what was actually applied, so an overpayment is never
    // taken from the account.
    const acct = data.accounts.find((a) => a.id === payFrom);
    if (acct && applied > 0) updateItem('accounts', acct.id, { balance: acct.balance - applied });
    // Credit card payments start as pending, because banks take a day or
    // three to post them. Other debts post right away.
    const isCard = (debt ? debt.type : form.type) === 'credit card';
    addItem('payments', {
      debtId: form.id,
      amount: applied,
      interest: interestPortion,
      principal: principalPortion,
      date: today(),
      account: acct ? acct.id : '',
      status: isCard ? 'pending' : 'posted',
    });
    const name = (debt && debt.name) || form.name || 'Debt';
    // Principal paydown is a balance sheet move (financing), not spending: a
    // debt record row that the income and expense filters skip.
    if (principalPortion > 0) {
      addTransaction({
        type: 'debt',
        label: `Debt payment: ${name}`,
        amount: principalPortion,
        date: today(),
        debtId: form.id,
      });
    }
    // Interest is a real cost, a genuine expense. Recorded without an accountId
    // (the cash already left via the applied debit above), so it counts in
    // spending and the income statement without moving a balance twice.
    if (interestPortion > 0) {
      addTransaction({
        type: 'expense',
        label: `Interest: ${name}`,
        amount: interestPortion,
        date: today(),
        debtId: form.id,
        source: 'interest',
      });
    }
    setForm((f) => ({ ...f, remaining: String(newRem) }));
    let msg = `Logged ${formatMoney(applied)}${acct ? ` from ${acct.name}` : ''}.`;
    if (interestPortion > 0) msg += ` ${formatMoney(interestPortion)} of it was interest.`;
    // Balance only grows when the payment falls short of the interest that
    // accrued. Paying exactly the interest holds it flat, so do not claim growth.
    if (applied < accrued) msg += ` That did not cover the interest, so the balance grew.`;
    if (overpay > 0) msg += ` ${formatMoney(overpay)} was more than you owed and was not taken.`;
    msg += ` New balance ${formatMoney(newRem)}.`;
    setMsg(msg);
    // Cleared to zero from a real balance: a debt is gone. The best moment in
    // the app to celebrate. Covers both a full mark paid off and a partial
    // payment that happens to finish it, since both route through here. Close
    // the edit modal first, or the celebration renders behind it (a Modal is a
    // separate native window on top) and the user never sees it.
    if (newRem === 0 && cur > 0) {
      setForm(null);
      setCelebrate({ message: `${name} paid off! Utang free.`, id: Date.now() });
    }
    return newRem;
  }
  function logPayment() {
    setConfirmPaidOff(false);
    applyPayment(Number(String(payAmount).replace(/[, ]/g, '')) || 0);
  }
  // Mark paid off is a real payment of everything still owed, from the
  // chosen account (or Outside the app), never a silent zeroing that makes
  // money vanish from nowhere. Two taps to confirm, same as Delete.
  function markPaid() {
    if (!form.id) return;
    const debt = data.debts.find((d) => d.id === form.id);
    const remaining = debt ? Number(debt.remaining) || 0 : 0;
    if (remaining <= 0) {
      setMsg('Already at zero.');
      return;
    }
    if (!confirmPaidOff) {
      setConfirmPaidOff(true);
      return;
    }
    setConfirmPaidOff(false);
    // Pay the FULL balance including interest accrued since the last payment, so
    // "Mark paid off" truly zeroes the debt instead of leaving the accrued
    // interest behind. splitDebtPayment gives that balance for the same inputs
    // applyPayment will use, so applied clamps to it and the debt lands at 0.
    const rate = debt ? Number(debt.monthlyRate) || 0 : 0;
    const { balance } = splitDebtPayment(remaining, rate, debt && debt.interestThroughISO, 0, today());
    applyPayment(balance > 0 ? balance : remaining);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Debts</Text>

        <View style={styles.card}>
          <Text style={styles.kicker}>TOTAL DEBT</Text>
          <Text style={styles.totalDebt}>{formatMoney(totalDebt)}</Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Minimum due this month</Text>
              <Text style={styles.smallValue}>{formatMoney(totalMin)}</Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Interest this month</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>{formatMoney(totalInterest)}</Text>
            </View>
          </View>
        </View>

        <Pressable onPress={openAdd} style={({ pressed }) => [styles.addBtn, pressed && styles.pressed]}>
          <Text style={styles.addBtnText}>+ Add debt</Text>
        </Pressable>

        <View style={styles.cardPad}>
          <Text style={styles.kicker}>PAYOFF STRATEGY</Text>
          <View style={styles.toggleRow}>
            {[
              { key: 'snowball', label: 'Snowball' },
              { key: 'avalanche', label: 'Avalanche' },
            ].map((opt) => {
              const on = strategy === opt.key;
              return (
                <Pressable key={opt.key} onPress={() => setStrategy(opt.key)} style={[styles.toggle, on && styles.toggleOn]}>
                  <Text style={[styles.toggleText, on && styles.toggleTextOn]}>{opt.label}</Text>
                </Pressable>
              );
            })}
          </View>
          <Text style={styles.strategyNote}>
            {strategy === 'snowball'
              ? 'Pay the smallest balance first for quick wins.'
              : 'Pay the highest interest first to save the most money.'}
          </Text>
        </View>

        {focus && focus.remaining > 0 ? (
          <View style={styles.focusCard}>
            <Text style={styles.focusKicker}>FOCUS DEBT</Text>
            <Text style={styles.focusName}>{focus.name}</Text>
            <Text style={styles.focusSub}>
              {formatMoney(focus.remaining)} left . put any extra money here first.
            </Text>
          </View>
        ) : null}

        <Group title="SHORT TERM" list={shortTerm} styles={styles} colors={colors} onPick={openEdit} />
        <Group title="LONG TERM" list={longTerm} styles={styles} colors={colors} onPick={openEdit} />

        {debts.length === 0 ? (
          <EmptyState icon="🎉" title="No debts" subtitle="Add a debt to track payoff, or enjoy being debt free." />
        ) : null}
      </ScrollView>

      {/* Add / edit / pay modal. */}
      <Modal visible={!!form} transparent animationType="slide" onRequestClose={close}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView>
              <Text style={styles.sheetTitle}>{form?.id ? 'Edit debt' : 'Add debt'}</Text>

              <Text style={styles.fieldLabel}>Name</Text>
              <TextInput
                style={styles.input}
                value={form?.name}
                onChangeText={(t) => setForm((f) => ({ ...f, name: t }))}
                placeholder="e.g. Credit Card"
                placeholderTextColor={colors.faint}
              />

              <Text style={styles.fieldLabel}>Type</Text>
              <View style={styles.chips}>
                {DEBT_TYPES.map((t) => {
                  const on = form?.type === t;
                  return (
                    <Pressable key={t} onPress={() => setForm((f) => ({ ...f, type: t }))} style={[styles.chip, on && styles.chipOn]}>
                      <Text style={[styles.chipText, on && styles.chipTextOn]}>{t}</Text>
                    </Pressable>
                  );
                })}
              </View>

              <Text style={styles.fieldLabel}>Remaining balance</Text>
              <TextInput
                style={styles.input}
                value={form?.remaining}
                onChangeText={(t) => setForm((f) => ({ ...f, remaining: t }))}
                placeholder="0"
                placeholderTextColor={colors.faint}
                keyboardType="numeric"
              />
              <Text style={styles.fieldLabel}>Monthly interest %</Text>
              <TextInput
                style={styles.input}
                value={form?.monthlyRate}
                onChangeText={(t) => setForm((f) => ({ ...f, monthlyRate: t }))}
                placeholder="check your SOA, PH cards charge up to 3% monthly"
                placeholderTextColor={colors.faint}
                keyboardType="numeric"
              />
              {form?.type === 'credit card' ? (
                <Text style={styles.fieldHint}>
                  This rate applies to a balance you carry past the due date. If you pay
                  your card in full every month, you are inside the grace period and pay no
                  interest, so set this to 0.
                </Text>
              ) : null}
              <Text style={styles.fieldLabel}>Minimum payment</Text>
              <TextInput
                style={styles.input}
                value={form?.minPayment}
                onChangeText={(t) => setForm((f) => ({ ...f, minPayment: t }))}
                placeholder="0"
                placeholderTextColor={colors.faint}
                keyboardType="numeric"
              />
              <Text style={styles.fieldLabel}>Payment due day of the month (optional)</Text>
              <TextInput
                style={styles.input}
                value={form?.dueDay}
                onChangeText={(t) => setForm((f) => ({ ...f, dueDay: t }))}
                placeholder="e.g. 10"
                placeholderTextColor={colors.faint}
                keyboardType="numeric"
              />
              {form?.type === 'credit card' ? (
                <>
                  <Text style={styles.fieldLabel}>Statement cut off day (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.statementDay}
                    onChangeText={(t) => setForm((f) => ({ ...f, statementDay: t }))}
                    placeholder="e.g. 25"
                    placeholderTextColor={colors.faint}
                    keyboardType="numeric"
                  />
                  <Text style={styles.fieldLabel}>Days after statement until due (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.graceDays}
                    onChangeText={(t) => setForm((f) => ({ ...f, graceDays: t }))}
                    placeholder="e.g. 20, check your SOA, used when no fixed due day"
                    placeholderTextColor={colors.faint}
                    keyboardType="numeric"
                  />
                  <Text style={styles.fieldLabel}>Credit limit (optional)</Text>
                  <TextInput
                    style={styles.input}
                    value={form?.creditLimit}
                    onChangeText={(t) => setForm((f) => ({ ...f, creditLimit: t }))}
                    placeholder="e.g. 50000"
                    placeholderTextColor={colors.faint}
                    keyboardType="numeric"
                  />
                </>
              ) : null}

              {/* Payment tools, only when editing an existing debt. */}
              {form?.id ? (
                <View style={styles.payBox}>
                  <Text style={styles.fieldLabel}>Log a payment</Text>
                  <View style={styles.payRow}>
                    <TextInput
                      style={[styles.input, styles.payInput]}
                      value={payAmount}
                      onChangeText={setPayAmount}
                      placeholder="0"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Pressable onPress={logPayment} style={[styles.sheetBtn, styles.saveBtn]}>
                      <Text style={styles.saveText}>Log</Text>
                    </Pressable>
                  </View>
                  <Text style={styles.fieldLabel}>Paid from</Text>
                  <View style={styles.chips}>
                    {data.accounts.map((a) => {
                      const on = payFrom === a.id;
                      return (
                        <Pressable key={a.id} onPress={() => setPayFrom(a.id)} style={[styles.chip, on && styles.chipOn]}>
                          <Text style={[styles.chipText, on && styles.chipTextOn]}>{a.name}</Text>
                        </Pressable>
                      );
                    })}
                    <Pressable onPress={() => setPayFrom(null)} style={[styles.chip, payFrom === null && styles.chipOn]}>
                      <Text style={[styles.chipText, payFrom === null && styles.chipTextOn]}>Outside the app</Text>
                    </Pressable>
                  </View>
                  <Pressable onPress={markPaid} style={styles.markPaid}>
                    <Text style={styles.markPaidText}>
                      {confirmPaidOff
                        ? `Tap again to log ${formatMoney(Number(editDebt ? editDebt.remaining : 0) || 0)} as paid`
                        : 'Mark paid off'}
                    </Text>
                  </Pressable>
                  {msg ? <Text style={styles.msg}>{msg}</Text> : null}
                </View>
              ) : null}

              {/* Statement of account forecast for credit cards. */}
              {forecast ? (
                <View style={styles.payBox}>
                  <Text style={styles.fieldLabel}>SOA forecast</Text>
                  {forecast.statement ? (
                    <Text style={styles.soaLine}>Next statement cuts {fmtDate(forecast.statement)}</Text>
                  ) : null}
                  {forecast.due ? (
                    <Text style={styles.soaLine}>
                      Payment due {fmtDate(forecast.due)}
                      {forecast.dueMoved
                        ? `, moved from ${fmtDate(forecast.dueRaw)} because that is ${forecast.dueMovedReason}`
                        : ''}
                    </Text>
                  ) : null}
                  <Text style={styles.soaLine}>
                    Forecast balance {formatMoney(forecast.forecastBalance)}
                    {forecast.pending > 0 ? ` (${formatMoney(forecast.pending)} still pending)` : ''}
                  </Text>
                  {forecast.utilization !== null ? (
                    <Text style={styles.soaLine}>
                      Credit used {Math.min(Math.round(forecast.utilization * 100), 999)}% of{' '}
                      {formatMoney(forecast.creditLimit)}
                      {forecast.utilization > 0.3 ? '. Below 30% is the healthy zone.' : ''}
                    </Text>
                  ) : null}
                  <Text style={styles.soaHint}>
                    Pay the full {formatMoney(forecast.forecastBalance)} so new purchases stay
                    interest free, or at least {formatMoney(forecast.minDue)} to avoid late fees.
                  </Text>
                  {forecast.lateInterest > 0 ? (
                    <Text style={styles.soaWarn}>
                      Paying late or minimum only adds about {formatMoney(forecast.lateInterest)} interest
                      next month, plus the bank late fee if you miss the date.
                    </Text>
                  ) : forecast.forecastBalance > 0 ? (
                    <Text style={styles.soaWarn}>
                      No interest rate is saved for this card, so this forecast shows zero
                      interest. Check your SOA for the real rate (PH cards charge up to 3%
                      monthly) and add it above.
                    </Text>
                  ) : null}
                  <Pressable
                    onPress={() => Share.share({ message: buildSOA(editDebt, data.payments) }).catch(() => {})}
                    style={({ pressed }) => [styles.soaShareBtn, pressed && { opacity: 0.6 }]}
                  >
                    <Text style={styles.soaShareText}>Share this SOA forecast</Text>
                  </Pressable>
                </View>
              ) : null}

              {/* Card payments the bank has not posted yet. */}
              {pendingPays.length > 0 ? (
                <View style={styles.payBox}>
                  <Text style={styles.fieldLabel}>Pending payments</Text>
                  {pendingPays.map((p) => (
                    <View key={p.id} style={styles.pendingRow}>
                      <Text style={styles.soaLine}>
                        {formatMoney(p.amount)} on {p.date}
                      </Text>
                      <Pressable onPress={() => updateItem('payments', p.id, { status: 'posted' })} hitSlop={10}>
                        <Text style={styles.markPaidText}>Mark posted</Text>
                      </Pressable>
                    </View>
                  ))}
                </View>
              ) : null}

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
                  <Pressable onPress={close} style={[styles.sheetBtn, styles.cancelBtn]}>
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

function Group({ title, list, styles, colors, onPick }) {
  if (list.length === 0) return null;
  const subtotal = list.reduce((t, d) => t + d.remaining, 0);
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>{title}</Text>
        <Text style={styles.sectionSubtotal}>{formatMoney(subtotal)}</Text>
      </View>
      <View style={styles.card}>
        {list.map((d) => (
          <Pressable
            key={d.id}
            onPress={() => onPick(d)}
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
          >
            <Text style={styles.rowIcon}>💳</Text>
            <View style={styles.rowMiddle}>
              <Text style={styles.rowName}>{d.name}</Text>
              <Text style={styles.rowSub}>
                Min {formatMoney(d.minPayment)} . {formatMoney(monthlyInterest(d))} interest/mo
                {d.dueDay ? ` . due day ${d.dueDay}` : ''}
              </Text>
            </View>
            <Text style={styles.rowAmount}>{formatMoney(d.remaining)}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginBottom: spacing.md },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    cardPad: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    totalDebt: { color: colors.warning, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: spacing.xs, marginBottom: spacing.lg },
    splitRow: { flexDirection: 'row', justifyContent: 'space-between' },
    smallLabel: { color: colors.muted, fontSize: fontSize.caption },
    smallValue: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    addBtn: { backgroundColor: colors.card, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.md, paddingVertical: spacing.md, alignItems: 'center', marginBottom: spacing.lg },
    addBtnText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.6 },

    toggleRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.md },
    toggle: { flex: 1, paddingVertical: spacing.sm + 2, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, alignItems: 'center' },
    toggleOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    toggleText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    toggleTextOn: { color: colors.onPrimary },
    strategyNote: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.md },

    focusCard: { backgroundColor: colors.card, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    focusKicker: { color: colors.primary, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    focusName: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginTop: spacing.xs },
    focusSub: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs },

    section: { marginBottom: spacing.lg },
    sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5 },
    sectionSubtotal: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth },
    rowIcon: { fontSize: 22, marginRight: spacing.md },
    rowMiddle: { flex: 1 },
    rowName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    empty: { color: colors.faint, fontSize: fontSize.small, textAlign: 'center', marginTop: spacing.sm },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.sm },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    fieldHint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.xs, lineHeight: 16 },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    chipTextOn: { color: colors.onPrimary },

    payBox: { marginTop: spacing.lg, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: spacing.sm },
    payRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center' },
    payInput: { flex: 1 },
    markPaid: { marginTop: spacing.md, alignSelf: 'flex-start' },
    markPaidText: { color: colors.softGreen, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    msg: { color: colors.primary, fontSize: fontSize.small, marginTop: spacing.sm },
    soaLine: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs },
    soaHint: { color: colors.softGreen, fontSize: fontSize.small, marginTop: spacing.sm },
    soaWarn: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.xs },
    soaShareBtn: {
      marginTop: spacing.md,
      borderWidth: 1,
      borderColor: colors.primary,
      borderRadius: radius.md,
      paddingVertical: spacing.sm,
      alignItems: 'center',
    },
    soaShareText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    pendingRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', minHeight: 44 },

    sheetButtons: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.xl },
    sheetRight: { flexDirection: 'row', gap: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    deleteBtn: { backgroundColor: 'transparent' },
    deleteText: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    err: { color: colors.warning, fontSize: fontSize.small, marginBottom: spacing.sm },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
