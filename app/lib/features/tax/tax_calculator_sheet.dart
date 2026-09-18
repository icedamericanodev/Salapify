import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ph_tax.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The tax calculator, ported from src/components/TaxCalculatorModal.tsx.
///
/// Three tabs over the engine in core/money/ph_tax.dart: an employee's
/// take-home, the 13th month, and the freelancer's 8% against graduated
/// choice. Every figure comes from the engine, which is golden locked against
/// the prototype, so this sheet does no arithmetic of its own.
class TaxCalculatorSheet extends StatefulWidget {
  const TaxCalculatorSheet({super.key, required this.palette});

  final Palette palette;

  static Future<void> show(BuildContext context, Palette palette) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => TaxCalculatorSheet(palette: palette),
    );
  }

  @override
  State<TaxCalculatorSheet> createState() => _TaxCalculatorSheetState();
}

class _TaxCalculatorSheetState extends State<TaxCalculatorSheet> {
  int _tab = 0;

  final TextEditingController _salary = TextEditingController(text: '32500');
  PayFrequency _frequency = PayFrequency.semiMonthly;

  final TextEditingController _basic = TextEditingController(text: '30000');
  final TextEditingController _months = TextEditingController(text: '12');

  final TextEditingController _gross = TextEditingController(text: '1200000');
  FreelanceTaxOption _option = FreelanceTaxOption.eightPercentGit;

  @override
  void dispose() {
    _salary.dispose();
    _basic.dispose();
    _months.dispose();
    _gross.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    return SheetScaffold(
      palette: p,
      icon: Icons.calculate_outlined,
      title: 'Tax Calculator',
      subtitle: 'BIR TRAIN law rates, current for 2024 and 2025',
      tabs: const <String>['Take-home Pay', '13th Month', 'Freelance'],
      selectedTab: _tab,
      onSelectTab: (int i) => setState(() => _tab = i),
      child: switch (_tab) {
        0 => _employee(p),
        1 => _thirteenth(p),
        _ => _freelance(p),
      },
    );
  }

  // ------------------------------------------------------------- employee

  Widget _employee(Palette p) {
    final EmployeeTaxCalculation r = calculateEmployeeTaxDeductions(
      inputSalary: _num(_salary),
      inputFrequency: _frequency,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetField(
          palette: p,
          label: 'Your salary, per payout',
          controller: _salary,
          prefix: '₱ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.md),
        Text('How often you are paid', style: AppType.label(p)),
        const SizedBox(height: Spacing.xs),
        SegmentedChoice<PayFrequency>(
          palette: p,
          selected: _frequency,
          options: const <(PayFrequency, String)>[
            (PayFrequency.semiMonthly, '15th & 30th'),
            (PayFrequency.monthly, 'Monthly'),
            (PayFrequency.biWeekly, 'Every 2 weeks'),
            (PayFrequency.annually, 'Yearly'),
          ],
          onSelect: (PayFrequency f) => setState(() => _frequency = f),
        ),
        const SizedBox(height: Spacing.lg),
        StatPair(
          left: StatCard(
            palette: p,
            label: 'Take home',
            value: formatPeso(r.netTakeHome),
            caption: 'Every month, after everything',
            valueColor: p.positive,
          ),
          right: StatCard(
            palette: p,
            label: 'Per cutoff',
            value: formatPeso(r.semiMonthlyTakeHome),
            caption: 'Half of the monthly figure',
          ),
        ),
        const SizedBox(height: Spacing.lg),
        _card(p, 'What comes out', <Widget>[
          BreakdownRow(
            palette: p,
            label: 'Gross monthly',
            value: formatPeso(r.grossMonthlyIncome),
          ),
          BreakdownRow(
            palette: p,
            label: 'SSS',
            value: '- ${formatPeso(r.sss)}',
            valueColor: p.negative,
          ),
          BreakdownRow(
            palette: p,
            label: 'PhilHealth',
            value: '- ${formatPeso(r.philhealth)}',
            valueColor: p.negative,
          ),
          BreakdownRow(
            palette: p,
            label: 'Pag-IBIG',
            value: '- ${formatPeso(r.pagibig)}',
            valueColor: p.negative,
          ),
          BreakdownRow(
            palette: p,
            label: 'Withholding tax',
            value: '- ${formatPeso(r.withholdingTax)}',
            valueColor: p.negative,
          ),
          Divider(height: Spacing.lg, color: p.border),
          BreakdownRow(
            palette: p,
            label: 'Net take home',
            value: formatPeso(r.netTakeHome),
            valueColor: p.positive,
            emphasis: true,
          ),
        ]),
        const SizedBox(height: Spacing.md),
        _note(
          p,
          'Contributions are worked out from your BASE salary only. '
          'Allowances, overtime and night differential change the tax, not '
          'the contributions.',
        ),
      ],
    );
  }

  // ----------------------------------------------------------- 13th month

  Widget _thirteenth(Palette p) {
    final int months = (int.tryParse(_months.text.trim()) ?? 12).clamp(0, 12);
    final ThirteenthMonthPlan plan = calculate13thMonthPay(
      basicMonthlySalary: _num(_basic),
      monthsWorked: months,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetField(
          palette: p,
          label: 'Basic monthly salary',
          controller: _basic,
          prefix: '₱ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.md),
        SheetField(
          palette: p,
          label: 'Months worked this year',
          controller: _months,
          hint: '12',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.lg),
        StatCard(
          palette: p,
          label: 'Your 13th month',
          value: formatPeso(plan.net13thMonthPay),
          caption: plan.taxableExcessAmount > 0
              ? 'After tax on the amount above ₱90,000'
              : 'Completely tax free, it is under ₱90,000',
          valueColor: p.positive,
        ),
        const SizedBox(height: Spacing.lg),
        _card(p, 'How it is worked out', <Widget>[
          BreakdownRow(
            palette: p,
            label: 'Gross (salary x months / 12)',
            value: formatPeso(plan.calculatedGrossAmount),
          ),
          BreakdownRow(
            palette: p,
            label: 'Tax free portion',
            value: formatPeso(plan.taxExemptAmount),
            valueColor: p.positive,
          ),
          BreakdownRow(
            palette: p,
            label: 'Taxable excess',
            value: formatPeso(plan.taxableExcessAmount),
          ),
          BreakdownRow(
            palette: p,
            label: 'Estimated tax',
            value: '- ${formatPeso(plan.estimatedWithholdingTax)}',
            valueColor: p.negative,
          ),
          Divider(height: Spacing.lg, color: p.border),
          BreakdownRow(
            palette: p,
            label: 'Net 13th month',
            value: formatPeso(plan.net13thMonthPay),
            valueColor: p.positive,
            emphasis: true,
          ),
        ]),
        const SizedBox(height: Spacing.lg),
        Text('A suggested split', style: AppType.section(p)),
        const SizedBox(height: Spacing.sm),
        for (final ThirteenthMonthAllocation alloc in plan.allocations)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      '${alloc.percentage}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(alloc.category, style: AppType.rowTitle(p)),
                        Text(alloc.note, style: AppType.rowMeta(p)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    formatPeso(alloc.targetAmount, showDecimals: false),
                    style: AppType.amountSmall(p),
                  ),
                ],
              ),
            ),
          ),
        _note(
          p,
          'The tax on the excess is estimated at 20%, which is what the '
          'prototype does. Your payroll may withhold at your real bracket '
          'instead.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ freelance

  Widget _freelance(Palette p) {
    final double gross = _num(_gross);
    final FreelanceTaxCalculation git = calculateFreelanceTax(
      annualGrossIncome: gross,
    );
    final FreelanceTaxCalculation graduated = calculateFreelanceTax(
      annualGrossIncome: gross,
      taxOption: FreelanceTaxOption.graduatedRates,
    );
    final FreelanceTaxCalculation chosen =
        _option == FreelanceTaxOption.eightPercentGit ? git : graduated;
    final bool gitWins = git.estimatedTaxDue <= graduated.estimatedTaxDue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetField(
          palette: p,
          label: 'Your gross income for the year',
          controller: _gross,
          prefix: '₱ ',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.md),
        SegmentedChoice<FreelanceTaxOption>(
          palette: p,
          selected: _option,
          options: const <(FreelanceTaxOption, String)>[
            (FreelanceTaxOption.eightPercentGit, '8% flat'),
            (FreelanceTaxOption.graduatedRates, 'Graduated'),
          ],
          onSelect: (FreelanceTaxOption o) => setState(() => _option = o),
        ),
        const SizedBox(height: Spacing.lg),
        // The recommendation is the point of the tab. Naming the cheaper
        // option outright is more use than two columns of figures.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: p.positiveSoft,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                gitWins ? 'The 8% option is cheaper' : 'Graduated is cheaper',
                style: AppType.section(p).copyWith(color: p.positive),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                gross <= 0
                    ? 'Enter your yearly gross to compare the two.'
                    : 'You would save ${formatPeso((git.estimatedTaxDue - graduated.estimatedTaxDue).abs())} '
                          'a year by choosing it.',
                style: AppType.body(p),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        _card(p, 'Side by side', <Widget>[
          BreakdownRow(
            palette: p,
            label: '8% of gross above ₱250,000',
            value: formatPeso(git.estimatedTaxDue),
            valueColor: gitWins ? p.positive : null,
            emphasis: gitWins,
          ),
          BreakdownRow(
            palette: p,
            label: 'Graduated brackets on the full gross',
            value: formatPeso(graduated.estimatedTaxDue),
            valueColor: gitWins ? null : p.positive,
            emphasis: !gitWins,
          ),
        ]),
        const SizedBox(height: Spacing.md),
        _card(p, 'Your choice, in detail', <Widget>[
          BreakdownRow(
            palette: p,
            label: 'Allowable deduction',
            value: formatPeso(chosen.allowableDeduction),
          ),
          BreakdownRow(
            palette: p,
            label: 'Taxable base',
            value: formatPeso(chosen.taxableBase),
          ),
          BreakdownRow(
            palette: p,
            label: 'Tax due for the year',
            value: formatPeso(chosen.estimatedTaxDue),
            valueColor: p.negative,
            emphasis: true,
          ),
          BreakdownRow(
            palette: p,
            label: 'Effective rate',
            value: '${chosen.effectiveTaxRate.toStringAsFixed(2)}%',
          ),
          BreakdownRow(
            palette: p,
            label: 'Set aside each month',
            value: formatPeso(chosen.monthlyTaxProvision),
          ),
          BreakdownRow(
            palette: p,
            label: 'Suggested lean-month buffer',
            value: formatPeso(chosen.leanMonthsBufferRecommended),
          ),
        ]),
        const SizedBox(height: Spacing.md),
        _note(
          p,
          'The 8% option replaces both income tax and percentage tax, and is '
          'only open to you if your gross stays under the VAT threshold. '
          'Confirm with the BIR before you elect it.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- bits

  Widget _card(Palette p, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppType.section(p)),
          const SizedBox(height: Spacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _note(Palette p, String text) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 14, color: p.textMuted),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text, style: AppType.caption(p))),
        ],
      ),
    );
  }
}
