import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The "days left in cutoff" caption, and the divisor it used to print.
///
/// `SafeToSpendAnalysis.daysToPayday` is `max(1, payday.daysToPayday)`. That
/// clamp exists so the per-day figure cannot divide by zero, and it is
/// correct arithmetic and wrong English: on a phone with no payday set the
/// sheet printed "1 days left in cutoff", which invented a cutoff nobody had
/// entered AND disagreed with the hero card directly above it, which says
/// "Payday not set".
///
/// Two separate faults in one short string, so three states are pinned here:
/// no payday at all, a real cutoff of more than one day, and the genuine
/// one-day case, which is the only day the plural is ever visible.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: SafeToSpendSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no payday set claims no cutoff', (WidgetTester tester) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.removeSampleData();

    expect(
      state.payday.isSet,
      isFalse,
      reason: 'the fixture has a payday, so this proves nothing',
    );
    expect(
      state.safeToSpendAnalysis.daysToPayday,
      1,
      reason:
          'the engine stopped clamping to 1, so the string this test is '
          'about can no longer be produced',
    );

    await pump(tester, state);

    expect(
      find.textContaining('left in cutoff'),
      findsNothing,
      reason:
          'the sheet is naming a cutoff built from a divide-by-zero guard, '
          'directly under a card that says the payday is not set',
    );
    expect(find.text('Payday not set'), findsOneWidget);
  });

  testWidgets('a real cutoff is stated, and reads as English', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await pump(tester, state);

    expect(
      state.payday.daysToPayday,
      4,
      reason: 'the fixture cutoff moved, so the literal below is stale',
    );
    expect(find.text('4 days left in cutoff'), findsOneWidget);
  });

  testWidgets('the last day before payday says one day, not 1 days', (
    WidgetTester tester,
  ) async {
    // The only day the plural is ever wrong, and therefore the only day
    // anybody would ever catch it by looking.
    // Through the STORE, because nothing in the app can set a payday: see
    // the note in the commit. A saved ledger carrying a one day cutoff is
    // the only way this state is reachable at all today, and it arrives
    // through the same decoder a real restore uses.
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
      store: MemorySnapshotStore(oneDayCutoffFile),
    );
    await state.restore();

    expect(
      state.payday.isSet,
      isTrue,
      reason: 'a one day cutoff read as unset, so this hits the other branch',
    );

    await pump(tester, state);

    expect(find.text('1 day left in cutoff'), findsOneWidget);
    expect(
      find.text('1 days left in cutoff'),
      findsNothing,
      reason: 'the plural disagrees on the one day it is ever visible',
    );
  });
}

/// A saved ledger whose cutoff is tomorrow.
///
/// One day is the only value at which the plural is ever visible, so it is
/// the only value worth a fixture. Written as a FILE rather than by poking
/// the state, both because that is how a real ledger arrives and because
/// there is currently no other way in: nothing in the app writes a payday.
const String oneDayCutoffFile = '''
{
  "schemaVersion": 1,
  "accounts": [],
  "transactions": [],
  "debts": [],
  "budgets": [],
  "goals": [],
  "upcoming": [],
  "incomeStreams": [],
  "installments": [],
  "reconciliations": [],
  "payday": {
    "cycleType": "15_30",
    "lastPayday": "2026-09-15",
    "nextPayday": "2026-09-19",
    "daysToPayday": 1,
    "expectedIncome": 30000
  }
}
''';
