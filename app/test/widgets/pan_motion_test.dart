// Pan's motion (D30, docs/revamp/pan-motion.md), held to the three promises
// the brief makes about it:
//
//   1. Reduce motion turns ALL of it off, and leaves no ticker running.
//   2. The idle stops after panIdleCycles, so a screen with Pan on it
//      settles. An endless loop would hang every pumpAndSettle in the suite.
//   3. A tap squashes him, and a second tap RESTARTS the squash rather than
//      being swallowed by the one already playing.
//
// Each has a did-anything-happen check beside it, because "nothing is
// running" is also what a Pan that never animated at all looks like.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/pan_art.dart';

Widget _host({bool reduce = false, PanMood mood = PanMood.wave}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: Center(
            child: PanEmptyContent(
              mood: mood,
              title: const Text('Nothing logged yet'),
              body: const Text('Tap Log to record your first expense.'),
            ),
          ),
        ),
      ),
    );

double _squashX(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(panSquashKey)).transform.entry(0, 0);

void main() {
  testWidgets('reduce motion: Pan is still and no ticker is left running', (
    WidgetTester tester,
  ) async {
    final List<String> buzzes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') buzzes.add('$call');
        return null;
      },
    );
    await tester.pumpWidget(_host(reduce: true));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    // Still means no motion layers at all, not motion layers at rest.
    expect(find.byKey(panSquashKey), findsNothing);
    // The text is there at once, not rising in.
    expect(
      tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Nothing logged yet'),
              matching: find.byType(Opacity),
            ),
          )
          .every((Opacity o) => o.opacity == 1),
      isTrue,
    );
    await tester.tap(find.byType(PanArt));
    await tester.pump();
    expect(buzzes, isEmpty, reason: 'a tap must do nothing under reduce motion');
  });

  testWidgets('the idle stops after its cycles, so the screen settles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(mood: PanMood.calm));
    // DIRECTIONAL: he is genuinely moving at first.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.hasRunningAnimations, isTrue);

    // Calm is the longest idle (3600 ms there and back, three times), so if
    // this one settles they all do. The timeout is what fails if it never
    // stops.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a tap squashes him with a buzz, and a second tap restarts it', (
    WidgetTester tester,
  ) async {
    final List<String> buzzes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          buzzes.add(call.arguments as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(_host(mood: PanMood.sleep));
    await tester.pumpAndSettle();
    expect(_squashX(tester), 1);

    await tester.tap(find.byType(PanArt));
    // The first frame after a tap only starts the squash's clock; the next
    // one measures it. 22% of the 560 ms squash is its widest point.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 123));
    expect(_squashX(tester), greaterThan(1.1));
    expect(buzzes, <String>['HapticFeedbackType.lightImpact']);

    // Late in the first squash, tap again.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(PanArt));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 123));
    expect(
      _squashX(tester),
      greaterThan(1.1),
      reason: 'the second tap did not restart the squash',
    );
    await tester.pumpAndSettle();
  });
}
