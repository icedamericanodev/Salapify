// Widget behaviour for Pan's floating helper (f4.65): the bubble opens a
// swipeable tip sheet, swiping advances it, and tapping a tip's button hands the
// right tip back to the shell and closes the sheet. The tip content is proven in
// pan_tips_test.dart; the navigation mapping lives in the shell's exhaustive
// switch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/pan_tips.dart';
import 'package:salapify/widgets/pan_helper_bubble.dart';

void main() {
  late SalapifyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SalapifyStore();
    await store.load();
  });

  Future<void> pump(
    WidgetTester tester,
    void Function(PanTip) onTip, {
    VoidCallback? onOpenChat,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: PanHelperBubble(
              store: store,
              onTipTap: onTip,
              onOpenChat: onOpenChat ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the bubble opens the first tip; a CTA reports it back', (
    tester,
  ) async {
    PanTip? tapped;
    await pump(tester, (t) => tapped = t);

    // The sheet is closed until the bubble is tapped.
    expect(find.text('Pan says'), findsNothing);

    // Tap the bubble (the Semantics button).
    await tester.tap(find.bySemanticsLabel(RegExp('Pan, your money helper')));
    await tester.pumpAndSettle();

    // The sheet shows, on the first tip.
    expect(find.text('Pan says'), findsOneWidget);
    expect(find.text(panTips.first.title), findsOneWidget);

    // Tapping the first tip's button reports that exact tip and closes the sheet.
    await tester.tap(find.text(panTips.first.ctaLabel));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped!.target, panTips.first.target);
    expect(find.text('Pan says'), findsNothing);
  });

  testWidgets('the sheet leads with a Chat with Pan button that opens chat', (
    tester,
  ) async {
    var openedChat = false;
    await pump(tester, (_) {}, onOpenChat: () => openedChat = true);
    await tester.tap(find.bySemanticsLabel(RegExp('Pan, your money helper')));
    await tester.pumpAndSettle();

    // The headline button is present and opens the chat, then closes the sheet.
    expect(find.widgetWithText(FilledButton, 'Chat with Pan'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Chat with Pan'));
    await tester.pumpAndSettle();
    expect(openedChat, isTrue);
    expect(find.text('Pan says'), findsNothing);
  });

  testWidgets('the tips are swipeable to the last, the Ask Pan door', (
    tester,
  ) async {
    await pump(tester, (_) {});
    await tester.tap(find.bySemanticsLabel(RegExp('Pan, your money helper')));
    await tester.pumpAndSettle();

    // Swipe through every page to the last.
    for (var i = 1; i < panTips.length; i++) {
      await tester.drag(find.text(panTips[i - 1].title), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text(panTips.last.title), findsOneWidget);
    expect(panTips.last.target, PanTipTarget.askPan);
  });

  testWidgets('the dragged bubble snaps to a side and remembers it', (
    tester,
  ) async {
    await pump(tester, (_) {});
    // Drag the bubble from the default left side across to the right, with an
    // explicit gesture so onPanEnd is guaranteed to fire on release.
    final g = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel(RegExp('Pan, your money helper'))),
    );
    await tester.pump();
    // First move past the touch slop so the pan recognizer wins the arena, then
    // the rest of the way, pumping between so the moves are delivered.
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveBy(const Offset(330, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    // The store persists through a serialized async write; let real async run so
    // the write chain drains before reading it back.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(
      (store.data['settings'] as Map)['panHelperSide'],
      'right',
      reason: 'dragging past the middle should snap and persist the right side',
    );
  });
}
