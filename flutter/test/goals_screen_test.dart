// The Goals flow: open from Overview, add a goal from a template, add funds
// (which only updates the goal number), and delete it with the tap-to-confirm.
// Goals persist in data.goals through the store's guarded writes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openGoals(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Goals'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Goals'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goals'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add a goal from a template, fund it, then delete it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openGoals(tester);

    // Empty state shows the templates.
    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Emergency fund'), findsWidgets);

    // Tap the Emergency fund template, then Save the prefilled sheet.
    await tester.tap(find.text('Emergency fund').first);
    await tester.pumpAndSettle();
    expect(find.text('Add goal'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((store.data['goals'] as List).length, 1);
    final goal = (store.data['goals'] as List).first as Map;
    expect(goal['name'], 'Emergency fund');
    expect(goal['target'], 10000.0);
    expect(goal['saved'], 0.0);

    // Open it, add 2,500 to savings (comma tolerated), and confirm the number.
    await tester.tap(find.text('Emergency fund').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit goal'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2,500');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(((store.data['goals'] as List).first as Map)['saved'], 2500.0);

    // Delete needs two taps (tap to confirm). The sheet is taller than the
    // test viewport, so bring the button into view first.
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to confirm'), findsOneWidget);
    await tester.ensureVisible(find.text('Tap to confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to confirm'));
    await tester.pumpAndSettle();
    expect((store.data['goals'] as List).isEmpty, isTrue);
    expect(find.text('No goals yet'), findsOneWidget);
  });
}
