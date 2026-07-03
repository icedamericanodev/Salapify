// Backup, restore, CSV export, and v1 import helpers. Everything is text based
// (JSON or CSV) so it works on web and on the phone without any native file
// libraries. The screens show the text to copy, and on web also offer a
// download button.

import { todayISO } from './format';

const num = (x) => {
  const n = Number(x);
  return Number.isFinite(n) ? n : 0;
};
const asArray = (x) => (Array.isArray(x) ? x : []);
const isObj = (x) => !!x && typeof x === 'object' && !Array.isArray(x);
const cleanList = (x) => asArray(x).filter(isObj);

// Undated history gets stamped onto the first day of last month, never
// today: unknown old entries must not inflate this month's totals.
function legacyDate() {
  const now = new Date();
  return todayISO(new Date(now.getFullYear(), now.getMonth() - 1, 1));
}

// The data shape version this build understands. Bump it together with a
// new entry in MIGRATIONS whenever the stored shape changes.
export const SCHEMA_VERSION = 2;

// Forward only migrations, keyed by the version each one PRODUCES. Every
// migration is a pure function of the blob: no clock tricks that make it
// unrepeatable, nothing async, no device state. They run before coercion,
// and they must never drop fields they do not understand.
//
// GUARDRAIL: adding a new TOP LEVEL collection always requires bumping
// SCHEMA_VERSION with a migration, because sanitizeData rebuilds a fixed
// key list; an unknown collection restored by an older build would be
// silently dropped instead of refused.
const MIGRATIONS = {
  // 3: (d) => ({ ...d, people: [...] }),  // example shape for the future
};

// Bring an older blob forward one version at a time. A blob NEWER than
// this build (someone restored a backup from a fresher app onto an old
// binary) is refused loudly rather than mangled quietly.
function migrate(raw) {
  let d = raw;
  // Hostile or garbage version values (Infinity, NaN, negatives, strings)
  // must clamp to 2, never feed the loop: -Infinity plus one is still
  // -Infinity and would hang the app forever.
  let v = Math.trunc(Number(d.schemaVersion));
  if (!Number.isFinite(v) || v < 1) v = 2;
  if (v > SCHEMA_VERSION) {
    throw new Error(
      'This data comes from a newer version of Salapify. Update the app first, then try again. Nothing was changed.'
    );
  }
  while (v < SCHEMA_VERSION) {
    v += 1;
    if (MIGRATIONS[v]) d = MIGRATIONS[v](d);
    d = { ...d, schemaVersion: v };
  }
  return d;
}

// sanitizeData coerces any imported, restored, or loaded blob into a shape
// the app can never crash on: every collection a real array of objects,
// every money field a finite number, every transaction and payment dated.
// It migrates old shapes forward first, then coerces. A restored backup
// also gets appLock forced off (keepAppLock false), so a backup made on a
// phone with a fingerprint can never lock someone out of a phone without
// one.
export function sanitizeData(raw, { keepAppLock = false } = {}) {
  const src = migrate(isObj(raw) ? raw : {});
  const stampDate = legacyDate();
  const dated = (list) =>
    cleanList(list).map((it) => ({
      ...it,
      date: typeof it.date === 'string' && it.date ? it.date : stampDate,
    }));
  const settings = isObj(src.settings) ? src.settings : {};
  const str = (x, fallback = '') => (typeof x === 'string' ? x : fallback);
  return {
    schemaVersion: SCHEMA_VERSION,
    accounts: cleanList(src.accounts).map((a) => ({
      ...a,
      name: str(a.name, 'Account'),
      brand: str(a.brand),
      icon: str(a.icon),
      balance: num(a.balance),
      target: num(a.target),
    })),
    assets: cleanList(src.assets).map((a) => ({ ...a, value: num(a.value) })),
    debts: cleanList(src.debts).map((d) => ({
      ...d,
      remaining: num(d.remaining),
      monthlyRate: num(d.monthlyRate),
      minPayment: num(d.minPayment),
      dueDay: num(d.dueDay),
      statementDay: num(d.statementDay),
      graceDays: num(d.graceDays),
      creditLimit: num(d.creditLimit),
    })),
    payments: dated(src.payments).map((p) => ({ ...p, amount: num(p.amount) })),
    transactions: dated(src.transactions).map((t) => {
      const out = {
        ...t,
        amount: num(t.amount),
        type: t.type === 'income' ? 'income' : 'expense',
        label: typeof t.label === 'string' && t.label ? t.label : 'Entry',
      };
      // receiptUri must be a string or absent: a non string here would
      // reach Image source.uri and crash native Android.
      if (typeof t.receiptUri === 'string' && t.receiptUri) out.receiptUri = t.receiptUri;
      else delete out.receiptUri;
      return out;
    }),
    goals: cleanList(src.goals).map((g) => ({
      ...g,
      target: num(g.target),
      saved: num(g.saved),
    })),
    wins: cleanList(src.wins),
    notes: cleanList(src.notes),
    recurring: cleanList(src.recurring).map((r, i) => ({
      ...r,
      // Amounts can never be negative (a negative expense would ADD money
      // every month), and every item needs an id or it could never be
      // edited or deleted again.
      id: typeof r.id === 'string' && r.id ? r.id : `recurring_restored_${i}`,
      type: r.type === 'income' ? 'income' : 'expense',
      label: str(r.label, 'Recurring'),
      amount: Math.max(0, num(r.amount)),
      dayOfMonth: Math.min(Math.max(Math.round(num(r.dayOfMonth)) || 1, 1), 31),
      accountId: str(r.accountId),
      lastPosted: str(r.lastPosted),
    })),
    receivables: cleanList(src.receivables).map((r) => ({
      ...r,
      person: typeof r.person === 'string' && r.person ? r.person : 'Someone',
      amount: num(r.amount),
      paid: !!r.paid,
    })),
    settings: {
      ...settings,
      monthlyLimit: num(settings.monthlyLimit),
      quickAdds: cleanList(settings.quickAdds),
      appLock: keepAppLock ? !!settings.appLock : false,
    },
  };
}

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
  return sanitizeData(data);
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

  return sanitizeData({
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
  });
}
