import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Safe to Spend must be built from the USER's obligations, never the seed's.
///
/// The defect this file exists for was measured, not theorised. A brand new
/// user holding one real ₱50,000 account saw a Safe to Spend of ₱0.00, because
/// the engine was handed `SeedData.bills` and `SeedData.installments`
/// directly: ₱41,184 of demo bills (times the conservative 1.1 multiplier) and
/// ₱6,348 of demo plans were reserved against obligations they had never
/// entered. Worse than wrong, it was unaccountable, because no screen in the
/// app lists those bills. The Plan tab reads a different collection.
void main() {
  const Account onlyRealMoney = Account(
    id: 'real_1',
    name: 'My GCash',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: 50000,
    monogram: 'GC',
  );

  Snapshot emptyBut(List<Account> accounts) => Snapshot(
    accounts: accounts,
    transactions: const <Transaction>[],
    debts: const <Debt>[],
    budgets: const <Budget>[],
    goals: const <Goal>[],
    upcoming: const <UpcomingItem>[],
    incomeStreams: const <IncomeStream>[],
    installments: const <InstallmentPlan>[],
    reconciliations: const <ReconciliationRecord>[],
    bills: const <BillItem>[],
    payday: PaydayCycle.unset,
    theme: ThemeMode2.gabi,
    scenario: DecisionScenario.conservative,
  );

  Future<FinancialState> restoredFrom(Snapshot s) async {
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write(s.encode(at: DateTime.utc(2026, 9, 19)));
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: store,
    );
    await state.restore();
    return state;
  }

  test('a ledger holding only real money reserves nothing invented', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[onlyRealMoney]),
    );

    expect(state.bills, isEmpty, reason: 'demo bills came back from the seed');
    expect(state.installments, isEmpty);

    final SafeToSpendAnalysis a = state.safeToSpendAnalysis;
    expect(a.reservedBills, 0);
    expect(a.reservedInstallments, 0);

    // The whole point. Before the fix this was 0.00 on exactly this fixture.
    expect(
      a.safeToSpendUntilPayday,
      greaterThan(0),
      reason:
          'somebody with ₱50,000 and no obligations is being told they can '
          'spend nothing, because the app reserved money against demo bills '
          'they never entered and cannot find on any screen',
    );

    // 50,000 less the 15% conservative buffer, then the 85% spend split.
    expect(a.totalLiquidCash, 50000);
    expect(a.safeToSpendUntilPayday, closeTo(36125, 1));
  });

  test('a real bill the user entered DOES reserve money', () async {
    // The other half. A rule that reserves nothing is as wrong as one that
    // reserves the seed's, and it would pass the test above perfectly.
    final Snapshot s = emptyBut(const <Account>[onlyRealMoney]);
    final FinancialState state = await restoredFrom(
      Snapshot(
        accounts: s.accounts,
        transactions: s.transactions,
        debts: s.debts,
        budgets: s.budgets,
        goals: s.goals,
        upcoming: s.upcoming,
        incomeStreams: s.incomeStreams,
        installments: s.installments,
        reconciliations: s.reconciliations,
        bills: const <BillItem>[
          BillItem(
            id: 'bill_real',
            name: 'Meralco',
            amount: 3000,
            dueDate: '2026-09-25',
          ),
        ],
        payday: s.payday,
        theme: s.theme,
        scenario: s.scenario,
      ),
    );

    expect(state.bills.single.name, 'Meralco');
    expect(
      state.safeToSpendAnalysis.reservedBills,
      closeTo(3300, 0.01),
      reason: '3,000 times the 1.1 conservative multiplier',
    );
  });

  test('payday is stored, not a constant', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[onlyRealMoney]),
    );
    expect(
      state.payday.daysToPayday,
      0,
      reason:
          'a ledger with no payday set was being told "4 days to payday, '
          'Sep 15", which was true of the seed in September 2026 and of '
          'nothing else, ever',
    );
    expect(state.payday.isSet, isFalse);
    expect(
      state.payday.expectedIncome,
      0,
      reason:
          'the engine falls back to this when no income stream exists, so a '
          'non-zero default invents an income the person never declared',
    );
  });

  test('the seed still has bills, so the fixture did not go empty', () {
    // Guards the guard. If SeedData.bills ever became empty, every assertion
    // above would pass for a reason that has nothing to do with the fix.
    expect(SeedData.bills, isNotEmpty);
    expect(SeedData.installments, isNotEmpty);
    expect(SeedData.payday.daysToPayday, greaterThan(0));
  });

  test('bills and payday survive a save and a reload', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[onlyRealMoney]),
    );
    final String written = state.snapshot().encode(
      at: DateTime.utc(2026, 9, 19),
    );
    final Snapshot back = Snapshot.decode(written);
    expect(back.bills, isEmpty);
    expect(back.payday.daysToPayday, 0);
  });

  test('a key inside payday that we do not model is still kept', () async {
    // payday stopped being a foreign key when this build started modelling it.
    // Anything else inside it is still somebody else's.
    const String raw = '''
{
  "schemaVersion": 1,
  "accounts": [], "transactions": [], "debts": [], "budgets": [],
  "goals": [], "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": [],
  "payday": {"cycleType": "weekly", "payrollProviderId": "prov_7"}
}
''';
    final Snapshot s = Snapshot.decode(raw);
    expect(s.payday.cycleType, 'weekly');

    expect(
      s.encode(at: DateTime.utc(2026, 9, 19)),
      contains('payrollProviderId'),
      reason:
          'a field this build does not model was dropped on the first save, '
          'permanently, on a device with no second copy',
    );
  });
}
