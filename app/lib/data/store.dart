import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'json_codec.dart';
import '../features/pan/pan_history.dart' show panHistoryFileName;
import 'snapshot.dart';

/// Where the one file lives, and how it is written.
///
/// Split behind an interface for one reason that matters: `path_provider`
/// talks to the platform over a method channel, which does not exist in a
/// widget test. Tests use [MemorySnapshotStore] and exercise the same load and
/// save path the phone does.
abstract class SnapshotStore {
  /// The file's contents, or null when there is no file yet.
  Future<String?> read();

  /// The generation BEFORE the current one, or null when there is not one.
  ///
  /// Two generations rather than one because a single file has a single way
  /// to be unreadable and no way back. With a previous copy the worst case
  /// stops being "six months of entries are gone" and becomes "the last
  /// change is gone", which is a bad minute instead of a catastrophe.
  Future<String?> readPrevious();

  Future<void> write(String contents);

  /// The ledger as it was immediately BEFORE the last import, or null.
  ///
  /// A copy of its own, and not the .prev generation, for a reason worth
  /// stating because reusing .prev looks obviously right: write() demotes the
  /// live file on EVERY write, and every notification is a write, because
  /// notifyListeners is overridden to schedule a save. Tapping a filter chip
  /// is a write. So .prev would hold the pre-import ledger for exactly one
  /// user action, and the next tap would destroy the only copy of somebody's
  /// real records. That is a coincidence, not a recovery mechanism.
  Future<String?> readPreImport();

  /// Keeps [contents] as the pre-import copy, replacing any earlier one.
  ///
  /// Must be durable before it returns. The confirmation promises the person
  /// can put their ledger back, and the only way to keep that promise is to
  /// refuse to import when this fails.
  Future<void> writePreImport(String contents);

  /// Deletes EVERY file this store keeps, and says how many it removed.
  ///
  /// All of them, not just the live one, and that is the whole point of the
  /// method existing. Salapify keeps three copies of a ledger: the current
  /// file, the previous generation, and the copy taken before the last
  /// restore. The last of those is never overwritten and never expires, so a
  /// person who restored a backup once is carrying a complete second ledger,
  /// other people's names included, that no screen in the app mentions.
  ///
  /// "Delete everything on this phone" that left any of the three behind
  /// would be a false promise in the one place a false promise costs the
  /// most, and it is the promise the privacy policy and Play's data deletion
  /// question both rest on.
  Future<int> deleteEverything();

  /// Where the file is, for a diagnostics line. Never shown by default.
  String get location;
}

/// One JSON file in the app's documents directory.
class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore({
    this.fileName = 'salapify_data.json',
    Directory? directory,
  }) : _dir = directory;

  final String fileName;

  /// Where the files go. Null means ask path_provider, which is what the app
  /// does; a test passes a temp directory and never touches a platform
  /// channel. Same shape as FxService's cacheDir, and for the same reason:
  /// without it the only way to exercise the real file paths is on a phone.
  Directory? _dir;

  /// Makes each temp file its own, so two writes can never share a path even
  /// if something ever manages to overlap them.
  int _writeCounter = 0;

  @override
  String get location => _dir == null ? fileName : '${_dir!.path}/$fileName';

  Future<Directory> _directory() async =>
      _dir ??= await getApplicationDocumentsDirectory();

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<File> _previousFile() async =>
      File('${(await _directory()).path}/$fileName.prev');

  Future<File> _preImportFile() async =>
      File('${(await _directory()).path}/$fileName.preimport');

  @override
  Future<String?> read() async {
    final File f = await _file();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<String?> readPrevious() async {
    final File f = await _previousFile();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<String?> readPreImport() async {
    final File f = await _preImportFile();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<int> deleteEverything() async {
    int removed = 0;
    for (final File f in await filesToDeleteInOrder()) {
      // Each in its own try. One file refusing to go must not leave the
      // others behind.
      try {
        if (await f.exists()) {
          await f.delete();
          removed++;
        }
      } on Object {
        // Counted as not removed. The caller reports the count rather than
        // claiming success it cannot verify.
      }
    }
    return removed;
  }

  /// Every file a wipe removes, IN THE ORDER IT MUST REMOVE THEM.
  ///
  /// The order is a correctness property rather than an implementation
  /// detail, which is why it is a named method with its own test rather than
  /// a list inside the loop.
  Future<List<File>> filesToDeleteInOrder() async {
    final Directory dir = await _directory();
    final File live = await _file();

    // THE LIVE LEDGER GOES LAST, and getting this backwards handed somebody
    // their whole ledger back.
    //
    // The first version deleted it FIRST, reasoning that it is the file that
    // matters most. That is exactly wrong for a wipe, because `loadSnapshot`
    // reads a MISSING live file as an interrupted save and recovers from
    // `.prev`. So a phone killed between the two deletes (a force stop, an
    // OOM, a swipe away) came back next launch with every account and entry
    // restored, a banner saying only the last change was lost, and saving
    // re-enabled so it was immediately written back to disk. For somebody who
    // wiped before handing the phone over, that is the precise failure this
    // feature exists to prevent.
    //
    // With the copies removed first, an interrupted wipe leaves at most the
    // live file, which loads normally and can simply be wiped again.
    return <File>[
      await _preImportFile(),
      await _previousFile(),
      // Every orphaned temp file, ENUMERATED rather than named.
      //
      // `write` stages to `<file>.<n>.tmp` and renames. A process that dies
      // between the flush and the rename leaves that temp behind, holding a
      // complete plaintext ledger, and `_writeCounter` restarts at zero each
      // launch so a high-numbered orphan is never reused or overwritten.
      // Deleting four literal paths left it there while the screen said
      // everything had been removed.
      ...await _orphans(dir, live),
      // The FX cache. Not a ledger and not secret, but it is a file Salapify
      // put on this phone, and "everything" has to mean everything or the
      // sentence is doing work it has not earned.
      File('${dir.path}/salapify_fx_cache.json'),
      // The Pan conversation. The MOST sensitive of the non-ledger files,
      // despite being the least important: it holds sentences somebody typed
      // in their own words, which is a different kind of private from a
      // balance. Somebody wiping before handing the phone over is wiping
      // this above all.
      File('${dir.path}/$panHistoryFileName'),
      live,
    ];
  }

  /// Leftover staging files from a write that never finished.
  Future<List<File>> _orphans(Directory dir, File live) async {
    try {
      final List<FileSystemEntity> all = await dir.list().toList();
      return <File>[
        for (final FileSystemEntity e in all)
          if (e is File &&
              e.path.startsWith(live.path) &&
              e.path.endsWith('.tmp'))
            e,
      ];
    } on Object {
      // A directory that cannot be listed is not a reason to abandon the
      // wipe. The four known paths below still go.
      return const <File>[];
    }
  }

  /// Same temp-flush-rename dance as [write], and deliberately NO .prev
  /// demotion: this path has one generation and nothing else touches it.
  @override
  Future<void> writePreImport(String contents) async {
    final File target = await _preImportFile();
    final File temp = File('${target.path}.${_writeCounter++}.tmp');
    final RandomAccessFile handle = await temp.open(mode: FileMode.writeOnly);
    try {
      await handle.writeString(contents);
      await handle.flush();
    } finally {
      await handle.close();
    }
    await temp.rename(target.path);
  }

  /// Write to a temp file of its own, fsync it, keep the outgoing copy as the
  /// previous generation, then rename the new one into place.
  ///
  /// The rename is the point. Writing in place means a phone that dies mid
  /// write leaves a half written file, and half a ledger is worse than none
  /// because it looks like a whole one. A rename within a directory is
  /// atomic: afterwards the file is entirely the old contents or entirely the
  /// new, never a mixture.
  ///
  /// The fsync matters as much and is easier to get wrong. `writeAsString`
  /// takes `flush: false` BY DEFAULT, so the obvious one liner renames over
  /// bytes the kernel has not committed. On ext4 a fsync-on-rename heuristic
  /// usually hides that; f2fs, which is what most modern Android phones use,
  /// does not. Opening the file and calling flush ourselves is explicit about
  /// it. Dart still cannot fsync the DIRECTORY, so a small window survives
  /// where the rename itself is not durable, and that residual window is
  /// exactly why the previous generation below is not optional.
  @override
  Future<void> write(String contents) async {
    final File target = await _file();
    final File temp = File('${target.path}.${_writeCounter++}.tmp');
    final RandomAccessFile handle = await temp.open(mode: FileMode.writeOnly);
    try {
      await handle.writeString(contents);
      await handle.flush();
    } finally {
      await handle.close();
    }

    // Demote the current file before promoting the new one. Rename rather
    // than copy: it is one cheap syscall and it cannot half succeed.
    if (await target.exists()) {
      try {
        await target.rename('${target.path}.prev');
      } on FileSystemException {
        // Losing the previous generation is not a reason to lose the new
        // entry too. Carry on and publish the write.
      }
    }
    await temp.rename(target.path);
  }
}

/// A store that keeps the document in memory, for tests and previews.
class MemorySnapshotStore implements SnapshotStore {
  MemorySnapshotStore([this.contents]);

  String? contents;

  /// The generation before [contents], kept the same way the file store keeps
  /// it, so a test exercises the real recovery path rather than a simpler one.
  String? previous;

  /// Every write this store has seen, so a test can assert that a save
  /// actually happened rather than only that the numbers were right.
  int writes = 0;

  /// Set to make the next write fail, standing in for a full disk.
  Object? failWriteWith;

  /// Set to make reading the live file fail, standing in for a bad sector.
  Object? failReadWith;

  /// The pre-import copy, and the switch that makes keeping it fail.
  String? preImport;
  Object? failPreImportWith;

  /// Which write happened first. The ORDER is the safety property: the copy
  /// has to land before the new ledger does, so a phone that dies in between
  /// leaves the old ledger plus a copy of it, which is a harmless no-op.
  final List<String> order = <String>[];

  @override
  String get location => 'memory';

  @override
  Future<String?> read() async {
    if (failReadWith != null) throw failReadWith!;
    return contents;
  }

  @override
  Future<String?> readPrevious() async => previous;

  @override
  Future<String?> readPreImport() async => preImport;

  @override
  Future<int> deleteEverything() async {
    int removed = 0;
    for (final String? held in <String?>[contents, previous, preImport]) {
      if (held != null) removed++;
    }
    contents = null;
    previous = null;
    preImport = null;
    order.add('deleteEverything');
    return removed;
  }

  @override
  Future<void> writePreImport(String contents) async {
    if (failPreImportWith != null) throw failPreImportWith!;
    preImport = contents;
    order.add('preimport');
  }

  @override
  Future<void> write(String next) async {
    if (failWriteWith != null) throw failWriteWith!;
    if (contents != null) previous = contents;
    contents = next;
    writes++;
    order.add('write');
  }
}

/// What happened when the app tried to load.
enum LoadStatus {
  /// No file yet. A first run, or a fresh install.
  fresh,

  /// A file was there and was read.
  loaded,

  /// The current file could not be read, but the generation before it could.
  /// Everything is here except whatever the last save was carrying.
  recovered,

  /// Neither generation could be read. Nothing has been lost yet, and
  /// nothing may be written until the person decides what to do.
  unreadable,
}

class LoadResult {
  const LoadResult._(this.status, {this.snapshot, this.problem});

  const LoadResult.fresh() : this._(LoadStatus.fresh);
  const LoadResult.loaded(Snapshot snapshot)
    : this._(LoadStatus.loaded, snapshot: snapshot);
  const LoadResult.recovered(Snapshot snapshot, String problem)
    : this._(LoadStatus.recovered, snapshot: snapshot, problem: problem);
  const LoadResult.unreadable(String problem)
    : this._(LoadStatus.unreadable, problem: problem);

  final LoadStatus status;
  final Snapshot? snapshot;

  /// A sentence a beginner can act on, when [status] is unreadable.
  final String? problem;
}

/// Reads the file and turns every failure into an answer rather than a crash.
///
/// The one rule this exists to enforce: an unreadable file is NEVER
/// overwritten. Losing the ability to read somebody's ledger is a bad day;
/// writing seed data over it on the next tap is the end of their records, and
/// there is no server holding a copy.
Future<LoadResult> loadSnapshot(SnapshotStore store) async {
  final String? raw;
  try {
    raw = await store.read();
  } on Object catch (e) {
    return _fallBackToPrevious(
      store,
      'Salapify could not open its data file. $e',
    );
  }

  if (raw == null) {
    // No live file. There may still be a previous generation, if a save was
    // interrupted between demoting the old file and publishing the new one.
    return _fallBackToPrevious(
      store,
      'Salapify\'s data file is missing.',
      whenNoPrevious: const LoadResult.fresh(),
    );
  }

  if (raw.trim().isEmpty) {
    // An empty file is not a fresh start. Something wrote nothing where a
    // ledger should be, and treating it as a first run would hand the person
    // demo accounts and then save those over whatever went wrong.
    return _fallBackToPrevious(store, 'Salapify\'s data file is empty.');
  }

  // The shape check runs FIRST, and quietly: anything it cannot parse is left
  // for Snapshot.decode below, which produces a sentence written for a person
  // rather than a raw FormatException. Doing the jsonDecode here and letting it
  // throw replaced "The file is not valid JSON" with the parser's own output,
  // which store_test caught.
  Object? peek;
  try {
    peek = jsonDecode(raw);
  } on Object {
    peek = null;
  }
  if (peek is Map && !looksLikeSalapify(Map<String, dynamic>.from(peek))) {
    // Valid JSON, and not a ledger. Falling back to the previous generation
    // turns "everything is gone" into "one save is gone".
    return _fallBackToPrevious(
      store,
      'The data file does not look like a Salapify ledger any more. It has '
      'none of the parts one has.',
    );
  }

  try {
    return LoadResult.loaded(Snapshot.decode(raw));
  } on SnapshotFormatException catch (e) {
    return _fallBackToPrevious(store, e.message);
  } on Object catch (e) {
    return _fallBackToPrevious(
      store,
      'Salapify could not read its data file. $e',
    );
  }
}

/// The current file failed. Try the generation before it.
///
/// Recovering one save back is a different event from losing everything, and
/// conflating the two is how a bad minute gets reported to somebody as a
/// catastrophe. The caller tells them which one happened.
Future<LoadResult> _fallBackToPrevious(
  SnapshotStore store,
  String problem, {
  LoadResult? whenNoPrevious,
}) async {
  try {
    final String? previous = await store.readPrevious();
    if (previous != null && previous.trim().isNotEmpty) {
      return LoadResult.recovered(Snapshot.decode(previous), problem);
    }
  } on Object {
    // The previous generation is no better. Fall through to the honest answer
    // below rather than reporting the second failure over the first.
  }
  return whenNoPrevious ??
      LoadResult.unreadable(
        '$problem Nothing has been deleted and nothing has been written over '
        'it.',
      );
}

/// Turns a stored failure into a sentence a person can act on.
///
/// The raw text of these failures is written for whoever wrote the plugin, not
/// for whoever is holding the phone. The founder's own screenshot is the
/// argument for this function: the headline on their screen was
///
///     MissingPluginException(No implementation found for method
///     getApplicationDocumentsDirectory on channel
///     plugins.flutter.io/path_provider)
///
/// which names a channel, a method and a package, and answers none of the
/// three questions somebody actually has: is my money gone, was this my fault,
/// and what do I do now.
///
/// The raw text is NOT discarded by the caller, because it is what makes a
/// screenshot diagnosable. It moves underneath the plain sentence instead of
/// standing in for one.
String plainStorageProblem(String raw) {
  // The app is missing its own file-access plugin. On a development build this
  // means the running app predates the plugin and needs rebuilding; on a real
  // install it means the package was built wrong. "Reinstall" is the one
  // instruction that is true and useful in both cases.
  if (raw.contains('MissingPluginException')) {
    return 'This copy of Salapify cannot reach the phone’s file storage, '
        'so it was built without a part it needs. Reinstalling the app fixes '
        'it. Nothing already saved has been damaged.';
  }

  // Out of space. Worth its own sentence because it is the one on this list
  // the person can actually fix in the next minute.
  if (raw.contains('ENOSPC') || raw.contains('No space left')) {
    return 'This phone has run out of storage, so Salapify cannot write your '
        'entries. Freeing up some space will let it save again.';
  }

  if (raw.contains('EACCES') || raw.contains('Permission denied')) {
    return 'Salapify was refused permission to write to its own folder. '
        'Reinstalling the app usually restores it.';
  }

  // A file that exists and cannot be understood. Deliberately does NOT say
  // "corrupted", which sounds like everything is lost, when the previous
  // generation has usually already been opened instead.
  // 'not valid JSON' is matched as well as the exception NAMES, and that gap
  // was real rather than theoretical: loadSnapshot passes SnapshotFormatException's
  // .message, not its toString(), so the likeliest unreadable-file case in
  // the whole app arrived here carrying no exception name at all and fell
  // straight through to the raw text. A translator that misses the common
  // case and catches the rare ones is worse than none, because it reads as
  // though the wording was considered.
  if (raw.contains('SnapshotFormatException') ||
      raw.contains('FormatException') ||
      raw.contains('not valid JSON') ||
      raw.contains('could not read its data file')) {
    return 'Salapify could not make sense of its data file. It has not '
        'overwritten anything while it cannot read it.';
  }

  // Anything unrecognised is returned unchanged. Inventing a friendly sentence
  // for a failure nobody has seen would be guessing at a cause, and a wrong
  // reassuring sentence is worse than an ugly accurate one.
  return raw;
}
