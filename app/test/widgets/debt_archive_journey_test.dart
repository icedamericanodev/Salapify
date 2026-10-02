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
  double netWorthOf(FinancialState s) =>
      s.accounts.fold<double>(0, (double sum, Account a) => sum + a.balance.pesos);

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

  testWidgets('archiving moves no money and writes no entry', (
    WidgetTester tester,
  ) async {
    await openDebts(tester);
    final FinancialState store = storeOf(tester);

    await tapAndSettle(tester, find.text('Mark settled').first);
    await tapAndSettle(tester, find.text('Mark it settled'));

    final double owedBefore = store.debtsIOwe;
    final int entriesBefore = store.transactions.length;
    final double netBefore = netWorthOf(store);

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
