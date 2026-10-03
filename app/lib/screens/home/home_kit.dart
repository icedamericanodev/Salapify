import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// InfoDot moved to features/info, next to the sheet it opens, once Reports
/// needed it too. Re-exported here so every Home card that already imports
/// this file keeps working and the move stays invisible to them.
export '../../features/info/info_dot.dart';

/// Small shared pieces every Home card uses, so radius, border and tap target
/// cannot drift between one card and the next.

/// The standard white (or Gabi surface) card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.palette,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.radius = Radii.card,
  });

  final Palette palette;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: palette.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A rounded tinted square holding a small leading icon.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.palette,
    required this.icon,
    this.size = 36,
    this.iconSize = 18,
    this.background,
    this.foreground,
  });

  final Palette palette;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? palette.iconTile,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Icon(icon, size: iconSize, color: foreground ?? palette.accent),
    );
  }
}

/// The accent "See all >" / "Manage >" link that sits at the end of a heading.
class SectionLink extends StatelessWidget {
  const SectionLink({
    super.key,
    required this.palette,
    required this.label,
    this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          // 44 logical pixels is the floor for anything tappable.
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
              Icon(Icons.chevron_right, size: 15, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A count or status badge that rides on the corner of a header button.
class CornerBadge extends StatelessWidget {
  const CornerBadge({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    required this.ringColor,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: ringColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
