// A steady, font independent masked card number line.
//
// NAMING, because this repo has a Pan. "Pan" is the mascot (pan_mascot.dart);
// "PAN" here is the old card word Primary Account Number, the long number on a
// bank card. This widget draws that number line and nothing else. It shares no
// code and no meaning with the mascot; the file is named for the card feature
// it was asked for, and the class says plainly what it is.
//
// THE SECURITY CONTRACT IS UNCHANGED. Salapify never stores a full card number,
// only the last four digits (see flip_bank_card.dart and the data layer). So
// this widget takes a nullable [last4] and draws masked dots for everything in
// front of it. There is deliberately no way to pass a full number in; the extra
// groups are always dots, never real digits, because there is no real digit to
// show.
//
// WHY GEOMETRIC DOTS instead of a bullet character. The old number line was a
// run of the bullet glyph in the shipped font. A glyph's width and weight
// depend on the font, so the sandbox fallback drew it one way and Plus Jakarta
// Sans another, and toggling reveal swapped a run of bullets for a run of
// digits of a different width, which shifted the whole line ("jitter"). Fixed
// size Container circles are pixel exact in every font and every theme, and the
// last four ride on tabular figures so revealing them cannot change the line's
// width. That is the whole fix: the mask can no longer distort or jump.

import 'package:flutter/material.dart';

import '../theme.dart' show Barako;

/// A masked card number: [groups] runs of four dots, then the last four digits
/// (shown only when [revealed] and valid, dots otherwise). Intrinsically sized
/// and deterministic, so a caller can drop it in a [FittedBox] or [Expanded]
/// exactly like the text it replaces. It paints [color] and reads no palette of
/// its own, so it works on a colored card face as well as on a themed surface.
class CardNumberMask extends StatelessWidget {
  /// The last four digits, or null when there is nothing stored. Only a value
  /// of exactly four ASCII digits ever renders as real digits; anything else
  /// falls back to dots, the same rule the card faces already use.
  final String? last4;

  /// Reveal the last four. False draws dots in their place. The masked groups
  /// in front are dots either way, since no full number is ever stored.
  final bool revealed;

  /// How many four dot groups sit in front of the last four. A full card face
  /// uses 3 (••••  ••••  ••••  last4); the condensed back and the detail row
  /// use 0 (last4 alone), which is why this is a parameter.
  final int groups;

  /// The ink for both the dots and the digits. Defaults to the theme text so it
  /// reads on a normal surface; card faces pass white.
  final Color? color;

  /// The digit size. The dots are sized from this so the two always agree.
  final double fontSize;

  /// Scale the whole line down to fit its box rather than overflow, matching the
  /// card faces which already scale their number line. On by default because the
  /// only jitter left after geometric dots would be an overflow clip.
  final bool scaleDown;

  const CardNumberMask({
    super.key,
    required this.last4,
    this.revealed = false,
    this.groups = 3,
    this.color,
    this.fontSize = 15,
    this.scaleDown = true,
  });

  /// Whether [last4] is a real four digit value we may show.
  bool get _hasDigits => last4 != null && RegExp(r'^\d{4}$').hasMatch(last4!);

  /// The dot diameter, tied to the digit size so a restyle keeps them in step.
  double get _dotSize => (fontSize * 0.42).clamp(4.0, 9.0);

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Barako.text;
    final showDigits = revealed && _hasDigits;

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < groups; i++) ...[
          if (i > 0) SizedBox(width: fontSize * 0.66),
          _DotGroup(color: ink, dotSize: _dotSize),
        ],
        if (groups > 0) SizedBox(width: fontSize * 0.66),
        // The last four: real tabular digits when revealed, otherwise one more
        // dot group. Tabular figures hold the column so revealing cannot move
        // the line, and a fixed dot group is exactly as wide as four digits are
        // not, which is fine because the digits are the thing held steady.
        if (showDigits)
          Text(
            last4!,
            style: TextStyle(
              fontFamily: Barako.displayFont,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: ink,
              // The single reason the digits do not jitter: a fixed advance per
              // glyph, so 1189 and 8000 occupy the same width.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
          _DotGroup(color: ink, dotSize: _dotSize),
      ],
    );

    if (!scaleDown) return line;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: line,
    );
  }
}

/// Four evenly spaced dots. Pure geometry: a Container circle is the same width
/// in every font and every palette, which is what makes the masked line steady.
class _DotGroup extends StatelessWidget {
  final Color color;
  final double dotSize;
  const _DotGroup({required this.color, required this.dotSize});

  @override
  Widget build(BuildContext context) {
    final gap = dotSize * 0.55;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}
