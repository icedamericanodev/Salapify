// One obligation on the balance sheet twice: found, and the near misses that
// must stay quiet.
//
// THE SILENCE HALF IS THE HARD HALF. A missed flag costs a figure that is
// wrong where the person cannot see it. A false flag tells somebody their own
// correct bookkeeping is a mistake, which is worse, because it is the app
// being confidently wrong about something they know better than it does.
// Every silence case below is built so the clause under test is the ONLY
// thing separating it from a match.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/duplicate_balances.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

Account _acct(
  String id,
  String name,
  AccountKind kind,
  Money balance, {
  String institution = 'Test Bank',
  CurrencyCode currency = CurrencyCode.php,
}) => Account(
  id: id,
  name: name,
  kind: kind,
  institution: institution,
  balance: balance,
  monogram: 'TT',
  currency: currency,
);

Debt _debt(
  String id,
  String person,
  DebtDirection dir,
  Money total, {
  Money paid = Money.zero,
  bool settled = false,
}) => Debt(
  id: id,
  person: person,
  direction: dir,
  totalAmount: total,
  paidAmount: paid,
  isSettled: settled,
);

void main() {
  group('the sample ledger', () {
    final FinancialState seed = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final List<SuspectedDuplicateBalance> found = findDuplicateBalances(
      accounts: seed.accounts,
      debts: seed.debts,
    );

    test('both overlaps are found, and only those two', () {
      expect(
        found.length,
        2,
        reason:
            'found: ${found.map((SuspectedDuplicateBalance f) => f.accountName)}',
      );
    });

    test('the loan recorded as an account AND as a debt', () {
      final SuspectedDuplicateBalance f = found.firstWhere(
        (SuspectedDuplicateBalance f) => f.kind == BalanceOverlapKind.oneToOne,
      );
      expect(f.accountName, 'BPI Gadget Loan');
      expect(f.debtNames, <String>['BPI Personal Loan']);
      expect(f.amount, const Money.pesos(10000));
      expect(f.isLiability, isTrue);
    });

    test('the receivable account holding the running total', () {
      // The shape a one-to-one rule cannot see at all: no single debt is
      // 6,250, and "Internal Ledger" shares no word with "Kuya Mark".
      final SuspectedDuplicateBalance f = found.firstWhere(
        (SuspectedDuplicateBalance f) =>
            f.kind == BalanceOverlapKind.runningTotal,
      );
      expect(f.amount, const Money.pesos(6250));
      expect(f.debtNames.length, 2);
      expect(f.isLiability, isFalse);
    });

    test('the overlaps are genuinely live, so the flags are not vacuous', () {
      // If the seed ever changes these, the assertions above start passing or
      // failing for reasons unrelated to the detector.
      final Account loanAcct = seed.accounts.firstWhere(
        (Account a) => a.id == 'acc_personal_loan',
      );
      final Debt loanDebt = seed.debts.firstWhere(
        (Debt d) => d.id == 'debt_bpi_loan',
      );
      expect(loanAcct.balance, loanDebt.remaining);

      final Account recv = seed.accounts.firstWhere(
        (Account a) => a.id == 'acc_receivables',
      );
      Money owed = Money.zero;
      for (final Debt d in seed.debts.where(
        (Debt d) => d.direction == DebtDirection.owedToMe && !d.isSettled,
      )) {
        owed += d.remaining;
      }
      expect(recv.balance, owed);
    });
  });

  group('the clauses, one at a time', () {
    test('the ordinary case is reported', () {
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money.pesos(10000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money.pesos(10000),
            ),
          ],
        ),
        hasLength(1),
      );
    });

    test('a round figure collision with no shared word stays silent', () {
      // THE CLAUSE THAT EARNS ITS KEEP. Philippine lenders quote whole pesos,
      // so two genuinely different 10,000 obligations are ordinary. Same
      // amount, same side, same institution, different obligation.
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'Motorcycle Financing',
              AccountKind.loan,
              const Money.pesos(10000),
              institution: 'Security Bank',
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'Tita Baby',
              DebtDirection.iOwe,
              const Money.pesos(10000),
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('money you owe is never matched against money owed to you', () {
      // Same amount, shared word, and still two completely different facts.
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money.pesos(10000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Gadget refund',
              DebtDirection.owedToMe,
              const Money.pesos(10000),
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('one centavo apart is two obligations', () {
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money(1000000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money(1000001),
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('the ORIGINAL principal matches too, not only what is left', () {
      // Somebody who typed the original amount onto the account and never
      // updated it. 15,000 borrowed, 5,000 repaid, account still says 15,000.
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money.pesos(15000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money.pesos(15000),
              paid: const Money.pesos(5000),
            ),
          ],
        ),
        hasLength(1),
      );
    });

    test('a settled debt is behind you and is never flagged', () {
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money.pesos(10000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money.pesos(10000),
              settled: true,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('a foreign account is never matched across an exchange rate', () {
      // `Debt` has no currency at all, so an exact match here would be a
      // coincidence of today's rate and would come and go as it moved.
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Gadget Loan',
              AccountKind.loan,
              const Money.pesos(10000),
              currency: CurrencyCode.usd,
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money.pesos(10000),
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('a cash account is never flagged, whatever it holds', () {
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'BPI Savings',
              AccountKind.bank,
              const Money.pesos(10000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd',
              'BPI Personal Loan',
              DebtDirection.iOwe,
              const Money.pesos(10000),
            ),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('the running total shape', () {
    test('it matches the WHOLE set and never a subset', () {
      // THE CLAUSE THAT STOPS THIS BEING ASTROLOGY. Over n debts there are
      // 2^n subsets and one of them hits almost any balance, so a subset
      // match is evidence of arithmetic rather than of duplication. Here the
      // account equals one of the two debts exactly, which a subset rule
      // would call a match.
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'Receivables',
              AccountKind.receivable,
              const Money.pesos(5000),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd1',
              'Kuya Mark',
              DebtDirection.owedToMe,
              const Money.pesos(5000),
            ),
            _debt(
              'd2',
              'Sarah',
              DebtDirection.owedToMe,
              const Money.pesos(1250),
            ),
          ],
        ),
        isEmpty,
        reason:
            'the account equals ONE of the two debts, which is a sum the app '
            'can always find and which means nothing',
      );
    });

    test('and it does match when the whole set adds up', () {
      expect(
        findDuplicateBalances(
          accounts: <Account>[
            _acct(
              'a',
              'Receivables',
              AccountKind.receivable,
              const Money.pesos(6250),
            ),
          ],
          debts: <Debt>[
            _debt(
              'd1',
              'Kuya Mark',
              DebtDirection.owedToMe,
              const Money.pesos(5000),
            ),
            _debt(
              'd2',
              'Sarah',
              DebtDirection.owedToMe,
              const Money.pesos(1250),
            ),
          ],
        ),
        hasLength(1),
      );
    });

    test('one account is never reported twice', () {
      // A receivable that matches a single debt by name AND happens to equal
      // the whole set, because there is only one debt. Two rules, one truth,
      // one flag.
      final List<SuspectedDuplicateBalance> f = findDuplicateBalances(
        accounts: <Account>[
          _acct(
            'a',
            'Kuya Mark receivable',
            AccountKind.receivable,
            const Money.pesos(5000),
          ),
        ],
        debts: <Debt>[
          _debt(
            'd1',
            'Kuya Mark',
            DebtDirection.owedToMe,
            const Money.pesos(5000),
          ),
        ],
      );
      expect(f, hasLength(1));
      expect(f.first.kind, BalanceOverlapKind.oneToOne);
    });
  });
}
