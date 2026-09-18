import 'package:flutter/material.dart';

import '../../core/money/business_tax.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The business tax simulator, ported from
/// src/components/BusinessTaxSimulatorModal.tsx.
///
/// It compares EVERY regime at once rather than only the one selected. A
/// simulator that shows one answer makes somebody guess which to try; showing
/// all four and naming the cheapest is the actual decision.
class BusinessTaxSheet extends StatefulWidget {
  const BusinessTaxSheet({super.key, required this.palette});

  final Palette palette;

  static Future<void> show(BuildContext context, Palette palette) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => BusinessTaxSheet(palette: palette),
    );
  }

  @override
  State<BusinessTaxSheet> createState() => _BusinessTaxSheetState();
}

class _BusinessTaxSheetState extends State<BusinessTaxSheet> {
  final TextEditingController _revenue = TextEditingController(text: '3000000');
  final TextEditingController _cogs = TextEditingController(text: '1200000');
  final TextEditingController _opex = TextEditingController(text: '600000');

  EntityType _entity = EntityType.soleProp;
  VatStatus _vat = VatStatus.nonVat;
  TaxRegime _regime = TaxRegime.eightPercent;

  @override
  void dispose() {
    _revenue.dispose();
    _cogs.dispose();
    _opex.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  BusinessFinancials get _financials => BusinessFinancials(
    revenue: _num(_revenue),
    cogs: _num(_cogs),
    opex: _num(_opex),
  );

  BusinessTaxResult _run(TaxRegime regime) => calculateBusinessTax(
    entity: _entity,
    financials: _financials,
    vatStatus: _vat,
    regime: regime,
  );

  static const List<(TaxRegime, String)> _regimes = <(TaxRegime, String)>[
    (TaxRegime.eightPercent, '8% flat'),
    (TaxRegime.graduatedOsd, 'OSD 40%'),
    (TaxRegime.graduatedItemized, 'Itemized'),
    (TaxRegime.corporateRcit, 'RCIT'),
  ];

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final BusinessTaxResult chosen = _run(_regime);

    // Which regime costs least on these numbers. Computed, never assumed:
    // the answer flips with the cost structure, which is the whole point.
    TaxRegime cheapest = _regimes.first.$1;
    double lowest = double.infinity;
    for (final (TaxRegime r, String _) in _regimes) {
      final double t = _run(r).totalTax;
      if (t < lowest) {
        lowest = t;
        cheapest = r;
      }
    }

    return SheetScaffold(
      palette: p,
      icon: Icons.storefront_outlined,
      title: 'Business Tax Simulator',
      subtitle: 'Compare every BIR regime on your own numbers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            palette: p,
            label: 'Gross revenue for the year',
            controller: _revenue,
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'Cost of goods sold',
            controller: _cogs,
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'Operating expenses',
            controller: _opex,
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.lg),
          Text('Business type', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<EntityType>(
            palette: p,
            selected: _entity,
            options: const <(EntityType, String)>[
              (EntityType.soleProp, 'Sole proprietor'),
              (EntityType.partnership, 'Partnership'),
            ],
            onSelect: (EntityType e) => setState(() => _entity = e),
          ),
          const SizedBox(height: Spacing.md),
          Text('VAT registration', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<VatStatus>(
            palette: p,
            selected: _vat,
            options: const <(VatStatus, String)>[
              (VatStatus.nonVat, 'Non-VAT'),
              (VatStatus.vat, 'VAT registered'),
            ],
            onSelect: (VatStatus v) => setState(() => _vat = v),
          ),
          const SizedBox(height: Spacing.md),
          Text('Tax regime', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<TaxRegime>(
            palette: p,
            selected: _regime,
            options: _regimes,
            onSelect: (TaxRegime r) => setState(() => _regime = r),
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: cheapest == _regime ? p.positiveSoft : p.warningSoft,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  cheapest == _regime
                      ? 'This is the cheapest regime for these numbers'
                      : 'A cheaper regime exists',
                  style: AppType.section(p).copyWith(
                    color: cheapest == _regime ? p.positive : p.textPrimary,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  cheapest == _regime
                      ? 'Nothing on this list costs you less.'
                      : '${_label(cheapest)} would cost '
                            '${formatPeso(chosen.totalTax - lowest)} less a year.',
                  style: AppType.body(p),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text('Every regime, side by side', style: AppType.section(p)),
          const SizedBox(height: Spacing.sm),
          for (final (TaxRegime r, String label) in _regimes)
            _regimeRow(p, r, label, cheapest == r),
          const SizedBox(height: Spacing.lg),
          _card(p, 'Your selected regime', <Widget>[
            BreakdownRow(
              palette: p,
              label: 'Gross profit',
              value: formatPeso(chosen.grossProfit),
            ),
            BreakdownRow(
              palette: p,
              label: 'Net taxable income',
              value: formatPeso(chosen.netTaxableIncome),
            ),
            BreakdownRow(
              palette: p,
              label: 'Income tax',
              value: formatPeso(chosen.incomeTax),
              valueColor: p.negative,
            ),
            BreakdownRow(
              palette: p,
              label: 'Percentage tax',
              value: formatPeso(chosen.businessTax),
              valueColor: p.negative,
            ),
            Divider(height: Spacing.lg, color: p.border),
            BreakdownRow(
              palette: p,
              label: 'Total tax',
              value: formatPeso(chosen.totalTax),
              valueColor: p.negative,
              emphasis: true,
            ),
            BreakdownRow(
              palette: p,
              label: 'Net income after tax',
              value: formatPeso(chosen.netIncome),
              valueColor: p.positive,
              emphasis: true,
            ),
            BreakdownRow(
              palette: p,
              label: 'Effective rate on revenue',
              value: '${chosen.effectiveTaxRate.toStringAsFixed(2)}%',
            ),
          ]),
          const SizedBox(height: Spacing.lg),
          Text('Forms you would file', style: AppType.section(p)),
          const SizedBox(height: Spacing.sm),
          for (final ComplianceForm f in chosen.complianceForms)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(f.form, style: AppType.rowTitle(p)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            f.frequency,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(f.name, style: AppType.rowMeta(p)),
                    Text('Due: ${f.deadline}', style: AppType.rowMeta(p)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Spacing.sm),
          _note(
            p,
            _vat == VatStatus.vat
                ? 'VAT is treated as pass-through here, so it adds nothing to '
                      'your cost. Output VAT is billed to your customer and input '
                      'VAT is credited back. This is a cash-flow view, not a '
                      'filing figure.'
                : 'Non-VAT businesses pay 3% percentage tax on gross sales, '
                      'except under the 8% regime, which replaces it.',
          ),
        ],
      ),
    );
  }

  Widget _regimeRow(Palette p, TaxRegime r, String label, bool cheapest) {
    final BusinessTaxResult res = _run(r);
    final bool selected = r == _regime;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? p.accentSoft : p.card,
          borderRadius: BorderRadius.circular(Radii.control),
          child: InkWell(
            onTap: () => setState(() => _regime = r),
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: selected ? p.accent : p.border),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(label, style: AppType.rowTitle(p)),
                        ),
                        if (cheapest) ...<Widget>[
                          const SizedBox(width: Spacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.positiveSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CHEAPEST',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: p.positive,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    formatPeso(res.totalTax, showDecimals: false),
                    style: AppType.amountSmall(
                      p,
                    ).copyWith(color: cheapest ? p.positive : p.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(TaxRegime r) =>
      _regimes.firstWhere(((TaxRegime, String) e) => e.$1 == r).$2;

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
