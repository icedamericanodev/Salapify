// The one boxed card.
//
// A "card" in this app is a fill, a hairline border, one corner radius and one
// interior padding, and it had been hand-rolled as a bare Container with its
// own BoxDecoration and its own EdgeInsets in dozens of screens. They had
// stopped agreeing: the same visual object shipped with Insets.card here and a
// literal EdgeInsets.all(16) there, a kicker then Gap.xs on one card and Gap.sm
// on the next, and nothing failed, because a private padding is invisible to
// every test and to every reader not diffing two files side by side. The exact
// drift Kicker and AppText were built to stop, one layer out.
//
// This is that object, once. A screen names WHAT it is (a card, optionally with
// a kicker) and this file decides the fill, the border, the radius, the one
// interior padding and the one kicker gap, so restyling every card is a single
// edit here rather than a call-site sweep. It deliberately does NOT try to be
// every card: a card whose top line is a control (the Segmented on the safe to
// spend card) passes no kicker and lays that control out itself; a raised hero
// is its own surface with more corner (Radii.hero) and is not this. What this
// owns is the ordinary boxed card, which is most of them.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'section.dart';

class SalapifyCard extends StatelessWidget {
  /// An optional uppercase overline at the top of the card, drawn as a card
  /// kicker (the warm inside-a-card accent). Null for a card that leads with
  /// its own content or its own control.
  final String? kicker;

  /// The card body. A card with a [kicker] gets exactly one standard gap
  /// (Gap.sm) between the kicker and this, so no caller has to remember the
  /// number.
  final Widget child;

  /// Interior padding. Defaults to the one standard card interior (Insets.card,
  /// 16 on every side). Overridable only for the rare card that genuinely wants
  /// a different inset (a media card that bleeds an image to its edge), not as a
  /// routine knob.
  final EdgeInsetsGeometry padding;

  /// An optional whole-card tap. When set, the card becomes an InkWell whose
  /// ripple clips to the card's own radius, the standing rule for a tap that
  /// fills a card, so the ripple stops at the corner the eye already sees.
  final VoidCallback? onTap;

  /// Cross-axis alignment of the interior column. Defaults to start (a card
  /// reads top-left down), overridable for a centered empty-state card.
  final CrossAxisAlignment crossAxisAlignment;

  // NOT const: build() reads mutable Barako getters, so a const call site would
  // freeze the card in the previous palette after a theme switch. Same rule as
  // every shared widget that reads the live palette.
  // ignore: prefer_const_constructors_in_immutables
  SalapifyCard({
    super.key,
    this.kicker,
    required this.child,
    this.padding = Insets.card,
    this.onTap,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (kicker != null) ...[
            Kicker(kicker!, inCard: true),
            const SizedBox(height: Gap.sm),
          ],
          child,
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: onTap == null
          ? body
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.card),
                onTap: onTap,
                child: body,
              ),
            ),
    );
  }
}
