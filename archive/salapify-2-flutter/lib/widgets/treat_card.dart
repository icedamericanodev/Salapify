// The treat surfaced where the habit lives: Home. The full Treats screen
// existed but the daily loop (do the healthy thing, check in, earn the
// treat) was out of sight behind Menu, which is where habits go to die.
// Ported from the RN TreatCard: picks the first not-yet-earned treat (or
// the first earned one so the win still shows), progress dots, and the
// one-tap check-in writing through the same store method the Treats
// screen uses.
//
// The treat emoji is USER DATA (they picked it), so it renders as-is; the
// icon rule only governs Salapify-authored icons.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/schedule.dart' show daysUntilPayday;
import '../money/treats.dart' as treats;
import '../screens/treats.dart' show TreatsScreen;
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

class TreatCard extends StatelessWidget {
  final SalapifyStore store;

  /// Injectable clock, the usual seam.
  final DateTime Function() clock;

  // ignore: prefer_const_constructors_in_immutables
  TreatCard({super.key, required this.store, this.clock = DateTime.now});

  void _open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => TreatsScreen(store: store)));

  /// The quiet one-line form of this card: title, one sub line, a chevron,
  /// the same tap through to Treats. Used when there is nothing yet and when
  /// the pick is not close enough to earn front-page excitement.
  Widget _slimRow(
    BuildContext context, {
    required String title,
    required String sub,
  }) {
    return Card(
      child: Semantics(
        button: true,
        label: title,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong),
                      const SizedBox(height: 2),
                      Text(sub, style: AppText.caption.copyWith(height: 1.35)),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    salapifyIcon('forward'),
                    size: 18,
                    color: Barako.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = clock();
    final statuses = [
      for (final t in store.treatRules) treats.treatStatus(t, ref),
    ];
    Map<String, dynamic>? pick;
    for (final s in statuses) {
      if (s['earned'] != true) {
        pick = s;
        break;
      }
    }
    pick ??= statuses.isNotEmpty ? statuses.first : null;

    if (pick == null) {
      // No treats yet: a slim invite, not a wall.
      return _slimRow(
        context,
        title: 'Earn your treats',
        sub: 'Pair a small reward with a healthy habit. Guilt free.',
      );
    }

    final earned = pick['earned'] == true;
    final doneToday = pick['doneToday'] == true;
    final target = pick['target'] as int;
    final recent = pick['recent'] as int;
    final remaining = pick['remaining'] as int;
    final action = (pick['action'] ?? 'habit').toString().toLowerCase();
    final treatName = (pick['treat'] ?? 'treat').toString();

    // The full card with its dots earns front-page space only when something
    // is HAPPENING: the treat is earned (the win must show) or one check-in
    // away (the nudge can close it today). Mid-journey, one quiet line keeps
    // the habit visible without spending ~140dp of Home on it every day.
    if (!earned && remaining > 1) {
      return _slimRow(
        context,
        title: 'Earn your treats',
        sub:
            '$recent of $target toward ${treatName.toLowerCase()}. '
            '${remaining == target ? 'Start today.' : 'Keep going.'}',
      );
    }

    // Payday nudge only when the user explicitly set a schedule; without one
    // the line would fire on guesses and read as noise, the RN rule.
    final schedule = (store.data['settings'] is Map)
        ? (store.data['settings'] as Map)['paydaySchedule']
        : null;
    final paydaySoon = schedule != null && daysUntilPayday(ref, schedule) <= 1;

    final String sub;
    if (earned) {
      sub =
          'Earned. Enjoy your ${treatName.toLowerCase()}, you paid for it '
          'in $action.';
    } else if (paydaySoon) {
      sub =
          'Payday is close. Lock in your $action habit first, $remaining '
          'to go.';
    } else if (recent == 0) {
      sub = 'Do your $action, then check in. $target earns it.';
    } else {
      sub = '$recent of $target check ins. $remaining more and it is yours.';
    }

    return Card(
      shape: earned
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
              side: BorderSide(color: Barako.celebrate),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Earn your treat, open Treats',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _open(context),
                child: Row(
                  children: [
                    Text('EARN YOUR TREAT', style: Barako.cardKickerStyle),
                    const Spacer(),
                    if (earned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Barako.celebrate),
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                        child: Text(
                          'EARNED',
                          style: TextStyle(
                            color: Barako.celebrate,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    else
                      ExcludeSemantics(
                        child: Icon(
                          salapifyIcon('forward'),
                          size: 18,
                          color: Barako.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                if ((pick['emoji'] ?? '').toString().isEmpty)
                  SalapifyGlyph('treat', size: 22, boxed: false)
                else
                  Text(
                    (pick['emoji'] ?? '').toString(),
                    style: const TextStyle(fontSize: 24),
                  ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(treatName, style: AppText.bodyStrong)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < target; i++)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < recent
                          ? (earned ? Barako.celebrate : Barako.primary)
                          : null,
                      border: Border.all(
                        color: i < recent
                            ? (earned ? Barako.celebrate : Barako.primary)
                            : Barako.border,
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              sub,
              style: AppText.small.copyWith(
                color: earned ? Barako.celebrate : Barako.textSecondary,
                height: 1.4,
                fontWeight: earned ? TypeWeight.medium : TypeWeight.regular,
              ),
            ),
            // The check-in button: for an unearned treat, or to undo today's
            // check-in on an earned one. Never without a writable store.
            if (store.canWrite && (!earned || doneToday)) ...[
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: doneToday
                    ? FilledButton.icon(
                        onPressed: () => store.toggleTreatCheckIn(
                          (pick!['id'] ?? '').toString(),
                        ),
                        icon: Icon(salapifyIcon('selected'), size: 18),
                        label: const Text('Done for today, tap to undo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                          minimumSize: const Size(0, 48),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => store.toggleTreatCheckIn(
                          (pick!['id'] ?? '').toString(),
                        ),
                        icon: Icon(salapifyIcon('unselected'), size: 18),
                        label: const Text('I did it today'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Barako.primaryText,
                          side: BorderSide(color: Barako.primary),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
