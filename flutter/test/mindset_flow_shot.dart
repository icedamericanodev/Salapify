// Renders the Money Mindset flow (Step 1, Context) so it can be looked at.
// Not *_test.dart, so `flutter test` never collects it.
//   flutter test test/mindset_flow_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_flow.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show livedInBlob, loadPanFaces, loadRealFonts;

/// Several completed months so the multi-month engines have a base and Step 2
/// shows real figures.
Map<String, dynamic> _richBlob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  DateTime back(int m, int day) => DateTime(today.year, today.month - m, day);
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(back(m, 5)),
      'accountId': 'pay',
    });
    txns.add({
      'id': 'ex$m',
      'type': 'expense',
      'label': 'Living',
      'amount': 17000,
      'date': iso(back(m, 12)),
      'accountId': 'gcash',
    });
  }
  return <String, dynamic>{
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
    },
    'accounts': [
      {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 6000},
      {'id': 'bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 54000},
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 14000},
    ],
    'transactions': txns,
  };
}

void main() {
  testWidgets('Money Mindset flow, Step 1 Context, dark', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(livedInBlob),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetFlowScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Fill it in so the amount field and enabled Continue show.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'New headphones');
    await tester.enterText(fields.at(1), '14990');
    await tester.pumpAndSettle();
    // Drop focus so the render shows the typed values the way the phone does,
    // without the test's text-selection highlight around the amount.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-step1-dark.png'),
    );
  });

  testWidgets('Money Mindset flow, Step 2 Impact, dark', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_richBlob()),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetFlowScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '14990');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-step2-dark.png'),
    );
  });

  testWidgets('Money Mindset flow, Step 3 Decision result, dark', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_richBlob()),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetFlowScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '14990');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // -> step 2
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // -> step 3
    await tester.pumpAndSettle();

    // Answer the three questions; each answer auto-expands the next.
    await tester.tap(find.byKey(const Key('mindsetAnswer_0_false')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_1_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-step3-dark.png'),
    );
  });
}
