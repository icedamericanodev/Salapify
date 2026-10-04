import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/financial_truth.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/core/money/safe_to_spend.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// P2.3, protected accounts.
///
/// `isLiquid` was doing three unrelated jobs, and the app decided whether
/// money was spendable purely from the KIND of account it sat in. For this
/// audience that is wrong often enough to matter: an emergency fund in GSave,
/// Maya Savings, SeaBank or Tonik is a `gcash`, `maya` or `bank` account, so
/// somebody's ipon was counted as this fortnight's pocket money and Safe to
/// Spend told them they could spend it.
///
/// The fix is a second predicate, `isSpendable`, asked only by the three
/// things that mean "should this fund today". Everything that stays on
/// `isLiquid` provably cannot change, which is the point of splitting rather
/// than redefining.
///
/// The golden vectors for the engine live in safe_to_spend_golden_test.dart
/// and were generated from the prototype's TypeScript. This file holds the
/// behaviour the prototype cannot express.
void main() {
  const Account wallet = Account(
    id: 'a_wallet',
    name: 'GCash Wallet',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: Money.pesos(5000),
    monogram: 'GC',
  );

  const Account ipon = Account(
    id: 'a_ipon',
    name: 'GSave',
    kind: AccountKind.gcash,
    institution: 'GCash',
    balance: Money.pesos(50000),
    monogram: 'GS',
    purpose: AccountPurpose.protected,
  );

  const Account card = Account(
    id: 'a_card',
    name: 'BPI Card',
    kind: AccountKind.credit,
    institution: 'BPI',
    balance: Money.pesos(3000),
    monogram: 'BP',
  );

  group('the predicate split', () {
    test('protected money is still liquid, and no longer spendable', () {
      // Both halves in one assertion, because the whole design rests on
      // these two answers being allowed to differ.
      expect(ipon.isLiquid, isTrue, reason: 'money can still leave it');
      expect(ipon.isSpendable, isFalse, reason: 'but it must not fund today');
    });

    test('an ordinary account answers yes to both', () {
      expect(wallet.isLiquid, isTrue);
      expect(wallet.isSpendable, isTrue);
    });

    test('a credit card answers no to both, whatever its purpose says', () {
      // Belt and braces: the sheet refuses to show the control for a card,
      // but a hand-edited backup could still carry the key.
      const Account weird = Account(
        id: 'a_weird',
        name: 'Hand edited',
        kind: AccountKind.credit,
        institution: 'BPI',
        balance: Money.pesos(3000),
        monogram: 'HE',
        purpose: AccountPurpose.protected,
      );
      expect(weird.isLiquid, isFalse);
      expect(weird.isSpendable, isFalse);
    });

    test('the default is spendable, so nothing changes by itself', () {
      expect(wallet.purpose, AccountPurpose.spendable);
    });
  });

  group('copyWith carries the flag, which the ledger depends on', () {
    test('a balance change does NOT quietly un-protect an account', () {
      // THE TRAP. `copyWith(balance:)` is the copy the ledger makes every
      // time money moves, so if `purpose` were left off the list, logging
      // one expense from a protected account would silently un-protect it
      // and the person's Safe to Spend would jump back up with nothing on
      // any screen to explain why.
      final Account afterSpending = ipon.copyWith(balance: Money.pesos(49000));
      expect(afterSpending.purpose, AccountPurpose.protected);
      expect(afterSpending.isSpendable, isFalse);
    });

    test('and it can still be changed deliberately', () {
      expect(
        ipon.copyWith(purpose: AccountPurpose.spendable).isSpendable,
        isTrue,
      );
    });
  });

  group('the engine asks the right question in each place', () {
    SafeToSpendAnalysis run(List<Account> accounts) => computeSafeToSpend(
      accounts: accounts,
      transactions: const <Transaction>[],
      bills: const <BillItem>[],
      debtsIOwe: 0,
      installments: const <InstallmentPlan>[],
      incomeStreams: const <IncomeStream>[],
      payday: PaydayCycle.unset,
      scenario: DecisionScenario.conservative,
      now: DateTime.utc(2026, 10, 4),
    );

    test('the headline drops by the protected amount, and the buffer with '
        'it', () {
      final SafeToSpendAnalysis both = run(<Account>[
        wallet,
        ipon.copyWith(purpose: AccountPurpose.spendable),
      ]);
      final SafeToSpendAnalysis set = run(<Account>[wallet, ipon]);

      // DIRECTIONAL, not merely different. 55,000 spendable against 5,000.
      expect(both.safeToSpendUntilPayday, Money.pesos(39738));
      expect(set.safeToSpendUntilPayday, Money.pesos(3613));

      // The buffer is a slice of spendable cash, not of everything, or an
      // untouched emergency fund would be reserved twice: once by being set
      // aside and once by being buffered against itself.
      expect(both.emergencyBuffer, Money.pesos(8250));
      expect(set.emergencyBuffer, Money.pesos(750));
    });

    test('the runway does NOT drop, which is the hard half', () {
      final SafeToSpendAnalysis both = run(<Account>[
        wallet,
        ipon.copyWith(purpose: AccountPurpose.spendable),
      ]);
      final SafeToSpendAnalysis set = run(<Account>[wallet, ipon]);

      expect(
        set.cashRunwayDays,
        both.cashRunwayDays,
        reason:
            'the runway asks how long you last if income stops, and the '
            'emergency fund is exactly the money that answers it; excluding '
            'it would punish somebody for saving',
      );
      expect(set.totalLiquidCash, Money.pesos(55000));
    });

    test('and it reports how much was held back', () {
      expect(run(<Account>[wallet, ipon]).protectedCash, Money.pesos(50000));
      expect(run(<Account>[wallet]).protectedCash, Money.zero);
    });
  });

  test('the payday indicator stops counting the emergency fund', () {
    // "Will I make it to payday" means "without raiding my ipon". Somebody
    // who only scrapes through by spending their emergency fund has not made
    // it to payday, and an indicator that says otherwise is why the fund
    // gets spent.
    // The indicator refuses to guess a spending pace, so it needs five
    // separate days logged before it will answer at all.
    //
    // 3,000 on each of six days is 18,000 over the window, so a pace of 600
    // a day and 6,000 needed to reach payday. That is deliberately more than
    // the 5,000 spendable and far less than the 55,000 total, which is the
    // only arrangement where this test can tell the two apart. A gentler
    // pace passed both ways and proved nothing.
    final List<Transaction> pace = <Transaction>[
      for (int d = 1; d <= 6; d++)
        Transaction(
          id: 't$d',
          type: TransactionType.expense,
          amount: Money.pesos(3000),
          category: 'Food',
          accountId: wallet.id,
          date: '2026-09-${(20 + d).toString().padLeft(2, '0')}',
          createdAt: DateTime.utc(2026, 9, 20 + d).millisecondsSinceEpoch,
        ),
    ];

    HealthReport report(List<Account> accounts) => runHealthCheck(
      transactions: pace,
      accounts: accounts,
      budgets: const <Budget>[],
      goals: const <Goal>[],
      bills: const <BillItem>[],
      installments: const <InstallmentPlan>[],
      payday: const PaydayCycle(
        cycleType: '15_30',
        lastPayday: '2026-09-30',
        nextPayday: '2026-10-14',
        daysToPayday: 10,
        expectedIncome: Money.pesos(20000),
      ),
      now: DateTime.utc(2026, 10, 4),
    );

    final HealthIndicator open = report(<Account>[
      wallet,
      ipon.copyWith(purpose: AccountPurpose.spendable),
    ]).indicators.first;
    final HealthIndicator set = report(<Account>[
      wallet,
      ipon,
    ]).indicators.first;

    expect(open.tone, HealthTone.good);
    expect(
      set.tone,
      isNot(HealthTone.good),
      reason:
          'with only 5,000 genuinely spendable and ten days to go, this '
          'person is not comfortable, they are one bill from their ipon',
    );
  });

  test('the cash shortfall alarm sees past the emergency fund', () {
    // The loudest alarm in the app, and the one place the fix could have
    // been missed entirely: financial_truth.dart does not call isLiquid, it
    // types the kinds out again.
    List<ControlCenterAlert> alerts(List<Account> accounts) =>
        runControlCenterScan(
          accounts: accounts,
          transactions: const <Transaction>[],
          debts: const <Debt>[],
          budgets: const <Budget>[],
        );

    const Account nearlyEmpty = Account(
      id: 'a_thin',
      name: 'Pitaka',
      kind: AccountKind.cash,
      institution: 'Cash',
      balance: Money.pesos(400),
      monogram: 'PK',
    );

    bool shortfall(List<Account> a) =>
        alerts(a).any((ControlCenterAlert x) => x.id == 'alert_cash_shortfall');

    expect(
      shortfall(<Account>[
        nearlyEmpty,
        ipon.copyWith(purpose: AccountPurpose.spendable),
      ]),
      isFalse,
      reason: '50,400 of spendable cash is not a shortfall',
    );
    expect(
      shortfall(<Account>[nearlyEmpty, ipon]),
      isTrue,
      reason:
          'somebody with 400 to their name and an untouched emergency fund '
          'is in trouble this week, and the app could not see it',
    );
  });

  test('net worth and cash equivalents do NOT move', () {
    // The reassurance the UI gives has to be true. Both of these key off
    // assetKinds rather than isLiquid, so this is a guard against somebody
    // later "simplifying" them onto the new predicate.
    FinancialPosition position(List<Account> a) => computePosition(a, null);

    final FinancialPosition open = position(<Account>[
      wallet,
      ipon.copyWith(purpose: AccountPurpose.spendable),
      card,
    ]);
    final FinancialPosition set = position(<Account>[wallet, ipon, card]);

    expect(set.netWorth, open.netWorth);
    expect(set.totalAssets, open.totalAssets);
    expect(
      set.cashEquivalents,
      open.cashEquivalents,
      reason:
          'on a balance sheet GSave is a cash equivalent whatever you intend '
          'to do with it',
    );
  });

  group('the stored shape', () {
    test('protected survives a round trip', () {
      final Account back = accountFromJson(accountToJson(ipon));
      expect(back.purpose, AccountPurpose.protected);
    });

    test('an absent key reads as spendable', () {
      final Map<String, dynamic> m = accountToJson(wallet);
      expect(
        m.containsKey('purpose'),
        isFalse,
        reason:
            'written only when protected, so a file from a ledger nobody has '
            'touched is byte for byte what it was before P2.3',
      );
      expect(accountFromJson(m).purpose, AccountPurpose.spendable);
    });

    test('an unknown value is refused, never guessed', () {
      final Map<String, dynamic> m = accountToJson(ipon);
      m['purpose'] = 'someday_maybe';
      expect(
        () => accountFromJson(m),
        throwsA(anything),
        reason:
            'a future third purpose read as "spend this" would hand somebody '
            'their emergency fund back as pocket money',
      );
    });

    test('purpose is declared, so the sidecar does not claim it', () {
      // accountKeys is what tells the unknown-key sidecar which keys this
      // build understands. A field written but not declared would be stored
      // twice and could come back stale.
      expect(accountKeys, contains('purpose'));
    });
  });
}
