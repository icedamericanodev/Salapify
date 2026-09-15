// Backup, and the ways it can quietly destroy somebody's financial history.
//
// These run against no widgets and no storage on purpose. Every rule the
// restore flow leans on is decided here, in pure functions, so the screen only
// has to wire buttons to answers rather than be trusted with the answers.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/backup.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/features/settings/backup_service.dart';

import '../support/memory_store.dart';

final _now = DateTime(2026, 9, 15, 20, 30);

void main() {
  group('export', () {
    test('what comes out reads back as what went in', () {
      final data = livedIn();
      final out = buildVerifiedBackup(data, now: _now);

      final live = LedgerSummary.of(data);
      expect(out.summary.accounts, live.accounts);
      expect(out.summary.entries, live.entries);
      expect(out.summary.debts, live.debts);
      expect(out.summary.netWorth, closeTo(live.netWorth, 0.005));

      // Did anything happen. A fixture with nothing in it would satisfy every
      // assertion above while proving nothing at all.
      expect(live.accounts, greaterThan(0));
      expect(live.entries, greaterThan(0));
      expect(live.netWorth, isNot(0));
    });

    test('and it is a real Salapify backup, not just some JSON', () {
      final text = buildVerifiedBackup(livedIn(), now: _now).text;
      final obj = jsonDecode(text) as Map<String, dynamic>;

      expect(obj['app'], 'salapify');
      expect(obj['version'], 2);
      expect(obj['exportedAt'], _now.toIso8601String());
      expect(obj['data'], isA<Map>());
    });

    test('a backup that lost something is REFUSED, not saved', () {
      // The point of verifying: an export is the one file somebody stakes
      // their whole history on, so "we wrote something" is not success.
      //
      // Tested on `summariesMatch` rather than by feeding buildVerifiedBackup a
      // broken ledger, and that is a correction rather than a shortcut. The
      // first version of this test tried an infinite balance, then a row with
      // no id, then a row with a numeric id: all three survived the round trip
      // untouched, so the guard's failing branch was simply unreachable and the
      // test passed while proving nothing. CLAUDE.md is explicit that this
      // means the test is wrong, so the comparison was lifted out to where a
      // mismatch can be handed to it directly.
      const live = LedgerSummary(
        accounts: 3,
        entries: 96,
        debts: 2,
        netWorth: 171825.75,
      );

      expect(summariesMatch(live, live), isTrue, reason: 'identical disagreed');

      // Each field on its own, so a guard that only checks one still fails.
      expect(
        summariesMatch(
          live,
          const LedgerSummary(accounts: 2, entries: 96, debts: 2, netWorth: 171825.75),
        ),
        isFalse,
        reason: 'an account vanished in the export and nothing noticed',
      );
      expect(
        summariesMatch(
          live,
          const LedgerSummary(accounts: 3, entries: 95, debts: 2, netWorth: 171825.75),
        ),
        isFalse,
        reason: 'an entry vanished in the export and nothing noticed',
      );
      expect(
        summariesMatch(
          live,
          const LedgerSummary(accounts: 3, entries: 96, debts: 1, netWorth: 171825.75),
        ),
        isFalse,
        reason: 'a debt vanished in the export and nothing noticed',
      );
      expect(
        summariesMatch(
          live,
          const LedgerSummary(accounts: 3, entries: 96, debts: 2, netWorth: 171825.74),
        ),
        isFalse,
        reason: 'a centavo went missing and the export was called good',
      );

      // And rounding noise is not a mismatch, or every export would be refused.
      expect(
        summariesMatch(
          live,
          const LedgerSummary(accounts: 3, entries: 96, debts: 2, netWorth: 171825.7501),
        ),
        isTrue,
      );
    });

    test('the file name carries the date, so one file cannot hide another', () {
      expect(backupFileName(DateTime(2026, 9, 5)), 'salapify-backup-2026-09-05.json');
      expect(backupFileName(DateTime(2026, 12, 25)), 'salapify-backup-2026-12-25.json');
    });
  });

  group('reading a file, before anything is written', () {
    test('a real backup previews with its real figures', () {
      final text = buildVerifiedBackup(livedIn(), now: _now).text;
      final preview = previewBackup(text);

      expect(preview.accounts, LedgerSummary.of(livedIn()).accounts);
      expect(preview.isEmpty, isFalse);
    });

    test('nonsense is refused, and SAYS nothing was changed', () {
      // The first thing anybody thinks when a restore fails is "have I just
      // lost everything". Every refusal has to answer that in the same breath.
      for (final bad in ['not json at all', '{"truncated": ', '']) {
        expect(
          () => previewBackup(bad),
          throwsA(
            isA<BackupFileProblem>().having(
              (e) => e.message,
              'message',
              contains('Nothing on your phone was changed'),
            ),
          ),
          reason: 'input "$bad" was accepted, or refused without reassurance',
        );
      }
    });

    test('someone else\'s JSON is refused as not ours', () {
      expect(
        () => previewBackup('{"hello": "world"}'),
        throwsA(
          isA<BackupFileProblem>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('does not look like a Salapify backup'),
              contains('Nothing on your phone was changed'),
            ),
          ),
        ),
      );
    });

    test('a NEWER schema is refused rather than silently downgraded', () {
      // The dangerous one. A future Salapify writes fields this build does not
      // understand; accepting it would drop them on the floor and then write
      // the result back as the truth.
      final text = jsonEncode({
        'app': 'salapify',
        'version': 2,
        'data': {'accounts': <dynamic>[], 'schemaVersion': schemaVersion + 1},
      });
      expect(
        () => previewBackup(text),
        throwsA(isA<BackupFileProblem>()),
      );
    });

    test('an EMPTY backup parses, and is flagged as empty', () {
      // It is valid, and it is the most dangerous file the app can be handed:
      // nothing is wrong with it, and restoring it over a real ledger is the
      // most complete data loss available through a path where nothing failed.
      // The screen refuses to offer Replace for this; the flag is what it reads.
      final text = jsonEncode({
        'app': 'salapify',
        'version': 2,
        'data': {'accounts': <dynamic>[]},
      });
      expect(previewBackup(text).isEmpty, isTrue);
    });
  });

  group('restore, and the one undo', () {
    test('replaces everything, and keeps what was there', () async {
      final store = await memoryStore(livedIn());
      final before = LedgerSummary.of(store.data);

      final incoming = parseBackupText(
        jsonEncode({
          'app': 'salapify',
          'version': 2,
          'data': {
            'accounts': [
              {'id': 'a_only', 'name': 'Only', 'kind': 'cash', 'balance': 500.0},
            ],
          },
        }),
      );
      await store.restoreFrom(incoming);

      final after = LedgerSummary.of(store.data);
      expect(after.accounts, 1);
      expect(after.netWorth, closeTo(500, 0.005));

      // DIRECTIONAL: the old ledger really is gone, not merged alongside.
      // Without this, a restore that appended would pass "the new account is
      // here" perfectly.
      expect(
        before.accounts,
        greaterThan(1),
        reason: 'the fixture had one account, so replace and merge look alike',
      );
      expect(
        after.entries,
        0,
        reason:
            'entries from the old ledger survived the restore, so this merged '
            'rather than replaced and every figure is now double counted',
      );
    });

    test('and UNDO puts back exactly what was replaced', () async {
      final store = await memoryStore(livedIn());
      final before = LedgerSummary.of(store.data);

      await store.restoreFrom(
        parseBackupText(
          jsonEncode({
            'app': 'salapify',
            'version': 2,
            'data': {
              'accounts': [
                {'id': 'a_only', 'name': 'Only', 'kind': 'cash', 'balance': 500.0},
              ],
            },
          }),
        ),
      );
      expect(await store.hasUndoSnapshot, isTrue);

      expect(await store.undoRestore(), isTrue);

      final back = LedgerSummary.of(store.data);
      expect(back.accounts, before.accounts);
      expect(back.entries, before.entries);
      expect(back.debts, before.debts);
      expect(
        back.netWorth,
        closeTo(before.netWorth, 0.005),
        reason: 'undo returned a different amount of money than it took away',
      );
    });

    test('ONE undo, and the second attempt says so instead of lying', () async {
      final store = await memoryStore(livedIn());
      await store.restoreFrom(parseBackupText(
        buildVerifiedBackup(livedIn(), now: _now).text,
      ));
      expect(await store.undoRestore(), isTrue);

      expect(
        await store.undoRestore(),
        isFalse,
        reason:
            'a second undo reported success with nothing to undo, so the user '
            'is told their data came back when nothing happened',
      );
      expect(await store.hasUndoSnapshot, isFalse);
    });

    test('restoring onto an EMPTY app offers no undo, rather than a stale one', () async {
      final store = await memoryStore();
      await store.restoreFrom(
        parseBackupText(buildVerifiedBackup(livedIn(), now: _now).text),
      );

      expect(LedgerSummary.of(store.data).accounts, greaterThan(0));
      expect(
        await store.hasUndoSnapshot,
        isFalse,
        reason:
            'there was nothing on the phone to go back to, so offering Undo '
            'would put back an empty app the user never asked for',
      );
    });

    test('restore WORKS over a damaged ledger, which is when it is needed', () async {
      // The one write that must still go through when every other write is
      // refused. A user whose ledger will not decode has exactly one route
      // back, and it is this one.
      final repo = MemoryRepo('{not json');
      final store = LedgerStore(repo);
      await store.load();
      expect(store.isUnreadable, isTrue);

      await store.restoreFrom(
        parseBackupText(buildVerifiedBackup(livedIn(), now: _now).text),
      );

      expect(store.isUnreadable, isFalse);
      expect(LedgerSummary.of(store.data).accounts, greaterThan(0));
    });

    test('and the damaged bytes are what UNDO puts back, not an empty map', () async {
      // The subtle one. While damaged, the in-memory ledger is EMPTY, so a
      // snapshot taken from memory would throw away the only remaining copy of
      // the real history. The snapshot has to be the bytes from disk.
      const damaged = '{"accounts": [{"id": "a_bpi", "balance": 42300';
      final repo = MemoryRepo(damaged);
      final store = LedgerStore(repo);
      await store.load();

      await store.restoreFrom(
        parseBackupText(buildVerifiedBackup(livedIn(), now: _now).text),
      );
      expect(await store.undoRestore(), isTrue);

      expect(
        await repo.readLedger(),
        damaged,
        reason:
            'undo put back an empty ledger instead of the damaged bytes, so '
            'whatever was still recoverable in them is now gone for good',
      );
    });
  });
}
