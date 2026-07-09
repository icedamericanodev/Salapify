// AppData is the single shared place that holds all of the app's data:
// accounts, assets, debts, transactions, goals, and settings. Any screen can
// read it or change it through the helper functions here, and it saves to the
// device on its own whenever it changes. Storage is AsyncStorage for now; the
// screens never touch storage directly, so we can swap in SQLite later without
// changing any screen.

import { createContext, useContext, useEffect, useRef, useState } from 'react';
import { AppState, InteractionManager, Platform } from 'react-native';
import { loadData, saveData, snapshotData, clearSnapshot } from '../lib/storage';
import { deleteReceipt, cleanupReceipts } from '../lib/receipts';
import { setCurrencySymbol, todayISO } from '../lib/format';
import { rescheduleAll } from '../lib/notifications';
import { sanitizeData, SCHEMA_VERSION, DEFAULT_CATEGORIES, buildBackup } from '../lib/backup';
import { shouldRunAutoBackup, autoBackupFilenameFromDate } from '../lib/autobackup';
import { writeAutoBackup, pruneAutoBackups } from '../lib/files';
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
  schemaVersion: SCHEMA_VERSION,
  accounts: sampleAccounts,
  assets: sampleAssets,
  debts: sampleDebts,
  payments: [],
  transactions: sampleTransactions,
  goals: [],
  wins: [],
  notes: [],
  recurring: [],
  people: [],
  categories: DEFAULT_CATEGORIES.map((c) => ({ ...c })),
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
  // People I owe (payables). A fresh install has none: we never seed a sample
  // debt, so a new user is never shown a fake utang they owe someone.
  payables: [],
  settings: {
    currency: '₱',
    currencyCode: 'PHP',
    monthlyLimit: sampleBudget.monthlyLimit,
    quickAdds: sampleBudget.quickAdds,
    notifications: { payday: false, bills: false, collect: false, daily: false },
    appLock: false,
    onboarded: false,
    pro: false,
    // Automatic backup (Pro, Android only). Off by default; the user turns it
    // on and picks a folder in the Backup and data screen. These keys are
    // additive and survive a restore because sanitizeData spreads settings.
    autoBackup: false,
    autoBackupUri: '',
    lastAutoBackupAt: '',
    autoBackupKeep: 7,
    autoBackupBroken: false,
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
        try {
          // When a schema migration is about to rewrite this blob,
          // snapshot the pre migration shape first. The clamp mirrors
          // migrate() exactly: blobs with NO version (everything saved
          // before the framework existed) count as version 2 and DO get
          // migrated, so they must get the snapshot too.
          let incoming = Math.trunc(Number(res.data.schemaVersion));
          if (!Number.isFinite(incoming) || incoming < 1) incoming = 2;
          if (incoming < SCHEMA_VERSION) {
            await snapshotData();
          }
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
        } catch (e) {
          // A refused migration (data from a newer app version) lands here:
          // saving stays off so the newer data is never overwritten.
          setLoadFailed(true);
          console.warn('Saved data could not be used. Saving is off this session to protect it.', e);
        }
      } else if (res.status === 'empty') {
        setLoaded(true);
      } else {
        setLoadFailed(true);
        console.warn('Saved data could not be read. Saving is off this session to protect it.');
      }
    })();
  }, []);

  // ---- Saving: debounced, failure aware, flushed on background ----
  // Rapid taps produce many state changes; writing the whole blob each
  // time is wasted work. A short trailing debounce batches them, and the
  // AppState listener below flushes immediately when the app leaves the
  // screen, so a swipe kill right after logging never loses the entry.
  const [saveFailed, setSaveFailed] = useState(false);
  const [storageSize, setStorageSize] = useState(0);
  const saveTimer = useRef(null);
  const pendingData = useRef(null);
  const failCount = useRef(0);
  // A live mirror of the latest data, so the AppState listener (which is set
  // up once with an empty dep array) can read the current settings and blob on
  // resume instead of a stale first-render copy.
  const dataRef = useRef(data);
  dataRef.current = data;
  // Guards a slow auto-backup write from overlapping itself if the app is
  // backgrounded and foregrounded again before the first write finishes.
  const autoBackupRunning = useRef(false);

  async function persist(d) {
    const res = await saveData(d);
    setStorageSize(res.size);
    if (res.ok) {
      failCount.current = 0;
      setSaveFailed(false);
    } else {
      failCount.current += 1;
      // One transient failure is noise; three in a row means the phone is
      // genuinely not persisting and the user must be told.
      if (failCount.current >= 3) setSaveFailed(true);
    }
  }

  useEffect(() => {
    if (!loaded) return;
    pendingData.current = data;
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      saveTimer.current = null;
      const d = pendingData.current;
      pendingData.current = null;
      if (d) persist(d);
    }, 500);
  }, [data, loaded]);

  // If the provider ever unmounts (the crash shield's Try again remounts
  // the whole tree), flush the pending save right now, before the remount
  // reloads from disk. Without this, an entry logged just before a crash
  // could be silently lost to the debounce window. Raw saveData here, no
  // state updates during unmount.
  useEffect(() => {
    return () => {
      if (saveTimer.current) {
        clearTimeout(saveTimer.current);
        saveTimer.current = null;
      }
      const d = pendingData.current;
      pendingData.current = null;
      if (d) saveData(d);
    };
  }, []);

  // The automatic backup runner. Writes a dated backup file into the folder
  // the user granted, on FOREGROUND resume only. It is never called from the
  // background branch: a background write can be suspended by Android mid-write
  // and truncate the file, which is unacceptable for a money app, so the
  // existing background flush below stays exactly as it was. Only the automatic
  // backup is Pro; the manual tools in the Backup and data screen stay free.
  async function runAutoBackup() {
    // Platform check lives here (files.js and autobackup.js stay pure). iOS and
    // web are a no-op.
    if (Platform.OS !== 'android') return;
    if (autoBackupRunning.current) return;
    const today = todayISO();
    const settings = dataRef.current.settings;
    if (!shouldRunAutoBackup(settings, today)) return;
    autoBackupRunning.current = true;
    // runAfterInteractions so stringifying a large blob never janks the resume
    // frame or delays a tap; the write happens after the UI settles.
    InteractionManager.runAfterInteractions(async () => {
      try {
        const text = buildBackup(dataRef.current);
        const filename = autoBackupFilenameFromDate(new Date());
        // Create the NEW dated file first. Only after it succeeds do we prune,
        // so a failed write never leaves the folder emptier than before.
        await writeAutoBackup(settings.autoBackupUri, filename, text);
        // Best-effort rotation: prune failure is swallowed inside pruneAutoBackups
        // and must never turn a good backup into an error.
        await pruneAutoBackups(settings.autoBackupUri, Number(settings.autoBackupKeep) || 7);
        // Success clears any previous broken flag and stamps today so we run at
        // most once per day.
        updateSettings({ lastAutoBackupAt: today, autoBackupBroken: false });
      } catch (e) {
        // A SAF failure (folder revoked, storage full) flips the banner. We do
        // NOT wipe autoBackupUri and do NOT disable the feature: the user just
        // reconnects the folder from the gentle banner in the Backup screen.
        updateSettings({ autoBackupBroken: true });
        console.warn('Automatic backup could not write. The folder may need reconnecting.', e);
      } finally {
        autoBackupRunning.current = false;
      }
    });
  }

  // Flush the pending save the moment the app goes to the background, and
  // nudge the recurring engine when it comes back (people keep apps in the
  // switcher for weeks; bills must post on resume, not only cold start).
  const [resumeTick, setResumeTick] = useState(0);
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state !== 'active') {
        if (saveTimer.current) {
          clearTimeout(saveTimer.current);
          saveTimer.current = null;
          const d = pendingData.current;
          pendingData.current = null;
          if (d) persist(d);
        }
      } else {
        setResumeTick((t) => t + 1);
        // Foreground-only automatic backup. Guarded and self-throttling; never
        // blocks the resume or a tap.
        runAutoBackup();
      }
    });
    return () => sub.remove();
  }, []);

  // Also run the automatic backup once on cold start, not only on warm resume.
  // React Native does not emit an AppState 'active' event for the initial
  // launch, so a user who opens the app fresh and swipe kills it would never
  // get a backup from the resume listener alone. Same guard and in-flight ref,
  // so it stays at most once a day and never overlaps a resume run.
  useEffect(() => {
    if (loaded) runAutoBackup();
  }, [loaded]);

  // Keep scheduled reminders in sync with the data. Runs when the
  // notification switches, receivables, transactions, or debts change, so
  // the daily nudge knows you already logged today and bill reminders
  // follow due day edits. Does nothing on web.
  useEffect(() => {
    if (loaded) rescheduleAll(data);
  }, [loaded, data.receivables, data.transactions, data.debts, data.settings.notifications, data.settings.paydaySchedule]);

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
  }, [loaded, data.recurring, resumeTick]);

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

  // The direction a linked transaction moves its account balance. Income
  // raises it and everything else lowers it, EXCEPT a transaction that names
  // its own flow: flow 'in' always raises, flow 'out' always lowers. This lets
  // a cash move that is not income or spending (collecting an utang you lent,
  // taking a loan, a transfer between pockets) raise a balance without being
  // mislabeled as income. Transactions with no flow behave exactly as before.
  function balanceSign(t) {
    if (t && t.flow === 'in') return 1;
    if (t && t.flow === 'out') return -1;
    return t && t.type === 'income' ? 1 : -1;
  }

  // Add a transaction, and when it is linked to an account, move the
  // account's balance with it (see balanceSign for the direction).
  // This is the seam that keeps GCash in the app matching GCash in real
  // life. Transactions without an accountId behave exactly as before.
  function addTransaction(tx) {
    const withId = { ...tx, id: tx.id || genId('transactions') };
    setData((prev) => {
      const linked = withId.accountId && prev.accounts.some((a) => a.id === withId.accountId);
      const delta = balanceSign(withId) * (Number(withId.amount) || 0);
      const accounts = linked
        ? prev.accounts.map((a) =>
            a.id === withId.accountId ? { ...a, balance: (Number(a.balance) || 0) + delta } : a
          )
        : prev.accounts;
      return { ...prev, accounts, transactions: [...prev.transactions, withId] };
    });
    return withId.id;
  }

  // Edit a transaction honestly: the old entry's effect on its linked
  // account is reversed, then the new version's effect is applied, so
  // changing an amount, a type, or the account can never drift a balance.
  function updateTransaction(id, patch) {
    setData((prev) => {
      const tx = prev.transactions.find((t) => t.id === id);
      if (!tx) return prev;
      const next = { ...tx, ...patch };
      const shift = (accs, t, sign) => {
        if (!t.accountId || !accs.some((a) => a.id === t.accountId)) return accs;
        const delta = sign * balanceSign(t) * (Number(t.amount) || 0);
        return accs.map((a) =>
          a.id === t.accountId ? { ...a, balance: (Number(a.balance) || 0) + delta } : a
        );
      };
      const accounts = shift(shift(prev.accounts, tx, -1), next, 1);
      return {
        ...prev,
        accounts,
        transactions: prev.transactions.map((t) => (t.id === id ? next : t)),
      };
    });
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
      const delta = balanceSign(tx) * (Number(tx.amount) || 0);
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
  function replaceAll(newData, { snapshot = true } = {}) {
    // Safety net first: the current blob is copied to a snapshot key
    // before it gets replaced. Best effort and fire and forget; the
    // 500ms save debounce guarantees the snapshot reads the OLD blob.
    // Erase everything passes snapshot: false and clears the key instead,
    // because an erase that secretly keeps a copy would be a lie.
    if (snapshot) snapshotData().catch(() => {});
    else clearSnapshot().catch(() => {});
    const clean = sanitizeData(newData);
    // A restore must never invent money: a recurring item whose day this
    // month has ALREADY passed gets stamped as posted, because the real
    // posting may have happened after the backup was made and re-posting
    // it here would double the bill. An item whose day has NOT arrived yet
    // keeps its own lastPosted, otherwise restoring on July 3 would
    // silently skip the rent that is due July 15.
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    clean.recurring = (clean.recurring || []).map((r) => {
      const day = Math.min(Number(r.dayOfMonth) || 1, daysInMonth);
      // Never stamp BACKWARDS: a backup made on a clock that ran ahead can
      // carry lastPosted in our future, and downgrading it would let the
      // posting engine post that month a second time when it arrives.
      const keep = typeof r.lastPosted === 'string' && r.lastPosted > monthKey;
      return day <= now.getDate() ? (keep ? r : { ...r, lastPosted: monthKey }) : r;
    });
    // Erasing or replacing the money data also clears the receipt photos
    // it owned; photos still referenced by the incoming data are kept.
    cleanupReceipts((clean.transactions || []).map((t) => t.receiptUri).filter(Boolean));
    // A restore that carries any real records means this person is not a
    // first time user: mark them onboarded so the welcome flow never
    // appears on top of freshly restored data.
    const hasData = [
      'accounts', 'assets', 'debts', 'payments', 'transactions',
      'goals', 'wins', 'receivables', 'payables', 'notes', 'recurring', 'people',
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
    saveFailed,
    storageSize,
    addItem,
    updateItem,
    removeItem,
    addTransaction,
    updateTransaction,
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
