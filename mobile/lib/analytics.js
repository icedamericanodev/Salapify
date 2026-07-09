// analytics.js: the Pro analysis engine. Pure functions that turn the raw
// data into decisions: month by month trends, category movers, weekday
// patterns, a month end forecast, savings rate, a debt free projection
// with total interest, and a financial health score. Everything computes
// on the phone from local data, nothing leaves the device.

import { todayISO, nextPayday } from './format';
import { upcomingDues, nextOccurrence, daysUntil } from './soa';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

// Tracked utang: the still owed amount of receivables/payables that have a
// recorded cash leg (cashLeg === true), i.e. lending or borrowing that actually
// moved money out of or into an account. Only tracked utang belongs in net
// worth. Legacy utang, or new utang where the user skipped naming an account,
// has no cash leg: its money still sits in an account balance, so counting it
// again would double count. A partial payment already moved into an account, so
// only the remaining slice is still an asset/liability.
export function trackedRemaining(list) {
  return (list || []).reduce((t, r) => {
    if (!r || !r.cashLeg || r.paid) return t;
    const paid = (r.payments || []).reduce((s, p) => s + num(p && p.amount), 0);
    return t + Math.max(0, num(r.amount) - paid);
  }, 0);
}

// The ONE net worth breakdown for the whole app, so every screen agrees.
// Everything you own minus everything you owe, with the parts a screen needs to
// show a breakdown that always sums back to the headline:
//   assets      = accounts + holdings (assets) + tracked receivables
//   liabilities = debts + tracked payables
//   netWorth    = assets - liabilities
// Only tracked (cash leg) utang is included, so with none this is exactly
// accounts + holdings - debts and wiring every screen through it changes nothing
// until tracked utang exists.
export function netWorthParts(data) {
  const d = data || {};
  const accounts = (d.accounts || []).reduce((t, a) => t + num(a && a.balance), 0);
  const holdings = (d.assets || []).reduce((t, a) => t + num(a && a.value), 0);
  const receivables = trackedRemaining(d.receivables);
  const payables = trackedRemaining(d.payables);
  const debts = (d.debts || []).reduce((t, x) => t + num(x && x.remaining), 0);
  const assets = accounts + holdings + receivables;
  const liabilities = debts + payables;
  return { accounts, holdings, receivables, payables, debts, assets, liabilities, netWorth: assets - liabilities };
}

// The single net worth number. Same formula as netWorthParts, for callers that
// only need the total.
export function netWorth(data) {
  return netWorthParts(data).netWorth;
}

// Accounts you can actually spend from day to day. Savings are deliberately
// excluded: the whole point of safe to spend is to protect them.
const LIQUID_KINDS = ['cash', 'ewallet', 'checking'];

// The bills that land before the next sweldo, oldest first, with the total.
// Two sources: card and loan dues, and recurring bills that have not already
// posted this cycle (a posted one already left the balance). This is the
// detail behind safeToSpend's committed number. Returns:
//   { payday, daysLeft, bills: [{ name, kind, date, amount }], total }
export function upcomingCommitments(data, ref = new Date()) {
  const today = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  const schedule = data.settings && data.settings.paydaySchedule;

  // The horizon is the next sweldo. If today IS payday, the money just
  // arrived, so look ahead to the one after.
  let payday = nextPayday(today, schedule);
  const sameDay = (a, b) =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  if (sameDay(payday, today)) {
    payday = nextPayday(new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1), schedule);
  }
  const daysLeft = Math.max(1, daysUntil(payday, today));

  const monthKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  const bills = [];
  for (const d of upcomingDues(data.debts, daysLeft, today)) {
    if (num(d.amount) > 0) {
      bills.push({ name: (d.debt && d.debt.name) || 'Debt', kind: 'minimum', date: d.due, amount: num(d.amount) });
    }
  }
  for (const r of data.recurring || []) {
    if (!r || r.type !== 'expense') continue;
    const posted = typeof r.lastPosted === 'string' && r.lastPosted >= monthKey;
    if (posted) continue;
    const amt = Math.max(0, num(r.amount));
    const due = nextOccurrence(r.dayOfMonth, today);
    if (due && due <= payday && amt > 0) {
      bills.push({ name: r.label || 'Recurring', kind: 'bill', date: due, amount: amt });
    }
  }
  bills.sort((a, b) => a.date - b.date);
  const total = bills.reduce((t, b) => t + b.amount, 0);
  return { payday, daysLeft, bills, total };
}

// Safe to spend until sweldo: how much is genuinely free to spend each day
// between now and the next payday, after setting aside the bills that land
// before then. Answers the one question people open a money app to ask,
// "how much can I spend today and still make it to payday?". Everything is
// computed from data already on the phone. Returns:
//   { liquid, committed, available, perDay, daysLeft, payday, billCount }
export function safeToSpend(data, ref = new Date()) {
  const c = upcomingCommitments(data, ref);
  // Spendable right now: cash, e-wallets, checking. Never savings.
  const liquid = (data.accounts || []).reduce(
    (t, a) => (a && LIQUID_KINDS.includes(a.kind) ? t + num(a.balance) : t),
    0
  );
  const committed = c.total;
  const available = liquid - committed;
  const perDay = available > 0 ? available / c.daysLeft : 0;
  return {
    liquid,
    committed,
    available,
    perDay,
    daysLeft: c.daysLeft,
    payday: c.payday,
    billCount: c.bills.length,
  };
}

// The utang ledger, aged. Groups everything people owe you by person, nets
// out any partial payments, and ranks by who has owed you the longest so the
// screen can say who to follow up first, then who owes the most. A
// receivable counts as still outstanding when it is not marked paid and has a
// balance left after its payments. Its dueDate drives the aging: a due date
// in the past makes it overdue by that many days. Everything is money already
// on the phone. Returns:
//   { people: [{ personId, name, phone, outstanding, count, daysOverdue,
//     oldestDue }], totalOutstanding, overdueTotal, overdueCount, worst }
export function utangAging(data, ref = new Date()) {
  const today = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  // The canonical name for each person id, so a personId row and a legacy
  // name only row for the same person fold into one group instead of two.
  const nameById = new Map();
  for (const p of data.people || []) {
    if (p && typeof p.id === 'string' && p.id) nameById.set(p.id, typeof p.name === 'string' ? p.name : '');
  }
  const groups = new Map();
  for (const r of data.receivables || []) {
    if (!r || r.paid) continue;
    const paidSoFar = (r.payments || []).reduce((t, p) => t + Math.max(0, num(p && p.amount)), 0);
    const outstanding = num(r.amount) - paidSoFar;
    if (outstanding <= 0) continue;
    const name =
      (r.personId && (nameById.get(r.personId) || '').trim()) ||
      (typeof r.person === 'string' && r.person.trim()) ||
      'Someone';
    // Key by the resolved name so every row for one person folds together,
    // matching how the v3 migration itself grouped receivables by name.
    const key = name.toLowerCase();
    let g = groups.get(key);
    if (!g) {
      g = { personId: r.personId || '', name, phone: '', outstanding: 0, count: 0, oldestDue: null };
      groups.set(key, g);
    }
    // Keep a person id if any row carries one, so the row can still deep link.
    if (!g.personId && r.personId) g.personId = r.personId;
    g.outstanding += outstanding;
    g.count += 1;
    if (!g.phone && typeof r.phone === 'string' && r.phone) g.phone = r.phone;
    const dm = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(r.dueDate || '').trim());
    if (dm) {
      const due = new Date(Number(dm[1]), Number(dm[2]) - 1, Number(dm[3]));
      if (!g.oldestDue || due < g.oldestDue) g.oldestDue = due;
    }
  }
  const people = [...groups.values()].map((g) => ({
    personId: g.personId,
    name: g.name,
    phone: g.phone,
    outstanding: g.outstanding,
    count: g.count,
    daysOverdue: g.oldestDue ? Math.max(0, Math.round((today - g.oldestDue) / MS_PER_DAY)) : 0,
    oldestDue: g.oldestDue ? todayISO(g.oldestDue) : '',
  }));
  // Follow up the one who has owed you longest first, then the biggest
  // balance. A tie on both keeps a stable order by name.
  people.sort(
    (a, b) => b.daysOverdue - a.daysOverdue || b.outstanding - a.outstanding || a.name.localeCompare(b.name)
  );
  const totalOutstanding = people.reduce((t, p) => t + p.outstanding, 0);
  const overdue = people.filter((p) => p.daysOverdue > 0);
  const overdueTotal = overdue.reduce((t, p) => t + p.outstanding, 0);
  return { people, totalOutstanding, overdueTotal, overdueCount: overdue.length, worst: people[0] || null };
}

// One savings goal's pace: how far along it is, and the honest amount it
// takes to finish on time. progress is saved over target. With a real future
// target, perMonth and perWeek are the catch up pace. A deadline still coming
// this month reads as due soon (the whole balance lands this month); a
// deadline that has truly passed reads as behind. Returns
//   { pct, saved, target, remaining, done, status, monthsLeft, perMonth,
//     perWeek, targetDate }. status is one of
//   'done' | 'behind' | 'due-soon' | 'active' | 'no-date' | 'no-target'.
export function goalPace(goal, ref = new Date()) {
  const target = Math.max(0, num(goal && goal.target));
  const saved = Math.max(0, num(goal && goal.saved));
  const targetDate = typeof (goal && goal.targetDate) === 'string' ? goal.targetDate.trim() : '';
  // No real target means no progress and no pace to compute.
  if (target <= 0) {
    return { pct: 0, saved, target, remaining: 0, done: false, status: 'no-target', monthsLeft: null, perMonth: 0, perWeek: 0, targetDate };
  }
  const remaining = Math.max(0, target - saved);
  const pct = Math.min(saved / target, 1);
  const base = { pct, saved, target, remaining, targetDate };
  if (remaining <= 0) {
    return { ...base, pct: 1, done: true, status: 'done', monthsLeft: 0, perMonth: 0, perWeek: 0 };
  }
  // The month must be a real 01 to 12, or a typo like 2026-99 would fall
  // through to an absurd pace instead of the honest no-date fallback.
  const m = /^(\d{4})-(\d{2})(?:-(\d{2}))?$/.exec(targetDate);
  const mo = m ? Number(m[2]) - 1 : -1;
  if (!m || mo < 0 || mo > 11) {
    return { ...base, done: false, status: 'no-date', monthsLeft: null, perMonth: 0, perWeek: 0 };
  }
  const y = Number(m[1]);
  const today = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  // Concrete deadline: the given day, or the last day of the month when only
  // a month was set. That is what tells a date truly past from one still to
  // come later this month.
  const lastDay = new Date(y, mo + 1, 0).getDate();
  const day = m[3] ? Math.min(Math.max(Number(m[3]), 1), lastDay) : lastDay;
  const deadline = new Date(y, mo, day);
  // Whole months from this month to the target month, matching the Goals
  // screen's own perMonth math so the two never disagree.
  const monthsLeft = (y - ref.getFullYear()) * 12 + (mo - ref.getMonth());
  if (deadline < today) {
    // Truly past: the whole balance is overdue.
    return { ...base, done: false, status: 'behind', monthsLeft, perMonth: remaining, perWeek: remaining };
  }
  if (monthsLeft <= 0) {
    // This month, not yet passed: the balance is due within the month.
    return { ...base, done: false, status: 'due-soon', monthsLeft: Math.max(monthsLeft, 0), perMonth: remaining, perWeek: remaining };
  }
  const perMonth = Math.ceil(remaining / monthsLeft);
  const perWeek = Math.ceil(remaining / (monthsLeft * (52 / 12)));
  return { ...base, done: false, status: 'active', monthsLeft, perMonth, perWeek };
}

// Month key like "2026-07" for a Date.
function monthKey(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// Income, expenses, and net for each of the last n months, oldest first.
// Months with no data still appear, so the chart never lies by omission.
export function monthlySeries(transactions, n = 6, ref = new Date()) {
  const out = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(ref.getFullYear(), ref.getMonth() - i, 1);
    const key = monthKey(d);
    let income = 0;
    let expenses = 0;
    for (const t of transactions || []) {
      if (!t || String(t.date || '').slice(0, 7) !== key) continue;
      if (t.type === 'income') income += num(t.amount);
      else if (t.type === 'expense') expenses += num(t.amount);
    }
    out.push({ key, label: MONTHS_SHORT[d.getMonth()], income, expenses, net: income - expenses });
  }
  return out;
}

// Category totals for a given month offset (0 = this month, 1 = last).
function categoryTotals(transactions, offset, ref = new Date()) {
  const d = new Date(ref.getFullYear(), ref.getMonth() - offset, 1);
  const key = monthKey(d);
  const totals = Object.create(null);
  for (const t of transactions || []) {
    if (!t || t.type !== 'expense' || String(t.date || '').slice(0, 7) !== key) continue;
    const label = (typeof t.label === 'string' && t.label.trim()) || 'Other';
    totals[label] = (totals[label] || 0) + num(t.amount);
  }
  return totals;
}

// The biggest category changes vs last month, largest absolute move first.
// Each entry: { label, now, before, change } where change = now - before.
export function categoryMovers(transactions, ref = new Date(), limit = 5) {
  const now = categoryTotals(transactions, 0, ref);
  const before = categoryTotals(transactions, 1, ref);
  const labels = new Set([...Object.keys(now), ...Object.keys(before)]);
  const moves = [];
  for (const label of labels) {
    const a = now[label] || 0;
    const b = before[label] || 0;
    if (a === 0 && b === 0) continue;
    moves.push({ label, now: a, before: b, change: a - b });
  }
  return moves.sort((x, y) => Math.abs(y.change) - Math.abs(x.change)).slice(0, limit);
}

// This month's spending per category against the average of the last
// `months` full months, biggest current spender first. The question this
// answers is the one people actually decide with: am I overspending on
// this compared to my normal? Each entry: { label, now, avg }.
export function categoryVsAverage(transactions, ref = new Date(), months = 6, limit = 5) {
  const sums = Object.create(null);
  // Average over the months that actually have spending, so one month of
  // history is not diluted six ways into a fake "above normal" verdict.
  let active = 0;
  for (let i = 1; i <= months; i++) {
    const t = categoryTotals(transactions, i, ref);
    const keys = Object.keys(t);
    if (keys.length > 0) active += 1;
    for (const k of keys) sums[k] = (sums[k] || 0) + t[k];
  }
  const denom = Math.max(active, 1);
  // Pace matters: on the 2nd of the month everything looks "below normal"
  // against a FULL month average. expected is the average scaled to how
  // far into the month we are; verdicts should compare against it.
  const daysInMonth = new Date(ref.getFullYear(), ref.getMonth() + 1, 0).getDate();
  const frac = Math.min(ref.getDate() / daysInMonth, 1);
  const now = categoryTotals(transactions, 0, ref);
  const labels = new Set([...Object.keys(sums), ...Object.keys(now)]);
  const out = [];
  for (const label of labels) {
    const avg = (sums[label] || 0) / denom;
    const cur = now[label] || 0;
    if (avg === 0 && cur === 0) continue;
    out.push({ label, now: cur, avg, expected: avg * frac });
  }
  return out.sort((x, y) => y.now - x.now).slice(0, limit);
}

// Average spending per weekday over the last 8 weeks (56 days). Index 0 is
// Sunday, matching JavaScript's getDay.
export function weekdayPattern(transactions, ref = new Date()) {
  const totals = [0, 0, 0, 0, 0, 0, 0];
  const counts = [0, 0, 0, 0, 0, 0, 0];
  const start = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - 55);
  // Count occurrences of each weekday inside the window.
  for (let i = 0; i < 56; i++) {
    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
    counts[d.getDay()] += 1;
  }
  for (const t of transactions || []) {
    if (!t || t.type !== 'expense' || !t.date) continue;
    const parts = String(t.date).split('-').map(Number);
    if (parts.length !== 3 || parts.some(isNaN)) continue;
    const d = new Date(parts[0], parts[1] - 1, parts[2]);
    if (d < start || d > ref) continue;
    totals[d.getDay()] += num(t.amount);
  }
  return totals.map((sum, i) => ({ day: i, avg: counts[i] ? sum / counts[i] : 0 }));
}

// Split one debt payment into interest and principal, the bank-officer spec.
// Interest accrues over TIME on the diminishing balance, so it is booked by
// days elapsed since interestThroughISO (a 30 day month), NOT a full month per
// payment. That is what stops two payments in one month from booking two months
// of interest. The accrued interest capitalizes into the balance, the payment
// covers interest first, and applied is clamped so you never pay or are charged
// more than you owe (fixing the old overpayment cash-loss). Returns every part
// the caller and reports need. Pure, so it is unit tested.
export function splitDebtPayment(remaining, monthlyRate, interestThroughISO, amount, todayStr) {
  const cur = Math.max(0, num(remaining));
  const rate = num(monthlyRate);
  const amt = Math.max(0, num(amount));
  const fromISO = typeof interestThroughISO === 'string' && interestThroughISO ? interestThroughISO : todayStr;
  // Guard against a bad stamp: a non-date string makes the diff NaN, which would
  // otherwise poison the balance (and a later save would coerce NaN to 0,
  // silently wiping the debt). A non-finite diff accrues 0 instead.
  const raw = Math.round((new Date(todayStr) - new Date(fromISO)) / 86400000);
  const days = Number.isFinite(raw) ? Math.max(0, raw) : 0;
  const accrued = rate > 0 ? Math.round(cur * (rate / 100) * (days / 30)) : 0;
  const balance = cur + accrued;
  const applied = Math.min(amt, balance);
  const interest = Math.min(applied, accrued);
  const principal = applied - interest;
  const newRemaining = balance - applied;
  const overpay = Math.max(0, amt - applied);
  return { accrued, balance, applied, interest, principal, newRemaining, overpay };
}

// This month's savings rate: what fraction of your EARNINGS you did not spend.
// Spending includes the INTEREST portion of a debt payment (a real cost, posted
// as an expense), but NOT the principal portion: paying down principal is not
// spending, it moves the same peso from cash to a smaller debt and builds net
// worth, so it must not lower the rate. That is why the whole debt payment is no
// longer subtracted here, only the interest, which already sits in expenses.
// Repaid utang (someone paying you back) is NOT counted as income: it is your
// own money coming home, not new earnings. It still shows in cash flow, which
// measures money moving through accounts, a different question. Null with no
// income. The payments argument is kept for callers but no longer used.
export function savingsRate(transactions, payments = [], ref = new Date()) {
  const key = monthKey(ref);
  let income = 0;
  let expenses = 0;
  for (const t of transactions || []) {
    if (!t || String(t.date || '').slice(0, 7) !== key) continue;
    if (t.type === 'income' && t.source !== 'receivable') income += num(t.amount);
    else if (t.type === 'expense') expenses += num(t.amount);
  }
  if (income <= 0) return null;
  return (income - expenses) / income;
}

// If spending keeps its current daily pace, where does the month land?
export function forecastMonthEnd(transactions, ref = new Date()) {
  const key = monthKey(ref);
  let spent = 0;
  for (const t of transactions || []) {
    if (t && t.type === 'expense' && String(t.date || '').slice(0, 7) === key) spent += num(t.amount);
  }
  const dayOfMonth = ref.getDate();
  const daysInMonth = new Date(ref.getFullYear(), ref.getMonth() + 1, 0).getDate();
  const projected = dayOfMonth > 0 ? (spent / dayOfMonth) * daysInMonth : spent;
  return { spent, projected: Math.round(projected), daysInMonth, dayOfMonth };
}

// Simulate paying down all debts month by month: interest accrues at each
// debt's monthly rate, minimum payments go to every debt, and any extra
// goes to the strategy's focus debt. Returns months to freedom, the total
// interest paid along the way, and the projected date, or null when the
// minimums can never win (balances grow forever).
export function debtFreeProjection(debts, strategy = 'avalanche', extra = 0, ref = new Date()) {
  const list = (debts || [])
    .filter((d) => d && num(d.remaining) > 0)
    .map((d) => ({
      remaining: num(d.remaining),
      monthlyRate: Math.max(0, num(d.monthlyRate)),
      minPayment: Math.max(0, num(d.minPayment)),
    }));
  if (list.length === 0) return { months: 0, totalInterest: 0, date: ref };

  // The whole point of avalanche and snowball: the monthly debt budget
  // stays the SAME after a debt is finished. Its freed minimum rolls into
  // the next focus debt instead of quietly leaving the plan, which is what
  // makes the payoff accelerate near the end.
  const totalMin = list.reduce((t, d) => t + d.minPayment, 0);

  let months = 0;
  let totalInterest = 0;
  while (list.some((d) => d.remaining > 0.5) && months < 600) {
    months += 1;
    for (const d of list) {
      if (d.remaining > 0) {
        const interest = (d.remaining * d.monthlyRate) / 100;
        d.remaining += interest;
        totalInterest += interest;
      }
    }
    // Every living debt gets its own minimum first, then whatever the
    // minimums did not use (freed minimums from finished debts plus the
    // extra) goes to the strategy's focus debt.
    let budget = totalMin + extra;
    for (const d of list) {
      if (d.remaining > 0) {
        const pay = Math.min(d.minPayment, d.remaining, budget);
        d.remaining -= pay;
        budget -= pay;
      }
    }
    const order = [...list].sort((a, b) =>
      strategy === 'snowball' ? a.remaining - b.remaining : b.monthlyRate - a.monthlyRate
    );
    for (const d of order) {
      if (budget <= 0) break;
      if (d.remaining > 0) {
        const pay = Math.min(budget, d.remaining);
        d.remaining -= pay;
        budget -= pay;
      }
    }
  }
  if (months >= 600) return null;
  const date = new Date(ref.getFullYear(), ref.getMonth() + months, 1);
  return { months, totalInterest: Math.round(totalInterest), date };
}

// Emergency fund runway: how many months of typical spending your accessible
// money would cover. The buffer is every account balance, cash, e-wallets,
// checking, and savings, since an emergency fund is money you can actually
// reach; it excludes illiquid assets like property. Typical monthly spend is
// the median of the completed months that had any expense over the last 6, so a
// new user with no history gets null instead of a made-up number. Returns:
//   { buffer, avgMonthlyExpense, monthsCovered, capped, firstTarget, oneMonthTarget }
// RUNWAY_CAP: we never claim more than this many months covered. A single
// sparse month of logging (say only 120 pesos recorded) would otherwise divide
// a real balance into a nonsense figure like 429 months, which reads as broken
// rather than reassuring. Anything past the cap is shown as "12+ months".
export const RUNWAY_CAP = 12;
export function emergencyRunway(data, ref = new Date()) {
  const d = data || {};
  // Buffer is the accessible account money: cash, e-wallets, checking, and
  // savings, but not illiquid assets. Goal saved amounts are a separate,
  // independent number in this app (funding a goal never moves an account
  // balance), so they are neither added nor subtracted here, no double count.
  const accountSum = (Array.isArray(d.accounts) ? d.accounts : []).reduce((t, a) => t + num(a && a.balance), 0);
  const buffer = Math.max(0, accountSum);
  // Typical monthly spend: the median of COMPLETED months that had any expense,
  // over the last 6. The median resists a one-off big month (tuition, a
  // hospital bill), and excluding the current partial month stops an early-in-
  // the-month low total from overstating the runway.
  const series = monthlySeries(Array.isArray(d.transactions) ? d.transactions : [], 7, ref);
  const completed = series.slice(0, 6).map((mo) => mo.expenses).filter((x) => x > 0).sort((a, b) => a - b);
  let typical = 0;
  // Require at least TWO completed months with spending before we quote a
  // months-covered figure. With a single month the "typical" is just that one
  // number, and a light logging month makes the runway wildly overstated. Two
  // months of real data give the median something to resist an outlier with.
  const RUNWAY_MIN_MONTHS = 2;
  if (completed.length >= RUNWAY_MIN_MONTHS) {
    const mid = Math.floor(completed.length / 2);
    typical = completed.length % 2 ? completed[mid] : (completed[mid - 1] + completed[mid]) / 2;
  }
  const rawMonths = typical > 0 ? Math.round((buffer / typical) * 10) / 10 : null;
  const capped = rawMonths != null && rawMonths > RUNWAY_CAP;
  const monthsCovered = capped ? RUNWAY_CAP : rawMonths;
  return {
    buffer: Math.round(buffer),
    avgMonthlyExpense: Math.round(typical),
    monthsCovered,
    capped,
    firstTarget: 10000,
    oneMonthTarget: Math.round(typical),
  };
}

// A single 0 to 100 financial health score from four honest ingredients:
// savings rate (35), budget adherence (25), debt load vs assets (25), and
// logging consistency over the last 14 days (15). Returns the total and
// the parts so the screen can explain itself.
export function healthScore(data, ref = new Date()) {
  const rate = savingsRate(data.transactions, data.payments, ref);
  const ratePts = rate === null ? 0 : Math.round(Math.max(0, Math.min(rate / 0.3, 1)) * 35);

  const { spent } = forecastMonthEnd(data.transactions, ref);
  const limit = num(data.settings && data.settings.monthlyLimit);
  let budgetPts = 0;
  if (limit > 0) {
    budgetPts = spent <= limit ? 25 : Math.round(Math.max(0, 1 - (spent - limit) / limit) * 25);
  }

  const sum = (arr, key) => (arr || []).reduce((t, x) => t + num(x && x[key]), 0);
  const assets = sum(data.accounts, 'balance') + sum(data.assets, 'value');
  const debt = sum(data.debts, 'remaining');
  let debtPts = 25;
  if (debt > 0) {
    debtPts = assets > 0 ? Math.round(Math.max(0, 1 - debt / assets) * 25) : 0;
  }

  // Only real logs count toward the logging habit points; transfer and
  // debt payment record rows are bookkeeping, not the logging habit.
  const logged = new Set(
    (data.transactions || [])
      .filter((t) => t && (t.type === 'income' || t.type === 'expense'))
      .map((t) => t.date)
  );
  let daysLogged = 0;
  for (let i = 0; i < 14; i++) {
    const d = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - i);
    if (logged.has(todayISO(d))) daysLogged += 1;
  }
  const logPts = Math.round((daysLogged / 14) * 15);

  return {
    total: ratePts + budgetPts + debtPts + logPts,
    parts: { savings: ratePts, budget: budgetPts, debt: debtPts, logging: logPts },
  };
}
