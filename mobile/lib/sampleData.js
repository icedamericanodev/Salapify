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
];

// Transactions: money in (income) and money out (expense) for this month.
export const sampleTransactions = [
  { id: 't1', type: 'income', label: 'Salary', amount: 15000, account: 'bpi' },
  { id: 't2', type: 'income', label: 'Freelance', amount: 4000, account: 'gcash' },
  { id: 't3', type: 'expense', label: 'Groceries', amount: 2300, account: 'cash' },
  { id: 't4', type: 'expense', label: 'Transport', amount: 850, account: 'gcash' },
  { id: 't5', type: 'expense', label: 'Bills', amount: 3200, account: 'bpi' },
];
