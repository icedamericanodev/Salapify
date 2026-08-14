// The full "View all" list of logged Money Mindset decisions, newest first.
// Reached from the Mindset Today dashboard. Read-only: it only reads the
// decision history, records nothing, and moves no balance.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/mindset_decisions.dart' show recentMindsetDecisions;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_decision_tile.dart';
import '../widgets/salapify_icon.dart';

class MindsetDecisionsListScreen extends StatelessWidget {
  final SalapifyStore store;
  const MindsetDecisionsListScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        // limit -1 returns all of them, newest first.
        final all = recentMindsetDecisions(store.mindsetDecisions, limit: -1);
        return Scaffold(
          backgroundColor: Barako.background,
          appBar: AppBar(title: const Text('Recent decisions')),
          body: all.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.gutter,
                    Gap.md,
                    Gap.gutter,
                    Gap.xl,
                  ),
                  children: [
                    for (final d in all)
                      MindsetDecisionTile(decision: d, now: now),
                  ],
                ),
        );
      },
    );
  }

  Widget _empty() => Center(
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
        ],
      ),
    ),
  );
}
