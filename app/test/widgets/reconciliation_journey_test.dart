import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/reports/reports_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Reconciliation, the only Reports tab that writes.
///
/// The design decision these tests exist to protect: a gap between the app and
/// the bank is closed by POSTING AN ENTRY, never by editing the balance. An
/// account whose history does not add up to its own balance is worse than the
/// discrepancy it started with, and the only way to catch that regression is
/// to walk to Activity afterwards and look.
void main() {
  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> reach(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCheck(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.insert_chart_outlined));
    await tapAndSettle(tester, find.text('Check'));
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<ReportsScreen>(find.byType(ReportsScreen)).state;

  double balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  testWidgets('it opens showing what Salapify thinks the account holds', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);

    // Cash on Hand is the first account, at 1,850.
    expect(find.text('SALAPIFY SAYS'), findsOneWidget);
    expect(find.text('₱1,850.00'), findsWidgets);
    expect(
      find.textContaining('Open your bank or e-wallet app'),
      findsOneWidget,
      reason:
          'before anything is typed it should say what to do, not show a '
          'variance of zero as though it had checked something',
    );
  });

  testWidgets('a statement that is HIGHER posts income, and says so first', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);
    final FinancialState store = storeOf(tester);
    final double before = balanceOf(store, 'acc_cash');
    final int entriesBefore = store.transactions.length;

    await tester.enterText(find.byType(TextField).first, '1950');
    await tester.pumpAndSettle();

    expect(find.textContaining('₱100.00 MORE in the account'), findsOneWidget);
    await reach(tester, find.textContaining('goes UP by ₱100.00'));
    expect(
      find.textContaining('filed as found cash'),
      findsOneWidget,
      reason: 'the consequence is stated before the button, not after it',
    );

    await tapAndSettle(tester, find.text('Post the adjustment'));

    // The balance moved...
    expect(balanceOf(store, 'acc_cash'), closeTo(before + 100, 0.001));
    // ...and an ENTRY moved it. This is the whole design.
    expect(
      store.transactions.length,
      entriesBefore + 1,
      reason:
          'If the balance moved without an entry, the account\'s history '
          'no longer adds up to its own balance, which for anybody who keeps '
          'books is worse than the gap they started with.',
    );

    final Transaction posted = store.transactions.first;
    expect(posted.type, TransactionType.income);
    expect(posted.status, TransactionStatus.reconciled);
    expect(posted.category, 'Adjustments & Found Cash');
  });

  testWidgets('a statement that is LOWER posts an expense', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);
    final FinancialState store = storeOf(tester);
    final double before = balanceOf(store, 'acc_cash');

    await tester.enterText(find.byType(TextField).first, '1600');
    await tester.pumpAndSettle();
    expect(find.textContaining('₱250.00 LESS in the account'), findsOneWidget);

    await tapAndSettle(tester, find.text('Post the adjustment'));

    expect(balanceOf(store, 'acc_cash'), closeTo(before - 250, 0.001));
    expect(store.transactions.first.type, TransactionType.expense);
    expect(store.transactions.first.category, 'Adjustments & Write-offs');
  });

  testWidgets('the adjustment is findable in Activity afterwards', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);

    await tester.enterText(find.byType(TextField).first, '1950');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Post the adjustment'));

    await tapAndSettle(tester, find.byIcon(Icons.menu_book_outlined));
    await reach(
      tester,
      find.text('Reconciliation adjustment (Cash on Hand (Pitaka))'),
    );
    expect(
      find.text('Reconciliation adjustment (Cash on Hand (Pitaka))'),
      findsOneWidget,
      reason:
          'The entry has to be findable by somebody who opens the account '
          'in six months and asks why the balance jumped.',
    );
  });

  testWidgets('a matching statement records the check and moves nothing', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);
    final FinancialState store = storeOf(tester);
    final double before = balanceOf(store, 'acc_cash');
    final int entriesBefore = store.transactions.length;

    await tester.enterText(find.byType(TextField).first, '1850');
    await tester.pumpAndSettle();
    expect(find.text('They match.'), findsOneWidget);
    expect(
      find.text('Post the adjustment'),
      findsNothing,
      reason: 'there is nothing to adjust, so the button must not be offered',
    );

    await tapAndSettle(tester, find.text('Record the check'));

    expect(balanceOf(store, 'acc_cash'), before);
    expect(store.transactions.length, entriesBefore);
    expect(store.reconciliations, hasLength(1));
    expect(store.reconciliations.single.balanced, isTrue);

    // And it is kept where somebody can see it.
    await reach(tester, find.text('CHECKS YOU HAVE DONE'));
    expect(find.text('CHECKS YOU HAVE DONE'), findsOneWidget);
  });

  testWidgets('the duplicate finder suggests and does not act on its own', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);
    final FinancialState store = storeOf(tester);
    final List<TransactionStatus> before = store.transactions
        .map((Transaction t) => t.status)
        .toList();

    await reach(tester, find.text('POSSIBLE DOUBLE ENTRIES'));
    expect(find.textContaining('it has not changed anything'), findsOneWidget);
    expect(
      store.transactions.map((Transaction t) => t.status).toList(),
      before,
      reason:
          'Two identical fares on one day are two real fares. Merely '
          'LOOKING at the list must not change a single status.',
    );
  });

  testWidgets('marking a duplicate changes the totals but not the money', (
    WidgetTester tester,
  ) async {
    await openCheck(tester);
    final FinancialState store = storeOf(tester);

    await reach(tester, find.text('Mark the second one a duplicate'));
    final int before = store.transactions
        .where((Transaction t) => t.status == TransactionStatus.duplicate)
        .length;
    final double cashBefore = balanceOf(store, 'acc_cash');

    await tapAndSettle(
      tester,
      find.text('Mark the second one a duplicate').first,
    );

    expect(
      store.transactions
          .where((Transaction t) => t.status == TransactionStatus.duplicate)
          .length,
      before + 1,
    );
    expect(
      balanceOf(store, 'acc_cash'),
      cashBefore,
      reason:
          'marking is a judgement about what an entry MEANS, not a '
          'movement of money',
    );
  });

  testWidgets('nothing on the check tab overflows at 320dp', (
    WidgetTester tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openCheck(tester);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, '1600');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'the fix card overflowed');
  });
}
