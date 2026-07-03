// Receipt photos for entries. The picture is copied into the app's own
// documents folder (cache folders get cleaned by Android), and the entry
// stores only the file path, never the image bytes, so AsyncStorage stays
// small and fast. Everything is a no-op on web.

import { Alert, Platform } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system/legacy';

const receiptsDir = () => `${FileSystem.documentDirectory}receipts/`;

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
  const dest = `${receiptsDir()}receipt_${Date.now().toString(36)}.jpg`;
  await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
  return dest;
}

// Best effort cleanup when an entry is deleted or an attachment replaced.
export function deleteReceipt(uri) {
  if (!uri || typeof uri !== 'string' || Platform.OS === 'web') return;
  FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => {});
}
