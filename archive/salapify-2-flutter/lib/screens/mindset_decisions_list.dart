// The full "View all" list of logged Money Mindset decisions, newest first,
// with a segmented filter (All / Bought / Avoided / Waiting). Reached from the
// Mindset Today dashboard. Read-only: it only reads the decision history,
// records nothing, and moves no balance.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/mindset_decisions.dart'
    show MindsetOutcome, filterMindsetByOutcome, recentMindsetDecisions;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_decision_detail.dart';
import '../widgets/mindset_decision_tile.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';
import 'mindset_flow.dart';

class MindsetDecisionsListScreen extends StatefulWidget {
  final SalapifyStore store;
  const MindsetDecisionsListScreen({super.key, required this.store});

  @override
  State<MindsetDecisionsListScreen> createState() =>
      _MindsetDecisionsListScreenState();
}

class _MindsetDecisionsListScreenState
    extends State<MindsetDecisionsListScreen> {
  // 'all' is the sentinel for no filter; the others are stored outcome values.
  String _filter = 'all';

  static const _options = [
    SegmentOption(value: 'all', label: 'All'),
    SegmentOption(value: MindsetOutcome.purchased, label: 'Bought'),
    SegmentOption(value: MindsetOutcome.avoided, label: 'Avoided'),
    SegmentOption(value: MindsetOutcome.waiting, label: 'Waiting'),
  ];

  void _openFlow() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MindsetFlowScreen(store: widget.store)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final now = DateTime.now();
        final anyLogged = widget.store.mindsetDecisions.isNotEmpty;
        final outcome = _filter == 'all' ? null : _filter;
        // Filter first, then sort newest-first (limit -1 returns all).
        final shown = recentMindsetDecisions(
          filterMindsetByOutcome(widget.store.mindsetDecisions, outcome),
          limit: -1,
        );
        return Scaffold(
          backgroundColor: Barako.background,
          appBar: AppBar(title: const Text('Recent decisions')),
          body: !anyLogged
              ? _emptyAll()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.gutter,
                        Gap.sm,
                        Gap.gutter,
                        Gap.sm,
                      ),
                      child: Segmented<String>(
                        options: _options,
                        current: _filter,
                        onPick: (v) => setState(() => _filter = v),
                      ),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? _emptyFilter()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                Gap.gutter,
                                Gap.sm,
                                Gap.gutter,
                                Gap.xl,
                              ),
                              children: [
                                for (final d in shown)
                                  MindsetDecisionTile(
                                    decision: d,
                                    now: now,
                                    onTap: () =>
                                        showMindsetDecisionDetail(context, d),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Nothing logged at all: never a dead end, offer the way in.
  Widget _emptyAll() => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(salapifyIcon('sparkle'), color: Barako.muted, size: 26),
          const SizedBox(height: Gap.md),
          Text(
            'No decisions logged yet.',
            style: AppText.body.w6.tint(Barako.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            onPressed: _openFlow,
            icon: Icon(salapifyIcon('add'), size: 18),
            label: const Text('Log a Decision'),
            style: FilledButton.styleFrom(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.xl,
                vertical: Gap.md,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // Some decisions exist, but none in this segment.
  Widget _emptyFilter() {
    final word = switch (_filter) {
      MindsetOutcome.purchased => 'bought',
      MindsetOutcome.avoided => 'avoided',
      MindsetOutcome.waiting => 'waiting',
      _ => 'logged',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Text(
          'No $word purchases here yet.',
          style: AppText.small.tint(Barako.muted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
