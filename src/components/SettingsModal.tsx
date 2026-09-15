import React, { useState } from 'react';
import { X, ShieldCheck, Download, Upload, RotateCcw, Palette, Calendar, Calculator, Briefcase, PlayCircle, Check } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { STARTER_CATEGORY_PACKS } from '../data/categoryPacks';
import { StarterPackId } from '../types';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onOpenTaxCalculator: () => void;
  onOpenYourSetup: (tab?: 'payday' | 'categories' | 'recurring' | 'emergency' | 'privacy') => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  onOpenTaxCalculator,
  onOpenYourSetup,
}) => {
  const {
    themeMode,
    setThemeMode,
    payday,
    resetToSampleData,
    restartOnboarding,
    applyStarterPack,
    transactions,
    accounts,
    debts,
    budgets,
    goals,
    upcoming,
  } = useFinancial();

  const [appliedPackId, setAppliedPackId] = useState<StarterPackId | null>(null);
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [resetSuccess, setResetSuccess] = useState(false);
  const [importError, setImportError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleExportData = () => {
    const backup = {
      timestamp: new Date().toISOString(),
      themeMode,
      transactions,
      accounts,
      debts,
      budgets,
      goals,
      upcoming,
      payday,
    };

    const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `salapify-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImportData = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        setImportError(null);
        const json = JSON.parse(event.target?.result as string);
        if (json.transactions && json.accounts) {
          localStorage.setItem('salapify_transactions_v3', JSON.stringify(json.transactions));
          localStorage.setItem('salapify_accounts_v3', JSON.stringify(json.accounts));
          if (json.debts) localStorage.setItem('salapify_debts_v3', JSON.stringify(json.debts));
          if (json.budgets) localStorage.setItem('salapify_budgets_v3', JSON.stringify(json.budgets));
          if (json.goals) localStorage.setItem('salapify_goals_v3', JSON.stringify(json.goals));
          if (json.upcoming) localStorage.setItem('salapify_upcoming_v3', JSON.stringify(json.upcoming));
          window.location.reload();
        } else {
          setImportError('Invalid backup file structure.');
        }
      } catch (err) {
        setImportError('Could not read or parse JSON file.');
      }
    };
    reader.readAsText(file);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
            Settings
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable list */}
        <div className="overflow-y-auto space-y-4 pr-1">
          {/* 1. Theme Appearance */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
              <Palette size={14} /> Appearance
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setThemeMode('hapon')}
                className={`p-3 rounded-xl border flex flex-col items-start gap-1 cursor-pointer transition-all ${
                  themeMode === 'hapon'
                    ? 'border-[#B03C09] bg-[#FFEEDF]/40'
                    : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]'
                }`}
              >
                <div className="flex items-center justify-between w-full">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Hapon (Light)</span>
                  {themeMode === 'hapon' && <Check size={14} className="text-[#B03C09]" />}
                </div>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Late afternoon warm peach</span>
              </button>

              <button
                type="button"
                onClick={() => setThemeMode('gabi')}
                className={`p-3 rounded-xl border flex flex-col items-start gap-1 cursor-pointer transition-all ${
                  themeMode === 'gabi'
                    ? 'border-[#FF9A52] bg-[#383029]/40'
                    : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]'
                }`}
              >
                <div className="flex items-center justify-between w-full">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Gabi (Dark)</span>
                  {themeMode === 'gabi' && <Check size={14} className="text-[#FF9A52]" />}
                </div>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Warm evening black</span>
              </button>
            </div>
          </div>

          {/* Your Setup Hub (Payday, Categories, Recurring, Emergency Fund) */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
              <Calendar size={14} /> Your Setup Hub
            </label>
            <button
              type="button"
              onClick={() => {
                onClose();
                onOpenYourSetup('payday');
              }}
              className="p-3.5 rounded-xl border border-[#B03C09]/30 dark:border-[#FF9A52]/30 bg-[#FFEEDF]/30 dark:bg-[#14100D] text-left flex items-center justify-between hover:border-[#B03C09] transition-colors cursor-pointer"
            >
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Payday, Categories &amp; Recurring
                  </span>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-[#B03C09]/10 text-[#B03C09] dark:text-[#FF9A52]">
                    {payday.daysToPayday}d to payday
                  </span>
                </div>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mt-0.5">
                  Configure sweldo cycle, customize budget limits, track bills, and emergency runway.
                </span>
              </div>
              <span className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
                Configure
              </span>
            </button>
          </div>

          {/* 3. Tax & Salary Calculator (CPA & Tax Advisor) */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
              <Calculator size={14} /> Philippine Tax & Take-Home
            </label>
            <button
              type="button"
              onClick={() => {
                onClose();
                onOpenTaxCalculator();
              }}
              className="p-3 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-left flex items-center justify-between hover:border-[#B03C09] transition-colors cursor-pointer"
            >
              <div>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                  Open Tax & 13th Month Calculator
                </span>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                  TRAIN law salary brackets, SSS, PhilHealth, Pag-IBIG, and freelancer 8% tax.
                </span>
              </div>
              <span className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
                Open
              </span>
            </button>
          </div>

          {/* 4. Starter Category Packs */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
              <Briefcase size={14} /> Switch Starter Category Pack
            </label>
            <div className="grid grid-cols-2 gap-1.5">
              {STARTER_CATEGORY_PACKS.map((pack) => (
                <button
                  key={pack.id}
                  type="button"
                  onClick={() => {
                    applyStarterPack(pack.id);
                    setAppliedPackId(pack.id);
                    setTimeout(() => setAppliedPackId(null), 2000);
                  }}
                  className="p-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-left flex items-center gap-2 hover:border-[#B03C09] transition-colors cursor-pointer"
                >
                  <span className="text-base">{pack.emoji}</span>
                  <div className="flex-1 min-w-0">
                    <span className="text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8] truncate block">
                      {pack.id === 'employee' ? 'Corporate' : pack.id === 'freelancer' ? 'Freelancer' : pack.id === 'student' ? 'Student' : 'OFW Family'}
                    </span>
                    <span className="text-[9px] text-[#6B6156] dark:text-[#AC9E92]">
                      {appliedPackId === pack.id ? 'Applied!' : 'Apply pack'}
                    </span>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* 5. Backup and Restore */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              Backup & Restore
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={handleExportData}
                className="p-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] flex items-center justify-center gap-1.5 hover:border-[#B03C09] transition-colors cursor-pointer"
              >
                <Download size={14} /> Export JSON
              </button>

              <label className="p-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] flex items-center justify-center gap-1.5 hover:border-[#B03C09] transition-colors cursor-pointer text-center">
                <Upload size={14} /> Import JSON
                <input
                  type="file"
                  accept=".json"
                  onChange={handleImportData}
                  className="hidden"
                />
              </label>
            </div>
            {importError && (
              <p className="text-[11px] text-[#9E2C1B] dark:text-[#FF8A6E] font-medium mt-1">
                {importError}
              </p>
            )}
          </div>

          {/* 6. Privacy Receipt */}
          <div className="p-3.5 rounded-xl bg-emerald-500/10 dark:bg-emerald-500/10 border border-emerald-500/20 flex items-start gap-2.5">
            <ShieldCheck size={18} className="text-[#16643F] dark:text-[#5FCB8E] shrink-0 mt-0.5" />
            <div className="flex flex-col">
              <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E]">
                Privacy Receipt & Offline Guarantee
              </span>
              <p className="text-[11px] text-[#16643F]/90 dark:text-[#5FCB8E]/90 mt-0.5">
                No user account. No cloud database. No analytics tracking. All financial records and debt balances are stored exclusively on this device.
              </p>
            </div>
          </div>

          {/* 7. Test Onboarding & Reset to Sample Data */}
          <div className="pt-2 space-y-2">
            <button
              type="button"
              onClick={() => {
                restartOnboarding();
                onClose();
              }}
              className="w-full py-2.5 rounded-xl border border-[#B03C09]/40 text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold hover:bg-[#B03C09]/10 transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
            >
              <PlayCircle size={14} /> Run First-Time Onboarding Flow
            </button>

            {!showResetConfirm ? (
              <button
                type="button"
                onClick={() => setShowResetConfirm(true)}
                className="w-full py-2.5 rounded-xl border border-[#9E2C1B]/30 text-[#9E2C1B] dark:text-[#FF8A6E] text-xs font-bold hover:bg-[#9E2C1B]/10 transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <RotateCcw size={14} /> Reset to Sample Data
              </button>
            ) : (
              <div className="p-3 rounded-xl border border-[#9E2C1B]/40 bg-[#9E2C1B]/5 dark:bg-[#9E2C1B]/10 space-y-2">
                <p className="text-[11px] text-[#9E2C1B] dark:text-[#FF8A6E] font-medium text-center">
                  Reset all accounts, transactions, debts &amp; goals back to default Philippine demo data?
                </p>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => setShowResetConfirm(false)}
                    className="flex-1 py-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] hover:opacity-90 cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      resetToSampleData();
                      setShowResetConfirm(false);
                      setResetSuccess(true);
                      setTimeout(() => {
                        setResetSuccess(false);
                        onClose();
                      }, 900);
                    }}
                    className="flex-1 py-1.5 rounded-lg bg-[#9E2C1B] text-white text-xs font-bold hover:opacity-95 transition-opacity cursor-pointer flex items-center justify-center gap-1"
                  >
                    <RotateCcw size={13} /> Confirm Reset
                  </button>
                </div>
              </div>
            )}

            {resetSuccess && (
              <div className="p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-700 dark:text-emerald-400 text-xs font-bold text-center flex items-center justify-center gap-1.5">
                <Check size={14} /> Sample data restored successfully!
              </div>
            )}
          </div>

          {/* 6. About */}
          <div className="text-center pt-2 text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
            Salapify 3 · Revamped offline-first budget & debt tracker
          </div>
        </div>
      </div>
    </div>
  );
};
