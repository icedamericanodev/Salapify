// soa.js: statement of account helpers for credit cards and loans.
// Debts can carry two optional day-of-month numbers:
//  - dueDay: the day payment is due each month (cards AND loans)
//  - statementDay: the day the card statement cuts off (credit cards)
// From those we forecast the next statement, the next due date, and the
// list of upcoming payments, so the app can show future cash flow and
// remind the user to pay in full, or at least the minimum, before fees hit.

import { todayISO } from './format';

// The next date a given day-of-month occurs, starting from "from".
// Day 31 in a 30 day month clamps to the 30th, February clamps too.
export function nextOccurrence(dayOfMonth, from = new Date()) {
  const day = Number(dayOfMonth);
  if (!Number.isFinite(day) || day < 1 || day > 31) return null;
  const y = from.getFullYear();
  const m = from.getMonth();
  const clampDay = (yy, mm) => Math.min(day, new Date(yy, mm + 1, 0).getDate());
  const todayMid = new Date(y, m, from.getDate());
  const candidate = new Date(y, m, clampDay(y, m));
  if (candidate >= todayMid) return candidate;
  return new Date(y, m + 1, clampDay(y, m + 1));
}

// Days from "from" until the given date, whole days, 0 means today.
export function daysUntil(date, from = new Date()) {
  const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const b = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.round((b - a) / 86400000);
}

// All payments coming due in the next `windowDays` days, across every debt
// that has a dueDay and money still owed. Sorted soonest first. Each entry:
// { debt, due (Date), dueISO, inDays, amount } where amount is the minimum
// payment (what must be paid to avoid penalties).
export function upcomingDues(debts, windowDays = 30, from = new Date()) {
  const list = [];
  for (const d of debts || []) {
    if (!d || !d.dueDay || !(d.remaining > 0)) continue;
    const due = nextOccurrence(d.dueDay, from);
    if (!due) continue;
    const inDays = daysUntil(due, from);
    if (inDays > windowDays) continue;
    list.push({
      debt: d,
      due,
      dueISO: todayISO(due),
      inDays,
      amount: Math.min(Number(d.minPayment) || 0, Number(d.remaining) || 0) || Number(d.remaining) || 0,
    });
  }
  return list.sort((a, b) => a.due - b.due);
}

// Forecast for one credit card: when the next statement cuts, when payment
// is due, the forecasted statement balance, and the minimum due. Logging a
// payment already reduces the card's remaining balance right away, so the
// forecast IS the remaining balance. Pending is returned separately as
// information only (money sent but not yet posted by the bank); subtracting
// it here would count every pending payment twice.
export function cardForecast(debt, payments = [], from = new Date()) {
  if (!debt) return null;
  const statement = debt.statementDay ? nextOccurrence(debt.statementDay, from) : null;
  const due = debt.dueDay ? nextOccurrence(debt.dueDay, from) : null;
  const pending = (payments || [])
    .filter((p) => p && p.debtId === debt.id && p.status === 'pending')
    .reduce((t, p) => t + (Number(p.amount) || 0), 0);
  const balance = Math.max(0, Number(debt.remaining) || 0);
  return {
    statement,
    due,
    pending,
    forecastBalance: balance,
    minDue: Math.min(Number(debt.minPayment) || 0, balance) || balance,
  };
}
