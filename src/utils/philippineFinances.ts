import {
  ThirteenthMonthPlan,
  FreelanceTaxCalculation,
  RemittanceChannel,
  RemittanceRecord,
  CashDenominationCount,
  PaydayRoutineTemplate,
  HouseholdAmbagPool,
} from '../types';

export type CashDenominations = CashDenominationCount;

export const REMITTANCE_CHANNELS: { id: RemittanceChannel; label: string; estFee: number }[] = [
  { id: 'palawan_express', label: 'Palawan Express Pera Padala', estFee: 40 },
  { id: 'cebuana_lhuillier', label: 'Cebuana Lhuillier', estFee: 50 },
  { id: 'gcash_padala', label: 'GCash Padala / Send Money', estFee: 15 },
  { id: 'maya', label: 'Maya Send Money / Instapay', estFee: 15 },
  { id: 'lbc', label: 'LBC Instant Peso Padala', estFee: 60 },
  { id: 'mlhuillier', label: 'M Lhuillier Kwarta Padala', estFee: 50 },
  { id: 'western_union', label: 'Western Union Direct', estFee: 100 },
  { id: 'bdo_remit', label: 'BDO Remit / Kabayan Padala', estFee: 100 },
  { id: 'bank_transfer', label: 'Bank Transfer (InstaPay / PESONet)', estFee: 15 },
  { id: 'cash_handover', label: 'Cash Abot / Personal Handover', estFee: 0 },
];

export const REMITTANCE_PURPOSES: { id: 'living_allowance' | 'school_tuition' | 'medical_maintenance' | 'house_renovation' | 'emergency'; label: string }[] = [
  { id: 'living_allowance', label: 'Living & Grocery Allowance' },
  { id: 'school_tuition', label: 'School Tuition & Baon' },
  { id: 'medical_maintenance', label: 'Medical & Maintenance Meds' },
  { id: 'house_renovation', label: 'Bahay Repairs & Renovation' },
  { id: 'emergency', label: 'Emergency Medical / Financial Help' },
];

export interface EmployeeTaxCalculation {
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

/**
 * Standard Philippine Employee Mandatory Contributions and TRAIN Law Withholding Tax
 * Verified by Philippine CPA & Tax Rules
 */
export function calculateEmployeeTaxDeductions(
  monthlySalary: number,
  monthsWorked: number = 12
): EmployeeTaxCalculation {
  if (monthlySalary <= 0) {
    return {
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

  // 1. SSS: Regular employee share 4.5% of Monthly Salary Credit (MSC)
  // Min MSC: ₱4,000 (₱180 employee share), Max MSC: ₱30,000 (₱1,350 employee share)
  const sssMsc = Math.min(30000, Math.max(4000, monthlySalary));
  const sss = Math.round(sssMsc * 0.045);
  const sssEmployer = Math.round(sssMsc * 0.095);

  // 2. PhilHealth: 5% total premium split 50/50 (2.5% employee share)
  // Floor ₱10,000 (₱250 share), Ceiling ₱100,000 (₱2,500 share)
  const philhealthBase = Math.min(100000, Math.max(10000, monthlySalary));
  const philhealth = Math.round(philhealthBase * 0.025);
  const philhealthEmployer = philhealth;

  // 3. Pag-IBIG: Standard employee contribution capped at ₱200 (HDMF circular ₱10,000 max salary cap)
  const pagibig = 200;
  const pagibigEmployer = 200;

  const totalContributions = sss + philhealth + pagibig;
  const taxableIncome = Math.max(0, monthlySalary - totalContributions);

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

  const netTakeHome = Math.max(0, Math.round(monthlySalary - totalContributions - withholdingTax));
  const semiMonthlyTakeHome = Math.round(netTakeHome / 2);

  // 13th-Month Pay
  const safeMonths = Math.min(12, Math.max(1, monthsWorked));
  const thirteenthMonthGross = Math.round((monthlySalary * safeMonths) / 12);
  const thirteenthMonthTaxable = Math.max(0, thirteenthMonthGross - 90000);
  const thirteenthMonthTax = thirteenthMonthTaxable > 0 ? Math.round(thirteenthMonthTaxable * 0.20) : 0;
  const thirteenthMonthNet = thirteenthMonthGross - thirteenthMonthTax;

  const annualGrossSalary = monthlySalary * 12;
  const annualTotalTax = Math.round(withholdingTax * 12 + thirteenthMonthTax);
  const annualNetTakeHome = Math.round(netTakeHome * 12 + thirteenthMonthNet);

  return {
    monthlySalary,
    monthsWorked: safeMonths,
    sss,
    sssEmployer,
    philhealth,
    philhealthEmployer,
    pagibig,
    pagibigEmployer,
    totalContributions,
    taxableIncome: Math.round(taxableIncome),
    withholdingTax: Math.round(withholdingTax),
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
}

/**
 * 13th-Month Pay Calculation (Presidential Decree No. 851 & Republic Act No. 10963 TRAIN Law)
 * Formula: (Total Basic Salary Earned within the Calendar Year) / 12
 * Tax-exempt ceiling: First PHP 90,000 is 100% Tax-Exempt under TRAIN Law.
 */
export function calculate13thMonthPay(
  basicMonthlySalary: number,
  monthsWorked: number = 12,
  marginalTaxRate: number = 0.20
): ThirteenthMonthPlan {
  const safeMonths = Math.min(12, Math.max(0, monthsWorked));
  const calculatedGross = (basicMonthlySalary * safeMonths) / 12;
  const taxExemptThreshold = 90000;
  
  const taxExemptAmount = Math.min(calculatedGross, taxExemptThreshold);
  const taxableExcessAmount = Math.max(0, calculatedGross - taxExemptThreshold);
  const estimatedWithholdingTax = taxableExcessAmount * marginalTaxRate;
  const net13thMonthPay = calculatedGross - estimatedWithholdingTax;

  // Default balanced Filipino 13th-month allocation blueprint
  const allocations = [
    {
      id: 'alloc-1',
      category: 'Ipon & Pag-IBIG MP2',
      name: 'Pag-IBIG MP2 / High-Yield Savings Boost',
      percentage: 35,
      targetAmount: Math.round(net13thMonthPay * 0.35),
      note: 'Compounding wealth builder for long-term goals',
    },
    {
      id: 'alloc-2',
      category: 'Debt & Loan Servicing',
      name: 'Debt & Installment Accelerator (Utang clearance)',
      percentage: 25,
      targetAmount: Math.round(net13thMonthPay * 0.25),
      note: 'Knock down high-interest credit or gadget balances',
    },
    {
      id: 'alloc-3',
      category: 'Family Support & Remittance',
      name: 'Family Pamasko & Sweldo Padala',
      percentage: 20,
      targetAmount: Math.round(net13thMonthPay * 0.20),
      note: 'Gifts and support for parents & relatives in the province',
    },
    {
      id: 'alloc-4',
      category: 'Food & Dining',
      name: 'Christmas Noche Buena & Holiday Celebrations',
      percentage: 10,
      targetAmount: Math.round(net13thMonthPay * 0.10),
      note: 'Family holiday feast and festivities',
    },
    {
      id: 'alloc-5',
      category: 'Shopping & Personal',
      name: 'Guilt-free Self Reward & Year-End Treat',
      percentage: 10,
      targetAmount: Math.round(net13thMonthPay * 0.10),
      note: 'Well-deserved reward for the entire year of hard work',
    },
  ];

  return {
    basicMonthlySalary,
    monthsWorkedTotal: safeMonths,
    calculatedGrossAmount: calculatedGross,
    taxExemptThreshold,
    taxExemptAmount,
    taxableExcessAmount,
    estimatedWithholdingTax,
    net13thMonthPay,
    allocations,
    status: 'projected',
  };
}

/**
 * Philippine Freelance & Self-Employed Tax Engine
 * Computes 8% Gross Income Tax (GIT) vs Graduated Rates under TRAIN Law.
 * 8% GIT allows a standard PHP 250,000 deduction on purely self-employed gross revenue.
 */
export function calculateFreelanceTax(
  annualGrossIncome: number,
  taxOption: '8_percent_git' | 'graduated_rates' = '8_percent_git'
): FreelanceTaxCalculation {
  const standardDeduction = 250000;
  
  if (taxOption === '8_percent_git') {
    const taxableBase = Math.max(0, annualGrossIncome - standardDeduction);
    const estimatedTaxDue = taxableBase * 0.08;
    const effectiveTaxRate = annualGrossIncome > 0 ? (estimatedTaxDue / annualGrossIncome) * 100 : 0;
    const monthlyTaxProvision = estimatedTaxDue / 12;
    const monthlyGross = annualGrossIncome / 12;
    const leanMonthsBufferRecommended = monthlyGross * 3; // 3 months runway

    return {
      grossIncome: annualGrossIncome,
      taxOption,
      allowableDeduction: standardDeduction,
      taxableBase,
      estimatedTaxDue,
      effectiveTaxRate,
      monthlyTaxProvision,
      leanMonthsBufferRecommended,
    };
  } else {
    // Graduated Income Tax Rates under TRAIN Law (2023 onwards)
    let tax = 0;
    const taxableBase = annualGrossIncome;
    if (taxableBase <= 250000) {
      tax = 0;
    } else if (taxableBase <= 400000) {
      tax = (taxableBase - 250000) * 0.15;
    } else if (taxableBase <= 800000) {
      tax = 22500 + (taxableBase - 400000) * 0.20;
    } else if (taxableBase <= 2000000) {
      tax = 102500 + (taxableBase - 800000) * 0.25;
    } else if (taxableBase <= 8000000) {
      tax = 402500 + (taxableBase - 2000000) * 0.30;
    } else {
      tax = 2202500 + (taxableBase - 8000000) * 0.35;
    }

    const effectiveTaxRate = annualGrossIncome > 0 ? (tax / annualGrossIncome) * 100 : 0;
    const monthlyTaxProvision = tax / 12;
    const monthlyGross = annualGrossIncome / 12;
    const leanMonthsBufferRecommended = monthlyGross * 4;

    return {
      grossIncome: annualGrossIncome,
      taxOption,
      allowableDeduction: 0,
      taxableBase,
      estimatedTaxDue: tax,
      effectiveTaxRate,
      monthlyTaxProvision,
      leanMonthsBufferRecommended,
    };
  }
}

/**
 * Standard Philippine Remittance Channel Fee Estimator
 */
export function estimateRemittanceFee(amount: number, channel: RemittanceChannel): number {
  if (amount <= 0) return 0;

  switch (channel) {
    case 'palawan_express':
      if (amount <= 100) return 2;
      if (amount <= 300) return 5;
      if (amount <= 500) return 10;
      if (amount <= 1000) return 20;
      if (amount <= 2000) return 40;
      if (amount <= 5000) return 90;
      if (amount <= 10000) return 160;
      return 220;
    
    case 'cebuana_lhuillier':
    case 'mlhuillier':
      if (amount <= 500) return 15;
      if (amount <= 1000) return 25;
      if (amount <= 3000) return 60;
      if (amount <= 5000) return 110;
      if (amount <= 10000) return 190;
      return 250;

    case 'gcash_padala':
      // GCash Padala standard 1% - 2% fee
      return Math.max(10, Math.round(amount * 0.015));

    case 'maya':
      return 15; // standard Instapay / Send money fee

    case 'lbc':
      if (amount <= 1000) return 30;
      if (amount <= 5000) return 120;
      return 200;

    case 'bank_transfer':
      return 15; // standard InstaPay fee across PH banks

    case 'cash_handover':
      return 0;

    case 'western_union':
    case 'bdo_remit':
    default:
      return Math.max(50, Math.round(amount * 0.02));
  }
}

/**
 * Compute total value of Cash Denomination counts
 */
export function calculateCashTotal(counts: CashDenominationCount): number {
  return (
    (counts.p1000 || 0) * 1000 +
    (counts.p500 || 0) * 500 +
    (counts.p200 || 0) * 200 +
    (counts.p100 || 0) * 100 +
    (counts.p50 || 0) * 50 +
    (counts.p20 || 0) * 20 +
    (counts.coins || 0)
  );
}

/**
 * Generate polite Taglish payment reminder copy ("Singilin" template)
 */
export function generateTaglishReminderMessage(
  debtorName: string,
  amount: number,
  purpose: string,
  accountInfo?: string
): string {
  const formattedAmount = `₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 2 })}`;
  const destination = accountInfo ? ` pwede po sa ${accountInfo}` : ' via GCash / Maya / Bank';
  
  return `Hi ${debtorName}! Hope you're doing well po. Friendly follow-up lang po for the ${formattedAmount} for ${purpose || 'our shared expense'}${destination}. Salamat po! 🙏✨`;
}

/**
 * Sample Initial Philippine Local Data
 */
export const INITIAL_REMITTANCES: RemittanceRecord[] = [
  {
    id: 'remit-1',
    recipientName: 'Nanay Corazon',
    relationship: 'Nanay',
    provinceCity: 'Iloilo City, Iloilo',
    channel: 'palawan_express',
    amount: 8000,
    fee: 160,
    referenceNumber: 'PE-2026-98124',
    purpose: 'living_allowance',
    cadence: 'monthly',
    status: 'claimed',
    date: '2026-09-02',
    notes: 'Monthly maintenance meds & household allowance for Nanay',
  },
  {
    id: 'remit-2',
    recipientName: 'Bunso Bea',
    relationship: 'Kapatid',
    provinceCity: 'Baguio City',
    channel: 'gcash_padala',
    amount: 3500,
    fee: 50,
    referenceNumber: 'GC-9921471',
    purpose: 'school_tuition',
    cadence: 'monthly',
    status: 'sent',
    date: '2026-09-12',
    notes: 'University dorm allowance & books',
  },
];

export const INITIAL_PAYDAY_TEMPLATES: PaydayRoutineTemplate[] = [
  {
    id: 'tmpl-15-30-quincena',
    name: '15th & 30th Sweldo Quincena Master Blueprint',
    cycleType: '15_30',
    cutoff: 'both',
    baseSalary: 45000,
    items: [
      {
        id: 'p-item-1',
        name: 'Meralco, Converge & Water Bills',
        category: 'Bills & Utilities',
        amount: 8500,
        percentage: 18.8,
        bucket: 'bills',
        isAutomaticTransfer: true,
      },
      {
        id: 'p-item-2',
        name: 'Padala kay Nanay sa Probinsya',
        category: 'Family Support & Remittance',
        amount: 8000,
        percentage: 17.7,
        bucket: 'padala',
        isAutomaticTransfer: false,
      },
      {
        id: 'p-item-3',
        name: 'Pag-IBIG MP2 & SeaBank High-Yield',
        category: 'Investment & Passive Income',
        amount: 9000,
        percentage: 20.0,
        bucket: 'ipon_mp2',
        isAutomaticTransfer: true,
      },
      {
        id: 'p-item-4',
        name: 'Home Credit / SpayLater Installment',
        category: 'Debt & Loan Servicing',
        amount: 3500,
        percentage: 7.8,
        bucket: 'debt_service',
        isAutomaticTransfer: true,
      },
      {
        id: 'p-item-5',
        name: 'Daily Commute & Food Allowance (Safe to Spend)',
        category: 'Food & Dining',
        amount: 16000,
        percentage: 35.5,
        bucket: 'daily_allowance',
        isAutomaticTransfer: false,
      },
    ],
    notes: 'Quincena allocation rule ensuring 0% missed bills and automated 20% savings first before spending.',
  },
];

export const INITIAL_HOUSEHOLD_AMBAG: HouseholdAmbagPool = {
  id: 'pool-bahay-1',
  name: 'Ambagan sa Bahay (Family Shared Bills)',
  totalMonthlyExpenseTarget: 22000,
  totalCollectedThisMonth: 17500,
  cycleMonth: '2026-09',
  members: [
    {
      id: 'hm-1',
      name: 'Ako (Self)',
      relation: 'Self',
      monthlyIncome: 45000,
      assignedSharePercentage: 45,
      monthlyExpectedAmbag: 9900,
      actualPaidThisMonth: 9900,
      assignedUtilities: ['Meralco Electricity', 'Converge Fiber WiFi'],
      isSettled: true,
    },
    {
      id: 'hm-2',
      name: 'Kuya Mark',
      relation: 'Kuya',
      monthlyIncome: 38000,
      assignedSharePercentage: 35,
      monthlyExpectedAmbag: 7700,
      actualPaidThisMonth: 7600,
      assignedUtilities: ['Supermarket Groceries', 'Maynilad Water'],
      isSettled: true,
    },
    {
      id: 'hm-3',
      name: 'Ate Sarah',
      relation: 'Ate',
      monthlyIncome: 28000,
      assignedSharePercentage: 20,
      monthlyExpectedAmbag: 4400,
      actualPaidThisMonth: 0,
      assignedUtilities: ['Pantry & LPG Gasul'],
      isSettled: false,
    },
  ],
  billsIncluded: [
    { name: 'Meralco Electricity', amount: 5800, paidByMemberId: 'hm-1' },
    { name: 'Converge Fiber 200Mbps', amount: 1625, paidByMemberId: 'hm-1' },
    { name: 'Supermarket Groceries (Puregold)', amount: 11000, paidByMemberId: 'hm-2' },
    { name: 'Maynilad Water', amount: 850, paidByMemberId: 'hm-2' },
    { name: 'LPG Gasul Tank Refill', amount: 1200, paidByMemberId: undefined },
    { name: 'Drinking Water Galon Refills', amount: 450, paidByMemberId: undefined },
  ],
};
