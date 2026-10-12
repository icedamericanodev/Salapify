import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// `Debt.openingTxId` (D35, 2026-10-10) and the copy that carries it.
void main() {
  const Debt plain = Debt(
    id: 'd',
    person: 'Ana',
    direction: DebtDirection.owedToMe,
    totalAmount: Money.pesos(300),
    paidAmount: Money.zero,
    isSettled: false,
  );

  test('a debt from an older backup loads with no opening entry', () {
    final Map<String, dynamic> old = debtToJson(plain);
    expect(old.containsKey('openingTxId'), isFalse, reason: 'row changed');
    expect(debtFromJson(old).openingTxId, isNull);
  });

  test('an opening entry survives a save and reload', () {
    const Debt opened = Debt(
      id: 'd',
      person: 'Ana',
      direction: DebtDirection.owedToMe,
      totalAmount: Money.pesos(300),
      paidAmount: Money.zero,
      isSettled: false,
      openingTxId: 'tx_split_1_lent',
    );
    expect(debtFromJson(debtToJson(opened)).openingTxId, 'tx_split_1_lent');
    expect(debtKeys, contains('openingTxId'));
  });

  test('a copy keeps the minimum and the opening entry', () {
    const Debt d = Debt(
      id: 'd',
      person: 'Card',
      direction: DebtDirection.iOwe,
      totalAmount: Money.pesos(10000),
      paidAmount: Money.zero,
      isSettled: false,
      minimumPayment: Money.pesos(1500),
      openingTxId: 'tx_1',
    );
    final Debt c = d.copyWith(paidAmount: const Money.pesos(500));
    expect(c.minimumPayment, const Money.pesos(1500));
    expect(c.openingTxId, 'tx_1');
  });

  test('paying a debt no longer erases the minimum the person typed', () async {
    // Measured before the fix: 1,500 before the payment, null after, so
    // Safe to Spend stopped holding back the card's minimum the moment the
    // person paid anything towards it.
    final FinancialState s = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    s.addDebt(
      const Debt(
        id: 'd_min',
        person: 'Card',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(10000),
        paidAmount: Money.zero,
        isSettled: false,
        minimumPayment: Money.pesos(1500),
      ),
    );
    s.recordDebtPayment('d_min', 500);
    final Debt after = s.debts.firstWhere((Debt d) => d.id == 'd_min');
    // Directional: the payment did land.
    expect(after.paidAmount, const Money.pesos(500));
    expect(after.minimumPayment, const Money.pesos(1500));
  });
}
