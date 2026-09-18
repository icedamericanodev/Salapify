// The Phase 3 feel pass, batch 1: feedback fires on real changes and only
// real changes, and motion honors the OS reduce-motion setting.
//
// Three rules under guard:
//  1. Switching tabs clicks once; re-tapping the current tab (scroll to top)
//     is a no-op selection and stays silent.
//  2. The segmented control follows the same rule: re-tapping the segment you
//     are on still calls onPick (the screen may want it) but never buzzes.
//  3. Pan's bob respects reduce-motion: with animations disabled the settle
//     is instant, no ticker left running.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart' show SalapifyApp;
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/widgets/pan_mascot.dart';
import 'package:salapify/widgets/segmented.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments.toString());
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

void main() {
  testWidgets('a tab change clicks once, a re-tap stays silent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    final haptics = _recordHaptics(tester);

    // A BAR tab, not Budget: Budget left the bar and is a pushed screen now, so
    // switching to it is a route push, not the selection this haptic guards.
    // Activity is a real neighbour on the bar, which is what clicks.
    await goToTab(tester, 'Activity');
    expect(haptics, hasLength(1), reason: 'a real tab change clicks once');

    await goToTab(tester, 'Activity');
    expect(
      haptics,
      hasLength(1),
      reason:
          're-tapping the current tab scrolls to top, a no-op selection, '
          'and a buzz on a no-op teaches the hand to distrust every buzz',
    );

    await goToTab(tester, 'Home');
    expect(haptics, hasLength(2), reason: 'switching back is a real change');
  });

  testWidgets('segmented re-tap stays silent but still reports the pick', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    var picks = 0;
    var current = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Segmented<String>(
              options: const [
                SegmentOption(value: 'a', label: 'First'),
                SegmentOption(value: 'b', label: 'Second'),
              ],
              current: current,
              onPick: (v) {
                picks += 1;
                setState(() => current = v);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(picks, 1, reason: 'onPick still fires on a re-tap');
    expect(haptics, isEmpty, reason: 'no buzz for picking what is picked');

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(picks, 2);
    expect(haptics, hasLength(1), reason: 'a real change clicks once');
  });

  testWidgets('pan bob is instant under reduce-motion, no ticker left', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PanMascot(mood: PanMood.happy)),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason:
          'with animations off the bob must settle instantly; a running '
          'ticker means the controller ignored the OS setting',
    );
  });

  testWidgets('pan bob actually animates when motion is allowed', (
    tester,
  ) async {
    // The companion that proves the test above measures the gate and not a
    // universally-dead controller.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PanMascot(mood: PanMood.happy)),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
  });
}
