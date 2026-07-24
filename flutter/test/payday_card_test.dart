// The payday ritual card on Home: shows only on a scheduled payday, invites
// the salary log (opening the sheet straight on income), flips to the done
// state when a real income lands, and the Savings first button opens Goals.
// The tests anchor a weekly schedule to today's weekday so "today is payday"
// holds on any calendar day the suite runs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _todayWeekday() => DateTime.now().weekday % 7; // JS-style, Sunday 0

String _todayISO() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _seed({
  bool salaryToday = false,
  bool paydayToday = true,
}) {
  return {
    'accounts': [
      {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 10000},
    ],
    'transactions': [
      if (salaryToday)
        {
          'id': 'i1',
          'date': _todayISO(),
          'type': 'income',
          'label': 'Sweldo',
          'amount': 20000,
          'accountId': 'c',
        },
    ],
    'settings': {
      'paydaySchedule': {
        'mode': 'weekly',
        // Anchored to today, or to tomorrow so today is NOT a payday.
        'weekday': paydayToday ? _todayWeekday() : (_todayWeekday() + 1) % 7,
      },
    },
  };
}

void main() {
  testWidgets('payday morning invites the ritual and opens the income sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_seed()),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('PAYDAY'), findsOneWidget);
    expect(
      find.text('It is payday. Three minutes sets your whole cycle.'),
      findsOneWidget,
    );

    // Log salary opens the sheet with the Income chip already selected.
    await tester.tap(find.text('Log salary'));
    await tester.pumpAndSettle();
    final incomeChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Income'),
    );
    expect(incomeChip.selected, isTrue);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    // Savings first opens Goals.
    await tester.tap(find.text('Savings first'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Goals'), findsOneWidget);
  });

  testWidgets('a salary logged today flips the card to the done state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_seed(salaryToday: true)),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Salary logged. Your cycle is set.'), findsOneWidget);
    expect(find.text('Log salary'), findsNothing);
    expect(find.text('Savings first'), findsOneWidget);
  });

  testWidgets(
    'done state never points at a number card that is not there (QA)',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Salary logged today but with no account and a zero balance: available
      // stays at zero, so Your Number does not render and the card must not
      // claim it does.
      final seed = _seed(salaryToday: true);
      (seed['accounts'] as List).clear();
      seed['accounts'] = [
        {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 0},
      ];
      ((seed['transactions'] as List).first as Map).remove('accountId');
      SharedPreferences.setMockInitialValues({
        'salapify_data_v2': jsonEncode(seed),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Salary logged. Your cycle is set.'), findsOneWidget);
      expect(find.text('YOUR NUMBER'), findsNothing);
      expect(find.textContaining('Your number below is fresh'), findsNothing);
      expect(
        find.textContaining('Your number appears below once'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no card on an ordinary day', (tester) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_seed(paydayToday: false)),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('PAYDAY'), findsNothing);
  });
}
