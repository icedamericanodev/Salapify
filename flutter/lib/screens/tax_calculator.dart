// Income tax: for freelancers, professionals, and small businesses, the
// flat 8 percent versus the graduated rate, whichever costs less. Adapted
// from the RN screen on the golden-ported phtax engine (selfEmployedTax,
// which compares both regimes with the VAT-threshold gate and the mixed
// earner guard). Awareness of forms and deadlines only, not tax advice.

import 'package:flutter/material.dart';

import '../money/phtax.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class TaxCalculatorScreen extends StatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  final gross = TextEditingController();
  final salaryTaxable = TextEditingController();
  final expenses = TextEditingController();
  bool mixedIncome = false;
  bool useOSD = true;

  @override
  void dispose() {
    gross.dispose();
    salaryTaxable.dispose();
    expenses.dispose();
    super.dispose();
  }

  double _parse(String s) {
    final cleaned = s.replaceAll(RegExp(r'[, ]'), '');
    if (cleaned.isEmpty) return 0;
    final n = double.tryParse(cleaned);
    return (n == null || !n.isFinite) ? 0 : n;
  }

  String _m(num n) => formatMoney((n + 0.5).floorToDouble());

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: Barako.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _row(String label, String value,
          {bool strong = false, bool subtle = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 13)),
            ),
            Text(value,
                style: TextStyle(
                    color: subtle ? Barako.muted : Barako.text,
                    fontSize: strong ? 15 : 13,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );

  Widget _seg(List<(bool, String)> options, bool value,
      void Function(bool) onChange) {
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: value == o.$1,
            onSelected: (_) => setState(() => onChange(o.$1)),
            selectedColor: Barako.primary,
            backgroundColor: Barako.background,
            labelStyle: TextStyle(
                color: value == o.$1
                    ? Barako.onPrimary
                    : Barako.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final grossNum = _parse(gross.text);
    final expensesNum = _parse(expenses.text);
    final salaryNum = _parse(salaryTaxable.text);
    final r = selfEmployedTax(grossNum,
        mixedIncome: mixedIncome,
        useOSD: useOSD,
        expenses: expensesNum,
        salaryTaxable: salaryNum);

    final eight = (r['eightPercent'] as Map).cast<String, dynamic>();
    final grad = (r['graduated'] as Map).cast<String, dynamic>();
    final eightWins = r['recommended'] == 'eight';
    // Only claim one is cheaper when the gap is a real peso or more and both
    // could be compared (a mixed earner needs a salary to compare).
    final meaningful =
        (r['canCompareGraduated'] as bool) && (r['savings'] as double) >= 1;
    final chosenTotal =
        eightWins ? eight['total'] as double : grad['total'] as double;

    final formsText = !(r['eligible8'] as bool)
        ? 'Over ${_m(vatThreshold)} a year you also register for VAT and file Form 2550Q each quarter, on top of your income tax returns (1701Q and 1701 or 1701A). This tool does not compute the 12% VAT, so please see an accountant.'
        : mixedIncome
            ? 'You file for both. Your employer gives you Form 2316 for the job. For your business, register once with Form 1901, file Form 1701Q each quarter (May 15, Aug 15, Nov 15), and file the yearly Form 1701 by April 15. Add Form 2551Q each quarter unless you are on the 8% option. Mixed income uses Form 1701, not 1701A.'
            : eightWins
                ? 'Register once with Form 1901. File income tax quarterly on Form 1701Q (May 15, Aug 15, Nov 15) and yearly on Form 1701A (April 15). On the 8% option you skip the percentage tax. Choose the 8% on time and it is locked for the year.'
                : 'Register once with Form 1901. File income tax quarterly on Form 1701Q (May 15, Aug 15, Nov 15) and yearly on ${useOSD ? 'Form 1701A' : 'Form 1701'} (April 15). Also file percentage tax quarterly on Form 2551Q, 3% of your gross.';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Income tax',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
                'For freelancers, professionals, and small businesses. Enter your yearly income and see whether the flat 8% or the graduated rate costs you less.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 13, height: 1.4)),
            _label('YEARLY GROSS INCOME'),
            TextField(
              controller: gross,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: Barako.text),
              decoration: InputDecoration(
                  prefixText: '₱ ', hintText: 'e.g. 600,000'),
            ),
            if (grossNum > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('About ${_m(grossNum / 12)} a month in sales or fees.',
                    style: TextStyle(color: Barako.muted, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => mixedIncome = !mixedIncome),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('I also earn a salary',
                              style: TextStyle(
                                  color: Barako.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              'Mixed income. The 250,000 tax-free part is used by your salary, so the whole business income is taxed.',
                              style: TextStyle(
                                  color: Barako.muted,
                                  fontSize: 12,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                        mixedIncome
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color:
                            mixedIncome ? Barako.primary : Barako.muted),
                  ],
                ),
              ),
            ),
            if (mixedIncome) ...[
              _label('YOUR YEARLY TAXABLE SALARY'),
              TextField(
                controller: salaryTaxable,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Barako.text),
                decoration: InputDecoration(
                    prefixText: '₱ ', hintText: 'e.g. 400,000'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Roughly your yearly basic pay minus SSS, PhilHealth, and Pag-IBIG. The take-home pay tool shows this. Needed to compare the graduated option fairly.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 12, height: 1.3)),
              ),
            ],
            _label('DEDUCTIONS FOR THE GRADUATED OPTION'),
            _seg(const [(true, '40% standard'), (false, 'My expenses')],
                useOSD, (v) => useOSD = v),
            if (!useOSD)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: expenses,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Barako.text),
                  decoration: InputDecoration(
                      prefixText: '₱ ', hintText: 'Yearly expenses'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'The 40% standard deduction (OSD) needs no receipts. Pick My expenses if your real costs are higher.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 12, height: 1.3)),
              ),
            if (grossNum > 0) ...[
              const SizedBox(height: 14),
              // The pick card.
              Card(
                color: Barako.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          !(r['eligible8'] as bool)
                              ? 'HEADS UP'
                              : 'OUR PICK',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(
                          !(r['eligible8'] as bool)
                              ? 'Over ${_m(vatThreshold)} a year'
                              : !(r['canCompareGraduated'] as bool)
                                  ? 'Take the flat 8%'
                                  : !meaningful
                                      ? 'Either option works'
                                      : eightWins
                                          ? 'Take the flat 8%'
                                          : 'Use the graduated rate',
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          !(r['eligible8'] as bool)
                              ? 'The flat 8% is only for income of ${_m(vatThreshold)} or less. Above it you register for VAT (12%), so this graduated figure is a rough floor, not the full picture. Talk to an accountant.'
                              : !(r['canCompareGraduated'] as bool)
                                  ? 'One simple tax, no receipts. To compare the graduated route fairly we need your yearly taxable salary, so add it above if you want to check both.'
                                  : meaningful
                                      ? 'Saves you about ${_m(r['savings'] as double)} a year versus the other option.'
                                      : 'Both options cost about the same this year, so pick whichever is simpler for you.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
              if (r['eligible8'] as bool) ...[
                const SizedBox(height: 12),
                _optionCard(
                  title: 'Flat 8% option',
                  win: eightWins && meaningful,
                  rows: [
                    _row(
                        mixedIncome
                            ? '8% on all business income'
                            : '8% on income over ${_m(250000)}',
                        _m(eight['total'] as double)),
                  ],
                  total: _m(eight['total'] as double),
                  note: mixedIncome
                      ? 'This is the tax on your business income only. Your salary is taxed separately by your employer. One flat tax, no expense receipts.'
                      : 'One flat tax. It covers both income tax and the percentage tax, and needs no expense receipts.',
                ),
              ],
              if (r['canCompareGraduated'] as bool) ...[
                const SizedBox(height: 12),
                _optionCard(
                  title: 'Graduated option',
                  win: !eightWins && meaningful,
                  rows: [
                    _row(useOSD ? '40% standard deduction' : 'Your expenses',
                        '- ${_m(grad['deduction'] as double)}',
                        subtle: true),
                    _row('Net taxable income',
                        _m(grad['net'] as double),
                        subtle: true),
                    if (mixedIncome)
                      _row('Taxed on top of your salary', _m(salaryNum),
                          subtle: true),
                    _row(
                        mixedIncome
                            ? 'Extra income tax (graduated)'
                            : 'Income tax (graduated)',
                        _m(grad['incomeTax'] as double)),
                    if ((grad['percentageTax'] as double) > 0)
                      _row('Percentage tax (3%)',
                          _m(grad['percentageTax'] as double)),
                  ],
                  total: _m(grad['total'] as double),
                  note: (grad['percentageTax'] as double) > 0
                      ? 'Graduated income tax on your net, plus a separate 3% tax on your whole gross.'
                      : 'Graduated income tax on your net. Above the VAT threshold the 3% tax is replaced by 12% VAT, which this tool does not compute.',
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'On your pick, set aside about ${_m(chosenTotal / 12)} a month so the tax is ready when it is due.',
                      style: TextStyle(
                          color: Barako.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FORMS YOU WILL FILE',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(formsText,
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Text(
                          'No more 500 peso annual registration fee since 2024 (Ease of Paying Taxes Act). A quarter with zero income still means you file, just with nothing to pay.',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Enter your yearly gross income to compare the two options.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 13, height: 1.4)),
              ),
            const SizedBox(height: 12),
            Text(
                'Estimate based on $ratesYear BIR rates: the graduated income tax table, the 8% option, and the 3% percentage tax for non-VAT taxpayers. The 8% must be chosen with the BIR on time (at registration or the first quarter return) and it is locked in for the whole year. The forms and deadlines here are for awareness, not tax advice or a filing service, and a deadline can shift when it lands on a weekend or holiday. Confirm with the BIR or a licensed accountant before you file.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required String title,
    required bool win,
    required List<Widget> rows,
    required String total,
    required String note,
  }) {
    return Card(
      shape: win
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Barako.primary, width: 2))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                if (win)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Barako.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('LOWER',
                        style: TextStyle(
                            color: Barako.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows,
            Divider(color: Barako.border, height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Total tax',
                      style: TextStyle(
                          color: Barako.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                Text(total,
                    style: TextStyle(
                        color: Barako.primary,
                        fontSize: 18,
                        fontFamily: Barako.displayFont,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(note,
                style: TextStyle(
                    color: Barako.muted, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
