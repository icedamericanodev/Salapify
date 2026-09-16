import React from 'react';
import { X, HandCoins, ShieldCheck, Calculator, Sparkles, AlertCircle, ArrowRightLeft, CalendarClock } from 'lucide-react';

export type InfoTopic = 'debt' | 'safe_to_spend' | 'sweldo_rail' | 'budget' | 'net_worth' | 'upcoming';

interface SectionInfoModalProps {
  topic: InfoTopic | null;
  onClose: () => void;
}

interface TopicData {
  title: string;
  subtitle: string;
  badge?: string;
  items: Array<{
    title: string;
    description: string;
    icon: React.ReactNode;
  }>;
  formula?: string;
}

const TOPIC_DETAILS: Record<InfoTopic, TopicData> = {
  debt: {
    title: 'Debt Both Ways',
    subtitle: 'Understanding Filipino debt dynamics and the Debt Beam',
    badge: 'CPA & Behavioral Guide',
    items: [
      {
        title: 'Utang & Pahiram (Both Directions)',
        description:
          'In Filipino culture, debt flows in two directions: what you owe to financial institutions/lenders, and what friends or family owe you from pahiram, split dining bills, or advance groceries.',
        icon: <HandCoins size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
      {
        title: 'The 5dp Proportional Debt Beam',
        description:
          'The colored beam at the top balances receivables (green, what is owed to you) against payables (rust orange, what you owe) so you always know your net exposure at a glance.',
        icon: <Sparkles size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
      {
        title: 'Installment Terms vs. Flexible Loans',
        description:
          'Scheduled debts show term progress (e.g. 4 of 6 payments) with upcoming due dates. Flexible personal debts let you log payments as cash flow permits.',
        icon: <CalendarClock size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
      {
        title: 'Settlement Celebration',
        description:
          'When you settle a debt completely, Salapify holds a 1.2s celebratory green state before moving the record to the Settled archive.',
        icon: <ShieldCheck size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
    ],
  },
  safe_to_spend: {
    title: 'Safe to Spend',
    subtitle: 'How your daily guilt-free spending limit is calculated',
    badge: 'Philippine Budget Standard',
    items: [
      {
        title: 'The Core Formula',
        description:
          'Safe to Spend subtracts all upcoming bills, scheduled debt installments, and committed savings from your liquid balances, leaving only what is truly safe to spend.',
        icon: <Calculator size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
      {
        title: 'Daily Sweldo Pacing',
        description:
          'Your total safe amount is divided by the exact days remaining until your next 15th or 30th sweldo, giving you a realistic daily target.',
        icon: <CalendarClock size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
      {
        title: 'Transfers Never Affect Safe to Spend',
        description:
          'Moving money between your own accounts (e.g., BPI to GCash) is a double-entry transfer, never an expense, keeping your net spend capacity intact.',
        icon: <ArrowRightLeft size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
    ],
    formula: 'Safe to Spend = Liquid Balances - Upcoming Bills - Committed Debts',
  },
  sweldo_rail: {
    title: 'The Sweldo Rail',
    subtitle: '15th and 30th Philippine payday cycle pacing',
    badge: 'Cash Flow Pacing',
    items: [
      {
        title: 'Bi-Monthly Cadence',
        description:
          'Built for typical Philippine payroll cycles (15th and 30th, or end of month). The quiet 5dp track fills as each day passes.',
        icon: <CalendarClock size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
      {
        title: 'Avoiding Petsa de Peligro',
        description:
          'By comparing the percentage of days elapsed with your remaining funds, you can see if you are spending faster than time is passing.',
        icon: <AlertCircle size={16} className="text-[#9E2C1B] dark:text-[#FF8A6E]" />,
      },
    ],
  },
  budget: {
    title: 'Budget Limits & Pacing',
    subtitle: 'Category tracking calibrated to your sweldo cycle',
    badge: 'Category Rules',
    items: [
      {
        title: 'Watch Closely vs. On Track',
        description:
          'Any category that has reached 80% or more of its allocated limit is flagged under Watch Closely to prevent surprises before payday.',
        icon: <AlertCircle size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
      {
        title: 'Flexible Category Adjustments',
        description:
          'Tap any category card at any time to adjust its limit. Your historical ledger entries remain completely untouched.',
        icon: <Sparkles size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
    ],
  },
  net_worth: {
    title: 'Net Worth Calculation',
    subtitle: 'True balance sheet for Philippine accounts',
    badge: 'CPA Standard',
    items: [
      {
        title: 'Total Assets',
        description:
          'Includes all physical cash, e-wallets (GCash, Maya), bank savings, high-yield digital accounts, and money owed to you by others.',
        icon: <ShieldCheck size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
      {
        title: 'Total Liabilities',
        description:
          'Includes all credit card balances, personal loans, installment balances, and money you owe to others.',
        icon: <HandCoins size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
    ],
    formula: 'Net Worth = Total Assets - Total Liabilities',
  },
  upcoming: {
    title: 'Upcoming Commitments',
    subtitle: 'Protected payables and recurring subscriptions',
    badge: 'Commitment Protection',
    items: [
      {
        title: 'Protected from Daily Spending',
        description:
          'Bills due before your next payday are locked away from your Safe to Spend so you never accidentally spend rent or electric bill money.',
        icon: <CalendarClock size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />,
      },
      {
        title: 'One-Tap Settlement',
        description:
          'When you pay a bill, tap "Pay" to automatically record the expense into your ledger and adjust the source account balance in one step.',
        icon: <ArrowRightLeft size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
      },
    ],
  },
};

export const SectionInfoModal: React.FC<SectionInfoModalProps> = ({ topic, onClose }) => {
  if (!topic) return null;
  const data = TOPIC_DETAILS[topic];
  if (!data) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs animate-in fade-in duration-200">
      <div
        className="fixed inset-0"
        onClick={onClose}
        aria-hidden="true"
      />
      <div className="relative w-full max-w-sm bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden animate-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4 gap-2">
          <div className="min-w-0 flex-1">
            {data.badge && (
              <span className="inline-block text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] mb-1">
                {data.badge}
              </span>
            )}
            <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
              {data.title}
            </h2>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mt-0.5">
              {data.subtitle}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer shrink-0"
            aria-label="Close details"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable details */}
        <div className="overflow-y-auto space-y-3.5 pr-1 text-xs">
          {data.items.map((item, idx) => (
            <div
              key={idx}
              className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD]/60 dark:border-[#383029]/60 flex items-start gap-2.5"
            >
              <div className="p-1.5 rounded-xl bg-white dark:bg-[#27201A] shadow-2xs shrink-0 mt-0.5">
                {item.icon}
              </div>
              <div className="min-w-0 flex-1">
                <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] mb-0.5">
                  {item.title}
                </h3>
                <p className="text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                  {item.description}
                </p>
              </div>
            </div>
          ))}

          {data.formula && (
            <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-center">
              <span className="text-[10px] font-bold text-amber-800 dark:text-amber-300 uppercase tracking-wider block mb-0.5">
                Formula
              </span>
              <span className="font-mono text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                {data.formula}
              </span>
            </div>
          )}
        </div>

        {/* Dismiss Button */}
        <div className="pt-4 mt-2 border-t border-[#F3DFCD] dark:border-[#383029]">
          <button
            type="button"
            onClick={onClose}
            className="w-full py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 active:scale-98 transition-all cursor-pointer"
          >
            Got it
          </button>
        </div>
      </div>
    </div>
  );
};
