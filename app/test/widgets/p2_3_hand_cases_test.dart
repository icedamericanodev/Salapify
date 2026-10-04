// The six hand test cases from docs/reviews/p2.3-test-cases.md, driven
// automatically.
//
// WHY THIS FILE EXISTS SEPARATELY from protected_accounts_journey_test.dart,
// which already covers the engine side: the founder asked whether the hand
// cases could be run without them. Most of them can, so they are, and this
// file is numbered to match the document exactly. When a case here fails, the
// founder knows which numbered case to look at rather than which Dart test.
//
// WHAT IT CANNOT DO, said plainly rather than left implied. These are the same
// Flutter widgets the phone builds, so a missing control or a wrong sentence
// is caught here. What is NOT caught is anything only a real device shows:
// how it feels to tap, whether the message bar is readable at arm's length,
// whether the sheet scrolls comfortably on a short phone. Two real defects in
// this project reached the founder with the whole suite green, so a pass here
// is evidence, not a substitute for the emulator.
//
// Case 0 is the one worth having most, and it is the one the founder cannot
// easily run: a file written by a build that had never heard of `purpose`,
// opened by this build. That is the path every existing user takes on the day
// this ships, and it happens exactly once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  Future<FinancialState> pumpApp(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    return pumpSalapify(tester);
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> goToAccounts(WidgetTester tester) async {
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
  }

  Account accountOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id);

  double netWorthOf(FinancialState s) => s.accounts.fold<double>(
    0,
    (double sum, Account a) => sum + a.balanceInPhp.pesos,
  );

  /// Scrolls the frontmost scrollable until [target] is in the tree.
  ///
  /// Plain drags rather than `dragUntilVisible`, which resolves its scrollable
  /// with `element` and throws when a sheet has more than one.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 12 && target.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -300),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
  }

  // -------------------------------------------------------------------------
  // CASE 0: a ledger saved by the OLD build, opened by this one.
  // -------------------------------------------------------------------------

  group('case 0, the upgrade path every existing user takes', () {
    /// A file with no `purpose` key anywhere, which is every backup and every
    /// saved ledger written before P2.3.
    const String oldFile = '''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "a_wallet", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 4200, "monogram": "GC"},
    {"id": "a_ipon", "name": "GSave", "kind": "gcash",
     "institution": "GCash", "balance": 60000, "monogram": "GS"}
  ],
  "transactions": [], "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": [],
  "onboardedAt": "2026-08-01"
}
''';

    Future<FinancialState> openOldFile(WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(1170, 3400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final MemorySnapshotStore store = MemorySnapshotStore(oldFile);
      final FinancialState state = FinancialState(
        clock: testToday,
        store: store,
      );
      await state.restore();
      addTearDown(state.dispose);
      await tester.pumpWidget(SalapifyApp(state: state));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('it opens, and nothing has been reclassified', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await openOldFile(tester);

      // The whole safety argument of this design in one assertion: the app
      // must never reach into a stored ledger and change what it means.
      expect(s.accounts, hasLength(2));
      expect(
        s.accounts.every((Account a) => a.purpose == AccountPurpose.spendable),
        isTrue,
        reason: 'the app guessed, which it must never do',
      );
      expect(
        s.safeToSpendAnalysis.protectedCash,
        Money.zero,
        reason: 'money was held back that nobody asked to hold back',
      );
    });

    testWidgets('and saving it back does not add noise to the file', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await openOldFile(tester);
      final String written = s.snapshot().encode(at: testToday);

      // Written only when protected, so an untouched ledger's file is what it
      // always was. A key appearing on every account would mean every
      // existing user's next backup differs from their last for no reason.
      expect(
        written.contains('"purpose"'),
        isFalse,
        reason: 'the save wrote a field nobody set',
      );
    });

    testWidgets('and THIS is the ledger the one-time card is for', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await openOldFile(tester);
      expect(
        s.shouldOfferSetAsideReview,
        isTrue,
        reason:
            'two real liquid accounts, nothing protected: the exact shape '
            'every existing user is in, and the only way they ever find out '
            'this setting exists',
      );
      await goToAccounts(tester);
      expect(find.byKey(const Key('set-aside-review')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // CASE 1: the control exists, and only where it means something.
  // -------------------------------------------------------------------------

  group('case 1, the setting exists and only where it makes sense', () {
    testWidgets('a wallet or bank account HAS the picker', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);
      await goToAccounts(tester);

      await tapIt(tester, find.text('BPI Preferred Payroll'));
      await scrollTo(tester, find.byKey(const Key('account-purpose')));

      expect(find.text('What this money is for'), findsOneWidget);
      expect(find.byKey(const Key('account-purpose')), findsOneWidget);
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Set aside'), findsOneWidget);
      expect(
        find.textContaining('still counts in your net worth'),
        findsOneWidget,
        reason: 'the reassurance has to be beside the control, not elsewhere',
      );
      expect(accountOf(s, 'acc_bpi').kind, AccountKind.bank);
    });

    testWidgets('a credit card does NOT', (WidgetTester tester) async {
      final FinancialState s = await pumpApp(tester);

      // THE SHEET IS OPENED DIRECTLY, and that is a deliberate retreat worth
      // writing down.
      //
      // A credit card is not reached the way a row is: it is drawn as
      // plastic, tapping it TURNS IT OVER, and the Edit button is on the
      // back. The first version of this test tapped the card's name and then
      // asserted "the picker is absent" against a sheet that had never
      // opened. It passed happily with the hiding rule deleted, which is
      // exactly what breaking the rule on purpose is meant to catch, and did.
      //
      // Driving the flip through the harness turned out to be its own
      // fight, and a test spent fighting an animation is a test that will
      // flake later. So this opens the sheet the way the render harness
      // does. It still exercises the real sheet with a real credit account,
      // which is the rule under test; what it no longer covers is the route
      // a finger takes to get there, and that is stated here rather than
      // quietly lost.
      final Account card = accountOf(s, 'acc_bpi_cc');
      expect(card.kind, AccountKind.credit);

      AccountSheet.show(
        tester.element(find.byType(AppShell)),
        palette: Palette.of(s.theme),
        state: s,
        existing: card,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Edit account'),
        findsOneWidget,
        reason: 'the sheet never opened, so the assertion below means nothing',
      );

      // Scrolled all the way down, because "not visible yet" and "not there"
      // are different answers and only one of them is a pass.
      for (int i = 0; i < 12; i++) {
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -400),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const Key('account-purpose')),
        findsNothing,
        reason:
            'a credit card is money you owe, so set aside would mean nothing '
            'there, and a control that does nothing teaches people the '
            'controls do nothing',
      );
      expect(find.text('What this money is for'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // CASE 2: setting money aside, and what the app says about it.
  // -------------------------------------------------------------------------

  testWidgets('case 2, the headline falls, net worth does not, and the app '
      'says so in both figures', (WidgetTester tester) async {
    final FinancialState s = await pumpApp(tester);

    final double worthBefore = netWorthOf(s);
    final Money spendBefore = s.safeToSpendAnalysis.safeToSpendToday;

    await goToAccounts(tester);
    await tapIt(tester, find.text('MariBank Digital Savings'));
    await scrollTo(tester, find.byKey(const Key('account-purpose')));
    await tapIt(tester, find.text('Set aside'));
    await tapIt(tester, find.text('Save changes'));

    final Money spendAfter = s.safeToSpendAnalysis.safeToSpendToday;

    // DIRECTIONAL, so this cannot pass by the tap doing nothing at all.
    expect(accountOf(s, 'acc_seabank').purpose, AccountPurpose.protected);
    expect(spendAfter, lessThan(spendBefore));

    // THE INVARIANT.
    expect(
      netWorthOf(s),
      worthBefore,
      reason: 'net worth moved, so the app really did lose money',
    );

    // And the message names BOTH figures plus the reassurance, because a
    // quarter knocked off the figure somebody reads first, at the exact
    // moment they did something sensible, is otherwise indistinguishable
    // from the app losing their money.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('is now set aside'), findsOneWidget);
    expect(
      find.textContaining('Your net worth has not changed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('you can still pay from this account'),
      findsOneWidget,
    );
  });

  /// The founder set an account aside on the emulator, it saved correctly,
  /// and NO MESSAGE APPEARED. Nothing structural was found: the bar renders
  /// above the navigation bar, measured rather than eyeballed. But the hunt
  /// turned up a real defect next door, which this pins.
  ///
  /// `_sayWhatChanged` used to return early when the figure did not move. The
  /// intent was not to announce a change that did not happen. The effect was
  /// total silence after a deliberate tap on any ledger whose Safe to Spend
  /// is already zero, so the person gets no confirmation their choice
  /// registered at all.
  testWidgets('a change that cannot move the figure STILL confirms itself', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // One wallet, and bills that reserve more than it holds, so Safe to Spend
    // is pinned at zero and setting money aside cannot move it.
    final MemorySnapshotStore store = MemorySnapshotStore('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "a_only", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 3000, "monogram": "GC"}
  ],
  "transactions": [], "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [],
  "bills": [{"id": "b1", "name": "Rent", "amount": 90000,
             "dueDate": "2026-09-25"}],
  "onboardedAt": "2026-08-01"
}
''');
    final FinancialState s = FinancialState(clock: testToday, store: store);
    await s.restore();
    addTearDown(s.dispose);
    await tester.pumpWidget(SalapifyApp(state: s));
    await tester.pumpAndSettle();

    final Money before = s.safeToSpendAnalysis.safeToSpendToday;
    expect(
      before,
      Money.zero,
      reason: 'the fixture has to pin the figure, or this tests nothing',
    );

    AccountSheet.show(
      tester.element(find.byType(AppShell)),
      palette: Palette.of(s.theme),
      state: s,
      existing: s.accounts.single,
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('account-purpose')));
    await tapIt(tester, find.text('Set aside'));
    await tapIt(tester, find.text('Save changes'));

    // It really did save, and the figure really could not move.
    expect(s.accounts.single.purpose, AccountPurpose.protected);
    expect(s.safeToSpendAnalysis.safeToSpendToday, before);

    // AND THE PERSON IS STILL TOLD.
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason:
          'a deliberate tap saved with no confirmation of any kind, so the '
          'person cannot tell whether it worked',
    );
    expect(find.textContaining('is now set aside'), findsOneWidget);
    expect(
      find.textContaining('does not change'),
      findsOneWidget,
      reason: 'it has to say WHY no figure moved, not just stay quiet',
    );
  });

  // -------------------------------------------------------------------------
  // CASE 3: it still says so afterwards.
  // -------------------------------------------------------------------------

  testWidgets('case 3, the Accounts row says Set aside', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await goToAccounts(tester);

    // The seed ships acc_maya protected, so this is testable without first
    // changing anything.
    expect(
      find.textContaining('Set aside'),
      findsWidgets,
      reason:
          'without this the only evidence the app is holding money back is '
          'a gap between two numbers on two different tabs, which looks '
          'exactly like a bug',
    );
  });

  // -------------------------------------------------------------------------
  // CASE 4: the app shows its working.
  // -------------------------------------------------------------------------

  testWidgets('case 4, audit step 1 names the amount left out, and step 5 is '
      'renamed', (WidgetTester tester) async {
    final FinancialState s = await pumpApp(tester);

    await tapIt(tester, find.byIcon(Icons.info_outline).first);
    await tapIt(tester, find.text('Audit & Math'));
    await scrollTo(tester, find.textContaining('Add up spendable cash'));

    expect(find.textContaining('Add up spendable cash'), findsOneWidget);
    expect(
      find.textContaining('you have set aside'),
      findsOneWidget,
      reason:
          'step 1 used to read "Cash, GCash, Maya, banks and debit", which '
          'goes false the moment anything is set aside',
    );
    expect(
      find.textContaining('still yours and still in your net worth'),
      findsOneWidget,
    );

    // The figure it names is the engine's, not a second copy that could
    // drift from it.
    expect(s.safeToSpendAnalysis.protectedCash, Money.pesos(15300));
    expect(find.textContaining('15,300'), findsWidgets);

    await scrollTo(tester, find.textContaining('surprise buffer'));
    expect(
      find.textContaining('surprise buffer'),
      findsWidgets,
      reason:
          'once somebody has a real emergency fund set aside, calling the '
          'engine 15 percent holdback the "emergency buffer" showed two '
          'different things under one name on one screen',
    );
    expect(find.text('Emergency buffer'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // CASE 5: you can still spend it in an emergency.
  // -------------------------------------------------------------------------

  testWidgets('case 5, a protected account is still in the pay-from list, and '
      'spending from it does not un-protect it', (WidgetTester tester) async {
    final FinancialState s = await pumpApp(tester);
    expect(accountOf(s, 'acc_maya').purpose, AccountPurpose.protected);

    await tapIt(tester, find.text('Log').last);

    // The picker is keyed because both the source and the destination list
    // account names, so the names alone cannot tell them apart.
    final Finder picker = find.byKey(const Key('log-source-picker'));
    expect(picker, findsOneWidget);
    expect(
      find.descendant(of: picker, matching: find.text('Maya Savings')),
      findsOneWidget,
      reason:
          'an emergency spend the app refuses to record would drift the '
          'stored balance from the real one, which is worse than any budget '
          'error',
    );

    // And the other half, which is the trap: writing a new balance must not
    // drop the flag, because that is the copy the ledger makes every time
    // money moves.
    final Money before = accountOf(s, 'acc_maya').balance;
    s.logTransaction(
      Transaction(
        id: 'tx_case5',
        type: TransactionType.expense,
        amount: Money.pesos(100),
        category: 'Health',
        accountId: 'acc_maya',
        date: '2026-09-19',
        createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
      ),
    );
    await tester.pumpAndSettle();

    expect(accountOf(s, 'acc_maya').balance, before - Money.pesos(100));
    expect(
      accountOf(s, 'acc_maya').purpose,
      AccountPurpose.protected,
      reason: 'logging one expense un-protected the emergency fund',
    );
  });

  // -------------------------------------------------------------------------
  // CASE 6: the one-time card.
  // -------------------------------------------------------------------------

  testWidgets('case 6, the card pre-ticks nothing and never comes back', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final MemorySnapshotStore store = MemorySnapshotStore('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "a_wallet", "name": "GCash", "kind": "gcash",
     "institution": "GCash", "balance": 4200, "monogram": "GC"},
    {"id": "a_ipon", "name": "GSave", "kind": "gcash",
     "institution": "GCash", "balance": 60000, "monogram": "GS"}
  ],
  "transactions": [], "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": [],
  "onboardedAt": "2026-08-01"
}
''');
    final FinancialState s = FinancialState(clock: testToday, store: store);
    await s.restore();
    addTearDown(s.dispose);
    await tester.pumpWidget(SalapifyApp(state: s));
    await tester.pumpAndSettle();

    await goToAccounts(tester);
    expect(find.byKey(const Key('set-aside-review')), findsOneWidget);

    // NOTHING PRE-TICKED. The app must never guess which account is savings:
    // "Maya Savings" is the product name of a wallet millions spend from
    // daily, and GSave sits inside GCash.
    for (final Account a in s.accounts) {
      expect(
        a.purpose,
        AccountPurpose.spendable,
        reason: 'the card arrived with a guess already applied',
      );
    }

    final Money before = s.safeToSpendAnalysis.safeToSpendToday;
    await tapIt(tester, find.byKey(const Key('set-aside-a_ipon')));
    await tapIt(tester, find.byKey(const Key('set-aside-save')));

    expect(accountOf(s, 'a_ipon').purpose, AccountPurpose.protected);
    expect(
      accountOf(s, 'a_wallet').purpose,
      AccountPurpose.spendable,
      reason: 'the card changed an account nobody ticked',
    );
    expect(s.safeToSpendAnalysis.safeToSpendToday, lessThan(before));

    // GONE, and gone for good.
    expect(find.byKey(const Key('set-aside-review')), findsNothing);
    expect(s.shouldOfferSetAsideReview, isFalse);

    // Including across a restart, because the flag is in the file and not in
    // memory. This is what stops it becoming a weekly nag.
    final FinancialState again = FinancialState(clock: testToday, store: store);
    await again.restore();
    addTearDown(again.dispose);
    expect(again.shouldOfferSetAsideReview, isFalse);
    expect(
      again.accounts.firstWhere((Account a) => a.id == 'a_ipon').purpose,
      AccountPurpose.protected,
      reason: 'the answer did not survive a restart',
    );
  });
}
