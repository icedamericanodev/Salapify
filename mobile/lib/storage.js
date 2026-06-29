// storage.js is a small wrapper around AsyncStorage, the phone's local
// storage. AsyncStorage can only store text, so here we convert our data to
// and from JSON. This works like the browser localStorage your v1 used, but
// it lives on the device and survives closing the app.

import AsyncStorage from '@react-native-async-storage/async-storage';

// The single key under which we save the whole app's data.
const STORAGE_KEY = 'salapify_data_v2';

// Read the saved data. Returns the saved object, or null if nothing is saved.
export async function loadData() {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    console.warn('loadData failed', e);
    return null;
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
