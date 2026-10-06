import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Take back the NEWEST payment, looking its id up the way a screen does.
///
/// `takeBackDebtPayment` and `takeBackPlanPayment` require the caller to name
/// the payment it believes it is removing, and refuse if that is not the last
/// row. The reason is written where those methods live: once a list of
/// payments is on screen, the obvious next step is a control on each row built
/// from the TAPPED row, and without the id the store would silently remove a
/// different payment than the confirmation just described in pesos.
///
/// These helpers exist so that discipline costs the tests nothing. Every call
/// site here means "the newest one", which is what they meant before the
/// parameter existed, so this preserves their intent exactly rather than
/// quietly changing what they assert.
///
/// A test that wants to prove the REFUSAL calls the store directly with a
/// deliberately wrong id. Do not add a helper for that: the whole point is
/// that it should look unusual.
/// BOTH lists are searched, and that is not defensive padding.
///
/// `FinancialState.debts` and `.installments` deliberately EXCLUDE archived
/// records (`financial_state.dart:421` and `:447`); the archived ones live in
/// `archivedDebts` and `archivedInstallments`. The store's take-backs work on
/// the raw `_debts` and `_installments`, so they happily act on an archived
/// record, and `plan_removal_test.dart` relies on exactly that: taking back
/// the payment that cleared a plan is what brings it back off the archive.
///
/// The first version of this helper looked only at the unarchived list, found
/// nothing for an archived plan, passed an empty id, and the store correctly
/// refused. Two tests went red and the helper was the only thing wrong.
bool takeBackNewestDebtPayment(FinancialState s, String debtId) {
  final Debt? d = <Debt>[
    ...s.debts,
    ...s.archivedDebts,
  ].where((Debt d) => d.id == debtId).firstOrNull;
  // An empty or missing register still has to reach the store, because
  // returning false from here would make the helper, rather than the code
  // under test, the thing that refused.
  final String id = (d == null || d.payments.isEmpty) ? '' : d.payments.last.id;
  return s.takeBackDebtPayment(debtId, paymentId: id);
}

bool takeBackNewestPlanPayment(FinancialState s, String planId) {
  final InstallmentPlan? p = <InstallmentPlan>[
    ...s.installments,
    ...s.archivedInstallments,
  ].where((InstallmentPlan p) => p.id == planId).firstOrNull;
  final String id = (p == null || p.payments.isEmpty) ? '' : p.payments.last.id;
  return s.takeBackPlanPayment(planId, paymentId: id);
}
