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
export const SCHEMA_VERSION = 11;

// The starter categories every user gets, tuned to Filipino daily life.
// Stable ids on purpose: quick adds and transactions point at them.
export const DEFAULT_CATEGORIES = [
  { id: 'cat_food', name: 'Food', icon: '🍜', monthlyCap: 0 },
  { id: 'cat_transport', name: 'Transport', icon: '🚌', monthlyCap: 0 },
  { id: 'cat_load', name: 'Load', icon: '📱', monthlyCap: 0 },
  { id: 'cat_bills', name: 'Bills', icon: '💡', monthlyCap: 0 },
  { id: 'cat_groceries', name: 'Groceries', icon: '🛒', monthlyCap: 0 },
  { id: 'cat_fun', name: 'Fun', icon: '🎉', monthlyCap: 0 },
  { id: 'cat_padala', name: 'Padala', icon: '💸', monthlyCap: 0 },
  { id: 'cat_health', name: 'Health', icon: '💊', monthlyCap: 0 },
];

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
  // v3: the per person utang ledger. Distinct receivable names become a
  // people collection, receivables point at their person by id and gain a
  // partial payments list. The legacy person string stays on every
  // receivable so old readers and old code paths keep working.
  3: (d) => {
    const receivables = Array.isArray(d.receivables) ? d.receivables : [];
    let people = Array.isArray(d.people) ? [...d.people] : [];
    const keyOf = (name) => String(name || '').trim().toLowerCase();
    const byKey = new Map(people.map((p) => [keyOf(p && p.name), p]));
    // New ids must never collide with people from an earlier run: this
    // migration can legally run again on a blob whose version marker was
    // lost, so the counter seeds past every existing person_m3_ id.
    let n = 0;
    for (const p of people) {
      const m = /^person_m3_(\d+)$/.exec(p && p.id);
      if (m) n = Math.max(n, Number(m[1]) + 1);
    }
    const migrated = receivables.map((r) => {
      if (!r || typeof r !== 'object') return r;
      // Already linked to a person: nothing to invent, keep it exactly,
      // just guarantee the payments list exists. This makes a re run on
      // already migrated data a true no op.
      if (typeof r.personId === 'string' && r.personId) return { payments: [], ...r };
      const key = keyOf(r.person);
      if (!key) return { payments: [], ...r };
      let person = byKey.get(key);
      if (!person) {
        person = {
          id: `person_m3_${n++}`,
          name: String(r.person).trim(),
          phone: typeof r.phone === 'string' ? r.phone : '',
          note: '',
        };
        people.push(person);
        byKey.set(key, person);
      } else if (!person.phone && typeof r.phone === 'string' && r.phone) {
        // Pure update: never mutate an object from the caller's blob.
        const updated = { ...person, phone: r.phone };
        people = people.map((p) => (p === person ? updated : p));
        byKey.set(key, updated);
        person = updated;
      }
      return { payments: [], ...r, personId: person.id };
    });
    return { ...d, people, receivables: migrated };
  },
  // v4: categories. Existing users get the starter set; blobs that
  // already carry categories keep theirs. Existing transactions stay
  // uncategorized on purpose, guessing would be inventing history.
  4: (d) => {
    // cleanList, not raw length: a blob carrying [null] must not block
    // the seed and then coerce down to zero categories.
    if (cleanList(d.categories).length > 0) return { ...d };
    return { ...d, categories: DEFAULT_CATEGORIES.map((c) => ({ ...c })) };
  },
  // v5: transactions may now carry type "transfer" or "debt", the record
  // rows the transfer and debt payment flows write so History tells the
  // whole story. Old data has no such rows, so nothing to transform; the
  // bump exists as a fence, because a v4 build restoring a v5 backup would
  // coerce those records into expenses and double count real spending.
  5: (d) => ({ ...d }),
  // v6 adds settings.treats (the earn-your-treats wellness feature). A missing
  // array defaults to empty in sanitizeData, so no data transform is needed;
  // the fence just stops a v5 build from silently dropping a v6 backup's treats.
  6: (d) => ({ ...d }),
  // v7 adds the payables collection (People I owe, the mirror of receivables).
  // A missing array defaults to empty in sanitizeData, so no data transform is
  // needed; the fence just stops a v6 build from silently dropping a v7
  // backup's payables.
  7: (d) => ({ ...d }),
  // v8 adds cash leg tracking: utang can carry cashLeg + accountId + a lend or
  // borrow transaction id, and those transactions carry flow ('in'/'out'). No
  // data transform is needed (absent cashLeg defaults to legacy behavior); the
  // fence stops an older build from accepting a v8 backup and silently
  // understating net worth (it would see the reduced balance but not count the
  // tracked utang).
  8: (d) => ({ ...d }),
  // v9 adds the debt interest split: debts carry interestThroughISO, debt
  // payments carry interest/principal. No transform needed (absent fields
  // default safely: no back accrual, whole legacy payment treated as
  // principal); the fence stops an older build from mis-reading a v9 backup.
  9: (d) => ({ ...d }),
  // v10 adds the balance adjustment: editing an account's total posts a
  // transaction of type 'adjustment' (flow 'in'/'out', kept accountId) instead
  // of silently overwriting the balance. No transform needed, but the fence
  // stops an OLDER build from accepting a v10 backup and coercing the adjustment
  // into an account-linked phantom expense (which would double count spending
  // and, on a later edit or delete, shift the real balance).
  10: (d) => ({ ...d }),
  // v11 adds per transaction currency: an expense can carry origCurrency +
  // origAmount (its foreign amount), while the stored amount stays in the base
  // currency. No transform needed (absent means a plain base currency entry);
  // the fence stops an older build from accepting a v11 backup, though the
  // amount would read fine there, the foreign detail would just be invisible.
  11: (d) => ({ ...d }),
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
    cleanList(list).map((it) => {
      // ISO datetimes like 2025-07-15T09:00:00Z from imports become plain
      // dates, so month filters and sorting see one consistent format.
      let date = typeof it.date === 'string' && it.date ? it.date : stampDate;
      if (/^\d{4}-\d{2}-\d{2}T/.test(date)) date = date.slice(0, 10);
      return { ...it, date };
    });
  const settings = isObj(src.settings) ? src.settings : {};
  const str = (x, fallback = '') => (typeof x === 'string' ? x : fallback);
  return {
    schemaVersion: SCHEMA_VERSION,
    accounts: cleanList(src.accounts).map((a) => ({
      ...a,
      name: str(a.name, 'Account'),
      brand: str(a.brand),
      icon: str(a.icon),
      // Coerce an unknown or missing kind to a known one. The screens bucket
      // accounts by kind (Cash vs Bank) and analytics tests liquidity by kind,
      // so a stray kind from a legacy or hand edited backup would otherwise
      // drop the account out of those views. Valid kinds pass through
      // untouched; anything else defaults to cash, the app's default for a new
      // account. Balance still counts toward net worth either way.
      kind: ['cash', 'savings', 'checking', 'ewallet'].includes(a.kind) ? a.kind : 'cash',
      balance: num(a.balance),
      target: num(a.target),
    })),
    assets: cleanList(src.assets).map((a) => ({ ...a, value: num(a.value) })),
    debts: cleanList(src.debts).map((d) => ({
      ...d,
      // Text fields become strings too: screens call .trim() on these in
      // press handlers, where a number from a bad blob is a hard crash.
      name: str(d.name, 'Debt'),
      type: str(d.type, 'other'),
      remaining: num(d.remaining),
      monthlyRate: num(d.monthlyRate),
      minPayment: num(d.minPayment),
      dueDay: num(d.dueDay),
      statementDay: num(d.statementDay),
      graceDays: num(d.graceDays),
      creditLimit: num(d.creditLimit),
      // The date interest has been accrued up to (kept as a plain date string or
      // absent). Absent means a payment accrues 0 interest and then starts the
      // clock, which is the correct no-back-accrual default for old debts.
      // Keep only a real YYYY-MM-DD stamp: a malformed string would make the
      // day-count diff NaN in splitDebtPayment and could wipe a balance, so a
      // bad value drops to undefined (the safe no-back-accrual default).
      interestThroughISO:
        typeof d.interestThroughISO === 'string' && /^\d{4}-\d{2}-\d{2}/.test(d.interestThroughISO)
          ? d.interestThroughISO
          : undefined,
    })),
    // Payments carry their interest/principal split so reports read stored
    // values, never recompute from live balances. Coerced to safe numbers when
    // present; left ABSENT for legacy payments so a reader can fall back to
    // treating the whole legacy amount as principal (they predate the split).
    payments: dated(src.payments).map((p, i) => ({
      ...p,
      id: str(p.id) || `pay_restored_${i}`,
      amount: Math.max(0, num(p.amount)),
      interest: p.interest != null ? Math.max(0, num(p.interest)) : undefined,
      principal: p.principal != null ? Math.max(0, num(p.principal)) : undefined,
    })),
    transactions: dated(src.transactions).map((t) => {
      const out = {
        ...t,
        // Negative amounts are direction smuggling (an expense that ADDS
        // money); the type field owns direction, amounts stay positive.
        amount: Math.max(0, num(t.amount)),
        // The honest directions. income and expense are the money math;
        // transfer, debt, and adjustment are record rows that every expense and
        // income filter automatically skips (adjustment is a manual balance
        // reconciliation). Anything else becomes an expense.
        type: ['income', 'transfer', 'debt', 'adjustment'].includes(t.type) ? t.type : 'expense',
        label: typeof t.label === 'string' && t.label ? t.label : 'Entry',
      };
      // receiptUri must match the exact shape the app itself writes,
      // receipts/receipt_<id>.<ext>, or be absent. Anything else (a crafted
      // https url in a backup file, an absolute path, a dot path like
      // receipts/.. that would let deleteReceipt escape the folder) is
      // dropped: the viewer and the file deleter must never leave receipts/.
      if (typeof t.receiptUri === 'string' && /^receipts\/receipt_[a-z0-9]+\.[A-Za-z0-9]+$/.test(t.receiptUri)) {
        out.receiptUri = t.receiptUri;
      } else {
        delete out.receiptUri;
      }
      // Same discipline for categoryId: a string or absent, never junk.
      if (typeof t.categoryId === 'string' && t.categoryId) out.categoryId = t.categoryId;
      else delete out.categoryId;
      // Per transaction currency: the stored `amount` is already in the base
      // currency, so origCurrency (a code string) and origAmount (a positive
      // number) are display only, kept together or dropped together so a row can
      // never claim a foreign amount with no currency or vice versa.
      if (typeof t.origCurrency === 'string' && t.origCurrency && num(t.origAmount) > 0) {
        out.origCurrency = t.origCurrency;
        out.origAmount = num(t.origAmount);
      } else {
        delete out.origCurrency;
        delete out.origAmount;
      }
      // flow decides which way a linked transaction moves its account balance,
      // so it is only trusted as an exact 'in' or 'out' on a transfer or a
      // balance adjustment. Anything else is dropped, so a hand edited backup
      // cannot flip an expense into an inflow. source is a plain label
      // (receivable/payable) kept as a string.
      if ((out.type === 'transfer' || out.type === 'adjustment') && (t.flow === 'in' || t.flow === 'out')) out.flow = t.flow;
      else delete out.flow;
      if (typeof t.source === 'string' && t.source) out.source = t.source;
      else delete out.source;
      // Legacy record rows never carry accountId: their balance moves happened
      // by hand at the moment of the transfer or debt payment, so a stray
      // accountId would let a later edit or delete shift a balance a second
      // time. BUT a cash leg transfer (utang lending, borrowing, collecting,
      // repaying) is different: it is a real linked move that keeps its
      // accountId on purpose, since that is the only thing that lets removing it
      // put the money back. Those carry a flow ('in'/'out'); keep their account.
      if ((out.type === 'transfer' || out.type === 'debt') && !out.flow) delete out.accountId;
      // A balance adjustment moves its account by its flow, so a valid flow is
      // required. If a hand edited backup stripped it, drop the accountId too so
      // the row becomes an inert history record instead of moving a balance with
      // no known direction.
      if (out.type === 'adjustment' && !out.flow) delete out.accountId;
      return out;
    }),
    goals: cleanList(src.goals).map((g) => ({
      ...g,
      name: str(g.name, 'Goal'),
      targetDate: str(g.targetDate),
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
    categories: (() => {
      // Ids must be unique: a hand edited backup with two cat_food rows
      // would double count the same money in both and break editing.
      const seen = new Set();
      return cleanList(src.categories).map((c, i) => {
        let id = typeof c.id === 'string' && c.id ? c.id : `cat_restored_${i}`;
        while (seen.has(id)) id = `${id}_dup`;
        seen.add(id);
        return {
          ...c,
          id,
          name: str(c.name, 'Category'),
          icon: str(c.icon, '🏷️'),
          monthlyCap: Math.max(0, num(c.monthlyCap)),
        };
      });
    })(),
    people: cleanList(src.people).map((p) => ({
      ...p,
      name: str(p.name, 'Someone'),
      phone: str(p.phone),
      note: str(p.note),
    })),
    receivables: cleanList(src.receivables).map((r) => ({
      ...r,
      person: typeof r.person === 'string' && r.person ? r.person : 'Someone',
      personId: str(r.personId),
      dueDate: str(r.dueDate),
      phone: str(r.phone),
      note: str(r.note),
      amount: num(r.amount),
      paid: !!r.paid,
      // cashLeg true means lending recorded a real cash outflow, so this utang
      // counts in net worth and collection returns cash. Coerced to a real
      // boolean so a hand edited backup cannot flip the accounting with a string.
      cashLeg: !!r.cashLeg,
      payments: cleanList(r.payments).map((p, i) => ({
        ...p,
        // A stable id per payment: removing one payment keys on this id, so a
        // restored payment that lost its id must get one back, else remove
        // would match every id-less row at once.
        id: str(p.id) || `rpay_restored_${i}`,
        amount: Math.max(0, num(p.amount)),
        date: typeof p.date === 'string' && p.date ? p.date : stampDate,
        // A settling payment is tagged so reopening an utang reverses only it,
        // never a genuine partial. Coerce to a real boolean so a hand edited or
        // corrupt backup cannot mark a real partial settled and have it silently
        // reversed and dropped on the next reopen.
        settled: !!p.settled,
      })),
    })),
    // Payables mirror receivables exactly (People I owe), coerced the same way.
    // Paying a payable now posts a real expense, so each payment carries a
    // txnId linking it to that expense. The spread below keeps txnId (and any
    // other field) intact, so a restored backup keeps the payment<->expense
    // link and can still reverse it on remove or delete.
    payables: cleanList(src.payables).map((r) => ({
      ...r,
      person: typeof r.person === 'string' && r.person ? r.person : 'Someone',
      personId: str(r.personId),
      dueDate: str(r.dueDate),
      phone: str(r.phone),
      note: str(r.note),
      amount: num(r.amount),
      paid: !!r.paid,
      // cashLeg true means borrowing recorded a real cash inflow, so this utang
      // counts in net worth and paying it leaves cash. Coerced to a real boolean.
      cashLeg: !!r.cashLeg,
      payments: cleanList(r.payments).map((p, i) => ({
        ...p,
        // A stable id per payment: removing one payment keys on this id, so a
        // restored payment that lost its id must get one back, else remove
        // would match every id-less row at once.
        id: str(p.id) || `ppay_restored_${i}`,
        amount: Math.max(0, num(p.amount)),
        date: typeof p.date === 'string' && p.date ? p.date : stampDate,
        // A settling payment is tagged so reopening an utang reverses only it,
        // never a genuine partial. Coerce to a real boolean so a hand edited or
        // corrupt backup cannot mark a real partial settled and have it silently
        // reversed and dropped on the next reopen.
        settled: !!p.settled,
      })),
    })),
    settings: (() => {
      const s = {
        ...settings,
        monthlyLimit: num(settings.monthlyLimit),
        quickAdds: cleanList(settings.quickAdds),
        appLock: keepAppLock ? settings.appLock === true : false,
        // Strict boolean: a truthy string like "no" must not unlock Pro.
        pro: settings.pro === true,
        notifications: isObj(settings.notifications) ? settings.notifications : {},
        // Earn-your-treats rules. Each rule is tiny: its check-ins are pruned to
        // the rolling window by the app, and lifetime never decreases. A missing
        // array cleans to empty, so old blobs degrade to the empty state.
        treats: cleanList(settings.treats).map((t, i) => ({
          ...t,
          id: str(t.id) || `treat_restored_${i}`,
          treat: str(t.treat, 'My treat'),
          action: str(t.action, 'My healthy action'),
          emoji: str(t.emoji, '☕'),
          target: Math.min(Math.max(Math.round(num(t.target)) || 3, 1), 14),
          windowDays: Math.min(Math.max(Math.round(num(t.windowDays)) || 7, 1), 31),
          checkIns: Array.from(new Set(
            (Array.isArray(t.checkIns) ? t.checkIns : []).filter(
              (dt) => typeof dt === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(dt)
            )
          )),
          lifetime: Math.max(0, Math.round(num(t.lifetime))),
          createdAt: str(t.createdAt) || stampDate,
        })),
      };
      // Junk currency poisons every formatted amount app wide; a missing
      // key lets the seed defaults fill in instead.
      if (typeof s.currency !== 'string' || !s.currency) delete s.currency;
      if (typeof s.currencyCode !== 'string') delete s.currencyCode;
      return s;
    })(),
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
