// New phone day: reachable from Menu, shows the three guided steps, hides the
// old-phone action buttons on an empty store (nothing to save yet) but shows
// them for settings-only data (a Steady Pay setup is worth moving too), and
// the new-phone step opens the existing import screen. The save and share
// sheets are platform channels, so the tests stop at the buttons.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openNewPhoneDay(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('New phone day'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('New phone day'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New phone day'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guides the handoff and opens the importer on the new phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Food',
            'amount': 100,
            'date': '2026-07-01',
            'accountId': 'c',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openNewPhoneDay(tester);

    expect(find.text('ON THIS PHONE'), findsOneWidget);
    expect(find.text('ON THE NEW PHONE'), findsOneWidget);
    expect(find.text('Save backup file'), findsOneWidget);
    expect(find.text('Share the backup'), findsOneWidget);

    await tester.tap(find.text('I am the new phone: bring data over'));
    await tester.pumpAndSettle();
    // The existing import screen opens.
    expect(find.widgetWithText(AppBar, 'Import backup'), findsOneWidget);
  });

  testWidgets('an empty store hides the old-phone action buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openNewPhoneDay(tester);

    expect(find.text('Save backup file'), findsNothing);
    expect(find.text('Share the backup'), findsNothing);
    expect(
      find.text('I am the new phone: bring data over'),
      findsOneWidget,
      reason: 'the new-phone path is exactly what an empty store needs',
    );
  });

  testWidgets('settings-only data still gets the save and share buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // No accounts, no transactions, just an accepted Steady Pay: data worth
    // moving to the new phone all the same.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'settings': {
          'steadyPay': {'amount': 2500, 'acceptedAt': '2026-07-01'},
        },
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openNewPhoneDay(tester);

    expect(find.text('Save backup file'), findsOneWidget);
    expect(find.text('Share the backup'), findsOneWidget);
  });
}
