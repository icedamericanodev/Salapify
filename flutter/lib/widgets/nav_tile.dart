// A destination as a row, and the band of rows they sit in.
//
// Menu's history, in three shapes: sixteen full-width blurbed rows (half the
// app below the fold), then a 2-up grid of boxed tiles (denser, but a wall
// of sixteen identical bordered boxes, the audit's "tile wall"), and now
// rows grouped into ONE card per band. Rows in a card, not a card per row:
// the same list physics Overview's MY MONEY card and Utang's people list
// use, so Menu reads as a few short lists instead of a wall of buttons.
//
// Blurbs stay out for plain destinations (a label like Accounts explains
// itself; where it does not, the fix is a better label). The optional
// [detail] line exists for rows that carry STATE (Appearance: "Barako,
// System") or a promise the label cannot make alone (Privacy receipt),
// because that second line is information, not decoration.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

class NavTile extends StatelessWidget {
  /// Semantic icon NAME, resolved through salapify_icon.dart, never a raw
  /// IconData. That is what keeps the "one file decides how our icons look"
  /// rule true, and what makes the content test able to catch a typo instead
  /// of letting it reach the silent fallback marker.
  final String icon;
  final String label;

  /// A second line only when it carries state or a needed promise.
  final String? detail;
  final VoidCallback onTap;

  // NOT const. build() reads Barako getters, and a const call site would let
  // Element.updateChild skip build(), freezing the row in the previous
  // palette after a theme switch. Same rule as SalapifyGlyph and EmptyState.
  // ignore: prefer_const_constructors_in_immutables
  NavTile({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // The Android tap floor. The padding alone leaves a one-line row a
        // few pixels short of it, and the a11y suite measures Menu.
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              // Unboxed: a column of discs reads as a column of buttons,
              // which is wrong when the ROW is already the button.
              SalapifyGlyph(icon, size: IconSizes.inline, boxed: false),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: AppText.body.w7),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(detail!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(salapifyIcon('forward'), size: 18, color: Barako.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// One band of Menu: its rows in ONE card, hairline dividers between them.
class NavBand extends StatelessWidget {
  final List<NavTile> tiles;

  // ignore: prefer_const_constructors_in_immutables
  NavBand({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      // Clipped so the first and last rows' ripples bend at the card's own
      // corner instead of squaring past it (P1-5's rule).
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) Divider(height: 1, color: Barako.border),
            t,
          ],
        ],
      ),
    );
  }
}
