import 'package:flutter/painting.dart';

import 'tokens.dart';

/// The colours the Reports charts draw with, VALIDATED rather than chosen.
///
/// Every value here was run through a colour-vision validator against the
/// app's own card surfaces (Hapon #FFFFFF, Gabi #1E1915) before it was
/// written down. The checks are lightness band, chroma floor, separation
/// under the three kinds of colour blindness, the normal-vision floor, and
/// contrast against the surface. Do not swap a value by eye: re-run the
/// validator, because the failure it exists to catch is invisible to anyone
/// with full colour vision.
///
/// WHY THESE ARE NOT THE APP'S POSITIVE AND NEGATIVE. The obvious choice for
/// money in and money out is the palette's green `positive` and orange
/// `negative`. The validator FAILED that pair in light mode: colour-blind
/// separation of 5.5 against a hard floor of 6, so somebody with red-green
/// colour blindness cannot reliably tell the two bars apart, on a chart whose
/// whole job is "above or below zero". Blue against orange scores 24.7 light
/// and 26.8 dark. Orange keeps the meaning it has everywhere else (money
/// out); only the inflow side changes, and only on charts.
///
/// WHY THE CATEGORY SET SKIPS ORANGE, GREEN AND RED. In this app those three
/// already MEAN something: orange is money out and the accent, green is money
/// in. A spending category drawn in orange would read as a debt. So the
/// categories use blue, aqua, yellow, magenta and violet, in that fixed
/// order, never cycled.
///
/// Two validator results worth knowing:
///   - Light mode passes every check, but aqua, yellow and magenta sit below
///     3:1 against white. That warning is not dismissable: it means every
///     category MUST carry a visible text label, never colour alone. The
///     legends on the charts are that label.
///   - Dark mode passes every check including contrast.
///   - The gray [other] "fails" the chroma floor in both modes, which is the
///     point of a gray. What matters is its one real neighbour, violet, the
///     slot it always follows: that pair passes colour-blind separation and
///     the normal-vision floor in both modes. The first dark gray, #5C534B,
///     was too dim to sit on the card (contrast 2.3) and was replaced.
///   - Position's "You owe" bar draws credit cards in [outflow] beside
///     violet; that pair was validated on its own and passes in both modes.
class ChartColors {
  const ChartColors._({
    required this.inflow,
    required this.outflow,
    required this.categories,
    required this.other,
  });

  /// Money in, or a positive net. Blue, see the class note for why not green.
  final Color inflow;

  /// Money out, or a negative net. The app's own orange meaning, kept.
  final Color outflow;

  /// Category identity, in FIXED order. A chart takes these from the front
  /// and folds anything past the end into [other]; it never generates a hue.
  final List<Color> categories;

  /// The "everything else" bucket. Gray on purpose, so it recedes and is
  /// never mistaken for a sixth category.
  final Color other;

  static const ChartColors _light = ChartColors._(
    inflow: Color(0xFF2A78D6),
    outflow: Color(0xFFEB6834),
    categories: <Color>[
      Color(0xFF2A78D6), // blue
      Color(0xFF1BAF7A), // aqua
      Color(0xFFEDA100), // yellow
      Color(0xFFE87BA4), // magenta
      Color(0xFF4A3AA7), // violet
    ],
    other: Color(0xFFB5ACA3),
  );

  static const ChartColors _dark = ChartColors._(
    inflow: Color(0xFF3987E5),
    outflow: Color(0xFFD95926),
    categories: <Color>[
      Color(0xFF3987E5), // blue
      Color(0xFF199E70), // aqua
      Color(0xFFC98500), // yellow
      Color(0xFFD55181), // magenta
      Color(0xFF9085E9), // violet
    ],
    other: Color(0xFF8A8078),
  );

  /// The set stepped for this palette's surface. Gabi is the dark one; the
  /// two palettes are canonical constants, so identity is the test.
  static ChartColors of(Palette p) =>
      identical(p, Palette.gabi) ? _dark : _light;
}
