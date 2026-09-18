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

  testWidgets('the sheet says plainly that nothing is saved to the phone yet', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openTab(tester, Icons.account_balance_wallet_outlined);
    await tapAndSettle(tester, find.text('Add'));

    expect(find.byType(AccountSheet), findsOneWidget);
    await reach(
      tester,
      find.textContaining('Nothing is saved to your phone yet'),
    );
    expect(
      find.textContaining('Nothing is saved to your phone yet'),
      findsOneWidget,
      reason:
          'Every other write in app/ says this. An account that silently '
          'vanishes on the next cold start, with no warning, is how somebody '
          'loses an evening of setting the app up.',
    );
  });
}
