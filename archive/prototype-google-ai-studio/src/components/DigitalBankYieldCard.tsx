import React, { useState } from 'react';
import { motion } from 'motion/react';
import {
  TrendingUp,
  Landmark,
  Sparkles,
  ShieldCheck,
  ChevronRight,
  Calculator,
  ArrowUpRight,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface DigitalBankYieldCardProps {
  onOpenPhilippineSuite?: () => void;
}

export const DigitalBankYieldCard: React.FC<DigitalBankYieldCardProps> = ({
  onOpenPhilippineSuite,
}) => {
  const { accounts, totalAssets } = useFinancial();

  // Find digital bank accounts
  const digitalAccounts = accounts.filter((acc) => {
    const inst = (acc.institution || '').toLowerCase();
    const name = acc.name.toLowerCase();
    return (
      inst.includes('seabank') ||
      inst.includes('maya') ||
      inst.includes('gotyme') ||
      inst.includes('tonik') ||
      inst.includes('cimb') ||
      name.includes('seabank') ||
      name.includes('maya') ||
      name.includes('gotyme') ||
      name.includes('tonik')
    );
  });

  const digitalBankBalance = digitalAccounts.reduce((sum, a) => sum + Math.max(0, a.balance), 0);
  // Default to a representative test balance if user has not yet categorized digital bank
  const simulatedBalance = digitalBankBalance > 0 ? digitalBankBalance : 50000;

  // Selected average interest rate (e.g. 4.5% p.a. net of 20% final withholding tax = 3.6% net)
  const [rate, setRate] = useState<number>(4.5); // SeaBank/GoTyme benchmark

  const grossAnnual = simulatedBalance * (rate / 100);
  const netAnnual = grossAnnual * 0.8; // 20% Philippine withholding tax
  const dailyEarnings = netAnnual / 365;
  const monthlyEarnings = netAnnual / 12;

  // Compare to traditional bank 0.0625%
  const tradAnnualNet = simulatedBalance * (0.000625 * 0.8);
  const annualGain = netAnnual - tradAnnualNet;

  return (
    <div className="w-full rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] p-4 shadow-xs">
      <div className="flex items-center justify-between pb-3 border-b border-[#F4E3D5] dark:border-[#2C241E] mb-3">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-emerald-100 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-400 flex items-center justify-center">
            <TrendingUp size={15} />
          </div>
          <div>
            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Digital Bank Yield Ladder
            </span>
            <span className="block text-[10px] text-[#6B6156] dark:text-[#A69B8F]">
              SeaBank • Maya • GoTyme • Tonik
            </span>
          </div>
        </div>

        <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400">
          Daily Accrual
        </span>
      </div>

      <div className="grid grid-cols-2 gap-3 mb-3">
        <div className="p-2.5 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029]">
          <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#A69B8F] block">
            Today's Passive Interest
          </span>
          <div className="text-xl font-extrabold text-emerald-600 dark:text-emerald-400 tabular-nums">
            +{formatPeso(dailyEarnings)}
          </div>
          <span className="text-[10px] text-[#6B6156] dark:text-[#A69B8F]">
            Credited daily at midnight
          </span>
        </div>

        <div className="p-2.5 rounded-xl bg-[#FBF5F0] dark:bg-[#251F1A] border border-[#F0D5C0] dark:border-[#383029]">
          <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#A69B8F] block">
            Annual Net Yield
          </span>
          <div className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
            +{formatPeso(netAnnual)}
          </div>
          <span className="text-[10px] font-semibold text-emerald-600 dark:text-emerald-400">
            +{formatPeso(annualGain, false)} vs old banks
          </span>
        </div>
      </div>

      {/* Preset Rate Pickers */}
      <div className="flex items-center justify-between text-xs pt-1">
        <span className="text-[11px] font-bold text-[#6B6156] dark:text-[#A69B8F]">
          Simulated APY:
        </span>
        <div className="flex items-center gap-1">
          {[
            { label: 'GoTyme 4%', val: 4.0 },
            { label: 'SeaBank 4.5%', val: 4.5 },
            { label: 'Maya 6-10%', val: 7.5 },
          ].map((item) => (
            <button
              key={item.label}
              type="button"
              onClick={() => setRate(item.val)}
              className={`px-2 py-0.5 rounded-md text-[10px] font-bold cursor-pointer transition-all ${
                rate === item.val
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03]'
                  : 'bg-[#FFEEDF] dark:bg-[#2F241C] text-[#6B6156] dark:text-[#A69B8F] hover:text-[#15120F]'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};
