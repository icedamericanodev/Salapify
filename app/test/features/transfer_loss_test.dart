// Logging a "transfer" from the Log sheet destroyed money.
//
// Found by a recovery review and reproduced here before it was fixed. The
// shape, end to end:
//
//   1. The Log sheet offered three types: expense, income, TRANSFER.
//   2. Picking Transfer wrote `type: 'transfer'` with an `accountId` and no
//      `flow`, because the sheet has one account picker and a transfer needs
//      two.
//   3. `balanceSign` returns -1 for anything that is not income and has no
//      flow, so `addTransaction` took the money OUT of the picked account.
//   4. Nothing received it. There is no destination on that sheet.
//   5. `sanitizeData` then STRIPPED the accountId, because a transfer with no
//      flow is not a one-sided row, so `removeTransaction` could never give
//      the balance back.
//
// One tap, no error, and the only repair left was retyping the balance in the
// account editor. Which is exactly the control a separate proposal was about
// to take away.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/backup.dart' show sanitizeData;
import 'package:salapify/core/money/ledger.dart'
    show addTransaction, amountOf, removeTransaction;
import 'package:salapify/features/log/log_view_model.dart';

import '../support/memory_store.dart';

Map<String, dynamic> _ledger() => sanitizeData({
  'schemaVersion': 12,
  'accounts': [
    {'id': 'a_gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 5000.0},
    {'id': 'a_bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 0.0},
  ],
});

double _balance(Map<String, dynamic> s, String id) => amountOf(
  (s['accounts'] as List).firstWhere((a) => (a as Map)['id'] == id)['balance'],
);

double _net(Map<String, dynamic> s) =>
    (s['accounts'] as List).fold(0.0, (t, a) => t + amountOf((a as Map)['balance']));

void main() {
  // The two tests below CHARACTERISE the hazard rather than demand a fix.
  //
  // Both behaviours live in `core/money` and `sanitizeData`, which are golden
  // locked and byte identical to the shipped app, so neither can be changed
  // here. They are pinned because they are the reason the feature layer must
  // never hand the engine a flowless transfer: if either of these ever starts
  // behaving differently, the third test's guard may no longer be needed, and
  // somebody should find that out from a red test rather than by guessing.

  test('CHARACTERISING: a flowless transfer takes money and gives none back', () {
    final before = _ledger();
    final after = addTransaction(before, {
      'id': 'tx_1',
      'type': 'transfer',
      'amount': 5000.0,
      'label': 'Move to BPI',
      'date': '2026-09-15',
      'accountId': 'a_gcash',
    });

    // balanceSign reads anything that is not income and has no flow as -1.
    expect(_balance(after, 'a_gcash'), 0.0);
    expect(_balance(after, 'a_bpi'), 0.0);
    expect(
      _net(after),
      0.0,
      reason:
          'the engine stopped destroying money on a one-sided transfer, so '
          'the view model guard may now be unnecessary. Check before removing '
          'it: this is good news, not a broken test',
    );
  });

  test('CHARACTERISING: and sanitizeData removes the only way back', () {
    // sanitizeData strips accountId from a flowless transfer, which is right
    // for the stored shape and fatal for the balance: removeTransaction then
    // has nothing to reverse against.
    final raw = addTransaction(_ledger(), {
      'id': 'tx_1',
      'type': 'transfer',
      'amount': 5000.0,
      'label': 'Move to BPI',
      'date': '2026-09-15',
      'accountId': 'a_gcash',
    });
    final stored = sanitizeData(raw);

    expect(
      (stored['transactions'] as List).first,
      isNot(contains('accountId')),
      reason: 'the accountId survived, so the row is repairable after all',
    );
    expect(
      _net(removeTransaction(stored, 'tx_1')),
      0.0,
      reason:
          'deleting the entry now restores the balance, which would make this '
          'recoverable. Verify and then simplify the guard',
    );
  });

  test('the Log sheet refuses to write one, even when the word is TYPED', () async {
    // Removing the Transfer segment was not enough on its own. `type` falls
    // back to `parsed.type`, and `fastlog` still infers 'transfer' from the
    // word. That file is golden locked and byte identical to the shipped app,
    // so the guard has to live in the view model, and this is what proves it
    // is there.
    final store = await memoryStore(livedIn());
    final vm = LogViewModel(store, now: DateTime(2026, 9, 15));

    vm.setLine('transfer 5000 to bpi');
    expect(
      vm.isTransfer,
      isTrue,
      reason:
          'the parser stopped recognising the word, so this test no longer '
          'exercises the path it was written for',
    );
    expect(
      vm.canSave,
      isFalse,
      reason:
          'the sheet would write a one-sided transfer row, which takes the '
          'money out of one account and puts it nowhere',
    );

    final before = (store.data['transactions'] as List).length;
    await vm.save();
    expect(
      (store.data['transactions'] as List).length,
      before,
      reason: 'save() wrote the row anyway despite canSave being false',
    );
  });
}
