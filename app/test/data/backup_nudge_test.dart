import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/backup_nudge.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/features/settings/export_backup.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// The backup reminder (D38.3): when Home asks, when it stays quiet, and that
/// only a backup that actually left the phone silences it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Transaction entry(int i, {int createdAt = 1, bool sample = false}) =>
      Transaction(
        id: 'tx_$i',
        type: TransactionType.expense,
        amount: const Money.pesos(50),
        category: 'Food & Dining',
        accountId: 'acc_cash',
        date: '2026-10-01',
        createdAt: createdAt,
        isSample: sample,
      );

  List<Transaction> entries(
    int n, {
    int createdAt = 1,
    bool sample = false,
  }) => <Transaction>[
    for (int i = 0; i < n; i++) entry(i, createdAt: createdAt, sample: sample),
  ];

  final DateTime now = DateTime(2026, 10, 12, 9);

  group('the rule', () {
    test(
      'never backed up: asks at 30 of the person\'s own entries, not 29',
      () {
        expect(
          backupNudgeCount(transactions: entries(29), now: now),
          isNull,
          reason: '29 entries is under the bar',
        );
        expect(backupNudgeCount(transactions: entries(30), now: now), 30);
      },
    );

    test('example entries are not the person\'s and do not count', () {
      expect(
        backupNudgeCount(
          transactions: <Transaction>[
            ...entries(29),
            ...entries(40, sample: true),
          ],
          now: now,
        ),
        isNull,
      );
    });

    test('counts only entries typed after the last backup, and needs 14 days '
        'since it', () {
      final DateTime backedUp = DateTime(2026, 9, 20, 8);
      final int before = backedUp.millisecondsSinceEpoch - 1;
      final int after = backedUp.millisecondsSinceEpoch + 1;
      final List<Transaction> ledger = <Transaction>[
        ...entries(100, createdAt: before),
        for (int i = 0; i < 31; i++) entry(1000 + i, createdAt: after),
      ];

      // 22 days on, 31 new entries: asks, and names only the new ones.
      expect(
        backupNudgeCount(
          transactions: ledger,
          now: now,
          lastBackupAt: backupStamp(backedUp),
        ),
        31,
      );
      // The same 31 new entries 13 days after the backup: quiet.
      expect(
        backupNudgeCount(
          transactions: ledger,
          now: backedUp.add(const Duration(days: 13)),
          lastBackupAt: backupStamp(backedUp),
        ),
        isNull,
        reason: 'heavy loggers are not asked more than every 14 days',
      );
    });

    test('a "Not now" holds until its day, then lets the card back', () {
      expect(
        backupNudgeCount(
          transactions: entries(40),
          now: now,
          snoozedUntil: '2026-10-13',
        ),
        isNull,
      );
      expect(
        backupNudgeCount(
          transactions: entries(40),
          now: DateTime(2026, 10, 13),
          snoozedUntil: '2026-10-13',
        ),
        40,
      );
    });

    test('an unreadable stored date is treated as absent, never as a reason '
        'to stay quiet', () {
      expect(
        backupNudgeCount(
          transactions: entries(30),
          now: now,
          lastBackupAt: 'not a date',
          snoozedUntil: 'nor this',
        ),
        30,
      );
    });
  });

  group('the store', () {
    FinancialState withEntries(int n) {
      final FinancialState s = FinancialState(clock: now);
      s.removeSampleData();
      for (final Transaction t in entries(n)) {
        s.logTransaction(t);
      }
      return s;
    }

    test('backing up silences it, and the dates survive a save and reload', () {
      final FinancialState s = withEntries(30);
      addTearDown(s.dispose);
      expect(s.backupNudge, 30);

      s.markBackedUp();
      expect(s.backupNudge, isNull);
      expect(s.lastBackupAt, DateTime(2026, 10, 12, 9));

      final Snapshot back = Snapshot.decode(s.snapshot().encode(at: now));
      expect(back.lastBackupAt, '2026-10-12T09:00');
    });

    test('"Not now" is 14 days and is saved', () {
      final FinancialState s = withEntries(30);
      addTearDown(s.dispose);
      s.snoozeBackupNudge();
      expect(s.backupNudge, isNull);
      final Snapshot back = Snapshot.decode(s.snapshot().encode(at: now));
      expect(back.backupNudgeSnoozedUntil, '2026-10-26');
    });

    test('restoring a backup counts as backed up now, so Home does not ask '
        'about the entries it just read from the file', () async {
      final FinancialState from = withEntries(40);
      addTearDown(from.dispose);
      // The file a FIRST backup writes: taken before the backup is recorded,
      // so it carries no lastBackupAt at all.
      final Snapshot file = Snapshot.decode(from.snapshot().encode(at: now));
      expect(file.lastBackupAt, isNull);

      final FinancialState phone = FinancialState(clock: now);
      await phone.restore();
      addTearDown(phone.dispose);
      expect(await phone.importSnapshot(file), isTrue);
      expect(phone.lastBackupAt, DateTime(2026, 10, 12, 9));
      expect(phone.backupNudge, isNull);
    });

    test('a file written before D38 reads as never backed up', () {
      final FinancialState s = withEntries(30);
      addTearDown(s.dispose);
      final String raw = s.snapshot().encode(at: now);
      expect(raw, isNot(contains('lastBackupAt')));
      expect(raw, isNot(contains('backupNudgeSnoozedUntil')));
      expect(Snapshot.decode(raw).lastBackupAt, isNull);
    });
  });

  group('the export records only a backup that left the phone', () {
    const MethodChannel paths = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    const MethodChannel share = MethodChannel(
      'dev.fluttercommunity.plus/share',
    );
    late Directory temp;
    late String reply;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('salapify_nudge_');
      final TestDefaultBinaryMessenger m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMethodCallHandler(paths, (MethodCall call) async => temp.path);
      m.setMockMethodCallHandler(share, (MethodCall call) async => reply);
    });

    tearDown(() {
      final TestDefaultBinaryMessenger m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMethodCallHandler(paths, null);
      m.setMockMethodCallHandler(share, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    for (final ({String name, String reply, bool counts}) c
        in <({String name, String reply, bool counts})>[
          // An app was picked: Android hands back its package name.
          (
            name: 'shared to an app',
            reply: 'com.google.android.apps.docs',
            counts: true,
          ),
          // The receiving app could not say; the file was still handed over.
          (
            name: 'unavailable',
            reply: 'dev.fluttercommunity.plus/share/unavailable',
            counts: true,
          ),
          // Swiped the share sheet away: nothing left the phone.
          (name: 'dismissed', reply: '', counts: false),
        ]) {
      test('${c.name}: ${c.counts ? 'counts' : 'does not count'}', () async {
        reply = c.reply;
        final FinancialState s = FinancialState(clock: now);
        addTearDown(s.dispose);
        final bool done = await exportBackup(state: s, say: (_) {});
        expect(done, c.counts);
        expect(s.lastBackupAt == null, !c.counts);
      });
    }
  });
}
