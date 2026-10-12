import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/loan.dart';

/// An amortisation schedule has to add up.
///
/// Found by a controller's audit on 2026-10-02: it did not, three different
/// ways, and it was live on the Car loan tab's own default inputs.
///
///  - Every one of its sixty rows had `principal + interest != payment`,
///    because the loop rounded two addends and their sum independently.
///  - The TOTAL PAYABLE chip disagreed with the table printed beneath it by
///    0.20, because the totals were accumulated from unrounded values that
///    never saw a row.
///  - The CSV export's header disagreed with its own columns by the same
///    0.20, and that file exists so somebody can lay it beside the letter
///    their bank sent.
///
/// These are EXACT equalities, in centavos, with no tolerance anywhere. A
/// tolerance here is precisely the size of the defect class, so a real error
/// passes through it unnoticed. The previous export tests used
/// `closeTo(..., 0.01)` on sums that are exact and `lessThan(1)` on a final
/// balance that should be zero, which is how this survived.
void main() {
  /// Whole centavos, so comparisons are integer and cannot drift.
  int c(double v) => (v * 100).round();

  /// A grid rather than one fixture. The flat add-on case failed on 100
  /// percent of its rows and the single existing golden never noticed,
  /// because it only ever ran one diminishing loan.
  final List<({String name, LoanCalculationResult r, double principal})> cases =
      <({String name, LoanCalculationResult r, double principal})>[
        (
          name: 'the Car loan tab defaults, flat add-on',
          r: calculateAmortization(
            principal: 880000,
            annualInterestRate: 9.5,
            termMonths: 60,
            rateType: RateType.flatAddon,
          ),
          principal: 880000,
        ),
        (
          name: 'the Bank housing tab defaults, diminishing with extra',
          r: calculateAmortization(
            principal: 2800000,
            annualInterestRate: 6.75,
            termMonths: 180,
            extraMonthlyPayment: 2000,
          ),
          principal: 2800000,
        ),
        (
          name: 'the prototype golden loan',
          r: calculateAmortization(
            principal: 2500000,
            annualInterestRate: 7,
            termMonths: 180,
          ),
          principal: 2500000,
        ),
        (
          name: 'a short high-rate loan',
          r: calculateAmortization(
            principal: 10000,
            annualInterestRate: 36,
            termMonths: 6,
          ),
          principal: 10000,
        ),
        (
          name: 'an interest-free loan',
          r: calculateAmortization(
            principal: 12000,
            annualInterestRate: 0,
            termMonths: 12,
          ),
          principal: 12000,
        ),
        (
          name: 'a sub-peso-per-month rounding edge',
          r: calculateAmortization(
            principal: 1000.03,
            annualInterestRate: 5.25,
            termMonths: 3,
          ),
          principal: 1000.03,
        ),
      ];

  for (final ({String name, LoanCalculationResult r, double principal}) t
      in cases) {
    group(t.name, () {
      final List<AmortizationRow> rows = t.r.amortizationSchedule;

      test('DID ANYTHING HAPPEN', () {
        // The companion, first, because every conservation check below is
        // satisfied perfectly by an empty schedule. Without this the whole
        // file passes hardest when the engine is most broken.
        expect(rows, isNotEmpty);
        expect(t.r.payoffMonths, rows.length);
        expect(t.r.monthlyPayment, greaterThan(0));
        // The balance really walks DOWN, rather than the schedule being a
        // list of identical rows that conserve everything by standing still.
        expect(
          rows.last.remainingBalance,
          lessThan(rows.first.remainingBalance),
        );
      });

      test('every row foots: principal + interest == payment', () {
        for (final AmortizationRow row in rows) {
          expect(
            c(row.principalComponent) + c(row.interestComponent),
            c(row.scheduledPayment),
            reason:
                'row ${row.period} says ${row.principalComponent} + '
                '${row.interestComponent} = ${row.scheduledPayment}',
          );
        }
      });

      test('the balance walks down by exactly the principal paid', () {
        int expected = c(t.principal);
        for (final AmortizationRow row in rows) {
          expected -= c(row.principalComponent) + c(row.extraPayment);
          expect(
            c(row.remainingBalance),
            expected,
            reason: 'the balance drifted from the rows at row ${row.period}',
          );
        }
      });

      test('it lands on exactly zero', () {
        expect(
          c(rows.last.remainingBalance),
          0,
          reason:
              'a residue is left on the last row, so the schedule never '
              'actually clears the loan',
        );
      });

      test('the rows pay off exactly the principal', () {
        int paid = 0;
        for (final AmortizationRow row in rows) {
          paid += c(row.principalComponent) + c(row.extraPayment);
        }
        expect(paid, c(t.principal));
      });

      test('the totals are the sum of the rows', () {
        int payment = 0;
        int interest = 0;
        for (final AmortizationRow row in rows) {
          payment += c(row.scheduledPayment) + c(row.extraPayment);
          interest += c(row.interestComponent);
        }
        expect(
          c(t.r.totalPayment),
          payment,
          reason:
              'the TOTAL PAYABLE chip disagrees with the table printed '
              'underneath it, which is what a person reads first',
        );
        expect(c(t.r.totalInterest), interest);
      });
    });
  }
}
