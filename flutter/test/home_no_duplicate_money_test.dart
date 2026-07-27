// One peso figure, once.
//
// This guards a bug I shipped in two halves and could not see, because each
// half was correct on its own. f2.50 put a committed-versus-free bar on Your
// Number. f2.51 put the bills between now and payday underneath it, with the
// total on its header. Both were right. Together they printed the SAME NUMBER
// twice, in the same colour, in adjacent cards.
//
// It is the same number arithmetically, not merely a similar one. safeToSpend
// defines `available = liquid - committed`, where `committed` is exactly
// upcomingCommitments' total. So `s.liquid - s.available` and `dues['total']`
// are one value written two ways, and both render through formatMoney in
// Barako.warning.
//
// A reader seeing a figure twice does not think "same number". They think
// "there must be two of these", and start looking for the difference.
//
// THE CLOCK IS PINNED, and that took three failed fixtures to learn. Each try
// at making a fixture hold "on every date" through the live clock failed on a
// real calendar behaviour: a bill on day 28 let the test skip silently on most
// dates; bills spread six days apart missed a two-day semimonthly window on
// Jan 28; and a bill pinned to its payday held on the raw blob but not through
// the store, because load() posts due recurring bills and stamps lastPosted,
// which excludes them from the window. Some real dates genuinely have no
// committed money, so no fixture can hold on all of them. OverviewScreen now
// takes an injectable clock, this file passes a fixed date, and the whole
// class of calendar flakiness is gone rather than patched.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/commitments.dart' show upcomingCommitments;
import 'package:salapify/money/cycle.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bills_before_payday.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// The pinned date. A Sunday, five days before the default semimonthly payday
/// on Jul 31, with the debt's due day landing on the Tuesday in between.
final _today = DateTime(2026, 7, 26);

/// Cash plus a DEBT minimum due before payday, which is what creates committed
/// money and a bills list at once.
///
/// A debt rather than a recurring bill on purpose: store.load() posts due
/// recurring bills and stamps lastPosted, rewriting the data the widget sees.
/// Debt minimums have no posting machinery, so what this fixture declares is
/// what the screen renders.
Map<String, dynamic> _withCommittedBills() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 20000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'amount': 100,
      'date': '2026-07-01',
      'accountId': 'cash',
    },
  ],
  'debts': [
    {
      'id': 'd1',
      'name': 'Internet plan',
      'type': 'credit card',
      'remaining': 8000,
      'monthlyRate': 3,
      'minPayment': 1699,
      'dueDay': 28,
    },
  ],
};

Future<SalapifyStore> _seed(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final s = SalapifyStore();
  await s.load();
  return s;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store) async {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: tabHost(
        OverviewScreen(store: store, onSwitchTab: (_) {}, clock: () => _today),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the two figures really are the same number, through the store', () async {
    // The PRECONDITION, on the data AS THE STORE LOADS IT. An earlier version
    // proved this on the raw blob while the widget saw store-rewritten data,
    // which is how a precondition test and the test it protects diverge.
    final store = await _seed(_withCommittedBills());
    final cycle = cycleStatus(store.data, _today);
    final dues = upcomingCommitments(store.data, _today);
    expect(cycle.show, isTrue);
    expect(
      cycle.liquid - cycle.available,
      closeTo((dues['total'] as num).toDouble(), 0.005),
      reason:
          'Your Number computes committed as liquid minus available, and the '
          'bills card takes it straight from upcomingCommitments. These are '
          'meant to be one value.',
    );
    expect(
      cycle.liquid - cycle.available,
      greaterThan(0),
      reason:
          'The fixture must produce committed money on the pinned date, or '
          'the widget test below renders neither the bar nor the bills card '
          'and asserts nothing.',
    );
  });

  testWidgets('the committed figure appears exactly once on Home', (
    tester,
  ) async {
    final store = await _seed(_withCommittedBills());
    final cycle = cycleStatus(store.data, _today);
    await _pump(tester, store);

    final committed = formatMoney(cycle.liquid - cycle.available);
    // Both cards are on screen, and the figure appears in exactly one of them.
    expect(find.text('BILLS BEFORE PAYDAY'), findsOneWidget);
    expect(find.text('Committed'), findsOneWidget);
    expect(
      find.text(committed),
      findsOneWidget,
      reason:
          'The committed total is on screen more than once. It is the SAME '
          'number as the bills total, in the same colour, in adjacent cards, '
          'so a reader assumes they are two different things and goes looking '
          'for the difference.',
    );
  });

  testWidgets('and comes back when the bar is not there to show it', (
    tester,
  ) async {
    // The other half, and the one that keeps this honest. Suppressing the
    // total unconditionally would be a worse bug than printing it twice: in
    // crunch, Your Number is hidden entirely, so the bills header is the ONLY
    // place the committed figure appears.
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: tabHost(
          ListView(
            children: [
              BillsBeforePayday(
                bills: const [
                  {
                    'name': 'Internet plan',
                    'kind': 'minimum',
                    'date': '2026-07-28',
                    'amount': 1699.0,
                  },
                ],
                total: 1699,
                format: formatMoney,
                formatDay: prettyDay,
                committedShownAbove: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₱1,699'), findsOneWidget);
  });
}
