// Global search across everything on the device: transactions, utang,
// debts, goals, notes, and accounts. Pure string work over the stored blob,
// no network, no engine money math, so it is fast and easy to test. The
// screen (app/search.js) only renders what this returns.
//
// One idea drives relevance: an item matches when its searchable text
// contains every word in the query (AND), so "jollibee 150" narrows to the
// jollibee entry that cost 150 rather than everything that mentions either.
// Amounts are searchable both as raw digits and as the formatted peso
// string, so "2300" and "2,300" both land.

import { formatMoney } from './format';

const lower = (s) => String(s == null ? '' : s).toLowerCase();

// Every searchable value for an item, folded into one lowercased string.
const hay = (...parts) => parts.map(lower).filter(Boolean).join(' ');

// An item matches when the haystack contains all query tokens.
function matches(haystack, tokens) {
  for (const t of tokens) if (!haystack.includes(t)) return false;
  return true;
}

// Amount searchable as "2300" and "2,300" (formatMoney adds the currency
// symbol; strip it so a bare-number query still hits).
const amountHay = (n) => {
  const v = Number(n);
  if (!Number.isFinite(v) || v === 0) return '';
  return `${Math.round(v)} ${String(formatMoney(v)).replace(/[^\d.,]/g, '')}`;
};

const PER_GROUP = 8; // show this many per group, count the rest as "more"

export function search(data, rawQuery) {
  const d = data || {};
  const q = String(rawQuery || '').trim().toLowerCase();
  const tokens = q.split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return { query: '', empty: true, total: 0, groups: [] };

  // Lookups so a transaction can be found by its category or account name,
  // not only its own label.
  const catName = new Map();
  for (const c of d.categories || []) if (c && c.id) catName.set(c.id, c.name || '');
  const acctName = new Map();
  for (const a of d.accounts || []) if (a && a.id) acctName.set(a.id, a.name || '');

  const groups = [];
  const add = (kind, title, route, all) => {
    if (!all.length) return;
    groups.push({ kind, title, route, count: all.length, items: all.slice(0, PER_GROUP), more: Math.max(0, all.length - PER_GROUP) });
  };

  // Transactions, newest first. Records (transfer, debt) are searchable too
  // so a past money move can still be found.
  const tx = [];
  for (const t of d.transactions || []) {
    if (!t) continue;
    const cat = t.categoryId ? catName.get(t.categoryId) : '';
    const acct = t.accountId ? acctName.get(t.accountId) : '';
    const h = hay(t.label, cat, acct, t.date, amountHay(t.amount), t.type === 'income' ? 'income' : t.type === 'transfer' ? 'transfer' : t.type === 'debt' ? 'debt payment' : 'expense');
    if (!matches(h, tokens)) continue;
    tx.push({
      id: t.id,
      title: t.label || 'Entry',
      subtitle: `${t.date || ''}${acct ? ` · ${acct}` : cat ? ` · ${cat}` : ''}`.trim(),
      amount: Number(t.amount) || 0,
      sign: t.type === 'income' ? '+' : t.type === 'transfer' ? '⇄' : t.type === 'debt' ? '' : '-',
      date: String(t.date || ''),
    });
  }
  tx.sort((a, b) => b.date.localeCompare(a.date));
  add('transactions', 'Entries', '/history', tx);

  // Utang: who owes you. Search person, note, phone, and the amount.
  const utang = [];
  for (const r of d.receivables || []) {
    if (!r) continue;
    const paid = (r.payments || []).reduce((s, p) => s + (Number(p && p.amount) || 0), 0);
    const outstanding = Math.max(0, (Number(r.amount) || 0) - paid);
    const h = hay(r.person, r.note, r.phone, amountHay(r.amount), amountHay(outstanding), 'utang owes');
    if (!matches(h, tokens)) continue;
    utang.push({
      id: r.id,
      title: r.person || 'Someone',
      subtitle: r.note ? String(r.note) : outstanding > 0 ? 'still owes you' : 'settled',
      amount: outstanding,
      sign: '',
    });
  }
  add('utang', 'Utang', '/receivables', utang);

  // Debts you owe.
  const debts = [];
  for (const dd of d.debts || []) {
    if (!dd) continue;
    const h = hay(dd.name, dd.type, amountHay(dd.remaining), 'debt loan card');
    if (!matches(h, tokens)) continue;
    debts.push({ id: dd.id, title: dd.name || 'Debt', subtitle: dd.type ? String(dd.type) : 'debt', amount: Number(dd.remaining) || 0, sign: '' });
  }
  add('debts', 'Debts', '/debts', debts);

  // Goals.
  const goals = [];
  for (const g of d.goals || []) {
    if (!g) continue;
    const h = hay(g.name, amountHay(g.target), amountHay(g.saved), 'goal save');
    if (!matches(h, tokens)) continue;
    goals.push({ id: g.id, title: g.name || 'Goal', subtitle: `${formatMoney(Number(g.saved) || 0)} of ${formatMoney(Number(g.target) || 0)}`, amount: Number(g.target) || 0, sign: '' });
  }
  add('goals', 'Goals', '/goals', goals);

  // Notes.
  const notes = [];
  for (const n of d.notes || []) {
    if (!n) continue;
    const text = String(n.text || '');
    if (!matches(lower(text), tokens)) continue;
    const first = text.split('\n')[0].trim();
    notes.push({ id: n.id, title: first || 'Note', subtitle: text.length > first.length ? 'note' : '', amount: null, sign: '' });
  }
  add('notes', 'Notes', '/notes', notes);

  // Accounts by name.
  const accts = [];
  for (const a of d.accounts || []) {
    if (!a) continue;
    const h = hay(a.name, a.kind, 'account wallet');
    if (!matches(h, tokens)) continue;
    accts.push({ id: a.id, title: a.name || 'Account', subtitle: a.kind ? String(a.kind) : 'account', amount: Number(a.balance) || 0, sign: '' });
  }
  add('accounts', 'Accounts', '/accounts', accts);

  const total = groups.reduce((s, g) => s + g.count, 0);
  return { query: q, empty: false, total, groups };
}
