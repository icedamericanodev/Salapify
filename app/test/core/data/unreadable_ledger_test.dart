// A damaged ledger must not be able to lock the founder out of their own app.
//
// `main.dart` awaits `store.load()` BEFORE `runApp`. `load` decoded the stored
// blob with a bare `jsonDecode`. So one unreadable ledger threw on launch,
// every launch, with no UI ever built: no screen to explain it, no button to
// recover from, and on an offline-first app with no server and no support
// channel that is the whole financial history gone with no way back in.
//
// The window is small and completely real. A write interrupted by a kill or a
// dying battery, a failing disk, a restore that wrote something wrong. The cost
// is total, which is what moves this from tidy-up to must-fix.
//
// Two behaviours are pinned here, and the SECOND is the one that matters:
//   1. The app can still load.
//   2. The damaged bytes are not overwritten, and cannot be, until somebody
//      decides what to do about them.
//
// Without 2, 1 is worse than the crash. Booting into an empty ledger and then
// letting the user log an entry would persist that empty ledger straight over
// the damaged one and finish the job the corruption started. A crash at least
// leaves the bytes intact for a later fix.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/ledger_store.dart';

import '../../support/memory_store.dart';

void main() {
  group('a stored ledger that will not decode', () {
    test('does not stop the app loading', () async {
      final repo = MemoryRepo('{this is not json');
      final store = LedgerStore(repo);

      // The assertion is that this does not throw. Before the fix it threw
      // FormatException here, which on a real phone happens before runApp.
      await store.load();

      expect(store.loaded, isTrue);
      expect(
        store.isUnreadable,
        isTrue,
        reason: 'the store loaded a broken blob and thinks everything is fine',
      );
    });

    test('and says WHY, rather than looking like an empty app', () async {
      final store = LedgerStore(MemoryRepo('{this is not json'));
      await store.load();

      expect(store.unreadable, isNotNull);
      expect(
        store.unreadable,
        contains('FormatException'),
        reason:
            'the reason was swallowed, so nothing can tell a damaged ledger '
            'from a brand new install, and those need opposite screens',
      );
    });

    test('REFUSES every write, so the damage cannot be made permanent', () async {
      final repo = MemoryRepo('{this is not json');
      final store = LedgerStore(repo);
      await store.load();

      final writesBefore = repo.writes;

      await expectLater(
        store.mutate((d) => d['accounts'] = []),
        throwsA(isA<StateError>()),
        reason:
            'a write went through over a damaged ledger, which replaces what '
            'is left of the real one with an empty blob',
      );
      await expectLater(
        store.apply((s) => {...s, 'accounts': const []}),
        throwsA(isA<StateError>()),
      );

      // THE DIRECTIONAL CHECK. "It threw" is not the claim; the claim is that
      // nothing reached the disk. An implementation that threw AFTER writing
      // would satisfy the two expectations above and still destroy the ledger.
      expect(
        repo.writes,
        writesBefore,
        reason:
            'the store wrote to disk and then threw, so the damaged ledger was '
            'overwritten anyway and the exception only hid it',
      );
    });

    test('and the damaged bytes are still there afterwards', () async {
      // The whole point of refusing. Whatever is left in that blob is the only
      // copy of the founder's history, so a later fix has to be able to find it
      // exactly as it was.
      const damaged = '{"accounts": [{"id": "a_bpi", "balance": 42300';
      final repo = MemoryRepo(damaged);
      final store = LedgerStore(repo);
      await store.load();

      expect(await repo.readLedger(), damaged);
    });

    test('a NORMAL ledger is unaffected, and the flag stays clear', () async {
      // The other half of the alarm. A guard that fires on a healthy ledger
      // would block every write in the app, so this is not a formality.
      final store = await memoryStore(livedIn());

      expect(store.isUnreadable, isFalse);
      expect(store.unreadable, isNull);
      expect((store.data['accounts'] as List), isNotEmpty);

      // And writing still works.
      await store.mutate((d) => d['settings'] = {...?d['settings'] as Map?});
      expect(store.isUnreadable, isFalse);
    });

    test('an EMPTY store is a first run, not damage', () async {
      // These two states look identical to a screen and are opposite in
      // meaning: one is a new user, the other is a disaster.
      for (final raw in <String?>[null, '']) {
        final store = LedgerStore(MemoryRepo(raw));
        await store.load();
        expect(store.loaded, isTrue);
        expect(
          store.isUnreadable,
          isFalse,
          reason: 'a fresh install was reported as a damaged ledger',
        );
      }
    });
  });
}
