// One payment, written down twice: does the detector find it, and does it
// keep quiet about the pairs that merely look alike.
//
// BOTH HALVES ARE LOAD BEARING and the second one is the harder test. An
// alarm that cries wolf gets its battery taken out, and then it is not there
// during the fire. So the silence cases below are not padding: each one is a
// pair the shipped sample ledger genuinely contains, which a looser rule
// would have reported.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/daily_projection.dart';
import 'package:salapify/core/money/duplicate_obligations.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

void main() {
  List<SuspectedDuplicate> onSeed(DateTime now) {
    final FinancialState s = FinancialState(clock: now);
    return findDuplicateOutflows(
      bills: s.bills,
      upcoming: s.upcoming,
      installments: s.installments,
      debts: s.debts,
      now: now,
    );
  }

  group('the sample ledger', () {
    test('both written-twice obligations are found, and only those two', () {
      // Founder decision D28 keeps the Home Credit pair in the seed for
      // exactly this: a notice with no proof case is a notice nobody has
      // ever seen fire.
      final List<SuspectedDuplicate> found = onSeed(DateTime.utc(2026, 9, 18));

      expect(
        found.length,
        2,
        reason: 'found: ${found.map((SuspectedDuplicate d) => d.label)}',
      );

      final SuspectedDuplicate meralco = found.firstWhere(
        (SuspectedDuplicate d) => d.label.contains('Meralco'),
      );
      expect(meralco.amount, const Money.pesos(2840));
      expect(
        meralco.register,
        ObligationRegister.bill,
        reason: 'a Bill and an Upcoming item for one electricity account',
      );
      expect(meralco.otherRegister, ObligationRegister.upcoming);
      expect(
        meralco.places,
        <String>['Coming Up'],
        reason:
            'three of the four registers are all Coming Up on screen, so '
            'this pair must not read "in Coming Up and Coming Up"',
      );

      final SuspectedDuplicate phone = found.firstWhere(
        (SuspectedDuplicate d) => d.label.contains('Home Credit'),
      );
      expect(phone.amount, const Money.pesos(2450));
      expect(
        phone.label,
        'Home Credit Installment',
        reason:
            'the ENTRY side leads. That is the row the person typed and the '
            'row they will go looking for; a debt minimum is machinery',
      );
      expect(phone.otherLabel, 'Home Credit (Phone)');
      expect(phone.places, <String>[
        'Coming Up',
        'Debts',
      ], reason: 'two real places, in the order the person would check them');
      expect(
        phone.label == phone.otherLabel,
        isFalse,
        reason:
            'the two labels DIFFER, which is why string equality was never '
            'an option and the loose word overlap below has to exist',
      );
    });

    test('the collision that must stay silent is genuinely a collision', () {
      // NOT VACUOUS, and this test exists to prove the silence below means
      // something. A Pru Life VUL premium and a BPI personal loan
      // amortisation, both 2,500, both due the same day, in two different
      // registers. Three of the four clauses match. Only the shared word
      // clause separates them, and this is the collision a Philippine ledger
      // produces constantly, because lenders and insurers quote whole pesos.
      final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));

      final BillItem vul = s.bills.firstWhere(
        (BillItem b) => b.id == 'bill_insurance',
      );
      final Debt loan = s.debts.firstWhere((Debt d) => d.id == 'debt_bpi_loan');

      expect(
        loan.monthlyMinimum,
        vul.amount,
        reason:
            'if these two amounts ever diverge the silence assertion below '
            'starts passing for the wrong reason, so it is checked here',
      );
      // Written in two different FORMATS for the same day, '2026-09-25'
      // against 'Sep 25', which is why the clause compares resolved days and
      // never the stored string.
      final DateTime now = DateTime.utc(2026, 9, 18);
      expect(daysUntil(vul.dueDate, now), daysUntil(loan.dueDate, now));
      expect(daysUntil(vul.dueDate, now), isNotNull);
    });

    test('and it stays silent about it', () {
      final List<SuspectedDuplicate> found = onSeed(DateTime.utc(2026, 9, 18));
      expect(
        found.where(
          (SuspectedDuplicate d) =>
              d.label.contains('Pru Life') || d.otherLabel.contains('Pru Life'),
        ),
        isEmpty,
        reason:
            'an insurance premium is not a loan amortisation. Telling '
            'somebody these are one payment would cost the notice its '
            'credibility, which is permanent',
      );
    });
    test('the answer does not wander with the clock', () {
      // The seed dates itself from today, so a rule keyed on the date the
      // ENGINE PLACED something would find a different set every morning.
      // These pairs are keyed on the date the PERSON WROTE.
      for (final DateTime now in <DateTime>[
        DateTime.utc(2026, 9, 18),
        DateTime.utc(2026, 10, 4),
        DateTime.utc(2027, 3, 20),
      ]) {
        expect(onSeed(now).length, 2, reason: 'on $now');
      }
    });
  });

  group('the four clauses, one at a time', () {
    // Hand-built ledgers, because the seed can only exercise the cases it
    // happens to contain and the near misses are the whole point.
    List<SuspectedDuplicate> pair({
      required String billName,
      required int billPesos,
      required String billDue,
      required String upName,
      required int upPesos,
      required String upDue,
    }) => findDuplicateOutflows(
      bills: <BillItem>[
        BillItem(
          id: 'b1',
          name: billName,
          amount: Money.pesos(billPesos),
          dueDate: billDue,
        ),
      ],
      upcoming: <UpcomingItem>[
        UpcomingItem(
          id: 'u1',
          name: upName,
          amount: Money.pesos(upPesos),
          dueDate: upDue,
          type: UpcomingItemType.bill,
        ),
      ],
      installments: const <InstallmentPlan>[],
      debts: const <Debt>[],
      now: DateTime.utc(2026, 9, 18),
    );

    test('the ordinary case is reported', () {
      expect(
        pair(
          billName: 'Globe Fiber',
          billPesos: 1899,
          billDue: '2026-09-20',
          upName: 'Globe broadband',
          upPesos: 1899,
          upDue: '2026-09-22',
        ),
        hasLength(1),
      );
    });

    test('one centavo apart is two payments', () {
      // No tolerance, deliberately. Five percent produces seven extra pairs
      // on the shipped seed alone.
      final List<SuspectedDuplicate> found = findDuplicateOutflows(
        bills: <BillItem>[
          const BillItem(
            id: 'b1',
            name: 'Globe Fiber',
            amount: Money(189900),
            dueDate: '2026-09-20',
          ),
        ],
        upcoming: <UpcomingItem>[
          const UpcomingItem(
            id: 'u1',
            name: 'Globe broadband',
            amount: Money(189901),
            dueDate: '2026-09-20',
            type: UpcomingItemType.bill,
          ),
        ],
        installments: <InstallmentPlan>[],
        debts: <Debt>[],
        now: DateTime.utc(2026, 9, 18),
      );
      expect(found, isEmpty);
    });

    test('eight days apart is two payments', () {
      // A calendar month is right for income, where there is one sweldo. It
      // is far too wide here: two genuine 5,000 payments in one month are
      // ordinary.
      expect(
        pair(
          billName: 'Globe Fiber',
          billPesos: 1899,
          billDue: '2026-09-20',
          upName: 'Globe broadband',
          upPesos: 1899,
          upDue: '2026-09-28',
        ),
        isEmpty,
      );
      expect(
        pair(
          billName: 'Globe Fiber',
          billPesos: 1899,
          billDue: '2026-09-20',
          upName: 'Globe broadband',
          upPesos: 1899,
          upDue: '2026-09-27',
        ),
        hasLength(1),
        reason: 'seven days is inside the window',
      );
    });

    test('a shared word that names the KIND of thing is not identity', () {
      // Without the noise list these two share "electric" and read as one
      // payment, which is the exact false positive that would teach somebody
      // the line says nothing.
      expect(
        pair(
          billName: 'Meralco Electric Bill',
          billPesos: 2840,
          billDue: '2026-09-20',
          upName: 'Visayan Electric payment',
          upPesos: 2840,
          upDue: '2026-09-20',
        ),
        isEmpty,
      );
    });

    test('a three letter acronym is enough identity', () {
      // "VUL" is three characters and the floor is three for this reason.
      expect(
        pair(
          billName: 'Pru Life VUL',
          billPesos: 2500,
          billDue: '2026-09-20',
          upName: 'VUL premium',
          upPesos: 2500,
          upDue: '2026-09-20',
        ),
        hasLength(1),
      );
    });

    test('an undated obligation is never paired', () {
      // daysUntil cannot read "sometime next week", and a pair placed on a
      // guess is a pair reported on a guess.
      expect(
        pair(
          billName: 'Globe Fiber',
          billPesos: 1899,
          billDue: 'sometime next week',
          upName: 'Globe broadband',
          upPesos: 1899,
          upDue: '2026-09-20',
        ),
        isEmpty,
      );
    });

    test('a paid obligation is behind you, not counted twice ahead of you', () {
      final List<SuspectedDuplicate> found = findDuplicateOutflows(
        bills: <BillItem>[
          const BillItem(
            id: 'b1',
            name: 'Globe Fiber',
            amount: Money.pesos(1899),
            dueDate: '2026-09-20',
            isPaid: true,
          ),
        ],
        upcoming: <UpcomingItem>[
          const UpcomingItem(
            id: 'u1',
            name: 'Globe broadband',
            amount: Money.pesos(1899),
            dueDate: '2026-09-20',
            type: UpcomingItemType.bill,
          ),
        ],
        installments: <InstallmentPlan>[],
        debts: <Debt>[],
        now: DateTime.utc(2026, 9, 18),
      );
      expect(found, isEmpty);
    });

    test('two rows in the SAME register are two real payments', () {
      // People do hold two plans with one provider, and nothing about two
      // bills carrying one name suggests a mistake.
      final List<SuspectedDuplicate> found = findDuplicateOutflows(
        bills: <BillItem>[
          const BillItem(
            id: 'b1',
            name: 'Globe Fiber',
            amount: Money.pesos(1899),
            dueDate: '2026-09-20',
          ),
          const BillItem(
            id: 'b2',
            name: 'Globe Fiber',
            amount: Money.pesos(1899),
            dueDate: '2026-09-20',
          ),
        ],
        upcoming: <UpcomingItem>[],
        installments: <InstallmentPlan>[],
        debts: <Debt>[],
        now: DateTime.utc(2026, 9, 18),
      );
      expect(found, isEmpty);
    });

    test('money coming IN is never a duplicated outflow', () {
      // Income has its own machinery and the opposite policy: it is
      // SUPPRESSED, because counting a salary twice hands somebody cash that
      // is not coming. This function must not reach it from the other side.
      final List<SuspectedDuplicate> found = findDuplicateOutflows(
        bills: <BillItem>[
          const BillItem(
            id: 'b1',
            name: 'Sweldo',
            amount: Money.pesos(32500),
            dueDate: '2026-09-20',
          ),
        ],
        upcoming: <UpcomingItem>[
          const UpcomingItem(
            id: 'u1',
            name: 'Sweldo',
            amount: Money.pesos(32500),
            dueDate: '2026-09-20',
            type: UpcomingItemType.payday,
          ),
        ],
        installments: <InstallmentPlan>[],
        debts: <Debt>[],
        now: DateTime.utc(2026, 9, 18),
      );
      expect(found, isEmpty);
    });
  });

  group('what the GRID counted, not what the ledger holds', () {
    // The narrowing lives in `projectDailyCash`, not in the detector, and the
    // distinction is the one this batch got wrong once. The detector answers
    // "is this one payment written into two registers". The card claims the
    // figure above took it out twice. On the sample ledger those two answers
    // differ by 2,840.
    test('the ledger holds two pairs, the grid counted one', () {
      final DateTime now = DateTime.utc(2026, 9, 18);
      final FinancialState s = FinancialState(clock: now);

      final List<SuspectedDuplicate> inLedger = findDuplicateOutflows(
        bills: s.bills,
        upcoming: s.upcoming,
        installments: s.installments,
        debts: s.debts,
        now: now,
      );
      expect(inLedger, hasLength(2), reason: 'Meralco and Home Credit');

      final DailyProjection p = s.dailyProjection;
      expect(
        p.duplicateOutflows.map((SuspectedDuplicate d) => d.label),
        <String>['Home Credit Installment'],
        reason:
            'Meralco is a Bill dated three days ago and an Upcoming item due '
            'today. The Bill is OVERDUE, so this engine never places it: it '
            'goes in the overdue bucket and the person already sees it in '
            'the not-counted line. Written twice, counted once',
      );
      expect(
        p.duplicateOutflowExtra,
        const Money.pesos(2450),
        reason:
            'the figure on the card. It read 5,290 for one render, which was '
            'the sum of a true pair and a false one',
      );
    });

    test('and the Meralco leg really is sitting in the overdue bucket', () {
      // NOT VACUOUS. If the seed ever dates that Bill forward, the test
      // above starts asserting the wrong thing for the right reason, so the
      // premise is checked rather than assumed.
      final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
      final BillItem meralco = s.bills.firstWhere(
        (BillItem b) => b.id == 'bill_meralco',
      );
      expect(
        daysUntil(meralco.dueDate, DateTime.utc(2026, 9, 18)),
        lessThan(0),
      );
      expect(s.dailyProjection.overdueOutflowCount, greaterThan(0));
    });
  });
}
