// storage.js is a small wrapper around AsyncStorage, the phone's local
// storage. AsyncStorage can only store text, so here we convert our data to
// and from JSON. This works like the browser localStorage your v1 used, but
// it lives on the device and survives closing the app.

import AsyncStorage from '@react-native-async-storage/async-storage';

// The single key under which we save the whole app's data.
const STORAGE_KEY = 'salapify_data_v2';

// A one deep safety net: before anything destructive (restore, import,
// erase), the current blob is copied here. One key, always overwritten.
const SNAPSHOT_KEY = 'salapify_data_v2_prev';

// Android stores each AsyncStorage key as one database row and refuses to
// READ rows near 2MB, which would lock the user out of their own data
// forever. These thresholds turn that cliff into a visible slope.
export const SIZE_NUDGE = 700 * 1024; // suggest a backup
export const SIZE_WARN = 1500 * 1024; // warn loudly, close to the wall

// Read the saved data. The status matters: "empty" means nothing was ever
// saved (safe to start fresh), "error" means something IS saved but could
// not be read right now. The caller must never overwrite storage after an
// error, or a single bad read would destroy the user's data.
export async function loadData() {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return { status: 'empty', data: null };
    return { status: 'ok', data: JSON.parse(raw) };
  } catch (e) {
    console.warn('loadData failed', e);
    return { status: 'error', data: null };
  }
}

// Save the whole data object. Returns { ok, size } so the caller can react
// to failures (a finance app that silently stops saving is a disaster) and
// to the blob growing toward the read limit.
export async function saveData(data) {
  let size = 0;
  try {
    const text = JSON.stringify(data);
    size = text.length;
    await AsyncStorage.setItem(STORAGE_KEY, text);
    return { ok: true, size };
  } catch (e) {
    console.warn('saveData failed', e);
    return { ok: false, size };
  }
}

// Copy the current blob to the snapshot key. Called right before anything
// destructive. Best effort: a snapshot failure never blocks the user's
// action, it just means the net is not there this one time.
export async function snapshotData() {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (raw) await AsyncStorage.setItem(SNAPSHOT_KEY, raw);
    return true;
  } catch (e) {
    console.warn('snapshotData failed', e);
    return false;
  }
}

// Read the snapshot back (for a future "undo restore" surface).
export async function loadSnapshot() {
  try {
    const raw = await AsyncStorage.getItem(SNAPSHOT_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    return null;
  }
}

// Delete the snapshot. Erase everything must erase this too, otherwise
// "cannot be undone" would be a lie and the erased ledger would survive
// in a hidden key.
export async function clearSnapshot() {
  try {
    await AsyncStorage.removeItem(SNAPSHOT_KEY);
  } catch (e) {
    console.warn('clearSnapshot failed', e);
  }
}
