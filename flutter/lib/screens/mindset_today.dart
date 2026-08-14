// Mindset Today: the landing screen for Money mindset. A calm header with a
// "Log a Decision" entry to the four-step flow, today's summary counts, and a
// Recent Decisions list with a "View all" to the full history.
//
// READ-ONLY money. Every figure here is READ from the logged decision history
// (settings.mindsetDecisions); the amounts are the person's own Step 1
// estimates shown back to them, never a transaction and never a balance change.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/format.dart' show formatMoney;
import '../money/pan_mood.dart' show PanMood;
import '../money/mindset_decisions.dart'
    show MindsetTodayStats, mindsetTodayStats, recentMindsetDecisions;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_decision_tile.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/salapify_icon.dart';
import 'mindset_decisions_list.dart';
import 'mindset_flow.dart';

class MindsetTodayScreen extends StatelessWidget {
  final SalapifyStore store;
  const MindsetTodayScreen({super.key, required this.store});

  void _openFlow(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MindsetFlowScreen(store: store)));

  void _openAll(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MindsetDecisionsListScreen(store: store)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final decisions = store.mindsetDecisions;
        final stats = mindsetTodayStats(decisions, now);
        final recent = recentMindsetDecisions(decisions, limit: 5);
        return Scaffold(
          backgroundColor: Barako.background,
          appBar: AppBar(title: const Text('Money mindset')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.xs,
              Gap.gutter,
              Gap.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: Gap.xl),
                Text("Today's summary", style: AppText.title.w7),
                const SizedBox(height: Gap.md),
                _summaryGrid(stats),
                const SizedBox(height: Gap.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Recent decisions',
                        style: AppText.title.w7,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recent.isNotEmpty)
                      TextButton(
                        onPressed: () => _openAll(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'View all',
                          style: AppText.small.w7.tint(Barako.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                if (recent.isEmpty)
                  _emptyRecent()
                else
                  for (final d in recent)
                    MindsetDecisionTile(decision: d, now: now),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      children: [
        PanMascot(mood: PanMood.calm, size: 92),
        const SizedBox(height: Gap.md),
        Text(
          'Think before you spend',
          style: AppText.title.w7,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.xxs),
        Text(
          'One mindful check at a time.',
          style: AppText.small.tint(Barako.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openFlow(context),
            icon: Icon(salapifyIcon('add'), size: 18),
            label: const Text('Log a Decision'),
            style: FilledButton.styleFrom(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summaryGrid(MindsetTodayStats s) {
    Widget cell(String value, String label, {Color? valueColor}) => Expanded(
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
              cell('${s.decisions}', 'Decisions made'),
              const SizedBox(width: Gap.md),
              cell('${s.purchased}', 'Purchases made'),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell('${s.avoided}', 'Purchases avoided'),
              const SizedBox(width: Gap.md),
              cell(
                formatMoney(s.moneyAvoided),
                'Money avoided',
                valueColor: Barako.income,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyRecent() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      children: [
        Icon(salapifyIcon('sparkle'), color: Barako.muted, size: 22),
        const SizedBox(height: Gap.sm),
        Text(
          'No decisions logged yet.',
          style: AppText.small.w6.tint(Barako.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.xxs),
        Text(
          'Tap Log a Decision to think a purchase through before you buy.',
          style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
