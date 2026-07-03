// soa.js: statement of account helpers for credit cards and loans.
// Debts can carry two optional day-of-month numbers:
//  - dueDay: the day payment is due each month (cards AND loans)
//  - statementDay: the day the card statement cuts off (credit cards)
// From those we forecast the next statement, the next due date, and the
// list of upcoming payments, so the app can show future cash flow and
// remind the user to pay in full, or at least the minimum, before fees hit.

import { todayISO, formatMoney } from './format';
import { bankingAdjust } from './holidays';

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

// The most recent date a given day-of-month occurred, on or before "from".
export function prevOccurrence(dayOfMonth, from = new Date()) {
  const day = Number(dayOfMonth);
  if (!Number.isFinite(day) || day < 1 || day > 31) return null;
  const y = from.getFullYear();
  const m = from.getMonth();
  const clampDay = (yy, mm) => Math.min(day, new Date(yy, mm + 1, 0).getDate());
  const todayMid = new Date(y, m, from.getDate());
  const candidate = new Date(y, m, clampDay(y, m));
  if (candidate <= todayMid) return candidate;
  return new Date(y, m - 1, clampDay(y, m - 1));
}

const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

// Every raw (unadjusted) due date a debt could still owe, oldest first.
// Two ways a card can define its schedule, matching how banks print it:
//  - dueDay: a fixed day of the month
//  - statementDay + graceDays: due N days after each statement cut
// The PREVIOUS cycle matters too: a raw due that already passed can have
// a bank adjusted due that is still today or later (a due on Good Friday
// is really payable Monday), so past cycles must stay in the running.
function rawDueCandidates(debt, from) {
  const out = [];
  if (debt.dueDay) {
    const prev = prevOccurrence(debt.dueDay, from);
    const next = nextOccurrence(debt.dueDay, from);
    if (prev) out.push(prev);
    if (next) out.push(next);
  } else {
    const grace = Number(debt.graceDays) || 0;
    if (debt.statementDay && grace > 0) {
      const prevStmt = prevOccurrence(debt.statementDay, from);
      if (prevStmt) {
        // The cycle before the previous one can also still be within its
        // grace window when the grace is long.
        const prevPrevStmt = prevOccurrence(debt.statementDay, addDays(prevStmt, -1));
        if (prevPrevStmt) out.push(addDays(prevPrevStmt, grace));
        out.push(addDays(prevStmt, grace));
      }
      const nextStmt = nextOccurrence(debt.statementDay, from);
      if (nextStmt) out.push(addDays(nextStmt, grace));
    }
  }
  return out.sort((a, b) => a - b);
}

// The next raw due date (no weekend or holiday adjustment). Kept for
// callers that want the printed date; most things should use bankDueDate.
export function dueDateFor(debt, from = new Date()) {
  const bd = bankDueDate(debt, from);
  return bd ? bd.raw : null;
}

// The next due date the way the BANK sees it: weekends and Philippine
// holidays push payment to the next banking day, and a cycle only stops
// counting once its ADJUSTED date has passed. Returns
// { date, raw, moved, reason } or null when the debt has no due schedule.
export function bankDueDate(debt, from = new Date()) {
  if (!debt) return null;
  const todayMid = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  for (const raw of rawDueCandidates(debt, from)) {
    const adj = bankingAdjust(raw);
    if (adj.date >= todayMid) {
      return { date: adj.date, raw, moved: adj.moved, reason: adj.reason };
    }
  }
  return null;
}

// All payments coming due in the next `windowDays` days, across every debt
// with a due schedule (fixed day or statement plus grace) and money still
// owed, using bank adjusted dates. Sorted soonest first. Each entry:
// { debt, due (Date), dueISO, inDays, amount } where amount is the minimum
// payment (what must be paid to avoid penalties).
export function upcomingDues(debts, windowDays = 30, from = new Date()) {
  const list = [];
  for (const d of debts || []) {
    if (!d || !(d.remaining > 0)) continue;
    const bankDue = bankDueDate(d, from);
    if (!bankDue) continue;
    const due = bankDue.date;
    const inDays = daysUntil(due, from);
    if (inDays > windowDays) continue;
    list.push({
      debt: d,
      due,
      dueISO: todayISO(due),
      inDays,
      moved: bankDue.moved,
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
  const bankDue = bankDueDate(debt, from);
  const pending = (payments || [])
    .filter((p) => p && p.debtId === debt.id && p.status === 'pending')
    .reduce((t, p) => t + (Number(p.amount) || 0), 0);
  const balance = Math.max(0, Number(debt.remaining) || 0);
  const limit = Number(debt.creditLimit) || 0;
  const rate = Math.max(0, Number(debt.monthlyRate) || 0);
  return {
    statement,
    due: bankDue ? bankDue.date : null,
    dueRaw: bankDue ? bankDue.raw : null,
    dueMoved: !!(bankDue && bankDue.moved),
    dueMovedReason: bankDue ? bankDue.reason : '',
    pending,
    forecastBalance: balance,
    minDue: Math.min(Number(debt.minPayment) || 0, balance) || balance,
    creditLimit: limit,
    utilization: limit > 0 ? balance / limit : null,
    // What carrying this balance one more month costs in interest, the
    // real price of paying late or paying only the minimum.
    monthlyRate: rate,
    lateInterest: Math.round((balance * rate) / 100),
  };
}

const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const longDate = (d) => (d ? `${MONTHS_SHORT[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}` : '');

// A shareable text SOA forecast for one credit card, built from the same
// numbers the screens show. Honest by design: it says clearly that it is
// a forecast from logged data, not the bank's official statement.
export function buildSOA(debt, payments = [], from = new Date()) {
  const f = cardForecast(debt, payments, from);
  if (!f) return '';
  const lines = [];
  lines.push('SALAPIFY SOA FORECAST');
  lines.push(`${debt.name}`);

  lines.push('');
  lines.push('THIS CYCLE');
  if (f.statement) lines.push(`Next statement cut: ${longDate(f.statement)}`);
  lines.push(`Forecast statement balance: ${formatMoney(f.forecastBalance)}`);
  if (f.creditLimit > 0) {
    lines.push(
      `Credit used: ${Math.min(Math.round((f.utilization || 0) * 100), 999)}% of ${formatMoney(f.creditLimit)}`
    );
  }
  if (f.pending > 0) {
    lines.push(`Payments sent but not yet posted: ${formatMoney(f.pending)}`);
  }

  lines.push('');
  lines.push('WHAT TO PAY');
  lines.push(`Pay in full: ${formatMoney(f.forecastBalance)} and no interest is charged`);
  lines.push(`Or at least the minimum: ${formatMoney(f.minDue)} to avoid late fees`);
  if (f.due) {
    if (f.dueMoved) {
      lines.push(
        `Due date: ${longDate(f.due)} (moved from ${longDate(f.dueRaw)}, which is ${f.dueMovedReason}; banks accept payment on the next banking day)`
      );
    } else {
      lines.push(`Due date: ${longDate(f.due)}`);
    }
  }

  if (f.lateInterest > 0) {
    lines.push('');
    lines.push('IF YOU PAY LATE OR ONLY THE MINIMUM');
    lines.push(
      `About ${formatMoney(f.lateInterest)} interest gets added next month (${f.monthlyRate}% monthly on the unpaid balance)`
    );
    lines.push('Missing the due date also adds your bank’s late fee, usually 850 to 1,500 pesos');
  }

  lines.push('');
  lines.push('Forecast from your logged data in Salapify. Your bank’s official SOA may differ if there are swipes or fees not logged here.');
  return lines.join('\n');
}
