// AppData is the single shared place that holds all of the app's data.
// Any screen can read it or update it, and it saves to the phone on its own
// whenever it changes. Later this will hold accounts, debts, transactions,
// goals, and settings. For now it has one test counter so we can prove that
// saving and loading actually works.

import { createContext, useContext, useEffect, useState } from 'react';
import { loadData, saveData } from '../lib/storage';

// The starting shape of our data, used the very first time the app runs
// (before anything has been saved).
const defaultData = {
  testCounter: 0,
  // accounts: [], debts: [], transactions: [], goals: [], settings: {} ... later
};

// createContext makes the shared box. We fill it in the Provider below.
const AppDataContext = createContext(null);

// AppDataProvider wraps the whole app. It loads saved data on startup and
// saves again whenever the data changes.
export function AppDataProvider({ children }) {
  const [data, setData] = useState(defaultData);
  // loaded tells us the first read from the phone has finished.
  const [loaded, setLoaded] = useState(false);

  // Run once on startup: read whatever was saved before.
  useEffect(() => {
    (async () => {
      const saved = await loadData();
      // Merge saved values over the defaults, so new fields we add later
      // still get their default value.
      if (saved) setData({ ...defaultData, ...saved });
      setLoaded(true);
    })();
  }, []);

  // Whenever data changes (but only after the first load), save it.
  useEffect(() => {
    if (loaded) saveData(data);
  }, [data, loaded]);

  return (
    <AppDataContext.Provider value={{ data, setData, loaded }}>
      {children}
    </AppDataContext.Provider>
  );
}

// useAppData is a shortcut so any screen can do:
//   const { data, setData } = useAppData();
export function useAppData() {
  const ctx = useContext(AppDataContext);
  if (!ctx) {
    throw new Error('useAppData must be used inside AppDataProvider');
  }
  return ctx;
}
