import 'package:flutter/gestures.dart';
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

  /// A MOUSE MAY DRAG, which Flutter refuses by default.
  ///
  /// `ScrollBehavior.dragDevices` ships as touch, stylus, inverted stylus,
  /// trackpad and unknown. Mouse is deliberately left out upstream, because on
  /// a desktop a click and drag usually means select text rather than scroll.
  ///
  /// Salapify is a phone app, so on a real device this changes NOTHING: a
  /// finger reports as touch and already scrolled everything. It exists for the
  /// Android EMULATOR, where the founder reviews every screen with a mouse.
  ///
  /// The symptom it fixes is worse than it sounds, because it is silent and it
  /// is asymmetric. A mouse WHEEL scrolls a vertical list, and a wheel is not a
  /// drag, so vertical lists work. A mouse has no sideways wheel, so every
  /// HORIZONTAL strip in the app reads as frozen. The founder hit this on the
  /// Activity filter strip, where the account chips sit past the fold: the
  /// chips they needed were on screen-edge and unreachable, and nothing
  /// distinguishes "there is nothing more here" from "I cannot reach it".
  /// Reviewing an app from that position is how a missing feature gets
  /// reported and a present one gets missed.
  ///
  /// Shift plus the wheel already worked, via `pointerAxisModifiers`, but a
  /// workaround nobody knows is not a route.
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
