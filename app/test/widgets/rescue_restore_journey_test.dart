// Rescuing an unreadable ledger from a backup, and what the person SEES
// afterwards.
//
// The money half of this path was already tested and already correct: the
// import lands, the raw bytes are kept as the pre-import copy, and saving
// turns back on. `test/data/import_state_test.dart` asserts all of it.
//
// What no test asked was the second half, and CLAUDE.md names this failure
// mode by itself: "A write path is not tested until somebody can SEE what it
// did". The rescue worked perfectly and every screen went on saying it had
// failed, because the branch that handles the unreadable case never cleared
// `_loadStatus` or `_loadProblem`. The ordinary branch, eight lines below it,
// clears both and carries a comment explaining why.
//
// What that costs is not cosmetic. Somebody who has just rescued their ledger
// is told, over their own correct figures, that Salapify cannot read their
// data and that nothing they type is being saved. The reasonable responses
// are to restore again, to wipe, or to uninstall, and uninstalling at that
// moment deletes the real, correct, saved file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import '../support/pinned_app.dart';

void main() {
  const Account rescued = Account(
    id: 'acc_real',
    name: 'BPI Payroll',
    kind: AccountKind.bank,
    institution: 'BPI',
    balance: Money.pesos(50000),
    monogram: 'BP',
  );

  Snapshot ledgerOf(List<Account> accounts) => Snapshot(
    accounts: accounts,
    transactions: const <Transaction>[],
    debts: const <Debt>[],
    budgets: const <Budget>[],
    goals: const <Goal>[],
    upcoming: const <UpcomingItem>[],
    incomeStreams: const <IncomeStream>[],
    installments: const <InstallmentPlan>[],
    reconciliations: const <ReconciliationRecord>[],
    bills: const <BillItem>[],
    payday: PaydayCycle.unset,
    theme: ThemeMode2.gabi,
    scenario: DecisionScenario.conservative,
  );

  /// An app whose data file will not decode, pumped and settled.
  Future<(FinancialState, MemorySnapshotStore)> unreadableApp(
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Not valid JSON at all, so both generations fail and the load lands on
    // `unreadable` rather than on `recovered`.
    final MemorySnapshotStore store = MemorySnapshotStore('{ not json');
    final FinancialState s = FinancialState(clock: testToday, store: store);
    await s.restore();
    addTearDown(s.dispose);
    await tester.pumpWidget(SalapifyApp(state: s));
    await tester.pumpAndSettle();
    return (s, store);
  }

  testWidgets('the rescue works, and every screen stops saying it failed', (
    WidgetTester tester,
  ) async {
    final (FinancialState s, MemorySnapshotStore store) = await unreadableApp(
      tester,
    );

    // The starting state is real, and the warning on it is correct and must
    // be here. Without this the assertions below could pass on an app that
    // never warned about anything.
    expect(s.loadStatus, LoadStatus.unreadable);
    expect(
      find.textContaining('These figures are not yours'),
      findsOneWidget,
      reason: 'the fixture is not actually in the unreadable state',
    );

    // The rescue, through the store the way Settings drives it.
    final bool ok = await s.importSnapshot(ledgerOf(<Account>[rescued]));
    await tester.pumpAndSettle();

    // HALF ONE, the money. Already covered elsewhere, repeated here so a
    // failure in half two cannot be mistaken for the import not happening.
    expect(ok, isTrue);
    expect(s.accounts.single.id, 'acc_real');
    expect(s.isSaving, isTrue);
    expect(
      store.preImport,
      '{ not json',
      reason: 'the damaged bytes were not kept, so there is no way back',
    );

    // HALF TWO, what a person can SEE. This is the half that was missing.
    expect(
      s.loadStatus,
      LoadStatus.loaded,
      reason:
          'the ledger loaded correctly and the app still calls it unreadable',
    );
    expect(
      s.loadProblem,
      isNull,
      reason: 'a stale problem message survives onto a healthy ledger',
    );

    expect(
      find.textContaining('These figures are not yours'),
      findsNothing,
      reason:
          'the rescue succeeded and Home still tells the person their figures '
          'are not theirs and nothing is being saved, over their own correct '
          'money. The reasonable next move is to uninstall, which deletes the '
          'file that was just restored',
    );
    expect(
      find.textContaining('could not read'),
      findsNothing,
      reason: 'a sentence about an unreadable file survived the rescue',
    );
  });

  testWidgets('and Settings agrees that saving is working', (
    WidgetTester tester,
  ) async {
    final (FinancialState s, _) = await unreadableApp(tester);
    await s.importSnapshot(ledgerOf(<Account>[rescued]));
    await tester.pumpAndSettle();

    // Settings computes its own verdict from `saveProblem` and `loadStatus`
    // rather than reading a flag, so it can disagree with Home. Checked
    // separately for that reason.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('NOT being saved'),
      findsNothing,
      reason: 'Settings says the entries are not being saved, and they are',
    );
    expect(
      find.textContaining('Salapify cannot read'),
      findsNothing,
      reason:
          'the export row still offers "the file Salapify cannot read", so '
          'the person files their only good backup under a name that says it '
          'is broken',
    );
  });
}
