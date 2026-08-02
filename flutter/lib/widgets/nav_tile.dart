// A destination as a tile, and the 2-up grid they sit in.
//
// Menu used to be sixteen full-width rows, each an icon, a title, a two-line
// blurb and a chevron. Rendered, it reached the eighth destination before
// running off the screen, so half the app was behind a scroll with no hint it
// was there. Two columns of tiles put most of it in view at once.
//
// The blurbs are gone, deliberately. Sixteen of them is a wall of text nobody
// reads, and labels like Accounts, Goals, Recurring and Reports explain
// themselves. Where a label does not, the fix is a better label rather than a
// sentence underneath it.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'pressable_scale.dart';
import 'salapify_icon.dart';

class NavTile extends StatelessWidget {
  /// Semantic icon NAME, resolved through salapify_icon.dart, never a raw
  /// IconData. That is what keeps the "one file decides how our icons look"
  /// rule true, and what makes the content test able to catch a typo instead
  /// of letting it reach the silent fallback marker.
  final String icon;
  final String label;
  final VoidCallback onTap;

  // NOT const. build() reads Barako getters, and a const call site would let
  // Element.updateChild skip build(), freezing the tile in the previous
  // palette after a theme switch. Same rule as SalapifyGlyph and EmptyState.
  // ignore: prefer_const_constructors_in_immutables
  NavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Gap.lg,
              horizontal: Gap.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Unboxed: a row of discs reads as a row of buttons, which is
                // right for a single icon in a card and wrong for a grid where
                // the CARD is already the button.
                SalapifyGlyph(icon, size: 24, boxed: false),
                const SizedBox(height: Gap.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.label.w7.copyWith(height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lay tiles out two to a row.
///
/// A Wrap over a GridView on purpose. GridView wants a fixed childAspectRatio,
/// which clips the label the moment someone turns the system font size up;
/// Wrap lets every tile take the height its text actually needs. The rows stay
/// even because each tile is given exactly half the width.
class NavTileGrid extends StatelessWidget {
  final List<NavTile> tiles;

  // ignore: prefer_const_constructors_in_immutables
  NavTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - Gap.md) / 2;
        return Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}
