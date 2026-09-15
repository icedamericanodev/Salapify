// Categories: the one rule is that hiding a LABEL never hides MONEY.
//
// The recovery pass on this feature ended SAFE WITH CONDITIONS, and the
// conditions are what this file holds. Chief among them: archive filters the
// PICKERS and nothing else, because a category that had 12,400 through it this
// month keeps its row on Plan and its slice in Insights, or hiding a word would
// hide a figure that is still inside the hero above it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/budget.dart' show budgetSummary;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/categories/category_rows.dart';
import 'package:salapify/features/insights/insight_rows.dart'
    show spendingByCategory;
import 'package:salapify/features/plan/budget_rows.dart' show categoryBudgets;

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

Map<String, dynamic> _cat(Map<String, dynamic> data, String id) =>
    allCategories(data).firstWhere((c) => c['id'] == id);

Map<String, dynamic> _hide(Map<String, dynamic> data, String id) {
  final out = Map<String, dynamic>.of(data);
  out['categories'] = [
    for (final c in allCategories(data))
      if (c['id'] == id) {...c, 'isArchived': true, 'monthlyCap': 0} else c,
  ];
  return out;
}

void main() {
  group('hiding a label never hides money', () {
    test('a hidden category KEEPS its Plan row and its spending', () {
      final before = livedIn();
      final row = categoryBudgets(
        before,
        sampleAnchor,
      ).firstWhere((r) => r.id == 'cat_groceries');
      // Did anything happen: the fixture really does have money through this
      // category, or the assertion below would be about an absent row.
      expect(
        row.spent,
        greaterThan(0),
        reason:
            'the fixture has no Groceries spending, so hiding it could not '
            'possibly hide any',
      );

      final after = _hide(before, 'cat_groceries');
      final kept = categoryBudgets(
        after,
        sampleAnchor,
      ).where((r) => r.id == 'cat_groceries');
      expect(
        kept,
        isNotEmpty,
        reason:
            'hiding Groceries took its row off Plan, so money that is still '
            'inside the hero figure has nothing on screen accounting for it',
      );
      expect(kept.first.spent, closeTo(row.spent, 0.005));
    });

    test('and its slice in Insights, under its own name', () {
      final before = livedIn();
      final was = spendingByCategory(before, sampleAnchor);
      final mine = was.firstWhere((s) => s.name == 'Groceries');
      expect(mine.amount, greaterThan(0));

      final after = spendingByCategory(
        _hide(before, 'cat_groceries'),
        sampleAnchor,
      );
      final still = after.where((s) => s.name == 'Groceries');
      expect(
        still,
        isNotEmpty,
        reason:
            'the spending moved into Uncategorised, so hiding a label rewrote '
            'history instead of narrowing a picker',
      );
      expect(still.first.amount, closeTo(mine.amount, 0.005));
    });

    test('and the month total does not move by one centavo', () {
      final before = livedIn();
      final after = _hide(before, 'cat_groceries');
      expect(
        amountOf(budgetSummary(after, sampleAnchor)['spent']),
        closeTo(amountOf(budgetSummary(before, sampleAnchor)['spent']), 0.005),
      );
    });
  });

  group('but it does leave the pickers', () {
    test('pickableCategories drops it, allCategories does not', () {
      final after = _hide(livedIn(), 'cat_groceries');
      expect(
        pickableCategories(after).any((c) => c['id'] == 'cat_groceries'),
        isFalse,
        reason: 'hiding a category did not take it out of the picker',
      );
      expect(
        allCategories(after).any((c) => c['id'] == 'cat_groceries'),
        isTrue,
        reason: 'the row was deleted rather than hidden',
      );
    });

    test('the flag is absent by default, never written as false', () {
      // Absence IS the default, the same rule the account flags follow, so a
      // backup carries exactly what it carried before this feature existed and
      // no golden fixture gains a key.
      for (final c in allCategories(livedIn())) {
        expect(c.containsKey('isArchived'), isFalse);
        expect(isArchivedCategory(c), isFalse);
      }
    });
  });

  group('what the confirmation promises', () {
    test('it names the cap in pesos, because that is what is lost', () {
      final data = livedIn();
      final groceries = _cat(data, 'cat_groceries');
      expect(amountOf(groceries['monthlyCap']), greaterThan(0));

      final said = hideConsequence(data, groceries);
      expect(said, contains('2,500'));
      expect(said, contains('monthly limit is removed'));
    });

    test('and says nothing about a cap when there is none', () {
      final data = livedIn();
      final fun = _cat(data, 'cat_fun');
      expect(amountOf(fun['monthlyCap']), 0);
      expect(hideConsequence(data, fun), isNot(contains('monthly limit')));
    });

    test('a category nothing points at can go completely', () {
      final data = livedIn();
      expect(canRemove(data, _cat(data, 'cat_fun')), isTrue);
      expect(
        canRemove(data, _cat(data, 'cat_groceries')),
        isFalse,
        reason:
            'a category with entries tagged to it was offered for outright '
            'removal, which rewrites stored history with no way back',
      );
    });
  });

  group('on the screen', () {
    testWidgets('hide Groceries, and Plan still shows its money', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final spentBefore = categoryBudgets(
        store.data,
        sampleAnchor,
      ).firstWhere((r) => r.id == 'cat_groceries').spent;

      // Reached by TAPPING, from Accounts to Settings to Categories, so this
      // also proves the door exists. A screen nobody can reach is not a
      // feature.
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Backup and settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup and settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Categories'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Bills now draws its two sub-categories (Electricity, Water) right
      // under it, which pushes Groceries below the fold. A fixed tap landed
      // on nothing the moment that grouping became visible; scrolling to the
      // target is the fix, not shrinking the list back to flat.
      await tester.scrollUntilVisible(
        find.text('Groceries'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(PillButton, 'Hide it'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Hide it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide it').last);
      await tester.pumpAndSettle();

      // It really was hidden, and the cap really did go with it.
      final after = _cat(store.data, 'cat_groceries');
      expect(
        isArchivedCategory(after),
        isTrue,
        reason: 'the write never landed',
      );
      expect(
        amountOf(after['monthlyCap']),
        0,
        reason:
            'the cap survived the hide, so Plan now draws a capped row that '
            'the budget editor can no longer list: a number nobody can change',
      );

      // AND THE MONEY IS STILL THERE. This is the half that gets forgotten.
      expect(
        categoryBudgets(
          store.data,
          sampleAnchor,
        ).firstWhere((r) => r.id == 'cat_groceries').spent,
        closeTo(spentBefore, 0.005),
        reason: 'hiding the label took the spending with it',
      );
    });

    testWidgets('the way to add one survives having no categories at all', (
      tester,
    ) async {
      // The Accounts bug, in a new place: hiding your only account hit an
      // empty-state early return that swallowed Settings and the backup behind
      // it. Zero categories is PERMANENT here, because _migration4 refills the
      // defaults only below schemaVersion 4 and a live ledger is at 12.
      final data = livedIn();
      data['categories'] = const [];
      final store = await memoryStore(data);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Backup and settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup and settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      expect(find.text('No categories yet'), findsOneWidget);
      expect(
        find.widgetWithText(PillButton, 'Add a category'),
        findsOneWidget,
        reason:
            'with no categories the only control that could make one is gone, '
            'so the state is a locked door',
      );
    });
  });
}
