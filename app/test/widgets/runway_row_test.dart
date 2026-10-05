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
      contains('Sweldo'),
      reason: 'a figure with no name is a figure nobody can go and check',
    );
    // "in Coming Up and in your payday rule" was cut on 2026-10-05, and the
    // assertion that used to live here went with it. It is the SAME TWO
    // PLACES every time this line can fire, so it is a lesson rather than a
    // figure, and the lesson is behind the "i" dot. The rule it was really
    // protecting, never print a class name at a person, is now checked
    // across every notice on the card below, which is where it belongs.
    expect(text, isNot(contains('payday rule')));
  });

  testWidgets('no notice prints a class name at a person', (
    WidgetTester tester,
  ) async {
    // WIDENED FROM ONE CLAUSE TO THE WHOLE CARD. This used to be asserted
    // only inside the counted-once sentence, so it stopped being checked at
    // all the moment that clause was cut. No screen in Salapify is called
    // "Upcoming": the Home card is "Coming Up" and the sheet is "Bills".
    // `UpcomingItem` is a class name and printing one at somebody sends them
    // nowhere.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    for (final String key in <String>[
      'runway-not-counted',
      'runway-counted-once',
      'runway-counted-twice',
    ]) {
      final Finder f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) continue;
      final Text w = tester.widget<Text>(f);
      final String text = w.data ?? w.textSpan!.toPlainText();
      expect(text, isNot(contains('Upcoming')), reason: key);
      expect(text, isNot(contains('BillItem')), reason: key);
      expect(text, isNot(contains('InstallmentPlan')), reason: key);
    }
  });

  testWidgets('a notice never prints its own label twice', (
    WidgetTester tester,
  ) async {
    // THE BUG THIS MAKES UNREPRESENTABLE. `_Notice` used to strip the label
    // back off the front of the body with a `startsWith`, because every
    // helper wrote the label into its own sentence as well as the call site
    // passing it. Six producers, three consumers, nothing pairing them: one
    // stray character of punctuation and the card renders "Counted twice:
    // Counted twice: 2,450" with the whole suite green.
    //
    // The helpers return the body alone now, so this reads as a tautology.
    // It is kept because the shape it guards is one edit away from coming
    // back, and the edit that brings it back looks harmless.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    for (final (String key, String label) in <(String, String)>[
      ('runway-not-counted', 'Not counted: '),
      ('runway-counted-once', 'Counted once: '),
      ('runway-counted-twice', 'Counted twice: '),
    ]) {
      final Finder f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) continue;
      final Text w = tester.widget<Text>(f);
      final String text = w.data ?? w.textSpan!.toPlainText();
      expect(
        label.allMatches(text).length,
        1,
        reason:
            'the label appears ${label.allMatches(text).length} times '
            'in "$text"',
      );
    }
  });

  testWidgets('the notices do not open a sheet that shows half of them', (
    WidgetTester tester,
  ) async {
    // The `_Notice` doc comment claimed the notices were "DELIBERATELY NOT
    // TAPPABLE" while they sat inside the card's own InkWell, so a tap on
    // the words "Counted twice, Home Credit Installment" opened BillsSheet,
    // which reads `state.upcoming` and nothing else. The person would land
    // on a sheet showing exactly ONE of the two rows the notice had just
    // named and conclude the app was wrong. An AbsorbPointer now makes the
    // stated intent true.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    int taps = 0;

    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final Palette p = Palette.of(s.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, s.theme),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: RunwayRow(
              state: s,
              onSeeDue: () => taps++,
              onSetPayday: () {},
              onInfo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('runway-counted-twice')));
    await tester.pumpAndSettle();
    expect(taps, 0, reason: 'the notice opened the bills sheet');

    // DIRECTIONAL COMPANION. Without this the test above passes with the
    // whole card made untappable, which would be a different defect: the
    // card's own job is to open the sheet.
    await tester.tap(find.textContaining('Tightest day'));
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'the card itself stopped opening the sheet');
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

  testWidgets('an outflow in two registers is named, with what it costs', (
    WidgetTester tester,
  ) async {
    // The other side of D27, and the opposite policy. The sample ledger
    // carries this pair because the founder decided on 2026-10-04 to keep
    // it (D28): a notice with no proof case is a notice nobody has ever
    // seen fire.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await pump(tester, s);

    final Finder line = find.byKey(const Key('runway-counted-twice'));
    expect(line, findsOneWidget);

    final Text w = tester.widget<Text>(line);
    final String text = w.data ?? w.textSpan!.toPlainText();

    expect(
      text,
      contains('2,450'),
      reason:
          'the Home Credit phone plan: an Upcoming item and a Debt minimum, '
          'both placed on the same day, so the figure above took 2,450 out '
          'twice',
    );
    expect(
      text,
      contains('Home Credit'),
      reason:
          'a figure with no name sends somebody hunting through four screens '
          'for it',
    );
    expect(
      text,
      isNot(contains('Meralco')),
      reason:
          'THE REGRESSION THIS LINE EXISTS FOR. Meralco is also written '
          'twice, as a Bill dated three days ago and an Upcoming item due '
          'today, and this card said "Counted twice: 5,290, Meralco and Home '
          'Credit" for one render. It was wrong by the whole 2,840: the Bill '
          'is OVERDUE, so the engine never places it and reports it in the '
          'not-counted line instead. Written twice, counted once',
    );
    expect(
      text,
      isNot(contains('5,290')),
      reason: 'the sum of a true pair and a false one',
    );
    expect(
      text,
      isNot(contains('duplicate')),
      reason:
          'that is a claim about the person\'s intent. People genuinely do '
          'pay the same provider the same amount twice in a week',
    );
    expect(
      text.toLowerCase(),
      isNot(contains('removed')),
      reason:
          'nothing was removed. Both copies are still in the figure above, '
          'which is the whole difference from the line that says "Counted '
          'once"',
    );
  });

  testWidgets('a ledger with nothing written twice gets no such line', (
    WidgetTester tester,
  ) async {
    // The silent half, and the one that matters more. An alarm that cries
    // wolf gets its battery taken out, and then it is not there during the
    // fire.
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

    expect(find.byKey(const Key('runway-counted-twice')), findsNothing);
  });

  testWidgets('two pairs name both, and never with a places clause', (
    WidgetTester tester,
  ) async {
    // THE BRANCH NOBODY HAD EVER SEEN RENDER. The sample ledger produces
    // exactly one counted-twice pair on every day of the year, so the
    // two-name wording at `_countedTwice` was unreachable from any fixture
    // and the shot harness could not show it. Copy nobody can render is copy
    // nobody has checked.
    //
    // Two pairs, deliberately in DIFFERENT register combinations: one Bill
    // against an Upcoming item, one Upcoming item against a Debt minimum.
    // That is why this branch must not carry a shared places clause: there
    // is no single pair of places true of both.
    final FinancialState s = FinancialState(clock: DateTime.utc(2026, 9, 18));
    await s.deleteEverything();
    s.addAccount(
      const Account(
        id: 'a1',
        name: 'GCash',
        kind: AccountKind.gcash,
        institution: 'GCash',
        balance: Money.pesos(50000),
        monogram: 'GC',
      ),
    );
    // Both pairs are an Upcoming item against a Debt minimum, because the
    // store has no `addBill`. That is a weaker fixture than a Bill against
    // an Upcoming item would be, and it is said here rather than left to be
    // discovered: it reaches the two-name BRANCH, which is the point, but it
    // cannot demonstrate two pairs whose places genuinely differ.
    s.addUpcoming(
      const UpcomingItem(
        id: 'u1',
        name: 'Globe broadband plan',
        amount: Money.pesos(1899),
        dueDate: '2026-09-25',
        type: UpcomingItemType.bill,
      ),
    );
    s.addDebt(
      const Debt(
        id: 'd0',
        person: 'Globe Fiber',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(9495),
        paidAmount: Money.zero,
        isSettled: false,
        minimumPayment: Money.pesos(1899),
        dueDate: '2026-09-25',
      ),
    );
    s.addUpcoming(
      const UpcomingItem(
        id: 'u2',
        name: 'Home Credit fridge',
        amount: Money.pesos(2000),
        dueDate: '2026-09-26',
        type: UpcomingItemType.debt,
      ),
    );
    s.addDebt(
      const Debt(
        id: 'd1',
        person: 'Home Credit (Fridge)',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(12000),
        paidAmount: Money.zero,
        isSettled: false,
        minimumPayment: Money.pesos(2000),
        dueDate: '2026-09-26',
      ),
    );
    await pump(tester, s);

    final Finder line = find.byKey(const Key('runway-counted-twice'));
    expect(line, findsOneWidget);
    final Text w = tester.widget<Text>(line);
    final String text = w.data ?? w.textSpan!.toPlainText();

    expect(text, contains('Globe'), reason: 'both pairs are named');
    expect(text, contains('Home Credit'));
    expect(
      text,
      contains('3,899'),
      reason: '1,899 and 2,000, each taken out a second time',
    );
    expect(
      text,
      contains('each in two places'),
      reason:
          'the two-name branch names and does not place. Two pairs can sit '
          'in different register combinations, so one shared places clause '
          'would be wrong about one of them. This fixture cannot prove that '
          'on its own, because the store has no addBill and both pairs here '
          'are Coming Up against Debts; the branch is what is being proven '
          'reachable, and the copy is what is being read',
    );
  });
}
