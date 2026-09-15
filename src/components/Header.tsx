import React from 'react';
import { Sun, Moon, Settings, ShieldCheck } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';

interface HeaderProps {
  onOpenSettings: () => void;
  onOpenInfo: () => void;
}

export const Header: React.FC<HeaderProps> = ({ onOpenSettings, onOpenInfo }) => {
  const { themeMode, toggleTheme } = useFinancial();
  const isDark = themeMode === 'gabi';

  const todayFormatted = new Date().toLocaleDateString('en-PH', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  });

  return (
    <header className="flex items-center justify-between py-3 px-1">
      <div className="flex flex-col">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold tracking-wider uppercase text-[#B03C09] dark:text-[#FF9A52]">
            Salapify 3
          </span>
          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52]">
            <ShieldCheck size={11} /> Offline Only
          </span>
        </div>
        <h1 className="text-sm font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
          {todayFormatted}
        </h1>
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={toggleTheme}
          title={`Switch to ${isDark ? 'Hapon (Light)' : 'Gabi (Dark)'} theme`}
          className="p-2 rounded-full transition-colors bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer"
          aria-label="Toggle theme"
        >
          {isDark ? <Sun size={17} className="text-[#FF9A52]" /> : <Moon size={17} className="text-[#B03C09]" />}
        </button>

        <button
          type="button"
          onClick={onOpenSettings}
          title="Settings & Backup"
          className="p-2 rounded-full transition-colors bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer"
          aria-label="Settings"
        >
          <Settings size={17} />
        </button>
      </div>
    </header>
  );
};
