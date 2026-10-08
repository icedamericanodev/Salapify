// applyNewBudget and budgetableCategories, the rules behind "Add a budget"
// (founder direction 2026-10-08). Net-new math with no prototype
// counterpart, so unit tests rather than a golden replay.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/plan.dart';
import 'package:salapify/models/models.dart';

const Budget _food = Budget(
  category: 'Food & Dining',
  limit: Money.pesos(5000),
  emoji: '🍔',
);

void main() {
  group('applyNewBudget', () {
    test('adds a budget at the end of the list', () {
      final List<Budget> next = applyNewBudget(
        const <Budget>[_food],
        category: 'Groceries',
        emoji: '🛒',
        limit: const Money.pesos(8000),
      );
      expect(next, hasLength(2));
      expect(next.first.category, 'Food & Dining');
      expect(next.last.category, 'Groceries');
      expect(next.last.limit, const Money.pesos(8000));
      expect(next.last.isSample, isFalse, reason: 'it is the person\'s own');
    });

    test('refuses a second budget for a category that has one', () {
      const List<Budget> before = <Budget>[_food];
      final List<Budget> next = applyNewBudget(
        before,
        category: 'Food & Dining',
        emoji: '🍔',
        limit: const Money.pesos(9000),
      );
      expect(identical(next, before), isTrue);
    });

    test('refuses a limit of zero or less', () {
      const List<Budget> before = <Budget>[];
      for (final Money bad in <Money>[Money.zero, const Money.pesos(-1)]) {
        expect(
          identical(
            applyNewBudget(
              before,
              category: 'Groceries',
              emoji: '🛒',
              limit: bad,
            ),
            before,
          ),
          isTrue,
        );
      }
    });

    test('refuses an empty category name', () {
      const List<Budget> before = <Budget>[];
      expect(
        identical(
          applyNewBudget(
            before,
            category: '  ',
            emoji: '',
            limit: const Money.pesos(100),
          ),
          before,
        ),
        isTrue,
      );
    });
  });

  test('budgetableCategories leaves out income and taken categories', () {
    const List<CategoryInfo> cats = <CategoryInfo>[
      CategoryInfo(
        id: 'food',
        name: 'Food & Dining',
        emoji: '🍔',
        subcategories: <String>[],
      ),
      CategoryInfo(
        id: 'groc',
        name: 'Groceries',
        emoji: '🛒',
        subcategories: <String>[],
      ),
      CategoryInfo(
        id: 'pay',
        name: 'Salary',
        emoji: '💼',
        subcategories: <String>[],
        kind: CategoryKind.income,
      ),
      CategoryInfo(
        id: 'both',
        name: 'Side gigs',
        emoji: '🧰',
        subcategories: <String>[],
        kind: CategoryKind.both,
      ),
    ];
    expect(
      budgetableCategories(cats, const <Budget>[
        _food,
      ]).map((CategoryInfo c) => c.name),
      <String>['Groceries', 'Side gigs'],
    );
  });
}
