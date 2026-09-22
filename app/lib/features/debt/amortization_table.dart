import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/loan.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The payoff schedule, ported from src/components/BankAmortizationTable.tsx.
///
/// A phone cannot show a five column table at a readable size, so this is NOT
/// a table. Each month is a row with the instalment on the right and the split
/// between interest and principal underneath, which is the one thing the table
/// existed to communicate: early payments are mostly interest.
class AmortizationTable extends StatefulWidget {
  const AmortizationTable({
    super.key,
    required this.palette,
    required this.result,
  });

  final Palette palette;
  final LoanCalculationResult result;

  @override
  State<AmortizationTable> createState() => _AmortizationTableState();
}

class _AmortizationTableState extends State<AmortizationTable> {
  bool _expanded = false;

  /// Twelve rows unless asked for more. A 30 year loan is 360 rows, and
  /// rendering all of them inside a scrolling sheet is both slow and useless.
  static const int _collapsedRows = 12;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final LoanCalculationResult r = widget.result;
    if (r.amortizationSchedule.isEmpty) return const SizedBox.shrink();

    final int total = r.amortizationSchedule.length;
    final int shown = _expanded ? total : total.clamp(0, _collapsedRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StatPair(
          left: StatCard(
            palette: p,
            label: 'Monthly payment',
            value: formatPeso(r.monthlyPayment),
            valueColor: p.accent,
          ),
          right: StatCard(
            palette: p,
            label: 'Total interest',
            value: formatPeso(r.totalInterest),
            caption: 'On top of what you borrowed',
            valueColor: p.negative,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: <Widget>[
            Expanded(child: Text('Payoff schedule', style: AppType.section(p))),
            Text('$total months', style: AppType.rowMeta(p)),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < shown; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: p.border),
                _row(p, r.amortizationSchedule[i]),
              ],
            ],
          ),
        ),
        if (total > _collapsedRows) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Text(
                  _expanded ? 'Show less' : 'Show all $total months',
                  style: AppType.button(p, color: p.accent),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(Palette p, AmortizationRow row) {
    // How much of this instalment is interest. Early rows are mostly interest
    // and late rows mostly principal, and the bar makes that visible without
    // anyone reading two columns of figures.
    final double total = row.principalComponent + row.interestComponent;
    final double interestShare = total > 0 ? row.interestComponent / total : 0;

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '${row.period}',
                  style: AppType.rowMeta(
                    p,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  'Interest ${formatPeso(row.interestComponent, showDecimals: false)} '
                  '· Principal ${formatPeso(row.principalComponent, showDecimals: false)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowMeta(p),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                formatPeso(row.scheduledPayment, showDecimals: false),
                style: AppType.amountSmall(p).copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 4,
              // The clamp keeps a sliver of colour visible when a share is
              // small but real. It is deliberately NOT applied when a share is
              // exactly zero: a 0% loan drew a red tick of interest on every
              // row, which is a bar saying something the numbers beside it
              // flatly deny.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (interestShare > 0)
                    Expanded(
                      flex: (interestShare * 100).round().clamp(1, 99),
                      child: ColoredBox(color: p.negative),
                    ),
                  if (interestShare < 1)
                    Expanded(
                      flex: (100 - interestShare * 100).round().clamp(1, 99),
                      child: ColoredBox(color: p.positive),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Balance after: ${formatPeso(row.remainingBalance, showDecimals: false)}',
                  style: AppType.caption(p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
