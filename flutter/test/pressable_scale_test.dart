// PressableScale must add the press feel WITHOUT stealing the child's tap or
// scroll. It wraps a Listener + AnimatedScale, so an inner InkWell/onTap still
// fires. This locks that composition so the polish can never silently break a
// button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/pressable_scale.dart';

void main() {
  testWidgets('a tap still reaches the child through PressableScale',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressableScale(
            child: Material(
              child: InkWell(
                onTap: () => taps++,
                child: const SizedBox(width: 120, height: 48, child: Text('Go')),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    // It is a scale wrapper, not a gesture owner.
    expect(find.byType(AnimatedScale), findsOneWidget);
  });
}
