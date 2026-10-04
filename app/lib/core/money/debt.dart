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

  /// Which account the money left, kept on the register row so a reversal
  /// knows where to put it back. Legitimately null: paying with no account is
  /// a real choice for somebody settling in cash they never logged, and the
  /// sheet says so before they confirm.
  String? accountId,

  /// Supplied by the caller so the register row and the ledger row it writes
  /// can be tied together. Defaults to a clock-derived id, which is fine for
  /// an engine test and not fine for the app, where the two have to match.
  String? paymentId,

  /// The ledger row this payment writes, when it writes one.
  ///
  /// Null is a real answer, not a missing one: a payment recorded with no
  /// account writes no entry at all, so there is nothing to point at. Taking
  /// one of those back moves the debt and must not go hunting for a row.
  String? txId,
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
      // THE THREE FIGURES THAT CANNOT BE RECOMPUTED, written down as they
      // were before this payment landed.
      //
      // `settledDate` is stamped only on the transition and a further payment
      // on an already settled debt keeps the original, so clearing it on the
      // way back is right in one case and destroys a real date in the other.
      // `installmentCurrent` saturates, so the last payment of a plan does not
      // move it and decrementing later would invent a payment nobody undid.
      // `paidAmount` is stored rather than derived by subtraction because
      // "Mark settled" can FILL it between two payments, after which the
      // running figure is not the sum of the payments and nothing else in the
      // app can tell you the difference.
      payments: <DebtPayment>[
        ...d.payments,
        DebtPayment(
          id: paymentId ?? 'dp_${today.microsecondsSinceEpoch}',
          date: isoDate(today),
          amount: amount,
          paidBefore: d.paidAmount,
          settledBefore: d.isSettled,
          settledDateBefore: d.settledDate,
          installmentCurrentBefore: d.installmentCurrent,
          accountId: accountId,
          txId: txId,
        ),
      ],
    );
  }).toList();
}

int _min(int a, int b) => a < b ? a : b;

/// Takes the MOST RECENT payment back off a debt, restoring what it moved.
///
/// Returns the debts unchanged when there is nothing to take back, which is
/// every debt that has not been paid through this build and every debt from a
/// restored backup. That is not a failure to report, it is the honest answer:
/// nothing is known about how those reached their figure.
///
/// ## Why only the most recent one
///
/// Not an implementation shortcut. `paidAmount` is a single running figure, so
/// a row's `paidBefore` is only the right answer to put back if nothing landed
/// after it. Restoring an older row would wind the debt back past payments
/// that still stand, and the register would then describe a debt that does not
/// exist. A caller wanting an older one has to take the later ones back first,
/// which is also the only order a person can actually reason about.
///
/// ## Why it restores rather than subtracts
///
/// Subtracting the amount gets `paidAmount` back and nothing else.
/// `settledDate` is stamped only on the transition, `installmentCurrent`
/// saturates, and "Mark settled" can FILL the paid figure between two
/// payments. All three are read off the row instead.
List<Debt> reverseLastDebtPayment(List<Debt> debts, String debtId) {
  return debts.map((Debt d) {
    if (d.id != debtId || d.payments.isEmpty) return d;

    final DebtPayment row = d.payments.last;

    return d.copyWith(
      paidAmount: row.paidBefore,
      isSettled: row.settledBefore,
      settledDate: row.settledDateBefore,
      // `settledDate` is nullable and copyWith treats null as "leave it", so
      // clearing needs saying out loud. Without this a debt that was NOT
      // settled before the payment keeps the date the payment stamped on it.
      clearSettledDate: row.settledDateBefore == null,
      // AND THE SETTLE MEMORY, for the same reason one line up.
      //
      // `paidBeforeSettle` only ever describes a settle that is IN FORCE.
      // Rewinding a payment past the settle that followed it leaves the
      // figure describing nothing, and copyWith carries it through unless
      // told otherwise, so it stayed attached to the debt, on no screen,
      // until the next un-settle spent it and destroyed the difference.
      //
      // Measured at 600.00 on a 1,000.00 debt: pay 400, settle, take it
      // back, pay the full 1,000, then un-settle, and the debt claims 400
      // was paid while the account is 1,000 down with a confirmed entry
      // explaining it. That is the data loss this field exists to prevent,
      // arriving through the take-back door.
      //
      // Only when the debt comes back UN-settled. A stray payment on an
      // already settled debt, taken back, leaves the settle standing, and
      // its memory is still the real figure.
      clearPaidBeforeSettle: !row.settledBefore,
      installmentCurrent: row.installmentCurrentBefore,
      payments: d.payments.sublist(0, d.payments.length - 1),
    );
  }).toList();
}

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

/// What every debt you owe costs you in a month, added up.
///
/// This is what Safe to Spend holds back at step 4, and it REPLACES the
/// prototype's `debtsIOwe * 0.08`. See [Debt.monthlyMinimum] for the rule and
/// for the measurement that shows the percentage is wrong in both directions.
///
/// Deliberately returns a figure that can be ZERO, and zero is a real answer
/// rather than a missing one: a person whose only debt is money owed to a
/// relative, with no schedule, genuinely has no monthly obligation to reserve
/// against, and the app inventing one for them is the defect this closes.
///
/// Only the `iOwe` direction. Money owed TO you is not something you have to
/// find every month, and counting it here would reserve your own spending
/// money against somebody else's debt.
Money monthlyDebtMinimums(List<Debt> debts) => sumMoney(
  debts
      .where((Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe)
      .map((Debt d) => d.monthlyMinimum)
      .whereType<Money>(),
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
