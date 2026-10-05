import React, { useState, useMemo, useEffect } from 'react';
import { X, Calculator, ShieldCheck, Check, Award, ArrowRight, Info, Sparkles, Building2, Briefcase, Plus, Minus, ChevronDown, ChevronUp, AlertCircle, HelpCircle, Calendar, Video, Landmark } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { calculateEmployeeTaxDeductions, calculateFreelanceTax, EmployeeTaxInputs } from '../utils/philippineFinances';

interface TaxCalculatorModalProps {
  isOpen: boolean;
  onClose: () => void;
}

type IncomeProfile = 'employed' | 'self_employed' | 'mixed';
type SelfEmployedType = 'freelancer' | 'affiliate' | 'commission' | 'professional' | 'business';

export const TaxCalculatorModal: React.FC<TaxCalculatorModalProps> = ({ isOpen, onClose }) => {
  const { payday, updatePayday } = useFinancial();

  // Initialize with the user's monthly estimated income (or 35,000)
  const defaultSalary = useMemo(() => {
    if (payday?.expectedIncome && payday.expectedIncome > 0) {
      return payday.cycleType === '15_30' ? payday.expectedIncome * 2 : payday.expectedIncome;
    }
    return 35000;
  }, [payday]);

  const [profile, setProfile] = useState<IncomeProfile>('employed');
  const [subType, setSubType] = useState<SelfEmployedType>('freelancer');
  const [taxRegime, setTaxRegime] = useState<'8_percent_git' | 'graduated_rates'>('8_percent_git');

  const [inputFrequency, setInputFrequency] = useState<'semi-monthly' | 'bi-weekly' | 'monthly' | 'annually'>('monthly');
  
  // Employed inputs
  const [baseSalaryStr, setBaseSalaryStr] = useState(defaultSalary.toString());
  const [taxableAllowanceStr, setTaxableAllowanceStr] = useState('');
  const [nonTaxableAllowanceStr, setNonTaxableAllowanceStr] = useState('');
  const [overtimeStr, setOvertimeStr] = useState('');
  const [nightDiffStr, setNightDiffStr] = useState('');
  
  // Self-Employed inputs
  const [revenueStr, setRevenueStr] = useState('50000');
  const [voluntarySss, setVoluntarySss] = useState(1400);
  const [voluntaryPhilhealth, setVoluntaryPhilhealth] = useState(500);
  const [voluntaryPagibig, setVoluntaryPagibig] = useState(200);

  const [monthsWorked, setMonthsWorked] = useState('12');
  const [appliedToPayday, setAppliedToPayday] = useState(false);
  const [showAdvanced, setShowAdvanced] = useState(false);

  // Sync default salary when modal opens
  useEffect(() => {
    if (isOpen) {
      setBaseSalaryStr(defaultSalary.toString());
      setInputFrequency('monthly');
      setAppliedToPayday(false);
    }
  }, [isOpen, defaultSalary]);

  const baseSalary = parseFloat(baseSalaryStr.replace(/,/g, '')) || 0;
  const taxableAllowance = parseFloat(taxableAllowanceStr.replace(/,/g, '')) || 0;
  const nonTaxableAllowance = parseFloat(nonTaxableAllowanceStr.replace(/,/g, '')) || 0;
  const overtime = parseFloat(overtimeStr.replace(/,/g, '')) || 0;
  const nightDifferential = parseFloat(nightDiffStr.replace(/,/g, '')) || 0;
  const monthsWorkedCount = parseInt(monthsWorked, 10) || 12;

  const monthlyRevenue = parseFloat(revenueStr.replace(/,/g, '')) || 0;

  // CPA & Tax Accountant calculations under Philippine TRAIN Law & 2023+ Updated Brackets
  const calculations = useMemo(() => {
    
    // Normalize frequency to monthly for inputs
    let actualMonthlySalary = baseSalary;
    if (inputFrequency === 'semi-monthly') actualMonthlySalary = baseSalary * 2;
    if (inputFrequency === 'bi-weekly') actualMonthlySalary = (baseSalary * 26) / 12;
    if (inputFrequency === 'annually') actualMonthlySalary = baseSalary / 12;

    let actualMonthlyRevenue = monthlyRevenue;
    if (inputFrequency === 'semi-monthly') actualMonthlyRevenue = monthlyRevenue * 2;
    if (inputFrequency === 'bi-weekly') actualMonthlyRevenue = (monthlyRevenue * 26) / 12;
    if (inputFrequency === 'annually') actualMonthlyRevenue = monthlyRevenue / 12;

    if (profile === 'employed') {
      if (actualMonthlySalary <= 0) {
        return {
          sss: 0, philhealth: 0, pagibig: 0, totalContributions: 0,
          taxableIncome: 0, withholdingTax: 0, netTakeHome: 0, semiMonthlyTakeHome: 0,
          thirteenthMonthGross: 0, thirteenthMonthTaxable: 0, thirteenthMonthTax: 0,
          thirteenthMonthNet: 0, isTaxExempt13th: true, grossMonthlyIncome: 0, monthlySalary: 0,
          complianceForms: []
        };
      }
      
      const empInputs: EmployeeTaxInputs = {
        inputSalary: baseSalary,
        inputFrequency,
        taxableAllowance,
        nonTaxableAllowance,
        overtime,
        nightDifferential
      };
      
      const calc = calculateEmployeeTaxDeductions(empInputs, monthsWorkedCount);
      return {
        ...calc,
        complianceForms: [
          {
            form: 'BIR Form 2316',
            name: 'Certificate of Compensation Payment',
            deadline: 'On or before Jan 31 of succeeding year',
            description: 'Provided by your employer. Typically filed via Substituted Filing.'
          }
        ]
      };
    } 
    
    if (profile === 'self_employed') {
      const annualGross = actualMonthlyRevenue * 12;
      const flTax = calculateFreelanceTax(annualGross, taxRegime);
      
      const totalContributions = voluntarySss + voluntaryPhilhealth + voluntaryPagibig;
      const monthlyTax = flTax.monthlyTaxProvision;
      const netTakeHome = Math.max(0, Math.round(actualMonthlyRevenue - monthlyTax - totalContributions));
      
      const forms = [
        {
          form: 'BIR Form 1701Q',
          name: 'Quarterly Income Tax Return',
          deadline: 'May 15 (Q1), Aug 15 (Q2), Nov 15 (Q3)',
          description: 'Declaration of quarterly earnings.'
        },
        {
          form: 'BIR Form 1701/1701A',
          name: 'Annual Income Tax Return',
          deadline: 'April 15 of next year',
          description: 'Final annual consolidation.'
        }
      ];

      if (taxRegime === 'graduated_rates') {
        forms.push({
          form: 'BIR Form 2551Q',
          name: 'Quarterly Percentage Tax',
          deadline: '25th day of month following quarter',
          description: '3% tax on gross receipts (Non-VAT).'
        });
      }

      return {
        sss: voluntarySss, philhealth: voluntaryPhilhealth, pagibig: voluntaryPagibig, totalContributions,
        taxableIncome: actualMonthlyRevenue,
        withholdingTax: Math.round(monthlyTax),
        netTakeHome,
        semiMonthlyTakeHome: Math.round(netTakeHome / 2),
        thirteenthMonthGross: 0, thirteenthMonthTaxable: 0, thirteenthMonthTax: 0, thirteenthMonthNet: 0, isTaxExempt13th: true,
        grossMonthlyIncome: actualMonthlyRevenue,
        monthlySalary: actualMonthlyRevenue,
        complianceForms: forms
      };
    }

    // mixed income earner
    if (profile === 'mixed') {
      const empInputs: EmployeeTaxInputs = {
        inputSalary: baseSalary,
        inputFrequency,
        taxableAllowance,
        nonTaxableAllowance,
        overtime,
        nightDifferential
      };
      
      // Calculate employment side
      const empCalc = calculateEmployeeTaxDeductions(empInputs, monthsWorkedCount);
      
      // Calculate business side
      // Note: In mixed income, the 250k deduction is applied to compensation first. 
      // So if 8% is chosen, it's 8% of gross receipts straight.
      const annualBizGross = actualMonthlyRevenue * 12;
      let bizMonthlyTax = 0;
      
      if (taxRegime === '8_percent_git') {
        bizMonthlyTax = (annualBizGross * 0.08) / 12;
      } else {
        // Simplified combined graduated
        // Actually, TRAIN law says you combine compensation taxable net + business taxable net and look up the table.
        // For simplicity in this UI estimator, we add the tax provisions if graduated (though it underestimates slightly).
        // Let's use a rough estimation for graduated combined:
        const combinedAnnualTaxable = (empCalc.taxableIncome * 12) + annualBizGross; // Assuming no OSD for biz here for simplicity
        const flTax = calculateFreelanceTax(combinedAnnualTaxable, 'graduated_rates');
        const combinedMonthlyTax = flTax.monthlyTaxProvision;
        bizMonthlyTax = Math.max(0, combinedMonthlyTax - empCalc.withholdingTax);
      }

      const totalMonthlyTax = empCalc.withholdingTax + bizMonthlyTax;
      // Net take home = (Emp Gross - Emp Deductions) + Biz Gross - Biz Tax
      const netTakeHome = Math.max(0, Math.round((empCalc.grossMonthlyIncome - empCalc.totalContributions - empCalc.withholdingTax) + (actualMonthlyRevenue - bizMonthlyTax)));
      
      return {
        ...empCalc,
        withholdingTax: totalMonthlyTax,
        netTakeHome,
        semiMonthlyTakeHome: Math.round(netTakeHome / 2),
        grossMonthlyIncome: empCalc.grossMonthlyIncome + actualMonthlyRevenue,
        complianceForms: [
          {
            form: 'BIR Form 2316',
            name: 'Certificate of Compensation',
            deadline: 'Jan 31',
            description: 'From employer.'
          },
          {
            form: 'BIR Form 1701',
            name: 'Annual Income Tax Return (Mixed)',
            deadline: 'April 15',
            description: 'Consolidated return for compensation and business/profession.'
          },
          {
            form: 'BIR Form 1701Q',
            name: 'Quarterly Income Tax',
            deadline: 'May 15, Aug 15, Nov 15',
            description: 'For business/professional income.'
          }
        ]
      };
    }
    
    return {
      sss: 0, philhealth: 0, pagibig: 0, totalContributions: 0,
      taxableIncome: 0, withholdingTax: 0, netTakeHome: 0, semiMonthlyTakeHome: 0,
      thirteenthMonthGross: 0, thirteenthMonthTaxable: 0, thirteenthMonthTax: 0, thirteenthMonthNet: 0, isTaxExempt13th: true, grossMonthlyIncome: 0, monthlySalary: 0,
      complianceForms: []
    };
  }, [profile, baseSalary, taxableAllowance, nonTaxableAllowance, overtime, nightDifferential, monthsWorkedCount, monthlyRevenue, taxRegime, voluntarySss, voluntaryPhilhealth, voluntaryPagibig, inputFrequency]);

  const handleApplyToPayday = () => {
    updatePayday({ expectedIncome: calculations.semiMonthlyTakeHome, cycleType: '15_30' });
    setAppliedToPayday(true);
    setTimeout(() => {
      onClose();
    }, 1500);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity cursor-pointer" onClick={onClose} />

      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col min-h-0 overflow-hidden">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-3 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
              <Landmark size={18} />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Comprehensive Tax Simulator
              </h2>
              <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] block">
                Salary, Freelance, Creator & Mixed Income
              </span>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0">
            <X size={18} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 min-h-0 overflow-y-auto space-y-4 pr-1 pb-4">
          
          {/* Income Profile Selector */}
          <div>
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-2 block">
              Primary Income Profile
            </label>
            <div className="grid grid-cols-1 gap-2">
              <button
                onClick={() => setProfile('employed')}
                className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                  profile === 'employed' 
                    ? 'bg-[#FFEEDF]/30 dark:bg-[#14100D] border-[#B03C09] dark:border-[#FF9A52]' 
                    : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029]'
                }`}
              >
                <Building2 size={16} className={profile === 'employed' ? 'text-[#B03C09] dark:text-[#FF9A52]' : 'text-[#6B6156]'} />
                <div>
                  <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Fully Employed</div>
                  <div className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">Standard corporate or full-time employee.</div>
                </div>
              </button>

              <button
                onClick={() => setProfile('self_employed')}
                className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                  profile === 'self_employed' 
                    ? 'bg-[#FFEEDF]/30 dark:bg-[#14100D] border-[#B03C09] dark:border-[#FF9A52]' 
                    : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029]'
                }`}
              >
                <Briefcase size={16} className={profile === 'self_employed' ? 'text-[#B03C09] dark:text-[#FF9A52]' : 'text-[#6B6156]'} />
                <div>
                  <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Self-Employed / Creator / Freelancer</div>
                  <div className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">Upwork, YouTube, Affiliates, Commission, Prof. Fees.</div>
                </div>
              </button>

              <button
                onClick={() => setProfile('mixed')}
                className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                  profile === 'mixed' 
                    ? 'bg-[#FFEEDF]/30 dark:bg-[#14100D] border-[#B03C09] dark:border-[#FF9A52]' 
                    : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029]'
                }`}
              >
                <Sparkles size={16} className={profile === 'mixed' ? 'text-[#B03C09] dark:text-[#FF9A52]' : 'text-[#6B6156]'} />
                <div>
                  <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Mixed Income Earner</div>
                  <div className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">Both fully employed & has side businesses/freelance.</div>
                </div>
              </button>
            </div>
          </div>

          {/* Sub-type for Self Employed */}
          {profile === 'self_employed' && (
            <div className="bg-[#FFEEDF]/20 dark:bg-[#14100D]/50 p-3 rounded-2xl border border-[#F3DFCD]/50 dark:border-[#383029]/50">
               <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1.5 block">
                  I specifically identify as a:
               </label>
               <select
                  value={subType}
                  onChange={(e) => setSubType(e.target.value as SelfEmployedType)}
                  className="w-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl px-3 py-2 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                >
                  <option value="freelancer">Freelancer / Independent Contractor</option>
                  <option value="professional">Professional (Doctor, Lawyer, CPA)</option>
                  <option value="affiliate">Content Creator / Affiliate / YouTube</option>
                  <option value="commission">Commission-based Agent (Real Estate, Insurance)</option>
                  <option value="business">Sole Proprietor (Small Business)</option>
               </select>
            </div>
          )}

          {/* Frequency & Core Inputs */}
          <div className="space-y-3 bg-[#FFEEDF]/20 dark:bg-[#14100D]/50 p-3 rounded-2xl border border-[#F3DFCD]/50 dark:border-[#383029]/50">
            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
                Input Frequency
              </label>
              <select
                value={inputFrequency}
                onChange={(e) => setInputFrequency(e.target.value as any)}
                className="w-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl px-3 py-2 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              >
                <option value="monthly">Monthly Input</option>
                <option value="semi-monthly">Semi-Monthly Input (Every 15th/30th)</option>
                <option value="bi-weekly">Bi-Weekly Input (Every 2 weeks)</option>
                <option value="annually">Annual Input</option>
              </select>
            </div>

            {(profile === 'employed' || profile === 'mixed') && (
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Base Salary (Gross)
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={baseSalaryStr}
                    onChange={(e) => setBaseSalaryStr(e.target.value)}
                    className="w-full pl-7 pr-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-sm font-extrabold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
            )}

            {(profile === 'self_employed' || profile === 'mixed') && (
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  {profile === 'mixed' ? 'Additional Side/Business Revenue (Gross)' : 'Estimated Revenue (Gross)'}
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={revenueStr}
                    onChange={(e) => setRevenueStr(e.target.value)}
                    className="w-full pl-7 pr-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-sm font-extrabold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
            )}

            {/* Tax Regime Selector for Self-Employed/Mixed */}
            {(profile === 'self_employed' || profile === 'mixed') && (
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1.5 block">
                  Tax Regime for Business/Profession
                </label>
                <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
                  <button
                    type="button"
                    onClick={() => setTaxRegime('8_percent_git')}
                    className={`flex-1 py-1.5 px-2 text-[11px] font-bold rounded-lg transition-all ${
                      taxRegime === '8_percent_git' ? 'bg-[#B03C09] text-white shadow-xs' : 'text-[#6B6156] dark:text-[#AC9E92]'
                    }`}
                  >
                    8% Flat Rate
                  </button>
                  <button
                    type="button"
                    onClick={() => setTaxRegime('graduated_rates')}
                    className={`flex-1 py-1.5 px-2 text-[11px] font-bold rounded-lg transition-all ${
                      taxRegime === 'graduated_rates' ? 'bg-[#16643F] text-white shadow-xs' : 'text-[#6B6156] dark:text-[#AC9E92]'
                    }`}
                  >
                    Graduated Rates
                  </button>
                </div>
                {taxRegime === '8_percent_git' && profile === 'mixed' && (
                  <p className="text-[9px] text-[#B03C09] mt-2">
                    *For Mixed Income Earner under 8%, the ₱250k deduction is applied to your compensation income. Business revenue is taxed at a flat 8%.
                  </p>
                )}
              </div>
            )}
            
            {/* Advanced Options for Employed */}
            {(profile === 'employed' || profile === 'mixed') && (
              <div className="pt-2">
                <button
                  type="button"
                  onClick={() => setShowAdvanced(!showAdvanced)}
                  className="flex items-center gap-1.5 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline"
                >
                  {showAdvanced ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                  {showAdvanced ? 'Hide Advanced Options' : 'Show Advanced Allowances (Non-Taxable, etc.)'}
                </button>

                {showAdvanced && (
                  <div className="mt-3 space-y-3 pt-3 border-t border-[#F3DFCD]/50 dark:border-[#383029]/50">
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="text-[9px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block uppercase">Taxable Allowance</label>
                        <input type="number" value={taxableAllowanceStr} onChange={(e) => setTaxableAllowanceStr(e.target.value)} placeholder="0" className="w-full px-2.5 py-1.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]" />
                      </div>
                      <div>
                        <label className="text-[9px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block uppercase">De Minimis (Non-Tax)</label>
                        <input type="number" value={nonTaxableAllowanceStr} onChange={(e) => setNonTaxableAllowanceStr(e.target.value)} placeholder="0" className="w-full px-2.5 py-1.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]" />
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Results Summary Hero */}
          <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-4 shadow-xs">
            <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
              <Calculator size={14} className="text-[#16643F] dark:text-[#5FCB8E]" /> Monthly Breakdown
            </h3>
            
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] space-y-3 text-xs">
              <div className="flex justify-between items-center pt-1">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">Gross Total Income</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(calculations.grossMonthlyIncome)}</span>
              </div>
              <div className="flex justify-between items-center pt-3">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1">Income Tax Provision <Info size={10} className="opacity-50" /></span>
                <span className="font-bold text-rose-700 dark:text-rose-500">-{formatPeso(calculations.withholdingTax)}</span>
              </div>
              <div className="flex justify-between items-center pt-3">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">SSS/PHIC/HDMF {profile === 'self_employed' ? '(Voluntary)' : '(Mandatory)'}</span>
                <span className="font-bold text-rose-700 dark:text-rose-500">-{formatPeso(calculations.totalContributions)}</span>
              </div>
              
              <div className="pt-4 mt-2 border-t-2 border-[#F3DFCD] dark:border-[#383029] flex justify-between items-center">
                <span className="font-black text-[#15120F] dark:text-[#F6EFE8] text-sm">Net Take-Home</span>
                <span className="font-black text-lg text-[#16643F] dark:text-[#5FCB8E]">{formatPeso(calculations.netTakeHome)}</span>
              </div>
            </div>
            
            {(profile === 'employed' || profile === 'mixed') && (
              <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/10 rounded-xl border border-blue-100 dark:border-blue-900/30">
                <div className="flex items-center gap-2 mb-2">
                  <Award size={14} className="text-blue-600 dark:text-blue-400" />
                  <span className="text-xs font-bold text-blue-900 dark:text-blue-300">13th Month Pay (Annual)</span>
                </div>
                <div className="flex justify-between items-center text-xs">
                  <span className="text-blue-800 dark:text-blue-400/80">Estimated Bonus</span>
                  <span className="font-bold text-blue-900 dark:text-blue-300">
                    {formatPeso(calculations.thirteenthMonthGross)}
                  </span>
                </div>
                {!calculations.isTaxExempt13th && (
                  <p className="text-[9px] text-rose-600 dark:text-rose-400 mt-1.5">
                    *Exceeds ₱90k threshold. Approx {formatPeso(calculations.thirteenthMonthTax)} tax withheld.
                  </p>
                )}
              </div>
            )}

            <button
              onClick={handleApplyToPayday}
              className={`w-full py-3.5 rounded-xl text-sm font-bold flex items-center justify-center gap-2 transition-all ${
                appliedToPayday
                  ? 'bg-[#16643F] text-white shadow-md'
                  : 'bg-[#B03C09] hover:bg-[#8e3007] text-white shadow-md hover:shadow-lg'
              }`}
            >
              {appliedToPayday ? (
                <><Check size={16} /> Applied to Sweldo Planner</>
              ) : (
                <>Use {formatPeso(calculations.semiMonthlyTakeHome)} for Sweldo Planner <ArrowRight size={16} /></>
              )}
            </button>
          </div>

          {/* BIR Compliance Calendar */}
          {calculations.complianceForms.length > 0 && (
            <div className="space-y-2">
              <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5 px-1">
                <Calendar size={14} className="text-[#B03C09] dark:text-[#FF9A52]" /> Required Tax Forms & Filing
              </h3>
              
              <div className="space-y-2">
                {calculations.complianceForms.map((form, idx) => (
                  <div key={idx} className="p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs flex items-start gap-3">
                    <div className="w-8 h-8 rounded-full bg-[#FFEEDF]/50 dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 border border-[#F3DFCD] dark:border-[#383029]">
                      <ShieldCheck size={14} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between items-start mb-0.5">
                        <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">{form.form}</h4>
                      </div>
                      <p className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mb-1">
                        Due: {form.deadline}
                      </p>
                      <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                        {form.description}
                      </p>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-3 p-3 rounded-xl bg-slate-50 dark:bg-slate-900/30 border border-slate-200 dark:border-slate-800 flex items-start gap-2.5">
                <AlertCircle size={16} className="text-slate-500 dark:text-slate-400 shrink-0 mt-0.5" />
                <div className="flex flex-col gap-1.5">
                  <p className="text-[10px] text-slate-700 dark:text-slate-300 leading-relaxed">
                    <strong>Disclaimer:</strong> This is an estimation tool, not a replacement for professional advice from accountants or CPAs. Deadlines reflect EOPT updates (RA 11976).
                  </p>
                  <a 
                    href="https://www.bir.gov.ph" 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline"
                  >
                    Visit Official BIR Website
                  </a>
                </div>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
};
