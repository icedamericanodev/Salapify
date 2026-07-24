// The Earn your treats flow: open from Menu, start from a template, check in
// today (which routes through the golden-locked engine), and confirm the cap of
// three. State persists in settings.treats through the store's guarded writes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openTreats(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Earn your treats'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Earn your treats'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Earn your treats'));
  await tester.pumpAndSettle();
}

List _treats(SalapifyStore store) =>
    (store.data['settings'] as Map)['treats'] as List;

void main() {
  testWidgets('start from a template, save, then check in today', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openTreats(tester);

    // Empty state shows the templates.
    expect(find.text('PICK ONE TO START'), findsOneWidget);
    expect(find.text('Milk tea or coffee'), findsOneWidget);

    // Tap a template, then Save the prefilled sheet.
    await tester.tap(find.text('Milk tea or coffee'));
    await tester.pumpAndSettle();
    expect(find.text('New treat'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_treats(store).length, 1);
    final t = _treats(store).first as Map;
    expect(t['treat'], 'Milk tea or coffee');
    expect(t['target'], 3);
    expect((t['checkIns'] as List).isEmpty, isTrue);

    // Check in today: the engine adds today and bumps lifetime.
    await tester.ensureVisible(find.text('I did it today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I did it today'));
    await tester.pumpAndSettle();
    expect(((_treats(store).first as Map)['checkIns'] as List).length, 1);
    expect((_treats(store).first as Map)['lifetime'], 1);
    expect(find.text('Done for today, tap to undo'), findsOneWidget);

    // Tap again to undo: back to zero, lifetime never negative.
    await tester.tap(find.text('Done for today, tap to undo'));
    await tester.pumpAndSettle();
    expect(((_treats(store).first as Map)['checkIns'] as List).isEmpty, isTrue);
    expect((_treats(store).first as Map)['lifetime'], 0);
  });

  testWidgets('the three treat cap disables Add', (tester) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'settings': {
          'treats': [
            {
              'id': 't1',
              'treat': 'A',
              'action': 'x',
              'target': 3,
              'windowDays': 7,
              'checkIns': [],
              'lifetime': 0,
            },
            {
              'id': 't2',
              'treat': 'B',
              'action': 'y',
              'target': 3,
              'windowDays': 7,
              'checkIns': [],
              'lifetime': 0,
            },
            {
              'id': 't3',
              'treat': 'C',
              'action': 'z',
              'target': 3,
              'windowDays': 7,
              'checkIns': [],
              'lifetime': 0,
            },
          ],
        },
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openTreats(tester);

    // The list renders and + Add is disabled at the cap of three.
    expect(find.text('A'), findsOneWidget);
    final addBtn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '+ Add'),
    );
    expect(addBtn.onPressed, isNull);
  });

  testWidgets('editing a treat keeps its check-ins and lifetime', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'settings': {
          'treats': [
            {
              'id': 't1',
              'treat': 'Milk tea',
              'action': 'Lakad',
              'emoji': '🧋',
              'target': 3,
              'windowDays': 7,
              'checkIns': ['2020-01-01'],
              'lifetime': 9,
              'createdAt': '2020-01-01',
            },
          ],
        },
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openTreats(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit treat'), findsOneWidget);
    // Rename the treat, then Save.
    await tester.enterText(find.byType(TextField).first, 'Kape');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final t = _treats(store).first as Map;
    expect(t['treat'], 'Kape');
    // The edit renormalizes user fields but must never wipe progress.
    expect(t['lifetime'], 9);
    expect(t['createdAt'], '2020-01-01');
    expect((t['checkIns'] as List), ['2020-01-01']);
  });
}
