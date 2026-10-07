// The sweldo allocation plan. When payday lands, the hardest question is not
// "how much do I have" but "how do I split this so it survives to the next
// sweldo". This turns the numbers the engine already knows into that split:
// the sweldo that just arrived, the bills due before the next one, a
// savings-first slice, and what is left to live on per day.
//
// It is a PLAN, not an action. It never moves money and never implies it did;
// it only does arithmetic on figures the user already entered. Pure and
// dependency-light so it is easy to test.

import { upcomingCommitments } from './analytics';
import { prevPayday, todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

// The default share to save when the user has not set their own: a gentle
// 10 percent, the common starter target.
const DEFAULT_SAVE_PCT = 0.1;

// sweldoAllocation(data, ref) ->
//   { income, bills, save, savePct, leftToLive, perDay, daysLeft, payday,
//     hasIncome }
// income is every income logged since this payday (the sweldo just received).
// bills is what the engine already commits before the next sweldo. save is the
// savings-first slice from the user's saved percentage. leftToLive is what
// remains to spend, floored at zero, spread over the days until next sweldo.
export function sweldoAllocation(data, ref = new Date()) {
  const d = data || {};
  const schedule = d.settings && d.settings.paydaySchedule;
  const lastPay = prevPayday(ref, schedule);
  const sinceKey = todayISO(lastPay);

  // The sweldo that just landed: income dated on or after this payday.
  let income = 0;
  for (const t of d.transactions || []) {
    if (t && t.type === 'income' && String(t.date || '') >= sinceKey) income += num(t.amount);
  }

  const c = upcomingCommitments(d, ref);
  const bills = Math.max(0, num(c.total));
  const daysLeft = Math.max(1, num(c.daysLeft) || 1);

  const savePct = clamp(num(d.settings && d.settings.savePct) || DEFAULT_SAVE_PCT, 0, 0.9);

  // Save from the sweldo, but never promise to save money that the bills
  // already need: the save slice can only come out of what is left after bills.
  const afterBills = Math.max(0, income - bills);
  const save = Math.min(Math.round(income * savePct), afterBills);

  const leftToLive = Math.max(0, income - bills - save);
  const perDay = leftToLive / daysLeft;

  return {
    income,
    bills,
    save,
    savePct,
    leftToLive,
    perDay,
    daysLeft,
    payday: c.payday,
    billCount: (c.bills || []).length,
    hasIncome: income > 0,
    // True when bills alone already exceed the sweldo: no room to save or
    // spend, the honest tight case.
    tight: income > 0 && bills >= income,
  };
}

// planForSave(data, ref, amount) -> the same plan recomputed for a specific
// save amount the user typed, so the card can show live "left to live" as they
// drag the number. amount is clamped to what is actually available after bills.
export function planForSave(data, ref, amount) {
  const base = sweldoAllocation(data, ref);
  const afterBills = Math.max(0, base.income - base.bills);
  const save = clamp(Math.round(num(amount)), 0, afterBills);
  const leftToLive = Math.max(0, base.income - base.bills - save);
  return { ...base, save, leftToLive, perDay: leftToLive / base.daysLeft };
}
