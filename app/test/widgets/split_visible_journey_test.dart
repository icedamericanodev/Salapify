// A split bill, followed to where a person would look for it (D32, D34, D35).
//
// The money half lives in test/data/split_lifecycle_test.dart. This is the
// other half: can somebody FOLLOW it afterwards. After a split, the account
// falls by the whole bill while only the person's share is spending, so the
// two entries that explain that drop must both be findable in Activity, and
// must say what they are. And a friend paying back must read as money in
// from that friend, not as "Account → GCash" with no sign.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(
      find
          .descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(Column))
                .first,
            matching: find.byType(TextField),
          )
          .first,
      value,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both halves of a split, and the repayment, are in Activity '
      'saying what they are', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    final Account account = state.accounts.first;

    // Split 1,200 with Carla, the way a person does.
    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Split'),
      ),
    );
    await type(tester, 'Total bill', '1200');
    await type(tester, 'What was it', 'Samgyup');
    await type(tester, 'Add somebody', 'Carla');
    await tapIt(tester, find.bySemanticsLabel('Add this person to the split'));
    await tapIt(tester, find.text('Record it'));

    // The confirmation names both halves, so 1,200 out of the account and
    // 600 in the Food budget do not read as 600 lost.
    expect(
      find.textContaining('₱600.00 your share, ₱600.00 lent'),
      findsOneWidget,
    );

    // Activity, by tapping.
    await tapIt(tester, find.text('Activity'));
    // The lent half, leaving the account for Carla.
    expect(
      find.textContaining('${account.name} → Carla'),
      findsOneWidget,
      reason: 'the 600 that left for Carla is not explained anywhere',
    );
    // The share half, under its own name.
    expect(find.text('Samgyup'), findsWidgets);

    // Carla pays back into the same account.
    final Debt carla = state.debts.firstWhere(
      (Debt d) => d.person == 'Carla' && (d.notes ?? '').startsWith('Split:'),
    );
    state.recordDebtPayment(carla.id, 600, accountId: account.id);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Carla → ${account.name}'),
      findsOneWidget,
      reason: 'the repayment does not say who it came from',
    );
    expect(
      find.text('+${formatPeso(600)}'),
      findsWidgets,
      reason: 'a friend paying back reads as money going OUT',
    );
    expect(carla.openingTxId, isNotNull);
    expect(
      state.debts.firstWhere((Debt d) => d.id == carla.id).remaining,
      Money.zero,
    );
  });
}
