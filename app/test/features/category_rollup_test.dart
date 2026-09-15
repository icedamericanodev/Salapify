// Sub-categories, and the one number that must not move.
//
// FOUNDER DECISION, 2026-09-15: a parent counts everything under it. Cap
// Utilities at 5,000, log 3,200 to Electricity underneath it, and Utilities
// says 3,200 of 5,000. The alternative is a limit sitting at zero while the
// money it was meant to govern walks past it.
//
// The danger this file exists for is the other side of that: a parent's figure
// CONTAINS its children's, so anything that adds rows together has to sum the
// top level only. Add every row and Electricity's 3,200 is counted twice, and
// the screen tells somebody they have spent money they have not.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/budget.dart' show budgetSummary;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/plan/budget_rows.dart';

import '../support/memory_store.dart' show livedIn;

/// A ledger with Utilities over Electricity and Water, and nothing else, so
/// every figure below can be checked by hand.
Map<String, dynamic> _tree({double utilitiesCap = 5000}) {
  final data = livedIn();
  data['categories'] = [
    {
      'id': 'cat_util',
      'name': 'Utilities',
      'icon': '💡',
      'monthlyCap': utilitiesCap,
    },
    {
      'id': 'cat_elec',
      'name': 'Electricity',
      'icon': '⚡',
      'monthlyCap': 0,
      'parentId': 'cat_util',
    },
    {
      'id': 'cat_water',
      'name': 'Water',
      'icon': '🚰',
      'monthlyCap': 0,
      'parentId': 'cat_util',
    },
    {'id': 'cat_food', 'name': 'Food', 'icon': '🍜', 'monthlyCap': 0},
  ];
  data['transactions'] = [
    {
      'id': 't_elec',
      'type': 'expense',
      'label': 'Meralco',
      'amount': 3200.00,
      'date': '2026-09-05',
      'categoryId': 'cat_elec',
    },
    {
      'id': 't_water',
      'type': 'expense',
      'label': 'Maynilad',
      'amount': 450.00,
      'date': '2026-09-06',
      'categoryId': 'cat_water',
    },
    {
      'id': 't_util',
      'type': 'expense',
      'label': 'Association dues',
      'amount': 800.00,
      'date': '2026-09-07',
      'categoryId': 'cat_util',
    },
    {
      'id': 't_food',
      'type': 'expense',
      'label': 'Jollibee',
      'amount': 250.00,
      'date': '2026-09-08',
      'categoryId': 'cat_food',
    },
  ];
  return data;
}

BudgetRow _row(List<BudgetRow> rows, String id) =>
    rows.firstWhere((r) => r.id == id);

void main() {
  group('a parent counts everything under it', () {
    test('Utilities carries its own spending AND its children', () {
      final rows = categoryBudgets(_tree(), sampleAnchor);
      final util = _row(rows, 'cat_util');

      // 800 of its own, 3,200 Electricity, 450 Water.
      expect(util.spent, closeTo(4450, 0.005));
      expect(
        util.fromChildren,
        closeTo(3650, 0.005),
        reason:
            'the parent cannot say how much of its figure came from below, so '
            'the screen cannot explain why it is larger than its own entries',
      );
      expect(util.rollsUp, isTrue);
      expect(util.cap, 5000);
      expect(util.remaining, closeTo(550, 0.005));
    });

    test('and the children still carry their own, unchanged', () {
      final rows = categoryBudgets(_tree(), sampleAnchor);
      expect(_row(rows, 'cat_elec').spent, closeTo(3200, 0.005));
      expect(_row(rows, 'cat_water').spent, closeTo(450, 0.005));
      expect(
        _row(rows, 'cat_elec').fromChildren,
        0,
        reason:
            'a leaf reported spending rolled up from children it cannot have',
      );
      expect(_row(rows, 'cat_elec').parentId, 'cat_util');
      expect(_row(rows, 'cat_util').parentId, isNull);
    });

    test('a category outside the tree is untouched', () {
      expect(
        _row(categoryBudgets(_tree(), sampleAnchor), 'cat_food').spent,
        closeTo(250, 0.005),
      );
    });
  });

  group('and the total still adds up', () {
    test(
      'summing the TOP LEVEL equals every categorised peso, exactly once',
      () {
        final data = _tree();
        final rows = categoryBudgets(data, sampleAnchor);

        final top = rows
            .where((r) => r.parentId == null)
            .fold(0.0, (t, r) => t + r.spent);

        // 3,200 + 450 + 800 + 250. Every expense in the fixture is categorised,
        // so the month total is the same figure.
        expect(top, closeTo(4700, 0.005));
        expect(
          amountOf(budgetSummary(data, sampleAnchor)['spent']),
          closeTo(top, 0.005),
          reason:
              'the rows and the hero disagree about the month, which is the '
              'contradiction this app has already had to fix twice',
        );
      },
    );

    test('summing EVERY row double counts, which is why nothing may', () {
      // Not a bug, a property: the parent contains its children by design. This
      // test exists so the next person to write `rows.fold` sees in the suite
      // why they must filter to the top level first.
      final rows = categoryBudgets(_tree(), sampleAnchor);
      final all = rows.fold(0.0, (t, r) => t + r.spent);
      expect(
        all,
        closeTo(4700 + 3650, 0.005),
        reason:
            'summing every row no longer double counts, so either the rollup '
            'is gone or a parent stopped containing its children',
      );
    });
  });

  group('the shapes the store can hand us', () {
    test('a parentId pointing at nothing is treated as top level', () {
      // normalizeCategoryTree drops an orphan parentId on the next load, so
      // this is what the row looks like in the window before that happens.
      final data = _tree();
      (data['categories'] as List)[1]['parentId'] = 'cat_gone';
      final rows = categoryBudgets(data, sampleAnchor);

      expect(_row(rows, 'cat_elec').parentId, isNull);
      expect(
        _row(rows, 'cat_util').spent,
        closeTo(1250, 0.005),
        reason:
            'an orphaned child still rolled into a parent that no longer '
            'claims it, so 3,200 was counted in two places',
      );
      // And it is still its own row, so the money is visible somewhere.
      expect(_row(rows, 'cat_elec').spent, closeTo(3200, 0.005));
    });

    test('a category that is its own parent does not eat itself', () {
      final data = _tree();
      (data['categories'] as List)[0]['parentId'] = 'cat_util';
      final rows = categoryBudgets(data, sampleAnchor);
      expect(_row(rows, 'cat_util').spent, closeTo(4450, 0.005));
      expect(_row(rows, 'cat_util').parentId, isNull);
    });

    test('a parent with a cap and no spending anywhere still shows', () {
      final data = _tree();
      data['transactions'] = const [];
      final rows = categoryBudgets(data, sampleAnchor);
      expect(_row(rows, 'cat_util').cap, 5000);
      expect(_row(rows, 'cat_util').spent, 0);
      expect(
        rows.any((r) => r.id == 'cat_elec'),
        isFalse,
        reason:
            'a child with no cap and no spending earned a row, which fills the '
            'screen with empty rows on a fresh ledger',
      );
    });

    test('a parent with NO cap still earns a row once a child spends', () {
      final data = _tree(utilitiesCap: 0);
      (data['transactions'] as List).removeWhere(
        (t) => (t as Map)['id'] == 't_util',
      );
      final rows = categoryBudgets(data, sampleAnchor);
      expect(
        rows.any((r) => r.id == 'cat_util'),
        isTrue,
        reason:
            'Utilities has 3,650 underneath it and no row, so the grouping the '
            'user built is invisible on the one screen it was built for',
      );
      expect(_row(rows, 'cat_util').spent, closeTo(3650, 0.005));
    });
  });
}
