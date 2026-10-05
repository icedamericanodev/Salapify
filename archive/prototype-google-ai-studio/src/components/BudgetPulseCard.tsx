import React, { useMemo } from 'react';
import { PieChart, AlertCircle, ChevronRight } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface BudgetPulseCardProps {
  onSeeAll: () => void;
}

export const BudgetPulseCard: React.FC<BudgetPulseCardProps> = ({ onSeeAll }) => {
  const { budgets, transactions } = useFinancial();

  const { totalBudgetLimit, totalSpent, watchCloselyCount } = useMemo(() => {
    const stats = budgets.map((b) => {
      const spent = transactions
        .filter((t) => t.type === 'expense' && t.category.toLowerCase() === b.category.toLowerCase())
        .reduce((sum, t) => sum + t.amount, 0);
      const remaining = b.limit - spent;
      const percent = Math.min(100, Math.round((spent / b.limit) * 100));
      return {
        isOver: remaining < 0,
        isNear: percent >= 80 && remaining >= 0,
        spent,
        limit: b.limit
      };
    });

    const watch = stats.filter(s => s.isOver || s.isNear).length;
    const limitSum = stats.reduce((sum, s) => sum + s.limit, 0);
    const spentSum = stats.reduce((sum, s) => sum + s.spent, 0);

    return { totalBudgetLimit: limitSum, totalSpent: spentSum, watchCloselyCount: watch };
  }, [budgets, transactions]);

  if (budgets.length === 0) return null;

  const totalRemaining = Math.max(0, totalBudgetLimit - totalSpent);
  const percentTotal = totalBudgetLimit > 0 ? Math.min(100, Math.round((totalSpent / totalBudgetLimit) * 100)) : 0;

  return (
    <div
      onClick={onSeeAll}
      className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-4 shadow-xs cursor-pointer hover:opacity-90 transition-opacity"
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-1.5">
          <div className="w-6 h-6 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400 flex items-center justify-center">
            <PieChart size={12} />
          </div>
          <span className="text-xs font-bold uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
            Budget Pulse
          </span>
        </div>
        <ChevronRight size={16} className="text-[#6B6156] dark:text-[#AC9E92]" />
      </div>

      <div className="flex items-end justify-between gap-2">
        <div>
          <span className="text-[#6B6156] dark:text-[#AC9E92] text-xs font-semibold block mb-0.5">
            Total Remaining
          </span>
          <div className="text-xl font-extrabold font-display text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
            {formatPeso(totalRemaining)}
          </div>
        </div>
        <div className="text-right">
          <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] font-semibold block mb-0.5">
            {percentTotal}% Spent
          </span>
          <div className="w-20 h-2 bg-[#FFEEDF] dark:bg-[#14100D] rounded-full overflow-hidden flex justify-end">
            <div 
              className="h-full rounded-full transition-all duration-500 bg-emerald-600 dark:bg-emerald-400"
              style={{ width: `${percentTotal}%` }}
            />
          </div>
        </div>
      </div>

      {watchCloselyCount > 0 && (
        <div className="mt-3 flex items-center gap-1.5 px-2.5 py-1.5 bg-amber-50 dark:bg-amber-900/20 rounded-xl text-amber-800 dark:text-amber-400 text-[10px] font-bold">
          <AlertCircle size={12} className="shrink-0" />
          <span>{watchCloselyCount} {watchCloselyCount === 1 ? 'category requires' : 'categories require'} attention</span>
        </div>
      )}
    </div>
  );
};
