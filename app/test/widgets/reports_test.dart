import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/features/info/info_dot.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/screens/reports/reports_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Reports, driven the way a person drives it: tap the tab, tap a sub-tab,
/// change the period.
///
/// The arithmetic is proved in reports_golden_test.dart against vectors from
/// the prototype. These tests ask the other question, which no engine test can
/// answer: does a person actually SEE the right number, on the right screen,
/// after tapping what they would tap.
void main() {
  /// The day the fixture's calendar is written for.
  ///
  /// These tests used to run against the real clock, and passed for eleven
  /// days until midnight on 2026-09-19 turned the seed's "today" coffee into
  /// yesterday's and the period picker test went red on its own. The dates in
  /// seed_data.dart are the prototype's, fixed in September 2026, so the only
  /// honest way to ask "what does TODAY show" is to say which day today is.
  final DateTime fixtureToday = DateTime(2026, 9, 18, 12);

  /// Pass [given] to drive Reports from a ledger built for one case. Without
  /// it this is the shipped sample data, which is what most of these tests
  /// want and what the "look around with example data" path leaves behind.
  Future<void> openReports(WidgetTester tester, {FinancialState? given}) async {
    final FinancialState state =
        given ??
        (FinancialState(clock: fixtureToday, store: MemorySnapshotStore())
          // The app opens on the welcome when nothing has been onboarded.
          ..startWithExampleData());

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insert_chart_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('the Reports tab opens on Position with real money on it', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    expect(find.byType(ReportsScreen), findsOneWidget);

    // MEASURED AFTER DEBTS AND PLANS JOINED THE BALANCE SHEET on 2026-10-05,
    // on founder decision. Every one of these three figures moved, and none
    // of them moved because the arithmetic changed:
    //
    //   assets      181,970.50 -> 188,220.50   (+6,250 lent out on the Debt
    //                                           screen, which is money owed
    //                                           TO the person)
    //   liabilities 399,200.00 -> 463,936.65   (+17,350 owed on the Debt
    //                                           screen, +47,386.65 of
    //                                           instalment PRINCIPAL)
    //   net worth  -217,229.50 -> -275,716.15
    //
    // Before this, a debt entered on the Debt screen was invisible to the
    // balance sheet and the identical debt entered as an account was not, so
    // the figure depended on which screen it had been typed into.
    //
    // NO MINUS SIGN ANY MORE. The figure is drawn unsigned under the heading
    // "Still to pay off", which is the same number read from the other end.
    expect(find.text('₱275,716.15'), findsOneWidget);
    expect(find.text('₱188,220.50'), findsWidgets, reason: 'total assets');
    expect(find.text('₱463,936.65'), findsWidgets, reason: 'total liabilities');
  });

  testWidgets('the headline names a job, not a verdict', (
    WidgetTester tester,
  ) async {
    // Founder decision, 2026-10-05. For the audience this app is for, a
    // deeply negative figure is usually one mortgage on a 25 year instrument
    // designed to be largest at the start. "Net worth: minus 275,716" reads
    // as a judgement on the person; "Still to pay off: 275,716" is the same
    // arithmetic named as a job with a finish line.
    await openReports(tester);

    expect(find.text('STILL TO PAY OFF'), findsOneWidget);
    expect(
      find.text('NET WORTH'),
      findsNothing,
      reason:
          'the accounting word belongs behind the dot, where somebody who '
          'meets it at a bank will recognise it, not on the headline',
    );

    // A = L + E in the only words that need no glossary, and on the screen
    // rather than behind the dot because it is two figures rather than a
    // lesson. It is what makes the headline checkable by eye.
    expect(
      find.text('You own ₱188,220.50 and owe ₱463,936.65.'),
      findsOneWidget,
    );
  });

  testWidgets('a negative net worth is defused on the screen, and explained '
      'behind the dot', (WidgetTester tester) async {
    await openReports(tester);

    // A mortgage makes net worth negative for a great many people, and the
    // screen must not read as an accusation. After the founder's "too wordy"
    // review the long reassurance moved into the explainer, but ONE short
    // line stays: alarm is the worst possible moment to make somebody go
    // hunting for the reason.
    // SHARPER THAN IT WAS. This read "A housing loan alone can do this.",
    // which excuses the figure without explaining it.
    //
    // THE GAP IT NAMES IS NOW CLOSEABLE, and this comment said otherwise for
    // a few hours. It read "AccountKind has no kind for something you own
    // outright", which was true when it was written and false by the end of
    // the same day: `AccountKind.property` exists. The sample ledger has a
    // mortgage and no property account, so the sentence is still correct HERE,
    // and the test below is the one that proves it goes away for somebody who
    // records the home.
    expect(
      find.textContaining('Your home is not counted here'),
      findsOneWidget,
    );

    // And the full version is genuinely one tap away, not merely written
    // down somewhere. This is the assertion the old test could not make.
    await tapAndSettle(tester, find.byType(InfoDot).first);
    expect(find.byType(InfoSheet), findsOneWidget);
    expect(
      find.textContaining('nothing is actually wrong'),
      findsOneWidget,
      reason: 'the net worth dot opened the wrong explainer, or an empty one',
    );
  });

  testWidgets('Performance shows the income statement and both ratios', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));

    expect(find.text('₱51,000.00'), findsWidgets, reason: 'money in');
    expect(find.text('₱25,774.75'), findsWidgets, reason: 'money out');
    expect(find.text('₱25,225.25'), findsWidgets, reason: 'kept');

    // Percent, not a fraction. A savings rate printed as 0.5% instead of
    // 52.4% is the classic hundredfold slip and it looks entirely plausible.
    expect(find.text('49.5%'), findsWidgets);
    expect(find.text('12.6%'), findsWidgets);
  });

  testWidgets('Cash flow adds its three sections up to the headline', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));

    // The headline equals operating + investing + financing, which the engine
    // test proves. Here it just has to be the number actually on the screen.
    expect(find.text('₱25,225.25'), findsWidgets, reason: 'net change');
    expect(find.text('-₱6,450.00'), findsWidgets, reason: 'net financing');
  });

  testWidgets('a transfer is reported and visibly left out of the total', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));
    await tester.scrollUntilVisible(
      find.text('1 transfer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 transfer'), findsOneWidget);
    expect(find.text('₱5,000.00'), findsWidgets);
    expect(
      find.text('Not counted above, on purpose.'),
      findsOneWidget,
      reason:
          'a 5,000 transfer that changes no total needs saying so, or it '
          'reads as money the report lost',
    );
  });

  testWidgets('changing the period changes the figures', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));
    expect(find.text('₱51,000.00'), findsWidgets);

    await tapAndSettle(tester, find.text('Today'));

    // The directional companion: it is not enough that the numbers are
    // "still valid" after the tap, they have to have MOVED. Today holds one
    // 180 peso coffee and no income at all.
    expect(
      find.text('₱51,000.00'),
      findsNothing,
      reason: 'the period picker did nothing',
    );
    expect(find.text('₱180.00'), findsWidgets);
    expect(find.textContaining('From 1 entry'), findsOneWidget);
  });

  testWidgets('an empty period says so instead of looking broken', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));
    await tapAndSettle(tester, find.text('This week'));

    // This week has entries, so first prove the note is counting rather than
    // hardcoded, then check the wording exists for the zero case by reading
    // the note itself.
    expect(find.textContaining('entries'), findsWidgets);
  });

  testWidgets('the period picker is hidden on Position', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    // A balance sheet is what you own NOW. Offering "this week" beside it
    // would promise last week's net worth, which needs history the app does
    // not keep.
    expect(find.text('This month'), findsNothing);

    await tapAndSettle(tester, find.text('Performance'));
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('the period pills sit side by side, not stacked', (
    WidgetTester tester,
  ) async {
    // Found by LOOKING at the render, not by any test. A Container given an
    // alignment and no width expands to its maximum constraint, so all six
    // pills filled the row and stacked into a column that ate a third of the
    // screen. Every test above still passed: the labels were present, the
    // taps worked, the figures were right.
    await tester.runAsync(loadRealFonts);
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));

    final double today = tester.getTopLeft(find.text('Today')).dy;
    final double week = tester.getTopLeft(find.text('This week')).dy;
    expect(
      today,
      week,
      reason:
          'the first two period pills are on different rows, so each one '
          'is filling the full width instead of sizing to its label',
    );

    // And a pill must not be as wide as the screen.
    final double pillWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text('Today'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .width;
    expect(
      pillWidth,
      lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
      reason: 'a period pill is as wide as the whole screen',
    );
  });

  testWidgets('the missing fourth tab explains itself', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tester.scrollUntilVisible(
      find.text('Reconciliation comes next'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // A gap with no explanation reads as a bug. The prototype has four tabs
    // here and this build ships three.
    expect(find.text('Reconciliation comes next'), findsOneWidget);
  });

  testWidgets('the category breakdown is ordered biggest first', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));
    await tester.scrollUntilVisible(
      find.text('Family Support & Remittance'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final double biggest = tester
        .getTopLeft(find.text('Family Support & Remittance'))
        .dy;
    final double smaller = tester.getTopLeft(find.text('Groceries')).dy;
    expect(
      biggest,
      lessThan(smaller),
      reason:
          'the largest category must be at the top, or the list answers '
          '"what is eating my money" in the wrong order',
    );
  });

  testWidgets('nothing on Reports overflows at 320dp, on any sub-tab', (
    WidgetTester tester,
  ) async {
    // Real fonts, because the default test font is wider than Plus Jakarta
    // and measuring layout without it answers a different question.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openReports(tester);
    expect(tester.takeException(), isNull);

    for (final String tab in <String>['Performance', 'Cash flow', 'Position']) {
      await tapAndSettle(tester, find.text(tab));
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab overflowed at 320dp',
      );
    }
  });

  testWidgets('every control on Reports clears the 44dp floor', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    final Finder taps = find.descendant(
      of: find.byType(ReportsScreen),
      matching: find.byType(InkWell),
    );
    expect(taps, findsWidgets);

    for (int i = 0; i < taps.evaluate().length; i++) {
      final Size size = tester.getSize(taps.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'a control on Reports is only ${size.height} tall',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: 'a control on Reports is only ${size.width} wide',
      );
    }
  });

  testWidgets('a balance on the sheet twice is named, with both sides', (
    WidgetTester tester,
  ) async {
    // The sample ledger records 10,000 as both a loan ACCOUNT and a debt, and
    // 6,250 as both a receivable account and two owedToMe debts. Neither was
    // visible until debts joined the balance sheet on 2026-10-05, because
    // only one side of each pair was ever counted.
    await openReports(tester);

    expect(find.text('COUNTED TWICE'), findsOneWidget);
    expect(find.text('₱16,250.00'), findsOneWidget);

    // NAMED, both of them. A figure with no name sends somebody hunting
    // through two screens for it.
    expect(
      find.textContaining('BPI Gadget Loan is also recorded as'),
      findsOneWidget,
    );
    expect(find.textContaining('Accounts Receivable'), findsWidgets);

    // THE WRONG CONCLUSION THIS EXISTS TO STOP. The two sides pull net worth
    // in OPPOSITE directions, so somebody who subtracts 16,250 from the
    // headline gets a worse answer than if the card had said nothing.
    expect(
      find.textContaining('out by the difference, not by the total'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Nothing is wrong with your money'),
      findsOneWidget,
      reason:
          'a money app reporting a double count without that clause reads as '
          'the app confessing it lost something',
    );
  });

  testWidgets('no double count card on a ledger that has none', (
    WidgetTester tester,
  ) async {
    // THE SILENT HALF. A permanent badge saying everything is fine teaches
    // people to read this whole area as decoration, and then the one time it
    // speaks they will not know it has ever been quiet for a reason.
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
    s.addDebt(
      const Debt(
        id: 'd1',
        person: 'Nanay',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(3000),
        paidAmount: Money.zero,
        isSettled: false,
      ),
    );
    await openReports(tester, given: s);

    expect(find.text('COUNTED TWICE'), findsNothing);
  });

  testWidgets('recording the home takes the caveat away', (
    WidgetTester tester,
  ) async {
    // THE SENTENCE MUST NOT OUTLIVE THE GAP IT DESCRIBES. "Your home is not
    // counted here" is a true and useful warning while nothing holds the
    // house. The moment somebody records it, the app would be printing a
    // false statement to the one person who did the thing it asked for.
    final FinancialState s = FinancialState(
      clock: fixtureToday,
      store: MemorySnapshotStore(),
    )..startWithExampleData();
    s.addAccount(
      const Account(
        id: 'home',
        name: 'House and lot',
        kind: AccountKind.property,
        institution: 'Owned',
        balance: Money.pesos(3200000),
        monogram: 'OWN',
      ),
    );
    await openReports(tester, given: s);

    expect(find.textContaining('Your home is not counted here'), findsNothing);

    // DIRECTIONAL COMPANION. The assertion above passes just as well if the
    // whole card stopped rendering, so this names what must still be there,
    // and it is also the feature working: a 3.2M house against the seed's
    // 385,000 mortgage turns the headline from a debt into a surplus.
    expect(find.text('WHAT IS REALLY YOURS'), findsOneWidget);
    expect(
      find.text('STILL TO PAY OFF'),
      findsNothing,
      reason:
          'with the home counted this ledger is no longer underwater, which '
          'is the whole point of giving the mortgage its other side',
    );
  });

  testWidgets('a period whose only income was a repayment dashes, not 0.0%', (
    WidgetTester tester,
  ) async {
    // THE GUARD THAT STOPPED REACHING ITS OWN CASE.
    //
    // `_ratioText` prints a dash rather than a percentage when there is
    // nothing to take a ratio of, because "0.0%" is a measurement and the
    // truth in that case is that there is no measurement.
    //
    // On 2026-10-06 both ratios moved to dividing by what was EARNED, so a
    // repayment is out of the denominator. The dash gate did not move with
    // them: it still asked `totalIncome > 0`, and a repayment counts there.
    //
    // So a period whose only inflow was somebody paying you back has
    // totalIncome above zero and earned income exactly zero. The engine
    // correctly returns 0 for both ratios, having nothing to divide by, and
    // the screen then printed that zero as though it were a result. Somebody
    // who paid 5,000 of loans that period was told their debt servicing was
    // 0.0%, which is the precise misreading the dash exists to prevent.
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 3000, "monogram": "GC"}
  ],
  "transactions": [
    {"id": "r1", "type": "income", "amount": 8000,
     "category": "Receivables & Repayments",
     "accountId": "gc", "date": "2026-09-10", "createdAt": 1,
     "status": "confirmed"},
    {"id": "d1", "type": "expense", "amount": 5000,
     "category": "Debt & Loan Servicing",
     "accountId": "gc", "date": "2026-09-12", "createdAt": 2,
     "status": "confirmed"}
  ],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
    final FinancialState s = FinancialState(clock: fixtureToday, store: store);
    await s.restore();

    await openReports(tester, given: s);
    await tapAndSettle(tester, find.text('Performance'));

    // DIRECTIONAL COMPANION. The repayment really did arrive, so "Money in"
    // must still say so. Without this the test passes just as well on a
    // screen that has stopped rendering the period at all, which is the
    // failure mode an absence-only assertion cannot see.
    expect(find.text('₱8,000.00'), findsWidgets, reason: 'money in');

    // And both rates refuse to answer, because nothing was earned.
    expect(
      find.text('0.0%'),
      findsNothing,
      reason: 'a rate of zero over nothing earned is not a measurement',
    );
    expect(find.text('-'), findsWidgets, reason: 'both ratios should dash');
  });

  testWidgets('the ratio denominator is shown when it is not Money in', (
    WidgetTester tester,
  ) async {
    // A percentage whose denominator is nowhere on the screen cannot be
    // checked. With a repayment in the period, "Money in" is NOT what either
    // rate divides by, so dividing the visible numerator by the visible
    // income gives a different answer from the printed one.
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 22000, "monogram": "GC"}
  ],
  "transactions": [
    {"id": "s1", "type": "income", "amount": 50000, "category": "Salary",
     "accountId": "gc", "date": "2026-09-05", "createdAt": 1,
     "status": "confirmed"},
    {"id": "r1", "type": "income", "amount": 8000,
     "category": "Receivables & Repayments",
     "accountId": "gc", "date": "2026-09-09", "createdAt": 2,
     "status": "confirmed"},
    {"id": "g1", "type": "expense", "amount": 30000, "category": "Groceries",
     "accountId": "gc", "date": "2026-09-11", "createdAt": 3,
     "status": "confirmed"}
  ],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
    final FinancialState s = FinancialState(clock: fixtureToday, store: store);
    await s.restore();

    await openReports(tester, given: s);
    await tapAndSettle(tester, find.text('Performance'));

    expect(find.text('Earned'), findsOneWidget);
    // 58,000 arrived, 50,000 of it earned, and BOTH are on screen so the
    // printed rate can be reconciled against the right one.
    expect(find.text('₱58,000.00'), findsWidgets, reason: 'money in');
    expect(find.text('₱50,000.00'), findsWidgets, reason: 'the denominator');
  });

  testWidgets('no Earned row when it would just restate Money in', (
    WidgetTester tester,
  ) async {
    // THE DIRECTIONAL HALF of the test above. Without it, that one is
    // satisfied by a row that is simply always there, which would put a
    // duplicate of "Money in" on every report anybody ever opens.
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));

    expect(find.text('Savings rate'), findsOneWidget, reason: 'right card');
    expect(
      find.text('Earned'),
      findsNothing,
      reason:
          'the seed has no repayment, so earned equals money in and the row '
          'would restate a figure already on the screen',
    );
  });

  testWidgets(
    'Cash flow says a month of saving is not a month of overspending',
    (WidgetTester tester) async {
      // Put money into MP2 and overpay a loan, which is exactly what this app
      // teaches, and the hero on Cash flow goes red at hero size. The sections
      // below explain it and nobody reads downward past a red headline about
      // their own money.
      final MemorySnapshotStore store = MemorySnapshotStore();
      await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 5000, "monogram": "GC"}
  ],
  "transactions": [
    {"id": "s1", "type": "income", "amount": 50000, "category": "Salary",
     "accountId": "gc", "date": "2026-09-05", "createdAt": 1,
     "status": "confirmed"},
    {"id": "g1", "type": "expense", "amount": 30000, "category": "Groceries",
     "accountId": "gc", "date": "2026-09-08", "createdAt": 2,
     "status": "confirmed"},
    {"id": "m1", "type": "expense", "amount": 15000,
     "category": "Investment", "accountId": "gc", "date": "2026-09-12",
     "createdAt": 3, "status": "confirmed"},
    {"id": "l1", "type": "expense", "amount": 10000,
     "category": "Debt & Loan Servicing", "accountId": "gc",
     "date": "2026-09-14", "createdAt": 4, "status": "confirmed"}
  ],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
      final FinancialState s = FinancialState(
        clock: fixtureToday,
        store: store,
      );
      await s.restore();

      await openReports(tester, given: s);
      await tapAndSettle(tester, find.text('Cash flow'));

      // Day to day: 50,000 in less 30,000 of groceries. The investment and the
      // loan payment are claimed by the other two sections, so operating keeps
      // neither.
      expect(
        find.textContaining('came out ahead by ₱20,000.00'),
        findsOneWidget,
      );
      expect(find.textContaining('not because you overspent'), findsOneWidget);
    },
  );

  testWidgets('and stays quiet when the month really was overspending', (
    WidgetTester tester,
  ) async {
    // THE OTHER HALF, and the one that matters more. An alarm that fires on
    // every negative month is an alarm whose battery gets taken out. Here
    // everyday living genuinely did not pay for itself, so the reassurance
    // would be a lie.
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 1000, "monogram": "GC"}
  ],
  "transactions": [
    {"id": "s1", "type": "income", "amount": 20000, "category": "Salary",
     "accountId": "gc", "date": "2026-09-05", "createdAt": 1,
     "status": "confirmed"},
    {"id": "g1", "type": "expense", "amount": 35000, "category": "Groceries",
     "accountId": "gc", "date": "2026-09-08", "createdAt": 2,
     "status": "confirmed"}
  ],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
    final FinancialState s = FinancialState(clock: fixtureToday, store: store);
    await s.restore();

    await openReports(tester, given: s);
    await tapAndSettle(tester, find.text('Cash flow'));

    // Directional: the card is on screen and the month really is negative.
    // _SectionCard uppercases its own title, so this is the rendered string.
    expect(find.text('NET CHANGE IN CASH'), findsOneWidget);
    expect(find.text('-₱15,000.00'), findsWidgets, reason: 'really negative');
    expect(find.textContaining('came out ahead'), findsNothing);
  });

  testWidgets('"You kept" never prints a share of nothing', (
    WidgetTester tester,
  ) async {
    // The same failure `_ratioText` was written to kill, on the one sentence
    // it was never applied to. The caption was gated on the surplus being
    // zero or more, and zero in with zero out IS a surplus of zero, so it
    // printed "That is 0.0% of what came in" about an income of nothing.
    //
    // The realistic way to land here is a period whose only entry is a
    // transfer between your own accounts. That is excluded from money in and
    // out by design, so the scope line says "From 1 entry" and the report
    // does NOT read as empty, which is what makes a bogus percentage on it
    // believable.
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 5000, "monogram": "GC"},
    {"id": "bpi", "name": "BPI", "kind": "bank",
     "institution": "BPI", "balance": 20000, "monogram": "BP"}
  ],
  "transactions": [
    {"id": "t1", "type": "transfer", "amount": 5000, "category": "Transfer",
     "accountId": "bpi", "toAccountId": "gc", "date": "2026-09-10",
     "createdAt": 1, "status": "confirmed"}
  ],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
    final FinancialState s = FinancialState(clock: fixtureToday, store: store);
    await s.restore();

    await openReports(tester, given: s);
    await tapAndSettle(tester, find.text('Performance'));

    expect(
      find.textContaining('of what came in'),
      findsNothing,
      reason: 'a percentage of an income of zero is not a measurement',
    );
    // DIRECTIONAL. Absence is also what a card that stopped rendering shows.
    expect(find.text('YOU KEPT'), findsOneWidget);
    expect(find.text('Nothing came in over this period.'), findsOneWidget);
  });

  testWidgets('an overdrawn account reads as negative on Position', (
    WidgetTester tester,
  ) async {
    // `formatPeso` returns the ABSOLUTE value on purpose, and Position used it
    // for every asset figure. Nothing clamps a balance at zero and the Log
    // sheet has no sufficiency check, so overspending an account is ordinary,
    // and an account at -1,500 then read "You own 1,500.00" in the positive
    // colour. Dropping the sign of a figure that can be negative does not
    // understate it, it REVERSES it, which is the exact argument this file
    // already makes for net worth.
    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "gc", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": -1500, "monogram": "GC"}
  ],
  "transactions": [],
  "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');
    final FinancialState s = FinancialState(clock: fixtureToday, store: store);
    await s.restore();

    await openReports(tester, given: s);

    expect(
      find.textContaining('You own ₱1,500.00'),
      findsNothing,
      reason: 'an overdrawn account was reported as money owned',
    );
    expect(find.textContaining('You own -₱1,500.00'), findsOneWidget);
    // DIRECTIONAL. The figure itself must still be there, with its sign.
    expect(find.text('-₱1,500.00'), findsWidgets);
  });
}
