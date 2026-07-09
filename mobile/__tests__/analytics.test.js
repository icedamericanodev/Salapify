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
  netWorth,
  trackedRemaining,
  splitDebtPayment,
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

describe('netWorth is one formula, counting only tracked utang', () => {
  test('with no utang it is accounts + assets - debts', () => {
    const data = {
      accounts: [{ balance: 20000 }, { balance: 5000 }],
      assets: [{ value: 100000 }],
      debts: [{ remaining: 30000 }],
      receivables: [],
      payables: [],
    };
    expect(netWorth(data)).toBe(95000); // 25000 + 100000 - 30000
  });
  test('legacy utang (no cash leg) is excluded, so the number never jumps', () => {
    const data = {
      accounts: [{ balance: 10000 }],
      receivables: [{ amount: 5000, paid: false, payments: [] }], // no cashLeg
      payables: [{ amount: 2000, paid: false, payments: [] }],
    };
    expect(netWorth(data)).toBe(10000); // utang without a cash leg does not count
  });
  test('tracked utang counts: receivable adds, payable subtracts, net of payments', () => {
    const data = {
      accounts: [{ balance: 10000 }],
      receivables: [{ amount: 5000, paid: false, cashLeg: true, payments: [{ amount: 2000 }] }],
      payables: [{ amount: 3000, paid: false, cashLeg: true, payments: [] }],
    };
    // 10000 + (5000 - 2000 remaining) - 3000 = 10000
    expect(netWorth(data)).toBe(10000);
    expect(trackedRemaining(data.receivables)).toBe(3000);
    expect(trackedRemaining(data.payables)).toBe(3000);
  });
  test('a paid tracked utang no longer counts', () => {
    const data = {
      accounts: [{ balance: 1000 }],
      receivables: [{ amount: 5000, paid: true, cashLeg: true, payments: [{ amount: 5000 }] }],
    };
    expect(netWorth(data)).toBe(1000);
  });
});

describe('splitDebtPayment splits interest and principal by day-count', () => {
  test('a full month elapsed: 20000 at 3%, pay 5000 -> 600 interest, 4400 principal, 15600 left', () => {
    const r = splitDebtPayment(20000, 3, '2026-06-09', 5000, '2026-07-09'); // 30 days
    expect(r.interest).toBe(600);
    expect(r.principal).toBe(4400);
    expect(r.newRemaining).toBe(15600);
    expect(r.overpay).toBe(0);
  });
  test('a second payment the same day books no more interest (no double count)', () => {
    // interestThroughISO is now today, so 0 days elapsed -> 0 accrued.
    const r = splitDebtPayment(15600, 3, '2026-07-09', 5000, '2026-07-09');
    expect(r.interest).toBe(0);
    expect(r.principal).toBe(5000);
    expect(r.newRemaining).toBe(10600);
  });
  test('a 0% debt: whole payment is principal', () => {
    const r = splitDebtPayment(10000, 0, '2026-06-09', 3000, '2026-07-09');
    expect(r.interest).toBe(0);
    expect(r.principal).toBe(3000);
    expect(r.newRemaining).toBe(7000);
  });
  test('no stamp: first payment accrues 0, never back-accrues history', () => {
    const r = splitDebtPayment(20000, 3, undefined, 5000, '2026-07-09');
    expect(r.interest).toBe(0);
    expect(r.principal).toBe(5000);
    expect(r.newRemaining).toBe(15000);
  });
  test('overpayment is clamped: never pay or be charged more than owed', () => {
    const r = splitDebtPayment(5000, 0, '2026-07-09', 6000, '2026-07-09');
    expect(r.applied).toBe(5000);
    expect(r.newRemaining).toBe(0);
    expect(r.overpay).toBe(1000);
  });
  test('a payment below the accrued interest grows the balance (negative amortization)', () => {
    // 30 days at 3% on 20000 = 600 interest; pay only 100.
    const r = splitDebtPayment(20000, 3, '2026-06-09', 100, '2026-07-09');
    expect(r.interest).toBe(100);
    expect(r.principal).toBe(0);
    expect(r.newRemaining).toBe(20500); // 20600 balance - 100 applied
  });
  test('a malformed stamp never poisons the balance with NaN', () => {
    // A non-date string makes the day-count diff NaN, which would wipe the debt
    // on the next save. The guard accrues 0 instead of propagating NaN.
    const r = splitDebtPayment(20000, 3, 'not-a-date', 5000, '2026-07-09');
    expect(Number.isFinite(r.newRemaining)).toBe(true);
    expect(r.interest).toBe(0);
    expect(r.principal).toBe(5000);
    expect(r.newRemaining).toBe(15000);
  });
});

describe('savingsRate is earnings minus spending, principal paydown excluded', () => {
  test('income minus expenses over income for this month', () => {
    const tx = [
      { type: 'income', amount: 20000, date: '2026-07-01' },
      { type: 'expense', amount: 10000, date: '2026-07-05' },
    ];
    expect(savingsRate(tx, [], REF)).toBe(0.5);
  });
  test('debt INTEREST (an expense) lowers the rate, but principal paydown does not', () => {
    // A debt payment now posts the principal as a type:debt record (skipped by
    // the expense filter) and only the interest as an expense. So the rate is
    // dented only by interest, not by the principal that builds net worth.
    const tx = [
      { type: 'income', amount: 20000, date: '2026-07-01' },
      { type: 'debt', amount: 4400, date: '2026-07-03' }, // principal, not spending
      { type: 'expense', amount: 600, date: '2026-07-03', source: 'interest' }, // interest, spending
    ];
    expect(savingsRate(tx, [], REF)).toBe(0.97); // (20000 - 600) / 20000
  });
  test('no income yields null, never a divide-by-zero', () => {
    expect(savingsRate([], [], REF)).toBeNull();
  });
  test('repaid utang is not counted as income (own money coming home)', () => {
    const tx = [
      { type: 'income', amount: 20000, date: '2026-07-01' },
      { type: 'income', amount: 5000, date: '2026-07-02', source: 'receivable' }, // someone paid you back
      { type: 'expense', amount: 10000, date: '2026-07-05' },
    ];
    // Only the 20000 real income counts: (20000 - 10000) / 20000 = 0.5,
    // not (25000 - 10000) / 25000 = 0.6.
    expect(savingsRate(tx, [], REF)).toBe(0.5);
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
