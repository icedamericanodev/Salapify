import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/loan.dart';
import 'package:salapify/core/money/loan_products.dart';

/// Golden vectors for the Philippine loan products, produced by running
/// src/utils/loanCalculators.ts under bun.
void main() {
  const double eps = 1e-6;

  group('Pag-IBIG housing', () {
    test('affordable housing is subsidised at 3 percent', () {
      final LoanCalculationResult r = calculatePagIbigHousingLoan(
        program: PagIbigProgram.affordableHousing,
        loanAmount: 750000,
        termYears: 30,
      );
      expect(r.monthlyPayment, 3162.03);
      expect(r.totalInterest, 388330.89);
      expect(r.payoffMonths, 360);
    });

    test('the regular rate is set by the fixing period, and rises with it', () {
      double rate(int fixing) => calculatePagIbigHousingLoan(
            program: PagIbigProgram.regularHousing,
            loanAmount: 2000000,
            termYears: 20,
            fixingPeriodYears: fixing,
          ).monthlyPayment;

      expect(rate(3), 14041.67);
      expect(rate(10), 15656.4);

      // Anything past 10 falls to the 7.75% default, which is the longest and
      // dearest fixing.
      expect(rate(30), 16418.97);
      expect(rate(3), lessThan(rate(10)));
      expect(rate(10), lessThan(rate(30)));
    });

    test('affordable housing beats every regular fixing, as intended', () {
      final double affordable = calculatePagIbigHousingLoan(
        program: PagIbigProgram.affordableHousing,
        loanAmount: 2000000,
        termYears: 20,
      ).monthlyPayment;
      for (final int fixing in <int>[1, 3, 5, 10, 30]) {
        expect(
          affordable,
          lessThan(calculatePagIbigHousingLoan(
            program: PagIbigProgram.regularHousing,
            loanAmount: 2000000,
            termYears: 20,
            fixingPeriodYears: fixing,
          ).monthlyPayment),
        );
      }
    });
  });

  group('bank housing and its repricing stress test', () {
    test('the downpayment comes off before anything is borrowed', () {
      final BankHousingResult r = calculateBankHousingLoan(
        propertyValue: 5000000,
        downpaymentPercent: 20,
        termYears: 20,
        fixedRate: 6.75,
      );
      expect(r.downpaymentAmount, 1000000);
      expect(r.loanPrincipal, 4000000);
      expect(r.monthlyPayment, 30414.56);
    });

    test('repricing shows the jump, which is the point of the calculator', () {
      final BankHousingResult r = calculateBankHousingLoan(
        propertyValue: 5000000,
        downpaymentPercent: 20,
        termYears: 20,
        fixedRate: 6.75,
        repricedRate: 8.5,
        fixedPeriodYears: 5,
      );
      expect(r.repricedMonthlyPayment, 33481.14);
      expect(r.monthlyPaymentJump, closeTo(3066.58, 0.01));
    });

    test('with no repriced rate there is no jump at all', () {
      final BankHousingResult r = calculateBankHousingLoan(
        propertyValue: 5000000,
        downpaymentPercent: 20,
        termYears: 20,
        fixedRate: 6.75,
      );
      expect(r.repricedMonthlyPayment, r.monthlyPayment);
      expect(r.monthlyPaymentJump, 0);
    });
  });

  group('car loan', () {
    test('the real day one cost is never just the downpayment', () {
      final CarLoanResult r = calculateCarLoan(
        vehiclePrice: 1200000,
        downpaymentPercent: 20,
        termMonths: 60,
        annualInterestRate: 9.5,
        rateType: RateType.flatAddon,
        includeInsuranceAndChattel: true,
      );
      expect(r.loanPrincipal, 960000);
      expect(r.chattelMortgageFee, 24000);
      expect(r.comprehensiveInsurance, 28800);

      // 240,000 of downpayment becomes 292,800 once the chattel mortgage and
      // the first year of insurance are counted.
      expect(r.initialCashOut, 292800);
      expect(r.monthlyPayment, 23600);
    });

    test('a balloon is a share of the CAR, not of the loan', () {
      final CarLoanResult r = calculateCarLoan(
        vehiclePrice: 1200000,
        downpaymentPercent: 20,
        termMonths: 36,
        annualInterestRate: 9.5,
        rateType: RateType.flatAddon,
        balloonPercent: 20,
      );
      // 20% of 1,200,000, not of the 960,000 borrowed.
      expect(r.balloonPayment, 240000);
      expect(r.monthlyPayment, 27600);
    });
  });

  group('salary loans', () {
    test('each lender carries its own rate and fee', () {
      final SalaryLoanResult sss = calculateSalaryLoan(
        loanType: SalaryLoanType.sssSalary,
        loanAmount: 100000,
        termMonths: 24,
      );
      expect(sss.annualRate, 10.0);
      expect(sss.processingFee, 1000);
      expect(sss.netProceeds, 99000);
      expect(sss.monthlyPayment, 4614.49);
      expect(sss.effectiveTotalCost, 11748);

      final SalaryLoanResult calamity = calculateSalaryLoan(
        loanType: SalaryLoanType.pagibigCalamity,
        loanAmount: 100000,
        termMonths: 24,
      );
      expect(calamity.annualRate, 5.95);
      expect(calamity.effectiveTotalCost, 6315);
    });

    test('the Pag-IBIG MPL dividend makes the dearest headline the cheapest',
        () {
      final SalaryLoanResult mpl = calculateSalaryLoan(
        loanType: SalaryLoanType.pagibigMpl,
        loanAmount: 100000,
        termMonths: 24,
      );
      expect(mpl.annualRate, 10.5);
      expect(mpl.totalInterest, closeTo(11302.5, 0.01));
      expect(mpl.estimatedDividendRebate, closeTo(2260.5, 0.01));

      // 10.5% is a higher rate than SSS at 10%, and MPL still costs LESS in
      // the end because a fifth of the interest comes back as a dividend and
      // there is no processing fee.
      expect(mpl.effectiveTotalCost, 9042);
      final SalaryLoanResult sss = calculateSalaryLoan(
        loanType: SalaryLoanType.sssSalary,
        loanAmount: 100000,
        termMonths: 24,
      );
      expect(mpl.effectiveTotalCost, lessThan(sss.effectiveTotalCost));
    });

    test('GSIS consolidation is the dearest of the four', () {
      final SalaryLoanResult gsis = calculateSalaryLoan(
        loanType: SalaryLoanType.gsisConso,
        loanAmount: 100000,
        termMonths: 24,
      );
      expect(gsis.annualRate, 12.0);
      expect(gsis.processingFee, 1500);
      expect(gsis.effectiveTotalCost, 14476);
    });
  });

  group('personal loan quoted as a monthly add-on', () {
    test('1.5 percent a month is 54,000 on 150,000 over two years', () {
      final PersonalLoanResult r = calculatePersonalLoan(
        principal: 150000,
        termMonths: 24,
        monthlyAddOnRate: 1.5,
        processingFee: 3000,
      );
      expect(r.monthlyPayment, 8500);
      expect(r.totalInterest, 54000);
      expect(r.totalPayment, 204000);
      expect(r.netCashReceived, 147000);
    });

    test('an add-on rate costs far more than the same rate diminishing', () {
      final double addOn = calculatePersonalLoan(
        principal: 150000,
        termMonths: 24,
        monthlyAddOnRate: 1.5,
        processingFee: 0,
      ).totalInterest;
      final double diminishing = calculateAmortization(
        principal: 150000,
        annualInterestRate: 18,
        termMonths: 24,
      ).totalInterest;
      // 54,000 against about 29,000. This gap is why the distinction matters.
      expect(addOn, greaterThan(diminishing * 1.7));
    });
  });

  group('business loan repayment frequency', () {
    test('the same loan restated daily, weekly and monthly', () {
      BusinessLoanResult at(RepaymentSchedule s) => calculateBusinessLoan(
            principal: 1000000,
            termMonths: 24,
            annualInterestRate: 18,
            repaymentSchedule: s,
            originationFeePercent: 2,
          );

      final BusinessLoanResult monthly = at(RepaymentSchedule.monthly);
      expect(monthly.monthlyPayment, 49924.1);
      expect(monthly.installmentAmount, 49924);
      expect(monthly.totalInstallmentCycles, 24);
      expect(monthly.netDisbursed, 980000);

      expect(at(RepaymentSchedule.weekly).installmentAmount, 11521);
      expect(at(RepaymentSchedule.weekly).totalInstallmentCycles, 104);

      // 260 banking days a year, not 365.
      expect(at(RepaymentSchedule.dailyDebit).installmentAmount, 2304);
      expect(at(RepaymentSchedule.dailyDebit).totalInstallmentCycles, 518);
    });

    test('changing the frequency never changes what is actually owed', () {
      final double a =
          calculateBusinessLoan(
            principal: 1000000,
            termMonths: 24,
            annualInterestRate: 18,
            repaymentSchedule: RepaymentSchedule.monthly,
            originationFeePercent: 2,
          ).totalInterest;
      final double b =
          calculateBusinessLoan(
            principal: 1000000,
            termMonths: 24,
            annualInterestRate: 18,
            repaymentSchedule: RepaymentSchedule.dailyDebit,
            originationFeePercent: 2,
          ).totalInterest;
      expect(a, closeTo(b, eps));
    });
  });

  group('debt consolidation', () {
    test('three debts into one loan', () {
      final ConsolidationResult r = calculateDebtConsolidation(
        debts: const <DebtToConsolidate>[
          DebtToConsolidate(
            id: 'a', name: 'Card A', balance: 80000,
            monthlyInterestRate: 3.0, currentMonthlyPayment: 4000,
          ),
          DebtToConsolidate(
            id: 'b', name: 'Card B', balance: 45000,
            monthlyInterestRate: 3.5, currentMonthlyPayment: 2500,
          ),
          DebtToConsolidate(
            id: 'c', name: 'Loan C', balance: 60000,
            monthlyInterestRate: 2.0, currentMonthlyPayment: 3500,
          ),
        ],
        newLoanMonthlyRate: 1.2,
        newTermMonths: 36,
      );

      expect(r.totalBalance, 185000);
      expect(r.totalCurrentMonthlyPayment, 10000);
      expect(r.newMonthlyPayment, 7358.89);
      expect(r.monthlyCashflowRelief, 2641);
      expect(r.currentTotalInterest, 93150);
      expect(r.newTotalInterest, 79920);
      expect(r.totalInterestSavings, 13230);
    });
  });
}
