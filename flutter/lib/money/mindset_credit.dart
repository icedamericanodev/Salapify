// The in-flow Credit / BNPL installment preview for Money Mindset. Flutter-only
// (no RN twin), so nothing here is golden-locked, but it is money the person
// reads, so it is pinned by test vectors and was checked by a PH bank officer
// before shipping.
//
// The founder chose (2026-08-15) a FLAT ADD-ON fee model: the fee is a ONE-TIME
// percentage of the price, spread evenly over the term. It is NOT a monthly
// interest rate. A flat 3% is very different from 3% per month, so the UI must
// label it as a one-time fee, never as interest per month. This is an estimate
// from the numbers entered, never a loan offer.

/// The result of spreading a one-time add-on fee over an installment term.
class BnplFlatPlan {
  final double price;
  final int months;
  final double feePercent;

  /// The one-time fee: price * feePercent / 100. Never negative.
  final double extraCost;

  /// price + extraCost.
  final double totalPaid;

  /// totalPaid / months, the even installment.
  final double monthly;

  const BnplFlatPlan({
    required this.price,
    required this.months,
    required this.feePercent,
    required this.extraCost,
    required this.totalPaid,
    required this.monthly,
  });
}

/// Spread a flat add-on fee over [months]. A zero or negative price yields all
/// zeros; the term is floored at 1 month so a stray 0 never divides by zero; a
/// negative fee is treated as no fee (junk in, safe out), the same defensive
/// contract the rest of the money layer keeps.
BnplFlatPlan bnplFlatPlan({
  required double price,
  required int months,
  required double feePercent,
}) {
  final p = price > 0 ? price : 0.0;
  final m = months >= 1 ? months : 1;
  final f = feePercent > 0 ? feePercent : 0.0;
  final extra = p * f / 100;
  final total = p + extra;
  return BnplFlatPlan(
    price: p,
    months: m,
    feePercent: f,
    extraCost: extra,
    totalPaid: total,
    monthly: total / m,
  );
}

/// The three Decision-Score engine inputs for a credit / BNPL plan, kept here so
/// the flow's wiring is testable and pinned rather than typed inline. Per the
/// engine's own contract (mindset_decision.dart) and a PH bank officer's review
/// (2026-08-15): the immediate cash out is the FIRST installment (not the full
/// price, the old bug), the ongoing monthly load is that same installment, and
/// the credit markup is the fee as a share of the CASH price. A true 0% plan has
/// a zero markup, so the engine's markup penalty is skipped.
({double cashNow, double monthlyLoad, double creditMarkup}) creditScoreInputs(
  BnplFlatPlan plan,
) {
  final markup = plan.price > 0 ? plan.extraCost / plan.price : 0.0;
  return (
    cashNow: plan.monthly,
    monthlyLoad: plan.monthly,
    creditMarkup: markup,
  );
}
