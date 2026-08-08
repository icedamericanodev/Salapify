// The shared frame around a financial chart.
//
// The chart PAINTERS legitimately differ per purpose (a cash flow projection
// is not a category donut), but the furniture around them had no reason to:
// every chart card hand-rolled its own kicker, its own period control row,
// its own legend dots and its own caption, so Reports and Insights graphs
// read as cousins from different families. This widget owns the furniture;
// the chart stays whatever widget the screen paints.
//
// The caption slot exists because of the audit's rule that every chart
// states its own conclusion: a chart with no printed number cannot answer
// "was July worse than June" and taxes the reader to do the reading the app
// should have done. Passing a caption with at least one figure in it is the
// convention; the slot being right here makes the omission visible in review.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'section.dart';

class ChartFrame extends StatelessWidget {
  /// The uppercase kicker naming the chart ("SIX MONTH TREND").
  final String kicker;

  /// The chart itself. Painting stays the screen's business, and so do its
  /// semantics: a bare CustomPaint is invisible to a screen reader, so a
  /// chart passed here either carries its own Semantics summary (the cash
  /// flow chart's pattern) or accepts that the caption is all a screen
  /// reader gets. A frame cannot know which, so it enforces neither.
  final Widget chart;

  /// The one-sentence conclusion under the chart, carrying at least one
  /// printed number. Nullable for the rare chart whose numbers live in a
  /// legend, but absence should be a decision, not a default.
  final String? caption;

  /// A short factual line under the kicker naming what the chart shows
  /// ("Last 6 months, spending per month"). Added in Phase 5 when Reports
  /// adopted the frame: its charts carried this line already, and losing it
  /// would have traded shared furniture for less information.
  final String? contextLine;

  /// A styled conclusion widget rendered where [caption] would go, for the
  /// chart whose read carries semantic color (Reports tints a warning read).
  /// Added in Phase 5 for the same adoption; provide one of [caption] or
  /// [footer], not both.
  final Widget? footer;

  /// An optional control on the kicker row: a period selector, a filter.
  final Widget? trailing;

  /// An optional legend row between chart and caption. Build it from
  /// [ChartFrame.legendDot] entries so every chart's legend reads the same.
  final Widget? legend;

  // NOT const. build() reads mutable Barako getters, and a const call site
  // would freeze the palette after a theme switch. Same rule as every shared
  // widget here.
  // ignore: prefer_const_constructors_in_immutables
  ChartFrame({
    super.key,
    required this.kicker,
    required this.chart,
    this.caption,
    this.contextLine,
    this.footer,
    this.trailing,
    this.legend,
  });

  /// One legend entry: a color dot beside its meaning. Shared so every
  /// chart's legend uses the same dot size and label style.
  static Widget legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: Gap.xs),
      Text(label, style: AppText.caption),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trailing == null)
              Kicker(kicker, inCard: true)
            else
              Row(
                children: [
                  Expanded(child: Kicker(kicker, inCard: true)),
                  const SizedBox(width: Gap.sm),
                  trailing!,
                ],
              ),
            if (contextLine != null) ...[
              const SizedBox(height: 4),
              Text(contextLine!, style: AppText.caption),
            ],
            const SizedBox(height: Gap.md),
            chart,
            if (legend != null) ...[const SizedBox(height: Gap.sm), legend!],
            if (caption != null) ...[
              const SizedBox(height: Gap.sm),
              Text(caption!, style: AppText.small.tint(Barako.muted)),
            ],
            if (footer != null) ...[
              const SizedBox(height: Gap.sm),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
