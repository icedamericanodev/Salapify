// The owned-asset kind, and the four lists it must and must not be in.
//
// WHY IT EXISTS AT ALL. Every other `AccountKind` is money or a claim on
// money, so a mortgage and a car loan had no other side. Taking out a 385,000
// Pag-IBIG loan dropped net worth by the whole 385,000 on the day it was
// taken and climbed back as it was repaid, which is wrong in the moment that
// matters most and wrong in the direction that makes borrowing to buy a home
// look like a catastrophe. Borrowing to buy a thing does not make you poorer.
//
// THE DANGEROUS HALF IS NOT THE ARITHMETIC. It is that a house is worth a lot
// and cannot be spent. A kind that leaked into Safe to Spend or the 45 day
// runway would tell somebody with a paid-off condo that they have two million
// pesos for groceries this fortnight. Most of this file is about that.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/accounts.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/core/money/safe_to_spend.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

Account _house(Money worth) => Account(
  id: 'house',
  name: 'House and lot',
  kind: AccountKind.property,
  institution: 'Owned',
  balance: worth,
  monogram: 'OWN',
);

const Account _cash = Account(
  id: 'cash',
  name: 'Wallet',
  kind: AccountKind.cash,
  institution: 'Cash',
  balance: Money.pesos(3000),
  monogram: 'CA',
);

void main() {
  group('it is an asset, and only in the places an asset belongs', () {
    test('it counts toward what you own', () {
      final FinancialPosition p = computePosition(<Account>[
        _cash,
        _house(const Money.pesos(2000000)),
      ], null);
      expect(p.totalAssets, const Money.pesos(2003000));
      expect(p.netWorth, const Money.pesos(2003000));
    });

    test('a mortgage and the home it bought cancel out', () {
      // THE WHOLE POINT, stated as the invariant it is. Buying a 2,000,000
      // house with a 2,000,000 loan leaves you exactly as well off as before:
      // you gained the house and you gained the debt. Before this kind
      // existed the same event cost 2,000,000 of net worth on paper.
      const Account loan = Account(
        id: 'm',
        name: 'Pag-IBIG',
        kind: AccountKind.mortgage,
        institution: 'Pag-IBIG',
        balance: Money.pesos(2000000),
        monogram: 'PI',
      );
      final FinancialPosition p = computePosition(<Account>[
        _cash,
        _house(const Money.pesos(2000000)),
        loan,
      ], null);
      expect(
        p.netWorth,
        _cash.balance,
        reason:
            'the house and the loan on it did not cancel. Net worth should be '
            'the cash and nothing else',
      );
      // DIRECTIONAL COMPANION, because the assertion above is a conservation
      // statement and would pass just as well if BOTH sides were being
      // ignored. These name the two figures that must really be there.
      expect(p.totalAssets, const Money.pesos(2003000));
      expect(p.totalLiabilities, const Money.pesos(2000000));
    });

    test('the parts Reports lists foot to the totals under them', () {
      // "What you own" listed cash, investments and owed-to-you, and the
      // total under them included the house as well, so with a home recorded
      // the rows summed to less than the figure printed under them. The
      // Position chart stacks exactly these parts on one bar, so a missing
      // part would also draw the bar short of its own total.
      const Account stocks = Account(
        id: 'inv',
        name: 'Index fund',
        kind: AccountKind.investment,
        institution: 'Broker',
        balance: Money.pesos(50000),
        monogram: 'IF',
      );
      const Account card = Account(
        id: 'cc',
        name: 'Card',
        kind: AccountKind.credit,
        institution: 'Bank',
        balance: Money.pesos(4200),
        monogram: 'CC',
      );
      final FinancialPosition p = computePosition(<Account>[
        _cash,
        stocks,
        card,
        _house(const Money.pesos(2000000)),
      ], null);

      expect(
        p.cashEquivalents + p.investments + p.receivables + p.property,
        p.totalAssets,
        reason: 'the parts of what you own do not add up to the total',
      );
      expect(p.creditCards + p.loans, p.totalLiabilities);
      // DIRECTIONAL: the house is really in its own part, not hiding inside
      // another one that happens to make the sum come out.
      expect(p.property, const Money.pesos(2000000));
    });

    test('the control still holds exactly', () {
      final FinancialPosition p = computePosition(<Account>[
        _cash,
        _house(const Money.pesos(1234567)),
      ], null);
      expect(p.totalAssets - p.totalLiabilities, p.netWorth);
    });
  });

  group('and it can never be spent', () {
    test('it is not liquid', () {
      expect(_house(const Money.pesos(2000000)).isLiquid, isFalse);
      expect(liquidKinds.contains(AccountKind.property), isFalse);
    });

    test('it is not a cash equivalent', () {
      expect(cashEquivalentKinds.contains(AccountKind.property), isFalse);
    });

    test('Safe to Spend does not move by one centavo', () {
      // THE ASSERTION THIS FILE EXISTS FOR. A two million peso house must
      // change nothing about this fortnight.
      SafeToSpendAnalysis run(List<Account> accounts) => computeSafeToSpend(
        accounts: accounts,
        transactions: const <Transaction>[],
        bills: const <BillItem>[],
        debtsIOwe: 0,
        installments: const <InstallmentPlan>[],
        incomeStreams: const <IncomeStream>[],
        // A real cycle rather than an empty one, because Safe to Spend
        // divides by days to payday and the figure has to be a figure for
        // "unchanged" to mean anything.
        payday: const PaydayCycle(
          cycleType: '15_30',
          lastPayday: 'Sep 15',
          nextPayday: 'Sep 30',
          daysToPayday: 12,
          expectedIncome: Money.pesos(32500),
          paydayDays: <int>[15, 30],
        ),
        scenario: DecisionScenario.conservative,
        now: DateTime.utc(2026, 9, 18),
      );

      final SafeToSpendAnalysis without = run(<Account>[_cash]);
      final SafeToSpendAnalysis withHouse = run(<Account>[
        _cash,
        _house(const Money.pesos(2000000)),
      ]);

      expect(
        withHouse.safeToSpendToday,
        without.safeToSpendToday,
        reason:
            'a house reached the figure that answers "what can I spend '
            'today". It cannot be spent and must not appear there',
      );
      expect(withHouse.safeToSpendUntilPayday, without.safeToSpendUntilPayday);
      expect(
        withHouse.cashRunwayDays,
        without.cashRunwayDays,
        reason:
            'the runway counted a house as cash it could live on, which is '
            'the same defect wearing a different figure',
      );

      // DIRECTIONAL COMPANION. Every assertion above is "nothing changed",
      // which passes just as well if the whole function returns a constant.
      // This names a figure that MUST have moved, so inaction cannot satisfy
      // the pair.
      expect(
        computePosition(<Account>[
          _cash,
          _house(const Money.pesos(2000000)),
        ], null).totalAssets,
        const Money.pesos(2003000),
      );
    });
  });

  group('it survives a round trip, and fails loudly when it cannot', () {
    test('stored and read back unchanged', () {
      final Account before = _house(const Money.pesos(2000000));
      final Account after = accountFromJson(accountToJson(before));
      expect(after.kind, AccountKind.property);
      expect(after.balance, before.balance);
    });

    test('an older build REFUSES the file rather than losing the account', () {
      // The safe failure, and worth pinning because the alternative is
      // silent. `decodeRequired` rejects a wire value it does not know with a
      // readable message. A build that defaulted to `cash` instead would turn
      // somebody's house into spendable money; one that skipped the row would
      // drop it out of their net worth with nothing said.
      expect(
        () => accountFromJson(<String, dynamic>{
          ...accountToJson(_house(const Money.pesos(2000000))),
          'kind': 'spaceship',
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('the Accounts screen shows everything it counts', () {
    // THE HOLE THE COMPILER COULD NOT SEE. `groupAssets` is a hand-typed list
    // of `.where()` calls, not a switch, so adding a kind put `property` in
    // its INPUT and in none of its output. The hero reads `summarize`, which
    // counts every asset; the list reads `groupAssets`, which would have
    // dropped the house. A total over a list that does not foot to it, with
    // no analyzer error anywhere.

    test('the groups foot to the total above them', () {
      final List<Account> accounts = <Account>[
        _cash,
        _house(const Money.pesos(400000)),
      ];
      Money grouped = Money.zero;
      for (final AccountGroup g in groupAssets(accounts)) {
        for (final Account x in g.accounts) {
          grouped += x.balanceInPhp;
        }
      }
      expect(grouped, computePosition(accounts, null).totalAssets);

      // DIRECTIONAL COMPANION. The sum above balances just as well when the
      // house is dropped from BOTH sides, which is exactly the defect. This
      // names the account that has to actually appear in a group.
      expect(
        groupAssets(
          accounts,
        ).expand((AccountGroup g) => g.accounts).map((Account x) => x.id),
        contains('house'),
        reason: 'the house is counted in the total and shown in no group',
      );
    });

    test('every kind lands in exactly one group', () {
      // THE FORCING FUNCTION, and the reason this file is worth its length.
      // A derived set is a rule; a typed set is only a promise. This reddens
      // the build for whoever adds the next kind, which is the only thing
      // that would have caught the one above.
      for (final AccountKind k in AccountKind.values) {
        final Account probe = Account(
          id: 'probe',
          name: 'Probe',
          kind: k,
          institution: 'Probe',
          balance: const Money.pesos(1000),
          monogram: 'PR',
        );
        final int claims =
            groupAssets(<Account>[probe]).length +
            groupLiabilities(<Account>[probe]).length;
        expect(
          claims,
          1,
          reason:
              '${k.name} is claimed by $claims groups. One means it is shown '
              'where it is counted; zero means the screen counts money it '
              'never displays; two means it is displayed twice',
        );
      }
    });
  });

  test('every kind is an asset or a liability, and never both', () {
    // Repeated from the direction table on purpose. A kind in neither list
    // contributes nothing to net worth and nothing says so, which is the
    // quietest way this change could have gone wrong.
    for (final AccountKind k in AccountKind.values) {
      final bool asset = assetKinds.contains(k);
      final bool liability = liabilityKinds.contains(k);
      expect(asset || liability, isTrue, reason: '${k.name} is in neither');
      expect(asset && liability, isFalse, reason: '${k.name} is in both');
    }
  });

  group('the age of an estimate', () {
    final DateTime now = DateTime.utc(2026, 10, 5);

    test('it reads as age, never as a date', () {
      expect(formatAge('2026-10-05', now: now), 'today');
      expect(formatAge('2026-10-04', now: now), 'yesterday');
      expect(formatAge('2026-09-28', now: now), '7 days ago');
      expect(formatAge('2026-08-20', now: now), 'about a month ago');
      expect(formatAge('2026-03-05', now: now), 'about 7 months ago');
      expect(formatAge('2025-09-05', now: now), 'about a year ago');
      expect(formatAge('2023-03-12', now: now), 'about 3 years ago');
    });

    test('the YEAR is never lost, which is the whole reason this exists', () {
      // `formatDateLabel` renders this as "Sun, Mar 12" with no year at all,
      // so a valuation from 2023 would read as March of this year. That is
      // the exact misreading the date was stored to prevent.
      expect(formatDateLabel('2023-03-12', now: now), isNot(contains('2023')));
      expect(formatAge('2023-03-12', now: now), contains('3 years'));
    });

    test('a date in the future says the only true thing about it', () {
      // Reachable two ways: somebody types it, or a backup arrives from a
      // phone whose clock was wrong. Neither is worth throwing over.
      expect(formatAge('2027-01-01', now: now), 'dated ahead');
    });

    test('nothing it returns could trip the raw-date guard', () {
      // `screen_readability_test` fails on a stored date reaching a screen,
      // and this string goes straight onto the Accounts row.
      final RegExp iso = RegExp(r'\d{4}-\d{2}-\d{2}');
      for (final String d in <String>[
        '2026-10-05',
        '2026-09-28',
        '2023-03-12',
        '2027-01-01',
      ]) {
        expect(formatAge(d, now: now), isNot(matches(iso)), reason: d);
      }
    });
  });

  group('the date survives, and survives the ledger', () {
    test('stored and read back', () {
      final Account a = Account(
        id: 'h',
        name: 'House',
        kind: AccountKind.property,
        institution: 'Owned',
        balance: const Money.pesos(400000),
        monogram: 'OWN',
        valuedOn: '2026-03-12',
      );
      expect(accountFromJson(accountToJson(a)).valuedOn, '2026-03-12');
    });

    test('an account written before the field is still valid', () {
      // The whole reason it is nullable. No migration, no guessing, and
      // nothing pretends to know a date nobody gave.
      final Map<String, dynamic> old = accountToJson(_house(Money.zero))
        ..remove('valuedOn');
      expect(accountFromJson(old).valuedOn, isNull);
    });

    test('a balance moving does not wipe the date', () {
      // `copyWith` is what the ledger calls every time a balance moves.
      // Dropping the date there would reset a house to "no date on it" the
      // first time anything touched the account, which is the opposite of
      // what storing it is for.
      final Account a = Account(
        id: 'h',
        name: 'House',
        kind: AccountKind.property,
        institution: 'Owned',
        balance: const Money.pesos(400000),
        monogram: 'OWN',
        valuedOn: '2026-03-12',
      );
      expect(
        a.copyWith(balance: const Money.pesos(410000)).valuedOn,
        '2026-03-12',
      );
    });
  });
}
