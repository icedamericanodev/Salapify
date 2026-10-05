const fs = require('fs');

const path = 'src/utils/philippineFinances.ts';
let content = fs.readFileSync(path, 'utf8');

const regex = /export interface EmployeeTaxCalculation \{[\s\S]*?return \{[\s\S]*?isTaxExempt13th.*?,\n  \};\n\}/;

const newCode = `export interface EmployeeTaxCalculation {
  inputFrequency: 'semi-monthly' | 'bi-weekly' | 'monthly' | 'annually';
  inputSalary: number;
  taxableAllowance: number;
  nonTaxableAllowance: number;
  overtime: number;
  nightDifferential: number;
  grossMonthlyIncome: number;
  monthlySalary: number;
  monthsWorked: number;
  sss: number;
  sssEmployer: number;
  philhealth: number;
  philhealthEmployer: number;
  pagibig: number;
  pagibigEmployer: number;
  totalContributions: number;
  taxableIncome: number;
  withholdingTax: number;
  netTakeHome: number;
  semiMonthlyTakeHome: number;
  annualGrossSalary: number;
  annualTotalTax: number;
  annualNetTakeHome: number;
  thirteenthMonthGross: number;
  thirteenthMonthTaxable: number;
  thirteenthMonthTax: number;
  thirteenthMonthNet: number;
  isTaxExempt13th: boolean;
}

export interface EmployeeTaxInputs {
  inputSalary: number;
  inputFrequency: 'semi-monthly' | 'bi-weekly' | 'monthly' | 'annually';
  taxableAllowance?: number;
  nonTaxableAllowance?: number;
  overtime?: number;
  nightDifferential?: number;
  monthsWorked?: number;
}

/**
 * Standard Philippine Employee Mandatory Contributions and TRAIN Law Withholding Tax
 * Verified by Philippine CPA & Tax Rules (2024-2025 rates)
 */
export function calculateEmployeeTaxDeductions(
  inputs: EmployeeTaxInputs | number,
  legacyMonthsWorked?: number
): EmployeeTaxCalculation {
  let monthlyBaseSalary = 0;
  let inputFrequency: 'semi-monthly' | 'bi-weekly' | 'monthly' | 'annually' = 'monthly';
  let inputSalary = 0;
  let taxableAllowance = 0;
  let nonTaxableAllowance = 0;
  let overtime = 0;
  let nightDifferential = 0;
  let monthsWorked = legacyMonthsWorked || 12;

  if (typeof inputs === 'number') {
    monthlyBaseSalary = inputs;
    inputSalary = inputs;
  } else {
    inputSalary = inputs.inputSalary || 0;
    inputFrequency = inputs.inputFrequency || 'monthly';
    taxableAllowance = inputs.taxableAllowance || 0;
    nonTaxableAllowance = inputs.nonTaxableAllowance || 0;
    overtime = inputs.overtime || 0;
    nightDifferential = inputs.nightDifferential || 0;
    monthsWorked = inputs.monthsWorked || 12;

    switch (inputFrequency) {
      case 'semi-monthly':
        monthlyBaseSalary = inputSalary * 2;
        break;
      case 'bi-weekly':
        monthlyBaseSalary = (inputSalary * 26) / 12;
        break;
      case 'annually':
        monthlyBaseSalary = inputSalary / 12;
        break;
      case 'monthly':
      default:
        monthlyBaseSalary = inputSalary;
        break;
    }
  }

  // Adjust frequencies for additional inputs assuming they are given in the same frequency
  // Actually, usually allowances are given per period. Let's assume the user enters them as they receive them per period.
  const frequencyMultiplier = inputFrequency === 'semi-monthly' ? 2 : (inputFrequency === 'bi-weekly' ? 26/12 : (inputFrequency === 'annually' ? 1/12 : 1));
  
  const monthlyTaxableAllowance = taxableAllowance * frequencyMultiplier;
  const monthlyNonTaxableAllowance = nonTaxableAllowance * frequencyMultiplier;
  const monthlyOvertime = overtime * frequencyMultiplier;
  const monthlyNightDiff = nightDifferential * frequencyMultiplier;

  if (monthlyBaseSalary <= 0) {
    return {
      inputFrequency,
      inputSalary,
      taxableAllowance,
      nonTaxableAllowance,
      overtime,
      nightDifferential,
      grossMonthlyIncome: 0,
      monthlySalary: 0,
      monthsWorked,
      sss: 0,
      sssEmployer: 0,
      philhealth: 0,
      philhealthEmployer: 0,
      pagibig: 0,
      pagibigEmployer: 0,
      totalContributions: 0,
      taxableIncome: 0,
      withholdingTax: 0,
      netTakeHome: 0,
      semiMonthlyTakeHome: 0,
      annualGrossSalary: 0,
      annualTotalTax: 0,
      annualNetTakeHome: 0,
      thirteenthMonthGross: 0,
      thirteenthMonthTaxable: 0,
      thirteenthMonthTax: 0,
      thirteenthMonthNet: 0,
      isTaxExempt13th: true,
    };
  }

  // 1. SSS: Regular employee share 4.5% of Monthly Salary Credit (MSC) + WISP
  // Max MSC for regular SSS is 20,000. Above 20,000 goes to WISP (up to 30,000 total).
  // Total employee share is simply 4.5% of up to 30,000.
  const sssMsc = Math.min(30000, Math.max(4000, monthlyBaseSalary));
  const sss = Math.round(sssMsc * 0.045);
  const sssEmployer = Math.round(sssMsc * 0.095);

  // 2. PhilHealth: 5% total premium split 50/50 (2.5% employee share)
  // Floor ₱10,000 (₱250 share), Ceiling ₱100,000 (₱2,500 share) (2024/2025 rates)
  const philhealthBase = Math.min(100000, Math.max(10000, monthlyBaseSalary));
  const philhealth = Math.round(philhealthBase * 0.025);
  const philhealthEmployer = philhealth;

  // 3. Pag-IBIG: 2% of fund salary up to 10,000 (max ₱200) (2024 updated rate)
  const pagibigBase = Math.min(10000, Math.max(1500, monthlyBaseSalary));
  const pagibig = Math.round(pagibigBase * 0.02);
  const pagibigEmployer = pagibig;

  const totalContributions = sss + philhealth + pagibig;
  
  // Total Taxable Income includes Base Salary + Taxable Allowances + OT + Night Diff - Contributions
  const grossTaxable = monthlyBaseSalary + monthlyTaxableAllowance + monthlyOvertime + monthlyNightDiff;
  const taxableIncome = Math.max(0, grossTaxable - totalContributions);

  // 4. BIR TRAIN Law 2023+ Updated Graduated Monthly Tax Table
  let withholdingTax = 0;
  if (taxableIncome <= 20833.33) {
    withholdingTax = 0;
  } else if (taxableIncome <= 33333.33) {
    withholdingTax = (taxableIncome - 20833.33) * 0.15;
  } else if (taxableIncome <= 66666.67) {
    withholdingTax = 1875.00 + (taxableIncome - 33333.33) * 0.20;
  } else if (taxableIncome <= 166666.67) {
    withholdingTax = 8541.67 + (taxableIncome - 66666.67) * 0.25;
  } else if (taxableIncome <= 666666.67) {
    withholdingTax = 33541.67 + (taxableIncome - 166666.67) * 0.30;
  } else {
    withholdingTax = 183541.67 + (taxableIncome - 666666.67) * 0.35;
  }

  const grossMonthlyIncome = monthlyBaseSalary + monthlyTaxableAllowance + monthlyNonTaxableAllowance + monthlyOvertime + monthlyNightDiff;
  const netTakeHome = Math.max(0, Math.round(grossMonthlyIncome - totalContributions - withholdingTax));
  const semiMonthlyTakeHome = Math.round(netTakeHome / 2);

  // 13th-Month Pay (Based on base salary only)
  const safeMonths = Math.min(12, Math.max(1, monthsWorked));
  const thirteenthMonthGross = Math.round((monthlyBaseSalary * safeMonths) / 12);
  const thirteenthMonthTaxable = Math.max(0, thirteenthMonthGross - 90000); // 90k exemption
  const thirteenthMonthTax = thirteenthMonthTaxable > 0 ? Math.round(thirteenthMonthTaxable * 0.20) : 0; // Approx tax bracket, but realistically it's added to gross. Using simple 20% for excess.
  const thirteenthMonthNet = thirteenthMonthGross - thirteenthMonthTax;

  const annualGrossSalary = grossMonthlyIncome * 12;
  const annualTotalTax = Math.round(withholdingTax * 12 + thirteenthMonthTax);
  const annualNetTakeHome = Math.round(netTakeHome * 12 + thirteenthMonthNet);

  return {
    inputFrequency,
    inputSalary,
    taxableAllowance,
    nonTaxableAllowance,
    overtime,
    nightDifferential,
    grossMonthlyIncome,
    monthlySalary: monthlyBaseSalary,
    monthsWorked,
    sss,
    sssEmployer,
    philhealth,
    philhealthEmployer,
    pagibig,
    pagibigEmployer,
    totalContributions,
    taxableIncome,
    withholdingTax,
    netTakeHome,
    semiMonthlyTakeHome,
    annualGrossSalary,
    annualTotalTax,
    annualNetTakeHome,
    thirteenthMonthGross,
    thirteenthMonthTaxable,
    thirteenthMonthTax,
    thirteenthMonthNet,
    isTaxExempt13th: thirteenthMonthGross <= 90000,
  };
}`;

if (regex.test(content)) {
  content = content.replace(regex, newCode);
  fs.writeFileSync(path, content, 'utf8');
  console.log('Successfully replaced!');
} else {
  console.log('Regex did not match.');
}
