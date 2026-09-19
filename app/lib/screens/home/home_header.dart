import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/tokens.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// The Home header, ported from src/components/Header.tsx.
///
/// Left: the wordmark, the Offline Only badge and today's date. Right: five
/// round buttons. The badge is not decoration, it is the product's core claim,
/// so it sits beside the name rather than in Settings.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.state,
    this.onOpenToolkit,
    this.onOpenCollaboration,
    this.onOpenReminders,
    this.onOpenSettings,
  });

  final FinancialState state;
  final VoidCallback? onOpenToolkit;
  final VoidCallback? onOpenCollaboration;
  final VoidCallback? onOpenReminders;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final bool isNight = state.theme == ThemeMode2.gabi;
    final int unread = state.unreadNotificationsCount;

    // Five 44dp buttons need 236dp of the row on their own. On a 320dp phone
    // that leaves the wordmark about 50dp, which overflowed rather than
    // shrank. Below 360dp the buttons take their own line instead.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 360;
        final Widget identity = _identity(palette);
        final Widget actions = _actions(palette, isNight, unread);

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              identity,
              const SizedBox(height: Spacing.sm),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: identity),
            const SizedBox(width: Spacing.sm),
            actions,
          ],
        );
      },
    );
  }

  Widget _identity(Palette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _LogoMark(),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Salapify',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: palette.accent,
                  ),
                ),
              ],
            ),
            _OfflineBadge(palette: palette),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          // "Friday, Sep 18", the prototype's en-PH long weekday format.
          DateFormat('EEEE, MMM d').format(state.now),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _actions(Palette palette, bool isNight, int unread) {
    // Only when saving is genuinely OFF. A recovery sets loadProblem too,
    // and everything is fine after one, so marking it would put a red badge
    // on the header for an event the app handled correctly.
    final bool needsAttention = state.saveProblem != null || !state.isSaving;
    return Wrap(
      spacing: Spacing.xs,
      children: <Widget>[
        _HeaderButton(
          palette: palette,
          icon: Icons.auto_awesome_outlined,
          tooltip: 'Philippine Financial Toolkit',
          foreground: palette.accent,
          onTap: onOpenToolkit,
        ),
        _HeaderButton(
          palette: palette,
          icon: Icons.people_outline,
          tooltip: 'Shared finances and collaboration',
          onTap: onOpenCollaboration,
          badge: state.memberCount > 1
              ? CornerBadge(
                  text: '${state.memberCount}',
                  background: palette.positive,
                  foreground: palette.background,
                  ringColor: palette.background,
                )
              : null,
        ),
        _HeaderButton(
          palette: palette,
          icon: Icons.notifications_none,
          tooltip: 'Reminders and alerts',
          foreground: unread > 0 ? palette.accent : null,
          onTap: onOpenReminders,
          badge: unread > 0
              ? CornerBadge(
                  // The prototype caps the count at "9+" so the pill
                  // cannot grow wide enough to shove the row around.
                  text: unread > 9 ? '9+' : '$unread',
                  background: palette.accent,
                  foreground: palette.onAccent,
                  ringColor: palette.background,
                )
              : null,
        ),
        _HeaderButton(
          palette: palette,
          icon: isNight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: isNight
              ? 'Switch to Hapon, the light theme'
              : 'Switch to Gabi, the dark theme',
          foreground: palette.accent,
          onTap: state.toggleTheme,
        ),
        _HeaderButton(
          palette: palette,
          icon: Icons.settings_outlined,
          tooltip: needsAttention
              ? 'Settings, and something needs your attention'
              : 'Settings and backup',
          foreground: needsAttention ? palette.negative : null,
          onTap: onOpenSettings,
          // A DOT, not a banner. The two banners that used to sit above this
          // header were removed on founder direction, 2026-09-19, because they
          // were in front of every screen and were distracting. This is what
          // is left of them: a mark on the gear when Settings has something
          // worth opening, and nothing at all when it does not.
          //
          // It carries no number, deliberately. A count would invite the same
          // "what is this" glance the banners did. It is on when saving has
          // failed, which is the one state where silence costs somebody
          // everything they typed.
          badge: needsAttention
              ? CornerBadge(
                  text: '!',
                  background: palette.negative,
                  foreground: palette.background,
                  ringColor: palette.background,
                )
              : null,
        ),
      ],
    );
  }
}

/// The app mark, the founder's own artwork recoloured to the Salapify palette.
///
/// This was a drawn "S" monogram while no logo existed, on the grounds that a
/// placeholder bitmap would be a worse lie than an obvious stand-in. The real
/// mark exists now, so the stand-in is gone.
///
/// 28 rather than 26: the ribbon strokes are fine and the peso sits inside
/// them, and two extra pixels is the difference between reading as the logo
/// and reading as a smudge.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // Matches the squircle baked into the artwork, so the corners do not
      // get clipped twice into a harder shape than the icon has.
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/brand/salapify_logo.png',
        width: 28,
        height: 28,
        // The mark carries its own plate, so it must not be tinted by the
        // theme. It is the one thing on this screen that stays put.
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_user_outlined, size: 12, color: palette.accent),
          const SizedBox(width: 4),
          Text(
            'Offline Only',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badge,
    this.foreground,
  });

  final Palette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget? badge;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Material(
                color: palette.surface,
                shape: CircleBorder(side: BorderSide(color: palette.border)),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      icon,
                      size: 18,
                      color: foreground ?? palette.textSecondary,
                    ),
                  ),
                ),
              ),
              if (badge != null) Positioned(top: 0, right: 0, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}
