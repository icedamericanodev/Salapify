import React from 'react';
import { motion } from 'motion/react';
import { Bot, Sparkles, ChevronRight } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface PanHeroCardProps {
  onOpenPan: () => void;
  onQuickAsk?: (prompt: string) => void;
}

export const PanHeroCard: React.FC<PanHeroCardProps> = ({ onOpenPan, onQuickAsk }) => {
  const { safeToSpend, safeToSpendPerDay, payday } = useFinancial();

  const handlePromptClick = (e: React.MouseEvent, prompt: string) => {
    e.stopPropagation();
    if (onQuickAsk) {
      onQuickAsk(prompt);
    } else {
      onOpenPan();
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      onClick={onOpenPan}
      className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs cursor-pointer hover:border-[#B03C09]/40 dark:hover:border-[#FF9A52]/40 transition-all group"
    >
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="w-9 h-9 rounded-2xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] flex items-center justify-center shrink-0 shadow-2xs group-hover:scale-105 transition-transform">
            <Bot size={18} strokeWidth={2.4} />
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Ask Pan Copilot
              </span>
              <span className="text-[9px] font-extrabold px-1.5 py-0.2 rounded-md bg-[#16643F]/10 dark:bg-[#5FCB8E]/15 text-[#16643F] dark:text-[#5FCB8E]">
                100% PRIVATE
              </span>
            </div>
            <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate">
              {formatPeso(safeToSpend)} safe • {payday.daysToPayday} days to sweldo
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] shrink-0">
          <span>Chat</span>
          <ChevronRight size={14} className="group-hover:translate-x-0.5 transition-transform" />
        </div>
      </div>

      {/* 3 Quick Prompt Chips */}
      <div className="flex items-center gap-1.5 pt-2.5 mt-2.5 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 overflow-x-auto no-scrollbar">
        {[
          '⚡ Safe to spend today?',
          '💳 Which card is due?',
          '🤝 Who owes me?',
        ].map((prompt, idx) => (
          <button
            key={idx}
            type="button"
            onClick={(e) => handlePromptClick(e, prompt.replace(/^[^\w\s]+\s*/, ''))}
            className="px-2 py-1 rounded-xl text-[10px] font-semibold bg-[#FFEEDF]/60 dark:bg-[#14100D]/70 hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C] text-[#5A5148] dark:text-[#C6B8AC] border border-[#F3DFCD]/80 dark:border-[#383029]/80 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            {prompt}
          </button>
        ))}
      </div>
    </motion.div>
  );
};
