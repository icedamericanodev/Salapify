import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// Taking an instalment plan off the list, which was impossible until now.
///
/// ## The hole this closes
///
/// A plan could not be removed by ANY route. No delete, no archive, and no
/// settle control on a plan card. Plans arrive from the seed or from a
/// restored backup and they never left.
///
/// That matters more than it sounds, because paying a plan ADOPTS it: the
/// engine's copier drops `isSample` on purpose, so a real payment makes a
/// demo record the person's own and the sample sweep can no longer touch it.
/// Both halves are correct on their own. Together they meant that one
/// exploratory tap of "Pay this month" on a demo plan, which is the obvious
/// thing to do on a screen somebody is exploring, permanently adopted a
/// liability Salapify invented, and Safe to Spend reserved an instalment of
/// it on Home for ever. The only exit was Delete everything.
///
/// The same shape reaches a real user with no sample data involved: a plan
/// restored from a backup that was cancelled, refinanced or paid off outside
/// the app.
///
/// The design mirrors the debt side exactly, which the founder settled on
/// 2026-10-02: delete one that never moved money, archive a SETTLED one,
/// refuse everything between.
void main() {
  InstallmentPlan plan({
    String id = 'p1',
    int paid = 0,
    bool settled = false,
    List<PlanPayment> payments = const <PlanPayment>[],
    bool sample = false,
  }) => InstallmentPlan(
    id: id,
    name: 'iPhone 15',
    provider: 'Home Credit',
    principal: const Money.pesos(24500),
    interestRate: 0,
    interestRateType: InterestRateType.fixed,
    totalInterest: const Money.pesos(4410),
    totalPayable: const Money.pesos(28910),
    termMonths: 12,
    installmentAmount: const Money.of(2409, 17),
    paidInstallments: paid,
    totalInstallments: 12,
    runningBalance: settled ? Money.zero : const Money.pesos(28910),
    principalRemaining: settled ? Money.zero : const Money.pesos(24500),
    interestRemaining: settled ? Money.zero : const Money.pesos(4410),
    startDate: '2026-01-15',
    maturityDate: '2027-01-15',
    payments: payments,
    isSettled: settled,
    isSample: sample,
  );

  late MemorySnapshotStore lastStore;

  Future<FinancialState> stateWith(List<InstallmentPlan> plans) async {
    final MemorySnapshotStore store = MemorySnapshotStore(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        // AN ACCOUNT WITH REAL MONEY IN IT, so Safe to Spend has somewhere
        // to move. With an empty ledger it is floored at zero and stays
        // there, which made the figure this feature exists to free up
        // unmeasurable: the test read 0.00 before and 0.00 after and could
        // not tell a working fix from a broken one.
        'accounts': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'acc_bpi',
            'name': 'BPI Savings',
            'kind': 'bank',
            'institution': 'BPI',
            'balance': 80000.00,
            'monogram': 'BP',
          },
        ],
        'transactions': <Map<String, dynamic>>[],
        'installments': plans.map(installmentToJson).toList(),
      }),
    );
    lastStore = store;
    final FinancialState s = FinancialState(clock: testToday, store: store);
    await s.restore();
    addTearDown(s.dispose);
    expect(
      <InstallmentPlan>[...s.installments, ...s.archivedInstallments],
      hasLength(plans.length),
      reason: 'the fixture did not load, so every assertion below is hollow',
    );
    return s;
  }

  group('delete, which is permanent', () {
    test('a plan that never took a payment goes', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[plan()]);

      expect(s.deletePlan('p1'), isTrue);
      expect(s.installments, isEmpty);
    });

    test('a plan with a REGISTER is refused', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(
          paid: 1,
          payments: <PlanPayment>[
            const PlanPayment(
              id: 'pp_1',
              date: '2026-10-01',
              amount: Money.of(2409, 17),
              toPrincipal: Money.pesos(2042),
              toInterest: Money.of(367, 17),
              settledBefore: false,
              installmentNumber: 1,
            ),
          ],
        ),
      ]);

      expect(s.deletePlan('p1'), isFalse);
      expect(
        s.installments,
        hasLength(1),
        reason:
            'the register and the ledger rows it points at would be left '
            'explaining a plan that no longer exists',
      );
    });

    test(
      'a COUNTER alone does not block it, which is the seeded case',
      () async {
        // THE TEST THAT CAUGHT THE FIRST VERSION OF THIS GATE.
        //
        // All three seeded plans arrive with a counter of 5, 10 and 2 and an
        // EMPTY register. A gate that also refused on paidInstallments left
        // every one of them unremovable by any route: not deletable (counter),
        // not archivable (not settled), not take-back-able (no register). The
        // exit still did not exist, which is the whole thing this was built
        // for.
        //
        // The counter is a number copied off a contract. The register is what
        // Salapify recorded, and it is the only thing that wrote ledger rows.
        final FinancialState s = await stateWith(<InstallmentPlan>[
          plan(paid: 10),
        ]);

        expect(
          s.deletePlan('p1'),
          isTrue,
          reason:
              'a plan Salapify never recorded a payment for cannot be removed, '
              'so every seeded plan is stuck in Safe to Spend for good',
        );
        expect(s.installments, isEmpty);
      },
    );

    test('deleting writes no entry and moves no balance', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[plan()]);
      final int before = s.transactions.length;

      expect(s.deletePlan('p1'), isTrue);
      expect(s.transactions, hasLength(before));
    });
  });

  group('archive, which is not', () {
    test('a settled plan goes, and comes back', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(settled: true, paid: 12),
        plan(id: 'p2'),
      ]);

      expect(s.archivePlan('p1'), isTrue);

      // THE MIDPOINT, before the round trip, because "returns to the start"
      // is satisfied perfectly by nothing happening.
      expect(s.installments.map((InstallmentPlan p) => p.id), <String>['p2']);
      expect(s.archivedInstallments.single.id, 'p1');
      expect(s.archivedInstallments.single.archivedAt, isNotNull);

      expect(s.unarchivePlan('p1'), isTrue);
      expect(s.installments.map((InstallmentPlan p) => p.id), <String>[
        'p1',
        'p2',
      ]);
      expect(s.archivedInstallments, isEmpty);
    });

    test('a LIVE plan is refused, however much is paid off', () async {
      // The founder's fork, applied here: archiving this plan would take a
      // real monthly obligation out of Safe to Spend on a tap.
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(paid: 6),
      ]);

      expect(s.archivePlan('p1'), isFalse);
      expect(s.archivedInstallments, isEmpty);
    });

    test(
      'archiving holds Safe to Spend still, because it is settled already',
      () async {
        final FinancialState s = await stateWith(<InstallmentPlan>[
          plan(settled: true, paid: 12),
          plan(id: 'p2'),
        ]);
        final double before = s.safeToSpend;

        expect(s.archivePlan('p1'), isTrue);

        expect(
          s.safeToSpend,
          before,
          reason:
              'archiving moved Safe to Spend, which is the whole thing the '
              'settled only gate exists to make impossible',
        );
        // The companion, because "nothing changed" is also true of nothing
        // happening at all.
        expect(s.archivedInstallments, hasLength(1));
      },
    );

    test('an archived plan survives a save and a GENUINE reload', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(settled: true, paid: 12),
      ]);
      expect(s.archivePlan('p1'), isTrue);
      await s.flushWrites();

      final FinancialState reopened = FinancialState(
        clock: testToday,
        store: lastStore,
      );
      await reopened.restore();
      addTearDown(reopened.dispose);

      expect(
        reopened.archivedInstallments,
        hasLength(1),
        reason:
            'it came back live, so archiving does not survive closing the '
            'app and the feature is cosmetic',
      );
      expect(reopened.installments, isEmpty);
    });
  });

  group('archived implies settled, whatever route is taken', () {
    test(
      'taking back the payment that cleared it brings it back too',
      () async {
        // reverseLastPlanPayment restores isSettled from the stored row, so
        // this un-settles the plan. Without the guard it would stay archived,
        // and the getter filters archived plans out of every total, so a live
        // obligation would count nowhere.
        final FinancialState s = await stateWith(<InstallmentPlan>[
          plan(
            settled: true,
            paid: 12,
            payments: <PlanPayment>[
              const PlanPayment(
                id: 'pp_last',
                date: '2026-10-01',
                amount: Money.of(2409, 13),
                toPrincipal: Money.pesos(2042),
                toInterest: Money.of(367, 13),
                settledBefore: false,
                installmentNumber: 12,
              ),
            ],
          ),
        ]);
        expect(s.archivePlan('p1'), isTrue);
        expect(s.archivedInstallments, hasLength(1));

        expect(s.takeBackPlanPayment('p1'), isTrue);

        expect(
          s.archivedInstallments,
          isEmpty,
          reason:
              'the plan is live AND archived, so a real monthly obligation '
              'appears on no screen and in no total',
        );
        expect(s.installments.single.id, 'p1');
        expect(s.installments.single.isSettled, isFalse);
      },
    );

    test(
      'an engine write on an archived plan does not quietly un-archive it',
      () async {
        // THE PATH THAT REACHES THE COPIER, and the reason this test exists.
        //
        // A first version of this group only covered a take-back that
        // UN-SETTLES the plan, and `_unarchiveIfLive` un-archives that one on
        // purpose. So deleting the copier's `archivedAt` carry changed nothing
        // and every test still passed, which per the house rule means the test
        // was wrong rather than the code unusually safe.
        //
        // The reachable case is a take-back whose stored row says the plan was
        // ALREADY settled before that payment. The plan stays settled, so the
        // invariant helper correctly leaves it alone, and the engine's copier
        // is then the only thing standing between the archive and oblivion.
        final FinancialState s = await stateWith(<InstallmentPlan>[
          plan(
            settled: true,
            paid: 12,
            payments: <PlanPayment>[
              const PlanPayment(
                id: 'pp_stray',
                date: '2026-10-01',
                amount: Money.pesos(100),
                toPrincipal: Money.pesos(100),
                toInterest: Money.zero,
                // Already settled when this one landed.
                settledBefore: true,
              ),
            ],
          ),
        ]);
        expect(s.archivePlan('p1'), isTrue);

        expect(s.takeBackPlanPayment('p1'), isTrue);

        // Read from the ARCHIVED list, because a plan that correctly stayed
        // archived is filtered out of `installments` by design.
        expect(
          <InstallmentPlan>[
            ...s.installments,
            ...s.archivedInstallments,
          ].single.isSettled,
          isTrue,
          reason: 'the fixture stopped exercising the stays-settled branch',
        );
        expect(
          s.archivedInstallments,
          hasLength(1),
          reason:
              'an ordinary engine write dropped the archive, so the plan '
              'reappeared on the Plans list on its own',
        );
      },
    );

    test('a take-back on a plan nobody archived archives nothing', () async {
      // The silent half. The guard above must not start archiving or
      // unarchiving plans on its own.
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(
          paid: 1,
          payments: <PlanPayment>[
            const PlanPayment(
              id: 'pp_1',
              date: '2026-10-01',
              amount: Money.of(2409, 17),
              toPrincipal: Money.pesos(2042),
              toInterest: Money.of(367, 17),
              settledBefore: false,
              installmentNumber: 1,
            ),
          ],
        ),
      ]);

      expect(s.takeBackPlanPayment('p1'), isTrue);
      expect(s.archivedInstallments, isEmpty);
      expect(s.installments, hasLength(1));
    });
  });

  group('the demo plan trap, which is what this was built for', () {
    test('a demo plan paid once can be got rid of again', () async {
      // The first-run sequence: install, open Plans, tap "Pay this month" on
      // a demo plan because that is the obvious thing to do, then want it
      // gone. Before this feature there was no way out at all.
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(sample: true),
      ]);

      s.payInstallment('p1');
      expect(
        s.installments.single.isSample,
        isFalse,
        reason:
            'paying a demo plan is meant to adopt it, so the sample sweep '
            'cannot delete a record the ledger points at',
      );
      expect(
        s.deletePlan('p1'),
        isFalse,
        reason: 'a plan with a payment against it must not be deleted',
      );

      // The route out, and it is two taps rather than none.
      expect(s.takeBackPlanPayment('p1'), isTrue);
      expect(s.deletePlan('p1'), isTrue);
      expect(s.installments, isEmpty);
      expect(s.archivedInstallments, isEmpty);
    });

    test('and Safe to Spend stops reserving for it', () async {
      final FinancialState s = await stateWith(<InstallmentPlan>[
        plan(sample: true),
      ]);
      final double withPlan = s.safeToSpend;

      s.payInstallment('p1');
      s.takeBackPlanPayment('p1');
      expect(s.deletePlan('p1'), isTrue);

      expect(
        s.safeToSpend,
        greaterThan(withPlan),
        reason:
            'the plan is gone and Salapify is still holding an instalment of '
            'it back on Home, which is the figure the trap actually cost',
      );
    });
  });

  test('the seed is not already carrying an archived plan', () {
    // A fixture check, not a feature check. Every assertion above about
    // archivedInstallments assumes a clean starting point.
    expect(
      SeedData.installments(
        testToday,
      ).where((InstallmentPlan p) => p.isArchived),
      isEmpty,
    );
  });
}
