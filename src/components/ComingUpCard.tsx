import React from 'react';
import { ChevronRight, Zap, Music, CalendarCheck, CreditCard } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface ComingUpCardProps {
  onSeeAll: () => void;
  onOpenBills?: () => void;
}

export const ComingUpCard: React.FC<ComingUpCardProps> = ({ onSeeAll, onOpenBills }) => {
  const { upcoming } = useFinancial();

  const getIcon = (type: string, name: string) => {
    if (type === 'payday') return CalendarCheck;
    if (name.toLowerCase().includes('spotify') || type === 'subscription') return Music;
    if (name.toLowerCase().includes('meralco') || name.toLowerCase().includes('electric') || name.toLowerCase().includes('bill')) return Zap;
    return CreditCard;
  };

  const handleAction = onOpenBills || onSeeAll;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between px-1">
        <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
          Coming up
        </h2>
        <button
          type="button"
          onClick={handleAction}
          className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-0.5 hover:underline cursor-pointer"
        >
          Manage bills <ChevronRight size={14} />
        </button>
      </div>

      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
        {upcoming.slice(0, 4).map((item) => {
          const Icon = getIcon(item.type, item.name);
          const isIncome = item.isIncome || item.type === 'payday';

          return (
            <div
              key={item.id}
              onClick={handleAction}
              className="flex items-center justify-between p-3.5 hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors cursor-pointer"
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                    isIncome
                      ? 'bg-[#16643F]/10 dark:bg-[#5FCB8E]/15 text-[#16643F] dark:text-[#5FCB8E]'
                      : 'bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]'
                  }`}
                >
                  <Icon size={17} />
                </div>
                <div className="flex flex-col">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {item.name}
                  </span>
                  <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    {item.dueDate}
                  </span>
                </div>
              </div>

              <span
                className={`text-xs font-bold ${
                  isIncome
                    ? 'text-[#16643F] dark:text-[#5FCB8E]'
                    : 'text-[#15120F] dark:text-[#F6EFE8]'
                }`}
              >
                {isIncome ? `+${formatPeso(item.amount)}` : formatPeso(item.amount)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};
