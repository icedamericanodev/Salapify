import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pinned_app.dart';

/// Guards the scrolling feel.
///
/// The founder hit this on the emulator first: dragging past the end of Home
/// stretched the whole screen, squashing the cards and the peso figures.
/// That is Android 12's stretch overscroll, which Flutter's
/// MaterialScrollBehavior turns on by default, so it arrives unasked.
///
/// These assert the indicator is genuinely absent from the built tree, not
/// merely invisible at rest.
void main() {
  testWidgets('no stretch or glow overscroll indicator is ever built', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();

    expect(
      find.byType(StretchingOverscrollIndicator),
      findsNothing,
      reason:
          'Android stretch overscroll is back, the screen will deform '
          'when dragged past the end',
    );
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });

  testWidgets('dragging past the end does not build an indicator either', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();

    // Overscroll downward, the exact gesture that stretched the screen.
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pump();

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list still scrolls, so the fix did not freeze it', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final double before = scrollable.position.pixels;

    // Drag upward to scroll down the page.
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    // Directional: the list actually moved down, it is not merely unstretched.
    expect(
      scrollable.position.pixels,
      greaterThan(before),
      reason: 'removing the overscroll indicator must not stop scrolling',
    );
  });

  /// A MOUSE can drag, which Flutter refuses by default.
  ///
  /// This is not about the shipped phone, where a finger reports as
  /// `PointerDeviceKind.touch` and always worked. It is about the Android
  /// EMULATOR, which is the only place the founder ever sees this app.
  ///
  /// The failure it guards is silent and asymmetric, which is why it went
  /// unnoticed. A mouse WHEEL scrolls a vertical list and a wheel is not a
  /// drag, so vertical scrolling worked and nothing looked wrong. A mouse has
  /// no sideways wheel, so every HORIZONTAL strip read as frozen. The founder
  /// hit it on Activity's filter strip, where the per-account chips sit past
  /// the fold: they could see a chip edge at the screen border and could not
  /// reach it, and nothing on screen distinguishes "there is no more here"
  /// from "I cannot get to it".
  testWidgets('a MOUSE can drag a list, not just a finger', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final double before = scrollable.position.pixels;

    // The whole point: kind is mouse, not the default touch.
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -300),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(
      scrollable.position.pixels,
      greaterThan(before),
      reason:
          'a mouse drag moved nothing, so every horizontal strip in the app '
          'is unreachable on the emulator the founder reviews with',
    );
  });

  testWidgets('and a finger still can, which is what actually ships', (
    WidgetTester tester,
  ) async {
    // The directional half. Adding a device kind must not disturb the one
    // that was already working, and touch is the only kind a phone sends.
    await pumpSalapify(tester);
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final double before = scrollable.position.pixels;

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -300),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(before));
  });
}
