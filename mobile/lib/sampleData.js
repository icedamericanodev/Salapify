// sampleData.js gives the screens something to show while we build the look,
// before we connect the real on-device database in Phase 2. These are made up
// numbers. None of this is saved; it is just for designing the screens.

// Accounts: cash, savings, checking, and e-wallets. "kind" decides the group.
export const sampleAccounts = [
  { id: 'cash', name: 'Cash on hand', icon: '💵', brand: '', kind: 'cash', balance: 3200 },
  { id: 'bpi', name: 'BPI Savings', icon: '🏦', brand: 'BPI', kind: 'savings', balance: 48500 },
  { id: 'gcash', name: 'GCash', icon: '📱', brand: 'GCash', kind: 'ewallet', balance: 1750 },
];

// Assets: investments and other things you own that have value.
export const sampleAssets = [
  { id: 'a1', name: 'Crypto', kind: 'crypto', value: 12000 },
  { id: 'a2', name: 'MP2 Savings', kind: 'mp2', value: 25000 },
];

// Debts: what you owe. "remaining" is the current balance left to pay.
export const sampleDebts = [
  { id: 'd1', name: 'Credit Card', type: 'credit card', remaining: 18500, monthlyRate: 3.5, minPayment: 1500 },
  { id: 'd2', name: 'Personal Loan', type: 'personal loan', remaining: 42000, monthlyRate: 1.2, minPayment: 3500 },
  { id: 'd3', name: 'Phone (BNPL)', type: 'bnpl', remaining: 6000, monthlyRate: 0, minPayment: 1000 },
];

// Net worth over the last few months, for the Insights trend chart.
export const sampleNetWorthHistory = [
  { month: 'Feb', value: 12000 },
  { month: 'Mar', value: 15000 },
  { month: 'Apr', value: 18000 },
  { month: 'May', value: 21000 },
  { month: 'Jun', value: 23950 },
];

// Budget settings: the monthly spending limit and the quick add buttons used
// for fast logging.
export const sampleBudget = {
  monthlyLimit: 20000,
  quickAdds: [
    { label: 'Food', amount: 150 },
    { label: 'Transport', amount: 50 },
    { label: 'Coffee', amount: 120 },
    { label: 'Load', amount: 100 },
  ],
};

// Transactions: money in (income) and money out (expense) for this month.
// Dates are stamped inside the current month (never in the future) so the
// month filters on the screens have something real to show on first run.
const _now = new Date();
const _day = (n) => {
  const d = Math.min(n, _now.getDate());
  return `${_now.getFullYear()}-${String(_now.getMonth() + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
};
export const sampleTransactions = [
  { id: 't1', type: 'income', label: 'Salary', amount: 15000, account: 'bpi', date: _day(1) },
  { id: 't2', type: 'income', label: 'Freelance', amount: 4000, account: 'gcash', date: _day(3) },
  { id: 't3', type: 'expense', label: 'Groceries', amount: 2300, account: 'cash', date: _day(5) },
  { id: 't4', type: 'expense', label: 'Transport', amount: 850, account: 'gcash', date: _day(8) },
  { id: 't5', type: 'expense', label: 'Bills', amount: 3200, account: 'bpi', date: _day(10) },
];

// The habit features (logging chain, week recap) must never celebrate rows
// the user did not log. These are the ids of the demo rows above.
export const SAMPLE_TX_IDS = new Set(sampleTransactions.map((t) => t.id));
