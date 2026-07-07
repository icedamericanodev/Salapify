// 13th month pay math (Presidential Decree 851). Pure functions, no network.
//
// The rules, plainly:
//   Every rank-and-file employee who worked at least one month in the calendar
//   year must get 13th month pay, on or before 24 December.
//   The amount is the total BASIC salary earned in the year divided by 12. Only
//   basic counts, not overtime, holiday pay, night differential, or allowances,
//   unless the company integrates them. So for a full year it equals one
//   month's basic; for part of a year it is prorated by months worked.
//   Under the TRAIN law the 13th month pay and other benefits are tax exempt up
//   to 90,000 pesos combined for the year. Only the excess is taxable, at the
//   employee's marginal income tax rate.
//
// This is an estimate tool. It says so and shows the rates year. No dashes.

import { annualIncomeTax, takeHomePay, RATES_YEAR } from './phtax';

export const THIRTEENTH_TAX_FREE_CEILING = 90000;

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const round2 = (x) => Math.round(num(x) * 100) / 100;

// thirteenthMonth(monthlyBasic, opts) -> the 13th month pay and its tax
// treatment.
//   opts.monthsWorked   months worked this year, 1 to 12 (default 12)
//   opts.otherBenefits  other bonuses already counted toward the 90,000 tax
//                       free ceiling this year (default 0)
// Returns { amount, monthsWorked, otherBenefits, ceiling, taxFreePortion,
//   taxable, taxOnExcess, net, ratesYear }.
//
// The 90,000 ceiling is used up by other benefits first; whatever is left
// shelters the 13th month, and only the remainder is taxed. The tax on that
// remainder is marginal: it stacks on top of the year's regular taxable pay.
export function thirteenthMonth(monthlyBasic, opts = {}) {
  const basic = Math.max(0, num(monthlyBasic));
  // Default to a full year only when months is genuinely not given. A real 0
  // (or any value below 1) clamps to the legal minimum of one month, so it never
  // silently becomes 12.
  const hasMonths = opts && opts.monthsWorked != null && opts.monthsWorked !== '';
  const monthsWorked = hasMonths
    ? Math.min(Math.max(1, Math.round(num(opts.monthsWorked))), 12)
    : 12;
  const otherBenefits = Math.max(0, num(opts && opts.otherBenefits));

  // Total basic earned in the year, over 12. For a full year this is one
  // month's basic; prorated otherwise.
  const amount = round2((basic * monthsWorked) / 12);

  // The ceiling shelters other benefits first, then the 13th month.
  const remainingExemption = Math.max(0, THIRTEENTH_TAX_FREE_CEILING - otherBenefits);
  const taxFreePortion = round2(Math.min(amount, remainingExemption));
  const taxable = round2(Math.max(0, amount - remainingExemption));

  // Marginal tax on the taxable part: it sits on top of the year's regular
  // taxable compensation (basic minus mandatory contributions), scaled by the
  // months actually worked so a partial-year earner is not pushed into too high
  // a bracket.
  const regularAnnualTaxable = round2(takeHomePay(basic).monthlyTaxable * monthsWorked);
  const taxOnExcess = taxable > 0
    ? round2(annualIncomeTax(regularAnnualTaxable + taxable) - annualIncomeTax(regularAnnualTaxable))
    : 0;

  const net = round2(amount - taxOnExcess);

  return {
    amount,
    monthsWorked,
    otherBenefits,
    ceiling: THIRTEENTH_TAX_FREE_CEILING,
    taxFreePortion,
    taxable,
    taxOnExcess,
    net,
    ratesYear: RATES_YEAR,
  };
}
