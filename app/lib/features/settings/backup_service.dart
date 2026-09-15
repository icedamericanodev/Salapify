// Backup, and everything that has to be true before somebody stakes their
// financial history on it.
//
// PURE. Not a widget, no file picker, no share sheet, no storage. It turns
// bytes into answers and answers into bytes, so every rule below is testable
// without a phone. The screen owns the buttons and the platform plumbing; this
// owns what is safe.
//
// THE ONE STRUCTURAL RULE, from which most of the rest follows: a restore is
// PARSED IN MEMORY FIRST, and only a parsed map is ever handed to the store.
// The alternative, writing the file's text and then reloading, makes a
// half-applied restore possible: a truncated file lands on disk, the decode
// fails on the next launch, and on an app with no server and no second copy
// that is the whole ledger gone with no way back. Parsing first makes that
// failure structurally impossible rather than unlikely.
import 'dart:convert';

import '../../core/data/backup.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/statements.dart' show netWorthParts;

/// What a ledger contains, in the four numbers a person can check.
///
/// Shown for the FILE and for the PHONE side by side before a restore, because
/// "are you sure?" is not a question anybody can answer. "This replaces 128
/// entries with 96" is.
class LedgerSummary {
  const LedgerSummary({
    required this.accounts,
    required this.entries,
    required this.debts,
    required this.netWorth,
  });

  final int accounts;
  final int entries;
  final int debts;

  /// From the golden-locked `netWorthParts`, so the figure quoted before a
  /// restore is the same figure the app will show after it.
  final double netWorth;

  /// Nothing in it at all. A backup that summarises to this is the one case a
  /// Replace button must never be offered for: a file from another app with an
  /// empty `accounts` list parses perfectly cleanly, and swapping a real ledger
  /// for it would be the most complete data loss the app can perform, through a
  /// path where nothing went wrong.
  bool get isEmpty => accounts == 0 && entries == 0 && debts == 0;

  static int _count(dynamic v) => v is List ? v.length : 0;

  factory LedgerSummary.of(Map<String, dynamic> data) => LedgerSummary(
    accounts: _count(data['accounts']),
    entries: _count(data['transactions']),
    debts: _count(data['debts']),
    netWorth: amountOf(netWorthParts(data)['netWorth']),
  );
}

/// Why a file could not be used, in words a person can act on.
///
/// Every one of these says what happened AND that nothing was changed, because
/// the first thing anybody thinks when a restore fails is "have I just lost
/// everything".
class BackupFileProblem implements Exception {
  const BackupFileProblem(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Read a backup file's text and say what is in it. Writes nothing, anywhere.
///
/// This is the whole preview step, and it is cheap precisely because
/// `parseBackupObject` and `netWorthParts` are pure: the file can be fully
/// understood, and rejected, without a single byte reaching storage.
LedgerSummary previewBackup(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw const BackupFileProblem(
      'This file could not be read. It may be incomplete, or it may not be a '
      'Salapify backup. Nothing on your phone was changed.',
    );
  }
  return LedgerSummary.of(parseBackupText(text, decoded));
}

/// Parse a backup's text into clean app data, translating the engine's
/// exceptions into sentences.
///
/// `parseBackupObject` already refuses a NEWER schema with user-ready wording,
/// and refuses anything without an `accounts` list as not ours. Both are kept
/// verbatim rather than reworded: they are the messages the shipped app has
/// been using, and a second wording for one condition is a second thing to keep
/// true.
Map<String, dynamic> parseBackupText(String text, [Object? decoded]) {
  final Object? obj;
  if (decoded != null) {
    obj = decoded;
  } else {
    try {
      obj = jsonDecode(text);
    } catch (_) {
      throw const BackupFileProblem(
        'This file could not be read. It may be incomplete, or it may not be a '
        'Salapify backup. Nothing on your phone was changed.',
      );
    }
  }
  try {
    return parseBackupObject(obj);
  } on NewerBackupException catch (e) {
    throw BackupFileProblem('${e.message} Nothing on your phone was changed.');
  } on NotABackupException catch (e) {
    throw BackupFileProblem('${e.message} Nothing on your phone was changed.');
  } catch (_) {
    throw const BackupFileProblem(
      'This file could not be read as a Salapify backup. Nothing on your '
      'phone was changed.',
    );
  }
}

/// Build the text to write out, and PROVE it can be read back.
///
/// The verification is not belt and braces. An export is the thing somebody
/// stakes their entire financial history on, and a file the app cannot itself
/// re-read is not a backup, it is a file. So the text is parsed straight back
/// and its summary compared to the live ledger before the caller is allowed to
/// tell anybody it worked.
///
/// Comparing COUNTS AND NET WORTH rather than comparing strings, deliberately.
/// `sanitizeData` legitimately normalises on the way back in, so a byte
/// comparison would fail for reasons that are not faults. What must survive is
/// the money and the rows, and that is what is checked.
({String text, LedgerSummary summary}) buildVerifiedBackup(
  Map<String, dynamic> data, {
  required DateTime now,
}) {
  final text = buildBackupText(data, exportedAt: now.toIso8601String());

  final live = LedgerSummary.of(data);
  final LedgerSummary readBack;
  try {
    readBack = LedgerSummary.of(parseBackupText(text));
  } catch (e) {
    throw BackupFileProblem(
      'Salapify could not read back the file it just made, so it is not safe '
      'to rely on. Nothing was saved. ($e)',
    );
  }

  if (!summariesMatch(live, readBack)) {
    throw const BackupFileProblem(
      'The backup Salapify just made does not match what is on your phone, so '
      'it is not safe to rely on. Nothing was saved.',
    );
  }

  return (text: text, summary: readBack);
}

/// Whether two ledgers hold the same rows and the same money.
///
/// PUBLIC, and separate from [buildVerifiedBackup], so it can be proved. Inside
/// that function this compares a ledger to itself through a round trip, and
/// that round trip turns out to be robust enough that no contrived input could
/// make it disagree: a first attempt at a test fed it an infinite balance, a
/// row with no id and a row with a numeric id, and all three survived
/// unchanged. That is good news about the format and it left the guard's
/// failing branch unreachable from outside, which CLAUDE.md is explicit about
/// reading as a broken test rather than unusually good code.
///
/// So the comparison is lifted out and tested on its own, where a mismatch can
/// simply be handed to it.
///
/// Counts and money, NOT a byte comparison. `sanitizeData` legitimately
/// normalises on the way back in (250 and 250.0 are the same peso), so
/// comparing text would fail for reasons that are not faults. What has to
/// survive an export is the rows and the money.
bool summariesMatch(LedgerSummary live, LedgerSummary readBack) =>
    readBack.accounts == live.accounts &&
    readBack.entries == live.entries &&
    readBack.debts == live.debts &&
    (readBack.netWorth - live.netWorth).abs() <= 0.005;

/// The file name a backup is offered under.
///
/// Dated, because the single most common backup mistake is keeping one file
/// and overwriting it, which leaves exactly one restore point and no way back
/// past the mistake you are trying to undo.
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'salapify-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
}
