// Mindset Today dashboard: the decision history persists and round-trips, the
// summary reads it, and logging a decision through the flow lands in the list
// without ever moving a balance.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/mindset_decisions.dart';
import 'package:salapify/screens/mindset_decisions_list.dart';
import 'package:salapify/screens/mindset_flow.dart';
import 'package:salapify/screens/mindset_insights.dart';
import 'package:salapify/screens/mindset_today.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/segmented.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

Map<String, dynamic> _blob({
  List<Map<String, dynamic>>? decisions,
  List<Map<String, dynamic>>? waiting,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(DateTime(today.year, today.month - m, 5)),
      'accountId': 'pay',
    });
  }
  return {
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'mindsetDecisions': ?decisions,
      'mindsetWaiting': ?waiting,
    },
    'accounts': [
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 40000},
    ],
    'transactions': txns,
  };
}

Map<String, dynamic> _dec(
  String outcome, {
  double? amount,
  String? item,
  String? note,
  DateTime? at,
}) {
  final t = at ?? DateTime.now();
  return {
    'id': 'd_${t.microsecondsSinceEpoch}_$item',
    'itemName': item ?? 'thing',
    'amount': ?amount,
    'outcome': outcome,
    'note': ?note,
    'createdAt': t.toIso8601String(),
  };
}

Future<SalapifyStore> _load(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(blob),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pumpDashboard(WidgetTester tester, SalapifyStore store) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: MindsetTodayScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'a logged decision persists, round-trips, and is absent when empty',
    () async {
      final store = await _load(_blob());
      expect(store.mindsetDecisions, isEmpty);
      // Absent-when-empty keeps the golden key-set contract: a store that never
      // logged a decision must not carry the key.
      expect(
        (store.data['settings'] as Map).containsKey('mindsetDecisions'),
        isFalse,
      );

      await store.addMindsetDecision(
        itemName: 'New headphones',
        amount: 4990,
        categoryId: 'fun',
        outcome: MindsetOutcome.avoided,
        note: '  I already have a pair  ',
        verdict: 'notInPlan',
      );
      expect(store.mindsetDecisions.length, 1);
      final rec = store.mindsetDecisions.single;
      expect(rec['itemName'], 'New headphones');
      expect(rec['amount'], 4990);
      expect(rec['outcome'], MindsetOutcome.avoided);
      // The blank-trimmed note is stored trimmed, not raw.
      expect(rec['note'], 'I already have a pair');
      expect(rec['createdAt'], isA<String>());

      // Reload from the same store bytes: load() runs sanitizeData, so this also
      // proves the decision survives the sanitize/backup passthrough.
      final reloaded = SalapifyStore();
      await reloaded.load();
      expect(reloaded.mindsetDecisions.length, 1);
      expect(reloaded.mindsetDecisions.single['itemName'], 'New headphones');
    },
  );

  test('a blank note is dropped, not stored as empty', () async {
    final store = await _load(_blob());
    await store.addMindsetDecision(
      itemName: 'x',
      outcome: MindsetOutcome.purchased,
      note: '   ',
    );
    expect(store.mindsetDecisions.single.containsKey('note'), isFalse);
  });

  testWidgets('the summary reads today\'s decisions', (tester) async {
    final store = await _load(
      _blob(
        decisions: [
          _dec(MindsetOutcome.purchased, amount: 900, item: 'Online shopping'),
          _dec(
            MindsetOutcome.avoided,
            amount: 350,
            item: 'GrabFood',
            note: 'I cooked at home instead',
          ),
          _dec(MindsetOutcome.avoided, amount: 150, item: 'Coffee'),
          _dec(MindsetOutcome.waiting, amount: 200, item: 'Sale item'),
        ],
      ),
    );
    await _pumpDashboard(tester, store);

    expect(find.text("Today's summary"), findsOneWidget);
    expect(find.text('Decisions made'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // decisions made
    expect(find.text('2'), findsOneWidget); // purchases avoided
    // Recent decisions shows the item and its note.
    expect(find.text('GrabFood'), findsOneWidget);
    expect(find.text('I cooked at home instead'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('empty state when nothing is logged yet', (tester) async {
    final store = await _load(_blob());
    await _pumpDashboard(tester, store);
    expect(find.text('No decisions logged yet.'), findsOneWidget);
    // No list to view, so no "View all".
    expect(find.text('View all'), findsNothing);
  });

  testWidgets('logging a decision from the dashboard lands in the list and '
      'moves no balance', (tester) async {
    final store = await _load(_blob());
    final txCount = (store.data['transactions'] as List).length;
    await _pumpDashboard(tester, store);

    // Open the flow from the dashboard.
    await tester.tap(find.text('Log a Decision'));
    await tester.pumpAndSettle();
    expect(find.byType(MindsetFlowScreen), findsOneWidget);

    // Walk the flow to a decision and skip (an "avoided" outcome).
    await tester.enterText(find.byType(TextField).at(0), 'New shoes');
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // step 2
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // step 3
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_0_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_1_false')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // A decision record was written with the avoided outcome.
    expect(store.mindsetDecisions.length, 1);
    expect(store.mindsetDecisions.single['outcome'], MindsetOutcome.avoided);
    expect(store.mindsetDecisions.single['itemName'], 'New shoes');

    // Back to the dashboard: the decision shows and no balance moved.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(MindsetTodayScreen), findsOneWidget);
    expect(find.text('New shoes'), findsOneWidget);
    expect((store.data['transactions'] as List).length, txCount);
  });

  testWidgets('tapping a recent decision opens its detail with the note', (
    tester,
  ) async {
    final store = await _load(
      _blob(
        decisions: [
          _dec(
            MindsetOutcome.avoided,
            amount: 350,
            item: 'GrabFood',
            note: 'I cooked at home instead',
          ),
        ],
      ),
    );
    await _pumpDashboard(tester, store);

    await tester.tap(find.text('GrabFood'));
    await tester.pumpAndSettle();

    // The detail sheet shows the stored note under a "Your note" heading
    // (the heading is sheet-only; the note itself also shows behind it on the
    // tile, so it appears twice).
    expect(find.text('Your note'), findsOneWidget);
    expect(find.text('I cooked at home instead'), findsWidgets);
    // Read-only: opening the detail records nothing.
    expect(store.mindsetDecisions.length, 1);
  });

  testWidgets('a malformed decision never crashes the dashboard or its detail', (
    tester,
  ) async {
    final store = await _load(
      _blob(
        decisions: [
          // Non-string outcome and itemName: an `as String?` cast would throw.
          {
            'id': 'm1',
            'outcome': 5,
            'itemName': 42,
            'createdAt': DateTime.now().toIso8601String(),
          },
          // An avoided buy with a NaN amount: the money-avoided sum goes NaN,
          // which the count-up must survive.
          {
            'id': 'm2',
            'outcome': MindsetOutcome.avoided,
            'itemName': 'Weird',
            'amount': 'NaN',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
      ),
    );
    await _pumpDashboard(tester, store);
    expect(find.byType(MindsetTodayScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The malformed row renders with the neutral fallback name and opens its
    // read-only detail without throwing.
    await tester.tap(find.text('A purchase'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Waiting on section surfaces paused items and their revisit '
      'time, and is absent when none are waiting', (tester) async {
    final now = DateTime.now();
    final store = await _load(
      _blob(
        waiting: [
          // Ready now: revisitAt in the past.
          {
            'id': 'w1',
            'itemName': 'New headphones',
            'amount': 4990,
            'status': 'waiting',
            'createdAt': now
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            'revisitAt': now
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
          },
          // Still cooling off: revisitAt in the future.
          {
            'id': 'w2',
            'itemName': 'Sneakers',
            'amount': 3200,
            'status': 'waiting',
            'createdAt': now.toIso8601String(),
            'revisitAt': now.add(const Duration(hours: 10)).toIso8601String(),
          },
          // Already reviewed: must NOT show.
          {
            'id': 'w3',
            'itemName': 'Old thing',
            'status': 'reviewed',
            'revisitAt': now.toIso8601String(),
          },
        ],
      ),
    );
    await _pumpDashboard(tester, store);

    expect(find.text('Waiting on'), findsOneWidget);
    expect(find.text('New headphones'), findsOneWidget);
    expect(find.text('Sneakers'), findsOneWidget);
    expect(find.text('Ready to revisit'), findsOneWidget);
    // The future one shows a countdown (exact hours depend on elapsed test time).
    expect(find.textContaining('Revisit in'), findsOneWidget);
    // A reviewed item is not waiting, so it is not surfaced.
    expect(find.text('Old thing'), findsNothing);

    // With nothing waiting, the section header is gone entirely.
    final empty = await _load(_blob());
    await _pumpDashboard(tester, empty);
    expect(find.text('Waiting on'), findsNothing);
  });

  testWidgets('See my 30 days opens the insights screen', (tester) async {
    final store = await _load(_blob());
    await _pumpDashboard(tester, store);
    await tester.tap(find.text('See my 30 days'));
    await tester.pumpAndSettle();
    expect(find.byType(MindsetInsightsScreen), findsOneWidget);
    expect(find.text('MINDFUL STREAK'), findsOneWidget);
  });

  testWidgets('View all filters the history by outcome', (tester) async {
    final store = await _load(
      _blob(
        decisions: [
          _dec(MindsetOutcome.purchased, amount: 900, item: 'Sneakers'),
          _dec(MindsetOutcome.avoided, amount: 350, item: 'GrabFood'),
        ],
      ),
    );
    await _pumpDashboard(tester, store);
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(MindsetDecisionsListScreen), findsOneWidget);
    // Both show under "All".
    expect(find.text('Sneakers'), findsOneWidget);
    expect(find.text('GrabFood'), findsOneWidget);
    // Filter to Avoided: tap the segment (the word also appears on the tile
    // badge, so scope the tap to the Segmented control). The purchased one
    // drops out.
    await tester.tap(
      find.descendant(
        of: find.byType(Segmented<String>),
        matching: find.text('Avoided'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GrabFood'), findsOneWidget);
    expect(find.text('Sneakers'), findsNothing);
  });
}
