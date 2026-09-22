// Where a receiving QR image actually lives: a local file, on this device only.
//
// The design in one sentence: user data stores a FILENAME (`qrRef`), the bytes
// live in a file next to the ledger, and nothing about a QR ever leaves the
// phone unless the person deliberately shares that file. The JSON backup carries
// the reference and its label, never the image bytes, so exporting a backup can
// never leak somebody's receiving QR. On a restored backup the reference points
// at a file that is not there, which the screen shows as "not in this backup"
// and offers to re-add, rather than a broken image.
//
// This class is PURE around a directory path so a test can point it at a temp
// folder, exactly the pattern FileLedgerRepository uses. Only the
// `inAppDocuments` factory touches path_provider.
//
// The vault OWNS the filename. It stamps `qr_<nonce>.<ext>`, the one shape
// account_taxonomy's `isQrRef` accepts, so a reference can never carry a path
// separator or a `..` that would escape this folder. A caller's nonce is
// sanitised to `[A-Za-z0-9_-]` before it is used, so even a hostile id cannot
// change where the file lands.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../money/account_taxonomy.dart' show isQrRef;

/// The image types the vault accepts, matched to `isQrRef`'s extension set.
const Set<String> kQrImageExtensions = {'png', 'jpg', 'jpeg', 'webp'};

/// The largest source image the vault will store. A QR is tiny; a photo of one
/// from a gallery can be several megabytes, but past this it is almost always a
/// wrong pick (a screenshot of a whole screen, a random photo) rather than a
/// scannable code, and storing it just bloats the device. Rejected with a
/// message, never silently truncated.
const int kQrMaxBytes = 6 * 1024 * 1024;

class QrSaveException implements Exception {
  final String message;
  QrSaveException(this.message);
  @override
  String toString() => message;
}

class QrVault {
  /// The folder QR files live in. In production this is the app documents
  /// directory; in a test it is a temp folder.
  final String directoryPath;

  const QrVault(this.directoryPath);

  /// The production vault, rooted at the app documents directory, the same
  /// durable, device-local folder the ledger uses.
  static Future<QrVault> inAppDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    return QrVault(dir.path);
  }

  File _fileFor(String ref) => File('$directoryPath/$ref');

  /// The absolute path for a stored reference, or null when the reference is
  /// not a legal QR filename. Never builds a path from an unvalidated string,
  /// so a corrupt `qrRef` can never point [File] at something outside the vault.
  String? pathFor(String? ref) {
    if (!isQrRef(ref)) return null;
    return _fileFor(ref as String).path;
  }

  /// True when the referenced file actually exists on disk. A stored reference
  /// with no file (a restored backup, a manual delete) is not an error; the
  /// screen shows an empty QR slot instead of a broken image.
  Future<bool> exists(String? ref) async {
    final p = pathFor(ref);
    if (p == null) return false;
    return File(p).exists();
  }

  /// Read the bytes for a reference, or null when there is no readable file.
  Future<Uint8List?> readBytes(String? ref) async {
    final p = pathFor(ref);
    if (p == null) return null;
    final f = File(p);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  /// Write [bytes] as a new QR file and return its reference (the filename).
  ///
  /// [ext] must be one of [kQrImageExtensions]. [nonce] is any string the caller
  /// has; it is sanitised to `[A-Za-z0-9_-]` and capped, so the resulting name
  /// always matches `isQrRef` whatever was passed in. Throws [QrSaveException]
  /// on an empty image, an image over [kQrMaxBytes], or an unsupported type,
  /// so the screen can show why rather than storing junk.
  Future<String> save(
    Uint8List bytes, {
    required String ext,
    required String nonce,
  }) async {
    final e = ext.toLowerCase();
    if (!kQrImageExtensions.contains(e)) {
      throw QrSaveException('That file type is not a supported image.');
    }
    if (bytes.isEmpty) {
      throw QrSaveException('That image was empty.');
    }
    if (bytes.length > kQrMaxBytes) {
      throw QrSaveException(
        'That image is too large. Pick the QR itself, not a full screenshot.',
      );
    }
    var clean = nonce.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (clean.isEmpty) clean = 'q';
    if (clean.length > 48) clean = clean.substring(0, 48);
    final ref = 'qr_$clean.$e';
    if (!isQrRef(ref)) {
      // Defensive: the sanitiser above already guarantees this, but a filename
      // that would not round-trip through the persistence contract must never
      // be written, or a load would silently drop the reference and orphan the
      // file we just created.
      throw QrSaveException('Could not build a safe filename for that image.');
    }
    await Directory(directoryPath).create(recursive: true);
    await _fileFor(ref).writeAsBytes(bytes, flush: true);
    return ref;
  }

  /// Delete the file for a reference. A missing file is a no-op, not an error:
  /// removing a QR that is already gone is success, not a failure to report.
  Future<void> remove(String? ref) async {
    final p = pathFor(ref);
    if (p == null) return;
    final f = File(p);
    if (await f.exists()) await f.delete();
  }

  /// Every `qr_*` file currently on disk in the vault folder. Used to find
  /// orphans against the set of references the data still points at.
  Future<Set<String>> filesOnDisk() async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return {};
    final out = <String>{};
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (isQrRef(name)) out.add(name);
      }
    }
    return out;
  }

  /// Delete every QR file not named in [keepRefs], and return how many were
  /// removed. This is the leak stop: a QR whose account was deleted, or that was
  /// replaced by a new image, leaves a file behind, and nothing else would ever
  /// clean it up. Runs against the live reference set, so a file that is still
  /// pointed at is always kept.
  Future<int> cleanupOrphans(Set<String> keepRefs) async {
    final onDisk = await filesOnDisk();
    var removed = 0;
    for (final name in onDisk) {
      if (!keepRefs.contains(name)) {
        await _fileFor(name).delete();
        removed++;
      }
    }
    return removed;
  }
}

/// Every `qrRef` the data currently points at, across accounts, debts and
/// assets. The keep-set for [QrVault.cleanupOrphans].
Set<String> qrRefsInData(Map<String, dynamic> data) {
  final refs = <String>{};
  for (final key in const ['accounts', 'debts', 'assets']) {
    final list = data[key];
    if (list is List) {
      for (final row in list) {
        if (row is Map && isQrRef(row['qrRef'])) {
          refs.add(row['qrRef'] as String);
        }
      }
    }
  }
  return refs;
}
