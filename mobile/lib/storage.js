// storage.js is a small wrapper around AsyncStorage, the phone's local
// storage. AsyncStorage can only store text, so here we convert our data to
// and from JSON. This works like the browser localStorage your v1 used, but
// it lives on the device and survives closing the app.

import AsyncStorage from '@react-native-async-storage/async-storage';

// The single key under which we save the whole app's data.
const STORAGE_KEY = 'salapify_data_v2';

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

// Save the whole data object. We turn it into text first.
export async function saveData(data) {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch (e) {
    console.warn('saveData failed', e);
  }
}
