import React from 'react';
import { X, Sparkles, HandCoins, ShieldCheck } from 'lucide-react';

interface InfoModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const InfoModal: React.FC<InfoModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-2xl border border-[#F3DFCD] dark:border-[#383029]">
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
            <Sparkles size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
            About Salapify 3
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        <div className="space-y-3.5 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
          <div>
            <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] mb-0.5">
              1. The Sweldo Rail & Safe to Spend
            </h3>
            <p>
              Calculates exactly how much you can comfortably spend each day until your 15th or 30th sweldo arrives, protecting upcoming bills and savings automatically.
            </p>
          </div>

          <div>
            <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] mb-0.5 flex items-center gap-1">
              <HandCoins size={14} className="text-[#B03C09]" /> 2. Debt Both Ways
            </h3>
            <p>
              Tracks what you owe (lenders, installments) and what friends or family owe you side-by-side with the 5dp proportional Debt Beam.
            </p>
          </div>

          <div>
            <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] mb-0.5 flex items-center gap-1">
              <ShieldCheck size={14} className="text-[#16643F] dark:text-[#5FCB8E]" /> 3. 100% Offline-First
            </h3>
            <p>
              No bank logins, no accounts, and no data leaves your browser. Pure local speed and total privacy.
            </p>
          </div>

          <div className="pt-2">
            <button
              type="button"
              onClick={onClose}
              className="w-full py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 cursor-pointer"
            >
              Got it
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
