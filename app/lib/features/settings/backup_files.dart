// Getting a backup out of the phone, and a backup back in.
//
// The PLATFORM half, kept apart from backup_service.dart on purpose. Everything
// that decides what is SAFE lives there and is testable with no phone; this
// file only moves bytes through the share sheet and the file picker, which
// cannot be tested without one.
//
// Ported from flutter/lib/data/backup_file.dart rather than written fresh. That
// code has been in front of real users and carries edge cases nobody thinks of
// up front: sweeping abandoned temp files, deleting the shared copy afterwards,
// telling a cancelled share from a completed one, and refusing an absurdly
// large file before loading it. Each of those is a comment below, because a
// port that keeps the code and drops the reasons invites the next person to
// tidy them away.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service.dart';

/// Hand the backup text to the system share sheet.
///
/// Returns false when the person dismissed the sheet without choosing
/// anywhere, so the caller never claims "saved" over a deliberate back-out.
/// That distinction matters more here than almost anywhere else in the app: a
/// person who believes they have a backup and does not is worse off than one
/// who knows they have none.
Future<bool> shareBackupText(String text, String fileName) async {
  final dir = await getTemporaryDirectory();

  // Sweep anything left behind by a share the OS killed mid-flow. The file is
  // the whole ledger in readable text, so a forgotten copy sitting in the cache
  // is the finances lying around outside the app's own storage.
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

  final file = File('${dir.path}/$fileName');
  await file.writeAsString(text);
  try {
    final result = await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'Salapify backup');
    return result.status != ShareResultStatus.dismissed;
  } finally {
    // Always, including when the share threw. The copy has served its purpose
    // the moment the sheet closes.
    try {
      await file.delete();
    } catch (_) {}
  }
}

/// Open the system file picker and return the chosen file's text.
///
/// Null when the person cancelled, which is a normal outcome and not an error.
Future<String?> pickBackupText() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json', 'txt'],
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;

  // A backup is small JSON. Refusing an absurd file BEFORE reading it means a
  // wrong pick (a video, a disk image) cannot run the phone out of memory
  // trying to decode something that was never going to be a backup.
  const maxBytes = 25 * 1024 * 1024;
  if (f.size > maxBytes) {
    throw const BackupFileProblem(
      'That file is too large to be a Salapify backup. Nothing on your phone '
      'was changed.',
    );
  }

  final bytes = f.bytes;
  if (bytes != null) return utf8.decode(bytes);
  final path = f.path;
  if (path == null) {
    throw const BackupFileProblem(
      'That file could not be opened. Nothing on your phone was changed.',
    );
  }
  return File(path).readAsString();
}
