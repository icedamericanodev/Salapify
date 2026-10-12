import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// The Reminders card on Home, ported from the block inside App.tsx's home
/// branch.
///
/// It used to carry a SIMULATOR tag and a Test Alerts button that opened a
/// "coming soon" message. The tag was load-bearing honesty while nothing
/// behind it worked, and it is gone now because something does: the card says
/// how many reminders are waiting and opens the tray that holds them.
///
/// A card that says a feature is fake is better than one that pretends. A card
/// that does the thing is better than both.
class RemindersBanner extends StatelessWidget {
  const RemindersBanner({super.key, required this.state, this.onOpen});

  final FinancialState state;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final int unread = state.unreadNotificationsCount;
    final int total = state.notifications.length;

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
                Text('Reminders', style: AppType.rowTitle(palette)),
                const SizedBox(height: 2),
                Text(
                  // A figure, not a lesson. What the rules ARE lives behind
                  // the dot on the sheet itself.
                  switch ((unread, total)) {
                    (0, 0) => 'Nothing due in the next few days',
                    (0, _) => '$total in the tray, all read',
                    _ => '$unread waiting for you',
                  },
                  maxLines: 2,
                  style: AppType.caption(palette),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          _OpenButton(palette: palette, onTap: onOpen, unread: unread),
        ],
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.palette, required this.unread, this.onTap});

  final Palette palette;
  final int unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool loud = unread > 0;
    return Semantics(
      button: true,
      child: Material(
        color: loud ? palette.accent : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            // A Row with mainAxisSize.min rather than an alignment: a
            // Container with an alignment and no width fills whatever the
            // Row hands it, which here is everything the Expanded left over.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Open',
                  style: AppType.button(
                    palette,
                    color: loud ? palette.onAccent : palette.textSecondary,
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
