import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/reports.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// One category in a breakdown: the name, the amount, a proportion bar, and
/// the sub-categories underneath it.
///
/// The bar is a bar and not a pie on purpose. A pie chart makes two similar
/// slices indistinguishable and cannot be read at all by somebody with a
/// colour vision deficiency; a row of bars sorted biggest first answers "what
/// is eating my money" at a glance, and the figure is written next to it so
/// the bar never has to be measured by eye.
class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.palette,
    required this.row,
    required this.barColor,
  });

  final Palette palette;
  final CategoryBreakdown row;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    // Only worth listing sub-categories when they say something the category
    // line does not. One sub-category is always 100% of its parent.
    final bool showSubs = row.subcategories.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowTitle(palette),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(formatPeso(row.total), style: AppType.amountSmall(palette)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: LinearProgressIndicator(
                    // The share is 0 to 100, the widget wants 0 to 1. Clamped
                    // because a rounding error above 1.0 makes the widget
                    // throw, and a report is not worth a crash.
                    value: (row.percentage / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: palette.trackSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // The percentage is written out as well as drawn. A bar alone
              // cannot be read precisely, and this is a financial report.
              SizedBox(
                width: 44,
                child: Text(
                  '${row.percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: AppType.caption(palette),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            row.count == 1 ? '1 entry' : '${row.count} entries',
            style: AppType.caption(palette),
          ),
          if (showSubs) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            for (final SubcategoryBreakdown s in row.subcategories)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.md, top: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        s.name,
                        // Two lines, because the real names are long:
                        // "Gadget Loan (Home Credit/SpayLater/LazPay)" was
                        // cut to "...LazPa" on a phone, which hides exactly
                        // the part that says which loan.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption(palette),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(formatPeso(s.total), style: AppType.caption(palette)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
