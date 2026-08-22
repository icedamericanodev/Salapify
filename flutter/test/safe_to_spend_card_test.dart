// Widget behaviour for the Safe-to-Spend card (f4.62). The money is proven in
// safe_buffer_golden_test.dart; this proves the card renders the right face for
// the right state and never leaks a figure past the privacy eye.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/safe_to_spend_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Map<String, dynamic> buffer,
    SafeToSpendView view = SafeToSpendView.buffer,
    double netWorth = 128450,
    bool hideBalances = false,
    void Function(SafeToSpendView)? onView,
    VoidCallback? onOpenTrend,
  }) {
    // Mirrors the screen's _money: masks to dots when the privacy eye is on, so
    // the test exercises the card exactly as it is wired in accounts.dart.
    String money(double v) => hideBalances ? '₱ ••••' : '₱${v.toStringAsFixed(0)}';
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafeToSpendCard(
              view: view,
              onView: onView ?? (_) {},
              buffer: buffer,
              netWorth: netWorth,
              money: money,
              hideBalances: hideBalances,
              onOpenTrend: onOpenTrend ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> healthy() => {
    'liquid': 38000.0,
    'cardDue': 7300.0,
    'billsDue': 12000.0,
    'committed': 19300.0,
    'buffer': 18700.0,
    'dueCount': 4,
    'minsUnset': 0,
    'windowDays': 14,
  };

  testWidgets('healthy buffer shows the figure and the honest sentence', (
    tester,
  ) async {
    await pump(tester, buffer: healthy());
    expect(find.text('₱18700'), findsOneWidget);
    // The sentence names both the free figure and the reserved amount, and the
    // words "card minimums" (the honesty anchor both reviewers required).
    expect(find.textContaining('free to spend'), findsOneWidget);
    expect(find.textContaining('card minimums'), findsWidgets);
    // A card is in the window, so the minimum-only caveat is present.
    expect(
      find.textContaining('Paying just the minimum'),
      findsOneWidget,
    );
  });

  testWidgets('a negative buffer leads with the shortfall, not a spend figure', (
    tester,
  ) async {
    final broke = {
      ...healthy(),
      'liquid': 2000.0,
      'buffer': 2000.0 - 19300.0,
    };
    await pump(tester, buffer: broke);
    // The shortfall is shown as a positive "short" amount, never "-₱".
    expect(find.textContaining('short for the next 14 days'), findsOneWidget);
    expect(find.textContaining('free to spend'), findsNothing);
  });

  testWidgets('a debt with no minimum set is flagged on the card', (
    tester,
  ) async {
    final flagged = {
      'liquid': 10000.0,
      'cardDue': 0.0,
      'billsDue': 0.0,
      'committed': 0.0,
      'buffer': 10000.0,
      'dueCount': 0,
      'minsUnset': 2,
      'windowDays': 14,
    };
    await pump(tester, buffer: flagged);
    expect(find.textContaining('have no minimum set'), findsOneWidget);
  });

  testWidgets('the privacy eye hides every figure and the sentence', (
    tester,
  ) async {
    await pump(tester, buffer: healthy(), hideBalances: true);
    expect(find.text('₱18700'), findsNothing);
    // No plain-English sentence with a peso figure leaks while hidden.
    expect(find.textContaining('free to spend'), findsNothing);
  });

  testWidgets('the toggle switches to the net worth lens', (tester) async {
    SafeToSpendView? picked;
    await pump(
      tester,
      buffer: healthy(),
      view: SafeToSpendView.netWorth,
      onView: (v) => picked = v,
    );
    // In the net worth lens the hero figure shows and taps through.
    expect(find.text('₱128450'), findsOneWidget);
    expect(find.textContaining('minus everything you owe'), findsOneWidget);

    // Tapping the buffer segment reports the change back to the screen.
    await tester.tap(find.text('Safe to spend'));
    await tester.pump();
    expect(picked, SafeToSpendView.buffer);
  });

  testWidgets('tapping the net worth figure opens the trend', (tester) async {
    var opened = false;
    await pump(
      tester,
      buffer: healthy(),
      view: SafeToSpendView.netWorth,
      onOpenTrend: () => opened = true,
    );
    await tester.tap(find.text('₱128450'));
    await tester.pump();
    expect(opened, isTrue);
  });
}
