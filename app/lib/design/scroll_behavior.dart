import 'package:flutter/material.dart';

/// Salapify's scrolling feel.
///
/// Android 12 and up ships a STRETCH overscroll: drag past the end of a list
/// and the whole thing rubber-bands, squashing the cards and the peso figures
/// with it. Flutter turns that on by default through MaterialScrollBehavior,
/// so it arrives without anyone asking for it.
///
/// It is wrong for this app for two reasons. The prototype in src/ is a web
/// build that simply stops at the end, so the stretch is a behaviour the
/// Flutter app invented rather than migrated. And a ledger is a document: a
/// person reading a column of money does not expect the numbers to deform
/// under their thumb.
///
/// So the indicator is dropped entirely. The list still scrolls exactly as
/// far as its content goes, it just stops at the edge instead of stretching.
/// No glow either, which is the older Android effect the same hook draws.
class SalapifyScrollBehavior extends MaterialScrollBehavior {
  const SalapifyScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Returning the child unwrapped is what removes the effect. Anything else
    // here, including a zero-size wrapper, puts it back.
    return child;
  }

  /// Clamping on every platform, so a list cannot be dragged past its own end
  /// and spring back. This is already the Android default; naming it means the
  /// feel does not silently change if the app is ever run on iOS.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
