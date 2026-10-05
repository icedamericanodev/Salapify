import 'package:salapify/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/accounts.dart';
import 'package:salapify/core/money/financial_truth.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/models/models.dart';

/// ONE card, put in front of every part of the app that reads its sign.
///
/// ## Why this file exists
///
/// A credit, loan or mortgage balance is stored POSITIVE when money is owed.
/// That convention was never written down in one place, and so two separate
/// engines were written against the opposite of it, each with a confident
/// comment, each with a test that agreed with it:
///
///   - `pan_health.dart`, now deleted, summed only the NEGATIVE side of card
///     balances. On the sample BPI card, 4,200 owed against a 40,000 limit, it
///     computed 0 percent and awarded a perfect score with the words "0% of
///     the limits you have entered". It reported zero utilisation on every
///     card that actually carried debt, and could only fire on a card in
///     credit, which by definition owes nothing.
///   - `_oneAccount` in `pan_engine.dart` read `balance < 0` as owing, so it
///     told somebody their card HELD the 4,200 they owed on it, and then
///     explained the wrong convention back to them as fact.
///
/// Neither was caught by a unit test, because every test that touched the sign
/// was written from the same wrong mental model. `pan_test.dart` put -18,400
/// on a card, `financial_truth_golden_test.dart` carried the reason string "a
/// credit card is SUPPOSED to be negative", and `pan_test.dart`'s own fixture
/// helper set the KIND from the sign, so a credit account in it could never be
/// positive. All green, all wrong together.
///
/// The defect lives in the gap between two readers, so the guard has to be a
/// single account read by all of them at once. That is this file, and it is
/// the same lesson the journeys file already carries: a defect that is correct
/// where it was written and wrong where it is read has nowhere else to be
/// caught.
void main() {
  // The sample card, exactly: 4,200 owed against a 40,000 limit.
  const Account card = Account(
    id: 'acc_bpi_cc',
    name: 'BPI Rewards Card',
    kind: AccountKind.credit,
    institution: 'BPI',
    balance: Money.pesos(4200),
    creditLimit: Money.pesos(40000),
    monogram: 'BPI',
  );

  const Account savings = Account(
    id: 'acc_savings',
    name: 'Everyday Savings',
    kind: AccountKind.bank,
    institution: 'BPI',
    balance: Money.pesos(23400),
    monogram: 'ES',
  );

  group('a positive balance on a card is money OWED', () {
    test('utilisation divides it straight through, no sign flip', () {
      // 4,200 of 40,000 is 10.5, which rounds to 11. A reader that treated
      // the positive balance as money held would return 0 here, which is the
      // most flattering possible wrong answer.
      expect(creditUtilization(card), 11);
      expect(isHighUtilization(card), isFalse);
    });

    test('net worth SUBTRACTS it', () {
      // The definition of the convention, in the one place that settles it:
      // assets minus a plain sum of the liability balances.
      final FinancialPosition p = computePosition(<Account>[
        savings,
        card,
      ], null);
      expect(p.totalAssets, const Money.pesos(23400));
      expect(p.totalLiabilities, const Money.pesos(4200));
      expect(p.netWorth, const Money.pesos(19200));
    });

    test('and it is not flagged as a negative balance, because it is not', () {
      final List<ControlCenterAlert> alerts =
          runControlCenterScan(
                accounts: <Account>[savings, card],
                transactions: const <Transaction>[],
                debts: const <Debt>[],
                budgets: const <Budget>[],
              )
              .where(
                (ControlCenterAlert a) => a.type == AlertType.balanceMismatch,
              )
              .toList();
      expect(alerts, isEmpty);
    });
  });

  group('and the three readers cannot drift apart again', () {
    test('every reader agrees this card is a liability carrying 4,200', () {
      // The cross-check, and the whole point of the file. Each assertion
      // below is already true somewhere else; what has never existed is all
      // of them against ONE account, which is the only shape that catches a
      // reader whose sign disagrees with its neighbours.
      expect(
        liabilityKinds.contains(card.kind),
        isTrue,
        reason: 'a credit account is a liability',
      );
      expect(
        card.balance > Money.pesos(0),
        isTrue,
        reason: 'and owing money on it is a POSITIVE balance',
      );
      expect(
        creditUtilization(card)! > 0,
        isTrue,
        reason:
            'so a reader that only counts the negative side reports 0% on a '
            'card that genuinely carries debt. That is what pan_health.dart '
            'did for its whole life.',
      );
      expect(
        computePosition(<Account>[card], null).netWorth,
        const Money.pesos(-4200),
        reason: 'and the money owed lowers net worth rather than raising it',
      );
    });

    test('a card in credit is the OTHER direction, and is not owing', () {
      // The second half, so a fix that simply flips every sign cannot pass.
      // An overpayment leaves the card owing you, which is unusual and real,
      // and it must not read as debt.
      const Account overpaid = Account(
        id: 'c2',
        name: 'Overpaid Card',
        kind: AccountKind.credit,
        institution: 'BPI',
        balance: Money.pesos(-1500),
        creditLimit: Money.pesos(40000),
        monogram: 'OC',
      );
      expect(
        computePosition(<Account>[overpaid], null).netWorth,
        const Money.pesos(1500),
      );
      expect(creditUtilization(overpaid)! < 0, isTrue);
    });
  });
}
