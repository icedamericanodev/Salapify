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

/// Rich ledger plus a lived-in Money Mindset history (checks, a paused/skipped
/// item, and small wins) so Step 4 shows real snapshot, streak, and wins.
Map<String, dynamic> _reflectionBlob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  String ago(int d) => iso(today.subtract(Duration(days: d)));
  final blob = _richBlob();
  blob['wins'] = [
    {'id': 'w1', 'note': 'Skipped new shoes', 'amount': 3200, 'date': ago(3)},
    {
      'id': 'w2',
      'note': 'Packed lunch all week',
      'amount': 1800,
      'date': ago(9),
    },
  ];
  (blob['settings'] as Map)['mindsetChecks'] = [
    {'date': ago(1), 'result': 'pause24h'},
    {'date': ago(8), 'result': 'notInPlan'},
    {'date': ago(15), 'result': 'fitsPlan'},
  ];
  (blob['settings'] as Map)['mindsetWaiting'] = [
    {'id': 'p1', 'createdAt': ago(3), 'status': 'skipped', 'amount': 3200},
    {'id': 'p2', 'createdAt': ago(1), 'status': 'waiting', 'amount': 1200},
  ];
  return blob;
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

  testWidgets('Money Mindset flow, Step 1 Credit detail, dark', (tester) async {
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

    await tester.tap(find.text('Credit or BNPL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '20000');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-credit-dark.png'),
    );
  });

  testWidgets('Money Mindset flow, Step 1 Subscription detail, dark', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    final blob = _richBlob();
    (blob['settings'] as Map)['mindsetSubscriptions'] = [
      {'id': 's1', 'name': 'Streaming', 'amount': 149, 'cycle': 'monthly'},
      {'id': 's2', 'name': 'Cloud', 'amount': 1200, 'cycle': 'annual'},
    ];
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(blob),
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

    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '499');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-subscription-dark.png'),
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

  testWidgets('Money Mindset flow, Step 2 short on bills, dark', (
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
    // A buy larger than everything on hand, so it eats into the money for bills
    // and the alert state renders: red band, warning glyph, and "short".
    await tester.enterText(find.byType(TextField).at(1), '90000');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-short-dark.png'),
    );
  });

  testWidgets('Money Mindset flow, Step 2 goal impact, dark', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    final blob = _richBlob();
    final soon = DateTime.now().add(const Duration(days: 120));
    blob['goals'] = [
      {
        'id': 'g1',
        'name': 'Emergency fund',
        'target': 100000,
        'saved': 82000,
        'targetDate':
            '${soon.year.toString().padLeft(4, '0')}-'
            '${soon.month.toString().padLeft(2, '0')}-'
            '${soon.day.toString().padLeft(2, '0')}',
      },
    ];
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(blob),
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
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-goal-impact-dark.png'),
    );
  });

  testWidgets('Money Mindset flow, score explainer sheet, dark', (
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How we score this'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-score-explainer-dark.png'),
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

  testWidgets('Money Mindset flow, Step 4 Reflection, dark', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(_reflectionBlob()),
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
    await tester.tap(find.byKey(const Key('mindsetAnswer_0_false')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_1_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now')); // -> step 4, skipped
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-step4-dark.png'),
    );
  });
}
