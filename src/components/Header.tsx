import React from 'react';
import { Sun, Moon, Settings, ShieldCheck, Bell, Users, Sparkles, CircleDollarSign, Bot } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';

interface HeaderProps {
  onOpenSettings: () => void;
  onOpenInfo: () => void;
  onOpenReminders: () => void;
  onOpenCollaboration?: () => void;
  onOpenPhilippineSuite?: () => void;
  onOpenPan?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  onOpenSettings,
  onOpenInfo,
  onOpenReminders,
  onOpenCollaboration,
  onOpenPhilippineSuite,
  onOpenPan,
}) => {
  const { themeMode, toggleTheme, unreadNotificationsCount, members } = useFinancial();
  const isDark = themeMode === 'gabi';

  const todayFormatted = new Date().toLocaleDateString('en-PH', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
  });

  return (
    <header className="flex items-center justify-between py-3 px-1 gap-2">
      <div className="flex flex-col min-w-0 flex-1">
        <div className="flex items-center gap-1.5 flex-wrap">
          <div className="flex items-center gap-1.5 shrink-0" title="Salapify 3">
            <img src="/logo.png" alt="Salapify Logo" className="w-6 h-6 rounded-full shadow-sm object-contain" />
            <span className="text-[13px] font-black tracking-tight text-[#B03C09] dark:text-[#FF9A52]">
              Salapify
            </span>
          </div>
          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52] shrink-0 whitespace-nowrap">
            <ShieldCheck size={11} /> Offline Only
          </span>
        </div>
        <h1 className="text-xs sm:text-sm font-semibold text-[#5A5148] dark:text-[#C6B8AC] truncate">
          {todayFormatted}
        </h1>
      </div>

      <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">


        {/* Philippine Local Tools Suite */}
        {onOpenPhilippineSuite && (
          <button
            type="button"
            id="header-open-ph-suite-btn"
            onClick={onOpenPhilippineSuite}
            title="Philippine Financial Tools (Padala, 13th-Month, Ambag, Sweldo)"
            className="p-2 rounded-full transition-colors bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#FFEEDF]/50 dark:hover:bg-[#383029] border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer"
            aria-label="Open Philippine Financial Suite"
          >
            <Sparkles size={17} />
          </button>
        )}

        {/* Collaboration / Shared Finances Button */}
        {onOpenCollaboration && (
          <button
            type="button"
            id="header-open-collaboration-btn"
            onClick={onOpenCollaboration}
            title="Shared Finances & Collaboration Hub"
            className="relative p-2 rounded-full transition-colors bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#B03C09] dark:hover:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer"
            aria-label="Open collaboration hub"
          >
            <Users size={17} />
            {members && members.length > 1 && (
              <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-[#16643F] dark:bg-[#5FCB8E] text-white dark:text-[#14100D] text-[9px] font-bold flex items-center justify-center ring-2 ring-white dark:ring-[#14100D]">
                {members.length}
              </span>
            )}
          </button>
        )}

        {/* Reminders & Alerts Bell */}
        <button
          type="button"
          id="header-open-reminders-btn"
          onClick={onOpenReminders}
          title="Reminders & Simulator"
          className="relative p-2 rounded-full transition-colors bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer"
          aria-label="Open reminders"
        >
          <Bell size={17} className={unreadNotificationsCount > 0 ? 'text-[#B03C09] dark:text-[#FF9A52]' : ''} />
          {unreadNotificationsCount > 0 && (
            <span className="absolute -top-1 -right-1 min-w-4 h-4 px-1 rounded-full bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] text-[10px] font-extrabold flex items-center justify-center leading-none ring-2 ring-white dark:ring-[#14100D]">
              {unreadNotificationsCount > 9 ? '9+' : unreadNotificationsCount}
            </span>
          )}
        </button>

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

