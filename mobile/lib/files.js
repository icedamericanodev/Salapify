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
import { filesToPrune } from './autobackup';

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

// ---- Automatic backup IO (Android SAF) ----
// These two wrappers power the Pro automatic backup. They write into a folder
// the user already granted us through requestDirectoryPermissionsAsync (the
// dirUri is a SAF tree uri, stored in settings.autoBackupUri). They use the
// SAME 'expo-file-system/legacy' import as saveToDevice above, so no new native
// module is added and this whole feature ships over the air.

// pickBackupFolder: show the Android folder picker (SAF) and return the granted
// tree uri, or null if the user cancelled. This is the same permission dialog
// saveToDevice uses; picking a Google Drive or Dropbox synced folder here is
// exactly how the cloud export works, no API or OAuth needed.
export async function pickBackupFolder() {
  if (Platform.OS !== 'android') return null;
  const perms = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
  return perms.granted ? perms.directoryUri : null;
}

// writeAutoBackup: create the dated file first, then write the blob into it.
// Returns the created file uri. Any failure throws to the caller, which flips
// settings.autoBackupBroken and surfaces the reconnect banner.
export async function writeAutoBackup(dirUri, filename, text) {
  const fileUri = await FileSystem.StorageAccessFramework.createFileAsync(
    dirUri,
    filename,
    'application/json'
  );
  await FileSystem.writeAsStringAsync(fileUri, text);
  return fileUri;
}

// pruneAutoBackups: rotation. List the folder, ask the pure filesToPrune which
// of OUR dated files fall outside the newest keep, and delete just those. Best
// effort: any failure here is swallowed, because a failed prune must never turn
// a successful backup into an error the user sees. Never touches a file that
// does not start with our 'salapify-auto-' prefix.
export async function pruneAutoBackups(dirUri, keep) {
  try {
    const entries = await FileSystem.StorageAccessFramework.readDirectoryAsync(dirUri);
    // SAF returns full content uris, not bare names. The tail after the last
    // encoded separator carries the filename, so decode and take that piece.
    const withNames = entries.map((uri) => {
      const decoded = decodeURIComponent(uri);
      const name = decoded.slice(decoded.lastIndexOf('/') + 1);
      return { uri, name };
    });
    const toDelete = filesToPrune(withNames.map((e) => e.name), keep);
    const dead = new Set(toDelete);
    for (const e of withNames) {
      if (dead.has(e.name)) {
        await FileSystem.deleteAsync(e.uri, { idempotent: true }).catch(() => {});
      }
    }
  } catch {
    // Best effort only: swallow everything so prune can never error the backup.
  }
}

export async function pickTextFile() {
  const res = await DocumentPicker.getDocumentAsync({
    copyToCacheDirectory: true,
    type: ['application/json', 'text/plain', 'application/octet-stream', '*/*'],
  });
  if (res.canceled || !res.assets || !res.assets[0]) return null;
  const uri = res.assets[0].uri;
  try {
    return await FileSystem.readAsStringAsync(uri);
  } finally {
    // The picker copied the chosen backup into our cache directory. Once it
    // is read into memory that copy is a lingering plaintext financial file,
    // so delete it, same discipline as saveTextFile above.
    FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => {});
  }
}
