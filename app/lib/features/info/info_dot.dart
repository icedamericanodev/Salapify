import 'package:flutter/material.dart';

/// The small circled "i" that opens an explanation.
///
/// It lives here, next to the sheet it opens, rather than in the Home kit
/// where it started. Reports needs it too, and a screen importing another
/// screen's widget file is how two screens end up unable to change
/// independently.
///
/// The 44 by 44 box is not decoration. The glyph is 14 logical pixels and a
/// 14 pixel tap target is unusable; the box is invisible and gives it the
/// floor every tappable control in this app has to clear.
class InfoDot extends StatelessWidget {
  const InfoDot({
    super.key,
    required this.color,
    required this.semanticLabel,
    this.onTap,
  });

  final Color color;

  /// Read aloud by a screen reader, so it has to say what the explanation is
  /// ABOUT. "Info" tells somebody who cannot see the heading beside it
  /// nothing at all.
  final String semanticLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.info_outline, size: 14, color: color),
        ),
      ),
    );
  }
}
