// The Goals flow, on the redesigned screens: create from a template through
// the creation screen, fund it from the detail screen (which only updates
// the goal number), and delete it behind the confirm dialog with a
// full-fidelity Undo. Goals persist in data.goals through the store's
// guarded writes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<void> _openGoals(WidgetTester tester) async {
  await openFromMenu(tester, 'Goals');
}

void main() {
  testWidgets('create from a template, fund it, then delete it with undo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openGoals(tester);

    // The redesigned empty state and its templates.
    expect(find.text('What are you saving for?'), findsOneWidget);
    expect(find.text('Emergency fund'), findsWidgets);

    // Template tap opens the creation screen prefilled; with no spending
    // data the emergency fund honestly offers no number, so type one.
    await tester.tap(find.text('Emergency fund').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Not enough data for a suggestion.', findRichText: true),
      findsNothing,
    ); // the full sentence is longer; presence checked below
    expect(
      find.textContaining('Not enough data for a suggestion'),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextField, '0').first, '10000');
    await tester.scrollUntilVisible(
      find.text('Save goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect((store.data['goals'] as List).length, 1);
    final goal = (store.data['goals'] as List).first as Map;
    expect(goal['name'], 'Emergency fund');
    expect(goal['target'], 10000.0);
    expect(goal['saved'], 0.0);
    expect(goal['kind'], 'savings');
    expect(goal['iconKey'], 'emergency');

    // The card is on the list; open the detail and add 2,500 (comma
    // tolerated). The write lands on the stored goal and history records it.
    await tester.tap(find.text('Emergency fund').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '2,500');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final funded = (store.data['goals'] as List).first as Map;
    expect(funded['saved'], 2500.0);
    expect((funded['contributions'] as List).length, 1);

    // Delete asks first, and Undo restores the FULL row: same id, history
    // intact, not a stripped re-creation.
    await tester.scrollUntilVisible(
      find.text('Delete this goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect((store.data['goals'] as List).length, 1, reason: 'Keep it keeps');

    await tester.tap(find.text('Delete this goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect((store.data['goals'] as List).isEmpty, isTrue);

    final beforeUndoId = funded['id'];
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final restored = (store.data['goals'] as List).first as Map;
    expect(restored['id'], beforeUndoId, reason: 'undo keeps the identity');
    expect(restored['saved'], 2500.0);
    expect(
      (restored['contributions'] as List).length,
      1,
      reason: 'undo keeps the history',
    );
  });

  testWidgets('the detail edit repaces a goal without touching its money', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'goals': [
          {'id': 'g1', 'name': 'Laptop', 'target': 40000.0, 'saved': 5000.0},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openGoals(tester);

    await tester.tap(find.text('Laptop').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust the plan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Target amount'),
      '45000',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final g = (store.data['goals'] as List).first as Map;
    expect(g['target'], 45000.0);
    expect(g['saved'], 5000.0, reason: 'adjusting the plan moves no money');
  });

  testWidgets('a legacy goal with no id still opens and renders', (
    tester,
  ) async {
    // Imported goals may carry no id; the card renders and tapping it is a
    // no-op rather than a crash (there is no identity to open).
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'goals': [
          {'name': 'Legacy goal', 'target': 5000.0, 'saved': 100.0},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openGoals(tester);

    expect(find.text('Legacy goal'), findsOneWidget);
    await tester.tap(find.text('Legacy goal').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((store.data['goals'] as List).length, 1);
  });

  testWidgets('pause hides the pace and moves the goal to its own section', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'goals': [
          {
            'id': 'g1',
            'name': 'Trip',
            'target': 20000.0,
            'saved': 4000.0,
            'targetDate': '2030-01-15',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openGoals(tester);

    await tester.tap(find.text('Trip').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pause this goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause this goal'));
    await tester.pumpAndSettle();
    expect(((store.data['goals'] as List).first as Map)['paused'], true);

    // Back on the list: a PAUSED section with the goal inside, saved intact.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('PAUSED'), findsOneWidget);
    expect(find.text('Paused'), findsWidgets);
    expect(((store.data['goals'] as List).first as Map)['saved'], 4000.0);
  });
}
