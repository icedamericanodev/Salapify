// Regression suite for lib/statements.js: the three personal financial
// statements. The balance sheet identity (Assets = Liabilities + Equity), the
// income statement (earnings, not cash movement), and the cash flow statement
// (operating/investing/financing that reconciles to the cash that moved).

import { balanceSheet, incomeStatement, cashFlowStatement } from '../lib/statements';

const REF = new Date(2026, 6, 15); // 15 July 2026

describe('balanceSheet: Assets = Liabilities + Equity', () => {
  test('splits current vs long term and balances', () => {
    const data = {
      accounts: [
        { id: 'a1', kind: 'cash', balance: 2000 },
        { id: 'a2', kind: 'ewallet', balance: 8000 },
      ],
      assets: [{ id: 'as1', value: 50000 }], // long term (investment/thing owned)
      debts: [
        { id: 'd1', type: 'credit card', remaining: 5000 }, // current
        { id: 'd2', type: 'personal loan', remaining: 30000 }, // long term
      ],
      receivables: [{ id: 'r1', cashLeg: true, amount: 1000, payments: [] }],
      payables: [{ id: 'p1', cashLeg: true, amount: 2000, payments: [] }],
    };
    const bs = balanceSheet(data);
    expect(bs.cash).toBe(2000);
    expect(bs.bank).toBe(8000);
    expect(bs.receivables).toBe(1000);
    expect(bs.investments).toBe(50000);
    expect(bs.currentAssets).toBe(11000); // 2000 + 8000 + 1000
    expect(bs.longTermAssets).toBe(50000);
    expect(bs.totalAssets).toBe(61000);
    expect(bs.shortDebts).toBe(5000);
    expect(bs.longDebts).toBe(30000);
    expect(bs.payables).toBe(2000);
    expect(bs.currentLiabilities).toBe(7000); // 5000 + 2000
    expect(bs.longTermLiabilities).toBe(30000);
    expect(bs.totalLiabilities).toBe(37000);
    expect(bs.equity).toBe(24000); // 61000 - 37000
    // The identity must hold.
    expect(bs.totalAssets).toBe(bs.totalLiabilities + bs.equity);
    expect(bs.balances).toBe(true);
  });

  test('a fresh user with nothing is all zeros and still balances', () => {
    const bs = balanceSheet({});
    expect(bs.totalAssets).toBe(0);
    expect(bs.equity).toBe(0);
    expect(bs.balances).toBe(true);
  });

  test('negative net worth still balances (owe more than you own)', () => {
    const bs = balanceSheet({
      accounts: [{ id: 'a1', kind: 'cash', balance: 1000 }],
      debts: [{ id: 'd1', type: 'personal loan', remaining: 10000 }],
    });
    expect(bs.equity).toBe(-9000);
    expect(bs.totalAssets).toBe(bs.totalLiabilities + bs.equity);
  });
});

describe('incomeStatement: earnings, not cash movement', () => {
  test('income minus expenses, interest called out', () => {
    const data = {
      transactions: [
        { type: 'income', amount: 30000, date: '2026-07-01' },
        { type: 'expense', amount: 8000, date: '2026-07-05' },
        { type: 'expense', amount: 600, date: '2026-07-06', source: 'interest' },
        // Not income: utang collected. Not counted.
        { type: 'income', amount: 1000, date: '2026-07-07', source: 'receivable' },
        // Not this month.
        { type: 'income', amount: 99999, date: '2026-06-30' },
      ],
    };
    const is = incomeStatement(data, REF);
    expect(is.income).toBe(30000);
    expect(is.expenses).toBe(8600);
    expect(is.interestExpense).toBe(600);
    expect(is.spendingExpense).toBe(8000);
    expect(is.netIncome).toBe(21400);
  });
});

describe('cashFlowStatement: sections reconcile to the cash that moved', () => {
  test('operating, financing, and a debt payment all reconcile', () => {
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [
        { type: 'income', amount: 30000, date: '2026-07-01', accountId: 'a1' }, // op in
        { type: 'expense', amount: 8000, date: '2026-07-05', accountId: 'a1' }, // op out
        { type: 'transfer', flow: 'in', amount: 5000, date: '2026-07-03', accountId: 'a1', source: 'payable' }, // borrowed: fin in
        { type: 'transfer', flow: 'out', amount: 2000, date: '2026-07-04', accountId: 'a1', source: 'receivable' }, // lent: fin out
        // interest expense from a debt payment has no accountId: excluded here.
        { type: 'expense', amount: 600, date: '2026-07-06', source: 'interest' },
        // principal record has no accountId: excluded here.
        { type: 'debt', amount: 4400, date: '2026-07-06' },
      ],
      payments: [
        { id: 'pm1', debtId: 'd1', account: 'a1', amount: 5000, interest: 600, principal: 4400, date: '2026-07-06' },
      ],
    };
    const cf = cashFlowStatement(data, REF);
    // Operating: 30000 in, 8000 spending + 600 interest out.
    expect(cf.operating.in).toBe(30000);
    expect(cf.operating.out).toBe(8600);
    expect(cf.operating.net).toBe(21400);
    // Financing: 5000 borrowed in, 2000 lent + 4400 principal out.
    expect(cf.financing.in).toBe(5000);
    expect(cf.financing.out).toBe(6400);
    expect(cf.financing.net).toBe(-1400);
    expect(cf.interestPaid).toBe(600);
    expect(cf.principalPaid).toBe(4400);
    // Net change: 21400 - 1400 = 20000. Reconciles to the raw account movement:
    // +30000 -8000 +5000 -2000 (linked txns) -5000 (debt payment) = 20000.
    expect(cf.netChange).toBe(20000);
    expect(cf.reconciles).toBe(true);
    expect(cf.recorded).toBe(20000);
  });

  test('a payment made Outside the app moves no in app cash', () => {
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [{ type: 'income', amount: 1000, date: '2026-07-01', accountId: 'a1' }],
      payments: [
        { id: 'pm1', debtId: 'd1', account: '', amount: 5000, interest: 600, principal: 4400, date: '2026-07-06' },
      ],
    };
    const cf = cashFlowStatement(data, REF);
    expect(cf.principalPaid).toBe(0);
    expect(cf.interestPaid).toBe(0);
    expect(cf.netChange).toBe(1000);
    expect(cf.reconciles).toBe(true);
  });

  test('legacy payment with no split counts the whole amount as principal', () => {
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [],
      payments: [{ id: 'pm1', debtId: 'd1', account: 'a1', amount: 3000, date: '2026-07-06' }],
    };
    const cf = cashFlowStatement(data, REF);
    expect(cf.principalPaid).toBe(3000);
    expect(cf.interestPaid).toBe(0);
    expect(cf.financing.out).toBe(3000);
    expect(cf.netChange).toBe(-3000);
    expect(cf.reconciles).toBe(true);
  });

  test('an imported payment with interest but no principal still reconciles', () => {
    // Principal is derived as amount minus interest, so the sections always sum
    // back to the amount that left the account.
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [],
      payments: [{ id: 'pm1', debtId: 'd1', account: 'a1', amount: 5000, interest: 600, date: '2026-07-06' }],
    };
    const cf = cashFlowStatement(data, REF);
    expect(cf.interestPaid).toBe(600);
    expect(cf.principalPaid).toBe(4400);
    expect(cf.netChange).toBe(-5000);
    expect(cf.reconciles).toBe(true);
  });

  test('a balance adjustment is left out of the cash flow but still reconciles', () => {
    // The adjustment moved the account balance (net worth reflects it), but it is
    // a manual reconciliation, not a real cash flow, so it does not appear here
    // and does not break the reconcile check.
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [
        { type: 'income', amount: 1000, date: '2026-07-01', accountId: 'a1' },
        { type: 'adjustment', flow: 'in', amount: 500, date: '2026-07-02', accountId: 'a1', label: 'Balance adjustment' },
      ],
      payments: [],
    };
    const cf = cashFlowStatement(data, REF);
    expect(cf.operating.in).toBe(1000); // the 500 adjustment is NOT counted
    expect(cf.netChange).toBe(1000);
    expect(cf.reconciles).toBe(true);
  });

  test('a transaction with no date is not counted in any month', () => {
    const data = {
      accounts: [{ id: 'a1', kind: 'cash', balance: 0 }],
      transactions: [
        { type: 'income', amount: 1000, date: '2026-07-01', accountId: 'a1' },
        { type: 'income', amount: 9999, accountId: 'a1' }, // no date: must be excluded
      ],
      payments: [],
    };
    const cf = cashFlowStatement(data, REF);
    expect(cf.operating.in).toBe(1000);
    expect(cf.netChange).toBe(1000);
    const is = incomeStatement(data, REF);
    expect(is.income).toBe(1000);
  });
});
