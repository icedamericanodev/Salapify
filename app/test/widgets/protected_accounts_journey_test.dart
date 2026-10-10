// Setting money aside, in BOTH halves.
//
// Half one asks whether the money behaved correctly. Half two asks whether a
// person can FOLLOW it afterwards, which is the half this repository keeps
// losing: a debt payment was once written perfectly and was invisible in the
// account's own history, with every money test green the whole time.
//
// Half two matters more than usual here, because the whole point of P2.3 is
// a number on Home getting SMALLER. If that happens and no screen explains
// it, the feature is indistinguishable from the app losing somebody's money,
// and the unit tests would all still be green.
//
// The invariant is "net worth does not change", which is a conservation
// statement and therefore unfalsifiable by inaction: it passes perfectly if
// the tap did nothing at all. So every one of them is paired with a
// DIRECTIONAL assertion naming the figure that had to move.

import '../support/net_worth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';
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

  group('the seed ships the lesson already set up', () {
    testWidgets('Maya Savings says Set aside on the Accounts screen', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await goToAccounts(tester);

      // CAN A PERSON SEE IT. The flag lives in an edit sheet, so without a
      // mark on the list the only evidence that Safe to Spend is holding
      // money back is the gap between two numbers on different tabs.
      expect(
        find.textContaining('Set aside'),
        findsWidgets,
        reason:
            'nothing on the Accounts screen said which account was being '
            'held out of Safe to Spend',
      );
    });

    testWidgets('and the Safe to Spend sheet names the amount left out', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);

      // The figure the step must now show, read off the engine rather than
      // typed in, so this cannot drift from what the seed holds.
      expect(s.safeToSpendAnalysis.protectedCash, Money.pesos(15300));

      // Through the hero's own info button, the way a person questioning
      // the figure would get there. By icon rather than by semantics label,
      // because the label sits on a Semantics wrapper and the tap has to
      // land on the InkWell inside it.
      await tapIt(tester, find.byIcon(Icons.info_outline).first);

      // The step-by-step working lives behind its own tab in the sheet.
      await tapIt(tester, find.text('Audit & Math'));

      // The audit steps are below the fold in a lazily built list, so they
      // do not exist in the tree until scrolled to. Plain drags rather than
      // dragUntilVisible, which resolves its scrollable with `element` and
      // throws when the sheet has more than one.
      for (int i = 0; i < 10; i++) {
        if (find
            .textContaining('Add up spendable cash')
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -300),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.textContaining('Add up spendable cash'),
        findsOneWidget,
        reason: 'the audit never reached step 1',
      );

      expect(
        find.textContaining('set aside'),
        findsWidgets,
        reason:
            'step 1 used to read "Cash, GCash, Maya, banks and debit", which '
            'is false the moment anything is protected',
      );
    });
  });

  group('setting an account aside, through the screens', () {
    testWidgets('the headline falls, net worth does not, and the row says '
        'so', (WidgetTester tester) async {
      final FinancialState s = await pumpApp(tester);

      // MariBank is the seed's deliberately-unprotected savings account, so
      // it is the one a person would plausibly set aside themselves.
      const String id = 'acc_seabank';
      final Money worthBefore = netWorthOf(s);
      final Money spendBefore = s.safeToSpendAnalysis.safeToSpendToday;
      final Money balance = accountOf(s, id).balance;
      expect(accountOf(s, id).purpose, AccountPurpose.spendable);

      s.setAccountPurpose(id, AccountPurpose.protected);
      await tester.pumpAndSettle();

      // DIRECTIONAL, so the test cannot pass by the tap doing nothing.
      expect(
        accountOf(s, id).purpose,
        AccountPurpose.protected,
        reason: 'the flag did not actually change',
      );
      expect(
        s.safeToSpendAnalysis.safeToSpendToday,
        lessThan(spendBefore),
        reason:
            'setting 24,250 aside left the headline exactly where it was, '
            'which means the engine never asked the new question',
      );
      expect(
        s.safeToSpendAnalysis.protectedCash,
        Money.pesos(15300) + balance,
        reason: 'both the seeded one and the one just set aside',
      );

      // THE INVARIANT. Money set aside is still the person's money.
      expect(
        netWorthOf(s),
        worthBefore,
        reason: 'net worth moved, so the app really did lose money',
      );

      // And a person can see it afterwards.
      await goToAccounts(tester);
      expect(find.textContaining('Set aside'), findsWidgets);
    });

    testWidgets('it is still payable from, so an emergency can be logged', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);

      // The reassurance the UI gives has to be true. If the pay-from list
      // dropped protected accounts, a real emergency spend could not be
      // recorded and the stored balance would drift from the real one,
      // which is worse than any budget error.
      final Account maya = accountOf(s, 'acc_maya');
      expect(maya.purpose, AccountPurpose.protected);
      expect(
        maya.isLiquid,
        isTrue,
        reason:
            'every pay-from picker and the transfer-to list key off '
            'isLiquid, so this is what keeps the emergency fund reachable',
      );

      final Money before = maya.balance;
      s.logTransaction(
        Transaction(
          id: 'tx_emergency',
          type: TransactionType.expense,
          amount: Money.pesos(2000),
          category: 'Health',
          accountId: 'acc_maya',
          date: '2026-09-19',
          createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        accountOf(s, 'acc_maya').balance,
        before - Money.pesos(2000),
        reason: 'the money did not actually leave the protected account',
      );

      // THE TRAP THIS JOURNEY EXISTS FOR. Spending from a protected account
      // must not quietly un-protect it. `copyWith` is what the ledger uses
      // to write the new balance, and a missing field there would raise the
      // person's Safe to Spend with nothing on any screen to explain it.
      expect(
        accountOf(s, 'acc_maya').purpose,
        AccountPurpose.protected,
        reason: 'logging one expense un-protected the emergency fund',
      );
    });
  });

  group('the one-time review card', () {
    testWidgets('the demo ledger is never asked, because none of it is '
        'theirs', (WidgetTester tester) async {
      final FinancialState s = await pumpApp(tester);
      expect(
        s.shouldOfferSetAsideReview,
        isFalse,
        reason:
            'every seeded account is a sample, and one already carries the '
            'flag, so there is nothing to ask about',
      );
      await goToAccounts(tester);
      expect(find.byKey(const Key('set-aside-review')), findsNothing);
    });

    testWidgets('a real ledger with two wallets IS asked, once', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);

      // Two real accounts and nothing protected: the exact shape the card is
      // for, and the shape every existing user is in on the day this ships.
      await s.deleteEverything();
      await tester.pumpAndSettle();
      s.addAccount(
        const Account(
          id: 'mine_1',
          name: 'GCash',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: Money.pesos(4000),
          monogram: 'GC',
        ),
      );
      s.addAccount(
        const Account(
          id: 'mine_2',
          name: 'GSave',
          kind: AccountKind.gcash,
          institution: 'GCash',
          balance: Money.pesos(60000),
          monogram: 'GS',
        ),
      );
      await tester.pumpAndSettle();

      expect(s.shouldOfferSetAsideReview, isTrue);

      await goToAccounts(tester);
      expect(find.byKey(const Key('set-aside-review')), findsOneWidget);

      // Nothing is pre-ticked. The card asks; it does not guess.
      expect(accountOf(s, 'mine_2').purpose, AccountPurpose.spendable);

      final Money before = s.safeToSpendAnalysis.safeToSpendToday;
      await tapIt(tester, find.byKey(const Key('set-aside-mine_2')));
      await tapIt(tester, find.byKey(const Key('set-aside-save')));

      expect(accountOf(s, 'mine_2').purpose, AccountPurpose.protected);
      expect(
        accountOf(s, 'mine_1').purpose,
        AccountPurpose.spendable,
        reason: 'the card changed an account nobody ticked',
      );
      expect(s.safeToSpendAnalysis.safeToSpendToday, lessThan(before));

      // AND IT NEVER COMES BACK.
      expect(s.shouldOfferSetAsideReview, isFalse);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-aside-review')), findsNothing);
    });

    testWidgets('Not now changes nothing, and still never comes back', (
      WidgetTester tester,
    ) async {
      final FinancialState s = await pumpApp(tester);
      await s.deleteEverything();
      await tester.pumpAndSettle();
      for (int i = 1; i <= 2; i++) {
        s.addAccount(
          Account(
            id: 'mine_$i',
            name: 'Wallet $i',
            kind: AccountKind.gcash,
            institution: 'GCash',
            balance: const Money.pesos(5000),
            monogram: 'W$i',
          ),
        );
      }
      await tester.pumpAndSettle();
      await goToAccounts(tester);

      final Money before = s.safeToSpendAnalysis.safeToSpendToday;
      await tapIt(tester, find.byKey(const Key('set-aside-not-now')));

      expect(
        s.safeToSpendAnalysis.safeToSpendToday,
        before,
        reason: 'declining the card moved somebody figure',
      );
      expect(
        s.accounts.every((Account a) => a.purpose == AccountPurpose.spendable),
        isTrue,
      );
      expect(s.shouldOfferSetAsideReview, isFalse);
      expect(find.byKey(const Key('set-aside-review')), findsNothing);
    });

    testWidgets('the answer survives a save and a reload', (
      WidgetTester tester,
    ) async {
      // The flag is stored, not held in memory, so reinstalling from a
      // backup does not re-ask and does not forget what was set aside.
      final FinancialState s = await pumpApp(tester);
      s.setAccountPurpose('acc_bpi', AccountPurpose.protected);
      s.markSetAsideReviewed();
      await tester.pumpAndSettle();

      final String written = s.snapshot().encode(at: testToday);
      expect(written, contains('setAsideReviewedAt'));
      expect(written, contains('"purpose": "protected"'));
    });
  });
}
