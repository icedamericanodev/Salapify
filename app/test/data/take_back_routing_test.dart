// Which entries can be taken back from Activity, and which are refused.
//
// Reversing a ledger row touches the ACCOUNT and nothing else. When Salapify
// wrote that row to explain something else, the something else does not move
// with it. Reconciliation offered exactly that once: one tap put the money
// back and left the debt still claiming it was paid, measured at 1,500.00
// with no screen anywhere explaining the difference.
//
// So the router refuses anything with a companion record, and every test
// below is a different companion. The ones that matter most are the three
// found by a STORED link rather than by the shape of an id string, because
// those keep working after a backup is restored and the id scheme has moved
// on.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

void main() {
  /// A store with one account holding 10,000, built through the REAL codec.
  ///
  /// Loaded from a file rather than assembled in memory, for the reason the
  /// sibling removal tests give: a fixture built by hand can carry a field
  /// the codec does not actually persist, and every assertion resting on it
  /// is then hollow. The stored `txId` links this whole file is about are
  /// exactly that kind of field.
  Future<FinancialState> storeWith({
    List<Transaction> transactions = const <Transaction>[],
    List<Debt> debts = const <Debt>[],
    List<InstallmentPlan> plans = const <InstallmentPlan>[],
    List<ReconciliationRecord> reconciliations = const <ReconciliationRecord>[],
  }) async {
    final MemorySnapshotStore store = MemorySnapshotStore(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'accounts': <Map<String, dynamic>>[
          accountToJson(
            Account(
              id: 'acc_1',
              name: 'BPI Savings',
              kind: AccountKind.bank,
              institution: 'BPI',
              monogram: 'BP',
              balance: Money.pesos(10000),
            ),
          ),
        ],
        'transactions': transactions.map(transactionToJson).toList(),
        'debts': debts.map(debtToJson).toList(),
        'installments': plans.map(installmentToJson).toList(),
        'reconciliations': reconciliations.map(reconciliationToJson).toList(),
      }),
    );

    final FinancialState s = FinancialState(
      clock: DateTime(2026, 10, 3),
      store: store,
    );
    await s.restore();
    addTearDown(s.dispose);

    expect(
      s.accounts,
      hasLength(1),
      reason: 'the fixture did not load, so every assertion below is hollow',
    );
    return s;
  }

  Transaction expense(String id) => Transaction(
    id: id,
    type: TransactionType.expense,
    amount: Money.pesos(500),
    category: 'Food & Dining',
    accountId: 'acc_1',
    date: '2026-10-03',
    createdAt: 1,
    // Set rather than left to the default, so the "nothing changed" checks
    // below compare against a status this file chose instead of one that
    // could quietly move.
    status: TransactionStatus.confirmed,
  );

  group('an ordinary entry comes back', () {
    test(
      'a hand logged expense can be taken back, and the money returns',
      () async {
        final FinancialState s = await storeWith(
          transactions: <Transaction>[expense('tx_1759400000000')],
        );

        expect(s.takeBackPreview('tx_1759400000000'), TakeBackOutcome.done);
        expect(s.takeBackEntry('tx_1759400000000'), TakeBackOutcome.done);

        // DIRECTIONAL. The balance in this fixture is the account's stored
        // figure and the expense was never applied to it, so what is asserted
        // is the reversal's own movement: 10,000 plus the 500 put back.
        expect(s.accounts.single.balance, Money.pesos(10500));

        // AND THE ROW STAYS. This is the founder's ruling from 2026-10-02 and
        // the whole reason this is a take-back and not a delete: somebody
        // keeping books needs the history to show the correction too.
        expect(s.transactions, hasLength(1));
        expect(s.transactions.single.status, TransactionStatus.corrected);
        expect(s.transactions.single.countsTowardTotals, isFalse);
      },
    );

    test('taking the same entry back twice does not credit it twice', () async {
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
      );

      s.takeBackEntry('tx_1759400000000');
      final Money after = s.accounts.single.balance;

      expect(
        s.takeBackEntry('tx_1759400000000'),
        TakeBackOutcome.alreadyNotCounting,
      );
      expect(
        s.accounts.single.balance,
        after,
        reason: 'a second take-back moved the money again',
      );
    });

    test(
      'an entry that is not there at all is reported, not ignored',
      () async {
        final FinancialState s = await storeWith();
        expect(s.takeBackEntry('tx_nothing'), TakeBackOutcome.gone);
      },
    );

    test('preview changes nothing, which is the whole point of it', () async {
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
      );

      expect(s.takeBackPreview('tx_1759400000000'), TakeBackOutcome.done);
      expect(s.accounts.single.balance, Money.pesos(10000));
      expect(s.transactions.single.status, TransactionStatus.confirmed);
    });
  });

  group('a stored link refuses, and it is a FACT not a guess', () {
    test('a debt payment register row claims its entry', () async {
      // The id deliberately does NOT look like an engine payment. This is the
      // case the prefix guess cannot see and the stored link can: an entry
      // from a restored backup written by a build whose ids were different.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
        debts: <Debt>[
          Debt(
            id: 'debt_1',
            person: 'Sarah',
            direction: DebtDirection.iOwe,
            totalAmount: Money.pesos(5000),
            paidAmount: Money.pesos(500),
            isSettled: false,
            payments: <DebtPayment>[
              DebtPayment(
                id: 'dp_1',
                date: '2026-10-03',
                amount: Money.pesos(500),
                paidBefore: Money.pesos(0),
                settledBefore: false,
                txId: 'tx_1759400000000',
              ),
            ],
          ),
        ],
      );

      expect(
        s.takeBackEntry('tx_1759400000000'),
        TakeBackOutcome.belongsToDebt,
      );
      expect(
        s.accounts.single.balance,
        Money.pesos(10000),
        reason: 'a refused take-back moved the money anyway',
      );
      expect(s.transactions.single.status, TransactionStatus.confirmed);
    });

    test('an ARCHIVED debt still owns its payment rows', () async {
      // The raw list is scanned rather than the filtered getter, and this is
      // why. An archived debt is out of sight on every screen, and its
      // payment entries are not: waving one through because the debt is
      // archived would be exactly the entry this refusal exists for.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
        debts: <Debt>[
          Debt(
            id: 'debt_1',
            person: 'Sarah',
            direction: DebtDirection.iOwe,
            totalAmount: Money.pesos(5000),
            paidAmount: Money.pesos(5000),
            isSettled: true,
            archivedAt: '2026-10-02',
            payments: <DebtPayment>[
              DebtPayment(
                id: 'dp_1',
                date: '2026-10-03',
                amount: Money.pesos(500),
                paidBefore: Money.pesos(4500),
                settledBefore: false,
                txId: 'tx_1759400000000',
              ),
            ],
          ),
        ],
      );

      expect(s.debts, isEmpty, reason: 'the fixture is not actually archived');
      expect(
        s.takeBackEntry('tx_1759400000000'),
        TakeBackOutcome.belongsToDebt,
      );
    });

    test('a plan payment register row claims its entry', () async {
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
        plans: <InstallmentPlan>[
          InstallmentPlan(
            id: 'plan_1',
            name: 'Laptop',
            provider: 'Home Credit',
            principal: Money.pesos(30000),
            interestRate: 0,
            interestRateType: InterestRateType.fixed,
            totalInterest: Money.zero,
            totalPayable: Money.pesos(30000),
            termMonths: 12,
            installmentAmount: Money.pesos(2500),
            paidInstallments: 1,
            totalInstallments: 12,
            runningBalance: Money.pesos(27500),
            principalRemaining: Money.pesos(27500),
            interestRemaining: Money.zero,
            startDate: '2026-09-01',
            maturityDate: '2027-09-01',
            payments: <PlanPayment>[
              PlanPayment(
                id: 'pp_1',
                date: '2026-10-03',
                amount: Money.pesos(2500),
                toPrincipal: Money.pesos(2500),
                toInterest: Money.pesos(0),
                txId: 'tx_1759400000000',
              ),
            ],
          ),
        ],
      );

      expect(
        s.takeBackEntry('tx_1759400000000'),
        TakeBackOutcome.belongsToPlan,
      );
      expect(s.accounts.single.balance, Money.pesos(10000));
    });

    test('a reconciliation record claims its adjustment', () async {
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_1759400000000')],
        reconciliations: <ReconciliationRecord>[
          const ReconciliationRecord(
            id: 'rec_1',
            accountId: 'acc_1',
            date: '2026-10-03',
            bookBalance: 9500,
            actualBalance: 10000,
            variance: 0,
            balanced: true,
            createdAt: 1,
            adjustmentTxId: 'tx_1759400000000',
          ),
        ],
      );

      expect(
        s.takeBackEntry('tx_1759400000000'),
        TakeBackOutcome.belongsToReconciliation,
      );
      expect(s.accounts.single.balance, Money.pesos(10000));
    });
  });

  group('an id prefix refuses too, as the backstop', () {
    test(
      'a debt entry whose register row did not survive is still refused',
      () async {
        // No DebtPayment anywhere, so the stored link cannot help. An older
        // backup restored into this build looks exactly like this, and the
        // prefix is the only thing left that knows what the row is.
        final FinancialState s = await storeWith(
          transactions: <Transaction>[expense('tx_debt_1759400000000')],
        );

        expect(
          s.takeBackEntry('tx_debt_1759400000000'),
          TakeBackOutcome.belongsToDebt,
        );
      },
    );

    test(
      'an instalment entry with no register row is refused as a plan',
      () async {
        final FinancialState s = await storeWith(
          transactions: <Transaction>[expense('tx_inst_1759400000000')],
        );
        expect(
          s.takeBackEntry('tx_inst_1759400000000'),
          TakeBackOutcome.belongsToPlan,
        );
      },
    );

    test('a prepayment entry routes to the plan, not to a debt', () async {
      // tx_inst_extra_ starts with tx_inst_, which isEnginePayment relies on
      // and which the routing must not accidentally read as tx_debt_.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_inst_extra_1759400000000')],
      );
      expect(
        s.takeBackEntry('tx_inst_extra_1759400000000'),
        TakeBackOutcome.belongsToPlan,
      );
    });

    test('a bill entry is refused, and a bill has NO stored link', () async {
      // UpcomingItem carries no transaction id, so the prefix is not a
      // backstop here, it is the only thing there is. Named in the method's
      // doc rather than left to be discovered.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_bill_1759400000000')],
      );
      expect(
        s.takeBackEntry('tx_bill_1759400000000'),
        TakeBackOutcome.belongsToBill,
      );
      expect(s.accounts.single.balance, Money.pesos(10000));
    });

    // The split route, in all three states, because the first version of this
    // group had ONE test, named "a split entry is refused, because its debts
    // are still standing", whose fixture passed no debts at all. It asserted
    // the refusal in exactly the state where the refusal is wrong, so the
    // test that was meant to guard the behaviour proved the defect instead.
    //
    // The dead end it hid: follow the refusal's own instruction, remove the
    // debts, come back, and meet the identical sentence, now false, with the
    // expense unreachable forever because the five second snackbar is gone.

    /// A split's expense and the receivables it wrote, sharing a stamp.
    ///
    /// Built the way `_save` builds them so the id link under test is the
    /// real one and not a shape invented for the test.
    List<Debt> splitDebts(String stamp, int count) => <Debt>[
      for (int i = 0; i < count; i++)
        Debt(
          id: 'debt_split_${stamp}_$i',
          person: 'Carla $i',
          direction: DebtDirection.owedToMe,
          totalAmount: Money.pesos(600),
          paidAmount: Money.zero,
          isSettled: false,
          notes: 'Split: Barkada lunch',
        ),
    ];

    test('refused while even ONE of its receivables is standing', () async {
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_split_1759400000000')],
        debts: splitDebts('1759400000000', 1),
      );
      expect(
        s.takeBackEntry('tx_split_1759400000000'),
        TakeBackOutcome.belongsToSplit,
      );
      expect(s.accounts.single.balance, Money.pesos(10000));
    });

    test('still refused when SOME were removed and others were not', () async {
      // Two were created, one deleted by hand. The remaining one is still a
      // person who owes for a bill that would otherwise stop existing.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_split_1759400000000')],
        debts: <Debt>[splitDebts('1759400000000', 2).last],
      );
      expect(
        s.takeBackEntry('tx_split_1759400000000'),
        TakeBackOutcome.belongsToSplit,
      );
    });

    test('ALLOWED once every one of them is gone', () async {
      // THE DEAD END, and the whole reason this group was rewritten. The
      // refusal says "remove those debts from the Debts screen first". This
      // is the state a person reaches by obeying that sentence, and until
      // 2026-10-03 they met the same refusal again with nothing left to do.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_split_1759400000000')],
      );

      expect(s.takeBackPreview('tx_split_1759400000000'), TakeBackOutcome.done);
      expect(s.takeBackEntry('tx_split_1759400000000'), TakeBackOutcome.done);
      expect(
        s.accounts.single.balance,
        Money.pesos(10500),
        reason: 'the expense is still unreachable after its debts were removed',
      );
    });

    test('another split debts do not hold this one hostage', () async {
      // A DIFFERENT stamp. Matching on the bare 'debt_split_' prefix instead
      // of the full stamp would make any surviving split anywhere refuse
      // every other split's expense forever.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_split_1759400000000')],
        debts: splitDebts('1759499999999', 1),
      );
      expect(s.takeBackPreview('tx_split_1759400000000'), TakeBackOutcome.done);
    });

    test('a transfer between the person OWN accounts is ordinary', () async {
      // tx_move_ is NOT refused and should not be. A transfer writes one row
      // and touches two balances, and reverseFromBalances already handles the
      // second leg. There is no companion record to strand.
      final FinancialState s = await storeWith(
        transactions: <Transaction>[expense('tx_move_1759400000000')],
      );
      expect(s.takeBackPreview('tx_move_1759400000000'), TakeBackOutcome.done);
    });
  });
}
