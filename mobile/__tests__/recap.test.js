// Regression suite for lib/recap.js: the monthly recap that feeds the share
// card. The money-in and kept-rate must match the income statement and savings
// rate, so utang you collected is not counted as income.

import { monthRecap } from '../lib/recap';

const REF = new Date(2026, 6, 15); // 15 July 2026

describe('monthRecap money in matches the income statement', () => {
  test('utang collected is not income and does not lift the kept rate', () => {
    const data = {
      transactions: [
        { type: 'income', amount: 20000, date: '2026-07-01' },
        { type: 'expense', amount: 10000, date: '2026-07-05' },
        // Collecting a legacy receivable: real income row tagged source
        // receivable. Not earnings, so excluded from money in and kept rate.
        { type: 'income', amount: 3000, date: '2026-07-07', source: 'receivable' },
      ],
    };
    const r = monthRecap(data, REF);
    expect(r.moneyIn).toBe(20000);
    expect(r.moneyOut).toBe(10000);
    // Kept 10000 of 20000 = 50%, not 13000/23000.
    expect(r.keptRate).toBe(0.5);
    // The utang collection still counts as a day you logged.
    expect(r.daysLogged).toBe(3);
  });
});
