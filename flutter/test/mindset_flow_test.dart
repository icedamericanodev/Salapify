// The redesigned Money Mindset flow: walks the four steps and checks the
// action write-through lands in the store through the existing tested paths.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({List<Map<String, dynamic>>? goals}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  DateTime back(int m, int day) => DateTime(today.year, today.month - m, day);
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(back(m, 5)),
      'accountId': 'pay',
    });
  }
  return {
    'schemaVersion': 12,
    'settings': {'onboarded': true},
    'accounts': [
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 40000},
    ],
    'transactions': txns,
    'goals': ?goals,
  };
}

Future<SalapifyStore> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? goals,
}) async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(_blob(goals: goals)),
  });
  final store = SalapifyStore();
  await store.load();
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MindsetFlowScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _toDecision(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(1), '3000');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // step 2
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // step 3
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mindsetAnswer_0_true')));
  await tester.pumpAndSettle();
  // "No" to affording without reserved money hard-caps the band at a pause, so
  // the result always offers a Remind me action.
  await tester.tap(find.byKey(const Key('mindsetAnswer_1_false')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('skipping records a win and logs the check', (tester) async {
    final store = await _pump(tester);
    expect((store.data['wins'] as List?)?.length ?? 0, 0);

    await _toDecision(tester);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // A win was recorded and the check logged; nothing moved a balance.
    expect((store.data['wins'] as List).length, 1);
    expect(store.mindsetChecks.length, 1);
    expect(find.text('Your last 30 days'), findsOneWidget); // reached step 4
    // The all-time money-kept hero appears now that there is at least one win.
    expect(find.text('Money kept, all time'), findsOneWidget);
  });

  testWidgets('remind me records a waiting item', (tester) async {
    final store = await _pump(tester);
    expect(store.mindsetWaiting.length, 0);

    await _toDecision(tester);
    // The button names the day the reminder arrives ("Remind me on Aug 16"),
    // not a "in N days" count that did not match the actual 24h revisit.
    final remind = find.textContaining('Remind me on');
    expect(remind, findsOneWidget);
    await tester.tap(remind);
    await tester.pumpAndSettle();

    expect(store.mindsetWaiting.length, 1);
    // The stored revisit is one day out, the same date the button named.
    final revisit = DateTime.parse(
      store.mindsetWaiting.first['revisitAt'] as String,
    );
    final delta = revisit.difference(DateTime.now());
    expect(delta.inHours >= 22 && delta.inHours <= 26, true);
  });

  testWidgets('the Credit or BNPL path shows the flat add-on cost breakdown', (
    tester,
  ) async {
    await _pump(tester);
    // Choose the credit path.
    await tester.tap(find.text('Credit or BNPL'));
    await tester.pumpAndSettle();

    // The fee is labelled a one-time fee, never "interest per month".
    expect(find.text('One-time fee (% of price)'), findsOneWidget);

    // Price 20,000 on a 6-month plan (default) with a 3% one-time fee.
    await tester.enterText(find.byType(TextField).at(1), '20000');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();

    // extra = 600, total = 20,600, monthly = 3,433.33; the cost card shows them.
    expect(find.text('Monthly payment (approx.)'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('Extra cost'), findsOneWidget);
    expect(find.textContaining('20,600'), findsWidgets);
    expect(find.textContaining('600'), findsWidgets);
    // The honest annualized cost is surfaced, not just the small peso fee.
    expect(find.text('Real cost per year'), findsOneWidget);
  });

  testWidgets('the Credit path scores on the installment, not the full price', (
    tester,
  ) async {
    await _pump(tester); // income 32,000/mo, ~40,000 in accounts
    await tester.tap(find.text('Credit or BNPL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '20000');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // A ~3,433 installment against 32,000 income is not a "Big impact" buy. The
    // old bug (20,000 as both the cash out AND the monthly load) would have
    // scored it as one; the fix scores on the installment instead.
    expect(find.text('Big impact'), findsNothing);
    // The score section still renders its explainer, so we are on Step 2.
    expect(find.text('How we score this'), findsOneWidget);
  });

  testWidgets('the Subscription path compares monthly vs yearly', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '499');
    await tester.pumpAndSettle();

    // Default is Monthly: 499/mo and 5,988/yr (499 * 12).
    expect(find.text('Per month'), findsOneWidget);
    expect(find.text('Per year'), findsOneWidget);
    expect(find.textContaining('5,988'), findsWidgets);

    // Switch to Yearly: now 499 is the yearly figure, ~41.58/mo.
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('41'), findsWidgets); // 499/12 per month
  });

  testWidgets('the Impact step defines the score in plain words', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The explainer link is present, and opening it defines the score plainly.
    final link = find.text('How we score this');
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.textContaining('quick read, from 0 to 100'), findsOneWidget);
    expect(find.text('Cash left after'), findsWidgets);
    expect(find.textContaining('a guide, not a rule'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('goal impact shows separately and does not enter the score', (
    tester,
  ) async {
    final soon = DateTime.now().add(const Duration(days: 120));
    String iso(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    await _pump(
      tester,
      goals: [
        {
          'id': 'g1',
          'name': 'Emergency fund',
          'target': 100000,
          'saved': 82000,
          'targetDate': iso(soon),
        },
      ],
    );
    await tester.enterText(find.byType(TextField).at(1), '14990');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The goal card is its own section with before/after bars and an honest,
    // engine-backed delay shown as a chip.
    expect(find.text('WHAT THIS COSTS YOUR GOAL'), findsOneWidget);
    expect(find.textContaining('Emergency fund'), findsWidgets);
    expect(find.text('Before purchase'), findsOneWidget);
    expect(find.text('After purchase'), findsOneWidget);
    // The delay lives in the headline chip now ("about N months later").
    expect(find.textContaining('later'), findsOneWidget);
    // The peso opportunity cost is stated plainly in the footer.
    expect(find.textContaining('you could put toward'), findsOneWidget);

    // The score breakdown still lists ONLY the three real axes; the goal is not
    // a scored row, so the number never silently moved because of it.
    expect(find.text('Cash left after'), findsOneWidget);
    expect(find.text('Size vs income'), findsOneWidget);
    expect(find.text('Money for bills'), findsOneWidget);
  });

  testWidgets('a tiny buy on an emergency fund stays quiet, not "Careful"', (
    tester,
  ) async {
    final soon = DateTime.now().add(const Duration(days: 120));
    String iso(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    await _pump(
      tester,
      goals: [
        {
          'id': 'g1',
          'name': 'Emergency fund',
          'target': 100000,
          'saved': 82000,
          'targetDate': iso(soon),
        },
      ],
    );
    // A tiny buy (well under 25% of what is left) must not draw the strongest
    // alarm just because the deadline math nudges the date by a ceil period.
    await tester.enterText(find.byType(TextField).at(1), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Careful'), findsNothing);
    expect(find.textContaining('This is your emergency fund'), findsOneWidget);
    expect(find.textContaining('small slice'), findsOneWidget);
  });

  testWidgets('a buy just under what is left never reads "more than"', (
    tester,
  ) async {
    await _pump(
      tester,
      goals: [
        {
          'id': 'g3',
          'name': 'New phone',
          'target': 40000,
          'saved': 38005, // remaining 1,995
        },
      ],
    );
    // 1,990 is 99.75% of 1,995: it rounds to 100% but is still LESS than what is
    // left, so the copy must not claim "more than".
    await tester.enterText(find.byType(TextField).at(1), '1990');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('more than'), findsNothing);
    expect(find.textContaining('you could put toward'), findsOneWidget);
  });

  testWidgets('with no goals, the Impact step still shows a goal prompt', (
    tester,
  ) async {
    await _pump(tester); // default blob has no goals
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The section is always visible, now as a discoverable prompt.
    expect(find.text('WHAT THIS COSTS YOUR GOAL'), findsOneWidget);
    expect(find.textContaining('Set a savings goal'), findsOneWidget);
  });

  testWidgets('a buy that eats into bills money shows a plain short warning', (
    tester,
  ) async {
    await _pump(tester); // 40,000 on hand, nothing reserved
    // A small buy leaves the money for bills alone: plain "Bills covered", no
    // warning glyph.
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Money for bills'), findsOneWidget);
    expect(find.text('Bills covered'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    // Back to step 1, now a buy larger than everything on hand.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '60000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Money for bills'), findsOneWidget);
    // Plain wording, never the old "Dips" jargon, and a warning glyph so the
    // signal is not carried by color alone.
    expect(find.textContaining('short'), findsWidgets);
    expect(find.textContaining('Dips'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('the cash buffer card shows the peso cushion and a status', (
    tester,
  ) async {
    await _pump(tester); // 40,000 on hand
    await tester.enterText(find.byType(TextField).at(1), '3000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // A small buy leaves a cushion: the card is present and not the empties state.
    expect(find.text('CASH BUFFER AFTER PURCHASE'), findsOneWidget);
    expect(find.text('Empties it'), findsNothing);

    // A buy larger than everything on hand empties the cushion; the card and the
    // breakdown row both say so.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '60000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('CASH BUFFER AFTER PURCHASE'), findsOneWidget);
    expect(find.text('Empties it'), findsWidgets);
  });

  testWidgets('a goal with no deadline shows no fabricated day count', (
    tester,
  ) async {
    await _pump(
      tester,
      goals: [
        {
          'id': 'g2',
          'name': 'New phone',
          'target': 40000,
          'saved': 10000,
          // no targetDate: goalTradeoff must return a null delay
        },
      ],
    );
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('WHAT THIS COSTS YOUR GOAL'), findsOneWidget);
    // No deadline means no fabricated "about N months later" projection; instead
    // the card points the person at setting a target date.
    expect(find.textContaining('Set a target date'), findsOneWidget);
    expect(find.textContaining('months later'), findsNothing);
    expect(find.textContaining('paydays later'), findsNothing);
    expect(find.textContaining('weeks later'), findsNothing);
  });

  testWidgets('buying on credit offers to log the monthly payment', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Credit or BNPL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '20000');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // step 2
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // step 3
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_0_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_1_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mindsetAnswer_2_true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy anyway'));
    await tester.pumpAndSettle();

    // The result offers to log the plan so the next check sees the commitment.
    expect(find.text('Add to Recurring'), findsOneWidget);
  });

  testWidgets('the flow never records a transaction (read-only money)', (
    tester,
  ) async {
    final store = await _pump(tester);
    final txCount = (store.data['transactions'] as List).length;
    await _toDecision(tester);
    await tester.tap(find.text('Buy anyway'));
    await tester.pumpAndSettle();
    expect((store.data['transactions'] as List).length, txCount);
  });
}
