import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/financial_truth.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// The Control Centre scan has to convert before it adds up, and has to say
/// which currency a single balance is in.
///
/// This engine was the LAST raw-currency fold in app/. Three others were
/// fixed first and this one survived because it does not call `isLiquid`,
/// it types the four account kinds out again, so a search for the usual
/// shape walked straight past it.
///
/// It is also the loudest thing the app can say. The cash shortfall alert
/// is a warning that somebody is nearly out of money, and the debt pressure
/// figure is a percentage of the same total. Both were wrong by the
/// exchange rate for anybody holding a foreign account.
///
/// Peso-only fixtures cannot see any of it, which is why every golden
/// vector stayed green through the defect and stays green through the fix.
void main() {
  // 1,000 dollars is 58,500 pesos at the indicative rate. The difference
  // between those two numbers is the whole of this file: one is comfortably
  // above the 5,000 buffer and the other is far below it.
  const Account dollarPayroll = Account(
    id: 'usd_1',
    name: 'Payroll USD',
    kind: AccountKind.bank,
    institution: 'BPI',
    balance: Money.pesos(1000),
    currency: CurrencyCode.usd,
    monogram: 'BPI',
  );

  List<ControlCenterAlert> scan(List<Account> accounts, {List<Debt>? debts}) =>
      runControlCenterScan(
        transactions: const <Transaction>[],
        accounts: accounts,
        debts: debts ?? const <Debt>[],
        budgets: const <Budget>[],
      );

  test('the fixture really holds foreign money', () {
    // Directional companion for everything below. Without it a fixture that
    // quietly lost its currency would satisfy the assertions by accident.
    expect(dollarPayroll.isForeign, isTrue);
    expect(dollarPayroll.balance.centavos, 100000);
    expect(dollarPayroll.balanceInPhp.centavos, 5850000);
  });

  test('a dollar payroll account does NOT trip the cash shortfall alarm', () {
    final Iterable<ControlCenterAlert> shortfall = scan(<Account>[
      dollarPayroll,
    ]).where((ControlCenterAlert a) => a.type == AlertType.cashShortfall);

    expect(
      shortfall,
      isEmpty,
      reason:
          'somebody holding 58,500 pesos worth of dollars was told their '
          'liquid reserves are down to 1,000 and below the working buffer, '
          'which is the loudest alarm this app has, fired on nothing',
    );
  });

  test('the alarm still fires when the money really is gone', () {
    // The other half, and the one that matters more. An alarm that cannot
    // fire is worse than one that fires wrongly, because nobody notices it
    // is missing. 50 dollars is 2,925 pesos, genuinely under the buffer.
    const Account nearlyEmpty = Account(
      id: 'usd_2',
      name: 'Payroll USD',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: Money.pesos(50),
      currency: CurrencyCode.usd,
      monogram: 'BPI',
    );

    final Iterable<ControlCenterAlert> shortfall = scan(<Account>[
      nearlyEmpty,
    ]).where((ControlCenterAlert a) => a.type == AlertType.cashShortfall);

    expect(shortfall.length, 1);
    expect(
      shortfall.first.amount,
      closeTo(2925, 0.01),
      reason: 'the alert quotes the converted figure, not the raw 50',
    );
  });

  test('debt pressure is a percentage of the CONVERTED reserves', () {
    // 20,000 owed against 58,500 of reserves is 34 percent, which is under
    // the 80 percent threshold and raises nothing. Read raw it is 20,000
    // against 1,000, which is 2,000 percent and a critical alert.
    final Iterable<ControlCenterAlert> pressure = scan(
      <Account>[dollarPayroll],
      debts: <Debt>[
        const Debt(
          id: 'd1',
          person: 'BPI',
          direction: DebtDirection.iOwe,
          totalAmount: Money.pesos(20000),
          paidAmount: Money.zero,
          isSettled: false,
        ),
      ],
    ).where((ControlCenterAlert a) => a.type == AlertType.debtPaymentRisk);

    expect(
      pressure,
      isEmpty,
      reason:
          'the denominator was the raw dollar figure, so the percentage was '
          'overstated by the exchange rate and a comfortable position read '
          'as a critical one',
    );
  });

  test('a negative foreign balance is named in its OWN currency', () {
    const Account overdrawn = Account(
      id: 'usd_3',
      name: 'Payroll USD',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: Money.pesos(-200),
      currency: CurrencyCode.usd,
      monogram: 'BPI',
    );

    final ControlCenterAlert alert = scan(
      <Account>[overdrawn],
    ).firstWhere((ControlCenterAlert a) => a.type == AlertType.balanceMismatch);

    // The description is what somebody reconciling reads against their
    // bank's own statement, so it has to be the figure that bank shows.
    expect(
      alert.description,
      contains(r'-$200.00'),
      reason:
          'the peso sign was hardcoded, so a dollar overdraft was announced '
          'as a peso one and the number matched no statement anywhere',
    );
    expect(alert.description, isNot(contains('₱-200')));

    // `amount` is the opposite case: nothing reads it as a currency and
    // every other alert here puts a peso figure in it, so it converts.
    expect(alert.amount, closeTo(11700, 0.01));
  });
}
