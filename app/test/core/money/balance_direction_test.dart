// Which way does money move, for every kind of account and every leg.
//
// WHY THIS FILE EXISTS. `applyToBalances` decided the direction from the
// TRANSACTION TYPE alone and never looked at what kind of account it was
// touching. For a bank account that is right. For a credit card, where the
// stored balance is what you OWE, subtracting made the debt smaller, so
// spending 1,000 on a card raised net worth from 19,200 to 20,200 and
// dropped the card from 4,200 to 3,200. Wrong by twice the amount, every
// time, and reachable from the receipt scanner's own "Paid from" picker.
//
// WHY NO TEST CAUGHT IT. Two reasons, and the second is the instructive one.
// Four journey files define net worth as a flat fold over every balance,
// which ADDS liabilities instead of subtracting them, so a card balance
// falling looks exactly like an asset falling. And `ledger_golden_test.dart`
// has a case literally named "a payment onto a card" which has been green
// over this bug the whole time, because it round trips apply against reverse:
// both were wrong identically, so the signs cancelled. A mirror test cannot
// prove either side is right, only that they agree, and that limitation is
// restated on the round trip group at the bottom of this file.
//
// THE SHAPE THAT FIXES IT. Every cell is written out as a literal, so a wrong
// answer has to be typed on purpose, and the table is asserted EXHAUSTIVE
// over every enum it touches, so a new AccountKind or a new TransactionType
// reddens the build instead of being silently skipped. That is the pattern
// `palette_contrast_test.dart` uses over the theme registry.
//
// THE LEG IS PART OF THE KEY, and the first version of this file got that
// wrong in a way worth recording. It hardcoded two of the three transaction
// types into its own exhaustiveness loop, so `transfer` had no row at all.
// The transfer destination was also the one path that reached past
// `signedDelta` to an inlined helper. The untested path and the path that
// bypassed the single source of truth were the same path, which is how that
// combination usually goes.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/models/models.dart';

/// The one amount every case uses. Round, so a wrong cell is obvious.
const Money kAmount = Money.pesos(1000);
const Money kUp = kAmount;
const Money kDown = Money.pesos(-1000);

/// Every leg that actually exists. An expense and an income have one side;
/// only a transfer has a receiving end.
const List<(TransactionType, TxLeg)> kLegs = <(TransactionType, TxLeg)>[
  (TransactionType.expense, TxLeg.source),
  (TransactionType.income, TxLeg.source),
  (TransactionType.transfer, TxLeg.source),
  (TransactionType.transfer, TxLeg.destination),
];

/// What each leg does to the TOUCHED ACCOUNT'S OWN stored balance.
///
/// Read the liability column against the asset column: it is the exact
/// opposite in every row, because owing more is not having less of something.
/// That single flip is the entire defect this file was written for.
const Map<(TransactionType, TxLeg), Map<AccountKind, Money>> kBalanceDelta =
    <(TransactionType, TxLeg), Map<AccountKind, Money>>{
      (TransactionType.expense, TxLeg.source): <AccountKind, Money>{
        AccountKind.cash: kDown,
        AccountKind.bank: kDown,
        AccountKind.gcash: kDown,
        AccountKind.maya: kDown,
        AccountKind.debit: kDown,
        AccountKind.investment: kDown,
        AccountKind.receivable: kDown,
        // THE THREE THAT WERE WRONG. Charging a card does not spend money you
        // have, it creates money you owe, so the stored figure goes UP.
        AccountKind.credit: kUp,
        AccountKind.loan: kUp,
        AccountKind.mortgage: kUp,
      },
      (TransactionType.income, TxLeg.source): <AccountKind, Money>{
        AccountKind.cash: kUp,
        AccountKind.bank: kUp,
        AccountKind.gcash: kUp,
        AccountKind.maya: kUp,
        AccountKind.debit: kUp,
        AccountKind.investment: kUp,
        AccountKind.receivable: kUp,
        // A REFUND OR A CASHBACK, and the naming matters more than the
        // number here. A one-sided entry arriving at a card can only be money
        // from outside that reduced the debt: a refund, a chargeback, a
        // waived fee. PAYING a card is NOT this. A payment has two legs, cash
        // falls and the card falls, and net worth does not move. Recorded as
        // income on the card it would have one leg and would raise net worth
        // out of nothing, so a card payment must always be a transfer.
        AccountKind.credit: kDown,
        AccountKind.loan: kDown,
        AccountKind.mortgage: kDown,
      },
      (TransactionType.transfer, TxLeg.source): <AccountKind, Money>{
        AccountKind.cash: kDown,
        AccountKind.bank: kDown,
        AccountKind.gcash: kDown,
        AccountKind.maya: kDown,
        AccountKind.debit: kDown,
        AccountKind.investment: kDown,
        AccountKind.receivable: kDown,
        // Money leaving a debt is a cash advance or a loan disbursing, so
        // what you owe rises.
        AccountKind.credit: kUp,
        AccountKind.loan: kUp,
        AccountKind.mortgage: kUp,
      },
      (TransactionType.transfer, TxLeg.destination): <AccountKind, Money>{
        AccountKind.cash: kUp,
        AccountKind.bank: kUp,
        AccountKind.gcash: kUp,
        AccountKind.maya: kUp,
        AccountKind.debit: kUp,
        AccountKind.investment: kUp,
        AccountKind.receivable: kUp,
        // THE CARD PAYMENT. This is the only correct way to pay a card down,
        // and no screen can currently produce it: Move Money filters both
        // ends to asset kinds. The engine is right and the door is shut.
        AccountKind.credit: kDown,
        AccountKind.loan: kDown,
        AccountKind.mortgage: kDown,
      },
    };

/// What each TYPE does to net worth, whatever it touched.
///
/// This column is kind-blind on purpose and it is the reason asserting net
/// worth ALONE would still have missed the defect: spending 1,000 lowers what
/// you are worth by 1,000 whether you paid with cash or with credit. What
/// differed was only which side of the sheet moved.
const Map<TransactionType, Money> kNetWorthDelta = <TransactionType, Money>{
  TransactionType.expense: kDown,
  TransactionType.income: kUp,
  TransactionType.transfer: Money.zero,
};

Account _account(String id, AccountKind kind, Money balance) => Account(
  id: id,
  name: 'Test $id',
  kind: kind,
  institution: 'Test',
  balance: balance,
  monogram: 'TT',
);

Transaction _entry({
  required String accountId,
  required TransactionType type,
  String? toAccountId,
}) => Transaction(
  id: 'tx',
  accountId: accountId,
  toAccountId: toAccountId,
  type: type,
  amount: kAmount,
  category: 'Test',
  merchant: 'Test',
  date: '2026-09-18',
  createdAt: DateTime.utc(2026, 9, 18).millisecondsSinceEpoch,
);

Money _netWorth(List<Account> accounts) {
  final FinancialPosition p = computePosition(accounts, null);
  // Through Money so the comparison is in centavos. `FinancialPosition` still
  // carries doubles, which is a known prerequisite for the balance control
  // that comes later; for these round thousand-peso fixtures the conversion
  // is exact, and this line is where that stops being true if the figures
  // ever gain centavos.
  return Money.fromDouble(p.netWorth);
}

/// 4,200 rather than zero, everywhere. A liability at zero cannot show a sign
/// error that drives it negative, and zero is the one starting balance where
/// up and down are hardest to tell apart.
const Money kStart = Money.pesos(4200);

void main() {
  group('one sided entries, every kind', () {
    for (final (TransactionType, TxLeg) leg in kLegs) {
      if (leg.$1 == TransactionType.transfer) continue;
      for (final MapEntry<AccountKind, Money> cell
          in kBalanceDelta[leg]!.entries) {
        test('${leg.$1.name} on ${cell.key.name}', () {
          // A second account so net worth is never zero on both sides of the
          // comparison, which is where a sign error can hide in an empty book.
          final Account other = _account(
            'other',
            AccountKind.bank,
            Money.pesos(23400),
          );
          final Account subject = _account('subject', cell.key, kStart);
          final List<Account> before = <Account>[other, subject];
          final List<Account> after = applyToBalances(
            before,
            _entry(accountId: 'subject', type: leg.$1),
          );

          expect(
            _netWorth(after) - _netWorth(before),
            kNetWorthDelta[leg.$1],
            reason: 'net worth moved the wrong way',
          );
          expect(
            after.firstWhere((Account a) => a.id == 'subject').balance - kStart,
            cell.value,
            reason: 'the account balance moved the wrong way',
          );
        });
      }
    }
  });

  group('a transfer, every pair of kinds', () {
    // ALL HUNDRED COMBINATIONS, including the six that no screen can reach
    // today. The engine is where correctness lives; which pairs a picker
    // offers is a product decision that can change without anybody revisiting
    // the arithmetic, and this is what makes that safe.
    for (final AccountKind fromKind in AccountKind.values) {
      for (final AccountKind toKind in AccountKind.values) {
        test('${fromKind.name} to ${toKind.name}', () {
          final Account from = _account('from', fromKind, kStart);
          final Account to = _account('to', toKind, kStart);
          final List<Account> before = <Account>[from, to];
          final List<Account> after = applyToBalances(
            before,
            _entry(
              accountId: 'from',
              type: TransactionType.transfer,
              toAccountId: 'to',
            ),
          );

          expect(
            _netWorth(after) - _netWorth(before),
            Money.zero,
            reason:
                'moving money between your own accounts created or '
                'destroyed some of it',
          );

          // THE DIRECTIONAL COMPANION, and it is mandatory. The assertion
          // above is a conservation statement, so it passes perfectly when
          // the transfer did nothing at all. These two name the movement per
          // account, which is the only shape inaction cannot satisfy.
          expect(
            after.firstWhere((Account a) => a.id == 'from').balance - kStart,
            kBalanceDelta[(TransactionType.transfer, TxLeg.source)]![fromKind],
            reason: 'the source leg is wrong',
          );
          expect(
            after.firstWhere((Account a) => a.id == 'to').balance - kStart,
            kBalanceDelta[(
              TransactionType.transfer,
              TxLeg.destination,
            )]![toKind],
            reason: 'the destination leg is wrong',
          );
        });
      }
    }
  });

  group('the table covers everything that exists', () {
    test('every transaction type has at least one leg written down', () {
      // THE CLAUSE THAT KEEPS THIS HONEST, and the first version of this file
      // failed it by hardcoding two of the three values into its own loop.
      // A derived set is a rule; a typed set is only a promise.
      for (final TransactionType type in TransactionType.values) {
        expect(
          kLegs.any(((TransactionType, TxLeg) l) => l.$1 == type),
          isTrue,
          reason: 'no leg is written down for ${type.name}',
        );
        expect(
          kNetWorthDelta.containsKey(type),
          isTrue,
          reason: 'no net worth effect is written down for ${type.name}',
        );
      }
    });

    test('every leg names every account kind', () {
      for (final (TransactionType, TxLeg) leg in kLegs) {
        expect(kBalanceDelta.containsKey(leg), isTrue, reason: '$leg');
        for (final AccountKind kind in AccountKind.values) {
          expect(
            kBalanceDelta[leg]!.containsKey(kind),
            isTrue,
            reason:
                'no direction is written down for ${kind.name} on $leg. '
                'Add the cell deliberately rather than letting the '
                'combination go untested',
          );
        }
      }
    });

    test('every kind is an asset or a liability, and never both', () {
      // The table is only meaningful if these two lists partition the enum. A
      // kind in neither is invisible to net worth entirely, which is a
      // quieter version of the same defect.
      for (final AccountKind kind in AccountKind.values) {
        final bool asset = assetKinds.contains(kind);
        final bool liability = liabilityKinds.contains(kind);
        expect(
          asset || liability,
          isTrue,
          reason:
              '${kind.name} is in neither assetKinds nor liabilityKinds, '
              'so it contributes nothing to net worth',
        );
        expect(asset && liability, isFalse, reason: '${kind.name} is in both');
      }
    });
  });

  group('applying and reversing returns every balance exactly', () {
    // WHAT THIS CAN AND CANNOT PROVE, stated because getting it wrong is what
    // let the defect survive. It proves apply and reverse AGREE. It cannot
    // prove either is right, because the signs cancel: both were wrong about
    // liabilities in exactly the same way and every round trip balanced. The
    // tables above are what prove correctness; this proves the two halves did
    // not drift apart, which matters because reverse runs on a take-back, an
    // edit, and on marking an entry excluded.
    for (final TransactionType type in TransactionType.values) {
      for (final AccountKind kind in AccountKind.values) {
        test('${type.name} on ${kind.name} round trips', () {
          final Account subject = _account('subject', kind, kStart);
          final Account dest = _account('dest', AccountKind.gcash, kStart);
          final List<Account> before = <Account>[subject, dest];
          final Transaction tx = _entry(
            accountId: 'subject',
            type: type,
            toAccountId: type == TransactionType.transfer ? 'dest' : null,
          );
          final List<Account> back = reverseFromBalances(
            applyToBalances(before, tx),
            tx,
          );

          for (final Account a in before) {
            expect(
              back.firstWhere((Account b) => b.id == a.id).balance,
              a.balance,
              reason: '${a.id} did not come back to where it started',
            );
          }
        });
      }
    }
  });
}
