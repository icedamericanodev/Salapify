import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  testWidgets('dbg3', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await pumpSalapify(tester);
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    for (int i = 0; i < 12 && find.text('BPI Rewards Card').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('BPI Rewards Card').first);
    await tester.pumpAndSettle();
    debugPrint('--- after flip ---');
    debugPrint('Edit label: ${find.bySemanticsLabel('Edit this account').evaluate().length}');
    for (final Element e in find.byType(Text).evaluate()) {
      final String? d = (e.widget as Text).data;
      if (d != null && d.length < 40) debugPrint('TXT: $d');
    }
  });
}
