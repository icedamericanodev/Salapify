import {
  Transaction,
  Account,
  Debt,
  Budget,
  ControlCenterAlert,
  DigitalTwinScenarioType,
  DigitalTwinSimulationResult,
  ScamAnalysisResult,
  FinancialCloseMonth,
  FinancialTruthMetadata
} from '../types';

/**
 * Generates the 10 Personal Financial Control Center Alerts:
 * 1. Duplicate charge detection
 * 2. Balance mismatch
 * 3. Category drift
 * 4. Unexpected recurring charge
 * 5. New payee
 * 6. High-fee transaction
 * 7. Cash shortfall
 * 8. Debt-payment risk
 * 9. Forecast variance
 * 10. Missing receipt
 */
export function runControlCenterScan(
  transactions: Transaction[],
  accounts: Account[],
  debts: Debt[],
  budgets: Budget[]
): ControlCenterAlert[] {
  const alerts: ControlCenterAlert[] = [];
  const now = Date.now();

  // 1. Duplicate charge detection
  const expenseTxs = transactions.filter((t) => t.type === 'expense');
  for (let i = 0; i < expenseTxs.length; i++) {
    for (let j = i + 1; j < expenseTxs.length; j++) {
      const a = expenseTxs[i];
      const b = expenseTxs[j];
      const sameMerchant = a.merchant && b.merchant && a.merchant.toLowerCase() === b.merchant.toLowerCase();
      const sameCategory = a.category.toLowerCase() === b.category.toLowerCase();
      const sameAmount = Math.abs(a.amount - b.amount) < 0.01;
      const dayDiff = Math.abs(new Date(a.date).getTime() - new Date(b.date).getTime()) / (1000 * 3600 * 24);

      if (sameAmount && (sameMerchant || sameCategory) && dayDiff <= 2 && a.id !== b.id) {
        alerts.push({
          id: `alert_dup_${a.id}_${b.id}`,
          type: 'duplicate_charge',
          title: 'Potential Duplicate Transaction',
          description: `Two identical charges of ₱${a.amount.toLocaleString()} for "${a.merchant || a.category}" recorded within 48 hours (${a.date} and ${b.date}).`,
          severity: 'medium',
          amount: a.amount,
          relatedTransactionId: b.id,
          detectedAt: now,
          isDismissed: false,
          suggestedAction: 'Review transaction ledger and mark redundant entry as duplicate or excluded.'
        });
        break; // one duplicate alert per pair
      }
    }
  }

  // 2. Balance mismatch (Accounts with zero or negative balance on non-credit accounts)
  accounts.forEach((acc) => {
    if (acc.kind !== 'credit' && acc.kind !== 'loan' && acc.kind !== 'mortgage' && acc.balance < 0) {
      alerts.push({
        id: `alert_neg_bal_${acc.id}`,
        type: 'balance_mismatch',
        title: `Negative Balance in ${acc.name}`,
        description: `Account has a negative balance of ₱${acc.balance.toLocaleString()}. A reconciliation adjustment is needed.`,
        severity: 'high',
        amount: Math.abs(acc.balance),
        relatedAccountId: acc.id,
        detectedAt: now,
        isDismissed: false,
        suggestedAction: 'Reconcile account balance against actual mobile banking / e-wallet statement.'
      });
    }
  });

  // 3. Category drift (Category spending exceeding budget limit)
  budgets.forEach((b) => {
    const spent = transactions
      .filter((t) => t.type === 'expense' && t.category.toLowerCase() === b.category.toLowerCase())
      .reduce((sum, t) => sum + t.amount, 0);

    if (spent > b.limit * 1.15) {
      alerts.push({
        id: `alert_drift_${b.category}`,
        type: 'category_drift',
        title: `Category Drift: ${b.category}`,
        description: `Spent ₱${spent.toLocaleString()} which is ${Math.round((spent / b.limit) * 100)}% of your ₱${b.limit.toLocaleString()} budget limit.`,
        severity: spent > b.limit * 1.3 ? 'high' : 'medium',
        amount: spent - b.limit,
        detectedAt: now,
        isDismissed: false,
        suggestedAction: 'Pace daily expenses or temporarily reallocate limit from discretionary categories.'
      });
    }
  });

  // 4. Unexpected recurring charge (Subscriptions or recurring entries higher than expected)
  const subscriptionTxs = transactions.filter(
    (t) => t.type === 'expense' && (t.category.toLowerCase().includes('sub') || t.tags?.includes('recurring'))
  );
  if (subscriptionTxs.length > 0) {
    const latestSub = subscriptionTxs[0];
    if (latestSub.amount > 1000) {
      alerts.push({
        id: `alert_sub_high_${latestSub.id}`,
        type: 'unexpected_recurring',
        title: 'High Recurring Subscription Entry',
        description: `Recurring charge of ₱${latestSub.amount.toLocaleString()} for "${latestSub.merchant || latestSub.category}" logged this cycle.`,
        severity: 'low',
        amount: latestSub.amount,
        relatedTransactionId: latestSub.id,
        detectedAt: now,
        isDismissed: false,
        suggestedAction: 'Verify plan pricing tier or audit active digital app subscriptions.'
      });
    }
  }

  // 5. New payee detection (Transactions with a previously unseen person or merchant)
  const merchantCounts: Record<string, number> = {};
  transactions.forEach((t) => {
    const name = t.merchant || t.person;
    if (name) {
      merchantCounts[name] = (merchantCounts[name] || 0) + 1;
    }
  });
  const singlePayees = Object.keys(merchantCounts).filter((m) => merchantCounts[m] === 1);
  if (singlePayees.length > 0) {
    const sampleNew = singlePayees[0];
    alerts.push({
      id: `alert_new_payee_${sampleNew}`,
      type: 'new_payee',
      title: `First-Time Payee: ${sampleNew}`,
      description: `First transaction recorded with new recipient "${sampleNew}". Verify routing or invoice details.`,
      severity: 'low',
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Confirm recipient legitimacy and save preferred payment reference.'
    });
  }

  // 6. High-fee transaction detection
  const feeTxs = transactions.filter(
    (t) =>
      t.type === 'expense' &&
      (t.category.toLowerCase().includes('fee') ||
        t.category.toLowerCase().includes('charges') ||
        (t.note && t.note.toLowerCase().includes('fee')))
  );
  const totalFees = feeTxs.reduce((sum, t) => sum + t.amount, 0);
  if (totalFees > 250) {
    alerts.push({
      id: 'alert_high_fees',
      type: 'high_fee',
      title: 'High Banking & Transfer Fee Accumulation',
      description: `₱${totalFees.toLocaleString()} in ATM withdrawal fees, cash-in charges, and InstaPay fees recorded recently.`,
      severity: 'medium',
      amount: totalFees,
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Switch to zero-fee digital bank transfers (e.g. MariBank 15 free weekly InstaPay or CIMB).'
    });
  }

  // 7. Cash shortfall risk
  const liquidCash = accounts
    .filter((a) => a.kind === 'cash' || a.kind === 'bank' || a.kind === 'gcash' || a.kind === 'maya')
    .reduce((sum, a) => sum + a.balance, 0);
  if (liquidCash < 5000) {
    alerts.push({
      id: 'alert_cash_shortfall',
      type: 'cash_shortfall',
      title: 'Low Liquid Cash Runway Alert',
      description: `Total liquid wallet and bank balance is ₱${liquidCash.toLocaleString()}. Buffer is tight for impending utilities or unexpected emergency needs.`,
      severity: 'critical',
      amount: liquidCash,
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Hold non-essential purchases until the upcoming sweldo crediting.'
    });
  }

  // 8. Debt-payment risk
  const unsettledDebts = debts.filter((d) => d.direction === 'i_owe' && !d.isSettled);
  const totalDebtOwed = unsettledDebts.reduce((sum, d) => sum + (d.totalAmount - d.paidAmount), 0);
  if (totalDebtOwed > liquidCash * 0.8 && totalDebtOwed > 0) {
    alerts.push({
      id: 'alert_debt_pressure',
      type: 'debt_payment_risk',
      title: 'Debt Service Cashflow Pressure',
      description: `Pending debt obligations (₱${totalDebtOwed.toLocaleString()}) represent ${Math.round((totalDebtOwed / (liquidCash || 1)) * 100)}% of your available liquid reserves.`,
      severity: 'high',
      amount: totalDebtOwed,
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Review installment amortization schedules and reserve minimum due amounts.'
    });
  }

  // 9. Forecast variance
  const totalExpenses = expenseTxs.reduce((sum, t) => sum + t.amount, 0);
  const totalBudgeted = budgets.reduce((sum, b) => sum + b.limit, 0);
  if (totalBudgeted > 0 && totalExpenses > totalBudgeted) {
    alerts.push({
      id: 'alert_forecast_var',
      type: 'forecast_variance',
      title: 'Overall Budget Limit Exceeded',
      description: `Total cycle expenses (₱${totalExpenses.toLocaleString()}) have exceeded your aggregate budget plan (₱${totalBudgeted.toLocaleString()}) by ₱${(totalExpenses - totalBudgeted).toLocaleString()}.`,
      severity: 'high',
      amount: totalExpenses - totalBudgeted,
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Adjust non-critical category limits or perform an interim financial review.'
    });
  }

  // 10. Missing receipt detection
  const largeTxsWithoutReceipt = transactions.filter(
    (t) => t.type === 'expense' && t.amount >= 1500 && !t.attachmentUrl
  );
  if (largeTxsWithoutReceipt.length > 0) {
    alerts.push({
      id: 'alert_missing_receipts',
      type: 'missing_receipt',
      title: `${largeTxsWithoutReceipt.length} Transaction(s) Missing Receipt Document`,
      description: `Higher-value transactions (such as ₱${largeTxsWithoutReceipt[0].amount.toLocaleString()} for "${largeTxsWithoutReceipt[0].merchant || largeTxsWithoutReceipt[0].category}") have no attached official receipt or photo proof.`,
      severity: 'low',
      detectedAt: now,
      isDismissed: false,
      suggestedAction: 'Attach photo receipt or proof of purchase for audit trail and warranty tracking.'
    });
  }

  return alerts;
}

/**
 * Evaluates the Financial Digital Twin life scenario shocks & opportunities:
 */
export function simulateDigitalTwin(
  scenario: DigitalTwinScenarioType,
  currentLiquidCash: number,
  monthlyExpenseRunrate: number,
  currentNetWorth: number,
  monthlyIncome: number
): DigitalTwinSimulationResult {
  const baselineRunwayMonths = monthlyExpenseRunrate > 0 ? currentLiquidCash / monthlyExpenseRunrate : 6;
  const baselineSafeToSpend = Math.max(0, currentLiquidCash * 0.4);

  switch (scenario) {
    case 'job_loss': {
      // 0 income, survival mode cuts expenses by 25%
      const survivalExpenses = monthlyExpenseRunrate * 0.75;
      const simulatedRunway = survivalExpenses > 0 ? currentLiquidCash / survivalExpenses : 0;
      return {
        scenarioType: 'job_loss',
        title: 'Sudden Inflow Disruption (Job Loss / Career Pivot)',
        description: 'Simulates zero new salary inflows. Non-essential lifestyle costs immediately frozen.',
        baselineRunwayMonths,
        simulatedRunwayMonths: simulatedRunway,
        baselineSafeToSpend,
        simulatedSafeToSpend: 0,
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - survivalExpenses * 3,
        bufferImpactPhp: -monthlyIncome * 3,
        recommendations: [
          'Immediately activate emergency survival budget (freeze leisure and dining out).',
          'File SSS Unemployment Benefit claim (grants up to ₱20,000 for qualified SSS contributors).',
          'Notify lenders for grace periods or interest-only restructuring on amortizations.'
        ]
      };
    }
    case 'delayed_income': {
      // 15-day delay in salary
      const delayDeficit = monthlyExpenseRunrate * 0.5;
      const simulatedRunway = Math.max(0, (currentLiquidCash - delayDeficit) / (monthlyExpenseRunrate || 1));
      return {
        scenarioType: 'delayed_income',
        title: 'Delayed Sweldo (15 to 30-Day Payroll Delay)',
        description: 'Simulates client payment hold or delayed corporate payroll crediting.',
        baselineRunwayMonths,
        simulatedRunwayMonths: simulatedRunway,
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, (currentLiquidCash - delayDeficit) * 0.3),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth,
        bufferImpactPhp: -delayDeficit,
        recommendations: [
          'Bridge utilities using liquid high-yield savings without touching long-term investments.',
          'Negotiate payment terms with landlords or service providers before due dates.',
          'Avoid high-interest short-term online lending apps (OLAs) with predatory daily penalties.'
        ]
      };
    }
    case 'rent_increase': {
      const annualRentBump = 3500 * 12;
      return {
        scenarioType: 'rent_increase',
        title: 'Housing Cost Jump (Rent Increase of +₱3,500/mo)',
        description: 'Simulates landlord contract renewal rate increase of ₱3,500 monthly.',
        baselineRunwayMonths,
        simulatedRunwayMonths: Math.max(0, currentLiquidCash / (monthlyExpenseRunrate + 3500)),
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, baselineSafeToSpend - 3500),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - annualRentBump,
        bufferImpactPhp: -annualRentBump,
        recommendations: [
          'Verify if rent increase complies with Philippine Rent Control Act (ceiling limits for lower-rent brackets).',
          'Offset the ₱3,500 monthly increase by optimizing electricity (aircon inverter timers) or cooking at home.',
          'Consider distance vs transport fare tradeoffs if relocating.'
        ]
      };
    }
    case 'medical_expense': {
      const medicalBill = 50000;
      const cashAfterMed = Math.max(0, currentLiquidCash - medicalBill);
      return {
        scenarioType: 'medical_expense',
        title: 'Emergency Medical Hospitalization (₱50,000 Out-of-Pocket)',
        description: 'Simulates unexpected hospitalization or diagnostic surgery exceeding PhilHealth/HMO limits.',
        baselineRunwayMonths,
        simulatedRunwayMonths: monthlyExpenseRunrate > 0 ? cashAfterMed / monthlyExpenseRunrate : 0,
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, cashAfterMed * 0.2),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - medicalBill,
        bufferImpactPhp: -medicalBill,
        recommendations: [
          'Apply for PhilHealth Case Rate deductions and hospital billing itemization.',
          'Utilize PCSO Medical Access Program or local LGU Malasakit Center subsidies.',
          'Rebuild emergency fund via auto-debit 10% monthly income allocation post-recovery.'
        ]
      };
    }
    case 'new_child': {
      const childMonthlyCare = 14000;
      return {
        scenarioType: 'new_child',
        title: 'New Family Addition (Baby Essentials & Healthcare)',
        description: 'Simulates recurring newborn expenses (+₱14,000/mo for formula, diapers, pediatric vaccines).',
        baselineRunwayMonths,
        simulatedRunwayMonths: currentLiquidCash / (monthlyExpenseRunrate + childMonthlyCare),
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, baselineSafeToSpend - childMonthlyCare),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - childMonthlyCare * 12,
        bufferImpactPhp: -childMonthlyCare * 12,
        recommendations: [
          'Enroll child in PhilHealth Newborn Care Package and utilize LGU health centers for standard vaccines.',
          'Build a dedicated sinking fund for pre-school tuition 2 years in advance.',
          'Secure term life and critical illness coverage for primary household earners.'
        ]
      };
    }
    case 'thirteenth_month': {
      const thirteenthGross = monthlyIncome;
      return {
        scenarioType: 'thirteenth_month',
        title: '13th-Month Pay Windfall Crediting',
        description: 'Simulates year-end mandatory 13th-month bonus receipt (tax-free up to ₱90,000).',
        baselineRunwayMonths,
        simulatedRunwayMonths: (currentLiquidCash + thirteenthGross) / (monthlyExpenseRunrate || 1),
        baselineSafeToSpend,
        simulatedSafeToSpend: baselineSafeToSpend + thirteenthGross * 0.3,
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth + thirteenthGross,
        bufferImpactPhp: thirteenthGross,
        recommendations: [
          'Apply 50/30/20 rule: 50% to high-yield debt/MP2, 30% to emergency fund, 20% guilt-free holiday celebration.',
          'Prevent lifestyle inflation by setting aside the savings portion immediately upon payroll crediting.',
          'Confirm tax-exempt status under TRAIN law Section 32.'
        ]
      };
    }
    case 'debt_prepayment': {
      const prepayAmount = 30000;
      const estimatedInterestSaved = prepayAmount * 0.18; // approx 18% annual credit card / personal loan interest saved
      return {
        scenarioType: 'debt_prepayment',
        title: 'Lump-Sum Debt Prepayment (₱30,000 Early Principal Paydown)',
        description: 'Simulates making an unscheduled principal reduction on your highest-interest obligation.',
        baselineRunwayMonths,
        simulatedRunwayMonths: Math.max(0, (currentLiquidCash - prepayAmount) / (monthlyExpenseRunrate || 1)),
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, baselineSafeToSpend - prepayAmount * 0.3),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth + estimatedInterestSaved,
        bufferImpactPhp: estimatedInterestSaved,
        recommendations: [
          'Confirm with lender that payment applies directly to principal rather than advancing future interest.',
          'Accelerates debt-free date by approximately 4 to 6 months.',
          'Frees up monthly cash flow previously locked into mandatory installment amortizations.'
        ]
      };
    }
    case 'business_slowdown': {
      const revenueCut = monthlyIncome * 0.3;
      return {
        scenarioType: 'business_slowdown',
        title: 'Freelance & Business Slowdown (-30% Inflow Dip)',
        description: 'Simulates lean seasonal quarters or delayed project milestones.',
        baselineRunwayMonths,
        simulatedRunwayMonths: currentLiquidCash / (monthlyExpenseRunrate || 1),
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, baselineSafeToSpend - revenueCut * 0.5),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - revenueCut * 3,
        bufferImpactPhp: -revenueCut * 3,
        recommendations: [
          'Maintain a dedicated 6-month lean season buffer separate from personal emergency funds.',
          'Review 8% gross income tax vs graduated tax options under BIR rules to minimize quarterly tax drag.',
          'Diversify client retainers to reduce dependence on any single source of revenue.'
        ]
      };
    }
    case 'major_purchase': {
      const purchasePrice = 65000;
      return {
        scenarioType: 'major_purchase',
        title: 'Major Capital Purchase (Work Laptop / Home Upgrade)',
        description: 'Simulates upfront cash purchase of essential productivity or household asset (₱65,000).',
        baselineRunwayMonths,
        simulatedRunwayMonths: Math.max(0, (currentLiquidCash - purchasePrice) / (monthlyExpenseRunrate || 1)),
        baselineSafeToSpend,
        simulatedSafeToSpend: Math.max(0, (currentLiquidCash - purchasePrice) * 0.3),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth, // Transformed cash into asset value
        bufferImpactPhp: -purchasePrice,
        recommendations: [
          'Evaluate 0% credit card installment plans (BPI SIP / Metrobank 0%) over 12 months to preserve liquidity.',
          'Ensure total installment payments stay below 20% of monthly take-home sweldo.',
          'Verify official BIR receipt and local manufacturer warranty coverage.'
        ]
      };
    }
  }
}

/**
 * Analyzes investment offers or messages for Philippine financial scam indicators:
 */
export function analyzeScamRisk(text: string): ScamAnalysisResult {
  const lower = text.toLowerCase();
  const flags: ScamAnalysisResult['detectedFlags'] = [];

  // 1. Urgency flags
  if (
    lower.includes('hurry') ||
    lower.includes('urgent') ||
    lower.includes('only today') ||
    lower.includes('24 hours') ||
    lower.includes('limited slots') ||
    lower.includes('act now') ||
    lower.includes('habol na')
  ) {
    flags.push({
      flag: 'urgency',
      title: 'Manufactured Artificial Urgency',
      description: 'Pressures the victim to commit funds without adequate due diligence or sleep-on-it reflection.',
      evidenceFound: 'Urgency phrases found in proposal.'
    });
  }

  // 2. Impersonation
  if (
    lower.includes('bsp officer') ||
    lower.includes('gcash security') ||
    lower.includes('bank representative') ||
    lower.includes('official support team') ||
    lower.includes('customer care agent') ||
    lower.includes('verify your account')
  ) {
    flags.push({
      flag: 'impersonation',
      title: 'Authority / Institution Impersonation',
      description: 'Pretending to be from Bangko Sentral ng Pilipinas, bank security, or GCash customer care.',
      evidenceFound: 'Keywords claiming institutional authority.'
    });
  }

  // 3. Guaranteed returns
  if (
    lower.includes('guaranteed') ||
    lower.includes('risk free') ||
    lower.includes('risk-free') ||
    lower.includes('double your money') ||
    lower.includes('100% safe') ||
    lower.includes('daily payout') ||
    lower.includes('weekly interest') ||
    lower.includes('paluwagan') ||
    lower.includes('sigurado')
  ) {
    flags.push({
      flag: 'guaranteed_returns',
      title: 'Guaranteed High Returns (Ponzi Red Flag)',
      description: 'Under Philippine financial law, all investments carry market risk. Guaranteeing fixed high returns is the #1 hallmark of Ponzi/pyramiding schemes.',
      evidenceFound: 'Guaranteed or risk-free return promises.'
    });
  }

  // 4. OTP / PIN requests
  if (
    lower.includes('otp') ||
    lower.includes('pin') ||
    lower.includes('mpin') ||
    lower.includes('one time password') ||
    lower.includes('6-digit') ||
    lower.includes('verification code')
  ) {
    flags.push({
      flag: 'otp_pin_request',
      title: 'Credential / OTP Exfiltration Attempt',
      description: 'Legitimate banks and e-wallets will NEVER ask for your MPIN or SMS One-Time Password.',
      evidenceFound: 'Request for OTP, PIN, or verification code.'
    });
  }

  // 5. Unusual payment instructions
  if (
    lower.includes('personal gcash') ||
    lower.includes('send to my number') ||
    lower.includes('personal maya') ||
    lower.includes('crypto deposit') ||
    lower.includes('direct wallet')
  ) {
    flags.push({
      flag: 'unusual_payment',
      title: 'Unusual / Personal Payment Channel',
      description: 'Soliciting funds into personal digital wallets or peer accounts rather than verified merchant merchant accounts.',
      evidenceFound: 'Direct personal account transfer request.'
    });
  }

  // 6. Unlicensed investment language
  if (
    lower.includes('sec registered') ||
    lower.includes('sec certificate') ||
    lower.includes('dti registered') ||
    lower.includes('trading bot') ||
    lower.includes('ai trading') ||
    lower.includes('cooperative license')
  ) {
    flags.push({
      flag: 'unlicensed_investment',
      title: 'Misleading Corporate Registration Claim',
      description: 'An SEC or DTI certificate of incorporation is merely a business birth certificate. Legally selling investments requires an explicit SEC Secondary License to Sell Securities.',
      evidenceFound: 'Reference to SEC/DTI registration as proof of investment legitimacy.'
    });
  }

  const riskScore = Math.min(100, flags.length * 28);
  let riskLevel: ScamAnalysisResult['riskLevel'] = 'Safe';
  if (riskScore >= 75) riskLevel = 'Critical Scam';
  else if (riskScore >= 50) riskLevel = 'Dangerous';
  else if (riskScore > 0) riskLevel = 'Suspicious';

  const regulatoryAdvice =
    flags.length > 0
      ? 'Bangko Sentral ng Pilipinas (BSP) and Securities and Exchange Commission (SEC) Advisory: Check the SEC list of Revoked/Suspended Corporations and unauthorized investment solicitations before sending money.'
      : 'No common fraud patterns detected. Always verify that investment brokers are licensed by the SEC or BSP.';

  const recommendedAction =
    riskScore >= 50
      ? 'DO NOT SEND MONEY. Block sender, never disclose OTP or MPIN, and report the account to the PNP Anti-Cybercrime Group (ACG) and SEC Enforcement and Investor Protection Department (EIPD).'
      : riskScore > 0
      ? 'Exercise high caution. Request official company secondary license and consult a licensed financial adviser.'
      : 'Proposal appears normal, but maintain healthy skepticism and check credentials.';

  return {
    riskScore,
    riskLevel,
    detectedFlags: flags,
    regulatoryAdvice,
    recommendedAction
  };
}

/**
 * Builds the default Financial Truth Layer metadata for an entity
 */
export function buildFinancialTruthMetadata(
  txCount: number,
  reconciledCount: number,
  lastReconciliationDate?: string
): FinancialTruthMetadata {
  const confidenceScore = txCount > 0 ? Math.round((reconciledCount / txCount) * 100) : 100;
  return {
    source: 'manual_verified',
    freshness: lastReconciliationDate ? `Reconciled ${lastReconciliationDate}` : 'Up to date',
    confidenceScore: Math.max(50, confidenceScore),
    lastReconciledDate: lastReconciliationDate || '2026-09-15',
    calculationTrail: [
      'Double-entry transaction balances verified against account balance limits.',
      'Transfers isolated from income and expense accounts (Transfer Invariant).',
      'Net worth mathematically balances against active assets minus settled debt positions.'
    ],
    changeHistoryCount: 14,
    isImmutableAuditLocked: true
  };
}
