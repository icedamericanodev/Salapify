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

/// The section label, inside a card or outside one.
///
/// theme.dart also defines `cardKickerStyle`, a caramel variant, with a note
/// that "the outside label orients, the inside label belongs to its card".
/// That distinction is deliberately NOT wired up here: the style is currently
/// used by nothing in the app, and debts.dart, the one screen already on the
/// theme style, uses the muted one inside its cards too. So muted everywhere
/// is the real convention, and one style is what this widget exists to
/// enforce. Splitting inside from outside is a design decision worth making
/// on its own, with a render to look at, not smuggled into a deduplication.
class Kicker extends StatelessWidget {
  final String text;

  // NOT const. Barako.kickerStyle is a getter over the ACTIVE palette, read
  // during build. Dart canonicalizes const instances, so a const call site
  // would let Element.updateChild skip build() and freeze this label in the
  // previous theme's colour after a switch. Removing const from the
  // constructor is what makes that impossible at every call site rather than
  // something each caller has to remember.
  // ignore: prefer_const_constructors_in_immutables
  Kicker(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: Barako.kickerStyle);
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
          style: TextStyle(
            color: trailingColor ?? Barako.primary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
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
        Text(
          label,
          textAlign: align,
          style: TextStyle(color: Barako.muted, fontSize: 13),
        ),
        const SizedBox(height: 2),
        // scaleDown, not ellipsis: a truncated peso figure is worse than a
        // small one, because "₱1,234..." reads as a different amount rather
        // than as a rendering limit. Money never gets cut off here.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignRight
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            textAlign: align,
            style: TextStyle(
              color: color ?? Barako.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              // Tabular figures so the two columns line up digit for digit.
              // Without it a 5 and a 1 are different widths and the pair reads
              // as ragged even when both are correct.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
