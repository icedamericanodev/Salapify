import 'package:salapify/core/money/money.dart';
import '../support/net_worth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// Taking a debt off the list, by tapping, the way a person does it.
///
/// Half two of the write-path rule. The money half is in
/// `test/data/debt_removal_test.dart`; this file is the half that gets
/// forgotten, whether a person can SEE what happened and get back.
///
/// The case it is really built around is the round trip. Archiving is the
/// only undo this feature has, so if the way back is unreachable the whole
/// design is a delete with a longer name.
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

  Future<void> openDebts(WidgetTester tester) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();
    await reach(tester, find.byType(DebtBeamCard));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    expect(find.byType(DebtScreen), findsOneWidget);
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<DebtScreen>(find.byType(DebtScreen)).state;

  /// Same shape the bills journey uses, so the two agree on the word.

  testWidgets('a debt with money against it offers no delete, and the card '
      'stays clean', (WidgetTester tester) async {
    await openDebts(tester);

    // Home Credit is part paid and live, the state that gets neither
    // control. The seed phone is ALL in that state, which is why the
    // explanation is behind the header's "i" dot rather than on the card: a
    // sentence here lands on every card forever.
    expect(find.text('Home Credit (Phone)'), findsOneWidget);
    expect(
      find.text('Delete this debt'),
      findsNothing,
      reason: 'a debt with payments is offering an irreversible delete',
    );
    expect(
      find.textContaining('Money is recorded against this debt'),
      findsNothing,
      reason:
          'the per-card explanation is back, which is the wall of grey text '
          'that was removed after looking at the render',
    );
  });

  testWidgets('and the explanation is behind the dot, where a lesson goes', (
    WidgetTester tester,
  ) async {
    // The companion to the test above. Without this one, deleting the info
    // entry entirely would leave a person with no control, no line, and
    // nowhere at all to find out why.
    await openDebts(tester);

    await tapAndSettle(tester, find.byIcon(Icons.info_outline).first);

    expect(
      find.text('Taking a debt off the list'),
      findsOneWidget,
      reason:
          'nothing on this screen or behind its dot explains why some debts '
          'can be removed and others cannot',
    );
  });

  testWidgets('ARCHIVE a settled debt, then PUT IT BACK, both by tapping', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);

    // Settle one first, because archiving is settled only. This also makes
    // the journey the real sequence rather than a fixture shortcut.
    await tapAndSettle(tester, find.text('Mark settled').first);
    await tapAndSettle(tester, find.text('Mark it settled'));

    final int liveAfterSettle = store.debts.length;
    expect(
      store.archivedDebts,
      isEmpty,
      reason: 'settling archived something, which it must never do',
    );

    await reach(tester, find.text('Archive it').first);
    await tapAndSettle(tester, find.text('Archive it').first);
    // The dialog's confirm carries the same words as the card's button, so
    // take the LAST match, which is the one inside the dialog.
    await tapAndSettle(tester, find.text('Archive it').last);

    // THE MIDPOINT. A round trip is unfalsifiable by inaction, so this has
    // to be asserted before the way back is tapped.
    expect(
      store.archivedDebts,
      hasLength(1),
      reason: 'nothing was archived, so the round trip below proves nothing',
    );
    expect(store.debts, hasLength(liveAfterSettle - 1));

    // The way back has to be REACHABLE, not merely implemented.
    await reach(tester, find.text('ARCHIVED'));
    expect(find.text('ARCHIVED'), findsOneWidget);

    await reach(tester, find.text('Put it back'));
    await tapAndSettle(tester, find.text('Put it back'));

    expect(
      store.archivedDebts,
      isEmpty,
      reason: 'the only way back out of the archive does not work',
    );
    expect(store.debts, hasLength(liveAfterSettle));
    expect(find.text('ARCHIVED'), findsNothing);
  });

  testWidgets('DELETE a debt by tapping, and the screens agree afterwards', (
    WidgetTester tester,
  ) async {
    // The irreversible path, walked the way a person walks it.
    //
    // This journey is here because a review pass found it missing. Delete had
    // unit coverage in test/data/debt_removal_test.dart and the only mention
    // of the button in any journey was a findsNothing assertion. So the one
    // action in this feature that destroys a record for good was never once
    // tapped, confirmed and followed to the screens that should change.
    await openDebts(tester);
    final FinancialState store = storeOf(tester);

    // Kuya Mark is the seeded debt with nothing paid, so it is the only kind
    // that can be deleted. It is money LENT, so it lives the other way round.
    await tapAndSettle(tester, find.text('Owed to you'));

    final int before = store.debts.length;
    final double owedBefore = store.debtsOwedToMe;
    final int entriesBefore = store.transactions.length;
    expect(find.text('Kuya Mark'), findsOneWidget);

    await reach(tester, find.text('Delete this debt').first);
    await tapAndSettle(tester, find.text('Delete this debt').first);

    // The confirmation has to state the consequence in FIGURES, and say the
    // one thing that matters about this path.
    expect(find.textContaining('There is no undo'), findsOneWidget);
    await tapAndSettle(tester, find.text('Delete'));

    expect(
      store.debts,
      hasLength(before - 1),
      reason: 'the delete did nothing, so every assertion below is hollow',
    );
    expect(
      find.text('Kuya Mark'),
      findsNothing,
      reason: 'the debt is gone from the store and still on the screen',
    );
    // Deleting a debt SHOULD move this figure, unlike archiving. That is the
    // difference between the two and it is worth pinning.
    expect(store.debtsOwedToMe, lessThan(owedBefore));
    expect(
      store.transactions,
      hasLength(entriesBefore),
      reason: 'deleting a debt invented or destroyed a ledger entry',
    );
  });

  testWidgets('UN-SETTLE by tapping, and the real paid figure is on screen', (
    WidgetTester tester,
  ) async {
    // The path that destroyed 4,650.00 of a founder's data.
    //
    // It has engine vectors (core/money/settle_toggle_test.dart) and a
    // screenshot, and until this review it had no journey: nothing walked to
    // the screen and checked that the restored figure is READABLE where a
    // person looks for it. That gap is the exact failure mode the house rule
    // exists for, the write being right where it was written and invisible
    // where it is read.
    await openDebts(tester);
    final FinancialState store = storeOf(tester);

    // Home Credit: 7,350.00 paid of 14,700.00.
    expect(find.text('Home Credit (Phone)'), findsOneWidget);
    expect(find.textContaining('of ₱14,700.00 so far'), findsOneWidget);
    final double owedBefore = store.debtsIOwe;

    await tapAndSettle(tester, find.text('Mark settled').first);
    await tapAndSettle(tester, find.text('Mark it settled'));

    // The midpoint, so the round trip below cannot pass by doing nothing.
    expect(
      store.debtsIOwe,
      lessThan(owedBefore),
      reason: 'settling changed nothing, so un-settling proves nothing',
    );

    await tapAndSettle(tester, find.text('Not settled after all').first);

    expect(
      store.debtsIOwe,
      owedBefore,
      reason:
          'the real paid figure was not restored, which is the 4,650.00 '
          'data loss returning',
    );
    // AND a person can read it. The store being right is half the job.
    //
    // Scrolled UP first, deliberately. Un-settling moves the card from
    // CLEARED at the bottom back to the open list at the top, and this list
    // only builds its visible range, so the card is genuinely not in the
    // widget tree until the view reaches it. A first version of this
    // assertion read that as the card failing to show the figure, which
    // would have been a false alarm reported as a defect.
    await tester.scrollUntilVisible(
      find.text('Home Credit (Phone)'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('₱7,350.00 of ₱14,700.00 so far'),
      findsOneWidget,
      reason:
          'the figure is correct in the store and the card does not show it, '
          'which is exactly how this defect hid the first time',
    );
  });

  testWidgets('archiving moves no money and writes no entry', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);

    await tapAndSettle(tester, find.text('Mark settled').first);
    await tapAndSettle(tester, find.text('Mark it settled'));

    final double owedBefore = store.debtsIOwe;
    final int entriesBefore = store.transactions.length;
    final Money netBefore = netWorthOf(store);

    await reach(tester, find.text('Archive it').first);
    await tapAndSettle(tester, find.text('Archive it').first);
    await tapAndSettle(tester, find.text('Archive it').last);

    expect(store.archivedDebts, hasLength(1), reason: 'nothing happened');
    expect(
      store.debtsIOwe,
      owedBefore,
      reason:
          'archiving changed what you owe, which is the whole thing the '
          'settled only gate exists to prevent',
    );
    expect(netWorthOf(store), netBefore);
    expect(
      store.transactions,
      hasLength(entriesBefore),
      reason: 'archiving invented a ledger entry',
    );
  });
}
