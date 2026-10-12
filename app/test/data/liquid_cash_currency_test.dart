import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/currencies.dart';
import 'package:salapify/core/money/js_round.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/pan/pan_context.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Liquid cash has to be CONVERTED before it is added up, and every surface
/// has to convert it the SAME way.
///
/// `FinancialState.totalLiquidCash` folded `a.balance.pesos`, the raw stored
/// figure, so a 1,000 dollar payroll account contributed 1,000 to a total
/// labelled pesos instead of 58,500. Every money test in the suite ran on a
/// peso-only fixture, where the raw sum and the converted sum are the same
/// number, so nothing could see it.
///
/// Fixing that getter ALONE made things worse before it made them better,
/// and that is the more important half of this file. Pan read the converted
/// total while the Safe to Spend engine still read the raw one, so Pan's own
/// explanation stopped adding up: "Safe to Spend is 15,173, it starts from
/// the 78,500 you can reach and holds back 3,150". Three figures, no two of
/// which agree. The engine stays raw, because it is golden-locked parity
/// with a prototype that has no currency field; the CALLER converts on the
/// way in. So the tests here pin agreement between surfaces, not just the
/// one getter.
void main() {
  // Derived, never typed. The rates are "indicative and fixed" and "stale by
  // construction" in currencies.dart's own words, so the day somebody
  // refreshes the table a hard-coded 78,500 would redden with a reason string
  // blaming a raw fold, which would be a lie. This way the arithmetic under
  // test is the conversion, not the rate.
  final double usdRate = exchangeRatesToPhp[CurrencyCode.usd]!;
  final int expectedCentavos = Money.fromDouble(
    20000 + 1000 * usdRate,
  ).centavos;

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

  // The fixture has to actually contain converted money, or every assertion
  // below is satisfied by a peso-only ledger and proves nothing. Named by
  // figure and by direction, so a fixture that quietly lost its dollar
  // account fails HERE with a clear reason rather than somewhere downstream.
  test('the fixture really holds foreign money', () {
    expect(dollarPayroll.isForeign, isTrue);
    expect(dollarPayroll.balance.centavos, 100000);
    expect(
      dollarPayroll.balanceInPhp.centavos,
      greaterThan(dollarPayroll.balance.centavos),
      reason: 'a dollar is worth more than a peso, so conversion must raise it',
    );
    expect(pesoWallet.isForeign, isFalse);
  });

  test(
    'a dollar balance is converted before it joins the liquid total',
    () async {
      final FinancialState state = await restoredFrom(
        emptyBut(const <Account>[pesoWallet, dollarPayroll]),
      );

      // EXACT, in centavos, not closeTo. A one centavo tolerance is exactly the
      // size of the difference between the two candidate rounding policies
      // (convert each account then sum, against sum then convert), so a
      // tolerant assertion cannot tell the policy this code chose from the one
      // it rejected. The raw fold produced 21,000: twenty thousand pesos and
      // one thousand dollars, added as if they were the same thing.
      expect(
        Money.fromDouble(state.totalLiquidCash).centavos,
        expectedCentavos,
        reason:
            'the dollar account was added at its face value, so the app is '
            'reporting 21,000 pesos to somebody who holds 78,500',
      );

      // Directional. 78,500 differs from the peso-only 20,000 as well as from
      // the broken 21,000, so neither a dropped account nor a raw fold passes.
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
      Money.fromDouble(state.totalLiquidCash).centavos,
      expectedCentavos,
      reason: 'an investment account is not money you can reach today',
    );
  });

  test('Pan says the converted figure out loud', () async {
    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[pesoWallet, dollarPayroll]),
    );

    // The half that a unit test on the getter cannot see: the number has to
    // survive the trip into PanFacts and out of the sentence a person reads.
    expect(
      Money.fromDouble(state.panFacts.liquidCash).centavos,
      expectedCentavos,
    );

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

  // The two rules meet here. P2.3 made this getter count only SPENDABLE
  // accounts, and this change made it CONVERT them; `isSpendable` is a strict
  // subset of `isLiquid`, so the two compose. A merge that kept one side's
  // intent and dropped the other's would still pass everything above, which
  // is exactly why this case exists.
  test('a protected dollar account is set aside AND converted', () async {
    const Account dollarEmergencyFund = Account(
      id: 'usd_3',
      name: 'Emergency fund USD',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: Money.pesos(2000),
      currency: CurrencyCode.usd,
      purpose: AccountPurpose.protected,
      monogram: 'BPI',
    );

    final FinancialState state = await restoredFrom(
      emptyBut(const <Account>[pesoWallet, dollarPayroll, dollarEmergencyFund]),
    );

    // Still 78,500. The 2,000 dollar fund is liquid and foreign, so it would
    // move this number under EITHER rule alone: a raw sum that respected
    // purpose reads 21,000, a converted sum that ignored purpose reads
    // 195,500, and only both rules together read 78,500.
    expect(
      Money.fromDouble(state.totalLiquidCash).centavos,
      expectedCentavos,
      reason:
          'money the person set aside is not money they can reach today, '
          'whatever currency it sits in',
    );
  });

  group('every surface agrees about liquid cash', () {
    // This group is the one that would have caught the regression that the
    // first version of this change shipped. Each test above asks whether ONE
    // number is right; these ask whether the app tells one story.

    test('Pan and the Safe to Spend engine quote the same figure', () async {
      final FinancialState state = await restoredFrom(
        emptyBut(const <Account>[pesoWallet, dollarPayroll]),
      );

      final SafeToSpendAnalysis a = state.safeToSpendAnalysis;

      expect(
        a.totalLiquidCash.centavos,
        Money.fromDouble(state.panFacts.liquidCash).centavos,
        reason:
            'Pan says "you can reach X today" and the Safe to Spend sheet '
            'shows step 1 as "add up liquid cash". Two screens, one tap '
            'apart, the same words. They cannot answer with two numbers.',
      );

      // Directional companion. Equality alone is satisfied by two RAW folds,
      // which is exactly the state this file exists to prevent returning to,
      // so pin the shared value to the CONVERTED figure.
      expect(a.totalLiquidCash.centavos, expectedCentavos);
    });

    test('Pan\'s Safe to Spend sentence adds up', () async {
      final FinancialState state = await restoredFrom(
        emptyBut(const <Account>[pesoWallet, dollarPayroll]),
      );
      final PanFacts f = state.panFacts;

      // The sentence is an explicit audit trail: "it starts from X and holds
      // back Y", so a reader can and will do the subtraction. These are the
      // engine's own steps 1, 7 and 8 restated, and they have to close.
      final double uncommitted = f.liquidCash - f.amountReserved;
      expect(
        jsRound(uncommitted * 0.85),
        f.safeToSpendUntilPayday.round(),
        reason:
            'Pan states a derivation between three figures it shows the '
            'user. If they are not derived from each other the sentence is '
            'false in a way anybody with a calculator can see.',
      );

      // Directional. A ledger reserving nothing satisfies the line above too
      // easily, and a peso-only one never exercises the conversion at all.
      expect(f.amountReserved, greaterThan(0));
      expect(Money.fromDouble(f.liquidCash).centavos, expectedCentavos);
    });
  });

  // Guards the trap documented in `accountsInPhp` and in safe_to_spend.dart.
  // The converted accounts the caller builds keep their ORIGINAL currency
  // code, because copyWith carries it through, so any conversion inside the
  // engine would be a second one and would silently multiply a dollar
  // balance by 58.50 twice.
  test('the Safe to Spend engine never reads a currency field', () {
    final File engine = File('lib/core/money/safe_to_spend.dart');
    expect(engine.existsSync(), isTrue, reason: 'ran from the wrong directory');

    // Comments discuss currency at length, deliberately. Strip them first, or
    // this guard fires on its own explanation.
    final String code = engine
        .readAsLinesSync()
        .where((String l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    for (final String banned in <String>[
      'currency',
      'balanceInPhp',
      'isForeign',
    ]) {
      expect(
        RegExp('\\b$banned\\b').hasMatch(code),
        isFalse,
        reason:
            'safe_to_spend.dart is handed balances that are ALREADY pesos by '
            'FinancialState, so reading "$banned" here would convert a '
            'second time. Convert in the caller, never in this engine.',
      );
    }
  });
}
