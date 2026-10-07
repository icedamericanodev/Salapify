// One row in the Mindset Today "Recent Decisions" list and the full "View all"
// list. Shows the item, an optional note, the estimated amount, an outcome
// badge, and when it was logged. Read-only: the amount is the person's Step 1
// estimate, never a transaction.

import 'package:flutter/material.dart';

import '../money/format.dart' show formatMoney;
import '../money/mindset_decisions.dart'
    show MindsetOutcome, mindsetDecisionWhen, mindsetOutcomeLabel;
import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

class MindsetDecisionTile extends StatelessWidget {
  final Map<String, dynamic> decision;
  final DateTime now;

  /// When set, the whole row is tappable and opens the decision detail. Null
  /// leaves it a plain, non-interactive row.
  final VoidCallback? onTap;

  const MindsetDecisionTile({
    super.key,
    required this.decision,
    required this.now,
    this.onTap,
  });

  static (String, Color) _look(String? outcome) => switch (outcome) {
    MindsetOutcome.purchased => ('cart', Barako.primary),
    MindsetOutcome.avoided => ('done', Barako.income),
    MindsetOutcome.waiting => ('paused', Barako.warning),
    _ => ('sparkle', Barako.muted),
  };

  double? _amount() {
    final v = decision['amount'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // Read a field as a string only when it actually is one. A malformed or
  // hand-edited backup can carry a number where a string belongs, and an
  // `as String?` cast would throw and take the whole screen down; the pure
  // helpers already read defensively, and these widgets must match them.
  static String? _str(dynamic v) => v is String ? v : null;

  @override
  Widget build(BuildContext context) {
    final outcome = _str(decision['outcome']);
    final (icon, color) = _look(outcome);
    final name = _str(decision['itemName'])?.trim();
    final note = _str(decision['note'])?.trim();
    final amount = _amount();
    final when = mindsetDecisionWhen(decision['createdAt'], now);

    final card = Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Icon(salapifyIcon(icon), size: 20, color: color),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name != null && name.isNotEmpty ? name : 'A purchase',
                  style: AppText.body.w6,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: Gap.xxs),
                  Text(
                    note,
                    style: AppText.small.tint(Barako.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amount != null)
                Text(formatMoney(amount), style: AppText.small.w7.tabular),
              const SizedBox(height: Gap.xxs),
              _badge(mindsetOutcomeLabel(outcome), color),
              if (when.isNotEmpty) ...[
                const SizedBox(height: Gap.xxs),
                Text(when, style: AppText.caption.tint(Barako.muted)),
              ],
            ],
          ),
        ],
      ),
    );

    final row = onTap == null
        ? card
        : Semantics(
            button: true,
            label: [
              name != null && name.isNotEmpty ? name : 'A purchase',
              mindsetOutcomeLabel(outcome),
              if (amount != null) formatMoney(amount),
            ].where((s) => s.isNotEmpty).join(', '),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.card),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: card),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: row,
    );
  }

  Widget _badge(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label, style: AppText.caption.w7.tint(color)),
    );
  }
}
