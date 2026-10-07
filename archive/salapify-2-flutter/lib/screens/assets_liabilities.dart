// Assets vs Liabilities (mockup screen 8): a Net worth / Own / Owe selector, a
// donut of where the money sits by category, and a printed breakdown.
//
// The donut is an ENHANCEMENT, never the only source: SalapifyDonutChart hides
// itself from the screen reader and the caller PRINTS every amount and percent
// beside it (the legend and the breakdown list), so a colour-blind reader loses
// nothing. Every figure comes from netWorthParts (the totals) and
// assetLiabilityBreakdown (the slices), which is tested to reconcile with those
// totals to the centavo, so this screen can never disagree with the hero.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/account_taxonomy.dart' show AccountClass;
import '../money/accounts_breakdown.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/statements.dart' show netWorthParts;
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_chart.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';

enum AssetsView { netWorth, own, owe }

class AssetsLiabilitiesScreen extends StatefulWidget {
  final SalapifyStore store;
  final AssetsView initial;
  const AssetsLiabilitiesScreen({
    super.key,
    required this.store,
    this.initial = AssetsView.own,
  });

  /// Open straight to the assets (Own) or liabilities (Owe) view, the way the
  /// hero's two totals link in.
  static Widget assets(SalapifyStore store) =>
      AssetsLiabilitiesScreen(store: store, initial: AssetsView.own);
  static Widget liabilities(SalapifyStore store) =>
      AssetsLiabilitiesScreen(store: store, initial: AssetsView.owe);

  @override
  State<AssetsLiabilitiesScreen> createState() =>
      _AssetsLiabilitiesScreenState();
}

class _AssetsLiabilitiesScreenState extends State<AssetsLiabilitiesScreen> {
  late AssetsView _view = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assets and liabilities')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final parts = netWorthParts(
              widget.store.data,
              fx: widget.store.fxTable,
            );
            final assets = parts['assets'] as double;
            final liabilities = parts['liabilities'] as double;
            final netWorth = parts['netWorth'] as double;
            final slices = assetLiabilityBreakdown(
              widget.store.data,
              fx: widget.store.fxTable,
            );
            final assetSlices =
                slices.where((s) => s.cls == AccountClass.asset).toList();
            final liaSlices =
                slices.where((s) => s.cls == AccountClass.liability).toList();

            return ListView(
              padding: Insets.screen,
              children: [
                Segmented<AssetsView>(
                  options: const [
                    SegmentOption(value: AssetsView.netWorth, label: 'Net worth'),
                    SegmentOption(value: AssetsView.own, label: 'Own'),
                    SegmentOption(value: AssetsView.owe, label: 'Owe'),
                  ],
                  current: _view,
                  onPick: (v) {
                    Haptics.select();
                    setState(() => _view = v);
                  },
                ),
                const SizedBox(height: Gap.lg),
                if (_view == AssetsView.netWorth)
                  _netWorthCard(netWorth, assets, liabilities)
                else ...[
                  _donutCard(
                    title: _view == AssetsView.own ? 'Total assets' : 'Total owed',
                    total: _view == AssetsView.own ? assets : liabilities,
                    slices: _view == AssetsView.own ? assetSlices : liaSlices,
                  ),
                  const SizedBox(height: Gap.lg),
                  _breakdownList(
                    _view == AssetsView.own ? assetSlices : liaSlices,
                    _view == AssetsView.own ? assets : liabilities,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The Net worth view: the net figure over a two-slice Owned/Owed donut, then
  /// both breakdowns, so the whole position reads on one screen.
  Widget _netWorthCard(double netWorth, double assets, double liabilities) {
    final owned = assets > 0 ? assets : 0.0;
    final owed = liabilities > 0 ? liabilities : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.hero),
            border: Border.all(color: Barako.border),
            gradient: Barako.heroWash,
          ),
          padding: Insets.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NET WORTH', style: Barako.kickerStyle),
              const SizedBox(height: Gap.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoneyText(netWorth),
                  maxLines: 1,
                  style: AppText.amountLg.w8,
                ),
              ),
              const SizedBox(height: Gap.lg),
              Center(
                child: SalapifyDonutChart(
                  semanticLabel:
                      'Owned ${formatMoneyText(owned)}, owed ${formatMoneyText(owed)}.',
                  slices: [
                    SalapifyDonutSlice('Owned', owned, Barako.primary),
                    SalapifyDonutSlice('Owed', owed, Barako.warning),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              _legendRow(Barako.primary, 'Owned', owned, assets + liabilities),
              const SizedBox(height: Gap.sm),
              _legendRow(Barako.warning, 'Owed', owed, assets + liabilities),
            ],
          ),
        ),
      ],
    );
  }

  Widget _donutCard({
    required String title,
    required double total,
    required List<BreakdownSlice> slices,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.border),
        gradient: Barako.heroWash,
      ),
      padding: Insets.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: Barako.kickerStyle),
          const SizedBox(height: Gap.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoneyText(total),
              maxLines: 1,
              style: AppText.amountLg.w8,
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (slices.isEmpty)
            Text(
              'Nothing here yet.',
              style: AppText.small.tint(Barako.muted),
            )
          else ...[
            Center(
              child: SalapifyDonutChart(
                semanticLabel: _donutSemantics(title, slices),
                slices: [
                  for (var i = 0; i < slices.length; i++)
                    SalapifyDonutSlice(
                      slices[i].label,
                      slices[i].total.abs(),
                      Barako.dataSeries[i % Barako.dataSeries.length],
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            for (var i = 0; i < slices.length; i++) ...[
              if (i > 0) const SizedBox(height: Gap.sm),
              _legendRow(
                Barako.dataSeries[i % Barako.dataSeries.length],
                slices[i].label,
                slices[i].total,
                total,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _donutSemantics(String title, List<BreakdownSlice> slices) {
    final parts = slices
        .map((s) => '${s.label} ${formatMoneyText(s.total)}')
        .join(', ');
    return '$title by category: $parts.';
  }

  /// A legend line: colour dot, label, the percent of the whole, the peso. The
  /// percent is printed, never only encoded in the slice, so meaning does not
  /// ride on colour. Percent is null-safe against a zero denominator.
  Widget _legendRow(Color color, String label, double value, double whole) {
    final pct = whole.abs() < 0.005 ? 0 : (value / whole * 100).round();
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.tint(Barako.text),
          ),
        ),
        const SizedBox(width: Gap.sm),
        Text('$pct%', style: AppText.small.w6.tint(Barako.muted)),
        const SizedBox(width: Gap.md),
        Text(
          formatMoneyText(value),
          style: AppText.small.w7.tint(Barako.text).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _breakdownList(List<BreakdownSlice> slices, double total) {
    if (slices.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BREAKDOWN', style: Barako.kickerStyle),
            const SizedBox(height: Gap.sm),
            for (var i = 0; i < slices.length; i++) ...[
              if (i > 0) Divider(height: Gap.lg, color: Barako.border),
              _breakdownRow(slices[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(BreakdownSlice s) {
    final unit = s.id == 'receivables' || s.id == 'payables'
        ? (s.count == 1 ? 'person' : 'people')
        : (s.count == 1 ? 'account' : 'accounts');
    return Row(
      children: [
        SalapifyGlyph(breakdownGlyph(s.id), size: IconSizes.inline),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.w7.tint(Barako.text),
              ),
              Text('${s.count} $unit', style: AppText.caption.tint(Barako.muted)),
            ],
          ),
        ),
        const SizedBox(width: Gap.sm),
        Text(
          formatMoneyText(s.total),
          style: AppText.amountRow.tint(Barako.text),
        ),
      ],
    );
  }
}
