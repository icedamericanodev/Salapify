import React from 'react';
import { Home, BookOpen, FileSpreadsheet, Target, Wallet, Plus } from 'lucide-react';

export type TabType = 'home' | 'ledger' | 'reports' | 'plan' | 'accounts';

interface TabBarProps {
  currentTab: TabType;
  onSelectTab: (tab: TabType) => void;
  onOpenLog: () => void;
}

export const TabBar: React.FC<TabBarProps> = ({
  currentTab,
  onSelectTab,
  onOpenLog,
}) => {
  const tabs = [
    { id: 'home' as TabType, label: 'Home', icon: Home },
    { id: 'ledger' as TabType, label: 'Activity', icon: BookOpen },
    { id: 'reports' as TabType, label: 'Reports', icon: FileSpreadsheet },
    { id: 'plan' as TabType, label: 'Plan', icon: Target },
    { id: 'accounts' as TabType, label: 'Accounts', icon: Wallet },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 dark:bg-[#27201A]/95 backdrop-blur-md border-t border-[#F3DFCD] dark:border-[#383029] px-1.5 sm:px-3 py-2 pb-safe shadow-lg">
      <div className="max-w-md mx-auto flex items-center justify-between gap-1">
        {/* The 5 main navigation destinations */}
        <div className="flex items-center gap-0.5 flex-1 min-w-0">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = currentTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => onSelectTab(tab.id)}
                className={`flex-1 min-w-0 flex flex-col items-center justify-center py-1 rounded-xl transition-all cursor-pointer ${
                  isActive
                    ? 'text-[#B03C09] dark:text-[#FF9A52] font-bold'
                    : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
                }`}
              >
                <Icon size={17} strokeWidth={isActive ? 2.4 : 1.8} className="shrink-0" />
                <span className="text-[9px] sm:text-[10px] mt-0.5 tracking-tight truncate max-w-full">
                  {tab.label}
                </span>
              </button>
            );
          })}
        </div>

        {/* The prominent + Log accent pill at the right end */}
        <button
          type="button"
          onClick={onOpenLog}
          className="ml-1 flex items-center gap-1 px-2.5 sm:px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 active:scale-95 transition-all cursor-pointer shrink-0 whitespace-nowrap"
        >
          <Plus size={14} strokeWidth={2.6} />
          <span>Log</span>
        </button>
      </div>
    </nav>
  );
};
