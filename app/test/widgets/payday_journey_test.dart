import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Setting a payday, by tapping, and then walking to every screen that should
/// now say something different.
///
/// A write path is not tested until somebody can SEE what it did, and this
/// write is unusual in that it has no row of its own anywhere. What it
/// changes is a DIVISOR, so the proof is that four separate screens start
/// agreeing about a figure none of them could show before.
///
/// It also closes the gap this whole feature came from: three surfaces asked
/// for a payday and none of them could accept one.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A phone somebody has actually put their own money into, with no payday.
  ///
  /// The sweep first, because the seed ships a payday and this feature is
  /// about the state where there is none. An account, because a Safe to
  /// Spend figure of zero would go on being zero whatever the divisor is,
  /// and this test is about the divisor.
  FinancialState fresh() {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 11, 9),
    );
    state.removeSampleData();
    state.addAccount(
      const Account(
        id: 'mine',
        name: 'My savings',
        kind: AccountKind.bank,
        institution: 'SeaBank',
        balance: 30000,
        monogram: 'SB',
      ),
    );
    return state;
  }

  testWidgets('the prompt on Home is the way in, and it works', (
    WidgetTester tester,
  ) async {
    final FinancialState state = fresh();
    await pump(tester, state);

    expect(
      state.payday.isSet,
      isFalse,
      reason: 'the fixture already has a payday, so this proves nothing',
    );
    expect(find.textContaining('Set your payday'), findsOneWidget);

    // THE TAP THAT DID NOT EXIST. This row said "Payday not set" under a
    // sentence asking for one, and led nowhere.
    await tester.tap(find.text('Payday not set'));
    await tester.pumpAndSettle();
    expect(find.text('When do you get paid'), findsOneWidget);

    // The founder's own second example, and the reason the days are a
    // choice: "Sometime 15th and 30th, sometimes 10th and 25th."
    //
    // It opens on 15 and 30, which is a starting point and not an answer:
    // the point of this test is that somebody paid on other days can say so.
    final Finder pickers = find.byType(DropdownButtonFormField<int>);
    expect(pickers, findsNWidgets(2));

    await tester.tap(pickers.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10th').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25th').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '20000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // 1. The store holds the RULE, not a countdown somebody typed.
    expect(state.payday.paydayDays, <int>[10, 25]);
    expect(state.payday.expectedIncome, 20000);

    // 2. And the countdown is derived from it. On 11 September the next
    //    payday under a 10th and 25th rule is the 25th, fourteen days out.
    expect(state.payday.daysToPayday, 14);
    expect(state.payday.nextPayday, 'Sep 25');

    // 3. Home stopped asking and started answering.
    expect(find.textContaining('Set your payday'), findsNothing);
    expect(find.text('14 days to payday'), findsOneWidget);
    expect(
      find.textContaining('a day until payday'),
      findsOneWidget,
      reason:
          'the per-day figure this whole feature gates is still not being '
          'shown, so nothing a person can see has changed',
    );
  });

  testWidgets('the Safe to Spend sheet agrees with Home', (
    WidgetTester tester,
  ) async {
    final FinancialState state = fresh();
    state.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);
    await pump(tester, state);

    await tester.tap(find.text('DETAILS'));
    await tester.pumpAndSettle();

    // The caption that used to read "1 days left in cutoff" on a phone with
    // no payday. It is a real cutoff now and it counts the real days.
    expect(find.text('14 days left in cutoff'), findsOneWidget);
    expect(find.text('Payday not set'), findsNothing);
  });

  testWidgets('Health Check stops asking for what it now has', (
    WidgetTester tester,
  ) async {
    final FinancialState state = fresh();
    await pump(tester, state);

    // Before: the question cannot be answered and offers the fix.
    HealthReport before = state.healthReport;
    HealthIndicator payday = before.indicators.first;
    expect(payday.id, 'payday');
    expect(
      payday.need,
      HealthNeed.setPayday,
      reason: 'the first question is not the one this test is about',
    );

    state.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);
    await tester.pumpAndSettle();

    before = state.healthReport;
    payday = before.indicators.first;
    expect(
      payday.need,
      isNot(HealthNeed.setPayday),
      reason:
          'Health Check is still asking for a payday that has just been '
          'recorded, so its offer leads to a sheet with nothing to do',
    );
  });

  testWidgets('the countdown moves on its own as the days pass', (
    WidgetTester tester,
  ) async {
    // THE WHOLE POINT OF STORING A RULE. The old cycle stored a number that
    // nothing ever touched again, so an app opened a week later still said
    // the same thing. Two states over the same rule, a week apart, must not
    // agree.
    final FinancialState monday = FinancialState(
      clock: DateTime(2026, 9, 11, 9),
    );
    monday.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);
    final FinancialState later = FinancialState(
      clock: DateTime(2026, 9, 18, 9),
    );
    later.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);

    expect(monday.payday.daysToPayday, 14);
    expect(
      later.payday.daysToPayday,
      7,
      reason:
          'a week passed and the countdown did not move, which is the defect '
          'the stored rule exists to fix',
    );
    expect(monday.payday.nextPayday, later.payday.nextPayday);
  });

  testWidgets('removing it puts every screen back to asking', (
    WidgetTester tester,
  ) async {
    final FinancialState state = fresh();
    state.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);
    await pump(tester, state);

    expect(find.text('14 days to payday'), findsOneWidget);

    await tester.tap(find.text('14 days to payday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove my payday'));
    await tester.pumpAndSettle();

    expect(state.payday.isSet, isFalse);
    expect(state.payday.paydayDays, isEmpty);
    expect(
      state.payday.expectedIncome,
      0,
      reason:
          'the expected income outlived the payday, so Safe to Spend is '
          'still counting money that nothing says is coming',
    );
    expect(find.text('Payday not set'), findsOneWidget);
  });

  testWidgets('a cycle from before this feature is left exactly alone', (
    WidgetTester tester,
  ) async {
    // The OTHER half, and the one that is easy to break by being helpful.
    // Every backup written before the editor existed, and every prototype
    // import, carries a countdown and two labels and NO rule. Guessing a
    // rule for those would quietly rewrite a stored cycle into one nobody
    // chose. The seed is exactly such a cycle, which is what makes this
    // testable at all.
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 9),
    );

    expect(
      state.payday.hasRule,
      isFalse,
      reason: 'the seed grew a rule, so this no longer tests the legacy path',
    );
    expect(
      state.payday.daysToPayday,
      4,
      reason:
          'a stored cycle with no rule was rewritten, so a restored ledger '
          'shows a payday its owner never entered',
    );
    expect(state.payday.nextPayday, 'Sep 15');
  });

  testWidgets('it survives being saved and read back', (
    WidgetTester tester,
  ) async {
    // The rule is the stored half, so a restore that dropped it would leave
    // a countdown that freezes again the moment the app restarts.
    final FinancialState state = fresh();
    state.setPaydayRule(daysOfMonth: <int>[10, 25], expectedIncome: 20000);

    final String file = state.snapshot().encode(at: state.now);
    final Snapshot back = Snapshot.decode(file);

    expect(back.payday.paydayDays, <int>[10, 25]);
    expect(back.payday.expectedIncome, 20000);
  });
}
