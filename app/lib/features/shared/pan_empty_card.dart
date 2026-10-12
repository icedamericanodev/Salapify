import 'package:flutter/material.dart';

import '../../design/pan_art.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'sheet_scaffold.dart';

/// An empty state with Pan in it, for the screens that had NO empty state of
/// their own before D30: Home on a first run, Plan's budgets and goals,
/// Accounts and Reports.
///
/// One widget so the five look like one family: the same card, the same
/// type, the same motion (PanEmptyContent does that part). Activity and Debt
/// keep their own cards, which already existed, and only swap the icon.
///
/// The button is optional ON PURPOSE. A card that offers "Set your budget"
/// when the app has no way to set one is worse than a card with no button,
/// so a screen passes [actionLabel] only when [onAction] really goes
/// somewhere.
class PanEmptyCard extends StatelessWidget {
  const PanEmptyCard({
    super.key,
    required this.palette,
    required this.mood,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.ring = false,
  });

  final Palette palette;
  final PanMood mood;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Home's first run only: the button sends out two soft rings once Pan has
  /// landed, pointing at the one thing to do next.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final bool hasAction = actionLabel != null && onAction != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.xl,
        Spacing.xl,
        Spacing.xl,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: PanEmptyContent(
        mood: mood,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: AppType.section(palette).copyWith(fontSize: 16),
        ),
        body: Text(
          body,
          textAlign: TextAlign.center,
          style: AppType.body(
            palette,
          ).copyWith(color: palette.textSecondary, height: 1.45),
        ),
        gap: Spacing.sm,
        actionGap: Spacing.lg,
        ring: ring,
        ringColor: palette.accent,
        ringRadius: Radii.control,
        action: hasAction
            ? PrimaryButton(
                palette: palette,
                label: actionLabel!,
                icon: Icons.add,
                onTap: onAction,
              )
            : null,
      ),
    );
  }
}
