import { AmortizationRow, InstallmentPlan, PaymentFrequency, InterestRateType } from '../types';

export interface LoanCalculationParams {
  principal: number;
  annualInterestRate: number; // e.g. 6.25 for 6.25%
  termMonths: number;
  rateType?: 'diminishing' | 'flat_addon';
  paymentFrequency?: PaymentFrequency;
  balloonPayment?: number;
  extraMonthlyPayment?: number;
}

export interface LoanCalculationResult {
  monthlyPayment: number;
  totalPayment: number;
  totalInterest: number;
  amortizationSchedule: AmortizationRow[];
  payoffMonths: number;
  interestSavedWithExtra: number;
  monthsSavedWithExtra: number;
  dsrPercentage?: number;
  affordabilityStatus?: 'healthy' | 'moderate' | 'stretched';
}

/**
 * Standard monthly compounding amortization calculation
 */
export function calculateAmortization(params: LoanCalculationParams): LoanCalculationResult {
  const {
    principal,
    annualInterestRate,
    termMonths,
    rateType = 'diminishing',
    balloonPayment = 0,
    extraMonthlyPayment = 0,
  } = params;

  if (principal <= 0 || termMonths <= 0) {
    return {
      monthlyPayment: 0,
      totalPayment: 0,
      totalInterest: 0,
      amortizationSchedule: [],
      payoffMonths: 0,
      interestSavedWithExtra: 0,
      monthsSavedWithExtra: 0,
    };
  }

  const monthlyRate = annualInterestRate / 100 / 12;

  let baseMonthlyPayment = 0;
  if (rateType === 'flat_addon') {
    // Flat add-on calculation commonly used by Philippine auto & appliance installment lenders
    const totalFlatInterest = principal * (annualInterestRate / 100) * (termMonths / 12);
    baseMonthlyPayment = (principal - balloonPayment + totalFlatInterest) / termMonths;
  } else if (monthlyRate === 0) {
    baseMonthlyPayment = (principal - balloonPayment) / termMonths;
  } else {
    // Standard diminishing balance formula (P * r * (1+r)^n - B * r) / ((1+r)^n - 1)
    const factor = Math.pow(1 + monthlyRate, termMonths);
    baseMonthlyPayment =
      ((principal * monthlyRate * factor) - (balloonPayment * monthlyRate)) / (factor - 1);
  }

  // Generate baseline schedule without extra payments to compare savings
  let baselineTotalInterest = 0;
  let balance = principal;
  for (let m = 1; m <= termMonths; m++) {
    const interest = balance * monthlyRate;
    const principalPart = Math.min(balance, baseMonthlyPayment - interest);
    baselineTotalInterest += interest;
    balance -= principalPart;
    if (balance <= 0) break;
  }

  // Generate actual schedule with extra payments
  const schedule: AmortizationRow[] = [];
  let remainingBalance = principal;
  let totalPaid = 0;
  let totalInterest = 0;
  let actualPayoffMonths = 0;

  for (let period = 1; period <= termMonths * 2; period++) {
    if (remainingBalance <= 0.01) break;

    const interestComponent = rateType === 'flat_addon'
      ? (principal * (annualInterestRate / 100) / 12)
      : (remainingBalance * monthlyRate);

    let scheduledPrincipal = baseMonthlyPayment - interestComponent;
    if (scheduledPrincipal > remainingBalance) {
      scheduledPrincipal = remainingBalance;
    }

    const extra = Math.min(extraMonthlyPayment, Math.max(0, remainingBalance - scheduledPrincipal));
    const totalPrincipalForMonth = scheduledPrincipal + extra;

    remainingBalance = Math.max(0, remainingBalance - totalPrincipalForMonth);
    const scheduledPaymentForMonth = scheduledPrincipal + interestComponent;

    totalInterest += interestComponent;
    totalPaid += (scheduledPaymentForMonth + extra);
    actualPayoffMonths = period;

    schedule.push({
      period,
      dueDate: `Month ${period}`,
      scheduledPayment: Math.round(scheduledPaymentForMonth * 100) / 100,
      principalComponent: Math.round(scheduledPrincipal * 100) / 100,
      interestComponent: Math.round(interestComponent * 100) / 100,
      extraPayment: Math.round(extra * 100) / 100,
      remainingBalance: Math.round(remainingBalance * 100) / 100,
    });

    if (remainingBalance <= 0) break;
  }

  // Handle balloon payment if applicable at end of term
  if (balloonPayment > 0 && actualPayoffMonths >= termMonths) {
    totalPaid += balloonPayment;
  }

  const interestSaved = Math.max(0, baselineTotalInterest - totalInterest);
  const monthsSaved = Math.max(0, termMonths - actualPayoffMonths);

  return {
    monthlyPayment: Math.round(baseMonthlyPayment * 100) / 100,
    totalPayment: Math.round(totalPaid * 100) / 100,
    totalInterest: Math.round(totalInterest * 100) / 100,
    amortizationSchedule: schedule,
    payoffMonths: actualPayoffMonths,
    interestSavedWithExtra: Math.round(interestSaved * 100) / 100,
    monthsSavedWithExtra: monthsSaved,
  };
}

/**
 * Debt-Service Ratio (DSR) and Affordability Evaluator
 * BSP prudential standard: < 30% Healthy, 30-40% Moderate, > 40% High Risk
 */
export function calculateDSR(monthlyDebtObligations: number, grossMonthlyIncome: number) {
  if (grossMonthlyIncome <= 0) {
    return {
      dsr: 0,
      status: 'healthy' as const,
      maxRecommendedMonthlyDebt: 0,
      maxBorrowingCapacity30Yr: 0,
      advice: 'Enter gross monthly income to evaluate debt capacity.',
    };
  }

  const dsr = (monthlyDebtObligations / grossMonthlyIncome) * 100;
  const maxRecommendedMonthlyDebt = grossMonthlyIncome * 0.35; // 35% benchmark
  const remainingDebtCapacity = Math.max(0, maxRecommendedMonthlyDebt - monthlyDebtObligations);
  
  // Approximate borrowing power on a 15-year 7% housing loan
  const r = 0.07 / 12;
  const n = 180;
  const maxBorrowingCapacity30Yr = remainingDebtCapacity > 0 
    ? Math.round(remainingDebtCapacity * ((Math.pow(1 + r, n) - 1) / (r * Math.pow(1 + r, n))))
    : 0;

  let status: 'healthy' | 'moderate' | 'stretched' = 'healthy';
  let advice = 'Your debt commitments are well within the 30% BSP safety threshold.';

  if (dsr > 40) {
    status = 'stretched';
    advice = 'Debt commitments exceed 40% of income. High vulnerability to income shocks.';
  } else if (dsr >= 30) {
    status = 'moderate';
    advice = 'Debt commitments are between 30% and 40%. Approaching the cautionary threshold.';
  }

  return {
    dsr: Math.round(dsr * 10) / 10,
    status,
    maxRecommendedMonthlyDebt: Math.round(maxRecommendedMonthlyDebt),
    maxBorrowingCapacity30Yr,
    advice,
  };
}

/**
 * PAG-IBIG Housing Loan Presets and Calculator
 */
export interface PagIbigOptions {
  program: 'affordable_housing' | 'regular_housing';
  loanAmount: number;
  termYears: number; // 5 to 30 years
  fixingPeriodYears: 1 | 3 | 5 | 10 | 15 | 20 | 25 | 30;
  extraMonthlyPayment?: number;
}

export function calculatePagIbigHousingLoan(options: PagIbigOptions): LoanCalculationResult {
  let annualRate = 5.75; // Default 3-year fixing

  if (options.program === 'affordable_housing') {
    // 3.0% for minimum wage earners up to ₱750,000
    annualRate = 3.0;
  } else {
    switch (options.fixingPeriodYears) {
      case 1:
        annualRate = 5.375;
        break;
      case 3:
        annualRate = 5.75;
        break;
      case 5:
        annualRate = 6.25;
        break;
      case 10:
        annualRate = 7.125;
        break;
      default:
        annualRate = 7.75;
        break;
    }
  }

  const termMonths = options.termYears * 12;
  return calculateAmortization({
    principal: options.loanAmount,
    annualInterestRate: annualRate,
    termMonths,
    extraMonthlyPayment: options.extraMonthlyPayment || 0,
  });
}

/**
 * Bank Housing Loan Calculator (BPI, BDO, Metrobank, Security Bank)
 * Supports fixed period, repricing stress testing, and downpayment LTV
 */
export interface BankHousingOptions {
  propertyValue: number;
  downpaymentPercent: number; // e.g. 20 for 20%
  termYears: number; // 5 to 25 years
  fixedRate: number; // e.g. 6.75%
  repricedRate?: number; // e.g. 8.5% after fixed period
  fixedPeriodYears?: number; // e.g. 3 or 5 years
  extraMonthlyPayment?: number;
}

export function calculateBankHousingLoan(options: BankHousingOptions) {
  const downpaymentAmount = options.propertyValue * (options.downpaymentPercent / 100);
  const loanPrincipal = Math.max(0, options.propertyValue - downpaymentAmount);
  const termMonths = options.termYears * 12;

  const result = calculateAmortization({
    principal: loanPrincipal,
    annualInterestRate: options.fixedRate,
    termMonths,
    extraMonthlyPayment: options.extraMonthlyPayment || 0,
  });

  // Repricing stress test
  let repricedMonthlyPayment = result.monthlyPayment;
  if (options.repricedRate && options.repricedRate > options.fixedRate) {
    const fixedMonths = (options.fixedPeriodYears || 3) * 12;
    const remainingTerm = Math.max(12, termMonths - fixedMonths);
    const estimatedBalance = loanPrincipal * 0.85; // approx remaining balance
    const repricedResult = calculateAmortization({
      principal: estimatedBalance,
      annualInterestRate: options.repricedRate,
      termMonths: remainingTerm,
    });
    repricedMonthlyPayment = repricedResult.monthlyPayment;
  }

  return {
    propertyValue: options.propertyValue,
    downpaymentAmount,
    loanPrincipal,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    payoffMonths: result.payoffMonths,
    interestSavedWithExtra: result.interestSavedWithExtra,
    repricedMonthlyPayment,
    monthlyPaymentJump: Math.max(0, repricedMonthlyPayment - result.monthlyPayment),
    schedule: result.amortizationSchedule,
  };
}

/**
 * Philippine Auto / Car Loan Calculator
 * Supports flat add-on vs diminishing, downpayment, chattel mortgage, and balloon payments
 */
export interface CarLoanOptions {
  vehiclePrice: number;
  downpaymentPercent: number; // e.g. 20%
  termMonths: number; // 12, 24, 36, 48, 60
  annualInterestRate: number; // e.g. 9.5% flat add-on or 15% diminishing
  rateType: 'flat_addon' | 'diminishing';
  balloonPercent?: number; // e.g. 20% for residual balloon
  includeInsuranceAndChattel?: boolean;
}

export function calculateCarLoan(options: CarLoanOptions) {
  const downpaymentAmount = options.vehiclePrice * (options.downpaymentPercent / 100);
  const loanPrincipal = Math.max(0, options.vehiclePrice - downpaymentAmount);
  const balloonPayment = options.balloonPercent ? options.vehiclePrice * (options.balloonPercent / 100) : 0;

  // Approx chattel mortgage fee (~2-3% of loan amount) and 1st year insurance (~2.5% of car price)
  const chattelMortgageFee = options.includeInsuranceAndChattel ? loanPrincipal * 0.025 : 0;
  const comprehensiveInsurance = options.includeInsuranceAndChattel ? options.vehiclePrice * 0.024 : 0;
  const initialCashOut = downpaymentAmount + chattelMortgageFee + comprehensiveInsurance;

  const result = calculateAmortization({
    principal: loanPrincipal,
    annualInterestRate: options.annualInterestRate,
    termMonths: options.termMonths,
    rateType: options.rateType,
    balloonPayment,
  });

  return {
    vehiclePrice: options.vehiclePrice,
    downpaymentAmount,
    loanPrincipal,
    chattelMortgageFee,
    comprehensiveInsurance,
    initialCashOut,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    balloonPayment,
    schedule: result.amortizationSchedule,
  };
}

/**
 * Salary Loan Calculator (SSS, GSIS, Pag-IBIG Multi-Purpose & Calamity Loan)
 * SSS: 10% diminishing p.a., 24-36 months
 * Pag-IBIG MPL: 10.5% p.a. with ~20% dividend earnings rebate returned to members
 */
export interface SalaryLoanOptions {
  loanType: 'sss_salary' | 'pagibig_mpl' | 'pagibig_calamity' | 'gsis_conso';
  loanAmount: number;
  termMonths: number; // 24 or 36
}

export function calculateSalaryLoan(options: SalaryLoanOptions) {
  let annualRate = 10.0;
  let processingFeePercent = 1.0;
  let dividendRebatePercent = 0;

  if (options.loanType === 'sss_salary') {
    annualRate = 10.0; // SSS 10% p.a.
    processingFeePercent = 1.0;
  } else if (options.loanType === 'pagibig_mpl') {
    annualRate = 10.5; // Pag-IBIG MPL 10.5% p.a.
    processingFeePercent = 0;
    dividendRebatePercent = 20.0; // Pag-IBIG returns ~20% of loan earnings back as member dividends
  } else if (options.loanType === 'pagibig_calamity') {
    annualRate = 5.95; // Pag-IBIG Calamity Loan subsidized
    processingFeePercent = 0;
  } else if (options.loanType === 'gsis_conso') {
    annualRate = 12.0;
    processingFeePercent = 1.5;
  }

  const result = calculateAmortization({
    principal: options.loanAmount,
    annualInterestRate: annualRate,
    termMonths: options.termMonths,
    rateType: 'diminishing',
  });

  const processingFee = options.loanAmount * (processingFeePercent / 100);
  const netProceeds = options.loanAmount - processingFee;
  const estimatedDividendRebate = (result.totalInterest * (dividendRebatePercent / 100));
  const effectiveTotalCost = result.totalInterest - estimatedDividendRebate + processingFee;

  return {
    loanAmount: options.loanAmount,
    netProceeds,
    processingFee,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    estimatedDividendRebate,
    effectiveTotalCost: Math.round(effectiveTotalCost),
    annualRate,
    schedule: result.amortizationSchedule,
  };
}

/**
 * Personal Loan & Digital Bank Loan Calculator (Maya, CIMB, Tonik, BPI Personal)
 */
export interface PersonalLoanOptions {
  principal: number;
  termMonths: number;
  monthlyAddOnRate: number; // e.g. 1.2% - 2.5% per month
  processingFee: number; // e.g. ₱1,500 or 2%
}

export function calculatePersonalLoan(options: PersonalLoanOptions) {
  const annualRate = options.monthlyAddOnRate * 12;
  const result = calculateAmortization({
    principal: options.principal,
    annualInterestRate: annualRate,
    termMonths: options.termMonths,
    rateType: 'flat_addon',
  });

  const netCashReceived = Math.max(0, options.principal - options.processingFee);

  return {
    principal: options.principal,
    processingFee: options.processingFee,
    netCashReceived,
    monthlyPayment: result.monthlyPayment,
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    schedule: result.amortizationSchedule,
  };
}

/**
 * Business & SME Loan Calculator (Working Capital / Merchant Advance)
 */
export interface BusinessLoanOptions {
  principal: number;
  termMonths: number;
  annualInterestRate: number;
  repaymentSchedule: 'daily_debit' | 'weekly' | 'monthly';
  originationFeePercent: number; // e.g. 2%
}

export function calculateBusinessLoan(options: BusinessLoanOptions) {
  const result = calculateAmortization({
    principal: options.principal,
    annualInterestRate: options.annualInterestRate,
    termMonths: options.termMonths,
    rateType: 'diminishing',
  });

  const originationFee = options.principal * (options.originationFeePercent / 100);
  const netDisbursed = options.principal - originationFee;

  let installmentAmount = result.monthlyPayment;
  let frequencyLabel = 'Monthly Amortization';
  let totalInstallmentCycles = options.termMonths;

  if (options.repaymentSchedule === 'weekly') {
    installmentAmount = (result.monthlyPayment * 12) / 52;
    frequencyLabel = 'Weekly Payment';
    totalInstallmentCycles = options.termMonths * 4.33;
  } else if (options.repaymentSchedule === 'daily_debit') {
    installmentAmount = (result.monthlyPayment * 12) / 260; // 260 banking days
    frequencyLabel = 'Daily Banking Debit';
    totalInstallmentCycles = options.termMonths * 21.6;
  }

  return {
    principal: options.principal,
    netDisbursed,
    originationFee,
    monthlyPayment: result.monthlyPayment,
    installmentAmount: Math.round(installmentAmount),
    frequencyLabel,
    totalInstallmentCycles: Math.round(totalInstallmentCycles),
    totalPayment: result.totalPayment,
    totalInterest: result.totalInterest,
    schedule: result.amortizationSchedule,
  };
}

/**
 * Debt Consolidation Calculator
 * Consolidates multiple credit cards and loans into 1 single low-interest personal loan
 */
export interface DebtToConsolidate {
  id: string;
  name: string;
  balance: number;
  monthlyInterestRate: number; // e.g. 3.0%
  currentMonthlyPayment: number;
}

export function calculateDebtConsolidation(
  debts: DebtToConsolidate[],
  newLoanMonthlyRate: number, // e.g. 1.2% per month
  newTermMonths: number // e.g. 24 or 36
) {
  const totalBalance = debts.reduce((sum, d) => sum + d.balance, 0);
  const totalCurrentMonthlyPayment = debts.reduce((sum, d) => sum + d.currentMonthlyPayment, 0);

  // Estimate current total interest without consolidation over approx 24 months
  const currentTotalInterest = debts.reduce((sum, d) => {
    return sum + (d.balance * (d.monthlyInterestRate / 100) * 18);
  }, 0);

  const newAnnualRate = newLoanMonthlyRate * 12;
  const newLoanResult = calculateAmortization({
    principal: totalBalance,
    annualInterestRate: newAnnualRate,
    termMonths: newTermMonths,
    rateType: 'flat_addon',
  });

  const monthlyCashflowRelief = Math.max(0, totalCurrentMonthlyPayment - newLoanResult.monthlyPayment);
  const totalInterestSavings = Math.max(0, currentTotalInterest - newLoanResult.totalInterest);

  return {
    totalBalance,
    totalCurrentMonthlyPayment,
    newMonthlyPayment: newLoanResult.monthlyPayment,
    monthlyCashflowRelief: Math.round(monthlyCashflowRelief),
    currentTotalInterest: Math.round(currentTotalInterest),
    newTotalInterest: newLoanResult.totalInterest,
    totalPayment: newLoanResult.totalPayment,
    totalInterestSavings: Math.round(totalInterestSavings),
    newTermMonths,
    schedule: newLoanResult.amortizationSchedule,
  };
}

/**
 * Credit Card BSP Minimum Payment Trap Calculator
 * BSP Maximum Finance Charge cap: 3% per month (36% p.a.)
 * Minimum Amount Due: Greater of ₱850 or 3% of balance + interest
 */
export interface CreditCardPayoffOptions {
  currentBalance: number;
  monthlyInterestRate?: number; // default 3.0%
  paymentStrategy: 'minimum_only' | 'fixed_amount';
  fixedMonthlyPayment?: number;
}

export interface CreditCardPayoffResult {
  monthsToPayoff: number;
  totalInterestPaid: number;
  totalAmountPaid: number;
  schedule: {
    month: number;
    payment: number;
    interest: number;
    principal: number;
    balance: number;
  }[];
  warningMessage?: string;
}

export function calculateCreditCardPayoff(options: CreditCardPayoffOptions): CreditCardPayoffResult {
  const {
    currentBalance,
    monthlyInterestRate = 3.0,
    paymentStrategy,
    fixedMonthlyPayment = 1500,
  } = options;

  const rate = monthlyInterestRate / 100;
  let balance = currentBalance;
  let totalInterest = 0;
  let totalPaid = 0;
  const schedule = [];
  const maxMonths = 360; // 30-year cap to prevent infinite loop

  for (let month = 1; month <= maxMonths; month++) {
    if (balance <= 0.5) break;

    const interest = balance * rate;
    let payment = 0;

    if (paymentStrategy === 'minimum_only') {
      // Philippine bank standard: 3% of outstanding balance + finance charge, with ₱850 minimum floor
      const calculatedMin = (balance * 0.03) + interest;
      payment = Math.max(850, calculatedMin);
    } else {
      payment = Math.max(850, fixedMonthlyPayment);
    }

    if (payment > balance + interest) {
      payment = balance + interest;
    }

    const principalPaid = payment - interest;
    balance = Math.max(0, balance - principalPaid);
    totalInterest += interest;
    totalPaid += payment;

    if (month <= 36 || month % 6 === 0 || balance <= 0) {
      schedule.push({
        month,
        payment: Math.round(payment),
        interest: Math.round(interest),
        principal: Math.round(principalPaid),
        balance: Math.round(balance),
      });
    }

    if (balance <= 0) break;
  }

  let warningMessage: string | undefined;
  if (paymentStrategy === 'minimum_only' && currentBalance > 20000) {
    warningMessage =
      'Warning: Paying only the minimum due triggers compounding finance charges under the 3% monthly BSP cap, extending repayment to years.';
  }

  return {
    monthsToPayoff: schedule.length > 0 ? (schedule[schedule.length - 1].month) : 0,
    totalInterestPaid: Math.round(totalInterest),
    totalAmountPaid: Math.round(totalPaid),
    schedule,
    warningMessage,
  };
}

/**
 * Debt Snowball vs. Debt Avalanche Simulator
 */
export interface DebtItemForStrategy {
  id: string;
  name: string;
  balance: number;
  interestRate: number; // annual %
  minimumPayment: number;
}

export interface StrategySimulationResult {
  strategy: 'snowball' | 'avalanche';
  monthsToDebtFreedom: number;
  totalInterestPaid: number;
  totalAmountPaid: number;
  orderOfPayoff: string[];
}

export function simulateDebtStrategies(
  debts: DebtItemForStrategy[],
  extraMonthlyBudget: number
): { snowball: StrategySimulationResult; avalanche: StrategySimulationResult; interestDifference: number } {
  const runSimulation = (strategy: 'snowball' | 'avalanche'): StrategySimulationResult => {
    // Clone debts
    let activeDebts = debts.map((d) => ({
      ...d,
      currentBalance: d.balance,
      monthlyRate: d.interestRate / 100 / 12,
    }));

    // Sort order:
    // Snowball: lowest current balance first
    // Avalanche: highest interest rate first
    if (strategy === 'snowball') {
      activeDebts.sort((a, b) => a.currentBalance - b.currentBalance);
    } else {
      activeDebts.sort((a, b) => b.interestRate - a.interestRate);
    }

    let months = 0;
    let totalInterest = 0;
    let totalPaid = 0;
    const orderOfPayoff: string[] = [];
    const maxMonths = 240;

    while (activeDebts.some((d) => d.currentBalance > 1) && months < maxMonths) {
      months++;
      let extraAvailable = extraMonthlyBudget;

      // 1. Accrue monthly interest and pay minimums
      for (const d of activeDebts) {
        if (d.currentBalance <= 0) continue;
        const interest = d.currentBalance * d.monthlyRate;
        totalInterest += interest;
        d.currentBalance += interest;

        const minPay = Math.min(d.currentBalance, d.minimumPayment);
        d.currentBalance -= minPay;
        totalPaid += minPay;

        if (d.currentBalance <= 0.01 && !orderOfPayoff.includes(d.name)) {
          orderOfPayoff.push(d.name);
          // Rollover freed up minimum payment into extraAvailable
          extraAvailable += d.minimumPayment;
        }
      }

      // 2. Put extra money towards target debt
      const targetDebt = activeDebts.find((d) => d.currentBalance > 0.01);
      if (targetDebt && extraAvailable > 0) {
        const extraPay = Math.min(targetDebt.currentBalance, extraAvailable);
        targetDebt.currentBalance -= extraPay;
        totalPaid += extraPay;

        if (targetDebt.currentBalance <= 0.01 && !orderOfPayoff.includes(targetDebt.name)) {
          orderOfPayoff.push(targetDebt.name);
        }
      }
    }

    return {
      strategy,
      monthsToDebtFreedom: months,
      totalInterestPaid: Math.round(totalInterest),
      totalAmountPaid: Math.round(totalPaid),
      orderOfPayoff,
    };
  };

  const snowball = runSimulation('snowball');
  const avalanche = runSimulation('avalanche');
  const interestDifference = Math.max(0, snowball.totalInterestPaid - avalanche.totalInterestPaid);

  return {
    snowball,
    avalanche,
    interestDifference,
  };
}

/**
 * Generate installment amortization schedule from existing InstallmentPlan
 */
export function generateInstallmentAmortization(plan: InstallmentPlan): AmortizationRow[] {
  const annualRate = plan.interestRateType === 'monthly'
    ? plan.interestRate * 12
    : plan.interestRateType === 'daily'
    ? plan.interestRate * 365
    : plan.interestRate;

  const res = calculateAmortization({
    principal: plan.principal,
    annualInterestRate: annualRate,
    termMonths: plan.termMonths,
    rateType: plan.interestRateType === 'fixed' ? 'flat_addon' : 'diminishing',
  });

  return res.amortizationSchedule;
}
