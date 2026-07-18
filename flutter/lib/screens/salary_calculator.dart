// Take-home pay: gross to net for a PH employee, adapted from the RN
// screen on the golden-ported phtax engine (SSS, PhilHealth, Pag-IBIG, and
// the graduated BIR table). The engine works in monthly pesos; the user can
// view the result per cutoff, monthly, or per year. Every explanation the
// RN screen gives about WHY the money comes out rides along.

import 'package:flutter/material.dart';

import '../money/phtax.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  State<SalaryCalculatorScreen> createState() =>
      _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  final basic = TextEditingController();
  final taxAllow = TextEditingController();
  final nonTaxAllow = TextEditingController();
  String period = 'month';

  @override
  void dispose() {
    basic.dispose();
    taxAllow.dispose();
    nonTaxAllow.dispose();
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

  Widget _line(String label, String value,
      {bool strong = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: strong ? Barako.text : Barako.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        strong ? FontWeight.w700 : FontWeight.w400)),
          ),
          Text(value,
              style: TextStyle(
                  color: valueColor ??
                      (strong ? Barako.text : Barako.textSecondary),
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basicNum = _parse(basic.text);
    final taxAllowNum = _parse(taxAllow.text);
    final nonTaxAllowNum = _parse(nonTaxAllow.text);
    final r = takeHomePay(basicNum,
        taxableAllowance: taxAllowNum, nonTaxableAllowance: nonTaxAllowNum);

    // The engine works in monthly pesos; only the displayed figures scale.
    final factor = period == 'cutoff' ? 0.5 : period == 'year' ? 12.0 : 1.0;
    final word = period == 'cutoff'
        ? 'per cutoff'
        : period == 'year'
            ? 'a year'
            : 'a month';
    String ms(num n) => _m(n * factor);
    final netLabel = period == 'cutoff'
        ? 'Take-home per cutoff'
        : period == 'year'
            ? 'Take-home per year'
            : 'Take-home pay';

    final gross = r['gross'] as double;
    final monthlyTax = r['monthlyTax'] as double;
    // Effective rate is tax as a share of gross; marginal is the bracket the
    // next taxable peso falls in. Both help the user read a raise correctly.
    final effRate = gross > 0
        ? ((monthlyTax / gross * 1000) + 0.5).floorToDouble() / 10
        : 0.0;
    final effRateText = effRate == 0 && monthlyTax > 0
        ? 'less than 0.1%'
        : '${effRate % 1 == 0 ? effRate.toInt() : effRate}%';
    final marginal =
        ((marginalRate((r['monthlyTaxable'] as double) * 12) * 100) + 0.5)
            .floorToDouble()
            .toInt();

    final showResults = basicNum > 0 && (r['net'] as double) >= 0;
    final tooLow = basicNum > 0 && !showResults;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Take-home pay',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _label('MONTHLY BASIC PAY'),
            TextField(
              controller: basic,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: Barako.text),
              decoration: InputDecoration(
                  prefixText: '₱ ', hintText: 'e.g. 25,000'),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('TAXABLE ALLOWANCE'),
                      TextField(
                        controller: taxAllow,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(color: Barako.text),
                        decoration: InputDecoration(
                            prefixText: '₱ ', hintText: '0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('NON-TAXABLE ALLOWANCE'),
                      TextField(
                        controller: nonTaxAllow,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(color: Barako.text),
                        decoration: InputDecoration(
                            prefixText: '₱ ', hintText: '0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Non-taxable covers de minimis benefits and allowances within BIR limits. They are added to your pay but not taxed. Contributions are figured on your basic pay.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 12, height: 1.4)),
            // The RN screen warns above 12,000, but the realistic monthly
            // total of the common de minimis items is 4,000 to 5,000, so
            // the compensation specialist lowered the trigger here.
            if (nonTaxAllowNum > 5000)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Heads up: each de minimis benefit has its own BIR ceiling. Amounts above those ceilings are not taxed right away, they first join the ₱90,000 a year cap together with your 13th month and other bonuses, and only the part above ₱90,000 gets taxed. A large non-taxable amount here can still overstate your take-home.',
                    style: TextStyle(
                        color: Barako.warning, fontSize: 12, height: 1.4)),
              ),
            if (showResults) ...[
              _label('SHOW RESULTS'),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in const [
                    ('cutoff', 'Per cutoff'),
                    ('month', 'Monthly'),
                    ('year', 'Per year'),
                  ])
                    ChoiceChip(
                      label: Text(p.$2),
                      selected: period == p.$1,
                      onSelected: (_) => setState(() => period = p.$1),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.background,
                      labelStyle: TextStyle(
                          color: period == p.$1
                              ? Barako.onPrimary
                              : Barako.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line('Basic pay', ms(r['basic'] as double),
                          strong: true),
                      if ((r['taxableAllowance'] as double) > 0)
                        _line('Taxable allowance',
                            '+ ${ms(r['taxableAllowance'] as double)}'),
                      if ((r['nonTaxableAllowance'] as double) > 0)
                        _line('Non-taxable allowance',
                            '+ ${ms(r['nonTaxableAllowance'] as double)}'),
                      if ((r['taxableAllowance'] as double) > 0 ||
                          (r['nonTaxableAllowance'] as double) > 0) ...[
                        Divider(color: Barako.border, height: 14),
                        _line('Gross pay', ms(gross), strong: true),
                      ],
                      Divider(color: Barako.border, height: 14),
                      _line('SSS', '- ${ms(r['sss'] as double)}'),
                      _line('PhilHealth',
                          '- ${ms(r['philhealth'] as double)}'),
                      _line('Pag-IBIG', '- ${ms(r['pagibig'] as double)}'),
                      _line('Income tax', '- ${ms(monthlyTax)}'),
                      Divider(color: Barako.border, height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(netLabel,
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text(ms(r['net'] as double),
                              style: TextStyle(
                                  color: Barako.primary,
                                  fontSize: 24,
                                  fontFamily: Barako.displayFont,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          period == 'cutoff'
                              ? 'An estimate for each of the two cutoffs (15th and end of month), splitting everything in half. Many employers deduct SSS, PhilHealth, and Pag-IBIG on just one cutoff, so one payout can be noticeably bigger and the other smaller. The two cutoffs together still match the monthly figure.'
                              : 'About ${_m((r['net'] as double) * 12)} a year, before any 13th month.',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHAT COMES OUT, AND WHY',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          'Contributions total ${ms(r['contributions'] as double)} $word. They come out before tax, so your taxable pay is ${ms(r['monthlyTaxable'] as double)}.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          'Income tax uses the graduated BIR table on your yearly taxable pay, spread across the year.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR TAX RATE',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          'Your income tax is about $effRateText of your gross pay.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          marginal == 0
                              ? 'Your taxable pay is within the tax-free ₱250,000 a year, so no income tax is due.'
                              : 'You are in the $marginal% tax bracket, so each extra ₱100 of taxable pay is taxed about ₱$marginal. A raise is only taxed at the margin, never your whole pay. Contributions can also rise a bit with a raise until their ceilings.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          'If you earn the minimum wage, your basic, overtime, holiday, and night pay are income tax free by law, so your real tax is likely zero.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ] else if (tooLow)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'That looks too low for a monthly salary. The minimum SSS, PhilHealth, and Pag-IBIG contributions come to about ${_m(r['contributions'] as double)}, so a basic pay under that would leave nothing to take home. Enter your full monthly basic pay.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 13, height: 1.4)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Enter your monthly basic pay to see the breakdown. Allowances add on top of it.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 13, height: 1.4)),
              ),
            const SizedBox(height: 12),
            Text(
                'Estimate based on $ratesYear SSS, PhilHealth, Pag-IBIG, and BIR rates. Contributions are figured on your basic pay, non-taxable allowances are not taxed, and low salaries still pay the minimum contributions. It assumes a full month worked with no absences, and no loan payments (SSS or Pag-IBIG salary loans), HMO share, or other company deductions. Your real payslip can differ with de minimis limits and your employer\'s rounding. Not a substitute for your official payslip or a BIR filing.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
