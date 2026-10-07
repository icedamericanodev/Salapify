import React from 'react';
import { motion } from 'motion/react';
import { Bot } from 'lucide-react';

interface PanFloatingButtonProps {
  onClick: () => void;
}

export const PanFloatingButton: React.FC<PanFloatingButtonProps> = ({ onClick }) => {
  return (
    <div className="fixed bottom-20 right-4 z-40">
      <motion.button
        type="button"
        id="floating-pan-btn"
        onClick={onClick}
        title="Ask Pan (Offline Financial Copilot)"
        initial={{ scale: 0, opacity: 0 }}
        animate={{
          scale: [1, 1.04, 1],
          boxShadow: [
            '0 10px 15px -3px rgba(0, 0, 0, 0.2), 0 0 0 0 rgba(176, 60, 9, 0.4)',
            '0 12px 20px -3px rgba(0, 0, 0, 0.25), 0 0 0 6px rgba(176, 60, 9, 0)',
            '0 10px 15px -3px rgba(0, 0, 0, 0.2), 0 0 0 0 rgba(176, 60, 9, 0)',
          ],
          opacity: 1,
        }}
        transition={{
          scale: {
            duration: 2.6,
            repeat: Infinity,
            ease: 'easeInOut',
          },
          boxShadow: {
            duration: 2.6,
            repeat: Infinity,
            ease: 'easeInOut',
          },
          opacity: { duration: 0.3 },
        }}
        whileHover={{ scale: 1.08 }}
        whileTap={{ scale: 0.95 }}
        className="flex items-center gap-1.5 px-3 py-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-lg cursor-pointer font-bold text-xs border border-white/20 dark:border-black/10"
        aria-label="Ask Pan AI"
      >
        <Bot size={16} strokeWidth={2.4} />
        <span>Ask Pan</span>
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse ml-0.5" />
      </motion.button>
    </div>
  );
};
