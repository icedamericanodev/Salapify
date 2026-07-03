// AppData is the single shared place that holds all of the app's data:
// accounts, assets, debts, transactions, goals, and settings. Any screen can
// read it or change it through the helper functions here, and it saves to the
// device on its own whenever it changes. Storage is AsyncStorage for now; the
// screens never touch storage directly, so we can swap in SQLite later without
// changing any screen.

import { createContext, useContext, useEffect, useState } from 'react';
import { loadData, saveData } from '../lib/storage';
import { deleteReceipt } from '../lib/receipts';
import { setCurrencySymbol } from '../lib/format';
import { rescheduleAll } from '../lib/notifications';
import { sanitizeData } from '../lib/backup';
import {
  sampleAccounts,
  sampleAssets,
  sampleDebts,
  sampleTransactions,
  sampleBudget,
} from '../lib/sampleData';

// Makes a short unique id for new items, like "accounts_lq3k_1".
let idCounter = 0;
export function genId(prefix = 'id') {
  return `${prefix}_${Date.now().toString(36)}_${(idCounter++).toString(36)}`;
}

// The starting data, used the very first time the app runs (nothing saved yet).
// We seed it from the sample data so the app is not empty on first open.
const seedData = {
  accounts: sampleAccounts,
  assets: sampleAssets,
  debts: sampleDebts,
  payments: [],
  transactions: sampleTransactions,
  goals: [],
  wins: [],
  notes: [],
  recurring: [],
  receivables: [
    // The sample utang is due two weeks from first run, so a new user is
    // never greeted by an already overdue fake debt.
    (() => {
      const d = new Date();
      d.setDate(d.getDate() + 14);
      const due = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      return { id: 'r1', person: 'Juan', amount: 500, dueDate: due, phone: '', note: 'Lunch', paid: false };
    })(),
  ],
  settings: {
    currency: '₱',
    currencyCode: 'PHP',
    monthlyLimit: sampleBudget.monthlyLimit,
    quickAdds: sampleBudget.quickAdds,
    notifications: { payday: false, bills: false, collect: false, daily: false },
    appLock: false,
    onboarded: false,
    pro: false,
  },
};

const AppDataContext = createContext(null);

export function AppDataProvider({ children }) {
  const [data, setData] = useState(seedData);
  const [loaded, setLoaded] = useState(false);
  const [loadFailed, setLoadFailed] = useState(false);

  // On startup, load saved data. Three cases matter:
  //  - "ok": clean it up (sanitizeData guarantees arrays, numbers, and
  //    dates, so a bad blob can never crash or brick the app) and use it.
  //  - "empty": first run, keep the seed and allow saving.
  //  - "error": something IS saved but could not be read. Keep the seed on
  //    screen but never enable saving, so one bad read cannot overwrite
  //    the user's real data with samples.
  useEffect(() => {
    (async () => {
      const res = await loadData();
      if (res.status === 'ok' && res.data && Array.isArray(res.data.accounts)) {
        const clean = sanitizeData(res.data, { keepAppLock: true });
        // Anyone with saved data from before the welcome flow existed has
        // clearly used the app already: never throw them into onboarding,
        // where Start empty sits one confirm away from their real data.
        // Only an explicit false (a fresh user who quit mid welcome) keeps
        // the flow.
        const onboarded = clean.settings.onboarded === false ? false : true;
        setData({
          ...clean,
          settings: { ...seedData.settings, ...clean.settings, onboarded },
        });
        setLoaded(true);
      } else if (res.status === 'empty') {
        setLoaded(true);
      } else {
        setLoadFailed(true);
        console.warn('Saved data could not be read. Saving is off this session to protect it.');
      }
    })();
  }, []);

  // Save whenever data changes, but only after the first load.
  useEffect(() => {
    if (loaded) saveData(data);
  }, [data, loaded]);

  // Keep scheduled reminders in sync with the data. Runs when the
  // notification switches, receivables, transactions, or debts change, so
  // the daily nudge knows you already logged today and bill reminders
  // follow due day edits. Does nothing on web.
  useEffect(() => {
    if (loaded) rescheduleAll(data);
  }, [loaded, data.receivables, data.transactions, data.debts, data.settings.notifications]);

  // Post recurring bills and income that have come due. Runs on load and
  // whenever the recurring list changes: each item posts one transaction
  // per month, on or after its day, stamped with the scheduled date. The
  // lastPosted month marker makes double posting impossible, and items
  // added after their day this month wait for next month.
  useEffect(() => {
    if (!loaded) return;
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    // Ordered comparison on the YYYY-MM key: anything posted this month OR
    // LATER counts as done, so a phone whose clock jumped ahead and back
    // can never post the same month twice.
    const posted = (r) => typeof r.lastPosted === 'string' && r.lastPosted >= monthKey;
    const anyDue = (data.recurring || []).some((r) => {
      const day = Math.min(Number(r.dayOfMonth) || 1, daysInMonth);
      return !posted(r) && now.getDate() >= day;
    });
    if (!anyDue) return;
    setData((prev) => {
      let transactions = prev.transactions;
      let accounts = prev.accounts;
      const recurring = (prev.recurring || []).map((r) => {
        const day = Math.min(Number(r.dayOfMonth) || 1, daysInMonth);
        if (posted(r) || now.getDate() < day) return r;
        const date = `${monthKey}-${String(day).padStart(2, '0')}`;
        const amount = Number(r.amount) || 0;
        const tx = {
          id: genId('transactions'),
          type: r.type === 'income' ? 'income' : 'expense',
          label: r.label || 'Recurring',
          amount,
          date,
          recurringId: r.id,
        };
        const acct = r.accountId ? accounts.find((a) => a.id === r.accountId) : null;
        if (acct) {
          tx.accountId = acct.id;
          const delta = (tx.type === 'income' ? 1 : -1) * amount;
          accounts = accounts.map((a) =>
            a.id === acct.id ? { ...a, balance: (Number(a.balance) || 0) + delta } : a
          );
        }
        transactions = [...transactions, tx];
        return { ...r, lastPosted: monthKey };
      });
      return { ...prev, transactions, accounts, recurring };
    });
  }, [loaded, data.recurring]);

  // ---- Helpers the screens use, so they never edit the data by hand ----

  // Add an item to a list (accounts, debts, transactions, assets, goals).
  // Returns the new item's id.
  function addItem(collection, item) {
    const withId = { ...item, id: item.id || genId(collection) };
    setData((prev) => ({ ...prev, [collection]: [...prev[collection], withId] }));
    return withId.id;
  }

  // Change some fields of one item in a list, found by id.
  function updateItem(collection, id, patch) {
    setData((prev) => ({
      ...prev,
      [collection]: prev[collection].map((it) => (it.id === id ? { ...it, ...patch } : it)),
    }));
  }

  // Remove one item from a list by id.
  function removeItem(collection, id) {
    setData((prev) => ({
      ...prev,
      [collection]: prev[collection].filter((it) => it.id !== id),
    }));
  }

  // Add a transaction, and when it is linked to an account, move the
  // account's balance with it (income raises it, an expense lowers it).
  // This is the seam that keeps GCash in the app matching GCash in real
  // life. Transactions without an accountId behave exactly as before.
  function addTransaction(tx) {
    const withId = { ...tx, id: tx.id || genId('transactions') };
    setData((prev) => {
      const linked = withId.accountId && prev.accounts.some((a) => a.id === withId.accountId);
      const delta = (withId.type === 'income' ? 1 : -1) * (Number(withId.amount) || 0);
      const accounts = linked
        ? prev.accounts.map((a) =>
            a.id === withId.accountId ? { ...a, balance: (Number(a.balance) || 0) + delta } : a
          )
        : prev.accounts;
      return { ...prev, accounts, transactions: [...prev.transactions, withId] };
    });
    return withId.id;
  }

  // Remove a transaction and undo its effect on the linked account, so a
  // delete or an Undo never leaves a balance permanently shifted.
  function removeTransaction(id) {
    setData((prev) => {
      const tx = prev.transactions.find((t) => t.id === id);
      if (!tx) return prev;
      // The attached receipt photo goes with it, so deleted entries never
      // leave orphan files piling up in storage.
      if (tx.receiptUri) deleteReceipt(tx.receiptUri);
      const linked = tx.accountId && prev.accounts.some((a) => a.id === tx.accountId);
      const delta = (tx.type === 'income' ? 1 : -1) * (Number(tx.amount) || 0);
      const accounts = linked
        ? prev.accounts.map((a) =>
            a.id === tx.accountId ? { ...a, balance: (Number(a.balance) || 0) - delta } : a
          )
        : prev.accounts;
      return { ...prev, accounts, transactions: prev.transactions.filter((t) => t.id !== id) };
    });
  }

  // Change settings (currency, monthly limit, quick adds, etc.). Accepts a
  // plain patch, or a function of the current settings for updates that
  // build on the latest value (like flipping one notification switch while
  // another toggle is still waiting on a permission dialog).
  function updateSettings(patch) {
    setData((prev) => {
      const p = typeof patch === 'function' ? patch(prev.settings) : patch;
      return { ...prev, settings: { ...prev.settings, ...p } };
    });
  }

  // Replace everything at once (used by Restore and the v1 import). The
  // data is sanitized, missing collections become EMPTY lists rather than
  // sample data (a restore must never invent money), and the app lock is
  // always off after a restore so nobody gets locked out.
  function replaceAll(newData) {
    const clean = sanitizeData(newData);
    // A restore must never invent money: every restored recurring item is
    // stamped as already posted for the current month, so the app shows
    // exactly what the backup contains and resumes posting next month.
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    clean.recurring = (clean.recurring || []).map((r) => ({ ...r, lastPosted: monthKey }));
    // A restore that carries any real records means this person is not a
    // first time user: mark them onboarded so the welcome flow never
    // appears on top of freshly restored data.
    const hasData = [
      'accounts', 'assets', 'debts', 'payments', 'transactions',
      'goals', 'wins', 'receivables', 'notes', 'recurring',
    ].some((k) => (clean[k] || []).length > 0);
    setData({
      ...clean,
      settings: {
        ...seedData.settings,
        ...clean.settings,
        appLock: false,
        onboarded: clean.settings.onboarded === true || hasData,
      },
    });
  }

  // Keep the money formatter in sync with the chosen currency, so amounts
  // across the app use the right symbol.
  setCurrencySymbol(data.settings && data.settings.currency);

  const value = {
    data,
    loaded,
    loadFailed,
    addItem,
    updateItem,
    removeItem,
    addTransaction,
    removeTransaction,
    updateSettings,
    replaceAll,
  };

  return <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>;
}

// Shortcut hook: const { data, addItem, updateItem, removeItem } = useAppData();
export function useAppData() {
  const ctx = useContext(AppDataContext);
  if (!ctx) {
    throw new Error('useAppData must be used inside AppDataProvider');
  }
  return ctx;
}
