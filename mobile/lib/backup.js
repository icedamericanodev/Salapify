// Backup, restore, CSV export, and v1 import helpers. Everything is text based
// (JSON or CSV) so it works on web and on the phone without any native file
// libraries. The screens show the text to copy, and on web also offer a
// download button.

const num = (x) => {
  const n = Number(x);
  return Number.isFinite(n) ? n : 0;
};
const asArray = (x) => (Array.isArray(x) ? x : []);

// Default quick-add buttons, used when an import does not bring usable ones.
const DEFAULT_QUICK_ADDS = [
  { label: 'Food', amount: 150 },
  { label: 'Transport', amount: 50 },
  { label: 'Coffee', amount: 120 },
  { label: 'Load', amount: 100 },
];

// Turn the whole app data into a backup JSON string.
export function buildBackup(data) {
  return JSON.stringify(
    { app: 'salapify', version: 2, exportedAt: new Date().toISOString(), data },
    null,
    2
  );
}

// Parse a Salapify v2 backup string back into a data object. Throws if it does
// not look like our backup.
export function parseBackup(text) {
  const obj = JSON.parse(text);
  const data = obj && obj.data ? obj.data : obj;
  if (!data || !Array.isArray(data.accounts)) {
    throw new Error('That does not look like a Salapify backup.');
  }
  return data;
}

// Make a simple CSV with transactions and debts.
export function toCSV(data) {
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const lines = [];
  lines.push('TRANSACTIONS');
  lines.push('date,type,label,amount');
  asArray(data.transactions).forEach((t) =>
    lines.push([esc(t.date || ''), esc(t.type), esc(t.label), num(t.amount)].join(','))
  );
  lines.push('');
  lines.push('DEBTS');
  lines.push('name,type,remaining,monthlyRate,minPayment');
  asArray(data.debts).forEach((d) =>
    lines.push(
      [esc(d.name), esc(d.type), num(d.remaining), num(d.monthlyRate), num(d.minPayment)].join(',')
    )
  );
  return lines.join('\n');
}

// Map a v1 (Peso Smart) backup into our v2 data shape. v1 item field names
// vary, so we read the likely fields and also keep the original fields, so
// nothing is thrown away.
export function parseV1(text) {
  const v1 = JSON.parse(text);
  if (!v1 || v1._app !== 'PesoSmart') {
    throw new Error('That does not look like a Peso Smart (v1) backup.');
  }
  const b = v1.budget || {};

  const accounts = [
    ...asArray(b.bankCash).map((a) => ({
      ...a,
      name: a.name || a.label || 'Account',
      kind: a.kind || (a.bank ? 'savings' : 'cash'),
      brand: a.brand || a.bank || '',
      icon: a.icon || '💵',
      balance: num(a.balance ?? a.bal ?? a.amount ?? a.value),
    })),
    ...asArray(b.savings).map((a) => ({
      ...a,
      name: a.name || a.label || 'Savings',
      kind: 'savings',
      brand: a.bank || a.brand || '',
      icon: a.icon || '🏦',
      balance: num(a.balance ?? a.amount ?? a.value ?? a.bal),
    })),
  ];

  const assets = asArray(b.otherAssets).map((a) => ({
    ...a,
    name: a.name || a.label || 'Asset',
    kind: a.kind || a.type || 'other',
    value: num(a.value ?? a.amount ?? a.bal),
  }));

  const debts = asArray(v1.debts).map((d) => ({
    ...d,
    name: d.name || d.label || 'Debt',
    type: d.type || 'other',
    remaining: num(d.remaining ?? d.balance ?? d.bal),
    monthlyRate: num(d.monthlyRate ?? d.rate),
    minPayment: num(d.minPayment ?? d.min),
  }));

  const payments = asArray(v1.payments);

  const expenses = asArray(b.expenses).map((e) => ({
    ...e,
    type: 'expense',
    label: e.label || e.category || e.cat || 'Expense',
    amount: num(e.amount ?? e.amt),
    date: e.date || '',
  }));
  const incomes = asArray(b.incomes).map((e) => ({
    ...e,
    type: 'income',
    label: e.label || e.source || e.src || 'Income',
    amount: num(e.amount ?? e.amt),
    date: e.date || '',
  }));
  const transactions = [...incomes, ...expenses];

  const goals = asArray((v1.goals || {}).goals).map((g) => ({
    ...g,
    name: g.name || g.label || 'Goal',
    target: num(g.target ?? g.targetAmount),
    saved: num(g.saved ?? g.savedAmount),
  }));

  return {
    accounts,
    assets,
    debts,
    payments,
    transactions,
    goals,
    settings: {
      currency: b.currency || '₱',
      monthlyLimit: num(b.monthlyBudget) || 20000,
      quickAdds: DEFAULT_QUICK_ADDS,
    },
  };
}
