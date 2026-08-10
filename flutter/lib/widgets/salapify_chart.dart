import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// One period in a financial series. The UI receives already-computed values;
/// charts never own accounting or analytics logic.
class SalapifyChartPoint {
  final String label;
  final double value;

  const SalapifyChartPoint(this.label, this.value);
}

/// Shared line-chart renderer for Insights and Reports.
///
/// It deliberately owns only presentation: axes, touch affordance, theme and
/// semantics. Callers remain responsible for producing canonical financial
/// values from the ledger/analytics engines.
class SalapifyLineChart extends StatelessWidget {
  final List<SalapifyChartPoint> primary;
  final List<SalapifyChartPoint> secondary;
  final String semanticLabel;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double height;

  const SalapifyLineChart({
    super.key,
    required this.primary,
    required this.semanticLabel,
    required this.primaryLabel,
    this.secondary = const [],
    this.secondaryLabel,
    this.primaryColor,
    this.secondaryColor,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...primary.map((p) => p.value), ...secondary.map((p) => p.value)];
    if (all.isEmpty) {
      return Semantics(
        label: semanticLabel,
        child: SizedBox(
          height: height,
          child: Center(child: Text('Not enough history yet', style: AppText.small)),
        ),
      );
    }

    final low = all.reduce((a, b) => a < b ? a : b);
    final high = all.reduce((a, b) => a > b ? a : b);
    final spread = (high - low).abs();
    final pad = spread == 0 ? (high.abs() * .12).clamp(1.0, double.infinity) : spread * .12;
    final pColor = primaryColor ?? Barako.primary;
    final sColor = secondaryColor ?? Barako.warningStrong;

    LineChartBarData line(List<SalapifyChartPoint> values, Color color) => LineChartBarData(
      isCurved: true,
      barWidth: 3,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].value)],
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: low - pad,
              maxY: high + pad,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: Barako.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= primary.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(primary[i].label, style: AppText.caption),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Barako.surfaceRaised,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final label = spot.barIndex == 0 ? primaryLabel : (secondaryLabel ?? 'Value');
                    return LineTooltipItem('$label\n${spot.y.toStringAsFixed(0)}', AppText.caption);
                  }).toList(),
                ),
              ),
              lineBarsData: [line(primary, pColor), if (secondary.isNotEmpty) line(secondary, sColor)],
            ),
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }
}

class SalapifyDonutSlice {
  final String label;
  final double value;
  final Color color;
  const SalapifyDonutSlice(this.label, this.value, this.color);
}

/// Accessible part-to-whole renderer. Essential amounts/percentages must still
/// be printed by the caller; the chart is enhancement, never the only source.
class SalapifyDonutChart extends StatelessWidget {
  final List<SalapifyDonutSlice> slices;
  final String semanticLabel;
  final double size;

  const SalapifyDonutChart({
    super.key,
    required this.slices,
    required this.semanticLabel,
    this.size = 156,
  });

  @override
  Widget build(BuildContext context) {
    final positive = slices.where((s) => s.value > 0).toList();
    if (positive.isEmpty) {
      return Semantics(label: semanticLabel, child: SizedBox.square(dimension: size));
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: size * .28,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              sections: [
                for (final slice in positive)
                  PieChartSectionData(
                    value: slice.value,
                    color: slice.color,
                    showTitle: false,
                    radius: size * .16,
                  ),
              ],
            ),
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }
}
