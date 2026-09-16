import React, { useState } from 'react';
import { Sparkles, ArrowRight, ArrowLeft, Upload, Check, Wallet, Calendar, ShieldCheck, Briefcase } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { AccountKind, StarterPackId } from '../types';
import { STARTER_CATEGORY_PACKS } from '../data/categoryPacks';
import { formatPeso } from '../utils/format';

interface OnboardingFlowProps {
  onComplete?: () => void;
}

export const OnboardingFlow: React.FC<OnboardingFlowProps> = () => {
  const { completeOnboarding, payday } = useFinancial();

  const [step, setStep] = useState<1 | 2 | 3>(1);

  // Step 2 state: First account & starter pack
  const [accountName, setAccountName] = useState('GCash');
  const [institution, setInstitution] = useState('GCash');
  const [kind, setKind] = useState<AccountKind>('cash');
  const [balance, setBalance] = useState('');
  const [selectedPack, setSelectedPack] = useState<StarterPackId>('employee');

  // Step 3 state: Payday cycle
  const [cycleType, setCycleType] = useState<'15_30' | 'monthly' | 'weekly'>('15_30');

  const presetInstitutions = [
    { name: 'GCash', kind: 'cash' as AccountKind, monogram: 'GC', sub: 'E-Wallet' },
    { name: 'Maya', kind: 'cash' as AccountKind, monogram: 'MY', sub: 'E-Wallet / Bank' },
    { name: 'BPI', kind: 'bank' as AccountKind, monogram: 'BPI', sub: 'Bank' },
    { name: 'SeaBank', kind: 'bank' as AccountKind, monogram: 'SB', sub: 'Digital Bank' },
    { name: 'Cash', kind: 'cash' as AccountKind, monogram: '₱', sub: 'Physical Cash' },
  ];

  const handleSelectPreset = (item: typeof presetInstitutions[0]) => {
    setAccountName(item.name);
    setInstitution(item.name);
    setKind(item.kind);
  };

  const handleRestoreBackup = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const json = JSON.parse(event.target?.result as string);
        if (json.transactions && json.accounts) {
          localStorage.setItem('salapify_transactions_v3', JSON.stringify(json.transactions));
          localStorage.setItem('salapify_accounts_v3', JSON.stringify(json.accounts));
          if (json.debts) localStorage.setItem('salapify_debts_v3', JSON.stringify(json.debts));
          if (json.budgets) localStorage.setItem('salapify_budgets_v3', JSON.stringify(json.budgets));
          if (json.goals) localStorage.setItem('salapify_goals_v3', JSON.stringify(json.goals));
          if (json.upcoming) localStorage.setItem('salapify_upcoming_v3', JSON.stringify(json.upcoming));
          localStorage.setItem('salapify_onboarded_v3', 'true');
          window.location.reload();
        }
      } catch (err) {
        alert('Invalid backup file. Please provide a valid Salapify JSON export.');
      }
    };
    reader.readAsText(file);
  };

  const handleFinish = () => {
    const initialBalance = parseFloat(balance) || 0;
    completeOnboarding({
      accountName: accountName.trim() || 'My Wallet',
      institution,
      kind,
      balance: initialBalance,
      cycleType,
      starterPackId: selectedPack,
    });
  };

  return (
    <div className="min-h-screen bg-[#FFEEDF] dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8] flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-6 sm:p-7 shadow-xl border border-[#F3DFCD] dark:border-[#383029] flex flex-col min-h-[540px]">
        {/* Progress indicator */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-1.5">
            {[1, 2, 3].map((s) => (
              <div
                key={s}
                className={`h-1.5 rounded-full transition-all duration-300 ${
                  s === step
                    ? 'w-7 bg-[#B03C09] dark:bg-[#FF9A52]'
                    : s < step
                    ? 'w-3 bg-[#16643F] dark:bg-[#5FCB8E]'
                    : 'w-3 bg-[#F3DFCD] dark:border-[#383029] bg-[#FFEEDF] dark:bg-[#14100D]'
                }`}
              />
            ))}
          </div>
          <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
            Step {step} of 3
          </span>
        </div>

        {/* STEP 1: WELCOME */}
        {step === 1 && (
          <div className="flex-1 flex flex-col justify-between animate-fadeIn">
            <div className="space-y-4 pt-2">
              <div className="w-12 h-12 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52]">
                <Sparkles size={24} />
              </div>

              <div>
                <h1 className="text-2xl font-extrabold tracking-tight text-[#15120F] dark:text-[#F6EFE8]">
                  Welcome to Salapify
                </h1>
                <p className="text-sm font-medium text-[#5A5148] dark:text-[#C6B8AC] mt-1.5 leading-relaxed">
                  Your private, offline-first sweldo companion and debt tracker. No bank logins, no accounts, and no cloud leaks.
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                <div className="flex items-start gap-2.5">
                  <ShieldCheck size={18} className="text-[#16643F] dark:text-[#5FCB8E] shrink-0 mt-0.5" />
                  <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                    <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                      Privacy Receipt Included
                    </strong>
                    All numbers stay inside this browser. You can export or clear your data at any time.
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-2.5 pt-6">
              <button
                type="button"
                onClick={() => setStep(2)}
                className="w-full py-3.5 px-4 rounded-2xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-sm shadow-sm flex items-center justify-center gap-2 hover:opacity-95 transition-opacity cursor-pointer"
              >
                Start fresh <ArrowRight size={16} />
              </button>

              <label className="w-full py-3.5 px-4 rounded-2xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] font-bold text-sm flex items-center justify-center gap-2 hover:border-[#B03C09] transition-colors cursor-pointer">
                <Upload size={16} /> Restore a backup
                <input
                  type="file"
                  accept=".json"
                  onChange={handleRestoreBackup}
                  className="hidden"
                />
              </label>
            </div>
          </div>
        )}

        {/* STEP 2: FIRST ACCOUNT & STARTER PACK */}
        {step === 2 && (
          <div className="flex-1 flex flex-col justify-between animate-fadeIn">
            <div className="space-y-4">
              <div>
                <h2 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                  First account and balance
                </h2>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-1">
                  Pick where you keep your primary spending money right now.
                </p>
              </div>

              {/* Presets */}
              <div className="grid grid-cols-3 gap-1.5 sm:gap-2">
                {presetInstitutions.map((item) => (
                  <button
                    key={item.name}
                    type="button"
                    onClick={() => handleSelectPreset(item)}
                    className={`p-2 sm:p-2.5 rounded-xl border text-left flex flex-col gap-0.5 transition-all cursor-pointer min-w-0 ${
                      accountName === item.name
                        ? 'border-[#B03C09] bg-[#FFEEDF]/40 dark:border-[#FF9A52] dark:bg-[#FF9A52]/10'
                        : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]'
                    }`}
                  >
                    <span className="font-extrabold text-xs text-[#B03C09] dark:text-[#FF9A52] truncate">
                      {item.monogram}
                    </span>
                    <span className="font-bold text-[11px] sm:text-xs text-[#15120F] dark:text-[#F6EFE8] truncate">
                      {item.name}
                    </span>
                  </button>
                ))}
              </div>

              {/* Balance input */}
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Current Balance in {accountName} (₱)
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-sm text-[#6B6156] dark:text-[#AC9E92]">
                    ₱
                  </span>
                  <input
                    type="number"
                    step="any"
                    autoFocus
                    value={balance}
                    onChange={(e) => setBalance(e.target.value)}
                    placeholder="5000.00"
                    className="w-full pl-8 pr-3 py-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>

              {/* Starter Category Pack Picker */}
              <div className="pt-1">
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 flex items-center gap-1.5">
                  <Briefcase size={14} /> Starter Category Budget Pack
                </label>
                <div className="space-y-1.5">
                  {STARTER_CATEGORY_PACKS.map((pack) => (
                    <div
                      key={pack.id}
                      onClick={() => setSelectedPack(pack.id)}
                      className={`p-2.5 rounded-xl border flex items-center justify-between cursor-pointer transition-all ${
                        selectedPack === pack.id
                          ? 'border-[#B03C09] bg-[#FFEEDF]/40 dark:border-[#FF9A52] dark:bg-[#FF9A52]/10'
                          : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]'
                      }`}
                    >
                      <div className="flex items-center gap-2.5">
                        <span className="text-base">{pack.emoji}</span>
                        <div>
                          <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                            {pack.title}
                          </span>
                          <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                            {pack.categories.length} categories pre-configured
                          </span>
                        </div>
                      </div>

                      {selectedPack === pack.id && (
                        <Check size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="flex gap-2 pt-4">
              <button
                type="button"
                onClick={() => setStep(1)}
                className="py-3 px-4 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1 cursor-pointer"
              >
                <ArrowLeft size={14} /> Back
              </button>
              <button
                type="button"
                onClick={() => setStep(3)}
                className="flex-1 py-3 px-4 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs flex items-center justify-center gap-1 cursor-pointer hover:opacity-95"
              >
                Continue <ArrowRight size={14} />
              </button>
            </div>
          </div>
        )}

        {/* STEP 3: PAYDAY CYCLE & SWELDO RAIL INTRO */}
        {step === 3 && (
          <div className="flex-1 flex flex-col justify-between animate-fadeIn">
            <div className="space-y-4">
              <div>
                <h2 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                  Payday cycle
                </h2>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-1">
                  Salapify paces your spending across your payroll cutoff.
                </p>
              </div>

              {/* Cycle selection options */}
              <div className="space-y-2">
                {[
                  {
                    id: '15_30' as const,
                    title: '15th and 30th (Bimonthly)',
                    sub: 'Most common Philippine corporate and private employer sweldo.',
                  },
                  {
                    id: 'monthly' as const,
                    title: 'Monthly (End of month or 25th)',
                    sub: 'Single paycheck per month.',
                  },
                  {
                    id: 'weekly' as const,
                    title: 'Weekly / Milestone Payouts',
                    sub: 'Freelancer weekly retainers or allowances.',
                  },
                ].map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => setCycleType(item.id)}
                    className={`w-full p-3 rounded-xl border text-left flex items-start justify-between cursor-pointer transition-all ${
                      cycleType === item.id
                        ? 'border-[#B03C09] bg-[#FFEEDF]/40 dark:border-[#FF9A52] dark:bg-[#FF9A52]/10'
                        : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]'
                    }`}
                  >
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                        {item.title}
                      </span>
                      <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5 block">
                        {item.sub}
                      </span>
                    </div>
                    {cycleType === item.id && (
                      <Check size={16} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                    )}
                  </button>
                ))}
              </div>

              {/* The Sweldo Rail preview */}
              <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                    The Sweldo Rail
                  </span>
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {payday.daysToPayday} days until payday
                  </span>
                </div>

                {/* 5dp Track */}
                <div className="w-full h-[5px] rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden">
                  <div
                    className="h-full rounded-full bg-[#B03C09] dark:bg-[#FF9A52] transition-all duration-500"
                    style={{ width: '60%' }}
                  />
                </div>

                <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] mt-2">
                  This track lives inside your hero panel to protect your daily runway automatically.
                </p>
              </div>
            </div>

            <div className="flex gap-2 pt-4">
              <button
                type="button"
                onClick={() => setStep(2)}
                className="py-3 px-4 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1 cursor-pointer"
              >
                <ArrowLeft size={14} /> Back
              </button>
              <button
                type="button"
                onClick={handleFinish}
                className="flex-1 py-3 px-4 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs flex items-center justify-center gap-1 cursor-pointer hover:opacity-95"
              >
                Complete Setup <Check size={16} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
