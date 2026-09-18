import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/plan/plan_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Plan, driven the way a person drives it.
///
/// The arithmetic is proved in plan_golden_test.dart. These ask the other
/// question: after tapping what somebody would tap, is the right number on
/// the right screen, and did a write actually land where they would look for
/// it afterwards.
void main() {
  Future<void> openPlan(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.track_changes_outlined));
    await tester.pumpAndSettle();
  }

  /// The store, read off the PLAN screen rather than Home.
  ///
  /// Home is not in the tree once another tab is open, so reading it there
  /// throws "Bad state: No element" in a way that looks like the test failed
  /// rather than like the finder was wrong.
  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<PlanScreen>(find.byType(PlanScreen)).state;

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openSegment(WidgetTester tester, String tile) async {
    await openPlan(tester);
    await tapAndSettle(tester, find.text(tile));
  }

  Future<void> typeIn(WidgetTester tester, String key, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Plan tab opens on the hub with a live figure', (
    WidgetTester tester,
  ) async {
    await openPlan(tester);

    expect(find.byType(PlanScreen), findsOneWidget);
    // 42,000 of limits less 16,574.75 spent this month.
    expect(find.text('₱25,425.25'), findsOneWidget);
    // The hub says which tile needs attention rather than being eight
    // identical doors.
    expect(find.text('1 over'), findsOneWidget);
  });

  testWidgets('every one of the seven tiles opens something', (
    WidgetTester tester,
  ) async {
    // The gap this closes: a hub whose tiles do nothing is worse than no hub.
    // Every tile is tapped, and every one has to change the header.
    const Map<String, String> tiles = <String, String>{
      'Budgets': 'Budgets',
      'Bills and payables': 'Bills and payables',
      'Goals': 'Goals',
      'Decisions': 'Decisions',
      'Trackers': 'Trackers',
      'Calculators': 'Calculators',
      'Learn': 'Learn',
    };

    for (final MapEntry<String, String> e in tiles.entries) {
      await openPlan(tester);
      await tapAndSettle(tester, find.text(e.key).first);
      expect(
        find.descendant(
          of: find.byType(PlanScreen),
          matching: find.text(e.value),
        ),
        findsWidgets,
        reason: 'the ${e.key} tile did not open its segment',
      );
      // And back out again, so the segment is not a one-way door.
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
      expect(find.text('Trackers'), findsWidgets);
    }
  });

  group('budgets', () {
    testWidgets('the over-budget row is named, and says by how much', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Budgets');

      // 6,450 spent against a 6,000 limit.
      expect(find.text('₱450.00 over limit'), findsOneWidget);
      expect(find.text('1 over, 0 to watch'), findsOneWidget);
    });

    testWidgets('trouble is sorted to the top', (WidgetTester tester) async {
      await openSegment(tester, 'Budgets');

      // A list in a fixed order makes somebody read all seven to find the one
      // that needs them.
      final double over = tester
          .getTopLeft(find.text('Debt & Loan Servicing'))
          .dy;
      final double fine = tester.getTopLeft(find.text('Food & Dining')).dy;
      expect(
        over,
        lessThan(fine),
        reason: 'the over-budget row is not at the top',
      );
    });

    testWidgets('an excluded entry is visibly NOT eating the budget', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Budgets');

      // The founder-approved divergence, checked on the screen rather than in
      // the engine. The prototype would put 5,680 here.
      expect(find.text('₱2,840.00'), findsOneWidget);
      expect(
        find.textContaining('₱5,680'),
        findsNothing,
        reason: 'the excluded duplicate reached the budget screen',
      );
    });

    testWidgets('changing a limit moves the row AND the headline', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Budgets');
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, find.text('Food & Dining'));
      await typeIn(tester, 'budget-limit', '12000');

      // What it is about to do, before it does it. 12,000 less the 465 spent.
      expect(find.text('₱11,535.00'), findsWidgets);

      await tapAndSettle(tester, find.text('Save limit'));

      // Half one: the store moved, and only that budget moved.
      expect(
        state.budgets.firstWhere((b) => b.category == 'Food & Dining').limit,
        12000,
      );
      expect(
        state.budgets.firstWhere((b) => b.category == 'Groceries').limit,
        8000,
        reason: 'changing one limit changed another',
      );

      // Half two: a person can SEE it. Total limits rise by 3,000, so left to
      // spend rises from 25,425.25 to 28,425.25.
      expect(
        find.text('₱28,425.25'),
        findsOneWidget,
        reason: 'the headline did not follow the limit that just changed',
      );
    });

    testWidgets('a limit below what is already spent warns before saving', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Budgets');
      await tapAndSettle(tester, find.text('Groceries'));
      await typeIn(tester, 'budget-limit', '1000');

      expect(
        find.textContaining('below what you have already spent'),
        findsOne,
      );
    });

    testWidgets('a limit of zero cannot be saved', (WidgetTester tester) async {
      await openSegment(tester, 'Budgets');
      final FinancialState state = storeOf(tester);

      await tapAndSettle(tester, find.text('Groceries'));
      await typeIn(tester, 'budget-limit', '0');
      await tester.tap(find.text('Save limit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        state.budgets.firstWhere((b) => b.category == 'Groceries').limit,
        8000,
        reason:
            'a zero limit was stored, which makes every percent meaningless',
      );
    });
  });

  group('goals', () {
    testWidgets('a contribution moves the goal AND is visible afterwards', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Goals');
      final FinancialState state = storeOf(tester);
      final double netBefore = state.accounts.fold<double>(
        0,
        (double s, a) => s + a.balance,
      );

      // The goal CARD is not tappable, only its button is. Tapping the card
      // would be a reasonable thing to build and is not what is built, so the
      // test drives what exists. Emergency Fund is first in the fixture, so
      // the first button belongs to it.
      await tapAndSettle(tester, find.text('Add to this goal').first);
      await typeIn(tester, 'contribute-amount', '2500');

      // The preview says where it lands before it lands.
      expect(find.text('₱45,000.00'), findsWidgets);

      await tapAndSettle(tester, find.text('Add to goal'));

      // Half one, with the directional companion.
      expect(
        state.goals.firstWhere((g) => g.id == 'goal_emergency').currentAmount,
        45000,
      );
      expect(
        state.goals.firstWhere((g) => g.id == 'goal_japan').currentAmount,
        28000,
        reason: 'contributing to one goal moved another',
      );

      // A goal is INTENT, not a pot. It must not move an account balance, or
      // every contribution double counts against the transfer that funded it.
      expect(
        state.accounts.fold<double>(0, (double s, a) => s + a.balance),
        netBefore,
        reason: 'a goal contribution moved real money',
      );

      // Half two: it is on the screen the app landed on.
      expect(find.text('₱45,000.00'), findsWidgets);
    });

    testWidgets('a new goal appears in the list', (WidgetTester tester) async {
      await openSegment(tester, 'Goals');
      final FinancialState state = storeOf(tester);
      final int before = state.goals.length;

      await tapAndSettle(tester, find.text('Add a goal'));
      await typeIn(tester, 'goal-name', 'Motor down payment');
      await typeIn(tester, 'goal-target', '60000');

      // It answers "when do I get there" before saving. 60,000 at a twelfth
      // of the target a month is twelve months.
      expect(find.textContaining('about 12 months'), findsOneWidget);

      await tapAndSettle(tester, find.text('Create goal'));

      expect(state.goals.length, before + 1);
      expect(
        find.text('Motor down payment'),
        findsOneWidget,
        reason: 'the goal saved and is not on the screen that lists goals',
      );
    });

    testWidgets('a finished goal offers no contribute button', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Goals');

      // goal_phone is fully funded in the fixture. A button that can only
      // refuse is worse than no button.
      expect(find.textContaining('Funded.'), findsOneWidget);
      expect(find.text('Add to this goal'), findsNWidgets(2));
    });
  });

  group('bills', () {
    testWidgets('payday is not counted as a bill', (WidgetTester tester) async {
      await openSegment(tester, 'Bills and payables');

      // The prototype's headline reads 38,029 here, because it sums the
      // 32,500 payday into "Total Scheduled Bills".
      expect(find.text('₱5,529.00'), findsOneWidget);
      expect(find.text('₱32,500.00'), findsWidgets);
      expect(
        find.textContaining('₱38,029'),
        findsNothing,
        reason: 'payday is being added into the bills total again',
      );
    });
  });

  group('decisions', () {
    testWidgets('a new income stream is listed AND moves Safe to Spend', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Decisions');
      final FinancialState state = storeOf(tester);
      final double before = state.safeToSpendAnalysis.safeToSpendToday;
      final double inflowBefore = state.safeToSpendAnalysis.totalExpectedInflow;

      await tapAndSettle(tester, find.text('Add an income stream'));
      await typeIn(tester, 'stream-name', 'Weekend tutoring');
      await typeIn(tester, 'stream-amount', '4000');
      await tapAndSettle(tester, find.text('Add stream'));

      // Half one, directional: it is not enough that the figure is still
      // valid, it has to have MOVED.
      //
      // It moves totalExpectedInflow and NOT safeToSpendToday, and the first
      // version of this test asserted the opposite and failed. Reading the
      // engine showed why: computeSafeToSpend works out expected inflow and
      // then never uses it, deriving the headline from liquid cash less
      // reserves alone. That is the prototype's behaviour and the engine is
      // vector-locked to it, so the SHEET'S COPY was corrected rather than the
      // arithmetic changed unasked.
      //
      // Asserting both halves is the point. The first proves the write landed
      // somewhere it is read; the second pins the surprising half, so a future
      // change to it has to be deliberate.
      expect(
        state.safeToSpendAnalysis.totalExpectedInflow,
        greaterThan(inflowBefore),
        reason:
            'the new stream was stored and the analysis never saw it, which '
            'is the shape of defect the store already had: it read the frozen '
            'seed list rather than the live one',
      );
      expect(
        state.safeToSpendAnalysis.safeToSpendToday,
        before,
        reason:
            'Safe to Spend moved on expected income. That may well be an '
            'improvement, but it is a money change and it is the founder\'s',
      );

      // Half two: it is on the screen.
      expect(find.text('Weekend tutoring'), findsOneWidget);
    });
  });

  group('trackers', () {
    testWidgets('the subscription total is computed, not the hardcoded one', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Trackers');

      // 549 + 239 + 2500 + 1549 monthly, plus 4790 a year at a twelfth.
      expect(find.text('₱5,236.17 a month'), findsOneWidget);
      expect(
        find.textContaining('₱3,288'),
        findsNothing,
        reason:
            'the prototype hardcodes 3,288 beside a list that does not '
            'add up to it, and an annual plan counted as monthly is a '
            'twelvefold error on that row',
      );
    });
  });

  group('learn', () {
    testWidgets('the category filter narrows the list', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Learn');

      expect(find.textContaining('Build your first emergency fund'), findsOne);

      await tapAndSettle(tester, find.text('Debt'));
      expect(
        find.textContaining('Build your first emergency fund'),
        findsNothing,
      );
      expect(find.textContaining('Credit cards, instalments'), findsOne);
    });

    testWidgets('the missing guides explain themselves', (
      WidgetTester tester,
    ) async {
      await openSegment(tester, 'Learn');
      expect(
        find.text('The business startup guides come next'),
        findsOneWidget,
      );
    });
  });

  testWidgets('nothing on Plan overflows at 320dp, on any segment', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final String tile in <String>[
      'Budgets',
      'Bills and payables',
      'Goals',
      'Decisions',
      'Trackers',
      'Calculators',
      'Learn',
    ]) {
      await openPlan(tester);
      expect(tester.takeException(), isNull, reason: 'the hub overflowed');
      await tapAndSettle(tester, find.text(tile).first);
      expect(tester.takeException(), isNull, reason: '$tile overflowed');

      // Back to the hub before the next one. pumpWidget with the same const
      // widget REUSES the element tree rather than rebuilding it, so the
      // screen keeps the segment it was on and the next tile's label is not
      // there to find. The failure reads "Bad state: No element", which looks
      // like the tile vanished rather than like the test never went home.
      await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    }
  });

  testWidgets('every control on the Plan hub clears the 44dp floor', (
    WidgetTester tester,
  ) async {
    await openPlan(tester);

    final Finder taps = find.descendant(
      of: find.byType(PlanScreen),
      matching: find.byType(InkWell),
    );
    expect(taps, findsWidgets);

    for (int i = 0; i < taps.evaluate().length; i++) {
      final Size size = tester.getSize(taps.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'a control on Plan is only ${size.height} tall',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: 'a control on Plan is only ${size.width} wide',
      );
    }
  });
}
