import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/loan.dart';

/// Golden vectors for the loan port, produced by running
/// src/utils/loanCalculators.ts under bun. Every figure below came out of the
/// prototype; none was computed by hand from an amortization formula.
void main() {
  const double eps = 1e-6;

  group('diminishing balance, a 2.5M housing loan at 7% over 15 years', () {
    final LoanCalculationResult r = calculateAmortization(
      principal: 2500000,
      annualInterestRate: 7,
      termMonths: 180,
    );

    test('the headline figures', () {
      expect(r.monthlyPayment, 22470.71);
      expect(r.totalPayment, 4044727.22);
      expect(r.totalInterest, 1544727.22);
      expect(r.payoffMonths, 180);
      expect(r.amortizationSchedule.length, 180);
    });

    test('the first row is mostly interest and the last is mostly principal',
        () {
      final AmortizationRow first = r.amortizationSchedule.first;
      expect(first.interestComponent, 14583.33);
      expect(first.principalComponent, 7887.37);
      expect(first.remainingBalance, 2492112.63);

      final AmortizationRow last = r.amortizationSchedule.last;
      expect(last.interestComponent, 130.32);
      expect(last.principalComponent, 22340.39);
      expect(last.remainingBalance, 0);
    });

    test('the loan actually finishes, which a schedule can silently fail to do',
        () {
      expect(r.amortizationSchedule.last.remainingBalance, 0);
    });
  });

  group('flat add-on, the convention car and appliance dealers quote', () {
    final LoanCalculationResult flat = calculateAmortization(
      principal: 800000,
      annualInterestRate: 9.5,
      termMonths: 60,
      rateType: RateType.flatAddon,
    );

    test('every month carries the same interest, on the ORIGINAL principal',
        () {
      expect(flat.monthlyPayment, 19666.67);
      expect(flat.totalInterest, 380000);

      // The defining property: interest never falls, because it is charged on
      // what was borrowed rather than on what is still owed.
      expect(flat.amortizationSchedule.first.interestComponent, 6333.33);
      expect(flat.amortizationSchedule.last.interestComponent, 6333.33);
    });

    test('flat add-on costs far more than the same rate diminishing', () {
      final LoanCalculationResult diminishing = calculateAmortization(
        principal: 800000,
        annualInterestRate: 9.5,
        termMonths: 60,
      );
      // Roughly double the interest for an identical headline rate. This is the
      // comparison the calculator exists to make visible.
      expect(flat.totalInterest, greaterThan(diminishing.totalInterest * 1.8));
    });
  });

  group('extra payments', () {
    final LoanCalculationResult r = calculateAmortization(
      principal: 500000,
      annualInterestRate: 12,
      termMonths: 60,
      extraMonthlyPayment: 3000,
    );

    test('3,000 a month clears a 5 year loan in 44 months', () {
      expect(r.payoffMonths, 44);
      expect(r.monthsSavedWithExtra, 16);
      expect(r.interestSavedWithExtra, 47055.37);
      expect(r.totalInterest, 120278.06);
    });

    test('the final extra is trimmed so the loan cannot overpay itself', () {
      // 1,900.22 rather than the full 3,000: the last instalment only takes
      // what is left.
      expect(r.amortizationSchedule.last.extraPayment, 1900.22);
      expect(r.amortizationSchedule.last.remainingBalance, 0);
    });

    test('with no extra payment nothing is reported as saved', () {
      final LoanCalculationResult plain = calculateAmortization(
        principal: 500000,
        annualInterestRate: 12,
        termMonths: 60,
      );
      expect(plain.interestSavedWithExtra, 0);
      expect(plain.monthsSavedWithExtra, 0);
      expect(plain.payoffMonths, 60);
    });
  });

  group('edge cases', () {
    test('a zero interest loan is the principal split evenly', () {
      final LoanCalculationResult r = calculateAmortization(
        principal: 120000,
        annualInterestRate: 0,
        termMonths: 12,
      );
      expect(r.monthlyPayment, 10000);
      expect(r.totalInterest, 0);
      expect(r.totalPayment, 120000);
      expect(r.amortizationSchedule.length, 12);
    });

    test('a zero principal returns an empty result rather than dividing by it',
        () {
      final LoanCalculationResult r = calculateAmortization(
        principal: 0,
        annualInterestRate: 10,
        termMonths: 24,
      );
      expect(r.monthlyPayment, 0);
      expect(r.amortizationSchedule, isEmpty);
      expect(r.payoffMonths, 0);
    });

    test('a balloon lowers the instalment and OVERRUNS the stated term', () {
      final LoanCalculationResult r = calculateAmortization(
        principal: 900000,
        annualInterestRate: 8,
        termMonths: 36,
        balloonPayment: 200000,
      );
      expect(r.monthlyPayment, 23268.79);

      // 45 months on a 36 month term. The instalment is sized to leave the
      // balloon outstanding at month 36, but the schedule keeps amortising
      // until the balance reaches zero instead of stopping and charging it.
      // That is the prototype's behaviour, captured here rather than fixed,
      // because changing it would move money on a screen.
      expect(r.payoffMonths, 45);
      expect(r.totalPayment, 1244329.18);
    });
  });

  group('debt service ratio against the BSP bands', () {
    test('under 30 percent is healthy', () {
      final DsrResult r = calculateDsr(
        monthlyDebtObligations: 10000,
        grossMonthlyIncome: 80000,
      );
      expect(r.dsr, 12.5);
      expect(r.status, AffordabilityStatus.healthy);
      expect(r.maxRecommendedMonthlyDebt, 28000);
      expect(r.maxBorrowingCapacity30Yr, 2002607);
    });

    test('exactly 30 percent is already moderate, not healthy', () {
      final DsrResult r = calculateDsr(
        monthlyDebtObligations: 24000,
        grossMonthlyIncome: 80000,
      );
      expect(r.dsr, 30);
      expect(r.status, AffordabilityStatus.moderate);
    });

    test('over 40 percent is stretched and borrowing capacity is gone', () {
      final DsrResult r = calculateDsr(
        monthlyDebtObligations: 40000,
        grossMonthlyIncome: 80000,
      );
      expect(r.dsr, 50);
      expect(r.status, AffordabilityStatus.stretched);
      expect(r.maxBorrowingCapacity30Yr, 0);
    });

    test('no income asks for income rather than dividing by zero', () {
      final DsrResult r = calculateDsr(
        monthlyDebtObligations: 5000,
        grossMonthlyIncome: 0,
      );
      expect(r.dsr, 0);
      expect(r.maxBorrowingCapacity30Yr, 0);
      expect(r.advice, contains('Enter gross monthly income'));
    });
  });

  group('invariants that must hold for any loan', () {
    test('principal components always sum back to the principal', () {
      for (final double rate in <double>[0, 5, 12, 24]) {
        final LoanCalculationResult r = calculateAmortization(
          principal: 300000,
          annualInterestRate: rate,
          termMonths: 24,
        );
        final double paidPrincipal = r.amortizationSchedule.fold<double>(
          0,
          (double s, AmortizationRow row) =>
              s + row.principalComponent + row.extraPayment,
        );
        expect(paidPrincipal, closeTo(300000, 1),
            reason: 'the schedule must repay exactly what was borrowed');
      }
    });

    test('a higher rate always costs more interest over the same term', () {
      double previous = -1;
      for (final double rate in <double>[0, 6, 12, 18, 24]) {
        final double interest = calculateAmortization(
          principal: 300000,
          annualInterestRate: rate,
          termMonths: 36,
        ).totalInterest;
        expect(interest, greaterThan(previous));
        previous = interest;
      }
    });

    test('every balance in a schedule falls, never rises', () {
      final LoanCalculationResult r = calculateAmortization(
        principal: 750000,
        annualInterestRate: 9,
        termMonths: 48,
      );
      double previous = double.infinity;
      for (final AmortizationRow row in r.amortizationSchedule) {
        expect(row.remainingBalance, lessThan(previous + eps));
        previous = row.remainingBalance;
      }
    });
  });
}
