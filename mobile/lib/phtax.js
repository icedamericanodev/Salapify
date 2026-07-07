// Philippine payroll and tax math: take-home pay for an employee, and the
// pieces the other tax tools reuse. Pure functions, no network. Every rate is
// a dated, sourced constant so it is easy to audit and update each year.
//
// This is an ESTIMATE tool, not tax filing. It uses published rates and the
// standard graduated table; a real payslip can differ (de minimis benefits,
// semi-monthly withholding rounding, employer-specific rules). The UI must say
// so and show the rates year. No em or en dashes in any copy this feeds.
//
// Sources (2025 rates, unchanged for 2026 as of this writing):
//   Income tax: TRAIN law graduated table effective 2023 onward (BIR).
//   SSS: 15% of MSC total, employee 5%, MSC 5,000 to 35,000 (RA 11199, 2025).
//   PhilHealth: 5% premium, employee half (2.5%), floor 10,000 ceiling 100,000.
//   Pag-IBIG: employee 2% (1% at 1,500 and below), max fund salary 10,000.

export const RATES_YEAR = 2025;

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const round2 = (x) => Math.round(num(x) * 100) / 100;

// Annual graduated income tax (TRAIN, 2023 onward). Each bracket: taxable up
// to `upTo` pays `base` plus `rate` on the amount over `over`.
const BRACKETS = [
  { upTo: 250000, base: 0, rate: 0, over: 0 },
  { upTo: 400000, base: 0, rate: 0.15, over: 250000 },
  { upTo: 800000, base: 22500, rate: 0.2, over: 400000 },
  { upTo: 2000000, base: 102500, rate: 0.25, over: 800000 },
  { upTo: 8000000, base: 402500, rate: 0.3, over: 2000000 },
  { upTo: Infinity, base: 2202500, rate: 0.35, over: 8000000 },
];

// annualIncomeTax(annualTaxable) -> the graduated income tax on that amount.
export function annualIncomeTax(annualTaxable) {
  const t = Math.max(0, num(annualTaxable));
  for (const b of BRACKETS) {
    if (t <= b.upTo) return round2(b.base + (t - b.over) * b.rate);
  }
  return 0;
}

// Employee monthly SSS contribution: 5% of the Monthly Salary Credit, which is
// the pay rounded to the nearest 500 and held between 5,000 and 35,000.
export function sssEmployee(monthly) {
  const m = num(monthly);
  if (m <= 0) return 0;
  const msc = Math.min(Math.max(Math.round(m / 500) * 500, 5000), 35000);
  return round2(msc * 0.05);
}

// Employee monthly PhilHealth: half of the 5% premium, so 2.5% of pay held
// between the 10,000 floor and 100,000 ceiling.
export function philhealthEmployee(monthly) {
  const m = num(monthly);
  if (m <= 0) return 0;
  const base = Math.min(Math.max(m, 10000), 100000);
  return round2((base * 0.05) / 2);
}

// Employee monthly Pag-IBIG: 2% of pay (1% at 1,500 and below), on a fund
// salary capped at 10,000, so at most 200.
export function pagibigEmployee(monthly) {
  const m = num(monthly);
  if (m <= 0) return 0;
  const fund = Math.min(m, 10000);
  const rate = m <= 1500 ? 0.01 : 0.02;
  return round2(fund * rate);
}

// takeHomePay(basic, opts) -> full monthly payslip estimate for an employee.
//   opts.taxableAllowance    added to taxable pay AND to gross (taxed)
//   opts.nonTaxableAllowance added to gross only (never taxed, e.g. de minimis)
// Returns { basic, taxableAllowance, nonTaxableAllowance, gross, sss,
//   philhealth, pagibig, contributions, monthlyTaxable, monthlyTax, annualTax,
//   net, ratesYear }.
//
// Model: the mandatory contributions are computed on the BASIC salary, the
// common payroll convention. Contributions come out before tax (they are
// exempt). Taxable allowances are taxed with the basic pay; non-taxable
// allowances pass straight to take-home. The graduated annual tax is spread
// across 12 months for the monthly withholding estimate.
export function takeHomePay(basic, opts = {}) {
  const basicPay = Math.max(0, num(basic));
  const taxableAllowance = Math.max(0, num(opts && opts.taxableAllowance));
  const nonTaxableAllowance = Math.max(0, num(opts && opts.nonTaxableAllowance));

  const sss = sssEmployee(basicPay);
  const philhealth = philhealthEmployee(basicPay);
  const pagibig = pagibigEmployee(basicPay);
  const contributions = round2(sss + philhealth + pagibig);

  const monthlyTaxable = Math.max(0, round2(basicPay + taxableAllowance - contributions));
  const annualTax = annualIncomeTax(monthlyTaxable * 12);
  const monthlyTax = round2(annualTax / 12);

  const gross = round2(basicPay + taxableAllowance + nonTaxableAllowance);
  const net = round2(gross - contributions - monthlyTax);

  return {
    basic: basicPay,
    taxableAllowance,
    nonTaxableAllowance,
    gross,
    sss,
    philhealth,
    pagibig,
    contributions,
    monthlyTaxable,
    monthlyTax,
    annualTax: round2(annualTax),
    net,
    ratesYear: RATES_YEAR,
  };
}

// ---------------------------------------------------------------------------
// Self-employed, freelancer, and professional income tax.
//
// A small self-employed taxpayer (annual gross of 3,000,000 or less, not
// VAT-registered) chooses ONE of two ways to be taxed on business income:
//
//   8% option: a flat 8% on gross receipts. For a purely self-employed
//     person the first 250,000 is exempt; this ONE tax replaces both the
//     graduated income tax AND the 3% percentage tax.
//
//   Graduated option: the same graduated income tax as an employee, but on
//     net income (gross minus deductions), PLUS a separate 3% percentage tax
//     on the whole gross. Deductions are either the 40% Optional Standard
//     Deduction (OSD) or the taxpayer's real itemized expenses.
//
// Which is cheaper depends on the margin: high real expenses favor graduated,
// thin expenses favor the flat 8%. This tool computes both and points to the
// lower one. It is an estimate; the 8% must be elected on time with the BIR.
// ---------------------------------------------------------------------------

// 2025: the percentage tax is back to 3% of gross for non-VAT taxpayers (the
// 1% CREATE relief ended 30 June 2023). Above the 3,000,000 threshold a
// taxpayer is VAT-registered and these self-employed rules no longer apply.
export const PERCENTAGE_TAX_RATE = 0.03;
export const VAT_THRESHOLD = 3000000;
export const SELF_EMPLOYED_EXEMPT = 250000;

// 3% percentage tax on annual gross (non-VAT self-employed).
export function percentageTax(annualGross) {
  const g = Math.max(0, num(annualGross));
  return round2(g * PERCENTAGE_TAX_RATE);
}

// The flat 8% option. For a purely self-employed taxpayer the first 250,000 of
// gross is exempt; for a mixed-income earner (also drawing a salary) the
// 250,000 is already used by the compensation, so the whole gross is taxed.
// This single figure replaces both the graduated income tax and percentage tax.
export function eightPercentTax(annualGross, opts = {}) {
  const g = Math.max(0, num(annualGross));
  const mixedIncome = !!(opts && opts.mixedIncome);
  const taxBase = mixedIncome ? g : Math.max(0, g - SELF_EMPLOYED_EXEMPT);
  return round2(taxBase * 0.08);
}

// The graduated option for a self-employed taxpayer. Deduction is the 40% OSD
// by default, or itemized expenses when opts.useOSD is false.
//   opts.salaryTaxable  yearly taxable salary of a mixed-income earner. The
//     business net stacks ON TOP of it and is taxed at the marginal rungs, so
//     the income tax here is the extra tax the business net adds. Zero (the
//     default) means purely self-employed and the net is taxed from the bottom.
//   opts.vatRegistered  true above the VAT threshold, where the 3% percentage
//     tax does not apply (12% VAT does instead, which this tool does not model).
// Returns the pieces plus the total (graduated income tax on net + percentage
// tax where it applies).
export function graduatedSelfEmployedTax(annualGross, opts = {}) {
  const g = Math.max(0, num(annualGross));
  const useOSD = !(opts && opts.useOSD === false);
  const expenses = Math.max(0, num(opts && opts.expenses));
  const salaryTaxable = Math.max(0, num(opts && opts.salaryTaxable));
  const vatRegistered = !!(opts && opts.vatRegistered);
  const deduction = useOSD ? round2(g * 0.4) : Math.min(expenses, g);
  // Note: a self-employed person's own SSS, PhilHealth, and Pag-IBIG are also
  // deductible, which would lower net a little. We leave them out here, which
  // makes the graduated estimate marginally conservative (tax a touch high),
  // the safe direction for a set-aside tool.
  const net = Math.max(0, round2(g - deduction));
  // Marginal: the tax the business net adds on top of the salary. For a purely
  // self-employed person salaryTaxable is 0, so this is just the tax on net.
  const incomeTax = round2(annualIncomeTax(salaryTaxable + net) - annualIncomeTax(salaryTaxable));
  const pct = vatRegistered ? 0 : percentageTax(g);
  return {
    deduction: round2(deduction),
    net,
    incomeTax: Math.max(0, incomeTax),
    percentageTax: pct,
    total: round2(Math.max(0, incomeTax) + pct),
  };
}

// selfEmployedTax(annualGross, opts) -> both options compared, with a pick.
//   opts.mixedIncome  true if the person also earns a salary (no 250k exempt)
//   opts.useOSD       true (default) uses the 40% OSD; false uses opts.expenses
//   opts.expenses     itemized annual expenses when useOSD is false
//   opts.salaryTaxable  yearly taxable salary of a mixed-income earner, needed
//     to compute the graduated branch correctly (business net stacks on it).
// Returns { gross, mixedIncome, eligible8, canCompareGraduated, eightPercent,
//   graduated, recommended ('eight'|'graduated'), savings, effectiveRate,
//   ratesYear }. canCompareGraduated is false for a mixed earner who has not
//   given a salary, since the graduated tax cannot be trusted without it.
export function selfEmployedTax(annualGross, opts = {}) {
  const gross = Math.max(0, num(annualGross));
  const mixedIncome = !!(opts && opts.mixedIncome);
  const salaryTaxable = Math.max(0, num(opts && opts.salaryTaxable));
  // The 8% option is only open to non-VAT taxpayers at or under the threshold.
  const eligible8 = gross <= VAT_THRESHOLD;

  // The 8% figure is always self-contained and correct. The graduated figure
  // for a mixed earner needs their salary; without it we do not compare.
  const canCompareGraduated = !mixedIncome || salaryTaxable > 0;

  const eightTotal = eightPercentTax(gross, { mixedIncome });
  const graduated = graduatedSelfEmployedTax(gross, {
    ...opts,
    salaryTaxable,
    vatRegistered: !eligible8,
  });

  const eightPercent = {
    exempt: mixedIncome ? 0 : SELF_EMPLOYED_EXEMPT,
    total: eightTotal,
  };

  // Recommend the lower tax, but only when we can trust both numbers and the
  // taxpayer actually qualifies for the 8%. The threshold check comes first:
  // over the VAT threshold the 8% is not even available, so a mixed earner who
  // left the salary blank must still be pointed at the graduated regime, not 8%.
  let recommended, savings;
  if (!eligible8) {
    recommended = 'graduated';
    savings = 0;
  } else if (!canCompareGraduated) {
    recommended = 'eight'; // the screen shows only 8% and explains why
    savings = 0;
  } else {
    recommended = eightTotal <= graduated.total ? 'eight' : 'graduated';
    savings = round2(Math.abs(graduated.total - eightTotal));
  }

  const chosenTotal = recommended === 'eight' ? eightTotal : graduated.total;
  const effectiveRate = gross > 0 ? round2((chosenTotal / gross) * 100) : 0;

  return {
    gross,
    mixedIncome,
    eligible8,
    canCompareGraduated,
    eightPercent,
    graduated,
    recommended,
    savings,
    effectiveRate,
    ratesYear: RATES_YEAR,
  };
}
