// The Sweldo Runway row on Home, state by state.
//
// Six states, first match wins, and the one most likely to be wrong is S4
// against S5. The sample ledger can only exercise one of them at a time, so
// each is driven from a ledger built for it rather than from the seed.
//
// WHY THE DISCRIMINATOR EXISTS AT ALL. `tightestDay` uses a strict less-than,
// so it returns the EARLIEST day at the minimum. On a ledger with no income
// after its last outflow the balance only falls and then sits flat, so the
// "tightest day" is simply the last day anything was scheduled and the
// sentence "you still have X then" means "at the end of your projection you
// have X" with a date stapled to it. That is every person who has not stored
// a payday rule.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/runway_row.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    // Real fonts, because this row MEASURES: the lead sentence wraps and the
    // not-counted line has no maxLines. Flutter's default test font is wider
    // than the face the app ships, so a layout judged without it is a
    // judgement about a font the phone never draws.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: RunwayRow(
              state: state,
              onSeeDue: () {},
              onSetPayday: () {},
              onInfo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The seed, with every spendable account set to [cash].
  FinancialState ledger({required int cash}) {
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    for (final Account a
        in s.accounts.where((Account a) => a.isSpendable).toList()) {
      s.updateAccount(a.copyWith(balance: Money.pesos(cash)));
    }
    return s;
  }

  testWidgets('S4: a real trough names the day and says it climbs back', (
    WidgetTester tester,
  ) async {
    // The sample ledger reaches this state only since founder decision D26
    // gave it a payday rule: the balance dips before the 30th and recovers on
    // it. Before D26 there was no income after the last outflow at all, and
    // this sentence was the fake insight described at the top of this file.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    expect(find.textContaining('Tightest day'), findsOneWidget);
    expect(
      find.textContaining('climbs back after'),
      findsOneWidget,
      reason:
          'without this clause the sentence is true of a flat line too, which '
          'is the state it must not be confused with',
    );
  });

  testWidgets('S5: a line that only falls says so, and names the window end', (
    WidgetTester tester,
  ) async {
    // The discriminator, from the other side. Clearing the payday rule
    // removes every recovery, so the balance declines to the end of the
    // window and the tightest day becomes the last scheduled day.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    s.setPaydayRule(daysOfMonth: const <int>[]);
    await pump(tester, s);

    expect(find.textContaining('Nothing dated runs you short'), findsOneWidget);
    expect(
      find.textContaining('that is the lowest it gets'),
      findsOneWidget,
      reason: 'the claim is about the whole window, so it says so',
    );
    expect(
      find.textContaining('climbs back'),
      findsNothing,
      reason: 'nothing climbs back on a line that only falls',
    );
  });

  testWidgets('S2: already short today leads with today, not a date', (
    WidgetTester tester,
  ) async {
    await pump(tester, ledger(cash: 500));
    expect(find.textContaining('Short today'), findsOneWidget);
    expect(
      find.textContaining('more than your spendable cash'),
      findsOneWidget,
    );
  });

  testWidgets('S1: nothing dated is an invitation, not an alarm', (
    WidgetTester tester,
  ) async {
    // Somebody who wiped the examples and entered one account: real money,
    // nothing on a calendar yet. That is a very ordinary second session.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await s.deleteEverything();
    s.addAccount(
      const Account(
        id: 'a1',
        name: 'GCash',
        kind: AccountKind.gcash,
        institution: 'GCash',
        balance: Money.pesos(12000),
        monogram: 'GC',
      ),
    );
    await pump(tester, s);

    expect(find.textContaining('Nothing is dated yet'), findsOneWidget);
    expect(
      find.textContaining('Put a due date on a bill'),
      findsOneWidget,
      reason: 'a blank state that does not say what to do next is a dead end',
    );
  });

  testWidgets('the not-counted line names what is excluded, with no total', (
    WidgetTester tester,
  ) async {
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    final Finder line = find.byKey(const Key('runway-not-counted'));
    expect(line, findsOneWidget);

    final String text = tester.widget<Text>(line).data!;
    expect(
      text,
      contains('10,487.80'),
      reason:
          'the real overdue OUTFLOW. It read 42,987.80 for a day, of which '
          '32,500 was a salary already received, because the bucket was '
          'filled before direction was checked',
    );
    expect(
      text,
      isNot(contains('42,987')),
      reason: 'an overdue salary is not money leaving the account',
    );
    expect(
      text,
      isNot(contains('10,726')),
      reason:
          'no total is printed. Each figure comes straight off the engine, '
          'because a screen that adds money is a screen doing arithmetic',
    );
  });

  testWidgets('a brand new install gets NO row at all', (
    WidgetTester tester,
  ) async {
    // S0. The two doors this row could offer are already open directly above
    // it on Home, so a third ask is a nag.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await s.deleteEverything();
    await pump(tester, s);

    expect(find.textContaining('NEXT 45 DAYS'), findsNothing);
  });
}
