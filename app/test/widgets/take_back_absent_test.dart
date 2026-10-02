import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// Three states, and the middle one is why this file exists.
///
/// ## What silence cost
///
/// "Take back the last payment" is ABSENT when there is nothing to take back,
/// which is correct: a dead control on a money screen reads as a broken app.
/// But absence cannot be told apart from a broken screen either, and that is
/// not theoretical. The founder restarted their emulator, saw no button where
/// one had been, concluded the feature was broken, and REINSTALLED THE APP.
/// Their test data went with it, and so did the evidence that would have said
/// which of the two it was.
///
/// So a debt that shows money paid and carries no record of it now says so.
/// Only that case: a debt with nothing paid has nothing surprising to explain,
/// and a line on every card is the clutter that makes people stop reading the
/// one that matters.
///
/// The three states, pinned here because the middle one is invisible to any
/// test that only checks the button:
///
///  1. Nothing paid          -> no button, no line
///  2. Paid, no record       -> no button, A LINE
///  3. Paid, with a record   -> the button
Debt _debt({
  required Money paid,
  List<DebtPayment> register = const <DebtPayment>[],
}) => Debt(
  id: 'd1',
  person: 'Home Credit',
  direction: DebtDirection.iOwe,
  totalAmount: const Money.pesos(14700),
  paidAmount: paid,
  isSettled: false,
  payments: register,
);

/// Built through the REAL load path, from a file holding exactly this debt.
///
/// No test-only setter was added to the store to make this convenient. A seam
/// that exists only for tests is a second way into the state that nothing else
/// uses, and the thing being checked here is what a person sees after the app
/// has loaded their file, which is precisely the path a setter would skip.
Future<void> _pump(WidgetTester tester, Debt d) async {
  final MemorySnapshotStore store = MemorySnapshotStore(
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'accounts': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'acc_gcash',
          'name': 'GCash Wallet',
          'kind': 'gcash',
          'institution': 'GCash',
          'balance': 8420.50,
          'monogram': 'GC',
        },
      ],
      'transactions': <Map<String, dynamic>>[],
      'debts': <Map<String, dynamic>>[debtToJson(d)],
    }),
  );

  final FinancialState state = FinancialState(clock: testToday, store: store);
  await state.restore();
  addTearDown(state.dispose);

  expect(
    state.debts.single.id,
    'd1',
    reason:
        'the fixture did not load, so every assertion below is about an '
        'empty screen rather than about this debt',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DebtScreen(state: state)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const String line = 'Salapify has no record of the payments on this debt';

  testWidgets('nothing paid: no button and NO line', (
    WidgetTester tester,
  ) async {
    // The directional half for the line itself. A line on every card is the
    // clutter that makes the one that matters invisible.
    await _pump(tester, _debt(paid: Money.zero));

    expect(find.text('Take back the last payment'), findsNothing);
    expect(
      find.textContaining(line),
      findsNothing,
      reason:
          'a debt nobody has paid is explaining something that needs no '
          'explaining, on every card',
    );
  });

  testWidgets('paid with NO record: no button, but it SAYS so', (
    WidgetTester tester,
  ) async {
    // Every debt from a restored backup, and every payment made before the
    // register existed. This is the state that cost the founder their data.
    await _pump(tester, _debt(paid: const Money.pesos(7350)));

    expect(find.text('Take back the last payment'), findsNothing);
    expect(
      find.textContaining(line),
      findsOneWidget,
      reason:
          'the screen is silent about why the control is missing, so there is '
          'no way to tell "nothing to take back" from "this is broken"',
    );
  });

  testWidgets('paid WITH a record: the button, and no line', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _debt(
        paid: const Money.pesos(8850),
        register: <DebtPayment>[
          const DebtPayment(
            id: 'dp_1',
            date: '2026-10-02',
            amount: Money.pesos(1500),
            paidBefore: Money.pesos(7350),
            settledBefore: false,
          ),
        ],
      ),
    );

    expect(find.text('Take back the last payment'), findsOneWidget);
    expect(
      find.textContaining(line),
      findsNothing,
      reason:
          'the button and the line are both shown, which contradicts '
          'itself on the same card',
    );
  });
}
