// Reports: stepping back a period, and the entries behind a category bar
// (D31), by tapping.
//
// The engine is test/core/money/report_period_test.dart. This is what a
// person does: opens Performance, taps a category, reads the same figure on
// the sheet that was on the bar, takes one entry back from inside it, and
// watches the sheet's total fall by exactly that entry; then steps back a
// month and finds the report saying which month it is showing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/activity/day_group.dart';
import 'package:salapify/screens/reports/category_entries_sheet.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  final DateTime fixtureToday = DateTime(2026, 9, 18, 12);

  Future<FinancialState> openPerformance(
    WidgetTester tester, {
    List<Transaction> extra = const <Transaction>[],
  }) async {
    await tester.runAsync(loadRealFonts);
    // Tall enough that the whole Performance tab is built: it is a lazy
    // list, and a card below the fold reads as absent whether or not it is.
    tester.view.physicalSize = const Size(1170, 14000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final FinancialState state = FinancialState(
      clock: fixtureToday,
      store: MemorySnapshotStore(),
    )..startWithExampleData();
    extra.forEach(state.logTransaction);
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insert_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Performance'));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  CategoryBreakdown foodRow(FinancialState s) => computeCategoryBreakdown(
    buildReports(
      transactions: s.transactions,
      accounts: s.accounts,
      period: ReportPeriod.monthly,
      now: s.now,
      debts: s.debts,
      plans: s.installments,
    ).transactions,
    TransactionType.expense,
  ).firstWhere((CategoryBreakdown c) => c.category == 'Food & Dining');

  testWidgets('a category opens its entries, the sheet total equals the bar, '
      'and taking one back moves it by exactly that entry', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openPerformance(tester);
    final CategoryBreakdown before = foodRow(state);
    expect(before.count, greaterThan(1), reason: 'fixture needs two or more');

    await tapIt(tester, find.text('Food & Dining'));
    expect(find.byType(CategoryEntriesSheet), findsOneWidget);
    final Finder total = find.byKey(const Key('category-sheet-total'));
    expect(tester.widget<Text>(total).data, formatPeso(before.total));
    expect(
      find.textContaining('of spending, ${before.count} entries'),
      findsOneWidget,
    );
    expect(find.text('This month'), findsWidgets);

    // Take the first listed entry back from its own sheet.
    final Finder rows = find.descendant(
      of: find.byType(CategoryEntriesSheet),
      matching: find.byType(TransactionRow),
    );
    expect(rows, findsNWidgets(before.count));
    final Transaction first = tester
        .widget<TransactionRow>(rows.first)
        .transaction;
    await tapIt(tester, rows.first);
    await tapIt(tester, find.text('Take this back'));
    await tapIt(tester, find.text('Take it back'));

    // Still on the category sheet, and it moved by exactly that entry.
    expect(find.byType(CategoryEntriesSheet), findsOneWidget);
    final double after = before.total - first.amount.pesos;
    expect(tester.widget<Text>(total).data, formatPeso(after));
    expect(foodRow(state).total, after, reason: 'the bar and sheet disagree');
    expect(rows, findsNWidgets(before.count - 1));
  });

  testWidgets('stepping back says which month it shows, says plainly when a '
      'past month is empty, stops at the oldest entry, and a chip lands back '
      'on now', (WidgetTester tester) async {
    // Every example entry is in September, so the test brings one July
    // entry of its own; August between them is empty.
    await openPerformance(
      tester,
      extra: <Transaction>[
        const Transaction(
          id: 'tx_july',
          type: TransactionType.expense,
          amount: Money.pesos(640),
          category: 'Food & Dining',
          accountId: 'acc_cash',
          date: '2026-07-10',
          createdAt: 1,
        ),
      ],
    );
    final Finder label = find.byKey(const Key('report-period-label'));
    final Finder back = find.byTooltip('Previous month');
    IconButton arrow() => tester.widget<IconButton>(
      find.ancestor(of: back, matching: find.byType(IconButton)).first,
    );
    expect(tester.widget<Text>(label).data, 'This month');
    expect(find.text('THIS MONTH VS LAST MONTH'), findsOneWidget);

    await tapIt(tester, back);
    expect(tester.widget<Text>(label).data, 'Aug 2026');
    // "yet" is gone, because August is over.
    expect(find.text('No entries in Aug 2026.'), findsOneWidget);
    expect(
      find.text('THIS MONTH VS LAST MONTH'),
      findsNothing,
      reason: 'a card that only knows this month showed on August',
    );

    await tapIt(tester, back);
    expect(tester.widget<Text>(label).data, 'Jul 2026');
    expect(find.text('From 1 entry'), findsOneWidget);
    expect(find.text('₱640.00'), findsWidgets);
    expect(arrow().onPressed, isNull, reason: 'stepped past the oldest entry');

    await tapIt(tester, find.text('Month'));
    expect(tester.widget<Text>(label).data, 'This month');
    expect(find.text('THIS MONTH VS LAST MONTH'), findsOneWidget);
  });
}
