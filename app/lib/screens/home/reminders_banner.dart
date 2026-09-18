import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'home_kit.dart';

/// The Reminders and Alerts banner, ported from the block inside App.tsx's
/// home branch.
///
/// The SIMULATOR tag is load-bearing honesty: nothing here schedules a real
/// notification yet, and a reminders card that quietly did nothing would be
/// worse than one that says what it is.
class RemindersBanner extends StatelessWidget {
  const RemindersBanner({super.key, required this.palette, this.onTest});

  final Palette palette;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      palette: palette,
      padding: const EdgeInsets.all(Spacing.md),
      radius: Radii.control,
      child: Row(
        children: <Widget>[
          IconTile(palette: palette, icon: Icons.notifications_none),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // A Wrap, not a Row. In a Row the SIMULATOR tag holds fixed
                // width and the TITLE is what gives way, so the card read
                // "Reminders & ..." on a 390dp phone. Wrapping drops the tag
                // to its own line instead, which costs a few pixels of height
                // and never truncates the name of the thing.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Spacing.sm,
                  runSpacing: 2,
                  children: <Widget>[
                    Text(
                      'Reminders & Alerts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.warningSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SIMULATOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          // textPrimary reads correctly on warningSoft in both
                          // themes: near-black on amber, near-white on the
                          // dark brown. No theme test needed.
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Daily log, payment due, bill & subscription reminders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _TestButton(palette: palette, onTap: onTest),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.palette, this.onTap});

  final Palette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: palette.accent,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.auto_awesome, size: 13, color: palette.onAccent),
                const SizedBox(width: 4),
                Text(
                  'Test Alerts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
