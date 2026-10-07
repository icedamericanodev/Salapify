import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

// Salapify's chart layer over fl_chart. The founder-approved architecture is a
// FIT-BASED split (docs/reviews/charting-architecture-evaluation.md): fl_chart
// carries the data-rich, part-to-whole and future investment charts, while the
// bespoke Sweldo Timeline / sparkline lines stay hand-rolled CustomPainters
// where their exact look and cheap repaint matter. This file used to also carry
// a SalapifyLineChart wrapper; it was never called (the live line charts are the
// CustomPainters in insights.dart, cashflow.dart and timeline_sparkline.dart),
// so it was removed rather than kept as a second, divergent line renderer.

/// One slice of a part-to-whole chart. The caller passes an already-computed
/// value and the colour to use (normally an index into Barako.dataSeries), so
/// the chart owns no accounting or colour policy.
class SalapifyDonutSlice {
  final String label;
  final double value;
  final Color color;
  const SalapifyDonutSlice(this.label, this.value, this.color);
}

/// Accessible part-to-whole donut. The essential amounts and percentages must
/// still be PRINTED by the caller (a legend of rows), because this is an
/// enhancement, never the only source of the numbers: the CustomPaint is hidden
/// from the screen reader and the whole widget carries one [semanticLabel]
/// sentence instead. Honours reduce-motion.
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
      return Semantics(
        label: semanticLabel,
        child: SizedBox.square(dimension: size),
      );
    }
    // A hairline in the card colour separates a slice from its neighbour and
    // from a light card, where a bright dopamine hue can otherwise sit at a low
    // edge contrast. On the near-black dark card the hues are already crisp, but
    // the stroke is harmless there.
    final stroke = BorderSide(color: Barako.card, width: 1.5);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: size * .30,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              sections: [
                for (final slice in positive)
                  PieChartSectionData(
                    value: slice.value,
                    color: slice.color,
                    showTitle: false,
                    radius: size * .17,
                    borderSide: stroke,
                  ),
              ],
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }
}
