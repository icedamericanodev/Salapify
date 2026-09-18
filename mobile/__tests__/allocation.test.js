// Regression suite for lib/allocation.js: the sweldo split shown on payday.
// It is arithmetic on figures the user already entered, so the invariants are
// that it never promises to save money the bills need and never goes negative.

import { sweldoAllocation, planForSave } from '../lib/allocation';

const REF = new Date(2026, 6, 10); // 10 July 2026
const SEMI = { paydaySchedule: { mode: 'semimonthly', days: [15, 31] } };

describe('sweldoAllocation splits the sweldo that just landed', () => {
  const data = {
    settings: SEMI,
    accounts: [],
    debts: [],
    recurring: [{ id: 'r1', type: 'expense', label: 'Load', amount: 2000, dayOfMonth: 12 }],
    transactions: [{ type: 'income', amount: 20000, date: '2026-07-01' }],
  };

  test('income is every income logged since the last payday', () => {
    expect(sweldoAllocation(data, REF).income).toBe(20000);
  });
  test('bills come from the committed total', () => {
    expect(sweldoAllocation(data, REF).bills).toBe(2000);
  });
  test('the default save slice is 10% of income', () => {
    expect(sweldoAllocation(data, REF).save).toBe(2000); // round(20000 * 0.1)
  });
  test('left to live is income minus bills minus save', () => {
    expect(sweldoAllocation(data, REF).leftToLive).toBe(16000);
  });
  test('per day spreads left to live over the days to the next sweldo', () => {
    expect(sweldoAllocation(data, REF).perDay).toBe(3200); // 16000 / 5
  });
});

describe('the save slice never eats into the bills money', () => {
  test('when bills already exceed the sweldo, nothing is saved and nothing goes negative', () => {
    const data = {
      settings: SEMI,
      accounts: [],
      debts: [],
      recurring: [{ id: 'r1', type: 'expense', label: 'Rent', amount: 5000, dayOfMonth: 12 }],
      transactions: [{ type: 'income', amount: 3000, date: '2026-07-01' }],
    };
    const plan = sweldoAllocation(data, REF);
    expect(plan.save).toBe(0);
    expect(plan.leftToLive).toBe(0);
    expect(plan.tight).toBe(true);
  });
});

describe('an empty dataset produces a calm zero plan', () => {
  test('no income means hasIncome is false and nothing is negative', () => {
    const plan = sweldoAllocation({ settings: SEMI }, REF);
    expect(plan.income).toBe(0);
    expect(plan.hasIncome).toBe(false);
    expect(plan.leftToLive).toBe(0);
    expect(plan.perDay).toBe(0);
  });
});

describe('planForSave clamps a typed save amount to what is available', () => {
  const data = {
    settings: SEMI,
    accounts: [],
    debts: [],
    recurring: [{ id: 'r1', type: 'expense', label: 'Load', amount: 2000, dayOfMonth: 12 }],
    transactions: [{ type: 'income', amount: 20000, date: '2026-07-01' }],
  };
  test('a huge typed save is capped at income after bills', () => {
    const plan = planForSave(data, REF, 999999);
    expect(plan.save).toBe(18000); // 20000 - 2000 bills
    expect(plan.leftToLive).toBe(0);
  });
  test('a negative typed save floors at zero', () => {
    const plan = planForSave(data, REF, -500);
    expect(plan.save).toBe(0);
    expect(plan.leftToLive).toBe(18000);
  });
});
