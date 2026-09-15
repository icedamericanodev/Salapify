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
    <div className="flex items-center justify-between gap-2 my-1 px-1">
      {actions.map((act) => {
        const Icon = act.icon;
        return (
          <button
            key={act.id}
            type="button"
            onClick={act.onClick}
            className="flex-1 flex flex-col items-center gap-2 group cursor-pointer active:scale-95 transition-transform"
          >
            <div
              className={`w-14 h-14 rounded-2xl flex items-center justify-center shadow-xs transition-colors border ${
                act.highlight
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent hover:opacity-90'
                  : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029] group-hover:text-[#B03C09] dark:group-hover:text-[#FF9A52]'
              }`}
            >
              <Icon size={22} strokeWidth={2.2} />
            </div>
            <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] tracking-tight">
              {act.label}
            </span>
          </button>
        );
      })}
    </div>
  );
};
