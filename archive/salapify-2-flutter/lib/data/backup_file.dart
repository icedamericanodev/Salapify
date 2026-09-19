// Native file backup: export the backup as a real .json file to the system
// share sheet (Files, Drive, email, anywhere) and import by picking a file.
// This is the RN app's file backup, ported. It needs the file_picker and
// share_plus plugins, so it ships in a base APK, not over the air. The backup
// TEXT is still built and parsed by the golden-locked store methods; this file
// only moves that text in and out of a file, it never touches the data shape.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'save_to_device.dart';
import 'store.dart';

/// A dated, human-readable backup filename that sorts well in a folder. The
/// time is part of the name ON PURPOSE: it makes every save land as a NEW file
/// instead of suggesting an overwrite of yesterday's backup. Overwriting
/// matters because cloud folders (Google Drive through the system dialog) do
/// not truncate an overwritten file, so writing a smaller backup over a bigger
/// one would leave the old file's tail behind and corrupt the JSON, discovered
/// only at restore time. No colons (they break some filesystems); hour and
/// minute only.
String backupFileName(DateTime now) =>
    'salapify-backup-${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}-'
    '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';

/// Writes the current backup to a temp file and opens the system share sheet,
/// so the user can save it to Files or Drive or email it to themselves. The
/// temp file holds the full ledger in plaintext, so it is NOT left behind: any
/// earlier backup temp files are swept first, and the fresh one is deleted once
/// the share sheet flow completes (the share is awaited first, so the receiving
/// app has finished reading the content URI before the file goes). Throws on
/// write or share failure; the caller surfaces it. Returns false when the user
/// dismissed the share sheet without picking a target (so callers do not claim
/// "sent" on a deliberate back-out), true otherwise; platforms that cannot
/// report the outcome count as true.
Future<bool> shareBackupFile(SalapifyStore store, DateTime now) async {
  final text = store.exportBackupText();
  final dir = await getTemporaryDirectory();
  // Sweep any leftover backup temp files (e.g. from a share the OS killed
  // mid-flow) so a plaintext copy of the finances never lingers in the cache.
  try {
    for (final e in dir.listSync()) {
      final name = e.path.split(Platform.pathSeparator).last;
      if (e is File &&
          name.startsWith('salapify-backup-') &&
          name.endsWith('.json')) {
        try {
          e.deleteSync();
        } catch (_) {}
      }
    }
  } catch (_) {}
  final file = File('${dir.path}/${backupFileName(now)}');
  await file.writeAsString(text);
  try {
    final result = await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'Salapify backup');
    return result.status != ShareResultStatus.dismissed;
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// Saves the current backup straight to the device through the system save
/// dialog (the user picks Downloads or any folder). All the platform care
/// (Android writes through the dialog, desktop needs the explicit write, one
/// save at a time) lives in saveBytesToDevice. Returns true when saved, false
/// when the user cancelled.
Future<bool> saveBackupFileToDevice(SalapifyStore store, DateTime now) =>
    saveBytesToDevice(
      utf8.encode(store.exportBackupText()),
      backupFileName(now),
    );

/// Opens the system file picker and returns the chosen file's text, or null if
/// the user cancelled. Reads the in-memory bytes when the platform provides
/// them (web, and Android with withData), otherwise the file path. The text is
/// handed to the store's validated import, so a wrong file fails safely there.
Future<String?> pickBackupFileText() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json', 'txt'],
    // On mobile read the path (no second cached copy, no full load into RAM);
    // the web has no path, so it must hand back the bytes.
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  // A backup is small JSON text; refuse an absurd file before loading it so a
  // wrong pick can never run the phone out of memory.
  const maxBytes = 25 * 1024 * 1024;
  if (f.size > maxBytes) {
    throw const FormatException(
      'That file is too large to be a Salapify backup.',
    );
  }
  final bytes = f.bytes;
  if (bytes != null) return utf8.decode(bytes);
  final path = f.path;
  if (path != null) return File(path).readAsString();
  return null;
}
