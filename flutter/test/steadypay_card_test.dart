// The Steady Pay card on Insights: appears only with real income history or
// an accepted draw, suggests the lean-month weekly pay, accepting through the
// dialog flips it to the weekly status, and a store with no history shows
// nothing. Seeds use months relative to the run day so the six-full-month
// window always contains them.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _monthsAgo(int months) {
  final n = DateTime.now();
  final d = DateTime(n.year, n.month - months, 10);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-10';
}

Map<String, dynamic> _gigSeed() => {
  'accounts': [
    {'id': 'c', 'name': 'GCash', 'kind': 'ewallet', 'balance': 24000},
  ],
  'transactions': [
    {
      'id': 'i1',
      'type': 'income',
      'label': 'Gigs',
      'amount': 12000,
      'date': _monthsAgo(1),
    },
    {
      'id': 'i2',
      'type': 'income',
      'label': 'Gigs',
      'amount': 9000,
      'date': _monthsAgo(2),
    },
    {
      'id': 'i3',
      'type': 'income',
      'label': 'Gigs',
      'amount': 15000,
      'date': _monthsAgo(3),
    },
  ],
};

Future<void> _openInsights(WidgetTester tester) async {
  await tester.tap(find.text('Insights'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'suggests the lean weekly pay and accepts it through the dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'salapify_data_v2': jsonEncode(_gigSeed()),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await _openInsights(tester);

      await tester.scrollUntilVisible(
        find.text('STEADY PAY · YOUR OWN SALARY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Lean baseline is the mean of 9000, 12000, 15000 = 12000 a month, so
      // the suggested weekly pay is 12000 * 12 / 52 = ~2769.
      expect(find.textContaining('Pay yourself ₱2,769 a week'), findsOneWidget);
      expect(find.textContaining('runway, not lifestyle'), findsOneWidget);

      // Accept through the dialog, typing the comma format the dialog itself
      // displays; the parse must strip it like every other amount field.
      await tester.tap(find.text('Set my weekly pay'));
      await tester.pumpAndSettle();
      expect(find.text('Your weekly pay'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '2,769',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The card flips to the weekly status, reading back the stored draw.
      expect(find.textContaining('₱2,769 a week'), findsOneWidget);
      expect(find.textContaining('Drawn'), findsOneWidget);
      expect(
        ((store.data['settings'] as Map)['steadyPay'] as Map)['amount'],
        2769,
      );
    },
  );

  testWidgets('thin history shows the honest building state (QA follow-up)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Two income months: not enough for a suggestion, enough to show the
    // card with progress instead of nothing, so the course lesson's button
    // never lands on a blank.
    final seed = _gigSeed();
    (seed['transactions'] as List).removeLast();
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(seed),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openInsights(tester);

    await tester.scrollUntilVisible(
      find.text('STEADY PAY · YOUR OWN SALARY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 so far'), findsOneWidget);
    expect(find.text('Set my weekly pay'), findsNothing);
  });

  testWidgets('no income history means no Steady Pay card', (tester) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'accounts': [
          {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openInsights(tester);
    expect(find.text('STEADY PAY · YOUR OWN SALARY'), findsNothing);
  });
}
