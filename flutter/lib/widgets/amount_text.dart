// One way to draw a money figure.
//
// The audit found a row amount reading five different ways in five screens
// (resized to 17 and 16, reweighted, rebuilt from raw TextStyle), and every
// one of those forks started life as a call site choosing its own font size.
// This widget removes that choice: a caller names the ROLE the figure plays
// on the screen and this file decides how it draws, through the AppText
// ladder, so restyling every amount in the app stays one edit in
// typography.dart.
//
// Formatting always goes through formatMoney, the one screen formatter, so a
// figure drawn here can never disagree with a figure drawn elsewhere about
// centavos or grouping.

import 'package:flutter/material.dart';

import '../money/format.dart';
import '../typography.dart';

/// The semantic sizes a money figure is allowed to render at. A screen says
/// what the number IS, never how many pixels it wants.
///
/// Every role above [row] is HEAVY (w800), the heavy-is-money rule. Sixteen
/// live sites currently render big amounts at w700; on adoption they snap to
/// heavy, a deliberate ruling rather than an accident, verified against the
/// golden baseline when those screens convert.
enum AmountRole {
  /// The net worth hero, the one biggest number in the app (42).
  hero,

  /// A hero one step down (34): the Reports net worth lead.
  xl,

  /// The hero on a busier screen (30).
  lg,

  /// A card's headline figure (28).
  card,

  /// A labelled metric beside its twin (17): the StatPair columns.
  metric,

  /// Money inline in a list row (15). Never resized, never reweighted;
  /// tint is the only permitted variation, same rule as AppText.amountRow.
  row,

  /// A supporting money figure (15, medium), subordinate to a primary hero,
  /// card, metric or row amount beside it. Keeps tabular figures and the
  /// scale-down protection every money face has; reads quieter by weight and
  /// the secondary ink, not by shrinking below a scannable size. Tint is
  /// overridable, the same as row.
  reference,
}

class AmountText extends StatelessWidget {
  final num value;
  final AmountRole role;

  /// Direction or warning color only. Direction is never color alone: pair a
  /// tint with [signed] or a glyph so a colorblind reader keeps the meaning.
  final Color? tint;

  /// Prefix a '+' on positive values, for rows where direction matters.
  /// Negative values already carry their '-' from formatMoney.
  final bool signed;

  final TextAlign? textAlign;

  // NOT const. The style getters read the live Barako palette during build,
  // and a const call site would freeze the color after a theme switch. Same
  // rule as every shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  AmountText(
    this.value, {
    super.key,
    this.role = AmountRole.row,
    this.tint,
    this.signed = false,
    this.textAlign,
  });

  /// The ladder style for a role. Public so a text INPUT showing an amount
  /// (the sheets' amount field) can share the exact face a rendered amount
  /// has, entering and reading a figure being one act.
  static TextStyle styleFor(AmountRole role) => switch (role) {
    AmountRole.hero => AppText.amountHero,
    AmountRole.xl => AppText.amountXl,
    AmountRole.lg => AppText.amountLg,
    AmountRole.card => AppText.amount,
    AmountRole.metric => AppText.amountMetric,
    AmountRole.row => AppText.amountRow,
    AmountRole.reference => AppText.amountReference,
  };

  @override
  Widget build(BuildContext context) {
    final style = tint == null ? styleFor(role) : styleFor(role).tint(tint!);
    // Always scale-down-to-fit, never clip and never ellipsize: a truncated
    // peso figure reads as a DIFFERENT amount, and a silent clip is worse
    // than the ellipsis this rule already forbids. The FittedBox is layout
    // neutral whenever the figure fits, which is nearly always.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: switch (textAlign) {
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      },
      child: Text(
        '${signed && value > 0 ? '+' : ''}${formatMoney(value)}',
        maxLines: 1,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
