import 'package:flutter/material.dart';

import 'institution_brand.dart';
import 'tokens.dart';
import 'type.dart';

/// An institution's own mark, or a clean monogram when there is not one.
///
/// One widget for both cases on purpose. Every caller that wants "show me who
/// this account is with" gets the best available answer without having to ask
/// which kind it is, and a bank added later upgrades every screen at once.
class InstitutionMark extends StatelessWidget {
  const InstitutionMark({
    super.key,
    required this.institution,
    required this.monogram,
    required this.palette,
    this.size = 40,
  });

  /// The name as the account stores it.
  final String institution;

  /// The account's own monogram, used when there is no mark to draw.
  final String monogram;

  final Palette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final InstitutionBrand? brand = brandFor(institution);
    final double radius = size * 0.28;

    if (brand != null && brand.hasMark) {
      return Semantics(
        label: '${brand.name} logo',
        image: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // White behind every mark, always. These are the institutions'
            // own marks, drawn for their own backgrounds, and several are
            // dark navy or maroon on white. Tinting the plate to the app's
            // surface turns those into a dark square in dark mode.
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: Image.asset(
              brand.asset!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // A missing asset must never take a screen down, and must never
              // show the grey broken-image glyph on a finance screen either.
              errorBuilder: (_, _, _) =>
                  _Monogram(text: monogram, palette: palette, size: size),
            ),
          ),
        ),
      );
    }

    return _Monogram(
      text: monogram,
      palette: palette,
      size: size,
      tint: brand?.color,
    );
  }
}

/// Two letters on a tinted plate.
///
/// Not a placeholder to be embarrassed about: for a government fund with a
/// seal rather than a logo, a clean monogram reads better at 40dp than a
/// blurry crest, and it is what the account already carries.
class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.text,
    required this.palette,
    required this.size,
    this.tint,
  });

  final String text;
  final Palette palette;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final Color base = tint ?? palette.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(base.withValues(alpha: 0.16), palette.surface),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: base.withValues(alpha: 0.35)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              // Against the app's own surface rather than against the brand
              // colour, because the plate is only a 16 percent wash of it.
              color: palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
