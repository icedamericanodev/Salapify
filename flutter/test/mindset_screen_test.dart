// The Money mindset flow: open from Tools, run the decision check to each of
// its three deterministic results, change an answer and see the result
// follow, clear the check, add a small win and see it listed, then delete it.
// Wins persist in data.wins through the store's guarded writes.
//
// The "What are you considering?" section (item, amount, category) and the
// budget impact it can surface are covered lower down, mounting the screen
// directly (the categories_screen_test.dart pattern) since none of that needs
// the full app shell.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob({
  bool pro = false,
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> transactions = const [],
}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, if (pro) 'pro': true},
  'categories': categories,
  'transactions': transactions,
};

String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

Future<SalapifyStore> _openDirect(
  WidgetTester tester,
  Map<String, dynamic> blob,
) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(MaterialApp(home: MindsetScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openMindset(WidgetTester tester) async {
  await openFromMenu(tester, 'Tools');
  await tester.scrollUntilVisible(
    find.text('Money mindset'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Money mindset'));
  await tester.pumpAndSettle();
}

/// Answers decision-check question [i] (0-indexed, in the order the screen
/// shows them) by tapping its Yes or No control.
Future<void> _answer(WidgetTester tester, int i, bool yes) async {
  final finder = find.text(yes ? 'Yes' : 'No').at(i);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the lesson card never shows a missing field as null or blank', () {
    test('a lesson with no title falls back to a safe title', () {
      final title = mindsetLessonTitle(const {
        'summary': 'Some summary',
        'icon': 'mind',
      });
      expect(title, isNot(contains('null')));
      expect(title.trim(), isNotEmpty);
    });

    test('a lesson with a blank title falls back the same way', () {
      final title = mindsetLessonTitle(const {'title': '   '});
      expect(title, isNot(contains('null')));
      expect(title.trim(), isNotEmpty);
    });

    test('a lesson with no summary falls back to a safe summary', () {
      final summary = mindsetLessonSummary(const {
        'title': 'Some title',
        'icon': 'mind',
      });
      expect(summary, isNot(contains('null')));
      expect(summary.trim(), isNotEmpty);
    });

    test('a completely empty lesson map still yields safe text', () {
      expect(mindsetLessonTitle(const {}), isNot(contains('null')));
      expect(mindsetLessonSummary(const {}), isNot(contains('null')));
    });

    testWidgets('the live screen never prints the word null anywhere', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('the decision check', () {
    testWidgets(
      'shows a neutral state until all three questions are answered',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
        expect(find.text('Fits your plan'), findsNothing);
        expect(find.text('Pause for 24 hours'), findsNothing);
        expect(find.text('Not in the plan right now'), findsNothing);
        expect(find.text('Clear check'), findsNothing);

        // Two of three answered is still incomplete.
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'essential and affordable, whether or not it waited: fits your plan',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, true); // affordable without touching reserved
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Fits your plan'), findsOneWidget);
        expect(find.text('Why this result'), findsOneWidget);
      },
    );

    testWidgets(
      'not essential, affordable, has not waited 24h: pause for 24 hours',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, false); // not essential
        await _answer(tester, 1, true); // affordable without touching reserved
        await _answer(tester, 2, false); // has not waited 24h

        expect(find.text('Pause for 24 hours'), findsOneWidget);
      },
    );

    testWidgets(
      'touches reserved money: not in the plan right now, even if essential',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, false); // would touch reserved money
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Not in the plan right now'), findsOneWidget);
      },
    );

    testWidgets('changing one answer updates the result', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      await _answer(tester, 0, false); // not essential
      await _answer(tester, 1, true); // affordable
      await _answer(tester, 2, false); // has not waited
      expect(find.text('Pause for 24 hours'), findsOneWidget);

      // Waiting 24 hours changes the answer, and the result follows it.
      await _answer(tester, 2, true);
      expect(find.text('Pause for 24 hours'), findsNothing);
      expect(find.text('Fits your plan'), findsOneWidget);
    });

    testWidgets('Clear check returns to the neutral state', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      await _answer(tester, 0, true);
      await _answer(tester, 1, true);
      await _answer(tester, 2, true);
      expect(find.text('Fits your plan'), findsOneWidget);

      final clear = find.text('Clear check');
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('Fits your plan'), findsNothing);
      expect(
        find.text('Answer all three questions to see where this fits.'),
        findsOneWidget,
      );
      expect(find.text('Clear check'), findsNothing);
    });
  });

  group('small wins', () {
    testWidgets('a small win can be added and removed', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await _openMindset(tester);
      await tester.scrollUntilVisible(
        find.text('SMALL WINS'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mindsetWinText')),
        'Packed lunch all week',
      );
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Packed lunch all week'), findsOneWidget);
      expect((store.data['wins'] as List).length, 1);

      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Packed lunch all week'), findsNothing);
      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);
      expect((store.data['wins'] as List).isEmpty, isTrue);
    });

    testWidgets('tapping delete on an imported win with no id does not crash', (
      tester,
    ) async {
      // A hand-edited backup can carry a win with no id (sanitize keeps wins
      // verbatim). The delete must no-op, not throw a cast error.
      SharedPreferences.setMockInitialValues({
        'salapify_data_v2': jsonEncode({
          'wins': [
            {'text': 'Legacy win', 'date': '2026-07-01'},
          ],
        }),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await _openMindset(tester);
      await tester.scrollUntilVisible(
        find.text('SMALL WINS'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Legacy win'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // The idless win cannot be targeted, so it stays and nothing throws.
      expect(tester.takeException(), isNull);
      expect(find.text('Legacy win'), findsOneWidget);
    });
  });

  group('what are you considering', () {
    testWidgets('item name and amount fields accept typed text', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await tester.enterText(
        find.byKey(const Key('mindsetItemName')),
        'New shoes',
      );
      await tester.enterText(find.byKey(const Key('mindsetAmount')), '1500');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New shoes'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
    });

    testWidgets('a blank amount is not treated as an error', (tester) async {
      await _openDirect(tester, _blob());

      expect(find.text('Enter a valid amount.'), findsNothing);
      expect(find.text('That amount is too large to check.'), findsNothing);
    });

    testWidgets('non-numeric and negative amounts show a validation message', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      final amountField = find.byKey(const Key('mindsetAmount'));

      await tester.enterText(amountField, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);

      await tester.enterText(amountField, '-100');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);

      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);
    });

    testWidgets('an excessive amount shows its own validation message', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await tester.enterText(
        find.byKey(const Key('mindsetAmount')),
        '9999999999999',
      );
      await tester.pumpAndSettle();

      expect(find.text('That amount is too large to check.'), findsOneWidget);
    });

    testWidgets('a category chip selects and deselects on tap', (tester) async {
      await _openDirect(
        tester,
        _blob(
          categories: [
            {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 0},
          ],
        ),
      );
      final chip = find.widgetWithText(ChoiceChip, '🍚 Food');
      expect(chip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);
    });

    testWidgets(
      'the decision check still reaches a verdict with none of these fields filled',
      (tester) async {
        await _openDirect(tester, _blob());

        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(find.text('Fits your plan'), findsOneWidget);
      },
    );
  });

  group('budget impact', () {
    List<Map<String, dynamic>> foodCategory(double cap) => [
      {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': cap},
    ];
    List<Map<String, dynamic>> spentThisMonth(double amount) => [
      {
        'id': 't1',
        'type': 'expense',
        'label': 'Jollibee',
        'amount': amount,
        'date': _todayIso(),
        'categoryId': 'food',
      },
    ];

    Future<void> fillConsider(
      WidgetTester tester, {
      required String amount,
    }) async {
      await tester.enterText(find.byKey(const Key('mindsetAmount')), amount);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.pumpAndSettle();
    }

    testWidgets('no impact shown without Pro, even with a cap stored', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          pro: false,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await fillConsider(tester, amount: '300');

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown without a selected category', (tester) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
      await tester.pumpAndSettle();

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown without a valid amount', (tester) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown when the category has no cap set', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(0),
          transactions: spentThisMonth(200),
        ),
      );

      await fillConsider(tester, amount: '300');

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets(
      'shows category remaining, purchase amount, and expected remaining when the data is reliable',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(200),
          ),
        );

        await fillConsider(tester, amount: '300');

        expect(find.textContaining('BUDGET IMPACT'), findsOneWidget);
        expect(find.text('Category budget remaining'), findsOneWidget);
        expect(find.text('₱800'), findsOneWidget); // remaining before
        expect(find.text('Purchase amount'), findsOneWidget);
        expect(find.text('₱300'), findsOneWidget);
        expect(find.text('Expected amount remaining'), findsOneWidget);
        expect(find.text('₱500'), findsOneWidget); // 800 - 300
      },
    );

    testWidgets(
      'warns and forces Not in the plan right now when the purchase would exceed the category budget',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(900), // ₱100 left before purchase
          ),
        );

        await fillConsider(tester, amount: '500'); // exceeds by ₱400

        expect(
          find.textContaining('over its ₱1,000 monthly cap'),
          findsOneWidget,
        );

        // Even answers that would otherwise fit the plan under phase 1 do
        // not override reliable budget data.
        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, true); // affordable, not reserved
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Not in the plan right now'), findsOneWidget);
        expect(find.text('Fits your plan'), findsNothing);
        // The clause now shows up twice: once in the budget impact card,
        // and once folded into "Why this result", per the founder's
        // result-integration rule.
        expect(
          find.textContaining('over its ₱1,000 monthly cap'),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'preserves the phase 1 result when the purchase stays within budget',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(200),
          ),
        );

        await fillConsider(tester, amount: '300'); // leaves ₱500, no warning

        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(find.text('Fits your plan'), findsOneWidget);
        expect(find.text('Not in the plan right now'), findsNothing);
      },
    );
  });

  group('clear check resets everything new too', () {
    testWidgets(
      'Clear check empties the item, amount, and category alongside the answers',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: [
              {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 1000},
            ],
          ),
        );

        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'New shoes',
        );
        await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.pumpAndSettle();
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);
        expect(find.text('Fits your plan'), findsOneWidget);

        await tester.ensureVisible(find.text('Clear check'));
        await tester.tap(find.text('Clear check'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetItemName')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetAmount')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '🍚 Food'))
              .selected,
          isFalse,
        );
        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
        expect(find.text('Clear check'), findsNothing);

        // Clearing the check is purely UI state; the founder's category is
        // still exactly what was loaded.
        expect((store.data['categories'] as List).length, 1);
      },
    );
  });

  group('the decision check never writes a financial record', () {
    testWidgets(
      'entering an item, amount, and category creates no transaction and moves no balance',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: [
              {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 1000},
            ],
          ),
        );

        final txnsBefore = jsonEncode(store.data['transactions']);
        final catsBefore = jsonEncode(store.data['categories']);

        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'New shoes',
        );
        await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.pumpAndSettle();
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(jsonEncode(store.data['transactions']), txnsBefore);
        expect(jsonEncode(store.data['categories']), catsBefore);
      },
    );
  });
}
