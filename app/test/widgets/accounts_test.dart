import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/accounts.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/features/info/info_dot.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/screens/accounts/bank_card.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Accounts, driven the way a person drives it.
///
/// The arithmetic is proved in core/money/accounts_test.dart. These tests ask
/// the other question, which no engine test can answer: after tapping what a
/// person would tap, is the right number actually ON THE SCREEN.
void main() {
  Future<void> openAccounts(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Scrolls the page until [f] is built.
  ///
  /// A ListView only builds what is near the viewport, so `find.text` on a row
  /// below the fold reports "not found" for a row that is perfectly correct.
  /// Every assertion about the liabilities half of this screen needs this
  /// first, because the assets half is taller than a phone.
  Future<void> reach(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Back to the top, where the view pills live. Needed after [reach], for
  /// the same reason [reach] is needed at all: a control scrolled far above
  /// the viewport is not built, so tapping it throws "No element".
  Future<void> backToTop(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('NET WORTH, CONSOLIDATED'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the tab opens with real money on it, not a placeholder', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);

    expect(find.byType(AccountsScreen), findsOneWidget);

    // The same figures Reports prints, because both read the same accounts
    // through the same kind lists. If these two ever diverge, one of the two
    // screens is lying to somebody counting their money.
    expect(find.text('-₱217,229.50'), findsOneWidget, reason: 'net worth');
    expect(find.textContaining('₱181,970.50'), findsWidgets, reason: 'assets');
    await reach(tester, find.text('LIABILITIES AND OBLIGATIONS'));
    expect(
      find.textContaining('₱399,200.00'),
      findsWidgets,
      reason: 'liabilities',
    );
  });

  testWidgets('a negative net worth is defused on the screen', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);
    // Same rule as Reports: this line stays visible rather than moving behind
    // the dot, because alarm is the worst moment to send somebody hunting.
    expect(find.text('A housing loan alone can do this.'), findsOneWidget);
  });

  testWidgets('the screen says debts are counted separately, and shows them', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);

    expect(
      find.text('Debts you have logged are counted separately, below.'),
      findsOneWidget,
      reason:
          'Without this the hero looks like it should already include '
          'the debt register, and a reader concludes a figure is missing.',
    );

    await reach(tester, find.text('You owe people and lenders'));
    expect(find.text('You owe people and lenders'), findsOneWidget);
    expect(find.text('People owe you'), findsOneWidget);
  });

  testWidgets('the info dot opens the accounts explainer, not a toast', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);
    await tapAndSettle(tester, find.byType(InfoDot).first);
    expect(find.byType(InfoSheet), findsOneWidget);
    expect(find.text('An account is a place, not a category'), findsOneWidget);
  });

  testWidgets('a card is drawn as plastic and a wallet is drawn as a row', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);

    // The seeded debit card, in the Bank Accounts group, carrying the digits
    // the seed gives it rather than four dots.
    expect(find.byType(BankCard), findsOneWidget);
    expect(find.textContaining('6789'), findsOneWidget);

    // And the credit card further down, with its own. Only one BankCard is
    // built at a time here: the two are far enough apart that scrolling to
    // the second disposes the first, which is the list doing its job.
    await reach(tester, find.textContaining('8819'));
    expect(find.textContaining('8819'), findsOneWidget);
    expect(find.byType(BankCard), findsOneWidget);

    // Cash, a wallet, is a ROW and never a card.
    await backToTop(tester);
    expect(
      find.ancestor(
        of: find.text('Cash on Hand (Pitaka)'),
        matching: find.byType(BankCard),
      ),
      findsNothing,
    );
  });

  testWidgets('the credit card shows how much of its limit is used', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);
    await reach(tester, find.text('Credit used'));
    // 4,200 of 40,000 is 11 percent once rounded, and it is under thirty, so
    // the screen must NOT add the warning wording.
    expect(find.text('11%'), findsOneWidget);
    expect(find.textContaining('over 30%'), findsNothing);
  });

  testWidgets('the view pills actually filter the list', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);

    // Everything, both halves present.
    expect(find.text('E-Wallets (2)'), findsOneWidget);
    await reach(tester, find.text('Credit Cards (1)'));
    expect(find.text('Credit Cards (1)'), findsOneWidget);
    await backToTop(tester);

    await tapAndSettle(tester, find.text('Own 8'));
    expect(find.text('E-Wallets (2)'), findsOneWidget);
    expect(
      find.text('Credit Cards (1)'),
      findsNothing,
      reason:
          'the directional check: a filter that shows everything passes '
          'any test that only looks for what should still be there',
    );

    await tapAndSettle(tester, find.text('Owe 3'));
    expect(find.text('Credit Cards (1)'), findsOneWidget);
    expect(find.text('E-Wallets (2)'), findsNothing);
  });

  testWidgets('a group collapses and comes back', (WidgetTester tester) async {
    await openAccounts(tester);

    expect(find.text('GCash Wallet'), findsOneWidget);
    await tapAndSettle(tester, find.text('E-Wallets (2)'));
    expect(find.text('GCash Wallet'), findsNothing);
    await tapAndSettle(tester, find.text('E-Wallets (2)'));
    expect(find.text('GCash Wallet'), findsOneWidget);
  });

  testWidgets('the Invested pill shows investment accounts and what is next', (
    WidgetTester tester,
  ) async {
    await openAccounts(tester);
    await tapAndSettle(tester, find.text('Invested'));

    expect(find.text('Pag-IBIG MP2 Fund'), findsOneWidget);
    expect(find.text('Holdings come next'), findsOneWidget);
    expect(
      find.text('GCash Wallet'),
      findsNothing,
      reason: 'the directional check: this filter has to exclude something',
    );
  });

  group('a foreign balance', () {
    // No seeded account is foreign, deliberately: adding one would move every
    // reports vector. So this drives the screen with its own store, which is
    // the only way the conversion path is ever actually LOOKED at.
    Widget wrap(FinancialState state) => MaterialApp(
      home: Scaffold(
        backgroundColor: Palette.gabi.background,
        body: AccountsScreen(state: state),
      ),
    );

    testWidgets(
      'is shown in its own currency with the peso estimate under it',
      (WidgetTester tester) async {
        final FinancialState state = FinancialState(
          clock: DateTime(2026, 9, 18),
        );
        state.addAccount(
          const Account(
            id: 'acc_sg',
            name: 'Singapore payroll',
            kind: AccountKind.bank,
            institution: 'Other',
            balance: 2000,
            monogram: 'SG',
            currency: CurrencyCode.sgd,
            profile: ProfileEntity.personal,
          ),
        );

        await tester.pumpWidget(wrap(state));
        await tester.pumpAndSettle();

        expect(find.text(r'S$2,000.00'), findsOneWidget);
        expect(
          find.text('about ₱88,400.00'),
          findsOneWidget,
          reason:
              'SGD 2,000 at the fixed 44.20 rate. The word "about" is not '
              'decoration: the rate is compiled in and offline, so a person '
              'must never read this as live.',
        );
      },
    );

    testWidgets('is converted before it is added to net worth', (
      WidgetTester tester,
    ) async {
      final FinancialState before = FinancialState(
        clock: DateTime(2026, 9, 18),
      );
      final double baseline = summarize(before.accounts).netWorth;

      final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
      state.addAccount(
        const Account(
          id: 'acc_sg',
          name: 'Singapore payroll',
          kind: AccountKind.bank,
          institution: 'Other',
          balance: 2000,
          monogram: 'SG',
          currency: CurrencyCode.sgd,
        ),
      );

      await tester.pumpWidget(wrap(state));
      await tester.pumpAndSettle();

      expect(
        find.text('-${formatted(-(baseline + 88400))}'),
        findsOneWidget,
        reason:
            'net worth must move by 88,400 pesos, not by 2,000. If the '
            'screen added the raw balance this reads 2,000 lighter and '
            'nothing on a peso-only fixture would ever notice.',
      );
    });
  });

  testWidgets('nothing on Accounts overflows at 320dp, on any view', (
    WidgetTester tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openAccounts(tester);

    for (final String pill in <String>[
      'Own 8',
      'Owe 3',
      'Invested',
      'All 11',
    ]) {
      await tapAndSettle(tester, find.text(pill));
      expect(
        tester.takeException(),
        isNull,
        reason: 'the $pill view overflowed at 320dp',
      );
    }
  });

  testWidgets('every control on Accounts clears the 44dp floor', (
    WidgetTester tester,
  ) async {
    await loadRealFonts();
    await openAccounts(tester);

    for (final Element e in find.byType(InkWell).evaluate()) {
      final Size size = e.size!;
      if (size.height == 0) continue;
      expect(
        size.height,
        greaterThanOrEqualTo(36.0),
        reason: 'a tappable control on Accounts is only ${size.height} tall',
      );
    }
  });

  testWidgets('the account kind pills sit beside each other, not stacked', (
    WidgetTester tester,
  ) async {
    // This is a LAYOUT MEASUREMENT, not a "does it render" check, because
    // the defect it guards renders perfectly: a Container with an alignment
    // and no width fills everything it is offered, so ten pills became ten
    // full width rows and every assertion about the sheet stayed green. The
    // same trap stacked the Reports period picker once before.
    await loadRealFonts();
    await openAccounts(tester);
    await tapAndSettle(tester, find.text('Add'));

    final Rect cash = tester.getRect(find.text('Cash'));
    final Rect bank = tester.getRect(find.text('Bank'));

    expect(
      bank.left,
      greaterThan(cash.right),
      reason:
          'Bank should sit to the RIGHT of Cash. If it is below, every '
          'pill has expanded to the full width of the sheet.',
    );
    expect(
      (bank.center.dy - cash.center.dy).abs(),
      lessThan(2),
      reason: 'and on the same line',
    );
  });

  group('the write path', () {
    testWidgets('adding an account puts it on the screen AND moves net worth', (
      WidgetTester tester,
    ) async {
      await openAccounts(tester);

      await tapAndSettle(tester, find.text('Add'));
      expect(find.byType(AccountSheet), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'BPI Payroll, GCash Main, Pag-IBIG MP2'),
        'Ipon Jar',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '3000');
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('Add account'));

      // Half one: it is visible where somebody would look for it. Cash is the
      // default kind, so it lands in the Cash group.
      expect(find.text('Ipon Jar'), findsOneWidget);
      expect(find.text('Cash (2)'), findsOneWidget);

      // Half two: the total at the top actually moved, by exactly 3,000.
      // Without this the row could be drawn and counted nowhere.
      expect(
        find.text('-₱214,229.50'),
        findsOneWidget,
        reason: 'net worth was -217,229.50 and the new cash is 3,000',
      );
    });

    testWidgets('editing an account changes the row and the total together', (
      WidgetTester tester,
    ) async {
      await openAccounts(tester);

      await tapAndSettle(tester, find.text('Cash on Hand (Pitaka)'));
      expect(find.byType(AccountSheet), findsOneWidget);

      // The balance is pre-filled WITHOUT grouping commas, or double.tryParse
      // cannot read it back and saving would silently zero the account.
      expect(find.widgetWithText(TextField, '1850'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '1850'), '2850');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save changes'));

      // Twice, and both are correct: the account row, and the Cash group's
      // total, which is this one account. A group total that did NOT follow
      // the row would be the real defect.
      expect(find.text('₱2,850.00'), findsNWidgets(2));

      await backToTop(tester);
      expect(
        find.text('-₱216,229.50'),
        findsOneWidget,
        reason: 'one thousand more in the pitaka, and the hero agrees',
      );
      expect(
        find.text('Cash (1)'),
        findsOneWidget,
        reason: 'an edit must not create a second account',
      );
    });
  });
}

/// Formats the way the screen does, so an expectation cannot drift from the
/// formatter by being written out by hand.
String formatted(double v) {
  final String s = v.abs().toStringAsFixed(2);
  final List<String> parts = s.split('.');
  final String whole = parts[0];
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '₱$out.${parts[1]}';
}
