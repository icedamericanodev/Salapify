// bnpl.js: the true cost of an installment or "0% interest" plan (GGives,
// BillEase, Home Credit, Shopee/Lazada installment, card installment). It backs
// out the real effective rate hidden inside a monthly quote and any upfront
// fee, so a "0%" plan that carries a processing fee is unmasked. Pure, offline,
// reuses the loan engine. This is an estimate from the numbers entered, not a
// loan offer. No dashes.

import { effectiveMonthlyRate, effectiveAnnualRate } from './loan';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

// fields: { cashPrice, downpayment, months, monthlyPayment, upfrontFee }
// Returns the totals, how much more than paying cash it costs, and the real
// effective monthly and annual rate on the credit actually received.
export function bnplCost(fields = {}) {
  const f = fields || {};
  const cash = Math.max(0, num(f.cashPrice));
  const down = Math.min(Math.max(0, num(f.downpayment)), cash);
  const fee = Math.max(0, num(f.upfrontFee));
  const months = Math.min(Math.max(1, Math.round(num(f.months)) || 1), 60);
  const monthly = Math.max(0, num(f.monthlyPayment));

  // What you finance is the price left after any downpayment. What you pay is
  // the downpayment now, the fee now, and the monthly installments over time.
  const financed = Math.max(0, cash - down);
  const totalPaid = down + fee + monthly * months;
  const extraCost = Math.max(0, totalPaid - cash); // more than paying cash today

  // The numbers do not add up when what you pay in total is less than the cash
  // price: the installments do not even cover the item. A true cost tool must
  // never reassure someone on impossible numbers, so this is its own state.
  const underpays = totalPaid < cash - 0.005;

  // The honest effective rate is measured on the credit actually received: the
  // financed amount minus any fee taken upfront. So a fee shows up as real cost
  // even when the quoted rate is "0%".
  const netCredit = Math.max(0, financed - fee);
  const monthlyRate = effectiveMonthlyRate(netCredit, monthly, months);
  const annualRate = effectiveAnnualRate(monthlyRate);
  // The rate is only meaningful when there is positive net credit to charge it
  // on. When a fee meets or exceeds what is financed, the rate math zeroes out,
  // so fall back to the plain peso extra-cost framing instead of "0%".
  const rateReliable = netCredit > 0.005 && monthlyRate > 0;

  // Genuinely free only when it fully covers the price, costs nothing over
  // cash, and carries no fee.
  const trulyFree = !underpays && extraCost <= 0.005 && fee <= 0.005;

  return {
    cash,
    down,
    fee,
    months,
    monthly,
    financed,
    netCredit,
    totalPaid,
    extraCost,
    monthlyRate,
    annualRate,
    rateReliable,
    underpays,
    trulyFree,
  };
}
