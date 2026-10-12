import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';

/// An absence and a refusal are not the same answer.
///
/// ## The defect this file exists to stop coming back
///
/// `_fallBackToPrevious` used to read the previous generation and DECODE it
/// inside one `try`. So a previous generation that EXISTED and would not
/// decode landed in the same branch as no previous generation at all.
///
/// The caller for a missing live file passes `whenNoPrevious: fresh`, and a
/// missing live file is a real state the store's own comments describe: a save
/// interrupted between demoting the old file and publishing the new one, a
/// force stop, an OOM.
///
/// So that combination reported a FIRST RUN. Saving turned on. The sample
/// ledger appeared. Nothing warned, because the red badge keys on a save
/// problem or an unreadable status and this was neither, and the Settings
/// panel said "Your entries are being saved to this phone". The first save did
/// not demote anything, because there was no live file to demote. The second
/// one overwrote the previous generation that still held the person's real
/// records.
///
/// Both copies gone, silently, while the app reported that everything was
/// being saved.
///
/// It was always reachable by any decode failure. The move to whole centavos
/// widened the set of decode failures, which is what brought it to light: an
/// amount a previous build stored with no magnitude check at all is refused by
/// a build that has one.
String _ledger(Object amount) => jsonEncode(<String, dynamic>{
  'schemaVersion': 1,
  'accounts': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'acc_1',
      'name': 'BPI',
      'kind': 'bank',
      'institution': 'BPI',
      'balance': 23000,
      'monogram': 'B',
    },
  ],
  'transactions': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'tx_1',
      'type': 'expense',
      'amount': amount,
      'category': 'Food',
      'accountId': 'acc_1',
      'date': '2026-09-12',
      'createdAt': 1,
    },
  ],
});

void main() {
  group('a previous generation that will not decode is NOT a first run', () {
    test('it stops, says so, and leaves both files alone', () async {
      // 1e17 pesos is past the point where a double can still count every
      // centavo, so Money refuses it. Any decode failure does the same thing
      // here; this is the one an upgrade can actually produce, because every
      // file already on a phone was written with no magnitude check.
      final MemorySnapshotStore store = MemorySnapshotStore(null)
        ..previous = _ledger(1e17);

      final LoadResult r = await loadSnapshot(store);

      expect(
        r.status,
        LoadStatus.unreadable,
        reason:
            'reported as a first run, which turns saving on over a file that '
            'still holds the records',
      );
      // The directional half. `unreadable` alone would pass if the function
      // simply refused everything, so the message has to name the second
      // failure rather than only the first.
      expect(r.problem, contains('data file is missing'));
      expect(r.problem, contains('copy before it could not be read either'));
      expect(r.problem, contains('nothing has been written over it'));
      expect(r.snapshot, isNull);

      // And the bytes are still there, which is the whole point of stopping.
      expect(store.previous, isNotNull);
      expect(store.writes, 0);
    });

    test('but a CLEAN previous generation still recovers', () async {
      // Without this, a fix that simply returned `unreadable` for every
      // fallback would pass the test above and break the recovery path that
      // exists to save people.
      final MemorySnapshotStore store = MemorySnapshotStore(null)
        ..previous = _ledger(250);

      final LoadResult r = await loadSnapshot(store);

      expect(r.status, LoadStatus.recovered);
      expect(r.snapshot, isNotNull);
      expect(r.problem, contains('data file is missing'));
    });

    test('and a GENUINE first run is still a first run', () async {
      // The half that would be easiest to break while fixing the other two,
      // and the most damaging to break: every new install takes this path. No
      // live file and no previous generation is somebody opening Salapify for
      // the first time, and they must not be told their data is unreadable.
      final MemorySnapshotStore store = MemorySnapshotStore(null);

      final LoadResult r = await loadSnapshot(store);

      expect(r.status, LoadStatus.fresh);
      expect(r.problem, isNull);
    });

    test('an EMPTY previous generation is an absence, not a refusal', () async {
      // A zero-length file is what an interrupted write leaves behind. It
      // carries no records, so there is nothing to protect and nothing to
      // report.
      final MemorySnapshotStore store = MemorySnapshotStore(null)
        ..previous = '   ';

      final LoadResult r = await loadSnapshot(store);

      expect(r.status, LoadStatus.fresh);
    });
  });
}
