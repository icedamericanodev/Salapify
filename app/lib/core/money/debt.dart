/// The debt register's engine, ported from src/context/FinancialContext.tsx
/// (`recordDebtPayment`, `toggleDebtSettled`) and src/components/DebtScreen.tsx.
///
/// Debt here means BOTH DIRECTIONS: what you owe, and what is owed to you.
/// That is the product's whole point, and it is why nothing in this file
/// treats one direction as the default and the other as a special case.
///
/// A payment has TWO halves and this file produces both:
///   1. the debt itself moves, which [applyDebtPayment] does, and
///   2. a ledger entry explains why an account balance changed, which
///      [paymentEntry] builds.
/// The second half is not optional garnish. A founder once paid 1,500 off a
/// loan, opened the account it came out of, and found nothing in its history:
/// the balance had moved with no entry explaining it, which for anybody who
/// keeps books is the defect. Every money test was green at the time.
library;

import '../../models/models.dart';
import 'money.dart';

/// Applies a payment to one debt and returns the whole list back.
///
/// The rules are the prototype's, verbatim:
/// - paid goes up by the amount, and is NOT capped at the total, so an
///   overpayment is visible rather than silently swallowed;
/// - settled the moment paid reaches the total;
/// - the settled date is stamped only on the transition, and a debt that was
///   already settled keeps the date it had;
/// - the instalment counter advances, capped at the total, and stays null on
///   a debt that never had one.
///
/// [today] is passed in rather than read from the clock, so a test can pin it
/// and a screenshot can be deterministic.
List<Debt> applyDebtPayment(
  List<Debt> debts,
  String debtId,
  Money amount, {
  required DateTime today,
}) {
  if (!amount.isPositive) return debts;

  return debts.map((Debt d) {
    if (d.id != debtId) return d;

    // IN WHOLE CENTAVOS, which is what makes the comparison below mean what
    // it says. On doubles, a debt of 78,510.57 paid with 70,662.84 and then
    // 7,847.73 accumulated to 78,510.56999999999, so `>=` was false and the
    // card read "0.00 remaining" and "not settled" at the same time. Two
    // ordinary typed figures, and for somebody keeping books a row that
    // contradicts itself discredits every other figure on the screen.
    final Money newPaid = d.paidAmount + amount;
    final bool settled = newPaid >= d.totalAmount;

    return d.copyWith(
      paidAmount: newPaid,
      isSettled: settled,
      settledDate: settled ? (d.settledDate ?? isoDate(today)) : d.settledDate,
      installmentCurrent: d.installmentCurrent == null
          ? null
          : _min(d.installmentTotal ?? 12, d.installmentCurrent! + 1),
    );
  }).toList();
}

int _min(int a, int b) => a < b ? a : b;

/// Marks a debt settled, or un-settles it.
///
/// Settling FILLS the paid amount to the total, which is what makes the
/// button honest: "settled" and "still owes 7,350" cannot both be true on one
/// row.
///
/// UN-SETTLING PUTS THE REAL FIGURE BACK when the fill is what put it there,
/// and leaves it alone otherwise. That distinction is the whole of this
/// function's difficulty, and getting it wrong destroyed money data.
///
/// The old rule was "un-settling never winds the paid amount back", and its
/// reasoning was sound for the case it was written for: a debt settled by
/// real payments really was paid, so inventing a smaller figure would be
/// worse than a wrong flag. But the same function also served a debt settled
/// BY THE BUTTON, where the fill was invented. Two taps, neither confirmed:
///
///     start        : paid 7,350.00 of 12,000.00
///     Mark settled : paid 12,000.00
///     Not settled  : paid 12,000.00, and 7,350.00 is gone for good
///
/// 4,650.00 nobody paid, recorded as paid, with no way back: a debt keeps no
/// payment history and there is no edit or delete for one. "Not settled after
/// all" is exactly the button somebody taps believing it is the way back.
///
/// [Debt.paidBeforeSettle] is what separates the two cases, and null is a
/// meaningful value rather than a missing one. It is set only by the fill
/// here, so a debt settled by payments, or stored before this field existed,
/// reads null and keeps the old behaviour, which is right for it.
///
/// Founder direction, 2026-10-01, choosing this over signposting it with a
/// warning: put the real figure back.
List<Debt> toggleDebtSettled(
  List<Debt> debts,
  String debtId, {
  required DateTime today,
}) {
  return debts.map((Debt d) {
    if (d.id != debtId) return d;
    final bool next = !d.isSettled;

    if (next) {
      return d.copyWith(
        isSettled: true,
        paidAmount: d.totalAmount,
        settledDate: isoDate(today),
        // Remembered BEFORE the fill overwrites it. Nothing else in the app
        // records what this debt had actually been paid.
        paidBeforeSettle: d.paidAmount,
      );
    }

    return d.copyWith(
      isSettled: false,
      paidAmount: d.paidBeforeSettle ?? d.paidAmount,
      clearSettledDate: true,
      // Spent. Leaving it would let a later un-settle wind back to a figure
      // from a settle that has already been undone.
      clearPaidBeforeSettle: true,
    );
  }).toList();
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The ledger entry a payment writes, or null when no account was chosen.
///
/// The direction decides everything: paying somebody is an EXPENSE out of the
/// chosen account, and being repaid is INCOME into it. The categories and
/// sub-categories are the prototype's own, and both already exist in the
/// app's category list, so an entry written here is filed somewhere Reports
/// and Budgets can find it rather than under a name nothing recognises.
///
/// An accountId is REQUIRED on the returned entry, unlike the archived
/// Salapify 2 engine which deliberately left it off. Here the balance moves
/// through the ordinary logging path, so the entry has to name the account it
/// came out of or the two halves cannot be reconciled.
Transaction? paymentEntry({
  required Debt debt,
  required double amount,
  required String? accountId,
  required DateTime today,
  required String id,
}) {
  if (accountId == null || amount <= 0) return null;

  final bool owing = debt.direction == DebtDirection.iOwe;

  return Transaction(
    id: id,
    type: owing ? TransactionType.expense : TransactionType.income,
    amount: Money.fromDouble(amount),
    category: owing ? 'Debt & Loan Servicing' : 'Receivables & Repayments',
    subcategory: owing
        ? 'Personal Loan Installment'
        : 'Pahiram Repayment Collected',
    accountId: accountId,
    person: debt.person,
    merchant: owing
        ? 'Repayment to ${debt.person}'
        : 'Repayment from ${debt.person}',
    date: isoDate(today),
    note: owing
        ? 'Payment for debt: ${debt.person}'
        : 'Collected pahiram from ${debt.person}',
    tags: <String>[owing ? '#debt-payment' : '#receivable-collected'],
    status: TransactionStatus.confirmed,
    profile: ProfileEntity.personal,
    createdAt: today.millisecondsSinceEpoch,
  );
}

/// What is still outstanding in one direction, settled debts excluded.
Money outstanding(List<Debt> debts, DebtDirection direction) => sumMoney(
  debts
      .where((Debt d) => !d.isSettled && d.direction == direction)
      .map((Debt d) => d.remaining),
);

/// The two halves of the beam on Home and on the Debt screen.
///
/// Clamped to between 10 and 90 percent, the prototype's own rule, so the
/// smaller side never collapses to an invisible sliver. That means the beam is
/// an ILLUSTRATION and not a measurement, and the figures beside it are what a
/// person should read.
({double owedToMe, double youOwe}) beamSplit(List<Debt> debts) {
  final Money mine = outstanding(debts, DebtDirection.owedToMe);
  final Money theirs = outstanding(debts, DebtDirection.iOwe);
  final Money total = mine + theirs;
  if (!total.isPositive) return (owedToMe: 50, youOwe: 50);
  // A proportion, so it divides centavos by centavos and stays a double.
  // The beam is an illustration; the figures beside it are the measurement.
  final double raw = mine.centavos / total.centavos * 100;
  final double clamped = raw.clamp(10.0, 90.0);
  return (owedToMe: clamped, youOwe: 100 - clamped);
}

/// The debts in one direction, open ones first and settled ones after.
///
/// Settled debts are KEPT rather than hidden. A cleared debt is the only
/// evidence a person has that they cleared it, and a register that forgets
/// what you paid off is a register nobody trusts.
({List<Debt> open, List<Debt> settled}) splitByStatus(
  List<Debt> debts,
  DebtDirection direction,
) {
  final List<Debt> inDirection = debts
      .where((Debt d) => d.direction == direction)
      .toList();
  return (
    open: inDirection.where((Debt d) => !d.isSettled).toList(),
    settled: inDirection.where((Debt d) => d.isSettled).toList(),
  );
}

/// Reads an amount the way the rest of the app does, so "1,500" works.
double? parseDebtAmount(String raw) {
  final double? v = double.tryParse(raw.trim().replaceAll(',', ''));
  if (v == null || v <= 0) return null;
  return v;
}
