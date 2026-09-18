import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';

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
  testWidgets('no stretch or glow overscroll indicator is ever built',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    expect(
      find.byType(StretchingOverscrollIndicator),
      findsNothing,
      reason: 'Android stretch overscroll is back, the screen will deform '
          'when dragged past the end',
    );
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });

  testWidgets('dragging past the end does not build an indicator either',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    // Overscroll downward, the exact gesture that stretched the screen.
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pump();

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list still scrolls, so the fix did not freeze it',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    final ScrollableState scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
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
}
