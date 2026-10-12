import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/safe_to_spend.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

import '../../support/test_clock.dart';

/// P2.4, what a debt really costs each month.
///
/// The engine held back `debtsIOwe * 0.08`, the prototype's own rule
/// (`archive/prototype-google-ai-studio/src/utils/safeToSpendEngine.ts:57`), and a percentage of a BALANCE is not
/// a monthly payment. It is wrong in BOTH directions, which reading the sample
/// ledger showed rather than the review:
///
///   - too SMALL for a short loan. The seed's two debts are both scheduled and
///     really cost 4,950 a month between them, against 1,388 for the
///     percentage;
///   - too LARGE for a debt with no schedule, where it invents an obligation
///     nobody ever agreed to.
///
/// Founder decision 2026-10-04: a debt with no minimum and no schedule
/// reserves nothing, and Salapify never assumes a percentage.
void main() {
  Debt owed({
    String id = 'd1',
    Money total = const Money.pesos(10000),
    Money paid = Money.zero,
    DebtSchedule schedule = DebtSchedule.flexible,
    int? current,
    int? totalInstalments,
    Money? minimum,
    bool settled = false,
  }) => Debt(
    id: id,
    person: 'Somebody',
    direction: DebtDirection.iOwe,
    totalAmount: total,
    paidAmount: paid,
    isSettled: settled,
    schedule: schedule,
    installmentCurrent: current,
    installmentTotal: totalInstalments,
    minimumPayment: minimum,
  );

  group('the rule, one branch at a time', () {
    test('an entered minimum wins over everything else', () {
      // Including over a schedule that would have derived a different figure,
      // because the person knows their own lender and the app does not.
      final Debt d = owed(
        schedule: DebtSchedule.scheduled,
        current: 1,
        totalInstalments: 5,
        minimum: const Money.pesos(900),
      );
      expect(d.monthlyMinimum, const Money.pesos(900));
    });

    test('a scheduled debt divides what is LEFT by the instalments LEFT', () {
      // 10,000 total, 4,000 paid, 2 of 5 instalments gone. 6,000 over 3.
      final Debt d = owed(
        paid: const Money.pesos(4000),
        schedule: DebtSchedule.scheduled,
        current: 2,
        totalInstalments: 5,
      );
      expect(d.monthlyMinimum, const Money.pesos(2000));
    });

    test('a flexible debt reserves NOTHING, which is the whole decision', () {
      final Debt d = owed();
      expect(
        d.monthlyMinimum,
        isNull,
        reason:
            'utang to a relative has no monthly minimum and never did, and '
            'charging somebody for one invents an obligation they never '
            'agreed to',
      );
    });

    test('a scheduled debt with no instalment numbers reserves nothing', () {
      // The schedule says there is one, but nothing says what it is. Guessing
      // here would be the same sin in a smaller place.
      expect(owed(schedule: DebtSchedule.scheduled).monthlyMinimum, isNull);
    });

    test('a settled debt reserves nothing, whatever it carries', () {
      final Debt d = owed(
        settled: true,
        minimum: const Money.pesos(900),
        schedule: DebtSchedule.scheduled,
        current: 1,
        totalInstalments: 5,
      );
      expect(d.monthlyMinimum, isNull);
    });

    test('the last instalment reserves the WHOLE remainder', () {
      // 3 of 3 paid but still carrying a balance, which a rounding remainder
      // or a part payment can produce. Dividing by zero instalments left must
      // not happen, and under-reserving the final payment would be worse than
      // the bug this replaces.
      final Debt d = owed(
        total: const Money.pesos(5000),
        paid: const Money.pesos(4000),
        schedule: DebtSchedule.scheduled,
        current: 3,
        totalInstalments: 3,
      );
      expect(d.monthlyMinimum, const Money.pesos(1000));
    });

    test('an explicit zero is respected and is NOT the same as null', () {
      // "This genuinely costs nothing a month" is a real claim, and a
      // different one from "nobody has said". Money.zero cannot express the
      // second, which is why the field is nullable.
      expect(owed(minimum: Money.zero).monthlyMinimum, Money.zero);
      expect(owed().monthlyMinimum, isNull);
    });
  });

  group('the total, and what it replaces', () {
    test('the seed reserves what its loans really cost, not 8 percent', () {
      final List<Debt> debts = SeedData.debts(testToday);

      // Home Credit: 7,350 over 3 instalments left = 2,450.
      // BPI loan:   10,000 over 4 instalments left = 2,500.
      expect(monthlyDebtMinimums(debts), const Money.pesos(4950));

      // What the prototype would have held back, computed here rather than
      // quoted, so this cannot drift from the fixture.
      final double iOwe = debts
          .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
          .fold<double>(0, (double s, Debt d) => s + d.remaining.pesos);
      expect(iOwe * 0.08, 1388.0);

      // DIRECTIONAL. The old rule UNDER-reserved by 3,562 against two real
      // loans, which is the half the review did not name.
      expect(monthlyDebtMinimums(debts).pesos, greaterThan(iOwe * 0.08));
    });

    test('money owed TO you is never reserved against your spending', () {
      final List<Debt> mixed = <Debt>[
        // 10,000 with none of its 2 instalments paid, so 5,000 a month.
        owed(
          id: 'mine',
          schedule: DebtSchedule.scheduled,
          current: 0,
          totalInstalments: 2,
        ),
        // Five times the size, and it must contribute nothing.
        const Debt(
          id: 'theirs',
          person: 'Kuya',
          direction: DebtDirection.owedToMe,
          totalAmount: Money.pesos(50000),
          paidAmount: Money.zero,
          isSettled: false,
          schedule: DebtSchedule.scheduled,
          installmentCurrent: 0,
          installmentTotal: 2,
        ),
      ];
      expect(
        monthlyDebtMinimums(mixed),
        const Money.pesos(5000),
        reason:
            'a debt owed to you is not something you have to find every '
            'month, and counting it reserves your money against somebody '
            'else obligation',
      );
    });

    test('a ledger of only family utang reserves nothing at all', () {
      expect(
        monthlyDebtMinimums(<Debt>[
          owed(id: 'a', total: const Money.pesos(20000)),
          owed(id: 'b', total: const Money.pesos(5000)),
        ]),
        Money.zero,
      );
    });
  });

  group('the engine takes the real figure', () {
    SafeToSpendAnalysis run({double? declared}) => computeSafeToSpend(
      accounts: const <Account>[
        Account(
          id: 'a',
          name: 'GCash',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: Money.pesos(60000),
          monogram: 'GC',
        ),
      ],
      transactions: const <Transaction>[],
      bills: const <BillItem>[],
      debtsIOwe: 17350,
      declaredDebtMinimums: declared,
      installments: const <InstallmentPlan>[],
      incomeStreams: const <IncomeStream>[],
      payday: PaydayCycle.unset,
      scenario: DecisionScenario.conservative,
      now: DateTime.utc(2026, 10, 4),
    );

    test('with a declared figure it reserves THAT, not the percentage', () {
      expect(run(declared: 4950).reservedDebtMinimums, const Money.pesos(4950));
    });

    test('with none declared it still reproduces the prototype exactly', () {
      // This is what keeps the golden vectors honest: the 8 percent branch is
      // reachable, so those vectors go on proving the port rather than
      // proving a fixture.
      expect(run().reservedDebtMinimums, const Money.pesos(1388));
    });

    test('a negative declared figure cannot credit somebody', () {
      expect(run(declared: -500).reservedDebtMinimums, Money.zero);
    });

    test('reserving MORE leaves LESS to spend, and the difference is the '
        'difference', () {
      final SafeToSpendAnalysis old = run();
      final SafeToSpendAnalysis now = run(declared: 4950);
      expect(now.safeToSpendUntilPayday, lessThan(old.safeToSpendUntilPayday));
      expect(
        now.amountReserved - old.amountReserved,
        const Money.pesos(3562),
        reason: '4,950 less 1,388, to the peso',
      );
    });
  });

  group('a monthly cost cannot be bigger than the debt, or smaller than '
      'nothing', () {
    test('an entered minimum is capped at what is actually left', () {
      // Reachable with no file editing at all: add a card with a 3,000
      // minimum, then pay it down with the payment sheet until 500 is left.
      // Before this cap Salapify held back the full 3,000 against a 500
      // debt, told the person they ran short on the 15th, and took 2,500 off
      // Safe to Spend that was really theirs to use.
      final Debt nearlyPaid = owed(
        total: const Money.pesos(60000),
        paid: const Money.pesos(59500),
        minimum: const Money.pesos(3000),
      );
      expect(nearlyPaid.remaining, const Money.pesos(500));
      expect(nearlyPaid.monthlyMinimum, const Money.pesos(500));
    });

    test("a NEGATIVE minimum cannot net off another debt's real one", () {
      // monthlyDebtMinimums SUMS, and computeSafeToSpend clamps only the
      // total, so it could never see one debt cancelling another. A single
      // minus sign typed into one card silenced every other debt's reserve.
      final Money sum = monthlyDebtMinimums(<Debt>[
        owed(id: 'real', minimum: const Money.pesos(5000)),
        owed(id: 'typo', minimum: const Money.pesos(-5000)),
      ]);
      expect(sum, const Money.pesos(5000));
    });

    test('an ABSENT instalment counter is read off the payments, not '
        'assumed to be zero', () {
      // debtToJson writes installmentCurrent only when it is not null, so a
      // debt restored from a backup written before the key existed comes
      // back with real payments and no counter. Reading that as "none have
      // run" spread the last 2,000 of a 12,000 plan over all six
      // instalments and reserved 333.34, a sixth of the true cost, forever,
      // because the null round-trips straight back into the next backup.
      final Debt restored = owed(
        total: const Money.pesos(12000),
        paid: const Money.pesos(10000),
        schedule: DebtSchedule.scheduled,
        totalInstalments: 6,
      );
      expect(restored.installmentCurrent, isNull);
      expect(restored.monthlyMinimum, const Money.pesos(2000));
    });

    test('a NEGATIVE counter does not stretch the plan past its own '
        'term', () {
      // Without the clamp this spreads 12,000 over NINE instalments of a six
      // month plan and reserves 1,333.34 a month for a debt that really
      // costs 2,000. Only a corrupted or hand-edited file reaches it.
      final Debt corrupt = owed(
        total: const Money.pesos(12000),
        schedule: DebtSchedule.scheduled,
        totalInstalments: 6,
        current: -3,
      );
      expect(corrupt.monthlyMinimum, const Money.pesos(2000));
    });

    test('a counter past the end of its own term reserves the arrears', () {
      // DOCUMENTS behaviour rather than guarding the upper clamp, and the
      // difference is the point: deleting that clamp does not change this
      // answer, because the `left < 1 ? 1` floor already absorbs a negative
      // divisor. Said plainly here rather than left as a test that passes
      // whatever the code does.
      //
      // The term has run out with 12,000 still on it, so the whole remainder
      // really is due now.
      final Debt corrupt = owed(
        total: const Money.pesos(12000),
        schedule: DebtSchedule.scheduled,
        totalInstalments: 6,
        current: 9,
      );
      expect(corrupt.monthlyMinimum, const Money.pesos(12000));
    });
  });

  group('the stored shape', () {
    test('a minimum survives a round trip', () {
      final Debt back = debtFromJson(
        debtToJson(owed(minimum: const Money.pesos(1200))),
      );
      expect(back.minimumPayment, const Money.pesos(1200));
    });

    test('absent reads as null, and nothing is written for it', () {
      final Map<String, dynamic> m = debtToJson(owed());
      expect(
        m.containsKey('minimumPayment'),
        isFalse,
        reason:
            'a debt nobody has touched must encode byte for byte as it always '
            'did, or every existing backup differs for no reason',
      );
      expect(debtFromJson(m).minimumPayment, isNull);
    });

    test('an explicit zero survives, because it is not the same as absent', () {
      final Map<String, dynamic> m = debtToJson(owed(minimum: Money.zero));
      expect(m['minimumPayment'], 0);
      expect(debtFromJson(m).minimumPayment, Money.zero);
    });

    test('the key is declared, so clearing it cannot be undone by the '
        'sidecar', () {
      // The paidBeforeSettle lesson, applied before it can bite: a key this
      // build writes but does not DECLARE gets filed as a stranger's field,
      // and the `{...kept, ...own}` merge then hands a cleared value back on
      // the next launch.
      expect(debtKeys, contains('minimumPayment'));
    });
  });
}
