import 'package:flutter/material.dart';

import '../../core/money/debt_strategy.dart';
import '../../core/money/amortization_export.dart';
import '../../core/money/format.dart';
import '../../core/money/loan.dart';
import '../../core/money/loan_products.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'amortization_table.dart';

/// The nine loan calculators, from src/components/DebtCalculatorsView.tsx.
///
/// EVERY FIGURE ON THIS SCREEN comes out of core/money/loan.dart,
/// loan_products.dart or debt_strategy.dart, all of which were ported earlier
/// and locked to vectors generated from the prototype's own arithmetic. This
/// file does no maths at all: it collects numbers, calls an engine, and lays
/// the answer out. That split is why a screen this large could be built in one
/// pass without a single new money decision.
///
/// The default values are the prototype's own, so the screen opens with real
/// Philippine figures on it rather than a page of empty boxes somebody has to
/// fill before it says anything.
class DebtCalculators extends StatefulWidget {
  const DebtCalculators({super.key, required this.palette});

  final Palette palette;

  @override
  State<DebtCalculators> createState() => _DebtCalculatorsState();
}

enum _Calc {
  pagibig,
  bankHousing,
  car,
  salaryLoan,
  personal,
  creditCard,
  consolidation,
  strategy,
  dsr,
}

class _DebtCalculatorsState extends State<DebtCalculators> {
  _Calc _active = _Calc.pagibig;

  /// One controller per field, keyed by name and seeded with the prototype's
  /// own defaults.
  ///
  /// A map rather than forty named fields. Forty controllers would be forty
  /// declarations, forty initialisations and forty disposals, and the one
  /// somebody forgets to dispose is a leak nothing reports.
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  static const Map<String, String> _defaults = <String, String>{
    'pagibigAmount': '1500000',
    'pagibigYears': '20',
    'pagibigExtra': '1000',
    'bankValue': '3500000',
    'bankDownPct': '20',
    'bankYears': '15',
    'bankRate': '6.75',
    'bankExtra': '2000',
    'carPrice': '1100000',
    'carDownPct': '20',
    'carMonths': '60',
    'carRate': '9.5',
    'salaryAmount': '50000',
    'salaryMonths': '24',
    'personalAmount': '30000',
    'personalMonths': '12',
    'personalRate': '2.5',
    'personalFee': '1500',
    'cardBalance': '45000',
    'cardRate': '3.0',
    'cardFixed': '5000',
    'consolRate': '1.5',
    'consolMonths': '36',
    'strategyExtra': '3000',
    'dsrObligations': '12000',
    'dsrIncome': '45000',
  };

  PagIbigProgram _pagibigProgram = PagIbigProgram.regularHousing;
  int _pagibigFixing = 3;
  RateType _carRateType = RateType.flatAddon;
  SalaryLoanType _salaryType = SalaryLoanType.pagibigMpl;
  CardPaymentStrategy _cardStrategy = CardPaymentStrategy.minimumOnly;

  TextEditingController _c(String key) => _fields.putIfAbsent(
    key,
    () => TextEditingController(text: _defaults[key] ?? ''),
  );

  double _v(String key) =>
      double.tryParse(_c(key).text.trim().replaceAll(',', '')) ?? 0;

  int _i(String key) => _v(key).round();

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  static const Map<_Calc, String> _labels = <_Calc, String>{
    _Calc.pagibig: 'Pag-IBIG housing',
    _Calc.bankHousing: 'Bank housing',
    _Calc.car: 'Car loan',
    _Calc.salaryLoan: 'SSS and Pag-IBIG salary',
    _Calc.personal: 'Personal and digital',
    _Calc.creditCard: 'Credit card trap',
    _Calc.consolidation: 'Consolidation',
    _Calc.strategy: 'Snowball or avalanche',
    _Calc.dsr: 'Can I afford it',
  };

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final MapEntry<_Calc, String> e in _labels.entries)
              _Pill(
                palette: p,
                label: e.value,
                selected: _active == e.key,
                onTap: () => setState(() => _active = e.key),
              ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        switch (_active) {
          _Calc.pagibig => _pagibig(p),
          _Calc.bankHousing => _bankHousing(p),
          _Calc.car => _car(p),
          _Calc.salaryLoan => _salary(p),
          _Calc.personal => _personal(p),
          _Calc.creditCard => _creditCard(p),
          _Calc.consolidation => _consolidation(p),
          _Calc.strategy => _strategy(p),
          _Calc.dsr => _dsr(p),
        },
      ],
    );
  }

  /// The statement card, for any calculator that repays a loan over time.
  ///
  /// One helper rather than six copies: every loan type shows the same four
  /// totals, the same two views and the same export, and six copies is how
  /// five of them keep a column the sixth quietly loses.
  Widget _statement(
    Palette p, {
    required List<AmortizationRow> schedule,
    required String title,
    required String institution,
    required double principal,
    required double annualRate,
    required String termLabel,
    required double monthlyPayment,
    required double totalInterest,
    required double totalPayment,
    required String footnote,
    double interestSaved = 0,
    int monthsSaved = 0,
    double extraMonthly = 0,
  }) => AmortizationTable(
    palette: p,
    schedule: schedule,
    meta: LoanStatementMeta(
      title: title,
      institution: institution,
      principal: principal,
      annualRate: annualRate,
      termLabel: termLabel,
      monthlyPayment: monthlyPayment,
      totalInterest: totalInterest,
      totalPayment: totalPayment,
      interestSaved: interestSaved,
      monthsSaved: monthsSaved,
      extraMonthly: extraMonthly,
    ),
    footnote: footnote,
  );

  // ---------------------------------------------------------------- Pag-IBIG

  Widget _pagibig(Palette p) {
    final LoanCalculationResult r = calculatePagIbigHousingLoan(
      program: _pagibigProgram,
      loanAmount: _v('pagibigAmount'),
      termYears: _i('pagibigYears'),
      fixingPeriodYears: _pagibigFixing,
      extraMonthlyPayment: _v('pagibigExtra'),
    );

    return _Card(
      palette: p,
      title: 'Pag-IBIG housing loan',
      note:
          'The rate depends on the programme and how long you fix it for. '
          'Affordable housing is 3 percent for the first ten years.',
      inputs: <Widget>[
        _Choice<PagIbigProgram>(
          palette: p,
          label: 'Programme',
          options: const <(PagIbigProgram, String)>[
            (PagIbigProgram.regularHousing, 'Regular'),
            (PagIbigProgram.affordableHousing, 'Affordable'),
          ],
          selected: _pagibigProgram,
          onSelect: (PagIbigProgram v) => setState(() => _pagibigProgram = v),
        ),
        _Num(
          palette: p,
          label: 'How much you are borrowing',
          c: _c('pagibigAmount'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Over how many years',
          c: _c('pagibigYears'),
          onChanged: _redraw,
        ),
        _Choice<int>(
          palette: p,
          label: 'Fix the rate for',
          options: const <(int, String)>[
            (1, '1 year'),
            (3, '3 years'),
            (5, '5 years'),
            (10, '10 years'),
          ],
          selected: _pagibigFixing,
          onSelect: (int v) => setState(() => _pagibigFixing = v),
        ),
        _Num(
          palette: p,
          label: 'Extra you can add each month',
          c: _c('pagibigExtra'),
          onChanged: _redraw,
          money: true,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'Every month',
          value: formatPeso(r.monthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'Interest over the whole loan',
          value: formatPeso(r.totalInterest),
        ),
        _Row(
          palette: p,
          label: 'Total you will have paid',
          value: formatPeso(r.totalPayment),
        ),
        _Row(palette: p, label: 'Paid off in', value: _months(r.payoffMonths)),
        if (r.interestSavedWithExtra > 0)
          _Row(
            palette: p,
            label: 'Saved by paying extra',
            value:
                '${formatPeso(r.interestSavedWithExtra)}, '
                '${_months(r.monthsSavedWithExtra)} sooner',
            highlight: true,
          ),
      ],
      schedule: AmortizationTable(
        palette: p,
        schedule: r.amortizationSchedule,
        meta: LoanStatementMeta(
          title: 'Pag-IBIG Housing Loan Statement',
          institution: 'Pag-IBIG Fund (HDMF Circular 449/450)',
          principal: _v('pagibigAmount'),
          annualRate: pagIbigRate(
            program: _pagibigProgram,
            fixingPeriodYears: _pagibigFixing,
          ),
          termLabel: '${_i('pagibigYears')} Years',
          monthlyPayment: r.monthlyPayment,
          totalInterest: r.totalInterest,
          totalPayment: r.totalPayment,
          interestSaved: r.interestSavedWithExtra,
          monthsSaved: r.monthsSavedWithExtra,
          extraMonthly: _v('pagibigExtra'),
        ),
        footnote:
            'Pag-IBIG loans use diminishing balance computation. Extra '
            'payments go straight to the principal, which cuts the interest '
            'that would have been charged on it for every month after.',
      ),
    );
  }

  // ------------------------------------------------------------ Bank housing

  Widget _bankHousing(Palette p) {
    final BankHousingResult r = calculateBankHousingLoan(
      propertyValue: _v('bankValue'),
      downpaymentPercent: _v('bankDownPct'),
      termYears: _i('bankYears'),
      fixedRate: _v('bankRate'),
      extraMonthlyPayment: _v('bankExtra'),
    );

    return _Card(
      palette: p,
      title: 'Bank housing loan',
      note:
          'A bank rate is fixed for a few years and then repriced. The jump '
          'is the part people are not ready for.',
      inputs: <Widget>[
        _Num(
          palette: p,
          label: 'What the property costs',
          c: _c('bankValue'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Downpayment, as a percent',
          c: _c('bankDownPct'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Over how many years',
          c: _c('bankYears'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Fixed rate, percent a year',
          c: _c('bankRate'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Extra you can add each month',
          c: _c('bankExtra'),
          onChanged: _redraw,
          money: true,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'Every month',
          value: formatPeso(r.monthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'Downpayment you need up front',
          value: formatPeso(r.downpaymentAmount),
        ),
        _Row(
          palette: p,
          label: 'What you are actually borrowing',
          value: formatPeso(r.loanPrincipal),
        ),
        _Row(
          palette: p,
          label: 'Interest over the whole loan',
          value: formatPeso(r.totalInterest),
        ),
        if (r.monthlyPaymentJump > 0)
          _Row(
            palette: p,
            label: 'After repricing, it becomes',
            value:
                '${formatPeso(r.repricedMonthlyPayment)}, up '
                '${formatPeso(r.monthlyPaymentJump)}',
            warn: true,
          ),
      ],
      schedule: _statement(
        p,
        schedule: r.schedule,
        title: 'Bank Housing Loan Statement',
        institution: 'Philippine universal bank, fixed then repriced',
        principal: r.loanPrincipal,
        annualRate: _v('bankRate'),
        termLabel: '${_i('bankYears')} Years',
        monthlyPayment: r.monthlyPayment,
        totalInterest: r.totalInterest,
        totalPayment: r.totalPayment,
        interestSaved: r.interestSavedWithExtra,
        extraMonthly: _v('bankExtra'),
        footnote:
            'Computed on the diminishing balance at the fixed rate. After the '
            'fixing period the bank reprices, so the later rows are what you '
            'pay only if the rate does not move.',
      ),
    );
  }

  // --------------------------------------------------------------- Car loan

  Widget _car(Palette p) {
    final CarLoanResult r = calculateCarLoan(
      vehiclePrice: _v('carPrice'),
      downpaymentPercent: _v('carDownPct'),
      termMonths: _i('carMonths'),
      annualInterestRate: _v('carRate'),
      rateType: _carRateType,
      includeInsuranceAndChattel: true,
    );

    return _Card(
      palette: p,
      title: 'Car loan',
      note:
          'Dealerships quote a flat add-on rate, which costs far more than '
          'the same number quoted the bank way. Switch the two to see it.',
      inputs: <Widget>[
        _Num(
          palette: p,
          label: 'Price of the car',
          c: _c('carPrice'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Downpayment, as a percent',
          c: _c('carDownPct'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Over how many months',
          c: _c('carMonths'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Rate they quoted, percent a year',
          c: _c('carRate'),
          onChanged: _redraw,
        ),
        _Choice<RateType>(
          palette: p,
          label: 'How the rate is charged',
          options: const <(RateType, String)>[
            (RateType.flatAddon, 'Flat add-on'),
            (RateType.diminishing, 'Diminishing'),
          ],
          selected: _carRateType,
          onSelect: (RateType v) => setState(() => _carRateType = v),
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'Every month',
          value: formatPeso(r.monthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'Cash you need on day one',
          value: formatPeso(r.initialCashOut),
          note:
              'Downpayment, chattel mortgage and the first year of '
              'comprehensive insurance.',
        ),
        _Row(
          palette: p,
          label: 'Chattel mortgage fee',
          value: formatPeso(r.chattelMortgageFee),
        ),
        _Row(
          palette: p,
          label: 'Comprehensive insurance',
          value: formatPeso(r.comprehensiveInsurance),
        ),
        _Row(
          palette: p,
          label: 'Interest over the whole loan',
          value: formatPeso(r.totalInterest),
        ),
      ],
      schedule: _statement(
        p,
        schedule: r.schedule,
        title: 'Auto Loan Statement',
        institution: 'Philippine bank auto loan',
        principal: r.loanPrincipal,
        annualRate: _v('carRate'),
        termLabel: '${_i('carMonths')} Months',
        monthlyPayment: r.monthlyPayment,
        totalInterest: r.totalInterest,
        totalPayment: r.totalPayment,
        footnote: _carRateType == RateType.flatAddon
            ? 'Add-on rate: the interest is worked out on the WHOLE amount '
                  'for the whole term, so every row carries the same interest '
                  'even as the balance falls. That is why it costs more than '
                  'the same rate on a diminishing balance.'
            : 'Diminishing balance: the interest each month is charged on '
                  'what is still owed, so it falls as the loan does.',
      ),
    );
  }

  // ------------------------------------------------------------ Salary loan

  Widget _salary(Palette p) {
    final SalaryLoanResult r = calculateSalaryLoan(
      loanType: _salaryType,
      loanAmount: _v('salaryAmount'),
      termMonths: _i('salaryMonths'),
    );

    return _Card(
      palette: p,
      title: 'SSS and Pag-IBIG salary loan',
      note:
          'These deduct their fee before you get the money, so what lands in '
          'your account is less than what you borrowed.',
      inputs: <Widget>[
        _Choice<SalaryLoanType>(
          palette: p,
          label: 'Which one',
          options: const <(SalaryLoanType, String)>[
            (SalaryLoanType.pagibigMpl, 'Pag-IBIG MPL'),
            (SalaryLoanType.sssSalary, 'SSS salary'),
            (SalaryLoanType.pagibigCalamity, 'Pag-IBIG calamity'),
            (SalaryLoanType.gsisConso, 'GSIS conso'),
          ],
          selected: _salaryType,
          onSelect: (SalaryLoanType v) => setState(() => _salaryType = v),
        ),
        _Num(
          palette: p,
          label: 'How much you are borrowing',
          c: _c('salaryAmount'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Over how many months',
          c: _c('salaryMonths'),
          onChanged: _redraw,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'What actually reaches you',
          value: formatPeso(r.netProceeds),
        ),
        _Row(
          palette: p,
          label: 'Processing fee taken up front',
          value: formatPeso(r.processingFee),
        ),
        _Row(
          palette: p,
          label: 'Every month',
          value: formatPeso(r.monthlyPayment),
        ),
        _Row(palette: p, label: 'Rate', value: '${r.annualRate}% a year'),
        _Row(
          palette: p,
          label: 'Interest over the whole loan',
          value: formatPeso(r.totalInterest),
        ),
        if (r.estimatedDividendRebate > 0)
          _Row(
            palette: p,
            label: 'Dividend rebate, roughly',
            value: formatPeso(r.estimatedDividendRebate),
            highlight: true,
          ),
        _Row(
          palette: p,
          label: 'What it really costs you',
          value: formatPeso(r.effectiveTotalCost),
          note: 'Interest and the fee, less any dividend coming back.',
        ),
      ],
      schedule: _statement(
        p,
        schedule: r.schedule,
        title: 'Salary Loan Statement',
        institution: switch (_salaryType) {
          SalaryLoanType.pagibigMpl => 'Pag-IBIG Multi-Purpose Loan',
          SalaryLoanType.sssSalary => 'SSS Salary Loan',
          SalaryLoanType.pagibigCalamity => 'Pag-IBIG Calamity Loan',
          SalaryLoanType.gsisConso => 'GSIS Consolidated Loan',
        },
        principal: r.loanAmount,
        annualRate: r.annualRate,
        termLabel: '${_i('salaryMonths')} Months',
        monthlyPayment: r.monthlyPayment,
        totalInterest: r.totalInterest,
        totalPayment: r.totalPayment,
        footnote:
            'Collected by salary deduction, so the payment leaves before you '
            'see it. The net proceeds above are what actually reaches you '
            'after the fee.',
      ),
    );
  }

  // ---------------------------------------------------------- Personal loan

  Widget _personal(Palette p) {
    final PersonalLoanResult r = calculatePersonalLoan(
      principal: _v('personalAmount'),
      termMonths: _i('personalMonths'),
      monthlyAddOnRate: _v('personalRate'),
      processingFee: _v('personalFee'),
    );

    return _Card(
      palette: p,
      title: 'Personal and digital lender',
      note:
          'These quote a rate per MONTH, not per year. A 2.5 there is 30 a '
          'year before the fee.',
      inputs: <Widget>[
        _Num(
          palette: p,
          label: 'How much you are borrowing',
          c: _c('personalAmount'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Over how many months',
          c: _c('personalMonths'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Rate they quoted, percent a MONTH',
          c: _c('personalRate'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'Processing fee',
          c: _c('personalFee'),
          onChanged: _redraw,
          money: true,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'What actually reaches you',
          value: formatPeso(r.netCashReceived),
        ),
        _Row(
          palette: p,
          label: 'Every month',
          value: formatPeso(r.monthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'Interest over the whole loan',
          value: formatPeso(r.totalInterest),
        ),
        _Row(
          palette: p,
          label: 'Total you will have paid',
          value: formatPeso(r.totalPayment),
        ),
      ],
      schedule: _statement(
        p,
        schedule: r.schedule,
        title: 'Personal Loan Statement',
        institution: 'Personal or digital lender',
        principal: r.principal,
        annualRate: _v('personalRate') * 12,
        termLabel: '${_i('personalMonths')} Months',
        monthlyPayment: r.monthlyPayment,
        totalInterest: r.totalInterest,
        totalPayment: r.totalPayment,
        footnote:
            'Quoted per month, which is the single most misread number in '
            'Philippine consumer lending. ${_v('personalRate')} percent a '
            'month is ${(_v('personalRate') * 12).toStringAsFixed(1)} percent '
            'a year, and the lender does not print that.',
      ),
    );
  }

  // ----------------------------------------------------------- Credit cards

  Widget _creditCard(Palette p) {
    final CreditCardPayoffResult r = calculateCreditCardPayoff(
      currentBalance: _v('cardBalance'),
      monthlyInterestRate: _v('cardRate'),
      paymentStrategy: _cardStrategy,
      fixedMonthlyPayment: _v('cardFixed'),
    );

    return _Card(
      palette: p,
      title: 'The credit card minimum trap',
      note:
          'Paying only the minimum is how a balance outlives the thing you '
          'bought with it. Switch to a fixed amount to see the difference.',
      inputs: <Widget>[
        _Num(
          palette: p,
          label: 'What you owe on the card',
          c: _c('cardBalance'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'Interest, percent a MONTH',
          c: _c('cardRate'),
          onChanged: _redraw,
        ),
        _Choice<CardPaymentStrategy>(
          palette: p,
          label: 'How you pay it',
          options: const <(CardPaymentStrategy, String)>[
            (CardPaymentStrategy.minimumOnly, 'Minimum only'),
            (CardPaymentStrategy.fixedAmount, 'A fixed amount'),
          ],
          selected: _cardStrategy,
          onSelect: (CardPaymentStrategy v) =>
              setState(() => _cardStrategy = v),
        ),
        if (_cardStrategy == CardPaymentStrategy.fixedAmount)
          _Num(
            palette: p,
            label: 'How much, every month',
            c: _c('cardFixed'),
            onChanged: _redraw,
            money: true,
          ),
      ],
      results: <Widget>[
        _Big(palette: p, label: 'Clear in', value: _months(r.monthsToPayoff)),
        _Row(
          palette: p,
          label: 'Interest you will pay',
          value: formatPeso(r.totalInterestPaid),
        ),
        _Row(
          palette: p,
          label: 'Total you will have paid',
          value: formatPeso(r.totalAmountPaid),
        ),
        if (r.warningMessage != null)
          _Note(palette: p, text: r.warningMessage!, warn: true),
      ],
    );
  }

  // ---------------------------------------------------------- Consolidation

  /// The three debts the prototype pre-loads, so the calculator shows an
  /// answer the moment it opens. Editing the list is a later step; the
  /// question this screen answers, "is one loan cheaper than three", is
  /// answerable with a realistic example.
  static const List<DebtToConsolidate> _sample = <DebtToConsolidate>[
    DebtToConsolidate(
      id: '1',
      name: 'Credit Card 1 (BDO)',
      balance: 45000,
      monthlyInterestRate: 3.0,
      currentMonthlyPayment: 2250,
    ),
    DebtToConsolidate(
      id: '2',
      name: 'Credit Card 2 (BPI)',
      balance: 30000,
      monthlyInterestRate: 3.0,
      currentMonthlyPayment: 1500,
    ),
    DebtToConsolidate(
      id: '3',
      name: 'Shopee SPayLater',
      balance: 15000,
      monthlyInterestRate: 2.5,
      currentMonthlyPayment: 1200,
    ),
  ];

  Widget _consolidation(Palette p) {
    final ConsolidationResult r = calculateDebtConsolidation(
      debts: _sample,
      newLoanMonthlyRate: _v('consolRate'),
      newTermMonths: _i('consolMonths'),
    );

    return _Card(
      palette: p,
      title: 'Rolling several debts into one',
      note:
          'Worked out against three example debts totalling '
          '${formatPeso(r.totalBalance)}.',
      inputs: <Widget>[
        for (final DebtToConsolidate d in _sample)
          _Row(
            palette: p,
            label: d.name,
            value:
                '${formatPeso(d.balance)} at '
                '${d.monthlyInterestRate}% a month',
          ),
        const SizedBox(height: Spacing.sm),
        _Num(
          palette: p,
          label: 'New loan rate, percent a MONTH',
          c: _c('consolRate'),
          onChanged: _redraw,
        ),
        _Num(
          palette: p,
          label: 'New loan, over how many months',
          c: _c('consolMonths'),
          onChanged: _redraw,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'One payment instead of three',
          value: formatPeso(r.newMonthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'You are paying now',
          value: formatPeso(r.totalCurrentMonthlyPayment),
        ),
        _Row(
          palette: p,
          label: 'Freed up each month',
          value: formatPeso(r.monthlyCashflowRelief),
          highlight: r.monthlyCashflowRelief > 0,
        ),
        _Row(
          palette: p,
          label: r.totalInterestSavings >= 0
              ? 'Interest saved overall'
              : 'Interest this COSTS you overall',
          value: formatPeso(r.totalInterestSavings),
          highlight: r.totalInterestSavings > 0,
          warn: r.totalInterestSavings < 0,
          note: r.totalInterestSavings < 0
              ? 'A smaller monthly payment over a longer term can still cost '
                    'more in the end. That is the case here.'
              : null,
        ),
      ],
      schedule: _statement(
        p,
        schedule: r.schedule,
        title: 'Consolidation Loan Statement',
        institution: 'One loan replacing several',
        principal: r.totalBalance,
        annualRate: _v('consolRate') * 12,
        termLabel: '${_i('consolMonths')} Months',
        monthlyPayment: r.newMonthlyPayment,
        totalInterest: r.newTotalInterest,
        totalPayment: r.totalPayment,
        footnote:
            'This is the NEW loan only. A lower monthly payment over a longer '
            'term can still cost more in total than the debts it replaces, '
            'which is what the comparison above is for.',
      ),
    );
  }

  // --------------------------------------------------------------- Strategy

  static const List<DebtItemForStrategy> _strategyDebts = <DebtItemForStrategy>[
    DebtItemForStrategy(
      id: '1',
      name: 'BDO Credit Card',
      balance: 35000,
      interestRate: 36,
      minimumPayment: 1500,
    ),
    DebtItemForStrategy(
      id: '2',
      name: 'Shopee SPayLater',
      balance: 8500,
      interestRate: 24,
      minimumPayment: 850,
    ),
    DebtItemForStrategy(
      id: '3',
      name: 'Pahiram kay Kuya',
      balance: 15000,
      interestRate: 0,
      minimumPayment: 1000,
    ),
  ];

  Widget _strategy(Palette p) {
    final StrategyComparison r = simulateDebtStrategies(
      debts: _strategyDebts,
      extraMonthlyBudget: _v('strategyExtra'),
    );

    return _Card(
      palette: p,
      title: 'Snowball or avalanche',
      note:
          'Snowball clears the smallest debt first, which feels better. '
          'Avalanche clears the dearest first, which costs less. Both against '
          'three example debts.',
      inputs: <Widget>[
        for (final DebtItemForStrategy d in _strategyDebts)
          _Row(
            palette: p,
            label: d.name,
            value: '${formatPeso(d.balance)} at ${d.interestRate}% a year',
          ),
        const SizedBox(height: Spacing.sm),
        _Num(
          palette: p,
          label: 'Extra you can put in each month',
          c: _c('strategyExtra'),
          onChanged: _redraw,
          money: true,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'Avalanche clears them in',
          value: _months(r.avalanche.monthsToDebtFreedom),
        ),
        _Row(
          palette: p,
          label: 'Avalanche interest',
          value: formatPeso(r.avalanche.totalInterestPaid),
        ),
        _Row(
          palette: p,
          label: 'Avalanche order',
          value: r.avalanche.orderOfPayoff.join(', '),
        ),
        const SizedBox(height: Spacing.sm),
        _Row(
          palette: p,
          label: 'Snowball clears them in',
          value: _months(r.snowball.monthsToDebtFreedom),
        ),
        _Row(
          palette: p,
          label: 'Snowball interest',
          value: formatPeso(r.snowball.totalInterestPaid),
        ),
        _Row(
          palette: p,
          label: 'Snowball order',
          value: r.snowball.orderOfPayoff.join(', '),
        ),
        _Note(
          palette: p,
          text: r.interestDifference.abs() < 1
              ? 'On these numbers the two cost the same, so pick whichever '
                    'you will actually stick to.'
              : 'Avalanche costs ${formatPeso(r.interestDifference.abs())} '
                    'less in interest. Snowball clears the first debt sooner, '
                    'which is worth something if that is what keeps you going.',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- DSR

  Widget _dsr(Palette p) {
    final DsrResult r = calculateDsr(
      monthlyDebtObligations: _v('dsrObligations'),
      grossMonthlyIncome: _v('dsrIncome'),
    );

    return _Card(
      palette: p,
      title: 'Can I afford another loan',
      note:
          'Banks call this the debt service ratio. It is what your monthly '
          'repayments come to, as a share of what you earn before deductions.',
      inputs: <Widget>[
        _Num(
          palette: p,
          label: 'Your repayments each month, all of them',
          c: _c('dsrObligations'),
          onChanged: _redraw,
          money: true,
        ),
        _Num(
          palette: p,
          label: 'What you earn each month, before deductions',
          c: _c('dsrIncome'),
          onChanged: _redraw,
          money: true,
        ),
      ],
      results: <Widget>[
        _Big(
          palette: p,
          label: 'Debt service ratio',
          value: '${r.dsr.toStringAsFixed(1)}%',
        ),
        _Note(
          palette: p,
          text: switch (r.status) {
            AffordabilityStatus.healthy =>
              'Comfortable. Most lenders are happy below 30 percent.',
            AffordabilityStatus.moderate =>
              'Workable, but a bank will look closely. Anything above 30 '
                  'percent starts to count against you.',
            AffordabilityStatus.stretched =>
              'Stretched. Above 40 percent most lenders will decline, and the '
                  'ones that do not are the expensive ones.',
          },
          warn: r.status == AffordabilityStatus.stretched,
        ),
        // ON THE SCREEN, not behind the info dot, and this is the exception
        // the screen rule names rather than a breach of it.
        //
        // This tab shows a ratio against thresholds, in the language lenders
        // use, inside an app with a debt register and nine loan calculators.
        // That is exactly the shape a Play reviewer skims and mis-files as a
        // lending app, in a market where dozens have been pulled and the
        // route is classification first and questions later. Somebody reading
        // it could also reasonably wonder whether anything was submitted
        // anywhere. Silence would mislead on both counts.
        _Note(
          palette: p,
          text:
              'This is your own check on your own numbers. Salapify does not '
              'lend money and does not arrange or refer loans. Nothing here '
              'is sent to any lender.',
        ),
      ],
    );
  }

  void _redraw(String _) => setState(() {});

  static String _months(int m) {
    if (m <= 0) return 'no time at all';
    if (m < 12) return '$m month${m == 1 ? '' : 's'}';
    final int years = m ~/ 12;
    final int rest = m % 12;
    final String y = '$years year${years == 1 ? '' : 's'}';
    if (rest == 0) return y;
    return '$y $rest month${rest == 1 ? '' : 's'}';
  }
}

// ------------------------------------------------------------- the small kit

class _Card extends StatelessWidget {
  const _Card({
    required this.palette,
    required this.title,
    required this.note,
    required this.inputs,
    required this.results,
    this.schedule,
  });

  final Palette palette;
  final String title;
  final String note;
  final List<Widget> inputs;
  final List<Widget> results;

  /// The month by month statement, for the calculators that produce one.
  ///
  /// Optional because not every calculator has a schedule to show: the
  /// affordability check and the snowball comparison answer a question rather
  /// than repay a loan.
  final Widget? schedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppType.section(palette)),
              const SizedBox(height: Spacing.xs),
              Text(note, style: AppType.body(palette)),
              const SizedBox(height: Spacing.lg),
              for (final Widget w in inputs) ...<Widget>[
                w,
                const SizedBox(height: Spacing.md),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: results,
          ),
        ),
        ?schedule,
      ],
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({
    required this.palette,
    required this.label,
    required this.c,
    required this.onChanged,
    this.money = false,
  });

  final Palette palette;
  final String label;
  final TextEditingController c;
  final ValueChanged<String> onChanged;

  /// Draws the peso sign inside the box. Every other money field in the app
  /// does, and without it a field holding 45000 is indistinguishable at a
  /// glance from one holding 45000 months.
  final bool money;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: c,
          onChanged: onChanged,
          // WITH the decimal point. Plain TextInputType.number gives Android a
          // pad with no "." key, so a rate of 6.75 simply cannot be typed.
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppType.rowTitle(palette).copyWith(fontSize: 15),
          decoration: InputDecoration(
            prefixText: money ? '₱ ' : null,
            prefixStyle: AppType.rowTitle(palette).copyWith(fontSize: 15),
            filled: true,
            fillColor: palette.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.palette,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final String label;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final (T v, String l) in options)
              _Pill(
                palette: palette,
                label: l,
                selected: selected == v,
                onTap: () => onSelect(v),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          // NO alignment. A Container with an alignment and no width fills
          // everything it is offered, which turns a row of pills into a
          // column of full width bars. It has happened twice here already.
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.palette, required this.label, required this.value});

  final Palette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: AppType.kicker(palette)),
          Text(value, style: AppType.amount(palette)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.palette,
    required this.label,
    required this.value,
    this.highlight = false,
    this.warn = false,
    this.note,
  });

  final Palette palette;
  final String label;
  final String value;
  final bool highlight;
  final bool warn;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final Color colour = warn
        ? palette.negative
        : highlight
        ? palette.positive
        : palette.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(label, style: AppType.body(palette))),
              const SizedBox(width: Spacing.sm),
              // Flexible, not a bare Text. Some of these values are sentences
              // rather than figures ("BDO Credit Card, Shopee SPayLater,
              // Pahiram kay Kuya" is the avalanche order), and an unbounded
              // Text in a Row overflowed by 110 pixels at 320dp. Flexible lets
              // it wrap instead of running off the edge of the phone.
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppType.amountSmall(palette).copyWith(color: colour),
                ),
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note!, style: AppType.caption(palette)),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.palette, required this.text, this.warn = false});

  final Palette palette;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: warn ? palette.negativeSoft : palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Text(text, style: AppType.caption(palette)),
    );
  }
}
