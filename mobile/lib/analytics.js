// analytics.js: the Pro analysis engine. Pure functions that turn the raw
// data into decisions: month by month trends, category movers, weekday
// patterns, a month end forecast, savings rate, a debt free projection
// with total interest, and a financial health score. Everything computes
// on the phone from local data, nothing leaves the device.

import { todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

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

// This month's savings rate: what fraction of income was not spent.
// Null when there is no income to judge by.
export function savingsRate(transactions, ref = new Date()) {
  const key = monthKey(ref);
  let income = 0;
  let expenses = 0;
  for (const t of transactions || []) {
    if (!t || String(t.date || '').slice(0, 7) !== key) continue;
    if (t.type === 'income') income += num(t.amount);
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
    for (const d of list) {
      if (d.remaining > 0) d.remaining = Math.max(0, d.remaining - d.minPayment);
    }
    let extraLeft = extra;
    const order = [...list].sort((a, b) =>
      strategy === 'snowball' ? a.remaining - b.remaining : b.monthlyRate - a.monthlyRate
    );
    for (const d of order) {
      if (extraLeft <= 0) break;
      if (d.remaining > 0) {
        const pay = Math.min(extraLeft, d.remaining);
        d.remaining -= pay;
        extraLeft -= pay;
      }
    }
  }
  if (months >= 600) return null;
  const date = new Date(ref.getFullYear(), ref.getMonth() + months, 1);
  return { months, totalInterest: Math.round(totalInterest), date };
}

// A single 0 to 100 financial health score from four honest ingredients:
// savings rate (35), budget adherence (25), debt load vs assets (25), and
// logging consistency over the last 14 days (15). Returns the total and
// the parts so the screen can explain itself.
export function healthScore(data, ref = new Date()) {
  const rate = savingsRate(data.transactions, ref);
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

  const logged = new Set((data.transactions || []).map((t) => t && t.date));
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
