import 'package:flutter/material.dart';

import '../money/analytics.dart' as analytics;
import '../theme.dart';
import '../typography.dart';
import 'amount_text.dart';
import 'salapify_chart.dart';

/// The first visible Insights v2 surface.
///
/// This widget owns presentation only. Every amount comes from the existing,
/// golden-verified analytics engine so the redesign cannot fork accounting
/// semantics from Reports or the ledger.
class InsightsOverviewV2 extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime ref;

  const InsightsOverviewV2({
    super.key,
    required this.data,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final series = analytics.monthlySeries(data['transactions'], 6, ref);
    final current = series.isEmpty
        ? const <String, dynamic>{
            'income': 0.0,
            'expenses': 0.0,
            'net': 0.0,
          }
        : series.last;
    final income = (current['income'] as num?)?.toDouble() ?? 0;
    final expenses = (current['expenses'] as num?)?.toDouble() ?? 0;
    final net = (current['net'] as num?)?.toDouble() ?? 0;
    final savingsRate = analytics.savingsRate(
      data['transactions'],
      data['payments'],
      ref,
    );

    final incomePoints = [
      for (final month in series)
        SalapifyChartPoint(
          month['label'] as String,
          (month['income'] as num).toDouble(),
        ),
    ];
    final expensePoints = [
      for (final month in series)
        SalapifyChartPoint(
          month['label'] as String,
          (month['expenses'] as num).toDouble(),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial snapshot',
                        style: AppText.subtitle.w8.tint(Barako.primaryText),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This month, from your actual Salapify records.',
                        style: AppText.small.tint(Barako.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Barako.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'OVERVIEW',
                    style: AppText.caption.w8.tint(Barako.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            _NetCashFlow(net: net),
            const SizedBox(height: Gap.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MoneyMetric(
                    label: 'Income',
                    value: income,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _MoneyMetric(
                    label: 'Expenses',
                    value: expenses,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            _RateMetric(rate: savingsRate),
            const SizedBox(height: Gap.xl),
            Text(
              'Cash flow trend',
              style: AppText.body.w7.tint(Barako.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              'Income and expenses across the last 6 months',
              style: AppText.caption.tint(Barako.textSecondary),
            ),
            const SizedBox(height: Gap.md),
            SalapifyLineChart(
              primary: incomePoints,
              secondary: expensePoints,
              primaryLabel: 'Income',
              secondaryLabel: 'Expenses',
              semanticLabel:
                  'Six month cash flow trend comparing income and expenses.',
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                _LegendDot(color: Barako.primary, label: 'Income'),
                const SizedBox(width: Gap.lg),
                _LegendDot(color: Barako.warningStrong, label: 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCashFlow extends StatelessWidget {
  final double net;

  const _NetCashFlow({required this.net});

  @override
  Widget build(BuildContext context) {
    final direction = net > 0
        ? 'Positive this month'
        : net < 0
        ? 'Negative this month'
        : 'Balanced this month';
    return Semantics(
      label: 'Net cash flow. $direction.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net cash flow', style: AppText.caption.tint(Barako.textSecondary)),
          const SizedBox(height: 4),
          AmountText(net, role: AmountRole.card, signed: true),
          const SizedBox(height: 4),
          Text(direction, style: AppText.small.tint(Barako.textSecondary)),
        ],
      ),
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  final String label;
  final double value;

  const _MoneyMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.md),
    decoration: BoxDecoration(
      color: Barako.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.tint(Barako.textSecondary)),
        const SizedBox(height: 6),
        AmountText(value, role: AmountRole.metric),
      ],
    ),
  );
}

class _RateMetric extends StatelessWidget {
  final double? rate;

  const _RateMetric({required this.rate});

  @override
  Widget build(BuildContext context) {
    final value = rate == null ? 'Not enough income data yet' : '${(rate! * 100).round()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Savings rate',
              style: AppText.caption.tint(Barako.textSecondary),
            ),
          ),
          Text(value, style: AppText.body.w8.tint(Barako.primaryText)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.caption.tint(Barako.textSecondary)),
    ],
  );
}
