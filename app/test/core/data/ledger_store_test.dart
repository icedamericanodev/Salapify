// LedgerStore is small on purpose, so these tests are about the few promises
// it actually makes rather than about money maths, which lives in core/money
// and is golden locked there.
//
// The promise worth testing hardest is the ORDER: persist, then swap, then
// notify. A store that notifies first tells the founder their money is saved
// while the write is still in flight, and if that write throws they are looking
// at a number that does not exist on disk.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/ledger_repository.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart';

/// A repository that records what happened to it, so the ordering can be
/// observed rather than assumed.
class _FakeRepo implements LedgerRepository {
  _FakeRepo([this._ledger]);

  String? _ledger;
  String? _undo;

  final events = <String>[];

  /// When set, writeLedger throws instead of storing. Models a full disk.
  bool failWrites = false;

  /// How long a write takes. Zero everywhere except the overlap tests.
  ///
  /// A real write is a platform channel round trip taking a real fraction of a
  /// second, and every race two writers can lose lives inside that window. An
  /// instant fake closes the race before a test can open it, so a deliberately
  /// broken guard passes and the test reads as proof.
  Duration writeDelay = Duration.zero;

  @override
  Future<String?> readLedger() async {
    events.add('read');
    return _ledger;
  }

  @override
  Future<void> writeLedger(String json) async {
    events.add('write');
    if (failWrites) throw StateError('disk full');
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    _ledger = json;
  }

  @override
  Future<String?> readUndoSnapshot() async => _undo;

  @override
  Future<void> writeUndoSnapshot(String json) async => _undo = json;

  @override
  Future<void> clearUndoSnapshot() async => _undo = null;

  @override
  Future<void> clearLedger() async => _ledger = null;

  /// What is actually on disk, for asserting against what is in memory.
  Map<String, dynamic>? get stored =>
      _ledger == null ? null : jsonDecode(_ledger!) as Map<String, dynamic>;
}

void main() {
  group('loading', () {
    test('an empty store is a first run, not an error', () async {
      final store = LedgerStore(_FakeRepo());
      expect(store.loaded, isFalse);

      await store.load();

      expect(store.loaded, isTrue);
      // Sanitized, so the defaults are there rather than an empty map.
      expect(store.data['schemaVersion'], isNotNull);
      expect(store.data['accounts'], isA<List>());
    });

    test('a stored ledger comes back with its money intact', () async {
      final repo = _FakeRepo(
        jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {
              'id': 'a1',
              'name': 'GCash',
              'kind': 'ewallet',
              'balance': 8410.50,
            },
          ],
        }),
      );

      final store = LedgerStore(repo);
      await store.load();

      final accounts = store.data['accounts'] as List;
      expect(accounts, hasLength(1));
      expect((accounts.single as Map)['balance'], 8410.50);
    });
  });

  group('mutating', () {
    test(
      'the change is on disk and in memory, and listeners hear once',
      () async {
        final repo = _FakeRepo();
        final store = LedgerStore(repo);
        await store.load();

        var notified = 0;
        store.addListener(() => notified++);

        await store.mutate((draft) {
          draft['accounts'] = [
            {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 500.0},
          ];
        });

        expect(notified, 1);
        expect((store.data['accounts'] as List), hasLength(1));
        // The half that actually matters: it survived the app being closed.
        expect((repo.stored!['accounts'] as List), hasLength(1));
      },
    );

    test('a failed write changes nothing and tells nobody it worked', () async {
      // The reason the order is persist, swap, notify. If this ran the other
      // way round the founder would be looking at a balance that exists only
      // in memory, and would find the old one after a restart.
      final repo = _FakeRepo();
      final store = LedgerStore(repo);
      await store.load();

      final before = jsonEncode(store.data);
      var notified = 0;
      store.addListener(() => notified++);
      repo.failWrites = true;

      await expectLater(
        store.mutate((draft) {
          draft['accounts'] = [
            {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 999.0},
          ];
        }),
        throwsA(isA<StateError>()),
      );

      expect(
        notified,
        0,
        reason: 'listeners were told about a write that failed',
      );
      expect(
        jsonEncode(store.data),
        before,
        reason: 'memory moved ahead of the disk',
      );
    });

    test(
      'the draft is a copy, so a throwing change leaves the ledger alone',
      () async {
        final repo = _FakeRepo();
        final store = LedgerStore(repo);
        await store.load();
        final before = jsonEncode(store.data);

        await expectLater(
          store.mutate((draft) {
            draft['accounts'] = [
              {'id': 'a1', 'name': 'Half done', 'kind': 'cash', 'balance': 1.0},
            ];
            throw StateError('changed my mind halfway');
          }),
          throwsA(isA<StateError>()),
        );

        expect(jsonEncode(store.data), before);
        expect(repo.events, isNot(contains('write')));
      },
    );
  });

  group('applying a pure change', () {
    test('the money engine composes straight into it', () async {
      // The reason apply() exists. Every function in core/money is state in,
      // new state out, and addTransaction moves the account balance as well as
      // appending the row. A feature calls this and never touches a balance.
      final repo = _FakeRepo(
        jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 1000.0},
          ],
        }),
      );
      final store = LedgerStore(repo);
      await store.load();

      await store.apply(
        (s) => addTransaction(s, {
          'id': 't1',
          'type': 'expense',
          'amount': 250.0,
          'label': 'Jollibee',
          'accountId': 'a1',
          'date': '2026-09-13',
        }),
      );

      final acct = (store.data['accounts'] as List).single as Map;
      expect((store.data['transactions'] as List), hasLength(1));
      expect(
        acct['balance'],
        750.0,
        reason: 'the row was added but the account balance did not move',
      );
      // The half that survives the app being closed.
      final storedAcct = (repo.stored!['accounts'] as List).single as Map;
      expect(storedAcct['balance'], 750.0);
    });

    test('a failed write changes nothing and tells nobody it worked', () async {
      // apply() has to carry the same promise as mutate(), not a weaker one.
      // Two paths into the same store is exactly how one of them ends up
      // notifying before it has persisted.
      final repo = _FakeRepo(
        jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 1000.0},
          ],
        }),
      );
      final store = LedgerStore(repo);
      await store.load();

      final before = jsonEncode(store.data);
      var notified = 0;
      store.addListener(() => notified++);
      repo.failWrites = true;

      await expectLater(
        store.apply(
          (s) => addTransaction(s, {
            'id': 't1',
            'type': 'expense',
            'amount': 250.0,
            'label': 'Jollibee',
            'accountId': 'a1',
            'date': '2026-09-13',
          }),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        notified,
        0,
        reason: 'listeners were told about a write that failed',
      );
      expect(
        jsonEncode(store.data),
        before,
        reason: 'memory moved ahead of the disk',
      );
    });

    test(
      'the change gets a copy, so a throw leaves the ledger alone',
      () async {
        final repo = _FakeRepo();
        final store = LedgerStore(repo);
        await store.load();
        final before = jsonEncode(store.data);

        await expectLater(
          store.apply((s) {
            s['accounts'] = [
              {'id': 'a1', 'name': 'Half done', 'kind': 'cash', 'balance': 1.0},
            ];
            throw StateError('changed my mind halfway');
          }),
          throwsA(isA<StateError>()),
        );

        expect(jsonEncode(store.data), before);
        expect(repo.events, isNot(contains('write')));
      },
    );
  });

  group('two writers at once', () {
    // The failure this guards is silent by construction. Both writers take a
    // deep COPY of the ledger and then await a write that takes a real fraction
    // of a second on a phone. Overlap inside that window and both branch from
    // the SAME copy, so the second write to land discards the first one's work.
    // Nothing throws, nothing is logged, and the user is told both saves
    // succeeded when one of them did not happen.
    //
    // It is not theoretical. A guard test for the editor sheets asserted "one
    // account exists" after a double tap and PASSED with its guard deleted,
    // because the two overlapping saves wrote the same thing. That is the only
    // reason it looked harmless.

    test('neither change is lost when two saves overlap', () async {
      final repo = _FakeRepo(
        jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 100.0},
          ],
        }),
      );
      final store = LedgerStore(repo);
      await store.load();
      repo.writeDelay = const Duration(milliseconds: 60);

      // Two DIFFERENT writers touching two different things, started without
      // awaiting the first. Recurring auto-posting and a net worth snapshot
      // will do exactly this at launch, with no sheet and no _saving flag
      // anywhere near them.
      final a = store.mutate((d) {
        d['settings'] = {
          ...(d['settings'] as Map).cast<String, dynamic>(),
          'monthlyLimit': 20000.0,
        };
      });
      final b = store.mutate((d) {
        d['accounts'] = [
          for (final acc in (d['accounts'] as List))
            {...(acc as Map).cast<String, dynamic>(), 'balance': 999.0},
        ];
      });
      await Future.wait([a, b]);

      final settings = (store.data['settings'] as Map).cast<String, dynamic>();
      final balance =
          ((store.data['accounts'] as List).first as Map)['balance'];

      expect(
        settings['monthlyLimit'],
        20000.0,
        reason:
            'the second save branched from a copy taken before the first one '
            'landed, so it wrote the limit back to what it used to be',
      );
      expect(
        balance,
        999.0,
        reason: 'the balance change was thrown away by the other writer',
      );
      // And what is on disk agrees with what is in memory, which is the whole
      // promise of persist-then-swap.
      expect(jsonEncode(repo.stored), jsonEncode(store.data));
    });

    test('a failed write does not poison the writes after it', () async {
      // The queue must not become permanently broken because one write threw.
      // A full disk is temporary; a store that refuses every later save is not.
      final repo = _FakeRepo(jsonEncode({'schemaVersion': 12}));
      final store = LedgerStore(repo);
      await store.load();

      repo.failWrites = true;
      await expectLater(
        store.mutate((d) => d['settings'] = {'monthlyLimit': 1.0}),
        throwsA(isA<StateError>()),
      );

      repo.failWrites = false;
      await store.mutate((d) => d['settings'] = {'monthlyLimit': 2.0});

      expect(
        (store.data['settings'] as Map)['monthlyLimit'],
        2.0,
        reason:
            'one failed write left the queue stuck, so every save after it '
            'silently did nothing',
      );
    });
  });
}
