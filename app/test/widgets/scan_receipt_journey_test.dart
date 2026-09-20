import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/log/scan_receipt_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
import 'package:salapify/state/financial_state.dart';

/// Scanning a receipt, in BOTH halves, the way CLAUDE.md requires.
///
/// Half one is whether the money moved correctly. Half two is whether a
/// person can FOLLOW it afterwards, and it is the half that gets forgotten:
/// a debt payment was once written perfectly and was invisible in the
/// account's own history, with every money test green.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<ActivityScreen>(find.byType(ActivityScreen)).state;

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Opens Log, then the scanner, and taps a sample.
  Future<void> openScanner(WidgetTester tester, String sample) async {
    // `.last` because Home carries TWO controls reading "Log": the quick
    // action in its own row and the accent pill in the tab bar. A bare
    // find.text throws "Too many elements" on Home and passes everywhere
    // else, which is the kind of test that works until somebody writes one
    // that does not navigate first.
    await tapAndSettle(tester, find.text('Log').last);
    await tapAndSettle(tester, find.text('Scan a receipt instead'));
    expect(find.byType(ScanReceiptSheet), findsOneWidget);
    await tapAndSettle(tester, find.text(sample));
  }

  testWidgets('a scanned receipt reaches the ledger and the account', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // The store before, read off a screen that is definitely built.
    await tapAndSettle(tester, find.text('Activity').last);
    final FinancialState state = storeOf(tester);
    final int txBefore = state.transactions.length;

    await openScanner(tester, 'Jollibee');

    // The parser filled the form. The amount is the TOTAL, not the 500 the
    // customer handed over nor the 287 sukli.
    expect(find.textContaining('213'), findsWidgets);

    // An account has to be chosen: the Jollibee slip names no wallet, so the
    // picker is deliberately empty and Confirm is disabled until it is set.
    await tapAndSettle(tester, find.text('Choose an account'));
    final Account cash = state.accounts.firstWhere((Account a) => a.isLiquid);
    await tapAndSettle(tester, find.text(cash.name).last);

    final double balanceBefore = state.accounts
        .firstWhere((Account a) => a.id == cash.id)
        .balance;

    await tapAndSettle(tester, find.text('Confirm and log'));

    // HALF ONE: the money moved, and by exactly the right amount.
    expect(state.transactions.length, txBefore + 1);
    final Transaction logged = state.transactions.first;
    expect(logged.amount, 213.00);
    expect(logged.type, TransactionType.expense);
    expect(logged.merchant, 'Jollibee');
    expect(
      state.accounts.firstWhere((Account a) => a.id == cash.id).balance,
      closeTo(balanceBefore - 213.00, 0.001),
      reason: 'the account did not fall by what was spent',
    );

    // The BIR fields came across, because the slip carries a TIN.
    expect(logged.isTaxDeductible, isTrue);
    expect(logged.taxTinOrRef, '000-408-495-000');

    // HALF TWO: a person can find it. Activity is where the app lands.
    expect(find.byType(ActivityScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jollibee'),
      findsWidgets,
      reason: 'the entry was saved and is nowhere a person would look',
    );
  });

  testWidgets('Undo takes it back out, and the balance with it', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('Activity').last);
    final FinancialState state = storeOf(tester);
    final int txBefore = state.transactions.length;

    await openScanner(tester, 'Jollibee');
    await tapAndSettle(tester, find.text('Choose an account'));
    final Account cash = state.accounts.firstWhere((Account a) => a.isLiquid);
    await tapAndSettle(tester, find.text(cash.name).last);
    final double balanceBefore = state.accounts
        .firstWhere((Account a) => a.id == cash.id)
        .balance;

    await tapAndSettle(tester, find.text('Confirm and log'));
    expect(state.transactions.length, txBefore + 1);

    await tapAndSettle(tester, find.text('Undo'));

    expect(
      state.transactions.length,
      txBefore,
      reason: 'the entry stayed in the ledger after Undo',
    );
    expect(
      state.accounts.firstWhere((Account a) => a.id == cash.id).balance,
      closeTo(balanceBefore, 0.001),
      reason:
          'the row went but the money did not come back, which leaves a '
          'balance nothing on any screen explains',
    );
    expect(find.textContaining('Taken back out'), findsOneWidget);
  });

  testWidgets('an e-wallet receipt suggests the matching account', (
    WidgetTester tester,
  ) async {
    // The GCash sample names its wallet, so the picker fills itself. The
    // parser still never sees the account list: it returns a KIND and the
    // sheet matches it, so a receipt naming nothing leaves this empty rather
    // than landing on whichever account happens to be first.
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('Activity').last);
    final FinancialState state = storeOf(tester);

    await openScanner(tester, 'GCash send');

    final Account gcash = state.accounts.firstWhere(
      (Account a) => a.kind == AccountKind.gcash,
    );
    expect(
      find.text(gcash.name),
      findsWidgets,
      reason: 'a receipt that named GCash did not preselect the GCash account',
    );
    expect(find.text('Choose an account'), findsNothing);
  });

  testWidgets('a receipt with no TIN is not offered as claimable', (
    WidgetTester tester,
  ) async {
    // The other half of that alarm. A scanner that ticked everything would
    // quietly propose claiming a transfer to a friend.
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('Activity').last);
    final FinancialState state = storeOf(tester);

    await openScanner(tester, 'GCash send');
    final Account gcash = state.accounts.firstWhere(
      (Account a) => a.kind == AccountKind.gcash,
    );
    await tapAndSettle(tester, find.text('Confirm and log'));

    final Transaction logged = state.transactions.first;
    expect(logged.accountId, gcash.id);
    expect(
      logged.isTaxDeductible,
      isFalse,
      reason: 'an e-wallet transfer was marked as a claimable expense',
    );
  });

  testWidgets('the samples say they are samples', (WidgetTester tester) async {
    // The prototype falls back to its Jollibee sample whenever a file name
    // matches nothing, so a photograph of any other receipt silently becomes
    // a Jollibee purchase carrying a stranger's TIN. Nothing here is
    // reachable except by tapping it, and the screen has to say so.
    await pumpApp(tester);
    await tapAndSettle(tester, find.text('Log').last);
    await tapAndSettle(tester, find.text('Scan a receipt instead'));
    expect(find.textContaining('made-up receipts'), findsOneWidget);
    expect(find.textContaining('unless you tap one'), findsOneWidget);
  });
}
