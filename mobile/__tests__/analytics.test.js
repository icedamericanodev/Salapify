// Regression suite for lib/analytics.js: the derived numbers that drive real
// decisions. Focus is the boundary and empty-data cases where a bug quietly
// invents or hides money. Every function takes a fixed ref date.

import {
  upcomingCommitments,
  safeToSpend,
  savingsRate,
  emergencyRunway,
  goalPace,
  debtFreeProjection,
  monthlySeries,
} from '../lib/analytics';

const REF = new Date(2026, 6, 10); // 10 July 2026
const SEMI = { paydaySchedule: { mode: 'semimonthly', days: [15, 31] } };

describe('upcomingCommitments totals the bills due before the next sweldo', () => {
  test('a recurring bill due before payday is committed', () => {
    const data = {
      settings: SEMI,
      debts: [],
      recurring: [{ id: 'r1', type: 'expense', label: 'Load', amount: 2000, dayOfMonth: 12 }],
    };
    const c = upcomingCommitments(data, REF);
    expect(c.total).toBe(2000);
    expect(c.daysLeft).toBe(5); // 10th to the 15th
    expect(c.bills).toHaveLength(1);
  });

  test('a recurring bill already posted this cycle is not double counted', () => {
    const data = {
      settings: SEMI,
      debts: [],
      recurring: [{ id: 'r1', type: 'expense', label: 'Load', amount: 2000, dayOfMonth: 12, lastPosted: '2026-07' }],
    };
    expect(upcomingCommitments(data, REF).total).toBe(0);
  });

  test('empty data commits nothing but still reports a real horizon', () => {
    const c = upcomingCommitments({ settings: SEMI }, REF);
    expect(c.total).toBe(0);
    expect(c.daysLeft).toBeGreaterThanOrEqual(1);
  });
});

describe('safeToSpend protects savings and sets aside committed bills', () => {
  const data = {
    settings: SEMI,
    accounts: [
      { id: 'a1', kind: 'cash', balance: 10000 },
      { id: 'a2', kind: 'savings', balance: 50000 },
    ],
    recurring: [{ id: 'r1', type: 'expense', label: 'Load', amount: 2000, dayOfMonth: 12 }],
  };

  test('only liquid accounts count, never savings', () => {
    expect(safeToSpend(data, REF).liquid).toBe(10000);
  });
  test('available is liquid minus committed bills', () => {
    expect(safeToSpend(data, REF).available).toBe(8000);
  });
  test('per day spreads what is available over the days to payday', () => {
    expect(safeToSpend(data, REF).perDay).toBe(1600); // 8000 / 5
  });
  test('no money and no bills is a calm zero, never a crash', () => {
    const s = safeToSpend({ settings: SEMI }, REF);
    expect(s.available).toBe(0);
    expect(s.perDay).toBe(0);
  });
});

describe('savingsRate counts debt payments as money out', () => {
  test('income minus expenses over income for this month', () => {
    const tx = [
      { type: 'income', amount: 20000, date: '2026-07-01' },
      { type: 'expense', amount: 10000, date: '2026-07-05' },
    ];
    expect(savingsRate(tx, [], REF)).toBe(0.5);
  });
  test('a debt payment lowers the savings rate', () => {
    const tx = [{ type: 'income', amount: 20000, date: '2026-07-01' }];
    const payments = [{ amount: 5000, date: '2026-07-03' }];
    expect(savingsRate(tx, payments, REF)).toBe(0.75); // (20000 - 0 - 5000) / 20000
  });
  test('no income yields null, never a divide-by-zero', () => {
    expect(savingsRate([], [], REF)).toBeNull();
  });
});

describe('emergencyRunway uses the median of completed months', () => {
  const data = {
    accounts: [{ kind: 'cash', balance: 25000 }],
    transactions: [
      { type: 'expense', amount: 5000, date: '2026-01-15' },
      { type: 'expense', amount: 5000, date: '2026-02-15' },
      { type: 'expense', amount: 15000, date: '2026-03-15' }, // one-off big month
    ],
  };
  test('the median resists a one-off big month', () => {
    // completed expenses [5000, 5000, 15000] -> median 5000
    expect(emergencyRunway(data, REF).avgMonthlyExpense).toBe(5000);
  });
  test('months covered divides the buffer by the typical spend', () => {
    expect(emergencyRunway(data, REF).monthsCovered).toBe(5); // 25000 / 5000
  });
  test('a brand new user with no history gets null, never a made-up number', () => {
    const runway = emergencyRunway({ accounts: [{ kind: 'cash', balance: 25000 }], transactions: [] }, REF);
    expect(runway.monthsCovered).toBeNull();
    expect(runway.avgMonthlyExpense).toBe(0);
  });
  test('a single sparse month is not enough: null, not a huge number', () => {
    // One completed month with only 120 logged would divide 25000 into ~208
    // months. We refuse to quote it until there are two real months.
    const runway = emergencyRunway({
      accounts: [{ kind: 'cash', balance: 25000 }],
      transactions: [{ type: 'expense', amount: 120, date: '2026-02-15' }],
    }, REF);
    expect(runway.monthsCovered).toBeNull();
    expect(runway.capped).toBe(false);
  });
  test('a real but very long runway is capped at 12+, never a silly figure', () => {
    // Two thin months (120 median) against a real balance would be ~208
    // months; we cap the claim at 12 and flag it so the screen shows "12+".
    const runway = emergencyRunway({
      accounts: [{ kind: 'cash', balance: 25000 }],
      transactions: [
        { type: 'expense', amount: 120, date: '2026-01-15' },
        { type: 'expense', amount: 120, date: '2026-02-15' },
      ],
    }, REF);
    expect(runway.monthsCovered).toBe(12);
    expect(runway.capped).toBe(true);
  });
});

describe('goalPace reports an honest status for every deadline', () => {
  test('no target means no pace to compute', () => {
    expect(goalPace({ target: 0, saved: 0 }, REF).status).toBe('no-target');
  });
  test('a fully funded goal reads as done', () => {
    expect(goalPace({ target: 10000, saved: 10000 }, REF).status).toBe('done');
  });
  test('a future deadline gives a catch-up monthly pace', () => {
    const p = goalPace({ target: 12000, saved: 0, targetDate: '2026-12' }, REF);
    expect(p.status).toBe('active');
    expect(p.perMonth).toBeGreaterThan(0);
  });
  test('a truly past deadline reads as behind', () => {
    expect(goalPace({ target: 10000, saved: 1000, targetDate: '2026-01' }, REF).status).toBe('behind');
  });
});

describe('debtFreeProjection simulates payoff month by month', () => {
  test('a simple interest-free debt is paid off on schedule', () => {
    const debts = [{ remaining: 10000, monthlyRate: 0, minPayment: 2000 }];
    const proj = debtFreeProjection(debts, 'avalanche', 0, REF);
    expect(proj.months).toBe(5); // 10000 / 2000
    expect(proj.totalInterest).toBe(0);
  });
  test('no debts means already free', () => {
    expect(debtFreeProjection([], 'avalanche', 0, REF).months).toBe(0);
  });
  test('minimums that can never beat the interest return null, never loop forever', () => {
    const debts = [{ remaining: 100000, monthlyRate: 10, minPayment: 100 }];
    expect(debtFreeProjection(debts, 'avalanche', 0, REF)).toBeNull();
  });
});

describe('monthlySeries never lies by omission', () => {
  test('months with no data still appear as zero rows', () => {
    const series = monthlySeries([], 6, REF);
    expect(series).toHaveLength(6);
    expect(series.every((m) => m.income === 0 && m.expenses === 0)).toBe(true);
  });
});
