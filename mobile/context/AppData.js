// AppData is the single shared place that holds all of the app's data:
// accounts, assets, debts, transactions, goals, and settings. Any screen can
// read it or change it through the helper functions here, and it saves to the
// device on its own whenever it changes. Storage is AsyncStorage for now; the
// screens never touch storage directly, so we can swap in SQLite later without
// changing any screen.

import { createContext, useContext, useEffect, useState } from 'react';
import { loadData, saveData } from '../lib/storage';
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
  settings: {
    currency: '₱',
    monthlyLimit: sampleBudget.monthlyLimit,
    quickAdds: sampleBudget.quickAdds,
  },
};

const AppDataContext = createContext(null);

export function AppDataProvider({ children }) {
  const [data, setData] = useState(seedData);
  const [loaded, setLoaded] = useState(false);

  // On startup, load saved data. We only use it if it looks like real data
  // (has an accounts list), otherwise we keep the seed.
  useEffect(() => {
    (async () => {
      const saved = await loadData();
      if (saved && Array.isArray(saved.accounts)) {
        setData({ ...seedData, ...saved });
      }
      setLoaded(true);
    })();
  }, []);

  // Save whenever data changes, but only after the first load.
  useEffect(() => {
    if (loaded) saveData(data);
  }, [data, loaded]);

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

  // Change settings (currency, monthly limit, quick adds, etc.).
  function updateSettings(patch) {
    setData((prev) => ({ ...prev, settings: { ...prev.settings, ...patch } }));
  }

  // Replace everything at once (used later by Restore and the v1 import).
  function replaceAll(newData) {
    setData({ ...seedData, ...newData });
  }

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
