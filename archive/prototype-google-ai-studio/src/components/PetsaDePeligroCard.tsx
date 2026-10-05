import React, { useState } from 'react';
import { motion } from 'motion/react';
import {
  ShieldAlert,
  ShieldCheck,
  Coffee,
  Sparkles,
  Zap,
  ArrowRight,
  TrendingDown,
  Info,
  Calendar,
  AlertTriangle,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface PetsaDePeligroCardProps {
  onOpenLog?: (amount?: number, category?: string, note?: string) => void;
  onOpenSafeToSpend?: () => void;
  onOpenPan?: (prompt?: string) => void;
}

export const PetsaDePeligroCard: React.FC<PetsaDePeligroCardProps> = ({
  onOpenLog,
  onOpenSafeToSpend,
  onOpenPan,
}) => {
  const { safeToSpend, safeToSpendPerDay, payday, bills, debts, totalAssets } = useFinancial();
  const [activeTab, setActiveTab] = useState<'survival' | 'luho'>('survival');

  const daysToPayday = Math.max(1, payday.daysToPayday);
  const isPetsaDePeligro = daysToPayday <= 5 || safeToSpendPerDay < 550;

  // Calculate upcoming commitments before payday
  const upcomingBillsTotal = bills
    .filter((b) => !b.isPaid && b.dueDate)
    .reduce((sum, b) => sum + b.amount, 0);

  // Calculate Luho (Guilt-Free Treat) Allowance:
  // Formula: Safe-to-spend minus an emergency buffer, distributed across the cycle.
  // 15% to 20% of safe-to-spend can be guilt-free treats if basic runway is positive
  const luhoAllowance = Math.max(0, Math.round(safeToSpend * 0.22));
  const luhoPerDay = Math.round(luhoAllowance / daysToPayday);

  // Tipid Survival Daily Allocation (Food + Fare)
  const tipidDailyTarget = Math.max(150, Math.min(450, Math.round(safeToSpendPerDay * 0.7)));

  return (
    <div className="w-full rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] p-4 shadow-xs transition-all">
      {/* Header Tabs: Petsa de Peligro vs Luho Jar */}
      <div className="flex items-center justify-between pb-3 border-b border-[#F4E3D5] dark:border-[#2C241E] mb-3">
        <div className="flex items-center gap-1.5 p-0.5 rounded-xl bg-[#FFEEDF] dark:bg-[#28211A] text-xs font-bold">
          <button
            type="button"
            onClick={() => setActiveTab('survival')}
            className={`flex items-center gap-1 px-2.5 py-1 rounded-lg transition-all cursor-pointer ${
              activeTab === 'survival'
                ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#A69B8F] hover:text-[#15120F]'
            }`}
          >
            {isPetsaDePeligro ? (
              <ShieldAlert size={13} className="text-[#B03C09] dark:text-[#FF9A52]" />
            ) : (
              <ShieldCheck size={13} className="text-emerald-600 dark:text-emerald-400" />
            )}
            <span>Petsa de Peligro</span>
            {isPetsaDePeligro && (
              <span className="w-1.5 h-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] animate-pulse" />
            )}
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('luho')}
            className={`flex items-center gap-1 px-2.5 py-1 rounded-lg transition-all cursor-pointer ${
              activeTab === 'luho'
                ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#A69B8F] hover:text-[#15120F]'
            }`}
          >
            <Coffee size={13} />
            <span>Luho Jar</span>
            <span className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400">
              {formatPeso(luhoAllowance, false)}
            </span>
          </button>
        </div>

        <button
          type="button"
          onClick={() => onOpenSafeToSpend && onOpenSafeToSpend()}
          className="text-[11px] font-semibold text-[#8C430B] dark:text-[#FFB076] hover:underline flex items-center gap-0.5 cursor-pointer"
        >
          <span>Audit</span>
          <ArrowRight size={11} />
        </button>
      </div>

      {activeTab === 'survival' ? (
        /* Petsa de Peligro Shield View */
        <div className="flex flex-col gap-3">
          <div className="flex items-start justify-between gap-2">
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#A69B8F]">
                  {isPetsaDePeligro ? '🔥 Critical Survival Shield' : '✅ Sweldo Pacing on Track'}
                </span>
                <span className="px-1.5 py-0.2 rounded text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#2F241C] text-[#B03C09] dark:text-[#FF9A52]">
                  {daysToPayday}d to sahod
                </span>
              </div>
              <div className="text-2xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5">
                {formatPeso(safeToSpendPerDay, false)}
                <span className="text-xs font-normal text-[#6B6156] dark:text-[#A69B8F] ml-1">
                  / day safe spend
                </span>
              </div>
            </div>

            <div className="text-right">
              <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#A69B8F]">
                Survival Target
              </span>
              <div className="text-sm font-bold text-emerald-600 dark:text-emerald-400 tabular-nums">
                ~{formatPeso(tipidDailyTarget, false)}/day
              </div>
              <span className="text-[10px] text-[#6B6156] dark:text-[#A69B8F]">
                Food + Pamasahe
              </span>
            </div>
          </div>

          {/* Quick Tipid Logger Buttons */}
          <div className="pt-1">
            <span className="text-[11px] font-bold text-[#6B6156] dark:text-[#A69B8F] block mb-1.5">
              ⚡ 1-Tap Fast Tipid Logging:
            </span>
            <div className="grid grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => onOpenLog && onOpenLog(85, 'Food & Dining', 'Tipid Meal / Karinderya')}
                className="py-1.5 px-2 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029] hover:border-[#B03C09] text-left transition-all cursor-pointer"
              >
                <div className="text-[10px] font-bold text-[#6B6156] dark:text-[#A69B8F] truncate">
                  Karinderya
                </div>
                <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">₱85</div>
              </button>

              <button
                type="button"
                onClick={() => onOpenLog && onOpenLog(45, 'Transportation', 'Jeepney / MRT Fare')}
                className="py-1.5 px-2 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029] hover:border-[#B03C09] text-left transition-all cursor-pointer"
              >
                <div className="text-[10px] font-bold text-[#6B6156] dark:text-[#A69B8F] truncate">
                  MRT / Jeep
                </div>
                <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">₱45</div>
              </button>

              <button
                type="button"
                onClick={() =>
                  onOpenPan &&
                  onOpenPan(`Can I survive ${daysToPayday} days with ₱${Math.round(safeToSpend)} safe to spend?`)
                }
                className="py-1.5 px-2 rounded-xl bg-[#FFEEDF] dark:bg-[#2E231B] border border-[#F0D5C0] dark:border-[#383029] text-left transition-all cursor-pointer flex flex-col justify-center"
              >
                <div className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-1">
                  <Zap size={10} />
                  <span>Ask Pan</span>
                </div>
                <div className="text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8]">Survival Plan</div>
              </button>
            </div>
          </div>
        </div>
      ) : (
        /* Luho Jar View */
        <div className="flex flex-col gap-3">
          <div className="flex items-start justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#A69B8F]">
                ✨ Guilt-Free Treat Buffer
              </span>
              <div className="text-2xl font-extrabold text-emerald-600 dark:text-emerald-400 tabular-nums mt-0.5">
                {formatPeso(luhoAllowance)}
              </div>
              <p className="text-[11px] text-[#6B6156] dark:text-[#A69B8F] mt-0.5">
                Spend this guilt-free. Bills & debt obligations are already locked and protected!
              </p>
            </div>

            <div className="text-right">
              <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#A69B8F]">
                Per Day Treat
              </span>
              <div className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                {formatPeso(luhoPerDay, false)}/day
              </div>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-2 pt-1">
            <button
              type="button"
              onClick={() => onOpenLog && onOpenLog(190, 'Food & Dining', 'Matcha / Iced Coffee Treat')}
              className="py-1.5 px-2 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029] hover:border-emerald-500 text-left transition-all cursor-pointer"
            >
              <div className="text-[10px] font-bold text-[#6B6156] dark:text-[#A69B8F] truncate">
                Iced Coffee
              </div>
              <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">₱190</div>
            </button>

            <button
              type="button"
              onClick={() => onOpenLog && onOpenLog(350, 'Food & Dining', 'Comfort Food / Samgyup Share')}
              className="py-1.5 px-2 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029] hover:border-emerald-500 text-left transition-all cursor-pointer"
            >
              <div className="text-[10px] font-bold text-[#6B6156] dark:text-[#A69B8F] truncate">
                Comfort Food
              </div>
              <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">₱350</div>
            </button>

            <button
              type="button"
              onClick={() => onOpenLog && onOpenLog(120, 'Entertainment', 'Movie / Snack Treat')}
              className="py-1.5 px-2 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029] hover:border-emerald-500 text-left transition-all cursor-pointer"
            >
              <div className="text-[10px] font-bold text-[#6B6156] dark:text-[#A69B8F] truncate">
                Luho Snack
              </div>
              <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">₱120</div>
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
