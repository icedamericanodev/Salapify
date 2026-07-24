// Share a win: reachable from Menu, lists the real milestones from the tested
// engine, switches between wins, hides amounts on toggle, and speaks honestly
// when there is nothing to share yet. The share sheet itself is a platform
// channel, so the tests stop at the buttons.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openWins(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Share a win'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Share a win'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share a win'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a paid debt and a funded goal both share, amounts optional', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 0,
          },
        ],
        'payments': [
          {'id': 'p1', 'debtId': 'd1', 'amount': 5000, 'date': '2026-06-01'},
        ],
        'goals': [
          {'name': 'Emergency fund', 'target': 10000, 'saved': 12000},
        ],
      }),
    });
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openWins(tester);

    // The debt win renders first, with its amount and a happy Pan.
    expect(find.text('Debt free'), findsWidgets);
    expect(find.text('Total paid'), findsWidgets);
    expect(find.bySemanticsLabel('Pan looking happy'), findsWidgets);
    expect(find.text('Share the card'), findsOneWidget);
    expect(find.text('Share as text'), findsOneWidget);

    // Switch to the goal win via its chip.
    await tester.tap(find.text('Goal reached · Emergency fund'));
    await tester.pumpAndSettle();
    expect(find.text('Goal reached'), findsWidgets);
    expect(find.text('Saved up'), findsWidgets);

    // The privacy toggle drops the amount row entirely.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Saved up'), findsNothing);
  });

  testWidgets('no wins yet speaks honestly and offers no share', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openWins(tester);

    expect(find.textContaining('No wins to share yet'), findsOneWidget);
    expect(find.text('Share the card'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
