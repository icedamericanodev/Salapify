import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Park it for 48 hours (D38.2): parking spends nothing, the wish survives a
/// save and a reopen, and Home asks only once the 48 hours are up.
void main() {
  final DateTime parkedOn = DateTime(2026, 10, 12, 20, 40);

  Future<FinancialState> reopenedAt(FinancialState from, DateTime at) async {
    final FinancialState later = FinancialState(
      clock: at,
      store: MemorySnapshotStore(from.snapshot().encode(at: from.now)),
    );
    await later.restore();
    addTearDown(later.dispose);
    return later;
  }

  test('parking spends nothing and moves no balance', () {
    final FinancialState s = FinancialState(clock: parkedOn);
    addTearDown(s.dispose);
    final List<Money> before = <Money>[
      for (final Account a in s.accounts) a.balance,
    ];
    final int entries = s.transactions.length;

    s.parkItem(
      name: 'Running shoes',
      amount: const Money.pesos(4500),
      category: 'Shopping',
    );

    expect(s.parkedItems.single.name, 'Running shoes');
    expect(s.transactions.length, entries, reason: 'parking logged an entry');
    expect(<Money>[for (final Account a in s.accounts) a.balance], before);
  });

  test('Home asks only once 48 hours have passed, and the wish survives a '
      'save and a reopen to get there', () async {
    final FinancialState s = FinancialState(clock: parkedOn);
    addTearDown(s.dispose);
    s.parkItem(name: 'Running shoes', amount: const Money.pesos(4500));
    expect(s.parkedReady, isNull);

    final FinancialState nextDay = await reopenedAt(
      s,
      parkedOn.add(const Duration(hours: 47, minutes: 59)),
    );
    expect(nextDay.parkedItems, hasLength(1));
    expect(nextDay.parkedReady, isNull, reason: 'asked before 48 hours');

    final FinancialState twoDays = await reopenedAt(
      s,
      parkedOn.add(const Duration(hours: 48)),
    );
    final ParkedItem ready = twoDays.parkedReady!;
    expect(ready.name, 'Running shoes');
    expect(ready.amount, const Money.pesos(4500));
  });

  test('let it go removes it, and Undo puts back exactly the same item', () {
    final FinancialState s = FinancialState(clock: parkedOn);
    addTearDown(s.dispose);
    final ParkedItem p = s.parkItem(
      name: 'Headphones',
      amount: Money.fromDouble(2999.5),
      category: 'Shopping',
    );

    final ParkedItem gone = s.unpark(p.id)!;
    expect(s.parkedItems, isEmpty);
    s.restoreParked(gone);
    expect(s.parkedItems.single.id, p.id);
    expect(s.parkedItems.single.parkedAt, p.parkedAt);
    // A second Undo is a no-op, never a duplicate.
    s.restoreParked(gone);
    expect(s.parkedItems, hasLength(1));
  });

  test('the file carries nothing new until something is parked', () {
    final FinancialState s = FinancialState(clock: parkedOn);
    addTearDown(s.dispose);
    expect(s.snapshot().encode(at: parkedOn), isNot(contains('parkedItems')));
    s.parkItem(name: 'x', amount: const Money.pesos(1));
    final Snapshot back = Snapshot.decode(s.snapshot().encode(at: parkedOn));
    expect(back.parkedItems.single.name, 'x');
  });

  test('a wipe takes the parked list with everything else', () async {
    final FinancialState s = FinancialState(clock: parkedOn);
    await s.restore();
    addTearDown(s.dispose);
    s.parkItem(name: 'x', amount: const Money.pesos(1));
    await s.deleteEverything();
    expect(s.parkedItems, isEmpty);
  });
}
