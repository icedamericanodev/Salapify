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
    // The discriminator, from the other side: a ledger with NO income at all,
    // so the balance declines to the end of the window and the tightest day
    // becomes the last scheduled day.
    //
    // Built from an empty store rather than by clearing the seed's payday
    // rule, which is how this fixture used to work and stopped working on
    // 2026-10-04. The seed's sweldo moved from a past date to the 15th so the
    // "counted once" notice could fire, and a recorded income item arrives
    // whether or not a payday RULE exists. Clearing the rule no longer
    // removes the recovery, so the old fixture was quietly testing S4 while
    // claiming to test S5.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await s.deleteEverything();
    s.addAccount(
      const Account(
        id: 'a1',
        name: 'GCash',
        kind: AccountKind.gcash,
        institution: 'GCash',
        balance: Money.pesos(20000),
        monogram: 'GC',
      ),
    );
    s.addUpcoming(
      UpcomingItem(
        id: 'u1',
        name: 'Rent',
        amount: const Money.pesos(5000),
        dueDate: '2026-09-30',
        type: UpcomingItemType.rent,
      ),
    );
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

    // The notice is a Text.rich now, so `data` is null and the words live in
    // the span. Reading the span is also closer to what the phone draws.
    final Text w = tester.widget<Text>(line);
    final String text = w.data ?? w.textSpan!.toPlainText();
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

  testWidgets('a sweldo written down twice is named, with its amount', (
    WidgetTester tester,
  ) async {
    // D27's other half. The sentence used to carry NO peso figure at all,
    // which is the one thing it needed: somebody genuinely paid the same
    // amount twice in a month is hunting for a missing number, and this is
    // the only line standing between them and silence.
    //
    // The sample ledger reaches this state since the founder moved the
    // sweldo to the 15th on 2026-10-04. Before that it was dated three days
    // in the past on every clock, so it sat in the overdue-income bucket and
    // the dedupe could never see it: swept across a full year, the notice
    // fired on none of 365 days.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    final Finder line = find.byKey(const Key('runway-counted-once'));
    expect(line, findsOneWidget);

    final Text w = tester.widget<Text>(line);
    final String text = w.data ?? w.textSpan!.toPlainText();

    expect(
      text,
      contains('₱'),
      reason: 'the figure is the whole point of this line',
    );
    expect(
      text,
      contains('Coming Up'),
      reason:
          'no screen in Salapify is called "Upcoming". UpcomingItem is a '
          'class name, and printing a class name at somebody sends them '
          'nowhere',
    );
    expect(text, isNot(contains('in Upcoming')));
    expect(text, contains('payday rule'));
  });

  testWidgets('one sweldo arriving twice is never named twice', (
    WidgetTester tester,
  ) async {
    // A SEPARATE CLOCK, and that is the finding rather than a detail. At
    // 18 September only ONE of the sweldo occurrences falls inside the
    // forty-five day window, so there is nothing to de-duplicate and an
    // assertion about it passes with the de-duplication deleted. Proven by
    // deleting it. From 4 October the window reaches past two fifteenths,
    // which is the only shape that reaches this branch.
    //
    // A day-of-month income date RECURS, so one sweldo written down twice
    // produces two suppressed occurrences carrying the SAME name, and the
    // two-item wording would otherwise read "Sweldo and Sweldo".
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 10, 4));
    await pump(tester, s);

    final Text w = tester.widget<Text>(
      find.byKey(const Key('runway-counted-once')),
    );
    final String text = w.data ?? w.textSpan!.toPlainText();

    // AT MOST once. Zero is the correct answer here and is what the code
    // does: with one name arriving twice the copy drops the list entirely and
    // leans on the figure and the count, because naming it would repeat it.
    expect(
      'Sweldo'.allMatches(text).length,
      lessThanOrEqualTo(1),
      reason: 'the same name was printed twice',
    );
    expect(
      text,
      contains('2 items'),
      reason:
          'with one name arriving twice the copy leans on the count, because '
          'listing it would repeat the name',
    );
  });
}
