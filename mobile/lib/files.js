// files.js: save and open real files on the phone, so backup and restore
// work by downloading and uploading instead of copy pasting text.
//  - saveTextFile writes the text to a file and opens the share sheet, so
//    you can save it to Files, Google Drive, or send it to yourself.
//  - pickTextFile opens the phone's file picker and reads the chosen file.
// Both are phone only. The web preview keeps its own download and paste
// flows, since browsers handle files differently.

import { Platform } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';

export async function saveTextFile(filename, text, mimeType = 'application/json') {
  const uri = FileSystem.cacheDirectory + filename;
  await FileSystem.writeAsStringAsync(uri, text);
  try {
    if (await Sharing.isAvailableAsync()) {
      await Sharing.shareAsync(uri, { mimeType, dialogTitle: filename });
      return true;
    }
    return false;
  } finally {
    // The cache copy of a full financial backup must not linger after the
    // share sheet closes; the user's chosen destination has the file now.
    FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => {});
  }
}

// Saves the file straight into a folder on the device (like Downloads).
// Android shows a folder picker once, then the file is written there
// directly. On other platforms this falls back to the share sheet.
export async function saveToDevice(filename, text, mimeType = 'application/json') {
  if (Platform.OS !== 'android') {
    return saveTextFile(filename, text, mimeType);
  }
  const perms = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
  if (!perms.granted) return false;
  const uri = await FileSystem.StorageAccessFramework.createFileAsync(
    perms.directoryUri,
    filename,
    mimeType
  );
  await FileSystem.writeAsStringAsync(uri, text);
  return true;
}

export async function pickTextFile() {
  const res = await DocumentPicker.getDocumentAsync({
    copyToCacheDirectory: true,
    type: ['application/json', 'text/plain', 'application/octet-stream', '*/*'],
  });
  if (res.canceled || !res.assets || !res.assets[0]) return null;
  return FileSystem.readAsStringAsync(res.assets[0].uri);
}
