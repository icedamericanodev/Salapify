import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/debt/payment_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/state/financial_state.dart';

/// The debt payment write path, in BOTH halves.
///
/// Half one is in core/money/debt_test.dart, against vectors from the
/// prototype's own reducer.
///
/// THIS file is half two, and it exists because of a specific failure: a
/// founder paid 1,500 off a loan, opened the account it came out of, and found
/// NOTHING in its history. The balance had moved and no entry explained why.
/// Every money test was green, because every money test asked only whether the
/// money was right. So these tests tap to every screen that should now mention
/// the payment and assert it is genuinely on the screen there.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

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

  /// Home, then the debt beam's "See all", which is how a person gets here.
  ///
  /// Scrolled to by the CARD and not by the words "See all": several cards on
  /// Home carry that label, and `.first` on a finder matching nothing yet
  /// throws "Bad state: No element" before any scrolling can happen.
  Future<void> openDebts(WidgetTester tester) async {
    await pumpApp(tester);
    await reach(tester, find.byType(DebtBeamCard));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    expect(
      find.byType(DebtScreen),
      findsOneWidget,
      reason: 'the debt beam on Home did not open the register',
    );
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<DebtScreen>(find.byType(DebtScreen)).state;

  testWidgets('paying a debt moves the money AND leaves a trail a person can '
      'follow', (WidgetTester tester) async {
    await openDebts(tester);

    final FinancialState store = storeOf(tester);
    final double gcashBefore = store.accounts
        .firstWhere((Account a) => a.id == 'acc_gcash')
        .balance;
    final int entriesBefore = store.transactions.length;

    // Home Credit: 14,700 total, 7,350 paid, so 7,350 to go.
    expect(find.text('Home Credit (Phone)'), findsOneWidget);
    expect(find.text('Payment 3 of 6 · Due Sep 18'), findsOneWidget);

    await tapAndSettle(tester, find.text('Record a payment').first);
    expect(find.byType(PaymentSheet), findsOneWidget);

    // The sheet pre-fills what is left, so the commonest action is one tap.
    expect(find.widgetWithText(TextField, '7350'), findsOneWidget);

    // Pay part of it instead, from GCash.
    await tester.enterText(find.widgetWithText(TextField, '7350'), '2450');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('GCash Wallet'));

    // The consequence is stated BEFORE the tap, not discovered after it.
    expect(find.textContaining('₱4,900.00 will still be owed'), findsOneWidget);
    expect(
      find.textContaining('GCash Wallet goes down by ₱2,450.00'),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.text('Record the payment'));

    // --- half one, directional: both sides moved by exactly 2,450 ---------
    expect(
      store.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance,
      closeTo(gcashBefore - 2450, 0.001),
      reason: 'the account the money came out of must be 2,450 lighter',
    );
    expect(
      store.debts.firstWhere((Debt d) => d.id == 'debt_homecredit').paidAmount,
      9800,
    );
    expect(
      store.transactions.length,
      entriesBefore + 1,
      reason: 'exactly one entry, not zero and not two',
    );

    // --- half two: can a person FOLLOW it -------------------------------
    // Screen one, the debt register itself: the row now reads differently.
    expect(find.text('Payment 4 of 6 · Due Sep 18'), findsOneWidget);
    expect(find.text('₱4,900.00'), findsWidgets);

    // Screen two, Activity. THIS is the screen the founder opened and found
    // empty. An entry has to be here, by name, or the balance moved for no
    // visible reason.
    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    await tapAndSettle(tester, find.byIcon(Icons.menu_book_outlined));
    await reach(tester, find.text('Repayment to Home Credit (Phone)'));
    expect(
      find.text('Repayment to Home Credit (Phone)'),
      findsOneWidget,
      reason:
          'The balance moved and nothing in Activity says why. This is '
          'the exact defect this test file exists for.',
    );

    // Screen three, Accounts: GCash itself is 2,450 lighter on screen.
    await tapAndSettle(
      tester,
      find.byIcon(Icons.account_balance_wallet_outlined).last,
    );
    expect(find.text('₱5,970.50'), findsOneWidget, reason: '8,420.50 - 2,450');
  });

  testWidgets('collecting a receivable puts money IN, not out', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);
    final double gcashBefore = store.accounts
        .firstWhere((Account a) => a.id == 'acc_gcash')
        .balance;

    await tapAndSettle(tester, find.text('Owed to you'));
    expect(find.text('Kuya Mark'), findsOneWidget);

    await tapAndSettle(tester, find.text('Record a collection').first);
    await tester.enterText(find.widgetWithText(TextField, '5000'), '1500');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('GCash Wallet'));
    expect(
      find.textContaining('GCash Wallet goes up by ₱1,500.00'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('Record the collection'));

    expect(
      store.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance,
      closeTo(gcashBefore + 1500, 0.001),
      reason:
          'Being repaid is money coming IN. If this went down, the '
          'direction was read backwards and the row on screen would look '
          'perfectly normal either way.',
    );

    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    await tapAndSettle(tester, find.byIcon(Icons.menu_book_outlined));
    await reach(tester, find.text('Repayment from Kuya Mark'));
    expect(find.text('Repayment from Kuya Mark'), findsOneWidget);
  });

  testWidgets('paying with no account moves the debt and nothing else', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);
    final int entriesBefore = store.transactions.length;
    final double gcashBefore = store.accounts
        .firstWhere((Account a) => a.id == 'acc_gcash')
        .balance;

    await tapAndSettle(tester, find.text('Record a payment').first);
    await tester.enterText(find.widgetWithText(TextField, '7350'), '1000');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('No account, just the debt'));

    // It says so plainly before the tap, because a person who expected their
    // GCash to move and finds it unchanged will assume the app is broken.
    expect(find.textContaining('No account will change'), findsOneWidget);

    await tapAndSettle(tester, find.text('Record the payment'));

    expect(
      store.debts.firstWhere((Debt d) => d.id == 'debt_homecredit').paidAmount,
      8350,
      reason: 'the debt still moved, which is the point of the option',
    );
    expect(
      store.transactions.length,
      entriesBefore,
      reason: 'and no entry was invented out of an account that never held it',
    );
    expect(
      store.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance,
      gcashBefore,
    );
  });

  testWidgets('marking a debt settled writes no phantom payment', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);
    final int entriesBefore = store.transactions.length;
    final double gcashBefore = store.accounts
        .firstWhere((Account a) => a.id == 'acc_gcash')
        .balance;

    await tapAndSettle(tester, find.text('Mark settled').first);

    final Debt d = store.debts.firstWhere(
      (Debt x) => x.id == 'debt_homecredit',
    );
    expect(d.isSettled, isTrue);
    expect(
      d.paidAmount,
      14700,
      reason: '"settled" and "still owes 7,350" cannot both be true on one row',
    );
    expect(
      store.transactions.length,
      entriesBefore,
      reason:
          'Marking settled is a CORRECTION, not a movement. Writing an '
          'entry would invent a 7,350 payment out of an account that never '
          'lost the money, and the account and the ledger would then disagree '
          'by exactly that amount.',
    );
    expect(
      store.accounts.firstWhere((Account a) => a.id == 'acc_gcash').balance,
      gcashBefore,
    );

    // And it is visible as cleared rather than simply gone.
    await reach(tester, find.text('CLEARED'));
    expect(find.text('CLEARED'), findsOneWidget);
  });

  testWidgets('the beam and the totals agree with the register after a '
      'payment', (WidgetTester tester) async {
    await openDebts(tester);

    // 17,350 owed at the seed, and Accounts says the same thing.
    expect(find.text('₱17,350.00'), findsWidgets);

    await tapAndSettle(tester, find.text('Record a payment').first);
    await tester.enterText(find.widgetWithText(TextField, '7350'), '2450');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('GCash Wallet'));
    await tapAndSettle(tester, find.text('Record the payment'));

    // Back up to the beam. Tapping the card's button scrolled past it, and a
    // widget above the viewport is not built, so find.text reports "not
    // found" for a figure that is perfectly correct.
    await tester.scrollUntilVisible(
      find.text('YOU OWE'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('₱14,900.00'), findsWidgets, reason: '17,350 - 2,450');

    // And the Accounts register card, a different screen reading the same
    // debts, must say the same number.
    await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
    await tapAndSettle(
      tester,
      find.byIcon(Icons.account_balance_wallet_outlined).last,
    );
    await reach(tester, find.text('You owe people and lenders'));
    expect(
      find.text('₱14,900.00'),
      findsOneWidget,
      reason:
          'Two screens reading the same debts must never print two '
          'different totals.',
    );
  });
}
