import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Liquid cash has to be CONVERTED before it is added up.
///
/// `FinancialState.totalLiquidCash` folded `a.balance.pesos`, the raw stored
/// figure, so a 1,000 dollar payroll account contributed 1,000 to a total
/// labelled pesos instead of 58,500. Every money test in the suite ran on a
/// peso-only fixture, where the raw sum and the converted sum are the same
/// number, so nothing could see it. accounts.dart says this in its own words
/// above `accountsTotalPhp`, and health_check.dart was already doing it
/// correctly; this one getter was the straggler.
///
/// It is not an internal figure. It feeds `PanFacts.liquidCash`, which Pan
/// reads out loud as "You can reach X today", so the defect surfaced as a
/// confident sentence about money the person does not have.
void main() {
  // Both liquid, so both land in the total. The dollar one is the OFW payroll
  // account the currency field was added for in the first place.
  const Account pesoWallet = Account(
    id: 'php_1',
    name: 'My GCash',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: Money.pesos(20000),
    monogram: 'GC',
  );

  const Account dollarPayroll = Account(
    id: 'usd_1',
    name: 'Payroll USD',
    kind: AccountKind.bank,
    institution: 'BPI',
    balance: Money.pesos(1000),
    currency: CurrencyCode.usd,
    monogram: 'BPI',
  );

  // An investment account is NOT liquid, so it must stay out of the total
  // even though it is also foreign. Without this the test would pass just as
  // well on code that converted everything and summed everything.
  const Account dollarInvestment = Account(
    id: 'usd_2',
    name: 'Brokerage',
    kind: AccountKind.investment,
    institution: 'COL',
    balance: Money.pesos(500),
    currency: CurrencyCode.usd,
    monogram: 'INV',
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

  test(
    'a dollar balance is converted before it joins the liquid total',
    () async {
      final FinancialState state = await restoredFrom(
        emptyBut(const <Account>[pesoWallet, dollarPayroll]),
      );

      // 20,000 pesos plus 1,000 dollars at the indicative 58.50, which is
      // 58,500 pesos. The raw fold produced 21,000: twenty thousand pesos and
      // one thousand dollars, added as if they were the same thing.
      expect(
        state.totalLiquidCash,
        closeTo(78500, 0.01),
        reason:
            'the dollar account was added at its face value, so the app is '
            'reporting 21,000 pesos to somebody who holds 78,500',
      );

      // Directional, not just "the total is right". 78,500 differs from the
      // peso-only 20,000 as well as from the broken 21,000, so neither a
      // dropped account nor a raw fold can satisfy this line.
      expect(state.totalLiquidCash, greaterThan(pesoWallet.balance.pesos));
    },
  );

  test('conversion does not drag in accounts that are not liquid', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[pesoWallet, dollarPayroll, dollarInvestment]),
    );

    // Unchanged by the brokerage account. A fix that converted correctly but
    // forgot the isLiquid filter would read 107,750 here and pass the test
    // above untouched.
    expect(
      state.totalLiquidCash,
      closeTo(78500, 0.01),
      reason: 'an investment account is not money you can reach today',
    );
  });

  test('Pan says the converted figure out loud', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[pesoWallet, dollarPayroll]),
    );

    // The half that a unit test on the getter cannot see: the number has to
    // survive the trip into PanFacts and out of the sentence a person reads.
    expect(state.panFacts.liquidCash, closeTo(78500, 0.01));

    final PanAnswer answer = askPan('how much do i have', state.panFacts);
    expect(answer.topic, 'cash');
    expect(
      answer.text,
      contains('78,500'),
      reason:
          'Pan tells the user what they can reach today, so a raw sum is not '
          'an internal rounding detail, it is a wrong sentence about money',
    );
  });
}
