// 13th month pay: what a rank-and-file employee should receive by 24
// December, prorated for months worked, with the TRAIN 90,000 tax-free
// ceiling handled honestly (other bonuses share the same ceiling, and only
// the excess is taxed at the user's own bracket). Adapted from the RN
// screen on the golden-ported thirteenth engine.

import 'package:flutter/material.dart';

import '../money/phtax.dart' show ratesYear;
import '../money/thirteenth.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class ThirteenthCalculatorScreen extends StatefulWidget {
  const ThirteenthCalculatorScreen({super.key});

  @override
  State<ThirteenthCalculatorScreen> createState() =>
      _ThirteenthCalculatorScreenState();
}

class _ThirteenthCalculatorScreenState
    extends State<ThirteenthCalculatorScreen> {
  final basic = TextEditingController();
  final monthsWorked = TextEditingController();
  final otherBenefits = TextEditingController();

  @override
  void dispose() {
    basic.dispose();
    monthsWorked.dispose();
    otherBenefits.dispose();
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

  Widget _row(String label, String value) => Padding(
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
                    color: Barako.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final basicNum = _parse(basic.text);
    // Empty means a full year, matching the RN screen.
    final monthsNum =
        monthsWorked.text.isEmpty ? 12.0 : _parse(monthsWorked.text);
    final otherNum = _parse(otherBenefits.text);
    final r = thirteenthMonth(basicNum,
        monthsWorked: monthsNum, otherBenefits: otherNum);
    final ready = basicNum > 0;
    final taxed = ((r['taxOnExcess'] as double) + 0.5).floorToDouble() > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('13th month pay',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
                'Every rank-and-file employee who worked at least a month this year should receive 13th month pay, on or before 24 December. It is your basic salary for the year divided by 12.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 13, height: 1.4)),
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
                      _label('MONTHS WORKED THIS YEAR'),
                      TextField(
                        controller: monthsWorked,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Barako.text),
                        decoration: InputDecoration(hintText: '12'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('OTHER BONUSES THIS YEAR'),
                      TextField(
                        controller: otherBenefits,
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
                'Only basic pay counts, not overtime, allowances, or holiday pay. Sales commissions that form part of your basic wage do count. Other bonuses matter only for the ${_m(thirteenthTaxFreeCeiling)} tax-free ceiling.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 12, height: 1.4)),
            if (ready) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('YOUR 13TH MONTH PAY',
                                style: TextStyle(
                                    color: Barako.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2)),
                          ),
                          if (!taxed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Barako.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('TAX FREE',
                                  style: TextStyle(
                                      color: Barako.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_m(r['amount'] as double),
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 30,
                              fontFamily: Barako.displayFont,
                              fontWeight: FontWeight.w700)),
                      if ((r['monthsWorked'] as int) < 12)
                        Text(
                            'Prorated for ${r['monthsWorked']} ${r['monthsWorked'] == 1 ? 'month' : 'months'} worked this year.',
                            style: TextStyle(
                                color: Barako.muted, fontSize: 12)),
                      if (taxed) ...[
                        Divider(color: Barako.border, height: 16),
                        _row('Tax free part',
                            _m(r['taxFreePortion'] as double)),
                        _row('Taxable part', _m(r['taxable'] as double)),
                        _row('Estimated tax on the excess',
                            '- ${_m(r['taxOnExcess'] as double)}'),
                        Divider(color: Barako.border, height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text('You take home about',
                                  style: TextStyle(
                                      color: Barako.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Text(_m(r['net'] as double),
                                style: TextStyle(
                                    color: Barako.primary,
                                    fontSize: 20,
                                    fontFamily: Barako.displayFont,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
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
                      Text('GOOD TO KNOW',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          taxed
                              ? 'The first ${_m(thirteenthTaxFreeCeiling)} of your 13th month pay and other bonuses combined is tax free. Only the amount above that is taxed, at your income tax rate, which is why the tax here is an estimate.'
                              : 'Your 13th month pay is within the ${_m(thirteenthTaxFreeCeiling)} tax-free ceiling for 13th month pay and other bonuses combined, so no tax is taken.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          'It must be paid on or before 24 December. It is separate from any 14th month or performance bonus your employer chooses to give.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Enter your monthly basic pay to see your 13th month pay.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 13, height: 1.4)),
              ),
            const SizedBox(height: 12),
            Text(
                'Estimate based on $ratesYear rules (PD 851 and the ${_m(thirteenthTaxFreeCeiling)} TRAIN tax-free ceiling). It assumes a steady basic salary and counts basic pay only. Months on unpaid leave or SSS maternity benefit count less, because the law divides the basic pay you actually earned by 12. Managerial employees are not covered by PD 851, though many companies pay anyway. If you leave mid-year, you still get the prorated amount with your final pay. Your actual 13th month can differ if your pay changed during the year or your company integrates other pay. Not a substitute for your payslip.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
