// The habit layer: the chain that never resets, the celebration a cleared
// debt deserves, and the treat surfaced on Home.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/chain.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  group('chainState', () {
    // Pinned reference day, the clock-seam rule: Monday 2026-07-27.
    final ref = DateTime(2026, 7, 27);

    List<Map<String, dynamic>> txs(List<String> dates) => [
      for (final (i, d) in dates.indexed)
        {'id': 't$i', 'type': 'expense', 'label': 'x', 'amount': 1, 'date': d},
    ];

    test('counts only income and expense days inside the window', () {
      final s = chainState([
        {'id': 'a', 'type': 'expense', 'amount': 1, 'date': '2026-07-27'},
        {'id': 'b', 'type': 'transfer', 'amount': 1, 'date': '2026-07-26'},
        {'id': 'c', 'type': 'income', 'amount': 1, 'date': '2026-07-25'},
        {'id': 'd', 'type': 'expense', 'amount': 1, 'date': '2026-07-01'},
      ], ref);
      expect(s.count, 2, reason: 'The transfer and the out-of-window day '
          'must not count; records are written by machinery.');
      expect(s.todayDone, isTrue);
      expect(s.days.first.iso, '2026-07-21');
      expect(s.days.last.iso, '2026-07-27');
    });

    test('the comeback line fires when it should', () {
      // Logged three days ago, missed yesterday, today still unlogged.
      final s = chainState(txs(['2026-07-24']), ref);
      expect(s.missedYesterday, isTrue);
      expect(
        s.message,
        contains('Nothing resets here'),
        reason:
            'A missed yesterday with an existing chain and an unlogged '
            'today is exactly the moment the comeback line exists for.',
      );
    });

    test('and stays silent when it should', () {
      // Same gap, but today IS logged: the comeback already happened, and
      // an alarm that cries wolf gets its battery taken out.
      final s = chainState(txs(['2026-07-24', '2026-07-27']), ref);
      expect(s.missedYesterday, isTrue);
      expect(s.message, isNot(contains('Nothing resets here')));
      expect(s.message, 'Two days in. One more and this becomes a real habit.');
    });

    test('seven for seven earns the full week line', () {
      final s = chainState(
        txs([for (var i = 0; i < 7; i++) '2026-07-${21 + i}']),
        ref,
      );
      expect(s.fullWeek, isTrue);
      expect(s.message, '7 for 7. The whole week, logged.');
    });

    test('zero days invites, never scolds', () {
      final s = chainState(const [], ref);
      expect(s.message, 'Log anything today to start your chain.');
      expect(s.missedYesterday, isFalse);
    });
  });

  group('on Home', () {
    Future<SalapifyStore> boot(
      WidgetTester tester,
      Map<String, dynamic> blob,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode(blob),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      return store;
    }

    Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
      ],
      'transactions': [
        {
          'id': 't1',
          'type': 'expense',
          'label': 'Groceries',
          'amount': 250,
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'accountId': 'cash',
        },
      ],
    };

    testWidgets('the chain and the treat invite render', (tester) async {
      await boot(tester, blob());
      await tester.scrollUntilVisible(
        find.text('LOGGING CHAIN'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('LOGGING CHAIN'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Earn your treats'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Earn your treats'), findsOneWidget);
    });

    testWidgets('a treat check-in from Home writes through the store', (
      tester,
    ) async {
      final b = blob();
      b['settings'] = {
        'treats': [
          {
            'id': 'tr1',
            'treat': 'Milk tea',
            'action': 'A 30 minute walk',
            'emoji': '🧋',
            'target': 3,
            'windowDays': 7,
            'checkIns': <String>[],
            'lifetime': 0,
          },
        ],
      };
      final store = await boot(tester, b);
      await tester.scrollUntilVisible(
        find.text('I did it today'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('I did it today'));
      await tester.pumpAndSettle();
      final treats =
          ((store.data['settings'] as Map)['treats'] as List).cast<Map>();
      expect(
        (treats.single['checkIns'] as List),
        hasLength(1),
        reason:
            'The Home check-in must write through the same store method the '
            'Treats screen uses.',
      );
      expect(find.text('Done for today, tap to undo'), findsOneWidget);
    });
  });

  group('the celebration', () {
    testWidgets('a settled utang celebrates with the overlay', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
          ],
          'people': [
            {'id': 'p1', 'name': 'Migs'},
          ],
          'receivables': [
            {
              'id': 'r1',
              'personId': 'p1',
              'person': 'Migs',
              'amount': 500,
              'payments': <Map<String, dynamic>>[],
              'paid': false,
            },
          ],
        }),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await goToOwedToMe(tester);
      await tester.tap(find.text('Migs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();
      // The confirm dialog.
      await tester.tap(find.text('Mark paid').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Migs paid you back in full.'),
        findsOneWidget,
        reason:
            'Settling a real balance is the happiest moment in the app, and '
            'it must celebrate, not just close a sheet.',
      );
      // The overlay dismisses itself; let its timers finish.
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Migs paid you back in full.'), findsNothing);
    });
  });
}
