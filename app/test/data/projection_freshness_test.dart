import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/daily_projection.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/state/financial_state.dart';

/// The runway's projection is MEMOISED, and the memo has to notice everything
/// the projection reads.
///
/// `dailyProjection` hashes a stamp of the inputs and returns the cached
/// object when the stamp is unchanged. The stamp counted `_upcoming.length`
/// and nothing else about those items, while `projectDailyCash` filters them
/// on `isPaid`. So ticking a scheduled item off changed what the projection
/// SHOULD say and nothing the stamp could see.
///
/// The docstring on the memo claimed "a stamp that misses a change costs a
/// stale card for one frame". That was false: the key is not time based, so a
/// missed change is stale until something unrelated moves or the calendar day
/// rolls over.
///
/// This matters more since the runway CHART was added, because the same stale
/// object is now drawn as forty five days of shape, not just summarised in a
/// sentence.
void main() {
  const String ledger = '''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 5000, "monogram": "GC"}
  ],
  "transactions": [],
  "upcoming": [
    {"id": "u_pay", "name": "Salary", "amount": 32500,
     "dueDate": "2026-09-30", "type": "payday", "isIncome": true,
     "isPaid": false}
  ],
  "debts": [], "budgets": [], "goals": [],
  "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''';

  Future<FinancialState> loaded() async {
    final MemorySnapshotStore store = MemorySnapshotStore(ledger);
    final FinancialState s = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
      store: store,
    );
    await s.restore();
    addTearDown(s.dispose);
    return s;
  }

  test('ticking an income row off refreshes the projection', () async {
    final FinancialState s = await loaded();

    final DailyProjection before = s.dailyProjection;
    final Money closingBefore = before.closingBalance;

    // DIRECTIONAL FIRST. The payday has to be IN the projection, or the
    // assertion below passes on a projection that never had it.
    expect(
      closingBefore.pesos,
      closeTo(37500, 0.0001),
      reason: '5,000 now plus a 32,500 payday still to arrive',
    );

    // The income path moves NO money on purpose: it is somebody confirming
    // their sweldo landed, and the balance already reflects it. So every
    // other term in the memo stamp is unchanged, which is exactly what made
    // this stale.
    s.markUpcomingPaid('u_pay');

    final DailyProjection after = s.dailyProjection;
    expect(
      after.closingBalance.pesos,
      closeTo(5000, 0.0001),
      reason:
          'the payday is marked arrived, so projecting it again counts the '
          'same 32,500 twice and tells the person they are richer than they '
          'are, which is the direction this card must never err in',
    );
    expect(
      identical(before, after),
      isFalse,
      reason: 'the memo handed back the object it built before the tick',
    );
  });

  test('nothing changing does still reuse the cache', () async {
    // The other half. A stamp that changes on every read is not a cache, and
    // "always refresh" would pass the test above while rebuilding forty five
    // days on every rebuild of Home.
    final FinancialState s = await loaded();
    expect(identical(s.dailyProjection, s.dailyProjection), isTrue);
  });
}
