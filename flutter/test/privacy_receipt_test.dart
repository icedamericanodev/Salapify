// The Privacy receipt screen: reachable from Menu under Security, states the
// two-connection list and the airplane mode challenge, and renders the real
// fetch log (or its honest empty state). The receipt is a launch trust
// surface, so its load-bearing claims are pinned here.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/fx_service.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openReceipt(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Privacy receipt'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Privacy receipt'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Privacy receipt'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens from Menu and pins the whole-list claim', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReceipt(tester);

    expect(find.text('Your money data lives on this phone'), findsOneWidget);
    expect(find.text('Live exchange rates'), findsOneWidget);
    expect(find.text('App updates'), findsOneWidget);
    expect(find.textContaining('That is the whole list'), findsOneWidget);
    expect(find.text('EVERY PERMISSION, AND WHY'), findsOneWidget);
    expect(find.text('Do not take our word for it'), findsOneWidget);
    expect(find.textContaining('airplane mode'), findsWidgets);
    // No fetches recorded yet: the log speaks honestly instead of hiding.
    expect(find.textContaining('No rate fetches yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders recorded fetch attempts, newest first', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      FxService.logKey: jsonEncode([
        {
          'at': DateTime(2026, 7, 24, 9, 5).millisecondsSinceEpoch,
          'base': 'PHP',
          'ok': true,
        },
        {
          'at': DateTime(2026, 7, 20, 21, 40).millisecondsSinceEpoch,
          'base': 'USD',
          'ok': false,
        },
      ]),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openReceipt(tester);

    await tester.scrollUntilVisible(
      find.textContaining('rates for PHP'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jul 24 2026, 9:05 AM rates for PHP'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Jul 20 2026, 9:40 PM rates for USD, no connection'),
      findsOneWidget,
    );
    expect(find.textContaining('No rate fetches yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
