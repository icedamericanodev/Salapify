/// What a payment plan ACTUALLY costs, solved from its own payments.
///
/// ## Why this exists
///
/// Philippine instalment lenders quote an ADD-ON rate: interest charged on the
/// original amount borrowed, for the whole term, however much of it you have
/// already paid back. The Home Credit sample plan quotes "1.5% a month", and
/// the app used to annualise that by multiplying by twelve and printing "18.0%
/// a year", with a code comment claiming this was "the comparison the lender
/// does not put on the poster".
///
/// It is the poster. 18% a year is what 1.5% a month means in the lender's own
/// arithmetic, and reprinting it changes nothing. On the money you still owe,
/// that plan costs about 2.6% a month, because you are paying interest on
/// 24,500 in month eleven while owing roughly 2,000.
///
/// The gap is not small and it is not a rounding question: 24,500 over twelve
/// months costs 4,410 in interest on this plan, against 2,453.92 on a genuine
/// 1.5% a month loan with the same principal and term. Eighty percent more,
/// for the same headline figure.
///
/// ## What it solves
///
/// The rate `r` where the money actually handed over is worth, today, exactly
/// the money borrowed:
///
///     principal = payment1/(1+r) + payment2/(1+r)^2 + ... + paymentN/(1+r)^N
///
/// By bisection, because that equation has no closed form and bisection cannot
/// diverge: the present value falls monotonically as `r` rises, so the bracket
/// always closes on the answer.
///
/// It needs no new stored field and cannot be gamed. It reads the principal,
/// the payments and the term, whatever the lender decided to call the rate.
///
/// ## What it is NOT
///
/// It is not a regulatory disclosure and must never be presented as one.
/// Salapify does not know what a lender disclosed, what fees sit outside the
/// schedule, or what a regulator requires of them. This is arithmetic on the
/// figures the person entered, described in plain words, which is the same
/// line `loan.dart` already draws when it refuses to call 30% "the BSP safety
/// threshold".
library;

import 'money.dart';

/// The highest monthly rate the solver will consider: 1000% a month.
///
/// Far beyond anything real, and deliberately so. A bracket that is too tight
/// returns its own upper bound and looks like an answer, which is the one
/// failure mode of a bisection that a caller cannot see.
const double _maxMonthlyRate = 10.0;

/// Stop when the bracket is narrower than this. A hundred-thousandth of a
/// percentage point a month is far finer than anything the screen shows, and
/// it keeps the result stable when the final payment is adjusted by a centavo.
const double _tolerance = 1e-10;

/// The monthly rate a schedule really costs, or null when there is no answer.
///
/// Null rather than zero when the question is meaningless, because zero is a
/// measurement: "this plan costs you nothing" is a strong claim and must only
/// be made about a plan that genuinely costs nothing.
///
/// Returns null when:
///  - the principal is not positive, so there is nothing to have borrowed;
///  - there are no payments;
///  - the payments total LESS than the principal, which is not a loan, and the
///    app must not describe a negative cost of credit it cannot explain.
///
/// Returns exactly 0 when the payments total exactly the principal. A genuine
/// 0% plan is real and common here, and it must land on zero rather than on
/// whatever a solver drifts to.
double? trueMonthlyRate({
  required Money principal,
  required List<Money> payments,
}) {
  if (!principal.isPositive || payments.isEmpty) return null;

  final int totalCentavos = payments.fold<int>(
    0,
    (int s, Money m) => s + m.centavos,
  );
  if (totalCentavos < principal.centavos) return null;
  if (totalCentavos == principal.centavos) return 0;

  final double borrowed = principal.pesos;
  final List<double> cash = payments.map((Money m) => m.pesos).toList();

  double presentValueAt(double rate) {
    double pv = 0;
    double discount = 1;
    for (final double payment in cash) {
      discount *= 1 + rate;
      pv += payment / discount;
    }
    return pv;
  }

  double lo = 0;
  double hi = _maxMonthlyRate;

  // The payments exceed the principal, so the present value at zero is above
  // it and the root is inside the bracket. If it somehow is not, say so with a
  // null rather than returning a bound dressed up as an answer.
  if (presentValueAt(hi) > borrowed) return null;

  while (hi - lo > _tolerance) {
    final double mid = (lo + hi) / 2;
    if (presentValueAt(mid) > borrowed) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// The same rate over a year, by the lender's own method.
///
/// MULTIPLIED BY TWELVE, not compounded, and that choice is deliberate. The
/// quoted figure on the screen beside it is also a monthly rate multiplied by
/// twelve, so computing the two the same way is the only comparison that is
/// about the RATE rather than about the arithmetic. Compounding one and not
/// the other would inflate the gap and invite an argument about convention
/// instead of about cost.
///
/// Compounding would make the honest annual figure higher still, which belongs
/// in the explainer rather than on the card.
double? trueAnnualRate({
  required Money principal,
  required List<Money> payments,
}) {
  final double? monthly = trueMonthlyRate(
    principal: principal,
    payments: payments,
  );
  return monthly == null ? null : monthly * 12;
}
