import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/loan.dart';

/// Golden vectors for the loan port, produced by running
/// src/utils/loanCalculators.ts under bun. Every figure below came out of the
/// prototype; none was computed by hand from an amortization formula.
///
/// ## SIX FIGURES NOW DIVERGE FROM THE PROTYPE, DELIBERATELY (2026-10-02)
///
/// Each one is marked WAS at its assertion. The rule in this repository is
/// that an odd prototype behaviour is reproduced and locked, with the defence
/// in the UI rather than in a quietly corrected number, and the stated
/// exception is where a wrong figure costs real money. A schedule whose rows
/// do not add up is that exception: it is the one artefact in this app a
/// person lays beside a lender's paperwork.
///
/// What was wrong. The loop rounded interest, principal and their sum
/// INDEPENDENTLY on the way into each row, so `principal + interest` did not
/// equal `payment`. On the Car loan tab's own defaults that was true of all
/// sixty rows. Separately, the totals were accumulated from unrounded values
/// that never saw a row, so the TOTAL PAYABLE chip disagreed with the table
/// beneath it by 0.20. These goldens encoded it: the first row below reads
/// 14,583.33 interest against a 22,470.71 payment, and 22,470.71 minus
/// 14,583.33 is 7,887.38, not the 7,887.37 the prototype recorded.
///
/// What is true now, enforced by loan_foots_test.dart across six loan shapes
/// with no tolerance anywhere: every row foots, the balance walks down by
/// exactly the principal paid, the last row lands on exactly zero, and every
/// total is the sum of its rows.
///
/// What was deliberately NOT changed: the balloon case still overruns its
/// stated term, because that is a product behaviour rather than arithmetic.
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
      expect(
        r.totalPayment,
        4044726.78,
      ); // WAS 4044727.22, now the sum of the rows
      expect(
        r.totalInterest,
        1544726.78,
      ); // WAS 1544727.22, now the sum of the rows
      expect(r.payoffMonths, 180);
      expect(r.amortizationSchedule.length, 180);
    });

    test(
      'the first row is mostly interest and the last is mostly principal',
      () {
        final AmortizationRow first = r.amortizationSchedule.first;
        expect(first.interestComponent, 14583.33);
        expect(
          first.principalComponent,
          7887.38,
        ); // WAS 7887.37, now foots with the payment
        expect(
          first.remainingBalance,
          2492112.62,
        ); // WAS ...63, follows the corrected principal

        final AmortizationRow last = r.amortizationSchedule.last;
        // WAS 130.32. The balance this is charged on walks down from the
        // corrected first row, so it arrives a centavo lower.
        expect(last.interestComponent, 130.31);
        // WAS 22340.39. Each row's principal is now derived from the payment
        // rather than rounded on its own, so a little more lands in the
        // earlier rows and the final one is correspondingly smaller. The
        // schedule still pays off exactly 2,500,000.00, which
        // loan_foots_test.dart asserts on this very loan.
        expect(last.principalComponent, 22339.38);
        expect(last.remainingBalance, 0);
      },
    );

    test(
      'the loan actually finishes, which a schedule can silently fail to do',
      () {
        expect(r.amortizationSchedule.last.remainingBalance, 0);
      },
    );
  });

  group('flat add-on, the convention car and appliance dealers quote', () {
    final LoanCalculationResult flat = calculateAmortization(
      principal: 800000,
      annualInterestRate: 9.5,
      termMonths: 60,
      rateType: RateType.flatAddon,
    );

    test(
      'every month carries the same interest, on the ORIGINAL principal',
      () {
        expect(flat.monthlyPayment, 19666.67);
        expect(flat.totalInterest, 380000);

        // The defining property: interest never falls, because it is charged on
        // what was borrowed rather than on what is still owed.
        expect(flat.amortizationSchedule.first.interestComponent, 6333.33);
        // WAS 6333.33. THE LAST ROW ABSORBS THE CONTRACT REMAINDER, and this
        // one is a judgement about lending practice rather than arithmetic,
        // so it is spelled out.
        //
        // A flat add-on quotes a TOTAL: 380,000.00 here, and the line above
        // asserts the app still reports exactly that. The true monthly share
        // is 6,333.333..., so charging the rounded 6,333.33 sixty times adds
        // up to 379,999.80 and the schedule contradicts the contract. The
        // instalment engine already answers this the same way, in its own
        // words, the final instalment absorbs the whole difference, and a
        // real dealer's final payment adjusts for exactly this reason.
        //
        // The property this test is named for still holds: interest never
        // FALLS. It rises by 0.20 on the final row.
        expect(flat.amortizationSchedule.last.interestComponent, 6333.53);
      },
    );

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
      expect(
        r.interestSavedWithExtra,
        47055.35,
      ); // WAS 47055.37, follows the summed interest
      expect(
        r.totalInterest,
        120278.08,
      ); // WAS 120278.06, now the sum of the rows
    });

    test('the final extra is trimmed so the loan cannot overpay itself', () {
      // 1,900.22 rather than the full 3,000: the last instalment only takes
      // what is left.
      expect(r.amortizationSchedule.last.extraPayment, 1900.40); // WAS 1900.22
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

    test(
      'a zero principal returns an empty result rather than dividing by it',
      () {
        final LoanCalculationResult r = calculateAmortization(
          principal: 0,
          annualInterestRate: 10,
          termMonths: 24,
        );
        expect(r.monthlyPayment, 0);
        expect(r.amortizationSchedule, isEmpty);
        expect(r.payoffMonths, 0);
      },
    );

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
      expect(
        r.totalPayment,
        1244329.22,
      ); // WAS 1244329.18, now the sum of the rows
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
      // 24,000 and 1,557,583 since P1.7, not 28,000 and 2,002,607. The
      // recommended ceiling was 35% of gross, the FOURTH debt to income figure
      // in the app and the only one nothing else agreed with. Founder decision
      // F8 made it 30%, the one rule now in core/money/debt_ratio.dart.
      //
      // A deliberate divergence from the prototype, like the SSS schedule and
      // the 8% election before it. Both figures were worked out by hand from
      // the 180 month annuity at 7% before this file was touched, and the same
      // hand calculation reproduces the OLD pair exactly at 0.35, which is
      // what makes them trustworthy rather than copied off a failing run.
      expect(r.maxRecommendedMonthlyDebt, 24000);
      expect(r.maxBorrowingCapacity30Yr, 1557583);
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
        expect(
          paidPrincipal,
          closeTo(300000, 1),
          reason: 'the schedule must repay exactly what was borrowed',
        );
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
