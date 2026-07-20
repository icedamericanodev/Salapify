// The Money mindset flow: open from Tools, run the impulse check verdict,
// add a small win and see it listed, then delete it. Wins persist in
// data.wins through the store's guarded writes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openMindset(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Tools'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Tools'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Money mindset'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Money mindset'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('impulse check verdict flips only when all three are checked',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();
    await _openMindset(tester);

    expect(find.text('Maybe wait a bit before buying.'), findsOneWidget);

    for (final q in const [
      'Do I actually need this?',
      'Can I wait 24 hours and still want it?',
      'Does it fit my budget this month?',
    ]) {
      await tester.tap(find.text(q));
      await tester.pumpAndSettle();
    }

    expect(find.text('Looks like a thoughtful buy. Go for it.'),
        findsOneWidget);
    expect(find.text('Maybe wait a bit before buying.'), findsNothing);
  });

  testWidgets('a small win can be added and removed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openMindset(tester);

    expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField).first, 'Packed lunch all week');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('🎉 Packed lunch all week'), findsOneWidget);
    expect((store.data['wins'] as List).length, 1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('🎉 Packed lunch all week'), findsNothing);
    expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);
    expect((store.data['wins'] as List).isEmpty, isTrue);
  });
}
