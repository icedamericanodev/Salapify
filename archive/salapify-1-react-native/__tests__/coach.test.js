// Regression suite for lib/coach.js: the DO NEXT decision layer. These lock in
// the ranking (one source of truth for Home and Insights) and the money-advice
// guardrails: never tell someone to cut an essential, survival before
// aspiration, and never celebrate a savings rate built on sparse logging.

import { decisionCandidates, weeklyCheckIn, pickWin, weekKey } from '../lib/coach';

const REF = new Date(2026, 6, 10); // 10 July 2026, a Friday
const SEMI = { paydaySchedule: { mode: 'semimonthly', days: [15, 31] } };

// Bills of 5,000 due before the 15th against 1,000 cash: available goes
// negative, so cash crunch fires and there is nothing free this cycle.
const crunchBase = () => ({
  settings: { ...SEMI },
  accounts: [{ id: 'a', kind: 'cash', balance: 1000 }],
  recurring: [{ id: 'r', type: 'expense', label: 'Rent', amount: 5000, dayOfMonth: 12 }],
  debts: [],
  transactions: [],
  goals: [],
});

describe('decisionCandidates ranking', () => {
  test('returns a list sorted by priority descending', () => {
    const data = crunchBase();
    data.goals = [{ id: 'g', name: 'Trip', target: 10000, saved: 2000, targetDate: '2026-06-01' }];
    const cands = decisionCandidates(data, REF);
    expect(cands.length).toBeGreaterThanOrEqual(2);
    for (let i = 1; i < cands.length; i++) {
      expect(cands[i - 1].prio).toBeGreaterThanOrEqual(cands[i].prio);
    }
  });

  test('cash crunch outranks a behind goal', () => {
    const data = crunchBase();
    data.goals = [{ id: 'g', name: 'Trip', target: 10000, saved: 2000, targetDate: '2026-06-01' }];
    const cands = decisionCandidates(data, REF);
    const crunch = cands.find((c) => c.kind === 'crunch');
    const goal = cands.find((c) => c.kind === 'goal');
    expect(crunch).toBeTruthy();
    expect(goal).toBeTruthy();
    expect(crunch.prio).toBeGreaterThan(goal.prio);
    expect(cands[0].kind).toBe('crunch');
  });

  test('empty app produces no candidates', () => {
    expect(decisionCandidates({}, REF)).toHaveLength(0);
  });
});

describe('guardrail: never tell someone to cut an essential', () => {
  test('an essential hot category keeps informational copy, no cut language', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 50000 }],
      transactions: [
        { type: 'expense', label: 'Food', amount: 3000, date: '2026-06-15' },
        { type: 'expense', label: 'Food', amount: 2000, date: '2026-07-05' },
      ],
      debts: [],
      recurring: [],
      goals: [],
    };
    const hot = decisionCandidates(data, REF).find((c) => c.kind === 'hot');
    expect(hot).toBeTruthy();
    expect(hot.message).toContain('worth a look');
    expect(hot.message).not.toMatch(/eas/i);
    expect(hot.message).not.toMatch(/trim/i);
    expect(hot.message).not.toMatch(/frees/i);
  });

  // A hot category needs a prior-month baseline plus a this-month spend above
  // the pace-adjusted expectation, on an app with money free (no crunch).
  const hotData = (label) => ({
    settings: { ...SEMI },
    accounts: [{ id: 'a', kind: 'cash', balance: 50000 }],
    transactions: [
      { type: 'expense', label, amount: 3000, date: '2026-06-15' },
      { type: 'expense', label, amount: 2000, date: '2026-07-05' },
    ],
    debts: [],
    recurring: [],
    goals: [],
  });

  test('a discretionary hot category keeps the gentle ease-back nudge', () => {
    const hot = decisionCandidates(hotData('Shopping'), REF).find((c) => c.kind === 'hot');
    expect(hot).toBeTruthy();
    expect(hot.message).toContain('Easing back');
  });

  test('discretionary "Media" keeps the ease-back number copy (no over-match on "med")', () => {
    const hot = decisionCandidates(hotData('Media'), REF).find((c) => c.kind === 'hot');
    expect(hot).toBeTruthy();
    expect(hot.message).toContain('Easing back frees');
    expect(hot.message).toContain('₱'); // the actual overspend number is stated
  });

  test('essential "Kuryente" gets the soft copy with no cut language', () => {
    const hot = decisionCandidates(hotData('Kuryente'), REF).find((c) => c.kind === 'hot');
    expect(hot).toBeTruthy();
    expect(hot.message).toContain('worth a look');
    expect(hot.message).not.toMatch(/eas/i);
    expect(hot.message).not.toMatch(/frees/i);
    expect(hot.message).not.toMatch(/trim/i);
  });

  test('essential "Groceries" gets the soft copy with no cut language', () => {
    const hot = decisionCandidates(hotData('Groceries'), REF).find((c) => c.kind === 'hot');
    expect(hot).toBeTruthy();
    expect(hot.message).toContain('worth a look');
    expect(hot.message).not.toMatch(/eas/i);
    expect(hot.message).not.toMatch(/frees/i);
  });
});

describe('guardrail: survival before aspiration', () => {
  test('a behind goal softens to pause when nothing is free this cycle', () => {
    const data = crunchBase();
    data.goals = [{ id: 'g', name: 'Trip', target: 10000, saved: 2000, targetDate: '2026-06-01' }];
    const goal = decisionCandidates(data, REF).find((c) => c.kind === 'goal');
    expect(goal).toBeTruthy();
    expect(goal.message).toContain('pause this goal muna');
    expect(goal.message).not.toContain('Set a fresh date');
  });

  test('a behind goal keeps the normal fund-and-reset nudge when money is free', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 50000 }],
      recurring: [],
      debts: [],
      transactions: [],
      goals: [{ id: 'g', name: 'Trip', target: 10000, saved: 2000, targetDate: '2026-06-01' }],
    };
    const goal = decisionCandidates(data, REF).find((c) => c.kind === 'goal');
    expect(goal).toBeTruthy();
    expect(goal.message).toContain('Set a fresh date');
    expect(goal.message).not.toContain('pause this goal muna');
  });
});

describe('LOG TODAY candidate', () => {
  test('fires when nothing is logged today on a started app, routing to Home', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 20000 }],
      transactions: [{ type: 'expense', label: 'Coffee', amount: 100, date: '2026-07-05' }],
      debts: [],
      recurring: [],
      goals: [],
    };
    const log = decisionCandidates(data, REF).find((c) => c.kind === 'logtoday');
    expect(log).toBeTruthy();
    expect(log.prio).toBe(58);
    expect(log.action.route).toBe('/');
  });

  test('does not fire on a brand-new empty app', () => {
    const log = decisionCandidates({}, REF).find((c) => c.kind === 'logtoday');
    expect(log).toBeUndefined();
  });

  test('does not fire when something is already logged today', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 20000 }],
      transactions: [{ type: 'expense', label: 'Coffee', amount: 100, date: '2026-07-10' }],
      debts: [],
      recurring: [],
      goals: [],
    };
    const log = decisionCandidates(data, REF).find((c) => c.kind === 'logtoday');
    expect(log).toBeUndefined();
  });
});

describe('EMERGENCY BUFFER THIN candidate', () => {
  test('fires when under a month covered and money is free', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 2000 }],
      // Two completed months of spending so the runway is real, not a guess
      // from a single sparse month.
      transactions: [
        { type: 'expense', label: 'x', amount: 8000, date: '2026-06-10' },
        { type: 'expense', label: 'x', amount: 8000, date: '2026-05-10' },
      ],
      debts: [],
      recurring: [],
      goals: [],
    };
    const buf = decisionCandidates(data, REF).find((c) => c.kind === 'buffer');
    expect(buf).toBeTruthy();
    expect(buf.prio).toBe(55);
    expect(buf.action.route).toBe('/goals');
  });

  test('is suppressed when nothing is free this cycle', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 1000 }],
      recurring: [{ id: 'r', type: 'expense', label: 'Rent', amount: 5000, dayOfMonth: 12 }],
      transactions: [{ type: 'expense', label: 'x', amount: 8000, date: '2026-06-10' }],
      debts: [],
      goals: [],
    };
    const buf = decisionCandidates(data, REF).find((c) => c.kind === 'buffer');
    expect(buf).toBeUndefined();
  });
});

describe('weeklyCheckIn stays the single top Home decision', () => {
  test('its top item equals the first non-nudge candidate', () => {
    const data = crunchBase();
    data.goals = [{ id: 'g', name: 'Trip', target: 10000, saved: 2000, targetDate: '2026-06-01' }];
    const cands = decisionCandidates(data, REF);
    const top = cands.find((c) => c.kind !== 'logtoday' && c.kind !== 'buffer');
    const wc = weeklyCheckIn(data, REF);
    expect(wc.kind).toBe(top.kind);
    expect(wc.title).toBe(top.title);
    expect(wc.message).toBe(top.message);
    expect(wc.action).toEqual(top.action);
    expect(wc.week).toBe(weekKey(REF));
  });

  test('Home excludes logtoday and buffer: when only those fire, Home is quiet but Insights still carries them', () => {
    // A started app with money free and under a month of buffer, nothing logged
    // today: only logtoday (58) and buffer (55) qualify, no real decision.
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 2000 }],
      transactions: [
        { type: 'expense', label: 'x', amount: 8000, date: '2026-06-10' },
        { type: 'expense', label: 'x', amount: 8000, date: '2026-05-10' },
      ],
      debts: [],
      recurring: [],
      goals: [],
    };
    const kinds = decisionCandidates(data, REF).map((c) => c.kind);
    // Insights (the full feed) carries both nudges.
    expect(kinds).toContain('logtoday');
    expect(kinds).toContain('buffer');
    // Home stays quiet: the all-clear, never a nudge.
    const wc = weeklyCheckIn(data, REF);
    expect(wc.kind).toBe('good');
    expect(wc.action).toBeNull();
  });

  test('returns the calm all-clear when nothing needs a decision', () => {
    const wc = weeklyCheckIn({}, REF);
    expect(wc.kind).toBe('good');
    expect(wc.action).toBeNull();
    expect(wc.week).toBe(weekKey(REF));
  });
});

describe('pickWin honesty', () => {
  test('never celebrates a savings rate when logging is sparse', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 1000 }],
      transactions: [
        { type: 'income', label: 'Sal', amount: 10000, date: '2026-07-02' },
        { type: 'expense', label: 'x', amount: 2000, date: '2026-07-02' },
      ],
      debts: [],
      goals: [],
      payments: [],
    };
    // Only one logged day, and it is outside the last 7, so the savings rate is
    // a mirage. pickWin must return nothing rather than a hollow high five.
    expect(pickWin(data, REF)).toBeNull();
  });

  test('celebrates a positive savings rate when logging is healthy (reachable win)', () => {
    // Income plus 4 logged days in the last 7: a real positive rate, so the
    // savings-rate win fires ahead of the streak fallback.
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 1000 }],
      transactions: [
        { type: 'income', label: 'Sal', amount: 20000, date: '2026-07-07' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-08' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-09' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-10' },
      ],
      debts: [],
      goals: [],
      payments: [],
    };
    const win = pickWin(data, REF);
    expect(win).toBeTruthy();
    expect(win.text).toContain('kept');
    expect(win.text).toContain('of your income this month');
  });

  test('celebrates a real logging streak when there is no income to rate', () => {
    const data = {
      settings: { ...SEMI },
      accounts: [{ id: 'a', kind: 'cash', balance: 1000 }],
      transactions: [
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-07' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-08' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-09' },
        { type: 'expense', label: 'x', amount: 100, date: '2026-07-10' },
      ],
      debts: [],
      goals: [],
      payments: [],
    };
    const win = pickWin(data, REF);
    expect(win).toBeTruthy();
    expect(win.text).toContain('logged 4 of the last 7');
  });

  test('celebrates net worth up versus the last check-in first of all', () => {
    const data = {
      settings: { ...SEMI, nwHistory: [{ month: '2026-06', value: 40000 }] },
      accounts: [{ id: 'a', kind: 'cash', balance: 50000 }],
      assets: [],
      debts: [],
      goals: [],
      transactions: [],
      payments: [],
    };
    const win = pickWin(data, REF);
    expect(win).toBeTruthy();
    expect(win.text).toContain('net worth is up');
    expect(win.text).toContain('since your last check-in');
  });
});
