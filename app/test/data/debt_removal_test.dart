import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// Taking a debt off the list, and the two gates that decide how.
///
/// Founder direction, 2026-10-02, choosing the narrower of two designs:
///
///  - A debt that never moved money can be DELETED outright. That is the
///    case the feature was asked for: a debt typed in wrong, ten seconds
///    old, with nothing against it.
///  - A SETTLED debt can be ARCHIVED, which is reversible and changes no
///    figure anywhere, because a settled debt is already out of what you
///    owe.
///  - Anything in between, part paid and still live, gets neither. The
///    rejected design let a live debt be archived, which would have taken a
///    real liability out of "You owe" on a tap.
///
/// BOTH GATES LIVE IN THE STATE, not only in the screen. A screen that hides
/// a control is a presentation choice; these are rules about the data, and
/// this file is what holds them to that.
void main() {
  const Debt clean = Debt(
    id: 'd_clean',
    person: 'Mama',
    direction: DebtDirection.iOwe,
    totalAmount: Money.pesos(500),
    paidAmount: Money.zero,
    isSettled: false,
  );

  const Debt partPaid = Debt(
    id: 'd_part',
    person: 'Home Credit',
    direction: DebtDirection.iOwe,
    totalAmount: Money.pesos(12000),
    paidAmount: Money.pesos(7350),
    isSettled: false,
  );

  const Debt settled = Debt(
    id: 'd_settled',
    person: 'Jollibee tab',
    direction: DebtDirection.iOwe,
    totalAmount: Money.pesos(800),
    paidAmount: Money.pesos(800),
    isSettled: true,
    settledDate: '2026-09-28',
  );

  /// The store is RETURNED, not hidden inside, and that is a fix rather than
  /// a style choice. The reload test below used to assert on the same
  /// in-memory object it had just written, so it could not see the file at
  /// all: blinding `debtFromJson` to archivedAt left all eight tests here
  /// green while the real round-trip test failed twice.
  late MemorySnapshotStore lastStore;

  Future<FinancialState> stateWith(List<Debt> debts) async {
    final MemorySnapshotStore store = MemorySnapshotStore(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
        'debts': debts.map(debtToJson).toList(),
      }),
    );
    lastStore = store;
    final FinancialState s = FinancialState(clock: testToday, store: store);
    await s.restore();
    addTearDown(s.dispose);
    expect(
      s.debts,
      hasLength(debts.length),
      reason: 'the fixture did not load, so every assertion below is hollow',
    );
    return s;
  }

  group('delete, which is permanent', () {
    test('a debt that never moved money goes', () async {
      final FinancialState s = await stateWith(<Debt>[clean, partPaid]);

      expect(s.deleteDebt('d_clean'), isTrue);
      expect(s.debts.map((Debt d) => d.id), <String>['d_part']);
    });

    test('a debt with a paid figure is REFUSED', () async {
      // The directional half, and the one that matters. Deleting this debt
      // would destroy the only structured record of its payments while the
      // entries they wrote stayed in Activity, pointing at a debt Reports
      // would then tell the person to go and fix on a screen that no longer
      // lists it.
      final FinancialState s = await stateWith(<Debt>[partPaid]);

      expect(s.deleteDebt('d_part'), isFalse);
      expect(
        s.debts,
        hasLength(1),
        reason: 'a debt with 7,350.00 against it was deleted anyway',
      );
    });

    test(
      'a debt with a payment register is REFUSED even at zero paid',
      () async {
        // paidAmount back at zero because every payment was taken back. The
        // register is still the history and the entries are still in Activity
        // marked corrected, so this is not a clean debt.
        final Debt emptied = clean.copyWith(
          payments: <DebtPayment>[
            const DebtPayment(
              id: 'dp_1',
              date: '2026-10-01',
              amount: Money.pesos(500),
              paidBefore: Money.zero,
              settledBefore: false,
            ),
          ],
        );
        final FinancialState s = await stateWith(<Debt>[emptied]);

        expect(s.deleteDebt('d_clean'), isFalse);
        expect(s.debts, hasLength(1));
      },
    );

    test('deleting writes no entry and moves no balance', () async {
      final FinancialState s = await stateWith(<Debt>[clean]);
      final int before = s.transactions.length;

      expect(s.deleteDebt('d_clean'), isTrue);
      expect(
        s.transactions,
        hasLength(before),
        reason: 'deleting a debt invented a ledger entry',
      );
    });
  });

  group('archive, which is not', () {
    test('a settled debt goes, and comes back', () async {
      final FinancialState s = await stateWith(<Debt>[settled, partPaid]);

      expect(s.archiveDebt('d_settled'), isTrue);

      // THE MIDPOINT, asserted before the round trip. A "returns to the
      // start" invariant is unfalsifiable by inaction, so without this the
      // test passes hardest with archiveDebt deleted.
      expect(s.debts.map((Debt d) => d.id), <String>['d_part']);
      expect(s.archivedDebts.map((Debt d) => d.id), <String>['d_settled']);
      expect(s.archivedDebts.single.archivedAt, isNotNull);

      expect(s.unarchiveDebt('d_settled'), isTrue);
      expect(s.debts.map((Debt d) => d.id), <String>['d_settled', 'd_part']);
      expect(s.archivedDebts, isEmpty);
    });

    test('a LIVE debt is refused, however much has been paid', () async {
      // Founder direction. This is the fork that was turned down: archiving
      // this debt would drop 4,650.00 out of "You owe" on a tap.
      final FinancialState s = await stateWith(<Debt>[partPaid]);

      expect(s.archiveDebt('d_part'), isFalse);
      expect(s.archivedDebts, isEmpty);
      expect(s.debts, hasLength(1));
    });

    test('archiving changes no total, because it is settled already', () async {
      final FinancialState s = await stateWith(<Debt>[settled, partPaid]);
      final double owedBefore = s.debtsIOwe;

      expect(s.archiveDebt('d_settled'), isTrue);

      expect(
        s.debtsIOwe,
        owedBefore,
        reason:
            'archiving moved a figure, which is exactly what the settled '
            'only gate exists to make impossible',
      );
      // The companion, because "nothing changed" is also true of nothing
      // happening at all.
      expect(s.archivedDebts, hasLength(1));
      expect(owedBefore, greaterThan(0), reason: 'the fixture owes nothing');
    });

    test('an archived debt survives a save and a GENUINE reload', () async {
      final FinancialState s = await stateWith(<Debt>[settled]);
      expect(s.archiveDebt('d_settled'), isTrue);
      await s.flushWrites();

      // A SECOND state, reading the file the first one wrote. The previous
      // version of this test asserted on `s` itself, which never consults
      // storage, so it passed with the decoder blinded to archivedAt.
      final FinancialState reopened = FinancialState(
        clock: testToday,
        store: lastStore,
      );
      await reopened.restore();
      addTearDown(reopened.dispose);

      expect(
        reopened.archivedDebts,
        hasLength(1),
        reason:
            'it came back live, so archiving does not survive closing the '
            'app and the whole feature is cosmetic',
      );
      expect(reopened.debts, isEmpty);
    });
  });

  group('archived implies settled, whatever route is taken', () {
    test('un-settling an archived debt brings it back to the list', () async {
      // THE DEFECT THIS PINS, found by the retrospective AFTER the founder
      // had tested and approved the feature.
      //
      // archiveDebt refuses a live debt, and that was taken to be enough. It
      // was not: the Archived section rendered the ordinary settle control,
      // so two taps made a debt live while it stayed archived. The `debts`
      // getter filters archived debts out, so that liability then counted in
      // no total anywhere, which is the design the founder explicitly turned
      // down, reached by a different route.
      // Settled by the BUTTON, so un-settling restores a real remainder and
      // "it counts again" is something a figure can actually show. A debt
      // settled by real payments has nothing left to count, which is correct
      // and makes it the wrong fixture for this assertion.
      final Debt byButton = partPaid.copyWith(
        paidAmount: const Money.pesos(12000),
        isSettled: true,
        paidBeforeSettle: const Money.pesos(7350),
      );
      final FinancialState s = await stateWith(<Debt>[byButton]);
      expect(s.archiveDebt('d_part'), isTrue);
      expect(s.archivedDebts, hasLength(1));
      expect(s.debtsIOwe, 0, reason: 'an archived debt is still being counted');

      s.toggleDebtSettledById('d_part');

      expect(
        s.archivedDebts,
        isEmpty,
        reason:
            'the debt is live AND archived, so it is a real liability that '
            'appears on no screen and in no total',
      );
      // The directional companion. "Not archived" is also true of a debt
      // that was quietly deleted, or of nothing happening at all.
      expect(s.debts.single.id, 'd_part');
      expect(s.debts.single.isSettled, isFalse);
      expect(
        s.debtsIOwe,
        4650,
        reason: 'it is back on the list but still counts for nothing',
      );
    });

    test(
      'taking a payment back on an archived debt brings it back too',
      () async {
        // THE THIRD DOOR, found by a QA review after the other two were shut.
        //
        // The test above pinned the un-settle route and the plan twin has
        // `_unarchiveIfLive`, so this route was the only one left without the
        // guard. The group's own title says "whatever route is taken", which
        // was a promise it did not keep.
        //
        // What it costs: the money comes back to the account and the restored
        // liability does not come back to the list. `debts` filters archived
        // debts out, so the amount owed appears on no screen and in no total
        // while the asset is counted in full. Net worth reads too high by
        // exactly the payment that was taken back.
        //
        // The confirmation dialog makes this worse by promising the opposite:
        // "goes back to 0.00 paid of 12,000.00" describes a live debt.
        final Debt settledByPayment = partPaid.copyWith(
          paidAmount: const Money.pesos(12000),
          isSettled: true,
          paidBeforeSettle: const Money.pesos(7350),
          payments: <DebtPayment>[
            const DebtPayment(
              id: 'dp_1',
              amount: Money.pesos(4650),
              date: '2026-09-18',
              // What the debt looked like BEFORE this payment, which is what
              // the reversal restores it to: 7,350 of 12,000, not settled.
              paidBefore: Money.pesos(7350),
              settledBefore: false,
            ),
          ],
        );

        final FinancialState s = await stateWith(<Debt>[settledByPayment]);

        expect(s.archiveDebt('d_part'), isTrue);
        expect(s.archivedDebts, hasLength(1));

        expect(s.takeBackDebtPayment('d_part', paymentId: 'dp_1'), isTrue);

        expect(
          s.archivedDebts,
          isEmpty,
          reason:
              'the debt is live AND archived, so the money owed appears on no '
              'screen and in no total while the cash is back in the account',
        );
        // DIRECTIONAL. "Not archived" is equally true of a debt that was
        // deleted, or of the take-back silently doing nothing at all.
        expect(s.debts.single.id, 'd_part');
        expect(s.debts.single.isSettled, isFalse);
        expect(
          s.debtsIOwe,
          greaterThan(0),
          reason: 'it is back on the list and must count again',
        );
      },
    );

    test('settling and un-settling a LIVE debt never archives it', () async {
      // The silent half of the alarm. The clause above must not start
      // archiving or unarchiving debts nobody put away.
      final FinancialState s = await stateWith(<Debt>[partPaid]);

      s.toggleDebtSettledById('d_part');
      expect(s.archivedDebts, isEmpty);
      expect(s.debts.single.isSettled, isTrue);

      s.toggleDebtSettledById('d_part');
      expect(s.archivedDebts, isEmpty);
      expect(s.debts.single.isSettled, isFalse);
    });
  });
}
