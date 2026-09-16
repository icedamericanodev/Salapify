import React from 'react';
import { Calculator, Briefcase, Calculator as CalcIcon, DollarSign, Building, PiggyBank, Target, Landmark, TrendingUp, TrendingDown, Percent, Wallet, Banknote, ShieldCheck } from 'lucide-react';

interface CalculatorLibraryProps {
  onOpenCalculator?: (calcId: string) => void;
}

export const CalculatorLibrary: React.FC<CalculatorLibraryProps> = ({ onOpenCalculator }) => {
  const categories = [
    {
      title: "Comprehensive Simulators",
      calculators: [
        { id: 'tax_comprehensive', name: 'Comprehensive Income & Tax Simulator', icon: Landmark, description: 'Fully Employed, Freelance, Affiliate, Mixed Income & Deductions' },
        { id: 'debt_loan', name: 'Debt & Loan Simulator', icon: Wallet, description: 'Payoff planner, Amortization, and Installment Affordability' },
                { id: 'business_pricing', name: 'Business Tax & Compliance Simulator', icon: Building, description: 'Sole Proprietorship, Partnership & BIR Deadlines' },
        { id: 'savings_investment', name: 'Savings & Investment Planner', icon: TrendingUp, description: 'Emergency Fund, Goals, Retirement, and Inflation Impact' },
      ]
    }
  ];

  return (
    <div className="flex flex-col gap-5 pb-20">
      <div className="px-1">
        <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Calculator Library</h2>
        <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">Comprehensive financial tools & simulators</p>
      </div>

      {categories.map((category, idx) => (
        <div key={idx} className="flex flex-col gap-2">
          <h3 className="text-xs font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52] px-1">
            {category.title}
          </h3>
          <div className="flex flex-col gap-2">
            {category.calculators.map(calc => {
              const Icon = calc.icon;
              return (
                <button
                  key={calc.id}
                  type="button"
                  onClick={() => onOpenCalculator && onOpenCalculator(calc.id)}
                  className="flex items-center gap-3 p-4 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs hover:border-[#B03C09] dark:hover:border-[#FF9A52] transition-colors cursor-pointer group text-left"
                >
                  <div className="w-12 h-12 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 group-hover:scale-105 transition-transform">
                    <Icon size={22} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {calc.name}
                    </span>
                    <span className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5">
                      {calc.description}
                    </span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
};
