/// When Home asks for a backup (D38.3).
///
/// Salapify keeps everything on the phone and nowhere else, so a lost or
/// broken phone loses every record with it. The fix already exists (Settings,
/// Export backup) and nobody goes looking for it, so Home asks. Rarely:
///
///   - only once there are [entriesBeforeAsking] of the person's OWN entries
///     the last backup does not hold, which spares somebody who logs twice a
///     week from being asked about a handful of rows;
///   - only once [daysBetweenAsks] days have passed since that backup, which
///     spares somebody who logs forty things a day from being asked daily;
///   - never while a "Not now" is still running.
///
/// Both counts must be met, and that pairing is the whole design: either
/// alone nags one kind of person.
///
/// Pure, so the rule is tested without a widget, and kept beside the other
/// rules in this folder because it reads the ledger the same way they do.
library;

import '../../models/models.dart';

/// Entries since the last backup before Home asks.
const int entriesBeforeAsking = 30;

/// Days since the last backup, and the length of a "Not now".
const int daysBetweenAsks = 14;

/// How many of the person's own entries the last backup does not hold, when
/// Home should ask about them, or null when it should not.
///
/// [lastBackupAt] and [snoozedUntil] are the stored strings, read here so the
/// store never has to. A value that cannot be read counts as absent: an
/// unreadable "last backup" is no evidence of a backup, and an unreadable
/// snooze is no reason to stay quiet.
int? backupNudgeCount({
  required List<Transaction> transactions,
  required DateTime now,
  String? lastBackupAt,
  String? snoozedUntil,
}) {
  final DateTime? snooze = snoozedUntil == null
      ? null
      : DateTime.tryParse(snoozedUntil);
  if (snooze != null && now.isBefore(snooze)) return null;

  final DateTime? last = lastBackupAt == null
      ? null
      : DateTime.tryParse(lastBackupAt);
  if (last != null && now.difference(last).inDays < daysBetweenAsks) {
    return null;
  }

  // Sample entries are not the person's; a backup protects their own.
  // createdAt is when the row was typed, which is what a backup taken at a
  // moment does or does not hold. The entry's own date is not: somebody
  // logging last Tuesday's lunch today has an entry the backup lacks.
  final int since = last?.millisecondsSinceEpoch ?? 0;
  final int count = transactions
      .where((Transaction t) => !t.isSample && t.createdAt > since)
      .length;
  return count >= entriesBeforeAsking ? count : null;
}

/// The stored form of "now" for [lastBackupAt]: to the minute, local time.
String backupStamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}T'
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';
