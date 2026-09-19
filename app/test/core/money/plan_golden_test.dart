import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/plan.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the Plan engine.
///
/// Produced by app/tool/gen_plan_vectors.ts, which runs the prototype's own
/// budget arithmetic over app/'s fixture and prints BOTH readings: the
/// prototype's, and the one the founder approved on 2026-09-18. To regenerate:
///
///   flutter test test/tool/dump_fixture_test.dart
///   bun app/tool/gen_plan_vectors.ts `the printed json` `the same json`
///
/// Clock PINNED to 2026-09-18, because the budget window is "this month".
void main() {
  final DateTime now = DateTime.utc(2026, 9, 18);

  List<BudgetStatus> budgets() => computeBudgets(
    budgets: SeedData.budgets,
    transactions: SeedData.transactions(),
    now: now,
  );

  BudgetStatus row(String category) =>
      budgets().firstWhere((BudgetStatus b) => b.category == category);

  void closeTo(double actual, double expected, String what) {
    expect(actual, moreOrLessEquals(expected, epsilon: 0.005), reason: what);
  }

  group('budgets, this month, excluded entries ignored', () {
    test('every line', () {
      const Map<String, (double spent, double limit, int percent, int n)>
      expected = <String, (double, double, int, int)>{
        'Food & Dining': (465, 9000, 5, 2),
        'Transport & Commute': (420, 3500, 12, 1),
        'Bills & Utilities': (2840, 6500, 44, 1),
        'Groceries': (3250.75, 8000, 41, 1),
        'Shopping & Personal': (1899, 4000, 47, 1),
        'Business & Freelance Ops': (1250, 5000, 25, 1),
        'Debt & Loan Servicing': (6450, 6000, 100, 3),
      };

      expected.forEach((String category, (double, double, int, int) want) {
        final BudgetStatus b = row(category);
        closeTo(b.spent, want.$1, '$category spent');
        closeTo(b.limit, want.$2, '$category limit');
        expect(b.percent, want.$3, reason: '$category percent');
        expect(b.entryCount, want.$4, reason: '$category entry count');
      });
    });

    test('THE DIVERGENCE: an excluded entry does not eat a budget', () {
      // This is the whole reason the founder was asked. The fixture holds two
      // identical 2,840 Meralco charges, one marked excluded because it was
      // billed twice. The prototype counts both, which puts Bills & Utilities
      // at 5,680 of 6,500 and into "watch closely" on a bill the person has
      // already said is not theirs.
      final BudgetStatus bills = row('Bills & Utilities');
      closeTo(bills.spent, 2840, 'the excluded duplicate was counted');
      expect(bills.entryCount, 1, reason: 'both Meralco charges were counted');
      expect(bills.health, BudgetHealth.onTrack);

      // Named so the failure message says what went wrong rather than just
      // which number moved.
      expect(
        bills.spent,
        isNot(5680),
        reason: 'this is the prototype figure, so the exclusion rule is gone',
      );
    });

    test('THE DIVERGENCE: only this month counts', () {
      // A limit that never resets is not a limit. Nothing in the fixture is
      // dated outside September 2026, so this asserts the RULE directly by
      // handing the engine an entry from last month.
      final List<Transaction> withLastMonth = <Transaction>[
        ...SeedData.transactions(),
        const Transaction(
          id: 'tx_last_month',
          type: TransactionType.expense,
          amount: 99999,
          category: 'Food & Dining',
          accountId: 'acc_cash',
          date: '2026-08-14',
          createdAt: 0,
        ),
      ];

      final BudgetStatus food = computeBudgets(
        budgets: SeedData.budgets,
        transactions: withLastMonth,
        now: now,
      ).firstWhere((BudgetStatus b) => b.category == 'Food & Dining');

      closeTo(food.spent, 465, 'August spending reached a September budget');
      expect(food.isOver, isFalse);
    });

    test('the three states, and one of each is reachable in the fixture', () {
      final List<BudgetStatus> rows = budgets();

      expect(
        rows
            .firstWhere(
              (BudgetStatus b) => b.category == 'Debt & Loan Servicing',
            )
            .health,
        BudgetHealth.over,
        reason:
            'the fixture is meant to contain an over-budget line, so the '
            'red state can be rendered and reviewed at all',
      );
      expect(
        rows.any((BudgetStatus b) => b.health == BudgetHealth.onTrack),
        isTrue,
      );
    });

    test('over budget keeps a real negative remaining, not a clamped zero', () {
      final BudgetStatus debt = row('Debt & Loan Servicing');
      expect(debt.isOver, isTrue);
      closeTo(debt.remaining, -450, 'remaining');
      // The PERCENT is capped so a progress bar cannot overflow its track.
      // The remaining is not, because somebody 450 over needs the 450.
      expect(debt.percent, 100);
    });

    test('totals', () {
      final BudgetTotals t = computeBudgetTotals(budgets());
      closeTo(t.totalLimit, 42000, 'totalLimit');
      closeTo(t.totalSpent, 16574.75, 'totalSpent');
      closeTo(t.leftToSpend, 25425.25, 'leftToSpend');
      expect(t.overCount, 1);
      expect(t.nearCount, 0);
      expect(t.allOnTrack, isFalse);
    });

    test('left to spend is floored at zero rather than going negative', () {
      final List<BudgetStatus> broke = <BudgetStatus>[
        const BudgetStatus(
          category: 'Food & Dining',
          emoji: 'x',
          limit: 1000,
          spent: 5000,
          remaining: -4000,
          percent: 100,
          entryCount: 1,
        ),
      ];
      closeTo(computeBudgetTotals(broke).leftToSpend, 0, 'leftToSpend');
    });

    test('a zero limit does not produce infinity or NaN', () {
      final List<BudgetStatus> rows = computeBudgets(
        budgets: const <Budget>[
          Budget(category: 'Food & Dining', limit: 0, emoji: 'x'),
        ],
        transactions: SeedData.transactions(),
        now: now,
      );
      expect(rows.single.percent, 0);
      expect(rows.single.percent.isFinite, isTrue);
    });
  });

  group('goals', () {
    test('every goal', () {
      final List<GoalStatus> rows = computeGoals(SeedData.goals);
      const Map<String, (int percent, double remaining, int? months)> expected =
          <String, (int, double, int?)>{
            'goal_emergency': (71, 17500, 4),
            'goal_japan': (37, 47000, 11),
            'goal_phone': (100, 0, null),
          };
      expected.forEach((String id, (int, double, int?) want) {
        final GoalStatus g = rows.firstWhere((GoalStatus g) => g.goal.id == id);
        expect(g.percent, want.$1, reason: '$id percent');
        closeTo(g.remaining, want.$2, '$id remaining');
        expect(g.monthsAtCurrentRate, want.$3, reason: '$id months');
      });
    });

    test('months to go rounds UP, because a part payment is still a payment', () {
      // 100 left at 30 a month is four payments, not three and a bit. A goal
      // tracker that rounds down is a goal tracker that lies about the last one.
      final List<GoalStatus> rows = computeGoals(const <Goal>[
        Goal(
          id: 'g',
          name: 'g',
          emoji: 'x',
          targetAmount: 1000,
          currentAmount: 900,
          targetDate: 'Dec 2026',
          monthlyTarget: 30,
        ),
      ]);
      expect(rows.single.monthsAtCurrentRate, 4);
    });

    test('a finished goal is finished, not negatively short', () {
      final GoalStatus done = computeGoals(
        SeedData.goals,
      ).firstWhere((GoalStatus g) => g.goal.id == 'goal_phone');
      expect(done.isComplete, isTrue);
      closeTo(done.remaining, 0, 'remaining');
      expect(done.monthsAtCurrentRate, isNull);
    });
  });

  group('contributing to a goal', () {
    test('moves that goal and nothing else', () {
      final List<Goal> after = applyGoalContribution(
        SeedData.goals,
        'goal_emergency',
        2500,
      );

      final Goal moved = after.firstWhere((Goal g) => g.id == 'goal_emergency');
      closeTo(moved.currentAmount, 45000, 'the contribution did not land');

      // The directional companion. Without this, a function that returns the
      // list untouched satisfies "nothing else changed" perfectly.
      final Goal untouched = after.firstWhere((Goal g) => g.id == 'goal_japan');
      closeTo(
        untouched.currentAmount,
        SeedData.goals
            .firstWhere((Goal g) => g.id == 'goal_japan')
            .currentAmount,
        'a contribution to one goal moved another',
      );
    });

    test('cannot push a goal past its own target', () {
      final List<Goal> after = applyGoalContribution(
        SeedData.goals,
        'goal_emergency',
        999999,
      );
      final Goal g = after.firstWhere((Goal g) => g.id == 'goal_emergency');
      closeTo(g.currentAmount, g.targetAmount, 'a goal went past 100 percent');
    });

    test('a zero or negative contribution changes nothing', () {
      for (final double bad in <double>[0, -500]) {
        final List<Goal> after = applyGoalContribution(
          SeedData.goals,
          'goal_emergency',
          bad,
        );
        closeTo(
          after.firstWhere((Goal g) => g.id == 'goal_emergency').currentAmount,
          42500,
          'a contribution of $bad was accepted',
        );
      }
    });
  });

  group('changing a budget limit', () {
    test('changes that budget and nothing else', () {
      final List<Budget> after = applyBudgetLimit(
        SeedData.budgets,
        'Food & Dining',
        12000,
      );
      closeTo(
        after.firstWhere((Budget b) => b.category == 'Food & Dining').limit,
        12000,
        'the new limit did not land',
      );
      closeTo(
        after.firstWhere((Budget b) => b.category == 'Groceries').limit,
        8000,
        'changing one limit changed another',
      );
    });

    test('refuses zero, negative, and nonsense', () {
      for (final double bad in <double>[0, -1, double.nan, double.infinity]) {
        final List<Budget> after = applyBudgetLimit(
          SeedData.budgets,
          'Food & Dining',
          bad,
        );
        closeTo(
          after.firstWhere((Budget b) => b.category == 'Food & Dining').limit,
          9000,
          'a limit of $bad was stored',
        );
      }
    });
  });

  group('upcoming', () {
    test('bills and income are separated', () {
      final UpcomingTotals t = computeUpcomingTotals(SeedData.upcoming);
      closeTo(t.totalOut, 5529, 'totalOut');
      closeTo(t.totalIn, 32500, 'totalIn');
      expect(t.billCount, 3);
    });

    test('THE DIVERGENCE: payday is not a bill', () {
      // The prototype's headline sums EVERY row under the label "Total
      // Scheduled Bills", so the 32,500 payday is counted as a bill and the
      // figure reads 38,029 when the bills come to 5,529. No stored number
      // changes here; both figures are shown instead of one wrong one.
      final UpcomingTotals t = computeUpcomingTotals(SeedData.upcoming);
      expect(
        t.totalOut,
        isNot(38029),
        reason: 'payday is being counted as a bill again',
      );
      closeTo(
        t.totalOut + t.totalIn,
        38029,
        'the two halves should still account for every row',
      );
    });

    test('a paid item drops out of both totals', () {
      final List<UpcomingItem> items = <UpcomingItem>[
        ...SeedData.upcoming.map(
          (UpcomingItem u) => UpcomingItem(
            id: u.id,
            name: u.name,
            amount: u.amount,
            dueDate: u.dueDate,
            type: u.type,
            isIncome: u.isIncome,
            isPaid: u.type == UpcomingItemType.bill,
            category: u.category,
          ),
        ),
      ];
      // Only the BILL type is marked paid above, so what is left is the
      // Spotify subscription at 239 and the Home Credit instalment at 2,450.
      // The first version of this test expected 2,450 and forgot the
      // subscription, which is worth recording: the assertion was wrong and
      // the engine was right, and a looser test would have agreed with me.
      final UpcomingTotals t = computeUpcomingTotals(items);
      closeTo(t.totalOut, 2689, 'a paid bill is still being counted');
      expect(t.billCount, 2);
    });
  });

  group('parsing a typed amount', () {
    test('accepts what a person types, refuses what breaks a total', () {
      expect(parsePlanAmount('2500'), 2500);
      expect(parsePlanAmount('2,500.50'), 2500.5);
      expect(parsePlanAmount(' 300 '), 300);
      for (final String bad in <String>['', 'abc', '0', '-5', 'NaN']) {
        expect(parsePlanAmount(bad), isNull, reason: '"$bad" was accepted');
      }
    });
  });
}
