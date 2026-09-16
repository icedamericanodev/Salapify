import React, { useState, useMemo, useEffect } from 'react';
import { X, Calculator, ShieldCheck, Check, Award, ArrowRight, Info, Sparkles, Building2, Briefcase } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import {
  calculateEmployeeTaxDeductions,
  calculateFreelanceTax,
} from '../utils/philippineFinances';

interface TaxCalculatorModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const TaxCalculatorModal: React.FC<TaxCalculatorModalProps> = ({ isOpen, onClose }) => {
  const { payday, updatePayday } = useFinancial();

  // Initialize with the user's monthly estimated income (or 35,000)
  const defaultSalary = useMemo(() => {
    if (payday?.expectedIncome && payday.expectedIncome > 0) {
      return payday.cycleType === '15_30' ? payday.expectedIncome * 2 : payday.expectedIncome;
    }
    return 35000;
  }, [payday]);

  const [monthlySalaryStr, setMonthlySalaryStr] = useState(defaultSalary.toString());
  const [employmentType, setEmploymentType] = useState<'employed' | 'freelancer'>('employed');
  const [monthsWorked, setMonthsWorked] = useState('12');
  const [appliedToPayday, setAppliedToPayday] = useState(false);

  // Sync default salary when modal opens
  useEffect(() => {
    if (isOpen) {
      setMonthlySalaryStr(defaultSalary.toString());
      setAppliedToPayday(false);
    }
  }, [isOpen, defaultSalary]);

  const monthlySalary = useMemo(() => {
    const parsed = parseFloat(monthlySalaryStr.replace(/,/g, ''));
    return isNaN(parsed) || parsed < 0 ? 0 : parsed;
  }, [monthlySalaryStr]);

  const monthsWorkedCount = useMemo(() => {
    const m = parseInt(monthsWorked, 10);
    return isNaN(m) || m < 1 ? 12 : Math.min(12, m);
  }, [monthsWorked]);

  // CPA & Tax Accountant calculations under Philippine TRAIN Law & 2023+ Updated Brackets
  const calculations = useMemo(() => {
    if (monthlySalary <= 0) {
      return {
        sss: 0,
        philhealth: 0,
        pagibig: 0,
        totalContributions: 0,
        taxableIncome: 0,
        withholdingTax: 0,
        netTakeHome: 0,
        semiMonthlyTakeHome: 0,
        thirteenthMonthGross: 0,
        thirteenthMonthTaxable: 0,
        thirteenthMonthTax: 0,
        thirteenthMonthNet: 0,
        isTaxExempt13th: true,
      };
    }

    if (employmentType === 'freelancer') {
      const flTax = calculateFreelanceTax(monthlySalary * 12, '8_percent_git');
      // Voluntary contributions standard tiers
      const sss = 1400; // Voluntary basic MSC tier
      const philhealth = 500; // Direct contributor baseline
      const pagibig = 200; // Regular mandatory savings
      const totalContributions = sss + philhealth + pagibig;
      const monthlyTax = flTax.monthlyTaxProvision;
      const netTakeHome = Math.max(0, Math.round(monthlySalary - monthlyTax - totalContributions));

      return {
        sss,
        philhealth,
        pagibig,
        totalContributions,
        taxableIncome: monthlySalary,
        withholdingTax: Math.round(monthlyTax),
        netTakeHome,
        semiMonthlyTakeHome: Math.round(netTakeHome / 2),
        thirteenthMonthGross: 0,
        thirteenthMonthTaxable: 0,
        thirteenthMonthTax: 0,
        thirteenthMonthNet: 0,
        isTaxExempt13th: true,
      };
    }

    // Corporate / Employed Deductions (Employee Share)
    const emp = calculateEmployeeTaxDeductions(monthlySalary, monthsWorkedCount);
    return {
      sss: emp.sss,
      philhealth: emp.philhealth,
      pagibig: emp.pagibig,
      totalContributions: emp.totalContributions,
      taxableIncome: emp.taxableIncome,
      withholdingTax: emp.withholdingTax,
      netTakeHome: emp.netTakeHome,
      semiMonthlyTakeHome: emp.semiMonthlyTakeHome,
      thirteenthMonthGross: emp.thirteenthMonthGross,
      thirteenthMonthTaxable: emp.thirteenthMonthTaxable,
      thirteenthMonthTax: emp.thirteenthMonthTax,
      thirteenthMonthNet: emp.thirteenthMonthNet,
      isTaxExempt13th: emp.isTaxExempt13th,
    };
  }, [monthlySalary, employmentType, monthsWorkedCount]);

  if (!isOpen) return null;

  const handleApplyToPayday = () => {
    if (calculations.netTakeHome <= 0) return;
    const cutoffAmount = payday.cycleType === '15_30' ? calculations.semiMonthlyTakeHome : calculations.netTakeHome;
    updatePayday({
      expectedIncome: cutoffAmount,
    });
    setAppliedToPayday(true);
    setTimeout(() => setAppliedToPayday(false), 2500);
  };

  const salaryPresets = [25000, 35000, 50000, 75000, 100000];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity cursor-pointer"
        onClick={onClose}
      />

      {/* Modal Dialog */}
      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col min-h-0 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-3 gap-2 shrink-0">
          <div className="flex items-center gap-2.5 min-w-0 flex-1">
            <div className="w-9 h-9 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
              <Calculator size={18} />
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] truncate">
                Philippine Tax & Take-Home
              </h2>
              <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate block">
                TRAIN Law, SSS, PhilHealth, Pag-IBIG & 13th Month
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 min-h-0 overflow-y-auto space-y-4 pr-1">
          {/* Segment: Employed vs Freelancer */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setEmploymentType('employed')}
              className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                employmentType === 'employed'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              <Building2 size={14} />
              <span>Corporate / Employed</span>
            </button>
            <button
              type="button"
              onClick={() => setEmploymentType('freelancer')}
              className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                employmentType === 'freelancer'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              <Briefcase size={14} />
              <span>Freelancer (8% BIR)</span>
            </button>
          </div>

          {/* Salary Input & Presets */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Monthly Gross Salary (₱)
              </label>
              <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                {employmentType === 'employed' ? 'Basic Monthly Pay' : 'Gross Monthly Invoicing'}
              </span>
            </div>

            <div className="relative">
              <span className="absolute left-3.5 top-1/2 -translate-y-1/2 font-extrabold text-sm text-[#6B6156] dark:text-[#AC9E92]">
                ₱
              </span>
              <input
                type="number"
                step="500"
                value={monthlySalaryStr}
                onChange={(e) => setMonthlySalaryStr(e.target.value)}
                placeholder="35000"
                className="w-full pl-8 pr-3 py-2.5 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              />
            </div>

            {/* Quick Presets */}
            <div className="flex items-center gap-1.5 pt-1 overflow-x-auto">
              <span className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] shrink-0">
                Presets:
              </span>
              {salaryPresets.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => setMonthlySalaryStr(preset.toString())}
                  className={`px-2 py-0.5 rounded-lg text-[10px] font-bold border transition-colors cursor-pointer whitespace-nowrap ${
                    monthlySalary === preset
                      ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D]'
                      : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC]'
                  }`}
                >
                  ₱{(preset / 1000).toFixed(0)}k
                </button>
              ))}
            </div>
          </div>

          {/* Results Summary Hero */}
          <div className="p-4 rounded-2xl bg-[#FFEEDF]/50 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                Estimated Monthly Net Take-Home
              </span>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#16643F]/10 dark:bg-[#5FCB8E]/15 text-[#16643F] dark:text-[#5FCB8E]">
                In Your Pocket
              </span>
            </div>

            <div className="text-3xl font-black text-[#16643F] dark:text-[#5FCB8E] tabular-nums">
              {formatPeso(calculations.netTakeHome)}
            </div>

            <div className="flex items-center justify-between text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] pt-1 border-t border-[#F3DFCD] dark:border-[#383029]">
              <span>Semi-monthly (15th &amp; 30th sweldo):</span>
              <strong className="text-[#15120F] dark:text-[#F6EFE8]">
                {formatPeso(calculations.semiMonthlyTakeHome)} / cutoff
              </strong>
            </div>

            {/* Sync with payday button */}
            <button
              type="button"
              onClick={handleApplyToPayday}
              className={`w-full py-2 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer shadow-xs ${
                appliedToPayday
                  ? 'bg-[#16643F] text-white'
                  : 'bg-white dark:bg-[#27201A] border border-[#B03C09] dark:border-[#FF9A52] text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#FFEEDF]/50'
              }`}
            >
              {appliedToPayday ? (
                <>
                  <Check size={14} />
                  <span>Synced to Payday Setup ({formatPeso(payday.cycleType === '15_30' ? calculations.semiMonthlyTakeHome : calculations.netTakeHome)})</span>
                </>
              ) : (
                <>
                  <Sparkles size={14} />
                  <span>Use as Expected Payday Income</span>
                </>
              )}
            </button>
          </div>

          {/* Breakdown Table */}
          <div className="space-y-1.5">
            <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] px-1">
              Monthly Deductions &amp; Contributions Breakdown
            </h3>

            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-3 divide-y divide-[#F3DFCD] dark:divide-[#383029] space-y-2 text-xs">
              <div className="flex justify-between items-center pt-1">
                <div>
                  <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC] block">
                    SSS Contribution
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    {employmentType === 'employed' ? '4.5% Employee regular share' : 'Voluntary regular MSC tier'}
                  </span>
                </div>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                  {formatPeso(calculations.sss)}
                </span>
              </div>

              <div className="flex justify-between items-center pt-2">
                <div>
                  <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC] block">
                    PhilHealth Contribution
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    {employmentType === 'employed' ? '2.5% Employee share (5% total rate)' : 'Direct contributor baseline'}
                  </span>
                </div>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                  {formatPeso(calculations.philhealth)}
                </span>
              </div>

              <div className="flex justify-between items-center pt-2">
                <div>
                  <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC] block">
                    Pag-IBIG Regular Savings
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    Mandatory employee monthly savings
                  </span>
                </div>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                  {formatPeso(calculations.pagibig)}
                </span>
              </div>

              <div className="flex justify-between items-center pt-2">
                <div>
                  <span className="font-medium text-[#B03C09] dark:text-[#FF9A52] block">
                    Withholding Income Tax (BIR)
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    {employmentType === 'employed'
                      ? calculations.taxableIncome <= 20833
                        ? 'Tax Exempt under TRAIN Law (<= ₱20,833)'
                        : 'Graduated TRAIN monthly tax table'
                      : '8% Optional Gross Tax (> ₱250k annual)'}
                  </span>
                </div>
                <span className="font-extrabold text-[#B03C09] dark:text-[#FF9A52] tabular-nums">
                  {formatPeso(calculations.withholdingTax)}
                </span>
              </div>

              <div className="flex justify-between items-center pt-2 font-bold">
                <span className="text-[#15120F] dark:text-[#F6EFE8]">Total Monthly Deductions</span>
                <span className="text-[#B03C09] dark:text-[#FF9A52] tabular-nums">
                  {formatPeso(calculations.totalContributions + calculations.withholdingTax)}
                </span>
              </div>
            </div>
          </div>

          {/* 13th Month Pay Card */}
          {employmentType === 'employed' ? (
            <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5 text-[#16643F] dark:text-[#5FCB8E] font-bold text-xs">
                  <Award size={16} />
                  <span>13th Month Pay Calculator</span>
                </div>
                <div className="flex items-center gap-1 text-[11px] text-[#5A5148] dark:text-[#C6B8AC]">
                  <span>Tenure:</span>
                  <select
                    value={monthsWorked}
                    onChange={(e) => setMonthsWorked(e.target.value)}
                    className="p-1 rounded-lg bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8]"
                  >
                    {[12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1].map((m) => (
                      <option key={m} value={m}>
                        {m} {m === 1 ? 'Month' : 'Months'}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]">
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                    Expected 13th Month Gross
                  </span>
                  <span className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                    {formatPeso(calculations.thirteenthMonthGross)}
                  </span>
                </div>

                <div className="p-2.5 rounded-xl bg-[#16643F]/10 dark:bg-[#5FCB8E]/15">
                  <span className="text-[10px] text-[#16643F] dark:text-[#5FCB8E] font-semibold block">
                    Net 13th Month Take-Home
                  </span>
                  <span className="text-sm font-black text-[#16643F] dark:text-[#5FCB8E] tabular-nums">
                    {formatPeso(calculations.thirteenthMonthNet)}
                  </span>
                </div>
              </div>

              <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                {calculations.isTaxExempt13th ? (
                  <span className="text-[#16643F] dark:text-[#5FCB8E] font-semibold flex items-center gap-1">
                    <Check size={13} />
                    <span>100% Tax-Exempt under the ₱90,000 threshold (TRAIN Law &amp; PD 851).</span>
                  </span>
                ) : (
                  <span className="text-[#B03C09] dark:text-[#FF9A52] font-semibold">
                    The portion exceeding ₱90,000 ({formatPeso(calculations.thirteenthMonthTaxable)}) is subject to standard tax ({formatPeso(calculations.thirteenthMonthTax)}).
                  </span>
                )}
              </p>
            </div>
          ) : (
            <div className="p-3.5 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-1.5">
              <div className="flex items-center gap-1.5 text-amber-700 dark:text-amber-400 font-bold text-xs">
                <Info size={15} />
                <span>Freelancer &amp; Contractor Tax Note</span>
              </div>
              <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Self-employed professionals and independent contractors are not statutory employees under DOLE, hence 13th-month pay is not mandated. The 8% optional gross tax applies on gross sales in excess of ₱250,000.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
