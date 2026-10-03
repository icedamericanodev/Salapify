import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';

/// What survives a wipe that does not finish.
///
/// From an adversarial QA pass. The first test is the reason the file exists:
/// the delete order was wrong, and a phone killed halfway through gave the
/// person their entire ledger back on the next launch, with saving re-enabled
/// so it was written straight back to disk.
void main() {
  late Directory dir;
  late FileSnapshotStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('salapify_wipe_');
    store = FileSnapshotStore(directory: dir);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String named(File f) => f.path.split('/').last;

  test('the copies go BEFORE the live ledger, so an interrupted wipe cannot '
      'restore it', () async {
    // loadSnapshot reads a MISSING live file as an interrupted save and
    // recovers from .prev. So with the live file deleted first, a process
    // killed between the two deletes comes back with everything.
    //
    // Asserted on the ORDER, because the order IS the property: every
    // prefix of this sequence has to leave a state that cannot resurrect
    // the ledger, and only the live file being last gives that.
    final List<String> order = (await store.filesToDeleteInOrder())
        .map(named)
        .toList();

    // EXACTLY ONCE, AND LAST. Asserting only "last" is not enough, and that
    // is not hypothetical: breaking the code by adding the live file to the
    // FRONT of the list left it at the back as well, and the weaker
    // assertion passed with the defect fully present. The property is that
    // nothing may unlink the live ledger before the copies are gone, so it
    // must appear once and at the end.
    expect(
      order.where((String f) => f == 'salapify_data.json').length,
      1,
      reason:
          'the live ledger is deleted more than once, so one of those deletes '
          'happens before the copies and a phone killed there recovers the '
          'whole ledger from .prev',
    );
    expect(
      order.last,
      'salapify_data.json',
      reason:
          'the live ledger is not deleted last, so a phone killed mid-wipe '
          'recovers the whole ledger from .prev on the next launch and '
          'starts saving it again',
    );
    for (final String copy in <String>[
      'salapify_data.json.prev',
      'salapify_data.json.preimport',
    ]) {
      expect(order, contains(copy));
      expect(
        order.indexOf(copy),
        lessThan(order.indexOf('salapify_data.json')),
      );
    }
  });

  test('an orphaned temp file from a crashed save is deleted too', () async {
    // write() stages to <file>.<n>.tmp and renames. A process that dies
    // between the flush and the rename leaves a complete plaintext ledger
    // behind, and _writeCounter restarts at zero each launch, so a high
    // numbered orphan is never reused and never overwritten.
    await File('${dir.path}/salapify_data.json').writeAsString('{}');
    final File orphan = File('${dir.path}/salapify_data.json.7.tmp');
    await orphan.writeAsString('{"accounts":[{"id":"a1","name":"Payroll"}]}');

    await store.deleteEverything();

    expect(
      orphan.existsSync(),
      isFalse,
      reason:
          'a full readable copy of the ledger is still on the phone after '
          '"delete everything" reported it had removed everything',
    );
  });

  test('a real wipe leaves the directory empty, and says how many', () async {
    await store.write('{"accounts":[]}');
    await store.writePreImport('{"accounts":[]}');
    await File('${dir.path}/salapify_fx_cache.json').writeAsString('{}');

    final int removed = await store.deleteEverything();

    expect(removed, greaterThanOrEqualTo(2));
    expect(
      dir.listSync().map((FileSystemEntity e) => named(File(e.path))).toList(),
      isEmpty,
      reason: 'something Salapify wrote is still on the phone',
    );
    expect(await store.read(), isNull);
    expect(await store.readPrevious(), isNull);
    expect(await store.readPreImport(), isNull);
  });

  test('wiping twice is harmless and reports nothing removed', () async {
    await store.write('{"accounts":[]}');
    expect(await store.deleteEverything(), greaterThan(0));
    expect(await store.deleteEverything(), 0);
  });
}
