// Loan and amortization math. Pure functions, no network. The whole point of
// this file is to show a Filipino borrower the TRUE cost of a loan, and to stop
// a lender's low "add-on" rate from hiding an effective rate roughly double it.
//
// Two rate conventions matter here:
//   Diminishing balance: interest each month is charged on the REMAINING
//     balance. This is how banks and formal lenders amortize. The standard
//     amortization formula applies.
//   Add-on: interest is charged on the ORIGINAL principal for the whole term,
//     then spread evenly. Common in in-house and informal financing. It looks
//     cheap but the effective rate is far higher, because you keep paying
//     interest on money you have already paid back.
//
// This is an estimate tool. Real contracts add fees, penalties, and
// pre-termination charges the UI must disclose. No em or en dashes in copy.

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const round2 = (x) => Math.round(num(x) * 100) / 100;

// Level monthly payment on a diminishing-balance loan.
//   A = P * r / (1 - (1 + r)^-n), and A = P / n when the rate is zero.
export function monthlyPayment(principal, monthlyRate, months) {
  const P = Math.max(0, num(principal));
  const r = Math.max(0, num(monthlyRate));
  const n = Math.max(1, Math.round(num(months)));
  if (P === 0) return 0;
  if (r === 0) return round2(P / n);
  const factor = r / (1 - Math.pow(1 + r, -n));
  return round2(P * factor);
}

// Full diminishing-balance schedule. Each row splits the payment into interest
// on the current balance and principal, and the balance reconciles to zero. The
// last payment absorbs any rounding so the loan closes exactly.
export function amortize(principal, monthlyRate, months) {
  const P = Math.max(0, num(principal));
  const r = Math.max(0, num(monthlyRate));
  const n = Math.max(1, Math.round(num(months)));
  const payment = monthlyPayment(P, r, n);
  const schedule = [];
  let balance = P;
  let totalInterest = 0;
  for (let i = 1; i <= n; i++) {
    const interest = round2(balance * r);
    let principalPaid = round2(payment - interest);
    // The final row clears whatever is left, absorbing rounding drift.
    if (i === n || principalPaid > balance) principalPaid = round2(balance);
    const rowPayment = round2(principalPaid + interest);
    balance = round2(balance - principalPaid);
    totalInterest = round2(totalInterest + interest);
    schedule.push({ period: i, payment: rowPayment, interest, principal: principalPaid, balance: Math.max(0, balance) });
  }
  return {
    payment,
    months: n,
    totalInterest: round2(totalInterest),
    totalPaid: round2(P + totalInterest),
    schedule,
  };
}

// Add-on loan: interest = principal * monthly add-on rate * months, charged on
// the original principal for the whole term. Payment is the level split of
// principal plus that interest.
export function addOnLoan(principal, monthlyAddOnRate, months) {
  const P = Math.max(0, num(principal));
  const rate = Math.max(0, num(monthlyAddOnRate));
  const n = Math.max(1, Math.round(num(months)));
  const totalInterest = round2(P * rate * n);
  const totalPaid = round2(P + totalInterest);
  const payment = round2(totalPaid / n);
  return { payment, months: n, totalInterest, totalPaid };
}

// The effective monthly rate a loan really costs, backed out from its principal,
// its level payment, and its term. For an add-on loan this reveals the true
// rate hiding behind the quoted one. Solved by bisection since the present-value
// function is monotonic in the rate.
export function effectiveMonthlyRate(principal, payment, months) {
  const P = Math.max(0, num(principal));
  const A = Math.max(0, num(payment));
  const n = Math.max(1, Math.round(num(months)));
  if (P <= 0 || A <= 0) return 0;
  if (A * n <= P) return 0; // paid no more than borrowed, so no interest
  // Present value of n level payments of A at monthly rate r.
  const pv = (r) => (r === 0 ? A * n : A * (1 - Math.pow(1 + r, -n)) / r);
  let lo = 0;
  let hi = 1; // 100% a month is a generous upper bound for any real loan
  for (let i = 0; i < 200; i++) {
    const mid = (lo + hi) / 2;
    // pv decreases as r rises; if pv is still above P, the rate must be higher.
    if (pv(mid) > P) lo = mid;
    else hi = mid;
  }
  return (lo + hi) / 2;
}

// Effective annual rate from a monthly rate, with compounding.
export function effectiveAnnualRate(monthlyRate) {
  const r = Math.max(0, num(monthlyRate));
  return Math.pow(1 + r, 12) - 1;
}

// loanSummary(principal, ratePercent, months, opts) -> one object the screen can
// render directly. opts.method 'diminishing' (default) or 'addon';
// opts.rateBasis 'monthly' (default) or 'annual' for how the rate is quoted.
// Returns the payment, totals, the schedule, and BOTH the nominal and the true
// effective annual rate so the real cost is never hidden.
export function loanSummary(principal, ratePercent, months, opts = {}) {
  const P = Math.max(0, num(principal));
  const n = Math.max(1, Math.round(num(months)));
  const method = opts && opts.method === 'addon' ? 'addon' : 'diminishing';
  const rateBasis = opts && opts.rateBasis === 'annual' ? 'annual' : 'monthly';
  // The quoted rate as a monthly decimal.
  const quotedMonthly = rateBasis === 'annual' ? num(ratePercent) / 100 / 12 : num(ratePercent) / 100;

  let payment, totalInterest, totalPaid, schedule;
  if (method === 'addon') {
    const a = addOnLoan(P, quotedMonthly, n);
    payment = a.payment;
    totalInterest = a.totalInterest;
    totalPaid = a.totalPaid;
    // Rebuild a diminishing schedule at the loan's TRUE rate so the row split is
    // honest, then let the last row absorb rounding to the same total.
    const eff = effectiveMonthlyRate(P, payment, n);
    schedule = amortize(P, eff, n).schedule;
  } else {
    const am = amortize(P, quotedMonthly, n);
    payment = am.payment;
    totalInterest = am.totalInterest;
    totalPaid = am.totalPaid;
    schedule = am.schedule;
  }

  const effMonthly = effectiveMonthlyRate(P, payment, n);
  const effAnnual = effectiveAnnualRate(effMonthly);

  return {
    principal: P,
    months: n,
    method,
    payment,
    totalInterest,
    totalPaid,
    quotedMonthlyRate: round4(quotedMonthly),
    effectiveMonthlyRate: round4(effMonthly),
    effectiveAnnualRate: round4(effAnnual),
    schedule,
  };
}

// Interest saved by paying the loan off after `paidMonths` payments, on a
// diminishing-balance loan (the only kind where early payoff cuts interest).
export function payoffSaving(principal, monthlyRate, months, paidMonths) {
  const full = amortize(principal, monthlyRate, months);
  const k = Math.max(0, Math.min(Math.round(num(paidMonths)), full.months));
  if (k >= full.months) return { interestSaved: 0, balanceCleared: 0 };
  const interestPaidSoFar = full.schedule.slice(0, k).reduce((s, row) => s + row.interest, 0);
  const balanceCleared = k > 0 ? full.schedule[k - 1].balance : num(principal);
  const interestSaved = round2(full.totalInterest - interestPaidSoFar);
  return { interestSaved, balanceCleared: round2(balanceCleared) };
}

function round4(x) {
  return Math.round(num(x) * 10000) / 10000;
}
