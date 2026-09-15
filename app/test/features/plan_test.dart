// What the Budget segment decides.
//
// Every case fixes "now", because which expenses count is "this month" and a
// test that passes only in the month somebody ran it is not a test.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/budget.dart' show budgetSummary;
import 'package:salapify/features/plan/budget_rows.dart';

import '../support/memory_store.dart';

/// The same moment the render harness pins.
final _now = DateTime(2026, 9, 11, 9, 30);

void main() {
  group('the rows', () {
    test(
      'a category earns a row for a cap OR for spending, never for neither',
      () {
        final rows = categoryBudgets(livedIn(), _now);
        final names = rows.map((r) => r.name).toList();

        // The three capped ones and the two that had money go through them.
        expect(
          names,
          containsAll(['Food', 'Groceries', 'Transport', 'Bills', 'Load']),
        );

        // The other default categories are neither capped nor used this month,
        // and a screen listing every category a user has ever had is a filing
        // cabinet rather than an answer.
        expect(names, isNot(contains('Shopping')));
      },
    );

    test('the ones closest to their limit come first', () {
      // A budget screen is read when somebody is about to spend, so the
      // category nearest its limit belongs at the top. Alphabetical order
      // would bury the only row that changes a decision.
      // URGENCY ORDERS WITHIN A LEVEL, and a child follows its parent. Sorting
      // everything by urgency alone scatters a child away from the parent whose
      // figure already contains it, and the screen then indents a row with
      // nothing above it to be indented under.
      final rows = categoryBudgets(livedIn(), _now);
      final top = [
        for (final r in rows)
          if (r.parentId == null) r.name,
      ];
      expect(top.first, 'Food');
      expect(top[1], 'Groceries');
      expect(top[2], 'Bills');
      expect(top[3], 'Transport');

      // Uncapped rows follow the capped ones, largest spend first. They are
      // information, not a decision.
      expect(top.last, 'Load');

      // And Electricity sits immediately under Bills rather than wherever its
      // own spend would have put it.
      final names = [for (final r in rows) r.name];
      expect(
        names[names.indexOf('Bills') + 1],
        'Electricity',
        reason:
            'a child is not directly under its parent, so the indent on screen '
            'points at nothing',
      );
    });

    test('spent, remaining and over are what the stored rows say', () {
      final rows = {
        for (final r in categoryBudgets(livedIn(), _now)) r.name: r,
      };

      // Jollibee 250 against a 200 cap.
      expect(rows['Food']!.spent, 250.00);
      expect(rows['Food']!.over, isTrue);
      expect(rows['Food']!.remaining, -50.00);

      // Groceries 2,450.50 against 2,500, so 49.50 left and not over.
      expect(rows['Groceries']!.spent, 2450.50);
      expect(rows['Groceries']!.over, isFalse);
      expect(rows['Groceries']!.remaining, 49.50);
    });

    test('an over budget row fills its bar rather than drawing past it', () {
      final rows = {
        for (final r in categoryBudgets(livedIn(), _now)) r.name: r,
      };

      // Clamped, so the bar says "full" and the CAPTION says how far over.
      // An unclamped fraction of 1.25 would paint outside its own track.
      expect(rows['Food']!.fraction, 1.0);
      expect(rows['Transport']!.fraction, closeTo(0.03, 0.001));
    });

    test('a category with no limit has no fraction to draw', () {
      final rows = {
        for (final r in categoryBudgets(livedIn(), _now)) r.name: r,
      };

      // Load, not Bills. Bills gained a limit when the fixture grew a real
      // parent and child under it, because a parent with no cap is a grouping
      // and a parent with a cap is the decision sub-categories exist to make.
      expect(rows['Load']!.capped, isFalse);
      expect(rows['Load']!.fraction, 0.0);
      expect(rows['Load']!.over, isFalse);

      // And it never counts toward the hero's "needs a look" tally, because
      // there is no limit for it to be close to.
      expect(rows['Load']!.needsALook, isFalse);

      // A CHILD with no limit of its own is the same shape, and it is the case
      // that arrived with the tree: it carries real spending, it rolls into a
      // capped parent, and it still draws no bar itself.
      expect(rows['Electricity']!.capped, isFalse);
      expect(rows['Electricity']!.spent, greaterThan(0));
      expect(rows['Electricity']!.fraction, 0.0);
      expect(rows['Electricity']!.needsALook, isFalse);
    });

    test('needs a look means over, or down to the last quarter', () {
      final rows = categoryBudgets(livedIn(), _now);

      // Food is over, Groceries has 49.50 of 2,500 left, which is under the
      // 625 quarter. Transport has 1,455 of 1,500 and is comfortable.
      expect(needALook(rows), 2);
    });

    test('last month\'s spending is not this month\'s', () {
      // The month rule is isThisMonth from the golden locked statements.dart
      // rather than a second date rule written here, because two month rules
      // that disagree is exactly what nothing would catch.
      final rows = categoryBudgets(livedIn(), DateTime(2026, 10, 5));
      final food = rows.where((r) => r.name == 'Food');

      // October: the caps are still set, so the rows still exist, but nothing
      // has been spent against them yet.
      expect(food.single.spent, 0.0);
      expect(food.single.over, isFalse);
      expect(needALook(rows), 0);
    });

    test('an empty ledger is empty, not an error', () {
      expect(categoryBudgets(const {}, _now), isEmpty);
      expect(needALook(const []), 0);
    });
  });

  group('the hero comes from the engine, not from here', () {
    test('left to spend is the stored limit minus this month\'s expenses', () {
      final s = budgetSummary(livedIn(), _now);

      // 3,200 Meralco + 250 Jollibee + 45 Pamasahe + 2,450.50 Groceries
      // + 100 Load. The transfer and the income are not expenses.
      expect(s['spent'], 6045.50);
      expect(s['limit'], 20000.00);
      expect(s['remaining'], 13954.50);
      expect(s['over'], isFalse);
    });

    test('the category rows never claim more spending than the hero counts', () {
      // The hero counts EVERY expense this month; the rows count only the
      // tagged ones. So the rows can be less, and must never be more. If they
      // ever were, one of the two would be double counting.
      //
      // TOP LEVEL ONLY, and that filter is the whole point rather than a
      // convenience. A parent's spend CONTAINS its children's, so folding every
      // row adds the children twice: with the fixture's Bills over Electricity
      // this assertion read 9,245.50 against a hero of 6,045.50. That is not a
      // defect in the figures, it is what the shape means, and it is exactly
      // why anything adding rows together has to filter first. This test is the
      // place that says so.
      final data = livedIn();
      final rows = categoryBudgets(data, _now);
      final tagged = rows
          .where((r) => r.parentId == null)
          .fold<double>(0, (sum, r) => sum + r.spent);

      expect(tagged, lessThanOrEqualTo(budgetSummary(data, _now)['spent']));

      // Did anything happen: the fixture really does have a parent carrying a
      // child's money, or the filter above is protecting against nothing and
      // this test would pass on a flat list forever.
      expect(
        rows.any((r) => r.rollsUp),
        isTrue,
        reason:
            'no row rolls anything up, so the top-level filter is untested and '
            'the double count it prevents cannot be reached',
      );
    });
  });
}
