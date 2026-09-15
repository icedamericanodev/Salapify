import React, { useState, useMemo } from 'react';
import { X, Calculator, ShieldCheck, HelpCircle, Check, DollarSign, Award } from 'lucide-react';
import { formatPeso } from '../utils/format';

interface TaxCalculatorModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const TaxCalculatorModal: React.FC<TaxCalculatorModalProps> = ({ isOpen, onClose }) => {
  const [monthlySalaryStr, setMonthlySalaryStr] = useState('35000');
  const [employmentType, setEmploymentType] = useState<'employed' | 'freelancer'>('employed');

  if (!isOpen) return null;

  const monthlySalary = parseFloat(monthlySalaryStr) || 0;

  // CPA & Tax Accountant calculations under Philippine TRAIN Law
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
        thirteenthMonthPay: 0,
        thirteenthMonthTax: 0,
      };
    }

    if (employmentType === 'freelancer') {
      // 8% optional gross income tax on gross sales exceeding 250k annual threshold
      const annualGross = monthlySalary * 12;
      const annualTaxable = Math.max(0, annualGross - 250000);
      const annualTax = annualTaxable * 0.08;
      const monthlyTax = annualTax / 12;

      return {
        sss: 1400, // Voluntary basic tier
        philhealth: 500, // Direct contributor minimum
        pagibig: 200, // Regular savings
        totalContributions: 2100,
        taxableIncome: monthlySalary,
        withholdingTax: Math.round(monthlyTax),
        netTakeHome: Math.round(monthlySalary - monthlyTax - 2100),
        thirteenthMonthPay: 0,
        thirteenthMonthTax: 0,
      };
    }

    // Employed: Mandatory deductions (Employee share)
    // SSS employee share ~ 4.5% of Monthly Salary Credit capped at MSC 30,000 (~1,350 max regular + WISP)
    const sss = Math.min(1350, Math.round(monthlySalary * 0.045));

    // PhilHealth: 5% premium split equally (2.5% employee share), capped at 100,000 ceiling
    const philhealthBase = Math.min(100000, Math.max(10000, monthlySalary));
    const philhealth = Math.round(philhealthBase * 0.025);

    // Pag-IBIG: Employee share capped at 200 PHP for standard salary
    const pagibig = 200;

    const totalContributions = sss + philhealth + pagibig;
    const taxableIncome = Math.max(0, monthlySalary - totalContributions);

    // TRAIN Law graduated monthly brackets:
    // Up to 20,833: 0%
    // 20,833 - 33,333: 15% of excess over 20,833
    // 33,333 - 66,667: 1,875 + 20% of excess over 33,333
    // 66,667 - 166,667: 8,541.80 + 25% of excess over 66,667
    // 166,667 - 666,667: 33,541.80 + 30% of excess over 166,667
    let withholdingTax = 0;
    if (taxableIncome <= 20833) {
      withholdingTax = 0;
    } else if (taxableIncome <= 33333) {
      withholdingTax = (taxableIncome - 20833) * 0.15;
    } else if (taxableIncome <= 66667) {
      withholdingTax = 1875 + (taxableIncome - 33333) * 0.20;
    } else if (taxableIncome <= 166667) {
      withholdingTax = 8541.80 + (taxableIncome - 66667) * 0.25;
    } else {
      withholdingTax = 33541.80 + (taxableIncome - 166667) * 0.30;
    }

    const netTakeHome = monthlySalary - totalContributions - withholdingTax;

    // 13th Month Pay: 1 month basic salary; exempt up to 90,000 PHP under TRAIN Law
    const thirteenthMonthPay = monthlySalary;
    const thirteenthMonthTaxable = Math.max(0, thirteenthMonthPay - 90000);
    const thirteenthMonthTax = thirteenthMonthTaxable > 0 ? thirteenthMonthTaxable * 0.20 : 0;

    return {
      sss,
      philhealth,
      pagibig,
      totalContributions,
      taxableIncome: Math.round(taxableIncome),
      withholdingTax: Math.round(withholdingTax),
      netTakeHome: Math.round(netTakeHome),
      thirteenthMonthPay,
      thirteenthMonthTax: Math.round(thirteenthMonthTax),
    };
  }, [monthlySalary, employmentType]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52]">
              <Calculator size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Philippine Tax & Take-Home
              </h2>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                TRAIN Law & CPA Audit Guidelines
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable content */}
        <div className="overflow-y-auto space-y-4 pr-1">
          {/* Segment: Employed vs Freelancer */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setEmploymentType('employed')}
              className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                employmentType === 'employed'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              Corporate / Employed
            </button>
            <button
              type="button"
              onClick={() => setEmploymentType('freelancer')}
              className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                employmentType === 'freelancer'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              Freelancer (8% BIR Tax)
            </button>
          </div>

          {/* Salary Input */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Monthly Gross Rate (₱)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-sm text-[#6B6156] dark:text-[#AC9E92]">
                ₱
              </span>
              <input
                type="number"
                step="500"
                value={monthlySalaryStr}
                onChange={(e) => setMonthlySalaryStr(e.target.value)}
                placeholder="35000"
                className="w-full pl-8 pr-3 py-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              />
            </div>
          </div>

          {/* Results Card */}
          <div className="p-4 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
              Estimated Net Take-Home (Per Month)
            </span>
            <div className="text-3xl font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
              {formatPeso(calculations.netTakeHome)}
            </div>
            <div className="text-[11px] font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
              Semi-monthly payout: <strong className="text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(calculations.netTakeHome / 2)}</strong> per 15th & 30th sweldo
            </div>
          </div>

          {/* Breakdown Rows */}
          <div className="space-y-2 text-xs">
            <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] px-1">
              Monthly Deductions Breakdown
            </h3>

            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl p-3 divide-y divide-[#F3DFCD] dark:divide-[#383029] space-y-2">
              <div className="flex justify-between items-center pt-1">
                <span className="text-[#5A5148] dark:text-[#C6B8AC]">SSS Contribution</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(calculations.sss)}
                </span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="text-[#5A5148] dark:text-[#C6B8AC]">PhilHealth Contribution</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(calculations.philhealth)}
                </span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="text-[#5A5148] dark:text-[#C6B8AC]">Pag-IBIG Contribution</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(calculations.pagibig)}
                </span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="text-[#5A5148] dark:text-[#C6B8AC]">Withholding Income Tax</span>
                <span className="font-bold text-[#B03C09] dark:text-[#FF9A52]">
                  {formatPeso(calculations.withholdingTax)}
                </span>
              </div>
            </div>
          </div>

          {/* 13th Month Pay Rule Card */}
          {employmentType === 'employed' && (
            <div className="p-3.5 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-1.5">
              <div className="flex items-center gap-1.5 text-[#16643F] dark:text-[#5FCB8E] font-bold text-xs">
                <Award size={15} /> 13th Month Pay Status
              </div>
              <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Expected 13th month: <strong className="text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(calculations.thirteenthMonthPay)}</strong>.
                {calculations.thirteenthMonthPay <= 90000 ? (
                  <span className="block text-[#16643F] dark:text-[#5FCB8E] font-semibold mt-0.5">
                    100% Tax-Exempt under the ₱90,000 TRAIN law threshold.
                  </span>
                ) : (
                  <span className="block text-[#B03C09] dark:text-[#FF9A52] font-semibold mt-0.5">
                    Portion exceeding ₱90,000 ({formatPeso(calculations.thirteenthMonthPay - 90000)}) is subject to tax ({formatPeso(calculations.thirteenthMonthTax)}).
                  </span>
                )}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
