import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/installments.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/true_rate.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Net-new money math, so it is proven against arithmetic rather than replayed
/// from the prototype: the prototype has no equivalent, it reprints the
/// lender's add-on rate.
///
/// The decisive test is the SANITY one. A loan that genuinely charges 1.5% a
/// month on the diminishing balance must solve back to exactly 1.5%. If the
/// solver cannot recover a rate it was given, nothing else it says is worth
/// reading.
List<Money> _payments(InstallmentPlan p) {
  final InstallmentSchedule s = scheduleFor(p);
  return <Money>[for (int i = 0; i < s.count; i++) s.instalmentAt(i)];
}

InstallmentPlan _plan(String id) => SeedData.installments(
  DateTime(2026, 9, 18),
).firstWhere((InstallmentPlan p) => p.id == id);

void main() {
  group('the solver recovers a rate it was given', () {
    test('a genuine 1.5 percent a month diminishing loan solves back', () {
      // A = P x r / (1 - (1+r)^-n), the standard amortisation formula. Twelve
      // payments of 2,246.16 on 24,500 IS a 1.5% a month loan, by
      // construction. The solver has to say so.
      const Money principal = Money.pesos(24500);
      final List<Money> level = <Money>[
        for (int i = 0; i < 12; i++) const Money.of(2246, 16),
      ];
      final double? r = trueMonthlyRate(principal: principal, payments: level);

      expect(r, isNotNull);
      expect(r! * 100, closeTo(1.5, 0.001));
    });

    test(
      'and the same loan as an ADD-ON costs far more for the same words',
      () {
        // The whole point, in one comparison. Same principal, same term, same
        // quoted "1.5% a month".
        const Money principal = Money.pesos(24500);

        final List<Money> diminishing = <Money>[
          for (int i = 0; i < 12; i++) const Money.of(2246, 16),
        ];
        final List<Money> addOn = _payments(_plan('inst_home_credit'));

        expect(sumMoney(diminishing), const Money.of(26953, 92));
        expect(sumMoney(addOn), const Money.pesos(28910));

        final double real = trueMonthlyRate(
          principal: principal,
          payments: diminishing,
        )!;
        final double quoted = trueMonthlyRate(
          principal: principal,
          payments: addOn,
        )!;
        expect(
          quoted > real * 1.7,
          isTrue,
          reason:
              'the add-on plan should cost well over half as much again, and '
              'the app used to print the same 18% a year for both',
        );
      },
    );
  });

  group('the seeded plans, measured', () {
    test('Home Credit: 1.5 a month quoted, about 2.6 a month real', () {
      final InstallmentPlan p = _plan('inst_home_credit');
      final double? monthly = trueMonthlyRate(
        principal: p.principal,
        payments: _payments(p),
      );
      expect(monthly, isNotNull);
      expect(monthly! * 100, closeTo(2.643, 0.01));
      expect(
        trueAnnualRate(principal: p.principal, payments: _payments(p))! * 100,
        closeTo(31.7, 0.1),
        reason: 'the screen used to say 18.0% a year for this plan',
      );
    });

    test('SPayLater: 2.95 a month quoted, about 4.9 a month real', () {
      final InstallmentPlan p = _plan('inst_spaylater');
      final double? monthly = trueMonthlyRate(
        principal: p.principal,
        payments: _payments(p),
      );
      expect(monthly! * 100, closeTo(4.865, 0.01));
    });

    test('a genuine 0 percent plan is exactly zero, not nearly zero', () {
      // It must LAND on zero rather than drift to whatever a bisection
      // converges on, because "this costs you nothing" is a real claim about
      // somebody's money and the BPI plan genuinely costs nothing.
      final InstallmentPlan p = _plan('inst_bpi_sip');
      expect(sumMoney(_payments(p)), p.principal);
      expect(
        trueMonthlyRate(principal: p.principal, payments: _payments(p)),
        0,
      );
      expect(trueAnnualRate(principal: p.principal, payments: _payments(p)), 0);
    });
  });

  group('it refuses rather than inventing a number', () {
    test(
      'no principal, no payments, or paying back less than you borrowed',
      () {
        expect(
          trueMonthlyRate(
            principal: Money.zero,
            payments: const <Money>[Money.pesos(100)],
          ),
          isNull,
        );
        expect(
          trueMonthlyRate(
            principal: const Money.pesos(1000),
            payments: const <Money>[],
          ),
          isNull,
        );
        expect(
          // Paying back less than was borrowed is not a loan, and a negative
          // cost of credit is not something this screen can explain.
          trueMonthlyRate(
            principal: const Money.pesos(1000),
            payments: const <Money>[Money.pesos(900)],
          ),
          isNull,
        );
      },
    );

    test('a single balloon payment still works', () {
      // 1,100 repaid once against 1,000 borrowed is 10% for that one period.
      final double? r = trueMonthlyRate(
        principal: const Money.pesos(1000),
        payments: const <Money>[Money.pesos(1100)],
      );
      expect(r! * 100, closeTo(10.0, 0.0001));
    });
  });

  group('the answer is stable', () {
    test('adjusting the final payment by a centavo barely moves it', () {
      // The schedule puts the rounding remainder on the last instalment. If
      // that moved the headline rate the figure would flicker between two
      // plans that cost the same.
      const Money principal = Money.pesos(24500);
      final List<Money> level = <Money>[
        for (int i = 0; i < 12; i++) const Money.of(2409, 17),
      ];
      final List<Money> adjusted = <Money>[
        for (int i = 0; i < 11; i++) const Money.of(2409, 17),
        const Money.of(2409, 13),
      ];
      final double a = trueMonthlyRate(principal: principal, payments: level)!;
      final double b = trueMonthlyRate(
        principal: principal,
        payments: adjusted,
      )!;
      expect((a - b).abs() * 100, lessThan(0.001));
    });
  });
}
