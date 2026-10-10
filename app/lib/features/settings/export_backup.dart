import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/financial_state.dart';

/// Writing the whole ledger to one file and handing it to the share sheet.
///
/// ## Why this is its own file rather than a method on Settings
///
/// It has TWO callers and they are at opposite ends of the same day. Settings
/// offers it as routine housekeeping. The wipe sheet offers it as the last
/// thing before everything goes, because the person who wants a clean start
/// and the person who wants their records gone are the same person on
/// different days, and the second one has no second chance.
///
/// The wipe sheet's class comment promised exactly that from the day it was
/// written, and for some time the promise was prose only: the sheet had no
/// export control at all, so somebody who read "it offers the export first"
/// had to back out, find Export in Settings, and come back. Extracting the
/// function was the alternative to copying forty five lines of share plumbing
/// and a clipboard fallback into a second place, where one copy would quietly
/// stop matching the other.
///
/// ## It never throws
///
/// Every failure path ends with the backup on the CLIPBOARD and a sentence
/// saying so. A share sheet that will not open is an inconvenience; a backup
/// that evaporates because a plugin was missing is the thing this function
/// exists to prevent. [say] reports what happened, and the caller decides
/// whether that is a snackbar or something else.
Future<void> exportBackup({
  required FinancialState state,
  required void Function(String message) say,
}) async {
  final String json = state.snapshot().encode(at: state.now);
  try {
    final Directory dir = await getTemporaryDirectory();
    // THE TIME IS PART OF THE NAME, and both halves of that earn their place.
    //
    // Without the time, two exports on one day carry the SAME name, and the
    // second one lands in Drive or Downloads as a silent overwrite or as
    // "(1)". Somebody exporting twice in a day is usually doing it because
    // they are about to try something they are not sure about, which is the
    // worst possible moment to quietly keep only one of the two files.
    //
    // Without the `3`, it is indistinguishable at a glance from the older
    // Salapify's `salapify-backup-<date>-<HHMM>.json`. During the changeover
    // both apps are installed and exporting into the same folder, and only
    // one of the two files can be regenerated at will: the other is the only
    // copy of records from an app that is about to be uninstalled. The names
    // have to be tellable apart at the moment it matters most.
    final DateTime at = state.now;
    final String day = at.toIso8601String().split('T').first;
    final String hhmm =
        '${at.hour.toString().padLeft(2, '0')}'
        '${at.minute.toString().padLeft(2, '0')}';
    final String stamp = '$day-$hhmm';
    final File file = File('${dir.path}/salapify3-backup-$stamp.json');
    await file.writeAsString(json, flush: true);
    try {
      await Share.shareXFiles(<XFile>[
        XFile(file.path, mimeType: 'application/json'),
      ], subject: 'Salapify backup $stamp');
    } finally {
      // The staging copy goes once the share sheet has it. share_plus hands
      // the receiving app its OWN copy, so nothing waits on this one, and
      // leaving it meant a plain text copy of the whole ledger stayed in
      // the app's cache after "Delete everything" said it was all gone.
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
  } on MissingPluginException {
    // Built before path_provider or share_plus were added. The backup is
    // not lost over a plugin registration; it goes to the clipboard.
    await Clipboard.setData(ClipboardData(text: json));
    say(
      'This build cannot open the share sheet yet, so your backup is on the '
      'clipboard instead. A full rebuild fixes it.',
    );
  } on Object catch (e) {
    await Clipboard.setData(ClipboardData(text: json));
    say('Could not share the file, so it is on your clipboard instead. $e');
  }
}

/// Removes every copy an export or a share left in the app's cache: backup
/// files, an unreadable file kept for rescue, amortization CSVs, and the
/// copies share_plus keeps of what it shared. Called by "Delete everything",
/// whose promise is that nothing of the ledger is left behind. Returns how
/// many files went.
///
/// Only ever the PHONE's cache. On a computer, as under `flutter test`, the
/// temporary directory is the machine's shared /tmp, and a sweep for every
/// .csv there would delete other programs' files. A test hands in a folder
/// of its own as [cache] instead.
Future<int> clearExportCopies({Directory? cache}) async {
  int removed = 0;
  if (cache == null && !(Platform.isAndroid || Platform.isIOS)) return 0;
  try {
    final Directory dir = cache ?? await getTemporaryDirectory();
    if (!dir.existsSync()) return 0;
    for (final FileSystemEntity e in dir.listSync()) {
      final String name = e.uri.pathSegments
          .where((String x) => x.isNotEmpty)
          .last;
      final bool ours =
          (e is File &&
              ((name.startsWith('salapify') && name.endsWith('.json')) ||
                  name.endsWith('.csv'))) ||
          (e is Directory && name == 'share_plus');
      if (!ours) continue;
      try {
        await e.delete(recursive: true);
        removed++;
      } catch (_) {}
    }
  } catch (_) {
    // No cache directory on this platform: nothing was ever written there.
  }
  return removed;
}
