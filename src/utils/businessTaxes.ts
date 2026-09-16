export type EntityType = 'sole_prop' | 'partnership';
export type TaxRegime = '8_percent' | 'graduated_osd' | 'graduated_itemized' | 'corporate_rcit';
export type VatStatus = 'non_vat' | 'vat';

export interface BusinessFinancials {
  revenue: number;
  cogs: number;
  opex: number;
}

export interface ComplianceForm {
  form: string;
  name: string;
  deadline: string;
  frequency: 'Monthly' | 'Quarterly' | 'Annually';
  description: string;
}

export interface BusinessTaxResult {
  grossProfit: number;
  netTaxableIncome: number;
  incomeTax: number;
  businessTax: number; // VAT or Percentage Tax
  totalTax: number;
  netIncome: number;
  effectiveTaxRate: number;
  complianceForms: ComplianceForm[];
}

export function calculateBusinessTax(
  entity: EntityType,
  financials: BusinessFinancials,
  vatStatus: VatStatus,
  regime: TaxRegime
): BusinessTaxResult {
  const { revenue, cogs, opex } = financials;
  
  let grossProfit = Math.max(0, revenue - cogs);
  let netTaxableIncome = 0;
  let incomeTax = 0;
  let businessTax = 0;
  
  // 1. Calculate Business Tax (Percentage Tax or VAT)
  // Note: 8% GIT replaces percentage tax for sole props.
  if (vatStatus === 'vat') {
    // Simplified: VAT output minus VAT input. Here we just show the output VAT 12% 
    // on value added, but traditionally it's billed to customer. 
    // For cash flow perspective, we'll estimate net VAT payable as 12% of Gross Profit 
    // (assuming COGS has input VAT). Realistically, OPEX also has input VAT.
    // To keep it standard, we'll just show 0 as expense since VAT is pass-through, 
    // OR we just calculate 12% of Revenue as Output VAT to monitor.
    // Let's set businessTax to 0 in Net Income calc, but we can compute it for info.
    businessTax = 0; // VAT is pass-through, doesn't strictly reduce net income in a perfect pass-through model.
  } else {
    // Non-VAT Percentage Tax is 3% of Gross Revenue (Sales)
    if (regime !== '8_percent') {
      businessTax = revenue * 0.03;
    }
  }

  // 2. Calculate Income Tax
  if (entity === 'sole_prop') {
    if (regime === '8_percent') {
      // 8% on Gross Sales in excess of 250k. Replaces Income and Percentage Tax.
      // (If derived solely from business. If mixed income, the 250k is not deducted here).
      // Assuming purely business:
      const taxableBase = Math.max(0, revenue - 250000);
      incomeTax = taxableBase * 0.08;
      netTaxableIncome = taxableBase;
    } else {
      // Graduated
      if (regime === 'graduated_osd') {
        // Optional Standard Deduction: 40% of Gross Sales
        netTaxableIncome = revenue - (revenue * 0.40);
      } else {
        // Itemized
        // For tax purposes, Percentage Tax is a deductible expense
        netTaxableIncome = Math.max(0, grossProfit - opex - businessTax);
      }
      
      // TRAIN Law Graduated Table (2023 onwards)
      if (netTaxableIncome <= 250000) incomeTax = 0;
      else if (netTaxableIncome <= 400000) incomeTax = (netTaxableIncome - 250000) * 0.15;
      else if (netTaxableIncome <= 800000) incomeTax = 22500 + (netTaxableIncome - 400000) * 0.20;
      else if (netTaxableIncome <= 2000000) incomeTax = 102500 + (netTaxableIncome - 800000) * 0.25;
      else if (netTaxableIncome <= 8000000) incomeTax = 402500 + (netTaxableIncome - 2000000) * 0.30;
      else incomeTax = 2202500 + (netTaxableIncome - 8000000) * 0.35;
    }
  } else if (entity === 'partnership') {
    // Partnership (General) treated as Corporation for tax.
    // Using CREATE Law standard MSME rate of 20% 
    // (Assuming Net Taxable < 5M and Assets < 100M).
    if (regime === 'graduated_osd') {
      // OSD for Corp/Partnership is 40% of Gross Income (Gross Profit)
      netTaxableIncome = grossProfit - (grossProfit * 0.40);
    } else {
      netTaxableIncome = Math.max(0, grossProfit - opex - businessTax);
    }
    incomeTax = netTaxableIncome * 0.20;
  }

  // Finalize computations
  const totalTax = incomeTax + businessTax;
  // If Itemized or RCIT, net income is Revenue - COGS - OPEX - Taxes
  // If OSD or 8%, real net cash flow is Revenue - COGS - OPEX - Taxes
  const netIncome = revenue - cogs - opex - totalTax;
  const effectiveTaxRate = revenue > 0 ? (totalTax / revenue) * 100 : 0;

  // 3. Generate Compliance Forms (BIR Deadlines)
  const forms: ComplianceForm[] = [];
  
  if (entity === 'sole_prop') {
    forms.push({
      form: 'BIR Form 1701Q',
      name: 'Quarterly Income Tax Return',
      deadline: 'May 15, Aug 15, Nov 15',
      frequency: 'Quarterly',
      description: 'Declaration of quarterly income and tax dues.'
    });
    forms.push({
      form: 'BIR Form 1701/1701A',
      name: 'Annual Income Tax Return',
      deadline: 'April 15 of next year',
      frequency: 'Annually',
      description: 'Final annual consolidation of income.'
    });
  } else {
    forms.push({
      form: 'BIR Form 1702Q',
      name: 'Quarterly Corporate Income Tax',
      deadline: '60 days after the end of quarter',
      frequency: 'Quarterly',
      description: 'Declaration of partnership/corporate quarterly income.'
    });
    forms.push({
      form: 'BIR Form 1702-RT/EX',
      name: 'Annual Corporate Income Tax',
      deadline: '105 days after the fiscal year end',
      frequency: 'Annually',
      description: 'Final annual consolidation for the partnership.'
    });
  }

  if (vatStatus === 'vat') {
    forms.push({
      form: 'BIR Form 2550Q',
      name: 'Quarterly Value-Added Tax Return',
      deadline: '25th day of the month following the quarter',
      frequency: 'Quarterly',
      description: 'Summary of Output VAT vs Input VAT.'
    });
  } else {
    if (regime !== '8_percent') {
      forms.push({
        form: 'BIR Form 2551Q',
        name: 'Quarterly Percentage Tax',
        deadline: '25th day of the month following the quarter',
        frequency: 'Quarterly',
        description: '3% tax on gross sales/receipts.'
      });
    }
  }
  
  // Note: Annual Registration Fee (BIR Form 0605) was repealed under the EOPT Law (RA 11976).

  return {
    grossProfit,
    netTaxableIncome,
    incomeTax,
    businessTax,
    totalTax,
    netIncome,
    effectiveTaxRate,
    complianceForms: forms
  };
}
