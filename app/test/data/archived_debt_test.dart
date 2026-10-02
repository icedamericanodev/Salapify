import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';

/// Archiving a debt, through the real file.
///
/// `stored_shape_test.dart` asserts `debtKeys` CONTAINS 'archivedAt', which
/// is cheap and catches the common mistake. This file does the other thing:
/// it drives the actual encode, decode, clear, re-encode sequence, so it
/// fails for the right reason rather than on a membership check somebody
/// could satisfy while the mechanism underneath stayed broken.
///
/// The failure it guards is the one `paidBeforeSettle` already demonstrated
/// for real, on a merged commit, for about eight hours: Snapshot copies any
/// key this build does not MODEL into an unknown-key sidecar, and on the way
/// back out merges `{...kept, ...own}`. A CLEARED field has no own value to
/// win that merge with, so an undeclared key comes back from the dead.
///
/// Applied here that reads: archive a debt, reload, put it back, save, and
/// the debt silently re-archives itself on the next launch. A liability
/// disappearing off the Debts screen on its own is the worst shape this
/// mechanism can fail in.
void main() {
  const Debt settled = Debt(
    id: 'd1',
    person: 'Home Credit',
    direction: DebtDirection.iOwe,
    totalAmount: Money.pesos(12000),
    paidAmount: Money.pesos(12000),
    isSettled: true,
    settledDate: '2026-09-28',
  );

  final DateTime at = DateTime.utc(2026, 10, 2, 10);

  /// [extras] is NOT optional decoration, and leaving it out is how the
  /// first version of the test below passed with the defect in place.
  ///
  /// A freshly constructed Snapshot carries `Extras.empty()`, so there is no
  /// sidecar to resurrect anything FROM and the branch under test is
  /// unreachable. The save that matters in real life is the one the app
  /// makes after a LOAD, carrying forward whatever the file held that this
  /// build did not model. That is the snapshot this test has to re-encode.
  Snapshot withDebts(List<Debt> debts, {Extras? extras}) => Snapshot(
    extras: extras ?? const Extras.empty(),
    accounts: const <Account>[],
    transactions: const <Transaction>[],
    debts: debts,
    budgets: const <Budget>[],
    goals: const <Goal>[],
    upcoming: const <UpcomingItem>[],
    incomeStreams: const <IncomeStream>[],
    installments: const <InstallmentPlan>[],
    reconciliations: const <ReconciliationRecord>[],
    bills: const <BillItem>[],
    payday: SeedData.payday,
    theme: ThemeMode2.gabi,
    scenario: DecisionScenario.conservative,
  );

  test('an archived debt survives the file', () {
    final Snapshot after = Snapshot.decode(
      withDebts(<Debt>[
        settled.copyWith(archivedAt: '2026-10-02'),
      ]).encode(at: at),
    );

    expect(after.debts.single.archivedAt, '2026-10-02');
    expect(
      after.debts.single.isArchived,
      isTrue,
      reason:
          'the debt came back live, so archiving does not survive a restart '
          'and the whole feature is cosmetic',
    );
  });

  test('a live debt writes no archivedAt key at all', () {
    // The directional half. A codec that wrote the key unconditionally would
    // pass the test above and bloat every untouched debt's row.
    final String wire = withDebts(<Debt>[settled]).encode(at: at);

    expect(
      wire.contains('archivedAt'),
      isFalse,
      reason:
          'a debt nobody archived is carrying the key anyway, so an older '
          'build reading this file sees a field that should not be there',
    );
  });

  test('PUTTING IT BACK is not undone by the unknown-key sidecar', () {
    // The sequence that actually bit this repository once, replayed.

    // 1. Archived, and written to the file.
    final String archived = withDebts(<Debt>[
      settled.copyWith(archivedAt: '2026-10-02'),
    ]).encode(at: at);
    expect(
      archived.contains('archivedAt'),
      isTrue,
      reason: 'the fixture never archived anything, so step 3 proves nothing',
    );

    // 2. Read back, which is where an UNDECLARED key would be filed away in
    //    the sidecar as a stranger's field.
    final Snapshot reloaded = Snapshot.decode(archived);
    expect(reloaded.debts.single.isArchived, isTrue);

    // 3. Put it back, and save again, CARRYING THE SIDECAR the load produced.
    //    This is the whole test. Re-encoding a fresh Snapshot instead would
    //    throw the sidecar away and pass no matter what debtKeys says.
    final Snapshot restored = withDebts(<Debt>[
      reloaded.debts.single.copyWith(clearArchivedAt: true),
    ], extras: reloaded.extras);
    final String wire = restored.encode(at: at);

    expect(
      wire.contains('archivedAt'),
      isFalse,
      reason:
          'the cleared key came back from the unknown-key sidecar, so this '
          'debt re-archives itself on the next launch and the person watches '
          'a liability vanish off the Debts screen on its own',
    );
    expect(
      Snapshot.decode(wire).debts.single.isArchived,
      isFalse,
      reason: 'it reloads still archived, which is the same defect one hop on',
    );
  });

  test('archivedAt is declared as a key this build models', () {
    // Kept alongside the behavioural test above rather than instead of it.
    // This one names the FIX in its failure message, which is what somebody
    // reads at the moment they have broken it.
    expect(
      debtKeys,
      contains('archivedAt'),
      reason:
          'add the string archivedAt to debtKeys in json_codec.dart, or a '
          'cleared value is resurrected from the sidecar',
    );
  });
}
