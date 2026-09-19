import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/amortization_export.dart';
import 'package:salapify/core/money/loan.dart';

/// The statement a person keeps, and the arithmetic in it.
///
/// This file exists because an exported schedule is the one thing in Salapify
/// somebody opens NEXT TO the letter their bank sent them. A column that is
/// out by a peso, or shifted by one because a loan name had a comma in it, is
/// found by the person least able to shrug it off.
void main() {
  /// A real schedule from the ported engine, not hand written rows: the export
  /// has to survive what the app actually produces.
  LoanCalculationResult loan({double extra = 0}) => calculateAmortization(
    principal: 1500000,
    annualInterestRate: 5.75,
    termMonths: 240,
    extraMonthlyPayment: extra,
  );

  const LoanStatementMeta meta = LoanStatementMeta(
    title: 'Pag-IBIG Housing Loan Statement',
    institution: 'Pag-IBIG Fund (HDMF Circular 449/450)',
    principal: 1500000,
    annualRate: 5.75,
    termLabel: '20 Years',
    monthlyPayment: 10531.25,
    totalInterest: 855171.14,
    totalPayment: 2355171.14,
  );

  group('the annual summary', () {
    test('twelve periods make year one, the thirteenth starts year two', () {
      final List<YearSummary> years = summariseByYear(
        loan().amortizationSchedule,
      );
      expect(years.first.year, 1);
      expect(
        years.first.monthCount,
        12,
        reason: 'ceil(period / 12) is the prototype\'s own bucketing',
      );
      expect(years[1].year, 2);
    });

    test('a year\'s parts add up to the months inside it', () {
      final List<AmortizationRow> schedule = loan().amortizationSchedule;
      final YearSummary first = summariseByYear(schedule).first;

      final List<AmortizationRow> twelve = schedule
          .where((AmortizationRow r) => r.period <= 12)
          .toList();
      expect(
        first.principalPaid,
        closeTo(
          twelve.fold<double>(
            0,
            (double s, AmortizationRow r) => s + r.principalComponent,
          ),
          0.01,
        ),
      );
      expect(
        first.interestPaid,
        closeTo(
          twelve.fold<double>(
            0,
            (double s, AmortizationRow r) => s + r.interestComponent,
          ),
          0.01,
        ),
      );
    });

    test('the year-end balance is the LAST month\'s, not an average', () {
      final List<AmortizationRow> schedule = loan().amortizationSchedule;
      final YearSummary first = summariseByYear(schedule).first;
      final AmortizationRow twelfth = schedule.firstWhere(
        (AmortizationRow r) => r.period == 12,
      );
      expect(first.endingBalance, closeTo(twelfth.remainingBalance, 0.001));
    });

    test('the balance falls every year, and ends at nothing', () {
      final List<YearSummary> years = summariseByYear(
        loan().amortizationSchedule,
      );
      for (int i = 1; i < years.length; i++) {
        expect(
          years[i].endingBalance,
          lessThan(years[i - 1].endingBalance),
          reason: 'year ${years[i].year} owes more than the year before it',
        );
      }
      expect(years.last.endingBalance, lessThan(1));
    });

    test('a final part year keeps its real month count', () {
      // 30 months is two whole years and a six month tail. A tail reported as
      // a year is a row that reads like somebody paid a quarter as much.
      final List<AmortizationRow> schedule = calculateAmortization(
        principal: 100000,
        annualInterestRate: 12,
        termMonths: 30,
      ).amortizationSchedule;
      final List<YearSummary> years = summariseByYear(schedule);
      expect(years, hasLength(3));
      expect(years.last.monthCount, 6);
    });

    test('an empty schedule summarises to nothing rather than throwing', () {
      expect(summariseByYear(const <AmortizationRow>[]), isEmpty);
    });
  });

  group('the CSV', () {
    test('it carries the loan\'s own terms at the top', () {
      final String csv = amortizationCsv(
        schedule: loan().amortizationSchedule,
        meta: meta,
      );
      expect(csv, contains('SALAPIFY 3 - PAG-IBIG HOUSING LOAN STATEMENT'));
      expect(csv, contains('Principal Loan Amount: PHP 1,500,000.00'));
      expect(csv, contains('Interest Rate: 5.75%'));
      expect(csv, contains('Loan Term: 20 Years'));
    });

    test('the columns are the prototype\'s, in its order', () {
      final String csv = amortizationCsv(
        schedule: loan().amortizationSchedule,
        meta: meta,
      );
      expect(
        csv,
        contains(
          'Period #,Due Date / Month,Scheduled Payment (PHP),'
          'Principal Component (PHP),Interest Component (PHP),'
          'Extra / Prepayment (PHP),Total Monthly Outflow (PHP),'
          'Cumulative Principal Paid (PHP),Cumulative Interest Paid (PHP),'
          'Running Balance (PHP)',
        ),
        reason:
            'the whole point of matching the prototype is that the file opens '
            'in the same spreadsheet next to the same columns',
      );
    });

    test('one row per month, plus the header block', () {
      final LoanCalculationResult r = loan();
      final String csv = amortizationCsv(
        schedule: r.amortizationSchedule,
        meta: meta,
      );
      final List<String> lines = csv.split('\r\n');
      // 8 meta lines, a blank, the section title, the header row, then data.
      expect(lines.length, r.amortizationSchedule.length + 11);
    });

    test('the cumulative columns really accumulate', () {
      final List<AmortizationRow> schedule = loan().amortizationSchedule;
      final List<String> lines = amortizationCsv(
        schedule: schedule,
        meta: meta,
      ).split('\r\n');

      // The first data row is line 11 (0-based).
      final List<String> first = lines[11].split(',');
      final List<String> second = lines[12].split(',');

      expect(double.parse(first[7]), closeTo(schedule[0].principalComponent, 0.01));
      expect(
        double.parse(second[7]),
        closeTo(
          schedule[0].principalComponent + schedule[1].principalComponent,
          0.01,
        ),
        reason:
            'cumulative principal that does not cumulate is the one column '
            'nobody can check against a single row of their own statement',
      );
    });

    test('the last running balance is nothing left to pay', () {
      final List<AmortizationRow> schedule = loan().amortizationSchedule;
      final List<String> lines = amortizationCsv(
        schedule: schedule,
        meta: meta,
      ).split('\r\n');
      expect(double.parse(lines.last.split(',').last), lessThan(1));
    });

    test('prepayment savings appear only when there ARE savings', () {
      expect(
        amortizationCsv(schedule: loan().amortizationSchedule, meta: meta),
        isNot(contains('Total Prepayment Interest Saved')),
      );

      final LoanCalculationResult withExtra = loan(extra: 1000);
      final String csv = amortizationCsv(
        schedule: withExtra.amortizationSchedule,
        meta: LoanStatementMeta(
          title: meta.title,
          institution: meta.institution,
          principal: meta.principal,
          annualRate: meta.annualRate,
          termLabel: meta.termLabel,
          monthlyPayment: meta.monthlyPayment,
          totalInterest: withExtra.totalInterest,
          totalPayment: withExtra.totalPayment,
          interestSaved: withExtra.interestSavedWithExtra,
          monthsSaved: withExtra.monthsSavedWithExtra,
        ),
      );
      expect(csv, contains('Total Prepayment Interest Saved'));
      expect(csv, contains('Months Saved / Accelerated Payoff'));
    });

    test('the annual view writes years, not months', () {
      final String csv = amortizationCsv(
        schedule: loan().amortizationSchedule,
        meta: meta,
        view: AmortizationView.annual,
      );
      expect(csv, contains('ANNUAL AMORTIZATION'));
      expect(csv, contains('Year-End Running Balance (PHP)'));
      expect(csv.split('\r\n').length, lessThan(40));
    });

    test('CRLF, because that is what a spreadsheet on Windows expects', () {
      final String csv = amortizationCsv(
        schedule: loan().amortizationSchedule,
        meta: meta,
      );
      expect(csv, contains('\r\n'));
      expect(
        csv.replaceAll('\r\n', ''),
        isNot(contains('\n')),
        reason: 'a stray bare newline splits one row into two',
      );
    });
  });

  group('a field that would break the file', () {
    test('a comma in the loan name is quoted, not left to shift the row', () {
      final String csv = amortizationCsv(
        schedule: loan().amortizationSchedule,
        meta: const LoanStatementMeta(
          title: 'Car, second hand',
          institution: 'BPI, Auto Loans',
          principal: 500000,
          annualRate: 9,
          termLabel: '5 Years',
          monthlyPayment: 10000,
          totalInterest: 100000,
          totalPayment: 600000,
        ),
      );
      expect(csv, contains('"SALAPIFY 3 - CAR, SECOND HAND"'));
      expect(csv, contains('"Institution / Standard: BPI, Auto Loans"'));
    });

    test('a quote in the name is doubled, the way CSV requires', () {
      final String csv = amortizationCsv(
        schedule: const <AmortizationRow>[],
        meta: const LoanStatementMeta(
          title: 'The "cheap" loan',
          institution: 'Somewhere',
          principal: 1,
          annualRate: 1,
          termLabel: '1',
          monthlyPayment: 1,
          totalInterest: 1,
          totalPayment: 1,
        ),
      );
      expect(csv, contains('"SALAPIFY 3 - THE ""CHEAP"" LOAN"'));
    });
  });

  group('the file name', () {
    test('it says which loan and which view', () {
      expect(
        amortizationFileName('Pag-IBIG Housing Loan', AmortizationView.monthly),
        'pag_ibig_housing_loan_monthly_schedule.csv',
      );
      expect(
        amortizationFileName('Auto / Car', AmortizationView.annual),
        'auto_car_yearly_summary.csv',
      );
    });

    test('a name of pure punctuation still produces a usable file name', () {
      expect(
        amortizationFileName('///', AmortizationView.monthly),
        'loan_monthly_schedule.csv',
      );
    });
  });
}
