// Moving your own money between your own accounts, and the one thing it must
// never do: change how much you have.
//
// The last transfer this app offered DESTROYED money (transfer_loss_test.dart
// keeps that line). This one runs entirely through the golden locked
// `applyTransfer`, so the invariant is the engine's, and what this file adds is
// the two halves every write path needs: is the money right, and can a person
// FIND it afterwards, on every screen that should now mention it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/money/statements.dart' show netWorthParts;
import 'package:salapify/core/money/transfers.dart'
    show applyTransfer, balanceLabel;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/accounts/account_detail_screen.dart'
    show accountHistory;
import 'package:salapify/features/ledger/ledger_screen.dart' show signedAmount;

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

double _balance(Map<String, dynamic> data, String id) {
  for (final a in (data['accounts'] as List)) {
    if (a is Map && a['id'] == id) return amountOf(a['balance']);
  }
  return double.nan;
}

double _worth(Map<String, dynamic> d) => netWorthParts(d)['netWorth'] as double;

/// Scroll the tab screen until [what] is on screen AND tappable.
Future<void> _scrollTo(WidgetTester tester, Finder what) async {
  await tester.scrollUntilVisible(
    what,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Home > Move, then pick, type and confirm.
Future<void> _move(
  WidgetTester tester, {
  required String from,
  required String to,
  required String amount,
}) async {
  await tester.tap(find.text('Move'));
  await tester.pumpAndSettle();
  // The chips carry the balance beside the name, so match on the name alone.
  // From and To each list every account, so the same name appears twice: the
  // first is in From, the second in To.
  await tester.tap(find.textContaining(from).first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(to).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), amount);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PillButton, 'Move it'));
  await tester.pumpAndSettle();
}

void main() {
  group('the money', () {
    testWidgets('a transfer between your own accounts cannot change net worth', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final worth = _worth(store.data);
      final bpi = _balance(store.data, 'a_bpi');
      final gcash = _balance(store.data, 'a_gcash');

      await _move(tester, from: 'BPI', to: 'GCash', amount: '2500');

      // THE INVARIANT, and its DIRECTIONAL companion. Net worth unchanged is
      // also true of a transfer that transferred nothing, so on its own it
      // passes hardest when the feature is most broken. The per-account
      // movement is what proves something happened.
      expect(
        _worth(store.data),
        closeTo(worth, 0.005),
        reason:
            'moving your own money between your own accounts changed net worth',
      );
      expect(
        _balance(store.data, 'a_bpi'),
        closeTo(bpi - 2500, 0.005),
        reason: 'the account the money left did not go down',
      );
      expect(
        _balance(store.data, 'a_gcash'),
        closeTo(gcash + 2500, 0.005),
        reason: 'the account the money went to did not go up',
      );
    });

    testWidgets('and it never touches the budget', (tester) async {
      // "Not income and not spending" is the sheet's own promise. A transfer
      // row has type transfer, and budgetSummary only sums expenses, so the
      // month's spent figure cannot move. Pinned here because the promise is
      // printed on the receipt, and a printed promise is a test.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final spentBefore = (store.data['transactions'] as List)
          .where((t) => t is Map && t['type'] == 'expense')
          .fold(0.0, (s, t) => s + amountOf((t as Map)['amount']));

      await _move(tester, from: 'BPI', to: 'GCash', amount: '1000');

      final spentAfter = (store.data['transactions'] as List)
          .where((t) => t is Map && t['type'] == 'expense')
          .fold(0.0, (s, t) => s + amountOf((t as Map)['amount']));
      expect(spentAfter, closeTo(spentBefore, 0.005));
    });

    testWidgets('more than the account holds is refused, in truthful words', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final before = _balance(store.data, 'a_gcash');
      await _move(tester, from: 'GCash', to: 'BPI', amount: '999999');

      expect(
        _balance(store.data, 'a_gcash'),
        closeTo(before, 0.005),
        reason: 'an overdraft went through',
      );
      // The TRUNCATED balance, the same figure the chip shows, so the sentence
      // and the chip cannot disagree. The engine's own string rounds.
      expect(
        find.textContaining('GCash only has ${balanceLabel(before)}'),
        findsOneWidget,
        reason:
            'the refusal did not name what the account actually holds, or '
            'named a rounded figure the next tap would contradict',
      );
      // And the button came back, so the person can fix the amount and try
      // again rather than being left with a dead control.
      expect(find.widgetWithText(PillButton, 'Move it'), findsOneWidget);
    });

    testWidgets(
      'picking the From account removes it from the To picker, so the '
      'refusal is unreachable rather than merely worded well',
      (tester) async {
        final store = await memoryStore(livedIn());
        await tester.pumpWidget(_app(store));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Move'));
        await tester.pumpAndSettle();

        // GCash is accounts[0] in the fixture, so it is the sheet's default
        // From. It must not also be offered as a To.
        expect(
          find.descendant(
            of: find.byType(PickChip),
            matching: find.textContaining('GCash'),
          ),
          findsOneWidget,
          reason:
              'GCash appears as a chip more than once, so the same account '
              'can still be picked on both sides',
        );

        // And picking a NEW From, BPI, removes IT from To instead, live.
        await tester.tap(
          find
              .descendant(
                of: find.byType(PickChip),
                matching: find.textContaining('BPI'),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(PickChip),
            matching: find.textContaining('BPI'),
          ),
          findsOneWidget,
          reason:
              'BPI was picked as From and still appears as a To option, so '
              'the collision this filter exists to prevent is reachable again',
        );
      },
    );

    test(
      'and the engine itself still refuses a same-account transfer, as the floor',
      () {
        // Pure, no widget: the picker is only ONE guard. This is the other, and
        // it is the one that actually stops money moving, per applyTransfer.
        final data = livedIn();
        final worth = _worth(data);
        final count = (data['transactions'] as List).length;

        final out = applyTransfer(
          data,
          fromId: 'a_bpi',
          toId: 'a_bpi',
          amountText: '100',
          today: '2026-09-11',
          genId: () => 'tx_test',
        );

        expect(out.ok, isFalse);
        expect(out.error, 'Pick two different accounts.');
        expect((data['transactions'] as List).length, count);
        expect(_worth(data), closeTo(worth, 0.005));
      },
    );

    testWidgets(
      'with one account there is nowhere to move it, and it says so',
      (tester) async {
        final data = livedIn();
        data['accounts'] = [(data['accounts'] as List).first];
        final store = await memoryStore(data);
        await tester.pumpWidget(_app(store));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Move'));
        await tester.pumpAndSettle();

        expect(find.text('Nowhere to move it yet'), findsOneWidget);
        expect(
          find.textContaining('Add a second account'),
          findsOneWidget,
          reason: 'a dead end with no way forward named',
        );
        expect(
          find.text('Move money'),
          findsNothing,
          reason: 'the sheet opened with nothing to pick',
        );
      },
    );
  });

  group('and a person can SEE what it did', () {
    testWidgets('the receipt names the move and both new balances', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await _move(tester, from: 'BPI', to: 'GCash', amount: '2500');

      // THE FIGURE IS THE TITLE now, "Moved ₱2,500", after an expert review
      // found the dialog said "not income, not spending" twice, once in the
      // sheet's own subtitle and again in the receipt: one promise, once.
      expect(find.textContaining('Moved ₱2,500'), findsOneWidget);
      // The figures on the receipt are read back from the STORE after the
      // write, so they are what is actually saved, not what the sheet meant.
      final bpi = _balance(store.data, 'a_bpi');
      expect(
        find.textContaining('BPI now has'),
        findsOneWidget,
        reason: 'the receipt did not say where the money left from',
      );
      expect(bpi, isNot(isNaN));
    });

    testWidgets('then find it in the Ledger, with the right sign', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await _move(tester, from: 'BPI', to: 'GCash', amount: '2500');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.textContaining('Transfer: BPI to GCash'));
      expect(find.textContaining('Transfer: BPI to GCash'), findsOneWidget);
    });

    testWidgets('and in BOTH accounts, going out of one and into the other', (
      tester,
    ) async {
      // The debt payment defect, guarded against here before it can happen
      // again: the balance moved and nothing in the account's history said
      // why. A transfer carries no accountId, deliberately, so the plain
      // entries lookup cannot see it. accountHistory has to.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await _move(tester, from: 'BPI', to: 'GCash', amount: '2500');

      // MATCHED ON transferFromId AND transferToId together, not on type
      // alone. The fixture already ships an OLD-shaped transfer on BPI (id
      // t7, the accountId plus flow form `entriesFor` has always read), so a
      // filter on type == 'transfer' finds TWO rows and proves nothing about
      // the one this test just made. That was the first version of this
      // assertion, and it read the fixture's own history as a failure.
      final fromLeg = accountHistory(store.data, 'a_bpi').where(
        (t) => t['transferFromId'] == 'a_bpi' && t['transferToId'] == 'a_gcash',
      );
      final toLeg = accountHistory(store.data, 'a_gcash').where(
        (t) => t['transferFromId'] == 'a_bpi' && t['transferToId'] == 'a_gcash',
      );
      expect(
        fromLeg,
        hasLength(1),
        reason:
            'BPI went down by 2,500 and its history has no entry saying why',
      );
      expect(
        toLeg,
        hasLength(1),
        reason:
            'GCash went up by 2,500 and its history has no entry saying why',
      );
      // DIRECTIONAL: out of one, into the other, through the golden locked
      // balanceSign rather than a second opinion here.
      expect(signedAmount(fromLeg.single), closeTo(-2500, 0.005));
      expect(signedAmount(toLeg.single), closeTo(2500, 0.005));

      // And an account that was not part of it sees nothing.
      expect(
        accountHistory(
          store.data,
          'a_cash',
        ).where((t) => t['type'] == 'transfer'),
        isEmpty,
        reason: 'a transfer leaked into an account it never touched',
      );
    });
  });

  // The pre-merge QA pass on this batch found all of these, and every one of
  // them was reachable in four taps from Home. They exist because THIS batch
  // made a `type: 'transfer'` row creatable for the first time, and the entry
  // detail screen predates transfers entirely: it offers the fields of an
  // ordinary entry, and the engine reads a transfer by rules an ordinary
  // entry does not follow.
  group('and editing one can never move money that already moved', () {
    /// Move 5,000, dismiss the receipt, then open the row from the Ledger.
    Future<void> openTheTransfer(WidgetTester tester) async {
      await _move(tester, from: 'BPI', to: 'GCash', amount: '5000');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.textContaining('Transfer: BPI to GCash'));
      await tester.tap(find.textContaining('Transfer: BPI to GCash').first);
      await tester.pumpAndSettle();
    }

    testWidgets('the edit sheet does not offer the amount or the accounts', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await openTheTransfer(tester);

      final worthBefore = _worth(store.data);
      final bpiBefore = _balance(store.data, 'a_bpi');
      final gcashBefore = _balance(store.data, 'a_gcash');
      expect(bpiBefore, isNot(isNaN));

      await tester.tap(find.widgetWithText(PillButton, 'Edit this entry'));
      await tester.pumpAndSettle();

      // THE TWO CONTROLS THAT DESTROYED MONEY. Tapping an account chip gave
      // the row an accountId it is defined not to have: `updateTransaction`
      // then reversed nothing (the old row had no account to reverse through)
      // and applied the new one at balanceSign -1, taking another 5,000 out
      // of an account with nothing receiving it. Editing the amount moved no
      // balance at all and left the row disagreeing with the money forever.
      //
      // SCOPED TO THE SHEET, because the detail screen BEHIND it carries a
      // Details row also titled "Account" (it reads None for a transfer, the
      // honest answer). An unscoped finder matches that row and fails on a
      // screen that is behind glass and perfectly correct.
      Finder inSheet(String label) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(label),
      );
      expect(
        inSheet('Account'),
        findsNothing,
        reason:
            'the account picker is on a transfer again, and one tap on it '
            'debits an account a second time with nothing receiving it',
      );
      expect(
        inSheet('How much'),
        findsNothing,
        reason:
            'the amount is editable on a transfer again, so the row can be '
            'made to disagree with the balances that actually moved',
      );

      // The label IS still editable, and saving it moves nothing.
      await tester.enterText(find.byType(TextField).first, 'Sweldo to GCash');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(
        _worth(store.data),
        closeTo(worthBefore, 0.005),
        reason: 'editing a transfer changed how much the person has',
      );
      expect(_balance(store.data, 'a_bpi'), closeTo(bpiBefore, 0.005));
      expect(_balance(store.data, 'a_gcash'), closeTo(gcashBefore, 0.005));
      // DID ANYTHING HAPPEN. Without this the three assertions above pass
      // perfectly on a save that silently did nothing at all.
      expect(
        find.textContaining('Sweldo to GCash'),
        findsWidgets,
        reason: 'the rename never landed, so this proved nothing about money',
      );
    });

    testWidgets('and the delete warning does not promise a reversal', (
      tester,
    ) async {
      // `removeTransaction` undoes a row through its accountId and a transfer
      // has none, so deleting one leaves both balances exactly where they are
      // and takes away the only row explaining why they moved. The dialog
      // promised the opposite in so many words.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await openTheTransfer(tester);

      await tester.tap(find.text('Delete this entry'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('does NOT move it back'),
        findsOneWidget,
        reason:
            'the confirmation still tells somebody keeping books that their '
            'balances go back to what they were, and they do not',
      );
      expect(
        find.textContaining('goes back to what it was'),
        findsNothing,
        reason: 'the old promise is still on screen for a transfer',
      );
    });

    testWidgets('and the detail screen agrees with Home about the figure', (
      tester,
    ) async {
      // Home and the Ledger both draw from `entryAmountText`; this screen was
      // left on `signedAmount` and read -5,000 for the same row they showed as
      // 5,000. A move is not a loss.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await openTheTransfer(tester);

      expect(
        find.text('-₱5,000'),
        findsNothing,
        reason:
            'the entry screen signs a transfer as a loss while the two '
            'screens you reach it from both call it ₱5,000',
      );
      expect(find.text('₱5,000'), findsWidgets);
    });
  });
}
