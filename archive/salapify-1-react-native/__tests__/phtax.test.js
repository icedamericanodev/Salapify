// Regression suite for lib/phtax.js: Philippine payroll and tax math. A bug
// here understates or overstates real pesos owed, so every bracket edge,
// contribution floor and ceiling, and the known-correct PH values are locked
// in. RATES_YEAR is 2026 (2025 rates confirmed unchanged).

import {
  RATES_YEAR,
  annualIncomeTax,
  marginalRate,
  sssMSC,
  sssEmployee,
  sssEmployer,
  philhealthEmployee,
  pagibigEmployee,
  pagibigEmployer,
  contributionBreakdown,
  takeHomePay,
  percentageTax,
  eightPercentTax,
  graduatedSelfEmployedTax,
  selfEmployedTax,
  annualizeCompensation,
  PERCENTAGE_TAX_RATE,
  VAT_THRESHOLD,
  SELF_EMPLOYED_EXEMPT,
  BONUS_TAX_FREE_CEILING,
} from '../lib/phtax';
import { THIRTEENTH_TAX_FREE_CEILING } from '../lib/thirteenth';

test('the rates year is 2026', () => {
  expect(RATES_YEAR).toBe(2026);
});

describe('graduated income tax lands exactly on every TRAIN bracket edge', () => {
  test.each([
    ['the 250k exemption ceiling pays nothing', 250000, 0],
    ['the top of the 15% band', 400000, 22500],
    ['the top of the 20% band', 800000, 102500],
    ['the top of the 25% band', 2000000, 402500],
    ['the top of the 30% band', 8000000, 2202500],
    ['a peso into the first taxable band', 250001, 0.15],
    ['inside the 20% band at 500k', 500000, 42500],
    ['into the top 35% band at 10M', 10000000, 2902500],
  ])('%s', (_label, taxable, expected) => {
    expect(annualIncomeTax(taxable)).toBe(expected);
  });

  test('zero taxable income owes zero tax', () => {
    expect(annualIncomeTax(0)).toBe(0);
  });

  test('the marginal rate is the bracket the next peso falls in', () => {
    expect(marginalRate(0)).toBe(0);
    expect(marginalRate(250000)).toBe(0); // still within the exemption
    expect(marginalRate(250001)).toBe(0.15);
    expect(marginalRate(500000)).toBe(0.2);
    expect(marginalRate(1000000)).toBe(0.25);
    expect(marginalRate(3000000)).toBe(0.3);
    expect(marginalRate(9000000)).toBe(0.35);
  });

  test('a negative taxable income owes zero, never a negative tax', () => {
    expect(annualIncomeTax(-100000)).toBe(0);
  });

  test('a huge income taxes at 35% on the amount over 8M', () => {
    // 2,202,500 base + 35% of (1,000,000,000 - 8,000,000)
    expect(annualIncomeTax(1000000000)).toBe(2202500 + 0.35 * (1000000000 - 8000000));
  });
});

describe('SSS contribution floors, ceilings, and rounding', () => {
  test.each([
    ['rounds pay to the nearest 500 MSC', 20000, 20000],
    ['clamps up to the 5,000 floor', 3000, 5000],
    ['clamps down to the 35,000 ceiling', 50000, 35000],
    ['zero pay yields a zero MSC', 0, 0],
  ])('%s', (_label, monthly, expectedMSC) => {
    expect(sssMSC(monthly)).toBe(expectedMSC);
  });

  test('employee SSS is 5% of the MSC', () => {
    expect(sssEmployee(20000)).toBe(1000);
    expect(sssEmployee(0)).toBe(0);
  });

  test('employer SSS adds the 30 peso EC at or above a 15k MSC', () => {
    expect(sssEmployer(20000)).toBe(2030); // 20000*0.1 + 30
  });

  test('employer SSS adds only the 10 peso EC below a 15k MSC', () => {
    expect(sssEmployer(10000)).toBe(1010); // 10000*0.1 + 10
  });
});

describe('PhilHealth premium floor and ceiling', () => {
  test('employee PhilHealth is 2.5% of pay in the normal range', () => {
    expect(philhealthEmployee(20000)).toBe(500);
  });

  test('pay below the 10k floor is charged on the floor', () => {
    expect(philhealthEmployee(5000)).toBe(250);
  });

  test('pay above the 100k ceiling is charged on the ceiling', () => {
    expect(philhealthEmployee(200000)).toBe(2500);
  });

  test('zero pay yields zero PhilHealth', () => {
    expect(philhealthEmployee(0)).toBe(0);
  });
});

describe('Pag-IBIG reduced rate and fund salary cap', () => {
  test('the reduced 1% rate applies at or below 1,500', () => {
    expect(pagibigEmployee(1500)).toBe(15);
    expect(pagibigEmployee(1000)).toBe(10);
  });

  test('the standard 2% rate applies above 1,500', () => {
    expect(pagibigEmployee(2000)).toBe(40);
  });

  test('the fund salary is capped at 10,000, so the employee pays at most 200', () => {
    expect(pagibigEmployee(50000)).toBe(200);
  });

  test('the employer always matches at 2%, even at the 1,500 reduced-rate level', () => {
    expect(pagibigEmployer(1500)).toBe(30); // 1500 * 0.02, not the employee 1%
  });
});

describe('contributionBreakdown totals reconcile', () => {
  test('employee and employer sides sum into the grand total', () => {
    const b = contributionBreakdown(20000);
    expect(b.sss.total).toBe(b.sss.employee + b.sss.employer);
    expect(b.employeeTotal).toBe(b.sss.employee + b.philhealth.employee + b.pagibig.employee);
    expect(b.grandTotal).toBe(b.employeeTotal + b.employerTotal);
    expect(b.msc).toBe(20000);
    expect(b.ratesYear).toBe(2026);
  });
});

describe('takeHomePay for an employee is the known-correct payslip estimate', () => {
  test('a 25,000 basic salary nets 22,611.25 after contributions and tax', () => {
    const p = takeHomePay(25000);
    expect(p.sss).toBe(1250);
    expect(p.philhealth).toBe(625);
    expect(p.pagibig).toBe(200);
    expect(p.contributions).toBe(2075);
    expect(p.monthlyTaxable).toBe(22925);
    expect(p.annualTax).toBe(3765);
    expect(p.monthlyTax).toBe(313.75);
    expect(p.gross).toBe(25000);
    expect(p.net).toBe(22611.25);
    expect(p.ratesYear).toBe(2026);
  });

  test('a zero salary nets zero and never goes negative', () => {
    const p = takeHomePay(0);
    expect(p.net).toBe(0);
    expect(p.contributions).toBe(0);
    expect(p.monthlyTax).toBe(0);
  });

  test('a non-taxable allowance passes straight to take-home, never taxed', () => {
    const base = takeHomePay(25000);
    const withAllowance = takeHomePay(25000, { nonTaxableAllowance: 2000 });
    expect(withAllowance.net).toBe(base.net + 2000);
    expect(withAllowance.monthlyTax).toBe(base.monthlyTax);
  });

  test('a taxable allowance raises both the taxable base and the tax', () => {
    const base = takeHomePay(25000);
    const taxed = takeHomePay(25000, { taxableAllowance: 5000 });
    expect(taxed.monthlyTaxable).toBe(base.monthlyTaxable + 5000);
    expect(taxed.monthlyTax).toBeGreaterThan(base.monthlyTax);
  });
});

describe('self-employed percentage tax, VAT threshold, and the 8% option', () => {
  test('the percentage tax is a flat 3% of gross', () => {
    expect(PERCENTAGE_TAX_RATE).toBe(0.03);
    expect(percentageTax(1000000)).toBe(30000);
    expect(percentageTax(0)).toBe(0);
  });

  test('the VAT threshold and self-employed exemption are the published values', () => {
    expect(VAT_THRESHOLD).toBe(3000000);
    expect(SELF_EMPLOYED_EXEMPT).toBe(250000);
  });

  test('the 8% option exempts the first 250k for a purely self-employed earner', () => {
    expect(eightPercentTax(1000000)).toBe(60000); // (1,000,000 - 250,000) * 8%
  });

  test('a mixed-income earner gets no 250k exemption on the 8% option', () => {
    expect(eightPercentTax(1000000, { mixedIncome: true })).toBe(80000); // whole gross * 8%
  });

  test('gross at or below the 250k exemption owes no 8% tax', () => {
    expect(eightPercentTax(200000)).toBe(0);
  });
});

describe('graduated self-employed tax with the 40% OSD', () => {
  test('a 1M gross with OSD owes 62,500 income tax plus 30,000 percentage tax', () => {
    const g = graduatedSelfEmployedTax(1000000);
    expect(g.deduction).toBe(400000); // 40% OSD
    expect(g.net).toBe(600000);
    expect(g.incomeTax).toBe(62500);
    expect(g.percentageTax).toBe(30000);
    expect(g.total).toBe(92500);
  });

  test('above the VAT threshold the 3% percentage tax drops off', () => {
    const g = graduatedSelfEmployedTax(4000000, { vatRegistered: true });
    expect(g.percentageTax).toBe(0);
  });
});

describe('selfEmployedTax compares both regimes and picks the cheaper', () => {
  test('at 1M gross the flat 8% wins and reports the savings', () => {
    const r = selfEmployedTax(1000000);
    expect(r.eligible8).toBe(true);
    expect(r.eightPercent.total).toBe(60000);
    expect(r.graduated.total).toBe(92500);
    expect(r.recommended).toBe('eight');
    expect(r.savings).toBe(32500);
    expect(r.effectiveRate).toBe(6);
  });

  test('above the VAT threshold the 8% option is refused and graduated is forced', () => {
    const r = selfEmployedTax(4000000);
    expect(r.eligible8).toBe(false);
    expect(r.recommended).toBe('graduated');
  });

  test('a mixed earner with no salary cannot be compared, so 8% is shown alone', () => {
    const r = selfEmployedTax(1000000, { mixedIncome: true });
    expect(r.canCompareGraduated).toBe(false);
    expect(r.recommended).toBe('eight');
    expect(r.savings).toBe(0);
  });
});

describe('the 90k bonus ceiling has a single source of truth', () => {
  test('phtax owns it and thirteenth re-exports the same value', () => {
    expect(BONUS_TAX_FREE_CEILING).toBe(90000);
    expect(THIRTEENTH_TAX_FREE_CEILING).toBe(BONUS_TAX_FREE_CEILING);
  });
});

describe('annualizeCompensation trues up the year and shows a refund or a shortfall', () => {
  test('a mid-year hire was over-withheld and gets a refund', () => {
    // 25,000 basic for 6 months annualizes to 137,550 taxable, below the
    // 250,000 floor, so the real tax is 0. If the employer withheld as if it
    // were a full year (313.75 x 6 = 1,882.50), all of it comes back.
    const r = annualizeCompensation(25000, { monthsWorked: 6, taxWithheld: 1882.5 });
    expect(r.regularTaxable).toBe(137550);
    expect(r.bonusTaxable).toBe(0);
    expect(r.annualTaxDue).toBe(0);
    expect(r.difference).toBe(1882.5);
    expect(r.isRefund).toBe(true);
    expect(r.effectiveRate).toBe(0);
  });

  test('a big bonus pushed the real tax above what was withheld, so the employee still owes', () => {
    // 50,000 basic all year: monthly taxable 46,800, annual 561,600. A 150,000
    // bonus (13th plus performance) is 60,000 over the 90,000 ceiling, so
    // taxable income is 621,600 and real tax is 66,820. If payroll only withheld
    // on the regular pay (54,820), the year-end trueup collects the 12,000 gap.
    const r = annualizeCompensation(50000, { bonuses: 150000, taxWithheld: 54820 });
    expect(r.regularTaxable).toBe(561600);
    expect(r.bonusTaxable).toBe(60000);
    expect(r.annualTaxable).toBe(621600);
    expect(r.annualTaxDue).toBe(66820);
    expect(r.difference).toBe(-12000);
    expect(r.isRefund).toBe(false);
  });

  test('withholding that exactly matches the tax due settles to zero, not a refund', () => {
    const r = annualizeCompensation(25000, { bonuses: 25000, taxWithheld: 3765 });
    expect(r.annualTaxDue).toBe(3765);
    expect(r.difference).toBe(0);
    expect(r.isRefund).toBe(false);
  });

  test('bonuses up to 90k are fully sheltered; only the excess is taxable', () => {
    expect(annualizeCompensation(50000, { bonuses: 90000 }).bonusTaxable).toBe(0);
    expect(annualizeCompensation(50000, { bonuses: 90001 }).bonusTaxable).toBe(1);
  });

  test('a minimum wage level salary annualizes to zero tax', () => {
    const r = annualizeCompensation(12000, { taxWithheld: 0 });
    expect(r.annualTaxDue).toBe(0);
    expect(r.difference).toBe(0);
    expect(r.isRefund).toBe(false);
  });

  test('months default to a full year and never go negative', () => {
    const r = annualizeCompensation(25000);
    expect(r.monthsWorked).toBe(12);
    const zero = annualizeCompensation(0);
    expect(zero.annualTaxDue).toBe(0);
    expect(zero.effectiveRate).toBe(0);
  });
});
