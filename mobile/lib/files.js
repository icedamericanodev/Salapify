// files.js: save and open real files on the phone, so backup and restore
// work by downloading and uploading instead of copy pasting text.
//  - saveTextFile writes the text to a file and opens the share sheet, so
//    you can save it to Files, Google Drive, or send it to yourself.
//  - pickTextFile opens the phone's file picker and reads the chosen file.
// Both are phone only. The web preview keeps its own download and paste
// flows, since browsers handle files differently.

import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import * as DocumentPicker from 'expo-document-picker';

export async function saveTextFile(filename, text, mimeType = 'application/json') {
  const uri = FileSystem.cacheDirectory + filename;
  await FileSystem.writeAsStringAsync(uri, text);
  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(uri, { mimeType, dialogTitle: filename });
    return true;
  }
  return false;
}

export async function pickTextFile() {
  const res = await DocumentPicker.getDocumentAsync({
    copyToCacheDirectory: true,
    type: ['application/json', 'text/plain', 'application/octet-stream', '*/*'],
  });
  if (res.canceled || !res.assets || !res.assets[0]) return null;
  return FileSystem.readAsStringAsync(res.assets[0].uri);
}
