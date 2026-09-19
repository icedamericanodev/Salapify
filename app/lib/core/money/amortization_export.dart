import 'loan.dart';

/// Turning an amortisation schedule into something a person can keep.
///
/// Ported from `handleExportCSV` and the `yearlySummary` memo in
/// `src/components/BankAmortizationTable.tsx`. Pure functions on purpose: the
/// screen decides when to export, this decides what the file says, and the
/// tests can read every byte of it without a widget in sight.
///
/// The CSV is deliberately the PROTOTYPE'S, column for column, because the
/// point of a statement is that somebody can open it in Excel beside the one
/// their bank sent and compare rows.

/// One year of the schedule, rolled up.
class YearSummary {
  const YearSummary({
    required this.year,
    required this.totalPayment,
    required this.principalPaid,
    required this.interestPaid,
    required this.extraPaid,
    required this.endingBalance,
    required this.monthCount,
  });

  final int year;
  final double totalPayment;
  final double principalPaid;
  final double interestPaid;
  final double extraPaid;

  /// The balance after the LAST month of the year, not an average.
  final double endingBalance;
  final int monthCount;
}

/// Groups the schedule into years of twelve periods.
///
/// `ceil(period / 12)` is the prototype's own bucketing, so period 1 to 12 is
/// year 1 and period 13 is year 2. A final part year keeps whatever months it
/// has rather than being padded or dropped, which is why [monthCount] is here:
/// a "year" of four months is a real row and saying so stops it reading like
/// a year where somebody paid a third as much.
List<YearSummary> summariseByYear(List<AmortizationRow> schedule) {
  final Map<int, _YearAccumulator> years = <int, _YearAccumulator>{};

  for (final AmortizationRow row in schedule) {
    final int year = (row.period / 12).ceil();
    final _YearAccumulator acc = years.putIfAbsent(
      year,
      () => _YearAccumulator(year),
    );
    acc.totalPayment += row.scheduledPayment + row.extraPayment;
    acc.principalPaid += row.principalComponent;
    acc.interestPaid += row.interestComponent;
    acc.extraPaid += row.extraPayment;
    // Last one wins, which is what "year end" means.
    acc.endingBalance = row.remainingBalance;
    acc.monthCount++;
  }

  final List<int> ordered = years.keys.toList()..sort();
  return <YearSummary>[
    for (final int y in ordered) years[y]!.build(),
  ];
}

class _YearAccumulator {
  _YearAccumulator(this.year);

  final int year;
  double totalPayment = 0;
  double principalPaid = 0;
  double interestPaid = 0;
  double extraPaid = 0;
  double endingBalance = 0;
  int monthCount = 0;

  YearSummary build() => YearSummary(
    year: year,
    totalPayment: totalPayment,
    principalPaid: principalPaid,
    interestPaid: interestPaid,
    extraPaid: extraPaid,
    endingBalance: endingBalance,
    monthCount: monthCount,
  );
}

/// Which of the two statements to write.
enum AmortizationView { monthly, annual }

/// What the header of the file says about the loan.
class LoanStatementMeta {
  const LoanStatementMeta({
    required this.title,
    required this.institution,
    required this.principal,
    required this.annualRate,
    required this.termLabel,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalPayment,
    this.interestSaved = 0,
    this.monthsSaved = 0,
    this.extraMonthly = 0,
  });

  final String title;
  final String institution;
  final double principal;
  final double annualRate;
  final String termLabel;
  final double monthlyPayment;
  final double totalInterest;
  final double totalPayment;
  final double interestSaved;
  final int monthsSaved;

  /// What the person said they could add each month. Carried so the savings
  /// note can name it: "prepaying 1,000 a month saves 172,329" is something
  /// somebody can act on, and "prepaying saves 172,329" is not.
  final double extraMonthly;
}

String _n(double v) => v.toStringAsFixed(2);

/// Plain grouped digits, no symbol, for the header lines. The peso sign goes
/// in the label as "PHP" so a spreadsheet does not read the column as text.
String _grouped(double v) {
  final String fixed = v.toStringAsFixed(2);
  final int dot = fixed.indexOf('.');
  final String whole = fixed.substring(0, dot);
  final String rest = fixed.substring(dot);
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '$out$rest';
}

/// A field, quoted only when it has to be.
///
/// Anything holding a comma, a quote or a newline is quoted and its quotes
/// doubled. Skipping this is how one loan called "Car, second hand" turns
/// every row after it into a spreadsheet with the columns shifted by one.
String _field(String raw) {
  if (!raw.contains(',') && !raw.contains('"') && !raw.contains('\n')) {
    return raw;
  }
  return '"${raw.replaceAll('"', '""')}"';
}

/// The whole statement, ready to write to a file.
///
/// Matches the prototype's own export: the metadata block, a blank line, the
/// section title, the column headers, then the rows. Line endings are CRLF
/// and the file is meant to be written with a UTF-8 BOM, both because that is
/// what makes Excel on Windows open a peso sign correctly instead of showing
/// mojibake.
String amortizationCsv({
  required List<AmortizationRow> schedule,
  required LoanStatementMeta meta,
  AmortizationView view = AmortizationView.monthly,
}) {
  final List<String> lines = <String>[
    _field('SALAPIFY 3 - ${meta.title.toUpperCase()}'),
    _field('Institution / Standard: ${meta.institution}'),
    _field('Principal Loan Amount: PHP ${_grouped(meta.principal)}'),
    _field('Interest Rate: ${meta.annualRate}%'),
    _field('Loan Term: ${meta.termLabel}'),
    _field('Monthly Amortization: PHP ${_grouped(meta.monthlyPayment)}'),
    _field('Total Interest over Term: PHP ${_grouped(meta.totalInterest)}'),
    _field('Total Repayment Amount: PHP ${_grouped(meta.totalPayment)}'),
    if (meta.interestSaved > 0) ...<String>[
      _field(
        'Total Prepayment Interest Saved: PHP ${_grouped(meta.interestSaved)}',
      ),
      _field('Months Saved / Accelerated Payoff: ${meta.monthsSaved} Months'),
    ],
    '',
  ];

  if (view == AmortizationView.monthly) {
    lines.add(
      _field(
        'MONTH-BY-MONTH AMORTIZATION & RUNNING BALANCE SCHEDULE '
        '(${schedule.length} MONTHS)',
      ),
    );
    lines.add(
      <String>[
        'Period #',
        'Due Date / Month',
        'Scheduled Payment (PHP)',
        'Principal Component (PHP)',
        'Interest Component (PHP)',
        'Extra / Prepayment (PHP)',
        'Total Monthly Outflow (PHP)',
        'Cumulative Principal Paid (PHP)',
        'Cumulative Interest Paid (PHP)',
        'Running Balance (PHP)',
      ].join(','),
    );

    // The cumulative columns are the reason this is worth exporting at all:
    // they answer "how much of this have I actually paid off by month 40",
    // which no single row can.
    double cumPrincipal = 0;
    double cumInterest = 0;
    for (final AmortizationRow row in schedule) {
      cumPrincipal += row.principalComponent;
      cumInterest += row.interestComponent;
      lines.add(
        <String>[
          '${row.period}',
          _field(row.dueDate.isEmpty ? 'Month ${row.period}' : row.dueDate),
          _n(row.scheduledPayment),
          _n(row.principalComponent),
          _n(row.interestComponent),
          _n(row.extraPayment),
          _n(row.scheduledPayment + row.extraPayment),
          _n(cumPrincipal),
          _n(cumInterest),
          _n(row.remainingBalance),
        ].join(','),
      );
    }
  } else {
    final List<YearSummary> years = summariseByYear(schedule);
    lines.add(
      _field(
        'ANNUAL AMORTIZATION & RUNNING BALANCE SUMMARY '
        '(${years.length} YEARS)',
      ),
    );
    lines.add(
      <String>[
        'Year #',
        'Year Label',
        'Total Payment (PHP)',
        'Principal Paid (PHP)',
        'Interest Paid (PHP)',
        'Extra Prepayments (PHP)',
        'Year-End Running Balance (PHP)',
      ].join(','),
    );
    for (final YearSummary y in years) {
      lines.add(
        <String>[
          '${y.year}',
          _field('Year ${y.year}'),
          _n(y.totalPayment),
          _n(y.principalPaid),
          _n(y.interestPaid),
          _n(y.extraPaid),
          _n(y.endingBalance),
        ].join(','),
      );
    }
  }

  return lines.join('\r\n');
}

/// The filename, sanitised the prototype's way.
String amortizationFileName(String title, AmortizationView view) {
  final String slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final String suffix = view == AmortizationView.monthly
      ? 'monthly_schedule'
      : 'yearly_summary';
  return '${slug.isEmpty ? 'loan' : slug}_$suffix.csv';
}
