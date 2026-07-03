// AppData is the single shared place that holds all of the app's data:
// accounts, assets, debts, transactions, goals, and settings. Any screen can
// read it or change it through the helper functions here, and it saves to the
// device on its own whenever it changes. Storage is AsyncStorage for now; the
// screens never touch storage directly, so we can swap in SQLite later without
// changing any screen.

import { createContext, useContext, useEffect, useState } from 'react';
import { loadData, saveData } from '../lib/storage';
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
  },
};

const AppDataContext = createContext(null);

export function AppDataProvider({ children }) {
  const [data, setData] = useState(seedData);
  const [loaded, setLoaded] = useState(false);

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
        setData({
          ...clean,
          settings: { ...seedData.settings, ...clean.settings },
        });
        setLoaded(true);
      } else if (res.status === 'empty') {
        setLoaded(true);
      } else {
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
    setData({
      ...clean,
      settings: { ...seedData.settings, ...clean.settings, appLock: false },
    });
  }

  // Keep the money formatter in sync with the chosen currency, so amounts
  // across the app use the right symbol.
  setCurrencySymbol(data.settings && data.settings.currency);

  const value = {
    data,
    loaded,
    addItem,
    updateItem,
    removeItem,
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
