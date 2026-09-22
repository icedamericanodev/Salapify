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
    show
        MindsetTodayStats,
        mindsetRangeStats,
        mindsetTodayStats,
        recentMindsetDecisions;
import '../money/mindset_waiting.dart' show isDue, revisitLabel, waitingItems;
import '../services/notifications.dart' show Reminders;
import '../theme.dart';
import '../typography.dart';
import '../widgets/count_up_text.dart';
import '../widgets/mindset_decision_detail.dart';
import '../widgets/mindset_decision_tile.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';
import 'mindset_decisions_list.dart';
import 'mindset_flow.dart';
import 'mindset_insights.dart';

class MindsetTodayScreen extends StatelessWidget {
  final SalapifyStore store;
  const MindsetTodayScreen({super.key, required this.store});

  void _openFlow(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MindsetFlowScreen(store: store)));

  void _openAll(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MindsetDecisionsListScreen(store: store)),
  );

  void _openInsights(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MindsetInsightsScreen(store: store)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final decisions = store.mindsetDecisions;
        final recent = recentMindsetDecisions(decisions, limit: 5);
        final waiting = waitingItems(store.mindsetWaiting);
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
                _MindsetSummary(decisions: decisions, now: now),
                const SizedBox(height: Gap.md),
                _insightsButton(context),
                if (waiting.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  Text('Waiting on', style: AppText.title.w7),
                  const SizedBox(height: Gap.sm),
                  for (final w in waiting) _waitingRow(context, w, now),
                ],
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
                            vertical: Gap.sm,
                          ),
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
                    MindsetDecisionTile(
                      decision: d,
                      now: now,
                      onTap: () => showMindsetDecisionDetail(context, d),
                    ),
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

  Widget _insightsButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => _openInsights(context),
      icon: Icon(salapifyIcon('chart'), size: 18, color: Barako.primary),
      label: Text(
        'See my 30 days',
        style: AppText.small.w7.tint(Barako.primary),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Barako.border),
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
      ),
    ),
  );

  // A parked "Remind me" purchase: its name, estimated amount, and when it is
  // ready to revisit. Tapping it opens the act-on-it sheet (skipped, bought, or
  // more time) so a decision can be resolved without waiting for the nudge.
  Widget _waitingRow(
    BuildContext context,
    Map<String, dynamic> item,
    DateTime now,
  ) {
    final name = (item['itemName'] is String)
        ? (item['itemName'] as String).trim()
        : '';
    final amt = item['amount'];
    final amount = amt is num
        ? amt.toDouble()
        : (amt is String ? double.tryParse(amt) : null);
    final due = isDue(item, now);
    final label = revisitLabel(item, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => _openWaitingActions(context, item),
          child: Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: Barako.card,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: Barako.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Barako.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(
                    salapifyIcon('paused'),
                    size: 20,
                    color: Barako.warning,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : "Something you're considering",
                        style: AppText.body.w6,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Gap.xxs),
                      Text(
                        label,
                        style: AppText.caption.w6.tint(
                          due ? Barako.income : Barako.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: Gap.sm),
                  Text(formatMoney(amount), style: AppText.small.w7.tabular),
                ],
                const SizedBox(width: Gap.sm),
                Icon(salapifyIcon('forward'), size: 16, color: Barako.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _waitingName(Map<String, dynamic> item) {
    final n = item['itemName'];
    return (n is String && n.trim().isNotEmpty)
        ? n.trim()
        : "Something you're considering";
  }

  // Act on a parked item, three deliberate outcomes, each a single store write:
  // "I skipped it" resolves it and logs the money kept as a win (the same thing
  // the flow's Skip does); "I bought it" just resolves it; "Keep waiting" pushes
  // the revisit out another 24 hours. Read-only money in the Salapify sense: a
  // win records what was NOT spent and never moves a balance.
  void _openWaitingActions(BuildContext context, Map<String, dynamic> item) {
    final id = item['id'];
    if (id is! String) return;
    final name = _waitingName(item);
    final amt = item['amount'];
    final amount = amt is num ? amt.toDouble() : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do you still want this?', style: AppText.title.w7),
                const SizedBox(height: 6),
                Text(name, style: AppText.bodyLg.w7),
                if (amount != null) ...[
                  const SizedBox(height: 2),
                  Text(formatMoney(amount), style: AppText.body),
                ],
                const SizedBox(height: Gap.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _resolveWaiting(
                        context,
                        id,
                        status: 'skipped',
                        winNote: 'Skipped $name',
                        winAmount: amount,
                        toast: 'Skipped. That is money kept.',
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('No, I skipped it'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _resolveWaiting(
                        context,
                        id,
                        status: 'reviewed',
                        toast: 'Logged. Off your waiting list.',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Barako.textSecondary,
                      side: BorderSide(color: Barako.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Yes, I bought it'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _extendWaiting(context, id);
                    },
                    child: Text(
                      'Not sure, keep waiting 24 hours',
                      style: AppText.small.w6.tint(Barako.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolveWaiting(
    BuildContext context,
    String id, {
    required String status,
    String? winNote,
    double? winAmount,
    required String toast,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.patchMindsetWaitingItem(id, {'status': status});
      if (winNote != null) {
        await store.addWin(winNote, amount: winAmount);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(store.data, DateTime.now());
    messenger.showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _extendWaiting(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = DateTime.now().add(const Duration(hours: 24));
    try {
      await store.patchMindsetWaitingItem(id, {
        'revisitAt': next.toIso8601String(),
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(store.data, DateTime.now());
    messenger.showSnackBar(
      const SnackBar(content: Text("We'll check back again in 24 hours.")),
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

/// The dashboard summary with a Today / 30 days toggle. Stateful only for the
/// selected window; every figure is still READ from the logged decisions, and
/// nothing here changes a balance.
class _MindsetSummary extends StatefulWidget {
  const _MindsetSummary({required this.decisions, required this.now});
  final Iterable? decisions;
  final DateTime now;

  @override
  State<_MindsetSummary> createState() => _MindsetSummaryState();
}

class _MindsetSummaryState extends State<_MindsetSummary> {
  // 1 = today only, 30 = the rolling last 30 days.
  int _days = 1;

  @override
  Widget build(BuildContext context) {
    final stats = _days == 1
        ? mindsetTodayStats(widget.decisions, widget.now)
        : mindsetRangeStats(widget.decisions, widget.now, days: 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _days == 1 ? "Today's summary" : 'Last 30 days',
          style: AppText.title.w7,
        ),
        const SizedBox(height: Gap.md),
        Segmented<int>(
          options: const [
            SegmentOption(value: 1, label: 'Today'),
            SegmentOption(value: 30, label: '30 days'),
          ],
          current: _days,
          onPick: (v) => setState(() => _days = v),
        ),
        const SizedBox(height: Gap.md),
        _grid(stats),
      ],
    );
  }

  Widget _grid(MindsetTodayStats s) {
    // Each figure counts up from zero on open. Money uses formatMoney so the
    // peso value rolls; the counts round to a whole number mid-roll.
    Widget cell(
      double value,
      String label, {
      bool money = false,
      Color? valueColor,
    }) => Expanded(
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
            CountUpText(
              value: value,
              format: (v) => money ? formatMoney(v) : v.round().toString(),
              style: AppText.titleLg.w8.tabular.copyWith(color: valueColor),
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
              cell(s.decisions.toDouble(), 'Decisions made'),
              const SizedBox(width: Gap.md),
              cell(s.purchased.toDouble(), 'Purchases made'),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell(s.avoided.toDouble(), 'Purchases avoided'),
              const SizedBox(width: Gap.md),
              cell(
                s.moneyAvoided,
                'Money avoided',
                money: true,
                valueColor: Barako.income,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
