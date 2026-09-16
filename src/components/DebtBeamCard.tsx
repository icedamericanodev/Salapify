import React, { useState } from 'react';
import { ChevronRight, Info } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { SectionInfoModal } from './SectionInfoModal';

interface DebtBeamCardProps {
  onSeeAll: () => void;
}

export const DebtBeamCard: React.FC<DebtBeamCardProps> = ({ onSeeAll }) => {
  const { totalDebtsOwedToMe, totalDebtsIOwe, debts } = useFinancial();
  const [showInfo, setShowInfo] = useState(false);

  // Calculate proportional split for the 5dp beam
  const totalCombined = totalDebtsOwedToMe + totalDebtsIOwe;
  const owedToMePercent = totalCombined > 0 
    ? Math.max(12, Math.min(88, (totalDebtsOwedToMe / totalCombined) * 100))
    : 50;
  const youOwePercent = 100 - owedToMePercent;

  // Find next upcoming debt due
  const nextDueDebt = debts
    .filter((d) => !d.isSettled && d.dueDate)
    .sort((a, b) => (a.dueDate || '').localeCompare(b.dueDate || ''))[0];

  return (
    <>
      <div className="flex flex-col gap-2">
        {/* Section Head */}
        <div className="flex items-center justify-between px-1">
          <div className="flex items-center gap-1.5">
            <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Debts (Both ways)
            </h2>
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                setShowInfo(true);
              }}
              className="inline-flex items-center justify-center w-5 h-5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
              title="What is Debt Both Ways?"
              aria-label="Debt Both Ways info"
            >
              <Info size={13} strokeWidth={2.2} />
            </button>
          </div>
          <button
            type="button"
            onClick={onSeeAll}
            className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-0.5 hover:underline cursor-pointer"
          >
            See all <ChevronRight size={14} />
          </button>
        </div>

      {/* Card */}
      <div
        onClick={onSeeAll}
        className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs hover:border-[#B03C09]/40 dark:hover:border-[#FF9A52]/40 transition-colors cursor-pointer"
      >
        {/* Amounts and Labels */}
        <div className="flex justify-between items-start mb-3 gap-2">
          <div className="flex flex-col min-w-0 flex-1">
            <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
              Owed to you
            </span>
            <span className="text-base sm:text-lg font-bold text-[#16643F] dark:text-[#5FCB8E] truncate tabular-nums">
              {formatPeso(totalDebtsOwedToMe)}
            </span>
          </div>

          <div className="flex flex-col items-end shrink-0 pl-2 text-right">
            <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
              You owe
            </span>
            <span className="text-base sm:text-lg font-bold text-[#B03C09] dark:text-[#FF9A52] whitespace-nowrap tabular-nums">
              {formatPeso(totalDebtsIOwe)}
            </span>
          </div>
        </div>

        {/* The Debt Beam: 5dp split bar */}
        <div className="w-full h-[5px] rounded-full overflow-hidden flex gap-[2px] bg-[#FFEEDF] dark:bg-[#14100D] mb-3">
          <div
            className="h-full rounded-l-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-500"
            style={{ width: `${owedToMePercent}%` }}
            title={`Owed to you: ${formatPeso(totalDebtsOwedToMe)}`}
          />
          <div
            className="h-full rounded-r-full bg-[#B03C09] dark:bg-[#FF9A52] transition-all duration-500"
            style={{ width: `${youOwePercent}%` }}
            title={`You owe: ${formatPeso(totalDebtsIOwe)}`}
          />
        </div>

        {/* Next payment caption */}
        {nextDueDebt ? (
          <div className="flex items-center justify-between text-xs pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 gap-2">
            <span className="text-[#5A5148] dark:text-[#C6B8AC] font-medium truncate min-w-0 flex-1">
              Next due: <strong className="text-[#15120F] dark:text-[#F6EFE8]">{nextDueDebt.person}</strong> ({nextDueDebt.dueDate})
            </span>
            <span className="font-semibold text-[#B03C09] dark:text-[#FF9A52] shrink-0 whitespace-nowrap pl-1">
              {formatPeso(nextDueDebt.totalAmount - nextDueDebt.paidAmount)} left
            </span>
          </div>
        ) : (
          <div className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
            No outstanding payment deadlines
          </div>
        )}
      </div>
    </div>

    <SectionInfoModal topic={showInfo ? 'debt' : null} onClose={() => setShowInfo(false)} />
  </>
  );
};
