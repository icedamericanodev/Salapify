import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/main.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// The state where Salapify cannot read your data file, walked end to end.
///
/// ## Why this needed building at all
///
/// It used to be a dead end. Export was disabled, Restore was disabled, saving
/// was off, eleven sample accounts were on screen, and the only signal was a
/// small red mark on the gear. The file holding the person's money sat in
/// app-private storage a stock Android file manager cannot open. The only
/// route out was to hope the previous generation happened to be clean, and
/// the obvious thing to try, uninstalling, destroys the very file that might
/// still have been rescued.
///
/// Three things now exist, and all three are asserted here:
///
///  1. Home says the figures are not yours and nothing is being saved.
///  2. Export sends the raw bytes, which is the only copy worth having.
///  3. Restore is offered, and keeps those bytes rather than a snapshot of
///     the sample ledger.
String _unreadableFile() => jsonEncode(<String, dynamic>{
  'schemaVersion': 1,
  'accounts': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'acc_real',
      'name': 'My real bank',
      'kind': 'bank',
      'institution': 'BPI',
      'balance': 48000,
      'monogram': 'B',
    },
  ],
  // Past the point where a double can still count every centavo, so the
  // decoder refuses it. Every file written before the centavo work had no
  // magnitude check at all, which is what makes this the upgrade case.
  'transactions': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'tx_bad',
      'type': 'expense',
      'amount': 1e17,
      'category': 'Food',
      'accountId': 'acc_real',
      'date': '2026-09-12',
      'createdAt': 1,
    },
  ],
});

void main() {
  testWidgets('Home says plainly that the figures are not yours', (
    WidgetTester tester,
  ) async {
    final MemorySnapshotStore store = MemorySnapshotStore(_unreadableFile());
    final FinancialState state = FinancialState(store: store, clock: testToday);
    await state.restore();
    addTearDown(state.dispose);

    expect(state.loadStatus, LoadStatus.unreadable);
    expect(state.isSaving, isFalse);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    // The wrong conclusion this exists to prevent: believing the sample
    // ledger is yours.
    expect(find.text('These figures are not yours'), findsOneWidget);
    // And the second one: typing a week of real spending into a ledger that
    // is not being saved.
    expect(
      find.textContaining('Nothing you type now is being saved'),
      findsOneWidget,
    );
    // A control, not a sentence telling somebody to go and find one.
    expect(find.text('What I can do about it'), findsOneWidget);
  });

  testWidgets('and it appears in NO other state', (WidgetTester tester) async {
    // The directional half, and the one that matters most: the founder
    // removed the standing banners because they were in front of every
    // screen. A banner that shows on an ordinary phone is the defect, not the
    // feature.
    final FinancialState state = await pumpSalapify(tester);

    expect(state.loadStatus, isNot(LoadStatus.unreadable));
    expect(find.text('These figures are not yours'), findsNothing);
  });

  test('the raw bytes are reachable, and they are the REAL file', () async {
    // Export used to be refused here, correctly, because a snapshot in this
    // state encodes the SEED. The remedy is to send the bytes instead.
    final MemorySnapshotStore store = MemorySnapshotStore(_unreadableFile());
    final FinancialState state = FinancialState(store: store, clock: testToday);
    await state.restore();
    addTearDown(state.dispose);

    final String? raw = await state.rawStoredFile();
    expect(raw, isNotNull);
    expect(
      raw,
      contains('My real bank'),
      reason: 'the export must carry the person\'s records, not the samples',
    );
    expect(
      state.snapshot().accounts.first.name,
      isNot('My real bank'),
      reason:
          'and this is WHY: the snapshot in this state is the sample ledger, '
          'so exporting one would hand somebody demo accounts labelled as '
          'their backup',
    );
  });

  test('restore is allowed, and keeps the unreadable bytes', () async {
    final MemorySnapshotStore store = MemorySnapshotStore(_unreadableFile());
    final FinancialState state = FinancialState(store: store, clock: testToday);
    await state.restore();
    addTearDown(state.dispose);
    expect(state.loadStatus, LoadStatus.unreadable);

    // A good backup, the sort somebody has in their email.
    final Snapshot good = Snapshot.decode(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'acc_from_backup',
            'name': 'Restored bank',
            'kind': 'bank',
            'institution': 'BPI',
            'balance': 12000,
            'monogram': 'B',
          },
        ],
        'transactions': <Map<String, dynamic>>[],
      }),
    );

    final bool ok = await state.importSnapshot(good);

    expect(
      ok,
      isTrue,
      reason:
          'restore was refused in the one state that '
          'needs it, leaving uninstalling as the only move',
    );
    expect(state.accounts.single.name, 'Restored bank');
    expect(state.isSaving, isTrue);

    // THE COPY PROMISE, kept literally. What was preserved is the real
    // unreadable file, not a snapshot of the sample ledger.
    expect(store.preImport, isNotNull);
    expect(
      store.preImport,
      contains('My real bank'),
      reason:
          'the pre-import copy held the sample ledger, so the only copy of '
          'the person\'s records was thrown away by the thing meant to save it',
    );
  });

  test('with nothing on disk at all, restore still refuses', () async {
    // The other half of the gate. The copy promise is this method's whole
    // contract: if there is nothing to copy, it must refuse rather than
    // quietly import without one.
    final MemorySnapshotStore store = MemorySnapshotStore('   ');
    final FinancialState state = FinancialState(store: store, clock: testToday);
    await state.restore();
    addTearDown(state.dispose);

    if (state.loadStatus == LoadStatus.unreadable) {
      final Snapshot good = Snapshot.decode(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'accounts': <Map<String, dynamic>>[],
          'transactions': <Map<String, dynamic>>[],
        }),
      );
      expect(await state.importSnapshot(good), isFalse);
    }
  });
}
