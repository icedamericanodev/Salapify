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

import '../../models/models.dart';
import 'debt.dart' show isoDate;
import 'js_round.dart';
import 'money.dart';

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

/// The payment schedule, in centavos, derived from the contract.
///
/// ## Where the leftover centavo goes, and why it is the LAST payment
///
/// A contract total rarely divides evenly by its term. 24,500 of principal
/// over 12 months is 2,041.6666..., so somebody has to carry the remainder.
///
/// Founder decision, on the lending officer's ruling: the repeated share is
/// rounded to the centavo and the FINAL instalment absorbs the whole
/// difference. Every Philippine lender's disclosure statement and payment
/// schedule works this way, Home Credit and SPayLater and the bank card
/// conversion plans alike: one level figure, with the last line adjusting.
///
/// `Money.split` was the other candidate and it is deliberately NOT used here.
/// It spreads the remainder over the EARLIEST shares, which is right for a
/// bill split and wrong for a loan: it would bill 2,409.17 for eight months
/// and 2,409.16 for four, and the month it diverges is a month the borrower is
/// holding their real statement next to this screen.
///
/// ## The payment is built from its PARTS
///
/// `instalment = principalShare + interestShare`, never
/// `round(totalPayable / n)`. Those two can differ by a centavo, and when they
/// do the row stops reconciling. Building it from the components makes
/// "principal plus interest equals the payment" true by construction on every
/// line, which is the one check a person actually runs.
class InstallmentSchedule {
  const InstallmentSchedule({
    required this.principalShares,
    required this.interestShares,
  });

  final List<Money> principalShares;
  final List<Money> interestShares;

  int get count => principalShares.length;

  Money principalAt(int i) => principalShares[i];
  Money interestAt(int i) => interestShares[i];
  Money instalmentAt(int i) => principalShares[i] + interestShares[i];

  /// What the whole schedule collects. Equal to the contract's totalPayable
  /// by construction, which is the invariant the old engine could not state.
  Money get totalPayable =>
      sumMoney(principalShares) + sumMoney(interestShares);
}

/// Splits a contract total into [n] shares, level except for the last.
List<Money> _levelShares(Money total, int n) {
  if (n <= 1) return <Money>[total];
  final Money share = Money(jsRound(total.centavos / n));
  final Money last = total - share * (n - 1);
  return <Money>[for (int i = 0; i < n - 1; i++) share, last];
}

/// The schedule for a plan, from its own contract terms.
InstallmentSchedule scheduleFor(InstallmentPlan p) {
  // A term of zero cannot produce a schedule, and Money.split throws rather
  // than quietly returning nothing. Guarded here so a bad import surfaces as
  // an empty schedule rather than an exception on a screen somebody opened.
  final int n = p.totalInstallments;
  if (n < 1) {
    return const InstallmentSchedule(
      principalShares: <Money>[],
      interestShares: <Money>[],
    );
  }
  return InstallmentSchedule(
    principalShares: _levelShares(p.principal, n),
    interestShares: _levelShares(p.totalInterest, n),
  );
}

/// What the NEXT scheduled payment actually collects.
///
/// Capped at what is still owed. Without the cap a plan that was prepaid keeps
/// demanding the full instalment, which is how a 5,000 prepayment came to be
/// collected TWICE: the counter never learned the plan got shorter, and the
/// forced zero at the end swallowed the difference.
Money nextPaymentFor(InstallmentPlan p) {
  if (p.isSettled || !p.runningBalance.isPositive) return Money.zero;
  final InstallmentSchedule s = scheduleFor(p);
  final int k = p.paidInstallments;
  final Money scheduled = k < s.count ? s.instalmentAt(k) : p.runningBalance;
  return minMoney(scheduled, p.runningBalance);
}

/// How much of an offered prepayment a plan can actually take.
///
/// ONE NAMED POLICY, because this used to be decided twice and the two
/// decisions drifted apart. `applyExtraPayment` capped at the running balance
/// while `FinancialState.payInstallmentExtra` capped at the principal, so
/// settling a plan early credited the plan 6,591.20 and moved the account by
/// 5,600.00: the plan's own history row and the account it came out of
/// disagreed by 991.20, and that much real cash had no record anywhere.
///
/// `nextPaymentFor` already had the right shape for the scheduled half. This
/// is its twin, and both halves of a prepayment must read it rather than
/// re-derive it.
Money appliedExtraPayment(InstallmentPlan p, Money amount) =>
    amount.isPositive ? minMoney(amount, p.runningBalance) : Money.zero;

/// Advances a plan by one scheduled instalment.
///
/// ## Two balances, and which one is derived
///
/// `principalRemaining` and `interestRemaining` are TRACKED; `runningBalance`
/// is their sum. That is the opposite way round from the first version, and
/// the reason is a lending reason rather than a software one. Unearned
/// interest on a fixed add-on contract has exactly two legitimate movers: an
/// instalment consuming one month's share, or an explicit rebate. Deriving it
/// from two other figures meant any arithmetic anywhere could move it, and one
/// did: a prepayment larger than the principal left clamped the principal at
/// zero and silently forgave 400 pesos of contractual interest.
///
/// ## There is no settlement sweep any more
///
/// The old code forced all three balances to zero on the final instalment,
/// commented as avoiding "a rounding crumb". It was not preventing a
/// discrepancy, it was deleting the evidence of one: the schedule never
/// footed, so a crumb was guaranteed, and the sweep hid it at the last
/// possible moment after eleven payments had already shown slightly wrong
/// figures. Both tests that claimed to guard it ran the one seeded plan that
/// divides evenly, and both passed with the sweep deleted.
///
/// With the schedule built to foot, the balances reach zero by subtraction and
/// there is nothing to sweep. A non-zero balance at the end of the counter is
/// now a fact the app can still see, which is the whole point.
List<InstallmentPlan> applyInstallmentPayment(
  List<InstallmentPlan> plans,
  String id, {

  /// Passed in rather than read from the clock, the same rule the debt engine
  /// already follows, so a test can pin it and a render is deterministic. It
  /// became load bearing when the register started stamping a date on every
  /// row: an engine that reaches for DateTime.now() writes a different file
  /// every run and no golden can hold it.
  required DateTime today,

  /// The ledger row this payment writes, when it writes one. Null is a real
  /// answer: paying with no account writes no entry, so the register row has
  /// nothing to point at and taking it back must not go hunting for one.
  String? txId,

  /// WHICH ACCOUNT the money came out of, stored on the row.
  ///
  /// `PlanPayment.accountId` existed, was declared in the codec, and was
  /// never written by anything, so it was always null. The take-back dialog
  /// reads it to name the account, found null every time, and told people
  /// "No account moves, because this payment was recorded against the plan
  /// alone" while `setTransactionStatus` put the money straight back.
  ///
  /// The debt engine has carried this since the register was built. The plan
  /// engine is the same feature one file over, and it did not.
  String? accountId,
}) {
  return plans.map((InstallmentPlan p) {
    if (p.id != id || p.isSettled) return p;

    final InstallmentSchedule s = scheduleFor(p);
    final int k = p.paidInstallments;

    // WHAT IS COLLECTED is the scheduled instalment or the balance, whichever
    // is smaller. That single cap is what makes a prepayment shorten the plan:
    // without it the engine kept demanding full instalments after the balance
    // had gone, which collected a 5,000 prepayment twice.
    final Money payment = nextPaymentFor(p);

    // HOW IT IS SPLIT is bookkeeping, not money: the total is already fixed
    // above. Interest for the period comes off first, then principal, and
    // anything still unallocated can only be interest, because that is the one
    // side a prepayment never touched. Without that last step a prepaid plan
    // runs out of principal before it runs out of payment and stalls, paying
    // ever smaller amounts for the full original term.
    Money interestPart = minMoney(
      minMoney(k < s.count ? s.interestAt(k) : Money.zero, p.interestRemaining),
      payment,
    );
    final Money principalPart = minMoney(
      payment - interestPart,
      p.principalRemaining,
    );
    final Money unallocated = payment - interestPart - principalPart;
    interestPart += minMoney(unallocated, p.interestRemaining - interestPart);

    final Money nextPrincipal = p.principalRemaining - principalPart;
    final Money nextInterest = p.interestRemaining - interestPart;
    final Money nextBalance = nextPrincipal + nextInterest;

    final int nextPaid = p.paidInstallments + 1;

    return _copy(
      p,
      paidInstallments: nextPaid,
      runningBalance: nextBalance,
      principalRemaining: nextPrincipal,
      interestRemaining: nextInterest,
      // SETTLEMENT IS BALANCE DRIVEN, not counter driven. A prepayment moves
      // the balance and leaves the counter behind, and the old counter-only
      // rule is exactly what let a settled plan keep accepting payments.
      isSettled: !nextBalance.isPositive || nextPaid >= p.totalInstallments,
      // RECORDED, because none of this survives in the plan.
      //
      // `paidInstallments` is a counter rather than a set of events, and the
      // collected amount is capped at the running balance, so a stub left by
      // a prepayment cannot be told apart afterwards from a full instalment
      // that happened to land on zero. Re-deriving one from the schedule
      // credited 1,647.80 against a ledger row holding 591.20, and invented
      // 1,400 of principal that was never owed.
      //
      // The three clamps and the unallocated sweep above are the other half:
      // which branch fired is not recoverable from the result, so the split
      // is written down rather than reasoned about later.
      payments: <PlanPayment>[
        ...p.payments,
        PlanPayment(
          id: 'pay_${p.id}_$nextPaid',
          date: isoDate(today),
          amount: payment,
          toPrincipal: principalPart,
          toInterest: interestPart,
          settledBefore: p.isSettled,
          accountId: accountId,
          txId: txId,
          installmentNumber: nextPaid,
        ),
      ],
    );
  }).toList();
}

/// Takes the MOST RECENT payment back off a plan, restoring what it moved.
///
/// Returns the plans unchanged when there is nothing to take back. Every plan
/// written before the register existed reports exactly that, which is the
/// truth: nothing is known about how it reached its figures, and guessing
/// would be the defect this whole register was built to stop.
///
/// ## Why only the most recent one, and why both kinds share one list
///
/// A prepayment SHORTENS a plan, so every scheduled instalment after it
/// collected a different amount. Taking the prepayment back while those stand
/// would leave their recorded amounts explainable by no schedule at all, and
/// the plan would then disagree with its own register. Scheduled payments and
/// prepayments therefore interleave in one ordered list, and only its last
/// entry can be removed; anything else is refused where the person can see it,
/// which also tells them which one they have to take back first.
///
/// ## Why nothing here is recomputed
///
/// Every figure comes off the stored row. The split cannot be re-derived: the
/// forward pass clamps three times and then sweeps what is unallocated, and
/// which branch fired is not visible in the result. Re-deriving a prepayment
/// from "principal first" overstates principal by the whole interest portion
/// it actually paid, measured at 400 on the seeded plan, with every total
/// still footing.
List<InstallmentPlan> reverseLastPlanPayment(
  List<InstallmentPlan> plans,
  String planId,
) {
  return plans.map((InstallmentPlan p) {
    if (p.id != planId || p.payments.isEmpty) return p;

    final PlanPayment row = p.payments.last;

    final Money nextPrincipal = p.principalRemaining + row.toPrincipal;
    final Money nextInterest = p.interestRemaining + row.toInterest;

    return _copy(
      p,
      // A scheduled instalment moved the counter; a prepayment did not. The
      // null instalment number is what tells them apart, which is why it is
      // stored rather than inferred from the amount.
      paidInstallments: row.installmentNumber != null
          ? p.paidInstallments - 1
          : p.paidInstallments,
      runningBalance: nextPrincipal + nextInterest,
      principalRemaining: nextPrincipal,
      interestRemaining: nextInterest,
      // READ OFF THE ROW, never recomputed from the restored balance.
      // applyExtraPayment has no settled guard at entry, so a prepayment can
      // land on an already clear plan; deciding settlement from the balance
      // afterwards would reopen a plan that was settled before this payment
      // ever happened.
      isSettled: row.settledBefore,
      // A prepayment also wrote a row on the plan's own history, and leaving
      // it behind would show a prepayment that no longer exists.
      extraPayments: row.installmentNumber == null
          ? p.extraPayments
                .where((ExtraPayment e) => e.id != row.id)
                .toList(growable: false)
          : p.extraPayments,
      payments: p.payments.sublist(0, p.payments.length - 1),
    );
  }).toList();
}

/// Records money paid on TOP of the schedule.
///
/// It comes off PRINCIPAL ONLY. On a flat add-on plan, which is what Philippine
/// BNPL and gadget loans almost always are, the interest was fixed when the
/// contract was signed and prepaying does not reduce it unless the provider
/// rebates unearned interest. Providers vary, so Salapify takes the reading
/// that cannot leave somebody short: no automatic rebate. A real rebate is a
/// figure the provider quotes, and belongs on screen as something the person
/// enters, never as something the engine assumes.
///
/// It is capped at the BALANCE, not at the principal, and the two are
/// different in a way that matters. The balance is everything still owed;
/// handing over all of it settles the plan, which is what somebody paying off
/// a loan expects and what the engine must honour. Capping at the principal
/// instead would mean a person could pay the full remaining balance and still
/// be told they owed the interest.
///
/// So money beyond the principal is not refused and not forgiven: it PAYS the
/// unearned interest, because it was actually handed over. What must never
/// happen, and used to, is the interest falling by more than was paid. The
/// invariant is that the balance drops by exactly the amount applied.
///
/// The APPLIED amount is what goes in the history. Recording more than was
/// applied is how a plan comes to claim a prepayment it never credited.
List<InstallmentPlan> applyExtraPayment(
  List<InstallmentPlan> plans,
  String id,
  Money amount, {
  required DateTime today,
  String? note,
  String? extraId,

  /// Same reason as [applyInstallmentPayment]'s, one function down.
  String? accountId,

  /// As above: the ledger row, when there is one.
  String? txId,
}) {
  if (!amount.isPositive) return plans;

  return plans.map((InstallmentPlan p) {
    if (p.id != id) return p;

    final Money applied = appliedExtraPayment(p, amount);
    if (!applied.isPositive) return p;

    // Principal first, which is the point of prepaying: it is the only part
    // that shortens the plan. Anything beyond the principal is paying the
    // interest early rather than escaping it.
    final Money offPrincipal = minMoney(applied, p.principalRemaining);
    final Money offInterest = applied - offPrincipal;

    final Money nextPrincipal = p.principalRemaining - offPrincipal;
    final Money nextInterest = p.interestRemaining - offInterest;
    final Money nextBalance = nextPrincipal + nextInterest;

    final String rowId = extraId ?? 'ext_${today.microsecondsSinceEpoch}';

    return _copy(
      p,
      runningBalance: nextBalance,
      principalRemaining: nextPrincipal,
      interestRemaining: nextInterest,
      isSettled: !nextBalance.isPositive,
      extraPayments: <ExtraPayment>[
        ...p.extraPayments,
        ExtraPayment(
          id: rowId,
          date: isoDate(today),
          amount: applied,
          note: note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Principal prepayment',
        ),
      ],
      // THE SPLIT IS RECORDED, not left to be worked out again.
      //
      // offPrincipal and offInterest were computed above and then thrown
      // away, so the only way back was to re-derive them from the policy
      // ("principal first"), which is wrong the moment a prepayment crosses
      // the principal: 6,000 against 5,600 principal restores 6,000 of
      // principal where the truth is 5,600 and 400. The balance foots either
      // way, which is what made it silent.
      payments: <PlanPayment>[
        ...p.payments,
        PlanPayment(
          id: rowId,
          date: isoDate(today),
          amount: applied,
          toPrincipal: offPrincipal,
          toInterest: offInterest,
          settledBefore: p.isSettled,
          accountId: accountId,
          txId: txId,
          note: note?.trim().isNotEmpty == true ? note!.trim() : null,
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
  required Money amount,
}) {
  if (accountId == null || !amount.isPositive) return null;
  return Transaction(
    // THE AMOUNT ACTUALLY COLLECTED, not the quoted instalment. They differ on
    // the adjusting final payment and on any stub left after a prepayment, and
    // writing the quoted figure made the account move by one number while the
    // plan recorded another.
    id: id,
    type: TransactionType.expense,
    amount: amount,
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
  required Money amount,
  required String? accountId,
  required DateTime today,
  required String id,
  String? note,
}) {
  if (accountId == null || !amount.isPositive) return null;
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
/// Capped at what is still owed on each plan. A plan with less than one
/// instalment left does not take a whole instalment out of next month, and
/// reserving one held back money the person did not owe.
Money monthlyInstallmentLoad(List<InstallmentPlan> plans) => sumMoney(
  plans
      .where((InstallmentPlan p) => !p.isSettled)
      .map(
        (InstallmentPlan p) => minMoney(p.installmentAmount, p.runningBalance),
      ),
);

/// Everything still owed across every open plan.
Money totalStillOwed(List<InstallmentPlan> plans) => sumMoney(
  plans
      .where((InstallmentPlan p) => !p.isSettled)
      .map((InstallmentPlan p) => p.runningBalance),
);

/// The interest an open plan has NOT yet been charged, across all of them.
///
/// This is the figure worth showing beside an extra-payment button, because it
/// is the part a prepayment can still take away. Interest already charged is
/// gone whatever anybody does now.
Money interestStillToCome(List<InstallmentPlan> plans) => sumMoney(
  plans
      .where((InstallmentPlan p) => !p.isSettled)
      .map((InstallmentPlan p) => p.interestRemaining),
);

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
  Money? runningBalance,
  Money? principalRemaining,
  Money? interestRemaining,
  bool? isSettled,
  List<ExtraPayment>? extraPayments,
  List<PlanPayment>? payments,
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
  payments: payments ?? p.payments,
  isSettled: isSettled ?? p.isSettled,
  notes: p.notes,
  // CARRIED THROUGH, unlike isSample one line down, and the difference
  // between them is the point.
  //
  // Dropping this would mean any engine write silently un-archived the plan,
  // which is the quiet kind of failure the debt side already paid for once.
  archivedAt: p.archivedAt,
  // NOT carried, deliberately, matching Debt.copyWith. A real payment against
  // a demo plan makes it the person's own, so the sample sweep cannot delete
  // a record that the user's own ledger rows point at. It was undocumented
  // here while the debt side explained itself, which is why a reviewer had to
  // work out whether it was a decision or an oversight. It is a decision.
);
