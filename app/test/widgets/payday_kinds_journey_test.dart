// Setting a weekly payday, then "no fixed payday", by tapping (D37).
//
// The engine and store halves are test/core/money/payday_kinds_test.dart and
// test/data/payday_kinds_state_test.dart. This is the half a person sees:
// the editor opens from Home, each choice saves, and Home then says the
// right thing about it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/payday_schedule.dart';
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

  testWidgets('weekly, then no fixed payday, from Home', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // 2026-09-18 is a Friday. The example payday is the 15th and 30th.
    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('12 days to payday'), findsOneWidget);

    // Every Friday. Today is a Friday, so the next one is a week away.
    await tapIt(tester, find.text('12 days to payday'));
    await tapIt(tester, find.byKey(const Key('payday-choice-weekly')));
    await tapIt(tester, find.text('Fri'));
    await tapIt(tester, find.text('Save'));

    expect(state.paydaySchedule!.kind, PaydayKind.weekly);
    expect(find.text('7 days to payday'), findsOneWidget);

    // No fixed payday: the editor offers a week from today, and Home counts
    // down to it as "days to go", not "to payday".
    await tapIt(tester, find.text('7 days to payday'));
    await tapIt(tester, find.byKey(const Key('payday-choice-none')));
    expect(
      find.text('Take-home pay each payday (optional)'),
      findsNothing,
      reason: 'no payday, so no amount each payday to give',
    );
    await tapIt(tester, find.text('Save'));

    expect(state.paydaySchedule!.kind, PaydayKind.lastUntil);
    expect(find.text('7 days to go'), findsOneWidget);
    expect(find.textContaining('a day until Sep 25'), findsOneWidget);
  });

  testWidgets('money logged after a "last until" date passes opens the '
      'person\'s own editor, not the 15th-and-30th question', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 21));
    await state.restore();
    state.startWithExampleData();
    // Not the first real entry, which opens the reminder offer instead.
    state.logTransaction(
      const Transaction(
        id: 'tx_before',
        type: TransactionType.expense,
        amount: Money.pesos(90),
        category: 'Food & Dining',
        accountId: 'acc_cash',
        date: '2026-09-20',
        createdAt: 1,
      ),
    );
    state.setPaydayRule(lastUntil: DateTime(2026, 9, 20));
    expect(state.paydayDatePassed, isTrue);
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    await tapIt(
      tester,
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Log'),
      ),
    );
    await tapIt(tester, find.text('Received'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '8000',
    );
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Save entry'));

    expect(
      find.textContaining('Most are paid on the 15th'),
      findsNothing,
      reason: 'offered somebody else\'s payday in place of theirs',
    );
    expect(find.text('When do you get paid'), findsOneWidget);
    // Their own choice, still selected.
    expect(state.paydaySchedule!.kind, PaydayKind.lastUntil);
  });
}
