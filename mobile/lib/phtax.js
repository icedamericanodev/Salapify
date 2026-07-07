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
