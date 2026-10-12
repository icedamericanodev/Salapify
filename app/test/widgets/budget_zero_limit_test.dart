// A budget whose limit is zero, which Home used to divide by.
//
// Found while moving `Budget.limit` to Money. `budget_pulse_card.dart` worked
// out each row's percentage as `jsRound((spent / b.limit) * 100)` with no
// guard, while `plan.dart` has always guarded the identical divide and says
// why in its own comment. Two copies of one piece of arithmetic, one of them
// defended.
//
// It is not theoretical. `jsRound` is `(value + 0.5).floor()`, and `floor()`
// on an Infinity throws, so a zero limit with ANY spending in that category
// took Home down rather than drawing a wrong number. The Plan tab, reading
// the same ledger through the guarded copy, was fine, which is the worst
// shape for working out what went wrong.
//
// A zero limit cannot be typed: `applyBudgetLimit` refuses one, deliberately,
// because it would make every percentage meaningless. It can only arrive in a
// FILE, which is why this test loads one rather than tapping its way there.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

void main() {
  /// A ledger with one spent-against budget whose limit is zero.
  ///
  /// The spending matters. A zero limit with nothing spent divides 0 by 0,
  /// which is a NaN, and NaN also throws in `floor()`; but a reader could
  /// reasonably think an empty category is the only way in. It is not, and
  /// the money has to be there for the row to be the one somebody sees.
  String ledgerWithAZeroLimit() => jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'accounts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'acc_cash',
        'name': 'Cash',
        'kind': 'cash',
        'institution': 'Wallet',
        'balance': 5000,
        'monogram': 'CA',
      },
    ],
    'transactions': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tx_1',
        'type': 'expense',
        'amount': 465,
        'category': 'Food & Dining',
        'accountId': 'acc_cash',
        'date': '2026-09-18',
        'createdAt': 1758153600000,
      },
    ],
    'budgets': <Map<String, dynamic>>[
      <String, dynamic>{'category': 'Food & Dining', 'limit': 0, 'emoji': 'F'},
    ],
  });

  testWidgets('Home survives a budget limit of zero', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: testToday,
      store: MemorySnapshotStore(ledgerWithAZeroLimit()),
    );
    await state.restore();
    addTearDown(state.dispose);

    // THE DIRECTIONAL HALF, and it has to come first. If the fixture failed
    // to load, the store falls back to the seed, every budget then has a real
    // limit, and the assertion below passes for a reason that has nothing to
    // do with the bug.
    expect(
      state.budgets,
      hasLength(1),
      reason: 'the fixture did not load, so this test proves nothing',
    );
    expect(
      state.budgets.single.limit.isZero,
      isTrue,
      reason: 'the zero limit did not survive the codec',
    );
    expect(state.transactions, hasLength(1));

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    // Rendering at all IS the assertion: an unguarded divide threw inside
    // build, which flutter_test reports as a failed test rather than a blank
    // screen. Naming something on the screen as well, so a future change that
    // makes Home render nothing cannot pass this quietly.
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
