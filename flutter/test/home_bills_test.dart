// The two questions Home could not answer, and the gap that hid one of them.
//
// "You can spend X a day" and "some of it is committed" both invite the same
// follow-up: committed to WHAT, and how long do I have to hold out. The app
// knew both answers and said neither.
//
// The countdown one is the interesting bug, because it was INVISIBLE. daysLeft
// lived only inside Your Number, and Your Number hides whenever there is
// nothing positive left to spend. So the answer to "how many days until I get
// paid" disappeared exactly when money was tight, which is the one time
// anybody asks it. Nothing looked broken: the screen rendered, the coach still
// spoke, and a missing card is indistinguishable from a card with nothing to
// say.
//
// These tests are deliberately CLOCK FREE. OverviewScreen reads DateTime.now()
// internally, so a test that needs a bill to fall inside the payday window
// passes or fails depending on the day it runs, which is worse than no test:
// it goes green for two weeks and then blames whoever pushed on the 28th. The
// widget is exercised directly with fixed rows, and the screen is exercised
// only on states that hold on every date.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:salapify/data/store.dart';
import 'package:salapify/money/cycle.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bills_before_payday.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _seed(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  return store;
}

/// Cash and nothing else. No debts and no recurring bills, so no bill can
/// fall inside the payday window on any date, which is what keeps these
/// clock free. [cash] alone decides whether Your Number has something to say.
Map<String, dynamic> _cashOnly(double cash) => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': cash},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'amount': 10,
      'date': '2026-07-20',
      'accountId': 'cash',
    },
  ],
};

Future<void> _pumpHome(WidgetTester tester, SalapifyStore store) async {
  // Tall viewport so the whole lazy ListView builds. Same pattern as
  // log_entry_test: scrolling to find a card that was never built reports
  // "not found" for the wrong reason.
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: OverviewScreen(store: store, onSwitchTab: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the bills card names them', () {
    testWidgets('each bill shows its name, its day, and its amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(
            body: BillsBeforePayday(
              bills: const [
                {
                  'name': 'BPI',
                  'kind': 'minimum',
                  'date': '2026-07-27',
                  'amount': 250.0,
                },
                {
                  'name': 'Internet',
                  'kind': 'bill',
                  'date': '2026-07-29',
                  'amount': 1699.0,
                },
              ],
              total: 1949,
              format: formatMoney,
              formatDay: prettyDay,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BPI'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('- ₱250'), findsOneWidget);
      expect(find.text('- ₱1,699'), findsOneWidget);
      // The total rides on the section header, which is why SectionHeader
      // grew a trailing slot.
      expect(find.text('₱1,949'), findsOneWidget);
    });

    testWidgets('a card minimum says so, because it is a weaker promise', (
      tester,
    ) async {
      // Paying a minimum dodges the late fee but not the interest. A row that
      // hides the distinction quietly overstates how covered the user is.
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(
            body: BillsBeforePayday(
              bills: const [
                {
                  'name': 'BPI',
                  'kind': 'minimum',
                  'date': '2026-07-27',
                  'amount': 250.0,
                },
              ],
              total: 250,
              format: formatMoney,
              formatDay: prettyDay,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('minimum · Jul 27'), findsOneWidget);
    });

    testWidgets('a junk date renders unchanged rather than throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(
            body: BillsBeforePayday(
              bills: const [
                {'name': 'Odd', 'kind': 'bill', 'date': 'nope', 'amount': 1.0},
              ],
              total: 1,
              format: formatMoney,
              formatDay: prettyDay,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the countdown survives a tight month', () {
    test('Your Number really does go silent when there is nothing spare', () {
      // The PRECONDITION for the bug. If this ever stops being true, the
      // widget test below is guarding a gap that no longer exists and would
      // pass for the wrong reason.
      final s = cycleStatus(_cashOnly(0), DateTime(2026, 7, 26));
      expect(
        s.show,
        isFalse,
        reason:
            'With nothing spendable there is no positive number to show, so '
            'Your Number hides. That is the state where the countdown used to '
            'disappear along with it.',
      );
    });

    testWidgets('the days card appears exactly when Your Number does not', (
      tester,
    ) async {
      await _pumpHome(tester, await _seed(_cashOnly(0)));
      expect(
        find.text('DAYS TO PAYDAY'),
        findsOneWidget,
        reason:
            'Money is tight, Your Number is silent, and the countdown went '
            'with it. Nothing on the screen looks broken, which is exactly '
            'why this needs a test rather than an eye.',
      );
    });

    testWidgets('and stays away when Your Number is already counting', (
      tester,
    ) async {
      // The other half, and the one that keeps this honest. Two countdowns on
      // one screen is worse than none, because the reader has to work out
      // whether they agree.
      await _pumpHome(tester, await _seed(_cashOnly(50000)));
      expect(find.text('YOUR NUMBER'), findsOneWidget);
      expect(
        find.text('DAYS TO PAYDAY'),
        findsNothing,
        reason:
            'Your Number already says how many days are left, so a second '
            'countdown card is duplication.',
      );
    });
  });
}
