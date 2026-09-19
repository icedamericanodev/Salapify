import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Home, on a ledger where nobody has said when they get paid.
///
/// This is not a rare state. It is what EVERY new install looks like once the
/// sample data is cleared, and what a restored file from another phone looks
/// like if it never carried a payday.
void main() {
  Future<FinancialState> restoredEmpty() async {
    final Snapshot s = Snapshot(
      accounts: const <Account>[
        Account(
          id: 'real_1',
          name: 'My GCash',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: 50000,
          monogram: 'GC',
        ),
      ],
      transactions: const <Transaction>[],
      debts: const <Debt>[],
      budgets: const <Budget>[],
      goals: const <Goal>[],
      upcoming: const <UpcomingItem>[],
      incomeStreams: const <IncomeStream>[],
      installments: const <InstallmentPlan>[],
      reconciliations: const <ReconciliationRecord>[],
      bills: const <BillItem>[],
      payday: PaydayCycle.unset,
      theme: ThemeMode2.gabi,
      scenario: DecisionScenario.conservative,
    );
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write(s.encode(at: DateTime.utc(2026, 9, 19)));
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: store,
    );
    await state.restore();
    return state;
  }

  Future<void> pump(WidgetTester tester, FinancialState state) async {
    // The REAL fonts, not the test default. Flutter's fallback face is wider
    // than Plus Jakarta Sans, and the Debts card on Home overflows by 45px in
    // it and by nothing on the phone. A layout judged in a font the app never
    // draws is a layout judged against the wrong app.
    await tester.runAsync(loadRealFonts);
    final Palette palette = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it never offers a daily figure it cannot compute', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = await restoredEmpty();
    await pump(tester, state);

    // THE DEFECT THIS GUARDS. computeSafeToSpend divides by
    // max(1, daysToPayday), so an unset cycle makes the daily figure equal the
    // WHOLE fortnight's allowance. The card would have told somebody with
    // ₱36,125 of room that they could spend ₱36,125 a day.
    expect(
      state.safeToSpendPerDay,
      state.safeToSpend,
      reason:
          'the engine is expected to collapse these when days are unset. If '
          'this ever differs, the screen guard below is guarding nothing and '
          'should be rewritten rather than deleted.',
    );
    expect(
      find.textContaining('a day until payday'),
      findsNothing,
      reason:
          'Home is printing a per-day figure equal to the entire fortnight, '
          'which is the opposite of the advice this card exists to give',
    );
    expect(find.textContaining('Set your payday'), findsOneWidget);
  });

  testWidgets('it says the payday is unset rather than counting to nothing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, await restoredEmpty());

    expect(find.text('Payday not set'), findsOneWidget);
    expect(
      find.textContaining('0 days to payday'),
      findsNothing,
      reason: 'a countdown to a date nobody has entered',
    );
    expect(
      find.textContaining('days away'),
      findsNothing,
      reason:
          '"0 days away" beside "Payday not set yet" is a countdown to '
          'nothing',
    );
  });

  testWidgets('a ledger WITH a payday still shows the countdown', (
    WidgetTester tester,
  ) async {
    // The other half of the alarm. A guard that hid the countdown always
    // would pass both tests above and remove a real feature.
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState seeded = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, seeded);

    expect(seeded.payday.isSet, isTrue);
    expect(find.textContaining('days to payday'), findsOneWidget);
    expect(find.textContaining('a day until payday'), findsOneWidget);
    expect(find.text('Payday not set'), findsNothing);
  });
}
