// Money Mindset Phase 5: the purchase-type picker (One-time / Subscription
// / Credit or BNPL), the subscription and credit summary cards, and the
// read-only goal trade-off. Mounts MindsetScreen directly, the same
// _openDirect pattern mindset_screen_test.dart's own "what are you
// considering" and "budget impact" groups already use, since none of this
// needs the full app shell.
//
// The Phase 2 one-time flow itself (its own fields, validation, and budget
// impact) is already covered there and is left untouched by this file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({
  List<Map<String, dynamic>> debts = const [],
  List<Map<String, dynamic>> goals = const [],
  List<Map<String, dynamic>> recurring = const [],
  List<Map<String, dynamic>> transactions = const [],
}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'debts': debts,
  'goals': goals,
  'recurring': recurring,
  'transactions': transactions,
};

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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectPurchaseType(WidgetTester tester, String label) =>
    _tap(tester, find.text(label));

/// Answers decision-check question [i] (0-indexed) by tapping Yes, the same
/// pattern mindset_screen_test.dart's own _answer helper uses.
Future<void> _answerYes(WidgetTester tester, int i) =>
    _tap(tester, find.text('Yes').at(i));

void main() {
  group('purchase type selector', () {
    testWidgets('defaults to One-time and preserves the Phase 2 fields', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      expect(find.byKey(const Key('mindsetAmount')), findsOneWidget);
      expect(find.byKey(const Key('mindsetSubAmount')), findsNothing);
      expect(find.byKey(const Key('mindsetCreditCash')), findsNothing);
    });

    testWidgets('switching to Subscription swaps the fields shown', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await _selectPurchaseType(tester, 'Subscription');

      expect(find.byKey(const Key('mindsetSubAmount')), findsOneWidget);
      expect(find.byKey(const Key('mindsetAmount')), findsNothing);
      expect(find.byKey(const Key('mindsetCreditCash')), findsNothing);
    });

    testWidgets('switching to Credit or BNPL swaps the fields shown', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await _selectPurchaseType(tester, 'Credit or BNPL');

      expect(find.byKey(const Key('mindsetCreditCash')), findsOneWidget);
      expect(find.byKey(const Key('mindsetCreditDown')), findsOneWidget);
      expect(find.byKey(const Key('mindsetCreditInstallment')), findsOneWidget);
      expect(
        find.byKey(const Key('mindsetCreditInstallmentsCount')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mindsetCreditFees')), findsOneWidget);
      expect(find.byKey(const Key('mindsetAmount')), findsNothing);
      expect(find.byKey(const Key('mindsetSubAmount')), findsNothing);
    });
  });

  group('subscription: monthly and annual equivalents', () {
    testWidgets('nothing shows until a usable amount is typed', (tester) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Subscription');

      expect(find.text('Monthly equivalent'), findsNothing);
      expect(find.text('Annual equivalent'), findsNothing);
    });

    testWidgets('a monthly subscription shows itself as both figures', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Subscription');

      await tester.enterText(find.byKey(const Key('mindsetSubAmount')), '149');
      await tester.pumpAndSettle();

      expect(find.text('Monthly equivalent'), findsOneWidget);
      expect(find.text('₱149'), findsOneWidget);
      expect(find.text('Annual equivalent'), findsOneWidget);
      expect(find.text('₱1,788'), findsOneWidget);
    });

    testWidgets('switching to Weekly recomputes both equivalents', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Subscription');
      await tester.enterText(find.byKey(const Key('mindsetSubAmount')), '100');
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Weekly'));

      expect(find.text('₱5,200'), findsOneWidget); // annual: 100 * 52
    });

    testWidgets('a missing amount shows no equivalents, never a crash', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Subscription');

      await tester.enterText(find.byKey(const Key('mindsetSubAmount')), 'abc');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Enter a valid amount.'), findsOneWidget);
      expect(find.text('Monthly equivalent'), findsNothing);
    });
  });

  group('credit or BNPL: total repayment', () {
    Future<void> fillCredit(
      WidgetTester tester, {
      required String cash,
      String down = '',
      required String installment,
      required String count,
      String fees = '',
    }) async {
      await tester.enterText(find.byKey(const Key('mindsetCreditCash')), cash);
      if (down.isNotEmpty) {
        await tester.enterText(
          find.byKey(const Key('mindsetCreditDown')),
          down,
        );
      }
      await tester.enterText(
        find.byKey(const Key('mindsetCreditInstallment')),
        installment,
      );
      await tester.enterText(
        find.byKey(const Key('mindsetCreditInstallmentsCount')),
        count,
      );
      if (fees.isNotEmpty) {
        await tester.enterText(
          find.byKey(const Key('mindsetCreditFees')),
          fees,
        );
      }
      await tester.pumpAndSettle();
    }

    testWidgets('missing fields show no summary card', (tester) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Credit or BNPL');

      // Only cash price typed; installment and count are still blank.
      await tester.enterText(
        find.byKey(const Key('mindsetCreditCash')),
        '12000',
      );
      await tester.pumpAndSettle();

      expect(find.text('Total repayment'), findsNothing);
    });

    testWidgets(
      'a fee-free plan that exactly covers the cash price reads as truly '
      'free, in the summary card and in Why this result',
      (tester) async {
        await _openDirect(tester, _blob());
        await _selectPurchaseType(tester, 'Credit or BNPL');

        // down 2000 + 10 installments of 1000 = 12000, matching the cash
        // price exactly: down + fee + monthly*months - cash = 0.
        await fillCredit(
          tester,
          cash: '12000',
          down: '2000',
          installment: '1000',
          count: '10',
        );

        expect(find.text('Total repayment'), findsOneWidget);
        expect(find.text('₱12,000'), findsWidgets); // cash price and total
        expect(find.text('Extra cost'), findsOneWidget);
        expect(find.text('₱0'), findsOneWidget);

        // Answer the three questions to see Why this result too.
        await _answerYes(tester, 0);
        await _answerYes(tester, 1);
        await _answerYes(tester, 2);

        expect(find.textContaining('costs nothing extra'), findsOneWidget);
      },
    );

    testWidgets('a known fee shows up as extra cost over the cash price', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Credit or BNPL');

      await fillCredit(
        tester,
        cash: '12000',
        down: '2000',
        installment: '1000',
        count: '10',
        fees: '500',
      );

      expect(find.text('Total repayment'), findsOneWidget);
      expect(find.text('₱12,500'), findsOneWidget);
      expect(find.text('₱500'), findsWidgets); // fee shows inside the total
      expect(find.text('Monthly payment'), findsOneWidget);
      expect(find.text('₱1,000'), findsOneWidget);

      await _answerYes(tester, 0);
      await _answerYes(tester, 1);
      await _answerYes(tester, 2);

      expect(
        find.textContaining('costs ₱500 more than the ₱12,000 cash price'),
        findsOneWidget,
      );
    });

    testWidgets('existing debt minimums show only when a real one is on file', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          debts: [
            {
              'id': 'd1',
              'name': 'Credit card',
              'type': 'credit card',
              'remaining': 5000.0,
              'minPayment': 500.0,
            },
          ],
        ),
      );
      await _selectPurchaseType(tester, 'Credit or BNPL');

      await fillCredit(tester, cash: '12000', installment: '1000', count: '12');

      expect(find.text('Debt minimums'), findsOneWidget);
      expect(find.text('₱500'), findsOneWidget);
    });

    testWidgets('no debt on file means no existing-commitments row', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      await _selectPurchaseType(tester, 'Credit or BNPL');

      await fillCredit(tester, cash: '12000', installment: '1000', count: '12');

      expect(find.text('Debt minimums'), findsNothing);
    });

    testWidgets(
      'selecting Credit or BNPL never forces Not in the plan on its own',
      (tester) async {
        await _openDirect(tester, _blob());
        await _selectPurchaseType(tester, 'Credit or BNPL');
        await fillCredit(
          tester,
          cash: '12000',
          down: '2000',
          installment: '1000',
          count: '10',
          fees: '500',
        );

        await _answerYes(tester, 0);
        await _answerYes(tester, 1);
        await _answerYes(tester, 2);

        expect(find.text('Fits your plan'), findsOneWidget);
        expect(find.text('Not in the plan right now'), findsNothing);
      },
    );
  });

  group('goal trade-off', () {
    testWidgets('no goals on file means no comparison section at all', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      expect(find.text('COMPARE TO A GOAL (OPTIONAL)'), findsNothing);
    });

    testWidgets(
      'selecting a goal and an amount shows purchase amount, remaining, '
      'and the percentage',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            goals: [
              {
                'id': 'g1',
                'name': 'Laptop fund',
                'target': 40000.0,
                'saved': 10000.0,
              },
            ],
          ),
        );

        expect(find.text('COMPARE TO A GOAL (OPTIONAL)'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('mindsetAmount')), '3000');
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Laptop fund'));

        expect(find.text('Purchase amount'), findsOneWidget);
        expect(find.text('₱3,000'), findsOneWidget);
        expect(find.text('Goal remaining'), findsOneWidget);
        expect(find.text('₱30,000'), findsOneWidget); // 40000 - 10000
        expect(find.text('Percent left'), findsOneWidget);
        expect(find.text('10%'), findsOneWidget); // 3000 / 30000
      },
    );

    testWidgets('a goal with no amount typed shows chips but no card', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          goals: [
            {
              'id': 'g1',
              'name': 'Laptop fund',
              'target': 40000.0,
              'saved': 10000.0,
            },
          ],
        ),
      );

      await _tap(tester, find.text('Laptop fund'));

      expect(find.text('Purchase amount'), findsNothing);
    });
  });

  group(
    'nothing here is ever a transaction, a debt change, or a goal change',
    () {
      testWidgets(
        'running through all three purchase types and a goal selection '
        'leaves debts, goals, recurring, and transactions untouched',
        (tester) async {
          final blob = _blob(
            debts: [
              {
                'id': 'd1',
                'name': 'Credit card',
                'type': 'credit card',
                'remaining': 5000.0,
                'minPayment': 500.0,
              },
            ],
            goals: [
              {
                'id': 'g1',
                'name': 'Laptop fund',
                'target': 40000.0,
                'saved': 10000.0,
              },
            ],
            recurring: [
              {
                'id': 'r1',
                'type': 'expense',
                'label': 'Netflix',
                'amount': 149.0,
                'dayOfMonth': 5,
              },
            ],
            transactions: [
              {
                'id': 't1',
                'type': 'expense',
                'label': 'Groceries',
                'amount': 500.0,
                'date': '2026-07-01',
              },
            ],
          );
          final store = await _openDirect(tester, blob);
          final before = jsonEncode({
            'debts': store.data['debts'],
            'goals': store.data['goals'],
            'recurring': store.data['recurring'],
            'transactions': store.data['transactions'],
          });

          // One-time: type item, amount, category-less purchase.
          await tester.enterText(
            find.byKey(const Key('mindsetItemName')),
            'New shoes',
          );
          await tester.enterText(
            find.byKey(const Key('mindsetAmount')),
            '1500',
          );
          await tester.pumpAndSettle();

          // Subscription.
          await _selectPurchaseType(tester, 'Subscription');
          await tester.enterText(
            find.byKey(const Key('mindsetSubAmount')),
            '149',
          );
          await tester.pumpAndSettle();

          // Credit or BNPL.
          await _selectPurchaseType(tester, 'Credit or BNPL');
          await tester.enterText(
            find.byKey(const Key('mindsetCreditCash')),
            '12000',
          );
          await tester.enterText(
            find.byKey(const Key('mindsetCreditDown')),
            '2000',
          );
          await tester.enterText(
            find.byKey(const Key('mindsetCreditInstallment')),
            '1000',
          );
          await tester.enterText(
            find.byKey(const Key('mindsetCreditInstallmentsCount')),
            '10',
          );
          await tester.pumpAndSettle();

          // Goal trade-off.
          await _tap(tester, find.text('Laptop fund'));

          // Answer the three questions to reach and log a verdict too.
          await _answerYes(tester, 0);
          await _answerYes(tester, 1);
          await _answerYes(tester, 2);

          final after = jsonEncode({
            'debts': store.data['debts'],
            'goals': store.data['goals'],
            'recurring': store.data['recurring'],
            'transactions': store.data['transactions'],
          });
          expect(after, before);
        },
      );
    },
  );
}
