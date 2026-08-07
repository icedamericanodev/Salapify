// The small uppercase label above a section or a card's content.
//
// This exists because the kicker had drifted into FIVE private copies, and
// they had stopped agreeing. The typography refresh moved the kicker to
// 12/w600/1.2 in theme.dart with a written reason (the old 0.18em tracking
// shouts), and debts.dart followed, but menu, overview, insights and
// privacy_receipt each kept their own hand-rolled 11/w700/2. So the same label
// rendered two different ways depending on which screen you were looking at,
// and nothing failed, because a private copy of a style is invisible to every
// test and to every reader who is not diffing two files side by side.
//
// One widget, reading the theme, is what stops that happening a second time.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// The section label, inside a card or outside one.
///
/// The inside/outside rule, written down at last (an earlier version of this
/// comment claimed cardKickerStyle was "used by nothing in the app", which
/// was stale the day the audit counted twenty-plus screens using it): a
/// kicker OUTSIDE a card orients the reader down the page and stays muted; a
/// kicker INSIDE a card belongs to its card and warms to caramel. Pass
/// [inCard] accordingly. One widget owning both halves is what stops the 26
/// hand-rolled letterspacing forks the audit found from growing back.
class Kicker extends StatelessWidget {
  final String text;

  /// True for a label inside a card or sheet surface: caramel, the accent
  /// that makes a card's own headings feel owned rather than utilitarian.
  /// False (the default) for the muted page-level label between cards.
  final bool inCard;

  // NOT const. Barako.kickerStyle is a getter over the ACTIVE palette, read
  // during build. Dart canonicalizes const instances, so a const call site
  // would let Element.updateChild skip build() and freeze this label in the
  // previous theme's colour after a switch. Removing const from the
  // constructor is what makes that impossible at every call site rather than
  // something each caller has to remember.
  // ignore: prefer_const_constructors_in_immutables
  Kicker(this.text, {super.key, this.inCard = false});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: inCard ? Barako.cardKickerStyle : Barako.kickerStyle);
}

/// A section label with an optional total on the right.
///
/// The shape a grouped list wants: `SHORT TERM            ₱4,000`. Naming the
/// group and subtotalling it in one line beats a header followed by a total
/// the reader has to add up themselves.
///
/// [trailing] is optional because most sections have nothing to total, and a
/// header that reserves space for a number it never shows just looks broken.
class SectionHeader extends StatelessWidget {
  final String text;
  final String? trailing;

  /// Tint for the trailing figure. Defaults to the accent; pass
  /// `Barako.warning` for money owed, matching how amounts are coloured
  /// elsewhere.
  final Color? trailingColor;

  // ignore: prefer_const_constructors_in_immutables
  SectionHeader(this.text, {super.key, this.trailing, this.trailingColor});

  @override
  Widget build(BuildContext context) {
    if (trailing == null) return Kicker(text);
    return Row(
      children: [
        // Expanded, not Flexible: Flexible sizes to the label, which would
        // leave the total sitting right beside it instead of at the right
        // edge. Expanded also absorbs the growth when the system font scale is
        // large, which is the pair most likely to overflow a Row.
        Expanded(child: Kicker(text)),
        const SizedBox(width: Gap.sm),
        Text(
          trailing!,
          style: AppText.amountRow.w8.tint(trailingColor ?? Barako.primary),
        ),
      ],
    );
  }
}

/// The two halves of a headline figure, side by side under it.
///
/// Net worth is one number made of two, and so is a month: the useful question
/// is never just "how much" but "made of what". Home used to answer that in a
/// single muted caption, `Assets ₱88,560  ·  Owed ₱46,000`, at 13pt in the
/// quietest colour on the card. Both halves were there and neither was
/// readable, because a middle dot is not a column and grey is not a label.
///
/// Two labelled columns give each side a name and let the amounts be coloured
/// against each other, so the shape of the number is legible at a glance
/// rather than after parsing a sentence.
class StatPair extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  /// Tints for the two amounts. Default to the accent on the left and the
  /// plain ink on the right; pass `Barako.warning` for money owed.
  final Color? leftColor;
  final Color? rightColor;

  // ignore: prefer_const_constructors_in_immutables
  StatPair({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.leftColor,
    this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    // At large accessibility text the two half-width columns would force the
    // FittedBox to shrink the figures back toward 1.0x, quietly cancelling
    // the one setting a low-vision user relies on, on exactly the numbers
    // they most need. Stacking full-width lets the figures keep their scale;
    // the FittedBox stays as the last resort within each side.
    final large = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _side(leftLabel, leftValue, leftColor, false),
          const SizedBox(height: Gap.sm),
          _side(rightLabel, rightValue, rightColor, false),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _side(leftLabel, leftValue, leftColor, false)),
        const SizedBox(width: Gap.md),
        Expanded(child: _side(rightLabel, rightValue, rightColor, true)),
      ],
    );
  }

  Widget _side(String label, String value, Color? color, bool alignRight) {
    final align = alignRight ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // The two styles this widget exists to standardize used to be
        // hand-rolled right here, invisible to the ladder they were dodging.
        // Now they name their rungs: small muted label, metric figure
        // (17, heavy, tabular so the two columns line up digit for digit).
        Text(label, textAlign: align, style: AppText.small.tint(Barako.muted)),
        const SizedBox(height: Gap.xxs),
        // scaleDown, not ellipsis: a truncated peso figure is worse than a
        // small one, because "₱1,234..." reads as a different amount rather
        // than as a rendering limit. Money never gets cut off here.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            textAlign: align,
            style: color == null
                ? AppText.amountMetric
                : AppText.amountMetric.tint(color),
          ),
        ),
      ],
    );
  }
}

/// One collapsible peer inside a band of several boxed cards, a title row
/// that reveals or hides [child] beneath it. Promoted out of insights.dart's
/// Tools band (previously a private `_CollapsibleTool`) so a second band, or
/// a second screen, gets the exact same interaction rather than a slightly
/// different hand-rolled copy. [child] is expected to be its own complete,
/// already-bordered `Card`, without its own leading title: the title lives
/// here, once, in the always-visible header row above it.
///
/// For a whole page SECTION (a bare [Kicker] plus everything under it), do
/// not reach for a collapsible variant of this widget: a `CollapsibleSection`
/// existed here briefly and was removed. Founder feedback, twice, was that
/// an in-place accordion for a page-level heading reads as clutter rather
/// than an affordance, however it is styled; the real fix for a section
/// that has grown too long is to give it its own destination screen and
/// leave one short `_navRow`-style row behind, the pattern menu.dart's own
/// SETTINGS card follows (see notifications_security.dart).
class CollapsibleCard extends StatefulWidget {
  final String title;
  final Widget child;

  /// Whether this card starts open. Defaults false: these are typically the
  /// nth of several peers, and the space saving is in not showing all of
  /// them at once.
  final bool initiallyExpanded;

  const CollapsibleCard({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        // The chevron below is decorative, so without this a screen reader
        // hears only a tappable title with no open/closed state; expanded
        // maps to the platform's expanded/collapsed announcement.
        child: Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            // The card's own radius, so the tap ripple clips at the corner the
            // eye already sees instead of squaring off 8dp short of it.
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title, style: AppText.label.w7),
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        _open
                            ? salapifyIcon('collapse')
                            : salapifyIcon('expand'),
                        color: Barako.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_open) ...[const SizedBox(height: 8), widget.child],
    ],
  );
}
