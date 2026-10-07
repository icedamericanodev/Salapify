// A read-only detail sheet for one logged decision, opened by tapping its row.
// Shows the full story the flat list cannot: the item, the estimated amount,
// the outcome, the note the person wrote, the private verdict, and the full
// date and time. Presentation only, it reads already-stored fields and changes
// nothing.

import 'package:flutter/material.dart';

import '../money/format.dart' show formatMoney;
import '../money/mindset_decisions.dart'
    show MindsetOutcome, mindsetOutcomeLabel;
import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

(String, Color) _look(String? outcome) => switch (outcome) {
  MindsetOutcome.purchased => ('cart', Barako.primary),
  MindsetOutcome.avoided => ('done', Barako.income),
  MindsetOutcome.waiting => ('paused', Barako.warning),
  _ => ('sparkle', Barako.muted),
};

// The private three-question verdict, in the same words the flow's band label
// uses, so a person sees the same phrase they saw when they decided.
String _verdictLabel(String? verdict) => switch (verdict) {
  'fitsPlan' => 'Fits comfortably',
  'pause24h' => 'Worth a pause',
  'notInPlan' => 'Big impact',
  _ => '',
};

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fullWhen(dynamic createdAt) {
  final d = createdAt is String ? DateTime.tryParse(createdAt) : null;
  if (d == null) return '';
  final h24 = d.hour;
  final period = h24 < 12 ? 'AM' : 'PM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_months[d.month - 1]} ${d.day}, ${d.year} at $h:$m $period';
}

double? _amount(Map<String, dynamic> d) {
  final v = d['amount'];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

Future<void> showMindsetDecisionDetail(
  BuildContext context,
  Map<String, dynamic> decision,
) {
  // Read strings defensively: a malformed backup can carry a non-string where
  // a string belongs, and an `as String?` cast would crash the sheet on tap.
  String? str(dynamic v) => v is String ? v : null;
  final outcome = str(decision['outcome']);
  final (icon, color) = _look(outcome);
  final name = str(decision['itemName'])?.trim();
  final note = str(decision['note'])?.trim();
  final amount = _amount(decision);
  final verdict = _verdictLabel(str(decision['verdict']));
  final when = _fullWhen(decision['createdAt']);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Barako.background,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(salapifyIcon(icon), color: color, size: 22),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name != null && name.isNotEmpty ? name : 'A purchase',
                        style: AppText.title.w7,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mindsetOutcomeLabel(outcome),
                        style: AppText.small.w7.tint(color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            if (amount != null) _row('Estimated amount', formatMoney(amount)),
            if (verdict.isNotEmpty) _row('Your read', verdict),
            if (when.isNotEmpty) _row('Logged', when),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Text('Your note', style: Barako.cardKickerStyle),
              const SizedBox(height: Gap.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.field),
                  border: Border.all(color: Barako.border),
                ),
                child: Text(note, style: AppText.small.copyWith(height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.small.tint(Barako.muted)),
      const SizedBox(width: Gap.md),
      Flexible(
        child: Text(value, style: AppText.small.w6, textAlign: TextAlign.right),
      ),
    ],
  ),
);
