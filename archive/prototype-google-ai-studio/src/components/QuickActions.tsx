import React from 'react';
import { Plus, HandCoins, Receipt, ArrowRightLeft } from 'lucide-react';

interface QuickActionsProps {
  onOpenLog: () => void;
  onOpenDebt: () => void;
  onOpenBills: () => void;
  onOpenMove: () => void;
}

export const QuickActions: React.FC<QuickActionsProps> = ({
  onOpenLog,
  onOpenDebt,
  onOpenBills,
  onOpenMove,
}) => {
  const actions = [
    {
      id: 'log',
      label: 'Log',
      icon: Plus,
      onClick: onOpenLog,
      highlight: true,
    },
    {
      id: 'debt',
      label: 'Debt',
      icon: HandCoins,
      onClick: onOpenDebt,
    },
    {
      id: 'bills',
      label: 'Bills',
      icon: Receipt,
      onClick: onOpenBills,
    },
    {
      id: 'move',
      label: 'Move',
      icon: ArrowRightLeft,
      onClick: onOpenMove,
    },
  ];

  return (
    <div className="grid grid-cols-4 gap-1.5 sm:gap-2 my-1 px-0.5 sm:px-1 w-full">
      {actions.map((act) => {
        const Icon = act.icon;
        return (
          <button
            key={act.id}
            type="button"
            onClick={act.onClick}
            className="flex flex-col items-center justify-center gap-1.5 group cursor-pointer active:scale-95 transition-transform min-w-0 w-full"
          >
            <div
              className={`w-12 h-12 xs:w-13 xs:h-13 sm:w-14 sm:h-14 max-w-[56px] max-h-[56px] min-w-[44px] min-h-[44px] rounded-2xl flex items-center justify-center shadow-xs transition-colors border aspect-square shrink-0 ${
                act.highlight
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent hover:opacity-90'
                  : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029] group-hover:text-[#B03C09] dark:group-hover:text-[#FF9A52]'
              }`}
            >
              <Icon size={20} strokeWidth={2.2} className="shrink-0" />
            </div>
            <span className="text-[11px] sm:text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] tracking-tight truncate w-full text-center px-0.5">
              {act.label}
            </span>
          </button>
        );
      })}
    </div>
  );
};
