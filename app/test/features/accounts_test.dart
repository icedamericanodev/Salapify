// What the Accounts screen decides, tested without pumping a widget.
//
// Every one of these cases is a defect the FIRST RENDER of this screen
// actually had. None of them was caught by the 370 tests that were green at
// the time, because none of those tests had ever put an account, a credit card
// and a debt in front of the same function.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/account_taxonomy.dart';
import 'package:salapify/features/accounts/accounts_screen.dart';

import '../support/memory_store.dart';

void main() {
  group('grouping', () {
    test('a credit card is a liability, not cash on hand', () {
      final groups = groupAccounts(livedIn());
      final cash = groups.firstWhere((g) => g.id == 'cash_equivalents');

      // The defect: with the card filed under `accounts` and a kind the
      // taxonomy does not know, it derived to cash_on_hand, sat in this
      // section, and was ADDED to assets.
      expect(
        cash.accounts.map((a) => a['name']),
        isNot(contains('UnionBank Rewards')),
        reason:
            'A credit card in the cash section is money owed counted as '
            'money held',
      );
      expect(groups.map((g) => g.id), contains('credit'));
    });

    test('sections come out in the taxonomy registry order', () {
      final groups = groupAccounts(livedIn());
      expect(groups.map((g) => g.label), [
        'Cash and e-wallets',
        'Credit cards',
      ]);
    });

    test(
      'loans get no section of their own, because the summary counts them',
      () {
        final groups = groupAccounts(livedIn());
        expect(
          groups.map((g) => g.id),
          isNot(contains('loans')),
          reason:
              'A loan with its own row AND a place in "You owe" is the same '
              'debt shown twice on one screen',
        );
        expect(rollsIntoDebtSummary('loans'), isTrue);
        expect(rollsIntoDebtSummary('installments'), isTrue);

        // Credit is the deliberate exception: it is the only liability with a
        // limit, so the only one with a utilisation bar worth a row.
        expect(rollsIntoDebtSummary('credit'), isFalse);
        expect(rollsIntoDebtSummary('cash_equivalents'), isFalse);
      },
    );

    test('an empty ledger groups into nothing rather than throwing', () {
      expect(groupAccounts(const {}), isEmpty);
      expect(groupAccounts(const {'accounts': null}), isEmpty);
    });
  });

  group('debt totals', () {
    test('both directions, and the credit card in neither', () {
      final d = debtTotals(livedIn());

      // Lola's personal loan only. The card is a row two sections up.
      expect(d.owed, 6000.00);
      expect(d.owedCount, 1);
      expect(d.due, 1800.00);
      expect(d.dueCount, 1);
      expect(d.any, isTrue);
    });

    test('a receivable is keyed on amount, not remaining', () {
      // The defect: the first fixture wrote `remaining` on a receivable, which
      // trackedRemaining does not read, so the row silently counted as zero
      // and the screen was 1,800 short with every test still green.
      final state = {
        'receivables': [
          {'id': 'r1', 'amount': 500.0, 'cashLeg': true},
        ],
      };
      expect(debtTotals(state).due, 500.00);
    });

    test('a receivable with no cash leg does not count', () {
      // Somebody owing a share of something did not take money out of the
      // founder's pocket, so it is not an asset. The backup round trip test
      // is where this rule was found.
      final state = {
        'receivables': [
          {'id': 'r1', 'amount': 500.0},
        ],
      };
      expect(debtTotals(state).due, 0.00);
    });

    test('no debts at all is not the same as being square', () {
      // A section reading "You owe P0 / Owed to you P0" claims the founder is
      // settled with the world. Having recorded none is a different sentence,
      // so the section does not draw.
      expect(debtTotals(const {}).any, isFalse);
    });
  });

  group('row presentation', () {
    test('the monogram prefers the institution, then the name', () {
      expect(monogramFor({'institutionId': 'bpi', 'name': 'Whatever'}), 'BP');
      expect(monogramFor({'name': 'Coop savings'}), 'CS');

      // UnionBank gives UB, not UN. A run together name splits at its internal
      // capital, and UN on a circle reads as the United Nations.
      expect(monogramFor({'institutionId': 'unionbank'}), 'UB');
    });

    test('an institution that only echoes the account name is dropped', () {
      // The first render said "BPI" over "BPI, Cash on hand". The name is
      // already the institution, so repeating it is not information.
      expect(
        accountKindLabel({
          'name': 'BPI',
          'institutionId': 'bpi',
          'kind': 'savings',
        }, AccountStore.accounts),
        'Savings account',
      );
      expect(
        accountKindLabel({
          'name': 'UnionBank Rewards',
          'institutionId': 'unionbank',
          'subtype': 'credit_card',
        }, AccountStore.debts),
        'UnionBank · Credit card',
      );
    });

    test('the money key follows the collection the row came from', () {
      // Reading `balance` off a debts row gives zero, and a credit card shown
      // as nothing owed is worse than a crash.
      final card = {'remaining': 4120.0, 'balance': 0.0};
      expect(rowAmount(card, AccountStore.debts), 4120.00);
      expect(rowAmount({'balance': 99.0}, AccountStore.accounts), 99.00);
      expect(rowAmount({'value': 250000.0}, AccountStore.assets), 250000.00);
    });
  });
}
