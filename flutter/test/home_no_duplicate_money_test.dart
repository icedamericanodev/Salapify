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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/commitments.dart' show upcomingCommitments;
import 'package:salapify/money/cycle.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/widgets/bills_before_payday.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Cash, plus a recurring bill due before the next payday, which is what
/// creates committed money AND a bills list at the same time. That overlap is
/// the only state where the duplication can appear.
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
  'recurring': [
    {
      'id': 'r1',
      'name': 'Internet',
      'type': 'expense',
      'amount': 1699,
      'dayOfMonth': 28,
      'active': true,
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
      home: tabHost(OverviewScreen(store: store, onSwitchTab: (_) {})),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the two figures really are the same number', () {
    // The PRECONDITION. If the engine ever stops defining available as
    // liquid minus committed, there is no duplication to suppress and the
    // widget test below is guarding nothing.
    final data = _withCommittedBills();
    final now = DateTime(2026, 7, 26);
    final cycle = cycleStatus(data, now);
    final dues = upcomingCommitments(data, now);
    expect(
      cycle.liquid - cycle.available,
      closeTo((dues['total'] as num).toDouble(), 0.005),
      reason:
          'Your Number computes committed as liquid minus available, and the '
          'bills card takes it straight from upcomingCommitments. These are '
          'meant to be one value.',
    );
  });

  testWidgets('the committed figure appears exactly once on Home', (
    tester,
  ) async {
    final data = _withCommittedBills();
    final cycle = cycleStatus(data, DateTime.now());
    final dues = upcomingCommitments(data, DateTime.now());

    // Only meaningful in the state where both would render. Skip rather than
    // pass vacuously, so a fixture that stops producing the overlap is loud
    // instead of quietly green.
    if (!cycle.show || cycle.liquid <= cycle.available) {
      markTestSkipped('fixture produced no committed money on this date');
      return;
    }

    await _pump(tester, await _seed(data));
    final committed = formatMoney(cycle.liquid - cycle.available);
    expect(
      find.text(committed),
      findsOneWidget,
      reason:
          'The committed total is on screen more than once. It is the SAME '
          'number as the bills total, in the same colour, in adjacent cards, '
          'so a reader assumes they are two different things and goes looking '
          'for the difference.',
    );
    expect(find.text(formatMoney((dues['total'] as num).toDouble())),
        findsOneWidget);
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
          Builder(
            builder: (_) => ListView(
              children: [
                BillsBeforePaydayForTest.build(committedShownAbove: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₱1,699'), findsOneWidget);
  });
}

/// A fixed bills card, so the "total comes back" case does not depend on a
/// clock or on which day the suite happens to run.
class BillsBeforePaydayForTest {
  static Widget build({required bool committedShownAbove}) => BillsBeforePayday(
    bills: const [
      {
        'name': 'Internet',
        'kind': 'bill',
        'date': '2026-07-28',
        'amount': 1699.0,
      },
    ],
    total: 1699,
    format: formatMoney,
    formatDay: prettyDay,
    committedShownAbove: committedShownAbove,
  );
}
