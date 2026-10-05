import React from 'react';
import { Bot, Sparkles } from 'lucide-react';

interface PanFloatingButtonProps {
  onClick: () => void;
}

export const PanFloatingButton: React.FC<PanFloatingButtonProps> = ({ onClick }) => {
  return (
    <div className="fixed bottom-20 right-4 z-40">
      <button
        type="button"
        id="floating-pan-ai-btn"
        onClick={onClick}
        title="Ask Pan (Offline Financial Copilot)"
        className="flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-lg hover:shadow-xl hover:scale-105 active:scale-95 transition-all cursor-pointer font-bold text-xs border border-white/20 dark:border-black/10"
        aria-label="Ask Pan AI"
      >
        <Bot size={16} strokeWidth={2.4} />
        <span>Ask Pan</span>
        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse ml-0.5" />
      </button>
    </div>
  );
};
