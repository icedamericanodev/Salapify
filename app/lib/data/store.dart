import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'json_codec.dart';
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

  /// Where the file is, for a diagnostics line. Never shown by default.
  String get location;
}

/// One JSON file in the app's documents directory.
class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore({this.fileName = 'salapify_data.json'});

  final String fileName;
  Directory? _dir;

  /// Makes each temp file its own, so two writes can never share a path even
  /// if something ever manages to overlap them.
  int _writeCounter = 0;

  @override
  String get location => _dir == null ? fileName : '${_dir!.path}/$fileName';

  Future<Directory> _directory() async =>
      _dir ??= await getApplicationDocumentsDirectory();

  Future<File> _file() async =>
      File('${(await _directory()).path}/$fileName');

  Future<File> _previousFile() async =>
      File('${(await _directory()).path}/$fileName.prev');

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
  Future<void> write(String next) async {
    if (failWriteWith != null) throw failWriteWith!;
    if (contents != null) previous = contents;
    contents = next;
    writes++;
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
    return _fallBackToPrevious(
      store,
      'Salapify\'s data file is empty.',
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
