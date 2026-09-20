import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/state/financial_state.dart';

/// The Accounts write path, in BOTH halves, the way CLAUDE.md requires.
///
/// Half one, did the money move correctly, lives in core/money/accounts_test
/// and in accounts_test.dart's own assertions about the hero.
///
/// THIS file is half two: can a person FOLLOW it afterwards. It taps to every
/// other screen that should now mention the new account and asserts it is
/// genuinely on screen there. That half is the one that gets forgotten, and
/// it is the one that caught a real defect before: a debt payment was written
/// perfectly and was invisible in the account's own history, with every money
/// test green the whole time.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<AccountsScreen>(find.byType(AccountsScreen)).state;

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon).last);
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

  testWidgets(
    'a new bank account reaches Accounts, Reports and the Log sheet',
    (WidgetTester tester) async {
      await pumpApp(tester);
      await openTab(tester, Icons.account_balance_wallet_outlined);

      final double before = storeOf(tester).accounts.fold<double>(
        0,
        (double s, dynamic a) => s + (a.balance as double),
      );

      await tapAndSettle(tester, find.text('Add'));
      await tapAndSettle(tester, find.text('Bank'));
      await tester.enterText(
        find.widgetWithText(TextField, 'BPI Payroll, GCash Main, Pag-IBIG MP2'),
        'Tonik Stash',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '7500');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Add account'));

      // The did-anything-happen check, and a DIRECTIONAL one: the store is
      // heavier by exactly 7,500. "The account list is not empty" would pass
      // with the whole write deleted.
      final double after = storeOf(tester).accounts.fold<double>(
        0,
        (double s, dynamic a) => s + (a.balance as double),
      );
      expect(after - before, closeTo(7500, 0.001));

      // Screen one: Accounts itself, in the Bank Accounts group.
      expect(find.text('Tonik Stash'), findsOneWidget);
      // Four: BPI payroll, MariBank savings, the UnionBank debit card, and the
      // one just added. The group is banks AND debit cards.
      expect(find.text('Bank Accounts (4)'), findsOneWidget);

      // Screen two: Reports. Its Position tab reads the same accounts, so
      // assets must be 7,500 heavier. This is the assertion that would have
      // caught two screens quietly disagreeing about the same money.
      await openTab(tester, Icons.insert_chart_outlined);
      expect(
        find.text('-₱209,729.50'),
        findsOneWidget,
        reason:
            'net worth was -217,229.50 and 7,500 of savings just arrived. '
            'If Reports still says -217,229.50 the two screens disagree about '
            'money the user can see on both of them.',
      );
      // .first, because Position prints total assets in the summary AND again
      // in the breakdown, and scrollUntilVisible needs one target.
      await reach(tester, find.text('₱189,470.50').first);
      expect(find.text('₱189,470.50'), findsWidgets, reason: 'total assets');

      // Screen three: the Log sheet. An account somebody just created has to be
      // spendable from, or it is a row in a list and nothing more.
      await tapAndSettle(tester, find.text('Log').last);
      await reach(tester, find.text('Tonik Stash'));
      expect(
        find.text('Tonik Stash'),
        findsWidgets,
        reason:
            'a new account that cannot be chosen when logging a spend is '
            'decoration, not an account',
      );
    },
  );

  testWidgets('a credit card added here is counted as something you OWE', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, Icons.account_balance_wallet_outlined);

    await tapAndSettle(tester, find.text('Add'));
    await tapAndSettle(tester, find.text('Credit card'));
    await tester.enterText(
      find.widgetWithText(TextField, 'BPI Payroll, GCash Main, Pag-IBIG MP2'),
      'Gadget Card',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5000');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Add account'));

    // Net worth must go DOWN by 5,000, not up. A card balance landing on the
    // asset side is the single worst arithmetic mistake this screen could
    // make, and it would look completely normal on the row itself.
    expect(
      find.text('-₱222,229.50'),
      findsOneWidget,
      reason:
          'a 5,000 card balance is 5,000 owed. If this reads '
          '-212,229.50 the card was counted as savings.',
    );

    await openTab(tester, Icons.insert_chart_outlined);
    expect(
      find.text('-₱222,229.50'),
      findsOneWidget,
      reason: 'and Reports agrees, from the same accounts',
    );
  });

  testWidgets('the sheet no longer claims that nothing is saved', (
    WidgetTester tester,
  ) async {
    // THIS TEST USED TO ASSERT THE OPPOSITE, and it was right to, for as
    // long as it was true. The sheet carried "Nothing is saved to your phone
    // yet, so this lasts until you close the app", with a comment beside it
    // saying it came out the day storage landed.
    //
    // Storage landed. main.dart builds the app with a FileSnapshotStore and
    // every edit made on that sheet is written to disk. The sentence, and
    // this test defending it, had become a promise of data loss that does
    // not happen, which on a finance app is the expensive direction to be
    // wrong in: the reasonable response to reading it is to stop bothering
    // to enter anything.
    await pumpApp(tester);
    await openTab(tester, Icons.account_balance_wallet_outlined);
    await tapAndSettle(tester, find.text('Add'));

    expect(find.byType(AccountSheet), findsOneWidget);
    expect(
      find.textContaining('Nothing is saved to your phone yet'),
      findsNothing,
      reason: 'the sheet told somebody their account would vanish',
    );
  });

  testWidgets('a card keeps its closing day, which had no input at all', (
    WidgetTester tester,
  ) async {
    // Account.statementDate has round tripped through the model, the codec
    // and the backup file since the first build, and NO screen could set it.
    // The only record that ever carried one was the sample card, because the
    // seed writes it directly.
    //
    // The read-back is the directional half. A field that is drawn and then
    // discarded on save looks identical on screen to one that is kept, so
    // every earlier test of this sheet would have passed either way.
    await pumpApp(tester);
    await openTab(tester, Icons.account_balance_wallet_outlined);
    await tapAndSettle(tester, find.text('Add'));

    await tapAndSettle(tester, find.text('Credit card'));
    await tester.enterText(find.byType(TextField).first, 'Test Card');
    await tester.pumpAndSettle();

    // Found by its own hint rather than by counting fields, so adding
    // another box above this one cannot quietly move the test onto the
    // wrong box and leave it green.
    final Finder closing = find.widgetWithText(TextField, 'The 10th');
    await reach(tester, closing);
    await tester.enterText(closing, '23rd');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Add account'));

    final FinancialState state = storeOf(tester);
    final dynamic saved = state.accounts.firstWhere(
      (dynamic a) => a.name == 'Test Card',
    );
    expect(
      saved.statementDate,
      '23rd',
      reason: 'the closing day was accepted on screen and thrown away',
    );
  });
}
