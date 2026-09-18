// Receipt photos for entries. The picture is copied into the app's own
// documents folder (cache folders get cleaned by Android), and the entry
// stores only the file path, never the image bytes, so AsyncStorage stays
// small and fast. Everything is a no-op on web.

import { Alert, Platform } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';

const receiptsDir = () => `${FileSystem.documentDirectory}receipts/`;

// Entries store RELATIVE paths like "receipts/receipt_abc.jpg", never the
// absolute documentDirectory uri: on iOS the sandbox path changes on every
// app update, and an absolute path stored today would be a dead link after
// the first update. resolveReceipt turns the stored path into a real uri
// at render time.
export function resolveReceipt(stored) {
  if (!stored || typeof stored !== 'string' || Platform.OS === 'web') return '';
  if (stored.startsWith('receipts/')) return `${FileSystem.documentDirectory}${stored}`;
  return stored;
}

// Ask camera or photos, pick, and copy into our folder. Returns the
// stored file uri, or null when the user cancels or permission is denied.
export async function pickReceipt() {
  if (Platform.OS === 'web') return null;
  const choice = await new Promise((resolve) => {
    Alert.alert('Attach a receipt', 'Where is the photo?', [
      { text: 'Take a photo', onPress: () => resolve('camera') },
      { text: 'From my photos', onPress: () => resolve('library') },
      { text: 'Cancel', style: 'cancel', onPress: () => resolve(null) },
    ]);
  });
  if (!choice) return null;

  let result;
  if (choice === 'camera') {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      Alert.alert('No camera access', 'Allow camera access in your phone settings to photograph receipts.');
      return null;
    }
    result = await ImagePicker.launchCameraAsync({ quality: 0.5 });
  } else {
    result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.5 });
  }
  if (!result || result.canceled || !result.assets || !result.assets[0]) return null;

  await FileSystem.makeDirectoryAsync(receiptsDir(), { intermediates: true }).catch(() => {});
  const name = `receipt_${Date.now().toString(36)}.jpg`;
  await FileSystem.copyAsync({ from: result.assets[0].uri, to: `${receiptsDir()}${name}` });
  return `receipts/${name}`;
}

// Best effort cleanup when an entry is deleted or an attachment replaced.
export function deleteReceipt(stored) {
  const uri = resolveReceipt(stored);
  if (!uri) return;
  FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => {});
}

// Delete every stored photo that no transaction references anymore. Runs
// after a restore or an erase everything, so old receipts never linger on
// disk after the money data that owned them is gone.
export async function cleanupReceipts(keep = []) {
  if (Platform.OS === 'web') return;
  const keepSet = new Set(keep.filter((k) => typeof k === 'string'));
  const names = await FileSystem.readDirectoryAsync(receiptsDir()).catch(() => []);
  for (const n of names) {
    if (!keepSet.has(`receipts/${n}`)) {
      FileSystem.deleteAsync(`${receiptsDir()}${n}`, { idempotent: true }).catch(() => {});
    }
  }
}
