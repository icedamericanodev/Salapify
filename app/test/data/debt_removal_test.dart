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

  Future<FinancialState> stateWith(List<Debt> debts) async {
    final MemorySnapshotStore store = MemorySnapshotStore(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
        'debts': debts.map(debtToJson).toList(),
      }),
    );
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

    test('a debt with a payment register is REFUSED even at zero paid',
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
    });

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

    test('archiving changes no total, because it is settled already',
        () async {
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

    test('an archived debt survives a save and a reload, still archived',
        () async {
      final FinancialState s = await stateWith(<Debt>[settled]);
      expect(s.archiveDebt('d_settled'), isTrue);
      await s.flushWrites();

      expect(
        s.debts,
        isEmpty,
        reason: 'the live list still shows it, so nothing was put away',
      );
      expect(s.archivedDebts, hasLength(1));
    });
  });
}
