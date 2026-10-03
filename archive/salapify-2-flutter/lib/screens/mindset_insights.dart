// "My 30 days": the reflection that used to be reachable only by walking the
// four-step flow to its end. It now stands on its own, one tap from the Mindset
// Today dashboard, so a person can see how they are doing without pretending to
// log a purchase.
//
// READ-ONLY money. Every figure is READ from the existing, golden-locked
// mindsetSnapshot (the same source the flow's step 4 uses): the 30-day counts,
// the spending avoided, and the mindful streak. No new money math, no new sum;
// this screen only presents what mindset_wins.dart already computes, so the two
// surfaces can never disagree about a peso.

import 'package:flutter/material.dart';

import '../content/lesson_model.dart' show lessonFromMap;
import '../content/lessons.dart' show lessonOfTheDay;
import '../data/store.dart';
import '../money/format.dart' show formatMoney;
import '../money/ledger.dart' show amountOf;
import '../money/mindset_decisions.dart' show mindsetWeekDots;
import '../money/mindset_wins.dart' show MindsetSnapshot, mindsetSnapshot;
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

class MindsetInsightsScreen extends StatelessWidget {
  final SalapifyStore store;
  const MindsetInsightsScreen({super.key, required this.store});

  static const List<String> _months = [
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

  String _fmtDate(dynamic iso) {
    final d = iso is String ? DateTime.tryParse(iso) : null;
    if (d == null) return '';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<Map<String, dynamic>> _wins() => [
    for (final w in (store.data['wins'] as List? ?? const []))
      if (w is Map<String, dynamic>) w,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final snap = mindsetSnapshot(
          wins: store.data['wins'],
          mindsetChecks: store.mindsetChecks,
          mindsetWaiting: store.mindsetWaiting,
          now: now,
        );
        final wins = _wins().reversed.take(6).toList();
        final lesson = lessonFromMap(lessonOfTheDay(now));
        return Scaffold(
          backgroundColor: Barako.background,
          appBar: AppBar(title: const Text('My 30 days')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.sm,
              Gap.gutter,
              Gap.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _snapshotGrid(snap),
                const SizedBox(height: Gap.lg),
                _streakCard(now),
                const SizedBox(height: Gap.lg),
                _lessonCard(lesson.title, lesson.summary),
                const SizedBox(height: Gap.lg),
                _winsCard(wins),
                const SizedBox(height: Gap.md),
                Text(
                  "This doesn't add to your balance. It reflects what you chose "
                  'not to spend.',
                  style: AppText.caption
                      .tint(Barako.muted)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _snapshotGrid(MindsetSnapshot snap) {
    Widget tile(String label, String value, {Color? valueColor}) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Barako.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Barako.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppText.titleLg.w8.tabular.copyWith(color: valueColor),
              maxLines: 1,
            ),
            const SizedBox(height: Gap.xxs),
            Text(
              label,
              style: AppText.small.tint(Barako.textSecondary),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Decision checks', '${snap.decisionChecksCompleted}'),
              const SizedBox(width: Gap.md),
              tile('Purchases paused', '${snap.purchasesPaused}'),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Purchases skipped', '${snap.purchasesSkipped}'),
              const SizedBox(width: Gap.md),
              tile(
                'Spending avoided',
                formatMoney(snap.confirmedSpendingAvoided),
                valueColor: Barako.income,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _streakCard(DateTime now) {
    final dots = mindsetWeekDots(store.mindsetChecks, _wins(), now);
    final active = dots.where((d) => d).length;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MINDFUL STREAK', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.xs),
          Text(
            active >= 1
                ? '$active of the last 4 weeks, you checked before buying.'
                : 'Check before a buy to start your streak.',
            style: AppText.body.w6.copyWith(height: 1.3),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              for (var i = 0; i < dots.length; i++) ...[
                _weekDot(dots[i], i + 1),
                if (i < dots.length - 1) const SizedBox(width: Gap.md),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekDot(bool active, int week) => Expanded(
    child: Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Barako.primary : Colors.transparent,
            border: Border.all(
              color: active ? Barako.primary : Barako.border,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text('W$week', style: AppText.caption.tint(Barako.muted)),
      ],
    ),
  );

  Widget _lessonCard(String title, String summary) => Container(
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(salapifyIcon('learning'), size: 16, color: Barako.primary),
            const SizedBox(width: Gap.xs),
            Text("TODAY'S LESSON", style: Barako.cardKickerStyle),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(title, style: AppText.body.w7.copyWith(height: 1.3)),
        const SizedBox(height: Gap.xs),
        Text(
          summary,
          style: AppText.small.tint(Barako.textSecondary).copyWith(height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _winsCard(List<Map<String, dynamic>> wins) => Container(
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMALL WINS', style: Barako.cardKickerStyle),
        const SizedBox(height: Gap.sm),
        if (wins.isEmpty)
          Text(
            'Each purchase you skip can be a small win. They show up here.',
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          )
        else
          for (var i = 0; i < wins.length; i++) ...[
            if (i > 0) Divider(height: Gap.lg, color: Barako.border),
            _winRow(wins[i]),
          ],
      ],
    ),
  );

  Widget _winRow(Map<String, dynamic> w) {
    final note = (w['note'] ?? w['itemName'] ?? 'Skipped a buy').toString();
    final amount = amountOf(w['amount']);
    final date = _fmtDate(w['date']);
    return Row(
      children: [
        Icon(salapifyIcon('done'), size: 18, color: Barako.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note,
                style: AppText.small.w6,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (date.isNotEmpty)
                Text(date, style: AppText.caption.tint(Barako.muted)),
            ],
          ),
        ),
        if (amount > 0) ...[
          const SizedBox(width: Gap.sm),
          Text(
            formatMoney(amount),
            style: AppText.small.w7.tint(Barako.primary),
          ),
        ],
      ],
    );
  }
}
