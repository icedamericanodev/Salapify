/// Instalment plans, ported from src/context/FinancialContext.tsx
/// (`recordInstallmentPayment`, `recordInstallmentExtraPayment`) and
/// src/components/InstallmentsView.tsx.
///
/// A plan is a CONTRACT, which is what separates it from a Debt: fixed term,
/// fixed cycle, a maturity date, and a rate agreed at the start. So paying one
/// advances a COUNTER rather than subtracting a figure somebody typed, and the
/// two remaining balances (what is left overall, and how much of that is
/// principal) move by different amounts on the same payment.
///
/// Like every other write path here it has two halves: the plan moves, and a
/// ledger entry explains why an account balance changed.
library;

import 'dart:math' as math;

import '../../models/models.dart';
import 'debt.dart' show isoDate;

/// The subcategory an instalment payment is filed under.
///
/// The prototype writes `'Personal Loan'`, WHICH DOES NOT EXIST in its own
/// category list. That list carries 'Personal Loan Installment' and, better
/// still for this, 'Gadget Loan (Home Credit/SpayLater/LazPay)', a name
/// invented for exactly these plans: it lists two of the three seeded
/// providers by name.
///
/// Filing under a name nothing recognises is not cosmetic. Budgets and the
/// Reports sub-breakdown both group by subcategory, so the money would sit
/// perfectly in the ledger and vanish from every summary that reads it.
const String installmentSubcategory =
    'Gadget Loan (Home Credit/SpayLater/LazPay)';

/// Advances a plan by one scheduled instalment.
///
/// The prototype's rules, verbatim:
/// - the paid counter goes up by one;
/// - settled the moment the counter reaches the total;
/// - once settled BOTH remaining balances go to zero, rather than being left
///   with a rounding crumb on them;
/// - otherwise the running balance drops by the instalment (principal AND
///   interest, which is what you actually hand over) while the principal
///   remaining drops by only its own share.
///
/// Those last two moving by different amounts is the whole point of keeping
/// both: it is how somebody can see that an early payment is mostly interest.
List<InstallmentPlan> applyInstallmentPayment(
  List<InstallmentPlan> plans,
  String id,
) {
  return plans.map((InstallmentPlan p) {
    if (p.id != id || p.isSettled) return p;

    final int nextPaid = p.paidInstallments + 1;
    final bool settled = nextPaid >= p.totalInstallments;
    final double perInstallmentPrincipal = p.totalInstallments <= 0
        ? 0
        : p.principal / p.totalInstallments;

    final double nextBalance = settled
        ? 0
        : math.max(0, p.runningBalance - p.installmentAmount);
    final double nextPrincipal = settled
        ? 0
        : math.max(0, p.principalRemaining - perInstallmentPrincipal);

    return _copy(
      p,
      paidInstallments: nextPaid,
      runningBalance: nextBalance,
      principalRemaining: nextPrincipal,
      interestRemaining: settled ? 0 : math.max(0, nextBalance - nextPrincipal),
      isSettled: settled,
    );
  }).toList();
}

/// Records money paid on TOP of the schedule.
///
/// An extra payment comes straight off the principal, which is why it is worth
/// making: it takes interest off the end of the plan rather than paying the
/// interest that was already going to be charged. Both balances drop by the
/// full amount, the prototype's own rule.
List<InstallmentPlan> applyExtraPayment(
  List<InstallmentPlan> plans,
  String id,
  double amount, {
  required DateTime today,
  String? note,
  String? extraId,
}) {
  if (amount <= 0) return plans;

  return plans.map((InstallmentPlan p) {
    if (p.id != id) return p;

    final double nextBalance = math.max(0, p.runningBalance - amount);
    final double nextPrincipal = math.max(0, p.principalRemaining - amount);

    return _copy(
      p,
      runningBalance: nextBalance,
      principalRemaining: nextPrincipal,
      interestRemaining: math.max(0, nextBalance - nextPrincipal),
      isSettled: nextBalance <= 0,
      extraPayments: <ExtraPayment>[
        ...p.extraPayments,
        ExtraPayment(
          id: extraId ?? 'ext_${today.microsecondsSinceEpoch}',
          date: isoDate(today),
          amount: amount,
          note: note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Principal prepayment',
        ),
      ],
    );
  }).toList();
}

/// The ledger entry a scheduled instalment writes, or null with no account.
Transaction? installmentEntry({
  required InstallmentPlan plan,
  required int installmentNumber,
  required String? accountId,
  required DateTime today,
  required String id,
}) {
  if (accountId == null) return null;
  return Transaction(
    id: id,
    type: TransactionType.expense,
    amount: plan.installmentAmount,
    category: 'Debt & Loan Servicing',
    subcategory: installmentSubcategory,
    accountId: accountId,
    merchant: '${plan.provider}, ${plan.name}',
    date: isoDate(today),
    note:
        'Installment $installmentNumber of ${plan.totalInstallments}: '
        '${plan.name}',
    tags: const <String>['#installment', '#debt'],
    status: TransactionStatus.confirmed,
    profile: ProfileEntity.personal,
    createdAt: today.millisecondsSinceEpoch,
  );
}

/// The ledger entry an EXTRA payment writes.
Transaction? extraPaymentEntry({
  required InstallmentPlan plan,
  required double amount,
  required String? accountId,
  required DateTime today,
  required String id,
  String? note,
}) {
  if (accountId == null || amount <= 0) return null;
  return Transaction(
    id: id,
    type: TransactionType.expense,
    amount: amount,
    category: 'Debt & Loan Servicing',
    subcategory: installmentSubcategory,
    accountId: accountId,
    merchant: '${plan.provider}, ${plan.name}',
    date: isoDate(today),
    note:
        'Prepayment on ${plan.name}'
        '${note != null && note.trim().isNotEmpty ? ', ${note.trim()}' : ''}',
    tags: const <String>['#installment', '#prepayment'],
    status: TransactionStatus.confirmed,
    profile: ProfileEntity.personal,
    createdAt: today.millisecondsSinceEpoch,
  );
}

/// What every open plan costs in a month, together.
///
/// Settled plans are excluded: a finished plan takes nothing out of next
/// month's money, however recently it finished.
double monthlyInstallmentLoad(List<InstallmentPlan> plans) => plans
    .where((InstallmentPlan p) => !p.isSettled)
    .fold<double>(0, (double s, InstallmentPlan p) => s + p.installmentAmount);

/// Everything still owed across every open plan.
double totalStillOwed(List<InstallmentPlan> plans) => plans
    .where((InstallmentPlan p) => !p.isSettled)
    .fold<double>(0, (double s, InstallmentPlan p) => s + p.runningBalance);

/// The interest an open plan has NOT yet been charged, across all of them.
///
/// This is the figure worth showing beside an extra-payment button, because it
/// is the part a prepayment can still take away. Interest already charged is
/// gone whatever anybody does now.
double interestStillToCome(List<InstallmentPlan> plans) => plans
    .where((InstallmentPlan p) => !p.isSettled)
    .fold<double>(0, (double s, InstallmentPlan p) => s + p.interestRemaining);

/// Open plans first, settled ones after. Settled plans are KEPT, for the same
/// reason a cleared debt is: it is the only record that it was cleared.
({List<InstallmentPlan> open, List<InstallmentPlan> settled}) splitPlans(
  List<InstallmentPlan> plans,
) => (
  open: plans.where((InstallmentPlan p) => !p.isSettled).toList(),
  settled: plans.where((InstallmentPlan p) => p.isSettled).toList(),
);

/// How the rate was quoted, in words, because the number alone is meaningless.
/// "1.5" is 18 a year if it is monthly and 1.5 a year if it is annual.
String rateLabel(InstallmentPlan p) {
  if (p.isZeroInterest) return 'No interest';
  return switch (p.interestRateType) {
    InterestRateType.monthly => '${p.interestRate}% a month',
    InterestRateType.annual => '${p.interestRate}% a year',
    InterestRateType.daily => '${p.interestRate}% a day',
    InterestRateType.fixed => '${p.interestRate}% fixed',
  };
}

/// What that rate works out to over a year, for the ones quoted per month or
/// per day. Simple multiplication, not compounding, which is how the lender
/// quotes it and therefore the comparison a person can check.
double? annualisedRate(InstallmentPlan p) => switch (p.interestRateType) {
  InterestRateType.monthly => p.interestRate * 12,
  InterestRateType.daily => p.interestRate * 365,
  InterestRateType.annual || InterestRateType.fixed => null,
};

InstallmentPlan _copy(
  InstallmentPlan p, {
  int? paidInstallments,
  double? runningBalance,
  double? principalRemaining,
  double? interestRemaining,
  bool? isSettled,
  List<ExtraPayment>? extraPayments,
}) => InstallmentPlan(
  id: p.id,
  name: p.name,
  provider: p.provider,
  principal: p.principal,
  interestRate: p.interestRate,
  interestRateType: p.interestRateType,
  totalInterest: p.totalInterest,
  totalPayable: p.totalPayable,
  termMonths: p.termMonths,
  paymentFrequency: p.paymentFrequency,
  startDate: p.startDate,
  maturityDate: p.maturityDate,
  installmentAmount: p.installmentAmount,
  paidInstallments: paidInstallments ?? p.paidInstallments,
  totalInstallments: p.totalInstallments,
  runningBalance: runningBalance ?? p.runningBalance,
  principalRemaining: principalRemaining ?? p.principalRemaining,
  interestRemaining: interestRemaining ?? p.interestRemaining,
  extraPayments: extraPayments ?? p.extraPayments,
  isSettled: isSettled ?? p.isSettled,
  notes: p.notes,
);
