// Avalanche vs Snowball, f4.64. A side-by-side of the two payoff orders so a
// person can see the trade before committing to one.
//
// The numbers are avalancheVsSnowball(...), which runs the golden-locked
// debtFreeProjection twice and subtracts. This widget renders them and does no
// money math. The one honest truth it is built around, proven in
// payoff_compare_golden_test.dart: at the minimums the two orders are IDENTICAL,
// because there is no budget above the minimums to allocate by priority. The
// difference appears only when you pay extra, so the card leads with an extra
// selector and says plainly when the two are the same.

import 'package:flutter/material.dart';

import '../money/ledger.dart' show amountOf;
import '../money/payoff_compare.dart';
import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

class PayoffCompareCard extends StatefulWidget {
  /// The debts list, passed straight to avalancheVsSnowball.
  final List<Map<String, dynamic>> debts;

  /// The screen's money formatter.
  final String Function(num) money;

  const PayoffCompareCard({
    super.key,
    required this.debts,
    required this.money,
  });

  @override
  State<PayoffCompareCard> createState() => _PayoffCompareCardState();
}

class _PayoffCompareCardState extends State<PayoffCompareCard> {
  // The extra-monthly amounts the comparison offers. Zero is first and is the
  // honest baseline: at the minimums the two orders match.
  static const List<int> _extras = [0, 1000, 2000, 5000];
  int _extra = 0;

  @override
  Widget build(BuildContext context) {
    final r = avalancheVsSnowball(widget.debts, extra: _extra.toDouble());
    final ava = r['avalanche'] as Map<String, dynamic>?;
    final snow = r['snowball'] as Map<String, dynamic>?;
    final sameInterest = r['sameInterest'] as bool;
    final interestSaved = r['interestSaved'] as double?;
    final monthsSaved = r['monthsSaved'] as int?;

    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVALANCHE VS SNOWBALL', style: Barako.kickerStyle),
          const SizedBox(height: Gap.sm),
          Text(
            'The two payoff orders only differ when you pay more than the '
            'minimums. Try an extra amount and see.',
            style: AppText.caption.tint(Barako.textSecondary).copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: Gap.md),
          // The extra-monthly selector.
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final e in _extras)
                ChoiceChip(
                  label: Text(e == 0 ? 'Minimums' : '+ ${widget.money(e)}'),
                  selected: _extra == e,
                  onSelected: (_) {
                    Haptics.select();
                    setState(() => _extra = e);
                  },
                  selectedColor: Barako.primary,
                  backgroundColor: Barako.background,
                  labelStyle: TextStyle(
                    color: _extra == e ? Barako.onPrimary : Barako.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          // The two columns.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _column(
                  'Avalanche',
                  'Highest rate first',
                  ava,
                  Barako.primary,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _column(
                  'Snowball',
                  'Smallest balance first',
                  snow,
                  Barako.celebrate,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Container(height: 1, color: Barako.border),
          const SizedBox(height: Gap.md),
          Text(
            _verdict(sameInterest, interestSaved, monthsSaved, ava, snow),
            style: AppText.small.tint(Barako.text).copyWith(height: 1.4),
          ),
          // A debt owed to a person can rightly outrank the interest math. Shown
          // only when there is more than one debt to reorder, so it never
          // appears where there is no choice to make.
          if (_activeCount() > 1) ...[
            const SizedBox(height: Gap.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  salapifyIcon('info'),
                  size: IconSizes.dense,
                  color: Barako.muted,
                ),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'If one of these is money you owe family or a friend, it is '
                    'fair to clear that first even when the interest math points '
                    'elsewhere.',
                    style: AppText.caption.tint(Barako.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _activeCount() =>
      widget.debts.where((d) => amountOf(d['remaining']) > 0).length;

  // One strategy column: name, its rule, the total interest (the figure that
  // actually differs), and the months to debt free beneath it.
  Widget _column(
    String name,
    String rule,
    Map<String, dynamic>? projection,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppText.smallStrong.tint(accent)),
          const SizedBox(height: 2),
          Text(rule, style: AppText.caption.tint(Barako.muted)),
          const SizedBox(height: Gap.md),
          if (projection == null) ...[
            Text(
              'Not payable at this amount',
              style: AppText.small.tint(Barako.warning).copyWith(height: 1.3),
            ),
          ] else ...[
            Text(
              'TOTAL INTEREST',
              style: AppText.micro.copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.money(projection['totalInterest'] as double),
                style: AppText.amount.w8.tint(accent),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _debtFreeLine(projection),
              style: AppText.caption.tint(Barako.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _debtFreeLine(Map<String, dynamic> p) {
    final months = p['months'] as int;
    if (months == 0) return 'Debt free now';
    return months == 1 ? 'Debt free in 1 month' : 'Debt free in $months months';
  }

  String _verdict(
    bool sameInterest,
    double? interestSaved,
    int? monthsSaved,
    Map<String, dynamic>? ava,
    Map<String, dynamic>? snow,
  ) {
    final active = _activeCount();
    // Nothing owed, or a single debt: order cannot matter.
    if (active == 0) {
      return 'You have no debt to pay off. Nothing to compare here.';
    }
    if (active == 1) {
      return 'You have one debt to focus on, so the payoff order does not change '
          'anything. Every peso above the minimum shortens it.';
    }
    // One order clears everything at this amount and the other never catches up.
    // This is the clearest argument for avalanche, so name it rather than hiding
    // it behind a generic "no payoff" line.
    if (ava != null && snow == null) {
      return 'Avalanche clears everything at this amount, but snowball never '
          'catches up because a high-rate debt keeps growing. This is the '
          'clearest case for paying the highest rate first.';
    }
    if (ava == null && snow != null) {
      return 'Snowball clears everything at this amount, but avalanche stalls on '
          'a large balance. Try a larger extra and avalanche usually wins on '
          'interest.';
    }
    if (ava == null || snow == null) {
      return 'At this amount the interest outruns the payments either way, so '
          'there is no clean payoff yet. Try a larger extra amount.';
    }
    // Both payable and effectively the same interest: never claim a saving.
    if (sameInterest || !(interestSaved != null && interestSaved > 0.005)) {
      return _extra == 0
          ? 'At the minimums, both orders cost the same. Add an extra amount '
                'above to see how they compare.'
          : 'At this amount, both orders cost about the same. Avalanche still '
                'never costs more.';
    }
    // Avalanche saves interest. Say by how much, add the time if it also differs,
    // and name snowball's honest upside so the choice stays the person's.
    final saved = widget.money(interestSaved);
    final timeClause = (monthsSaved != null && monthsSaved > 0)
        ? (monthsSaved == 1
              ? ' and is debt free a month sooner'
              : ' and is debt free $monthsSaved months sooner')
        : '';
    return 'Avalanche pays $saved less in interest$timeClause. Snowball clears '
        'your smallest debt first, which some people find easier to stick with. '
        'Either way, paying the extra is what moves the needle.';
  }
}
