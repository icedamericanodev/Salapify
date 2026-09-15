import React from 'react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

export const HeroPanel: React.FC = () => {
  const { safeToSpend, safeToSpendPerDay, payday } = useFinancial();

  // Progress along the current sweldo period (e.g. 15-day cycle)
  // Sep 1 to 15, current is day 11 -> 11/15 = 73%
  const cycleDays = 15;
  const daysPassed = cycleDays - payday.daysToPayday;
  const progressPercent = Math.min(100, Math.max(10, (daysPassed / cycleDays) * 100));

  return (
    <div
      className="w-full rounded-2xl p-5 shadow-sm transition-all duration-300 relative overflow-hidden"
      style={{
        background: 'linear-gradient(135deg, #FFD9B0 0%, #FEC078 50%, #FB9C52 100%)',
      }}
    >
      {/* Dark overlay for Gabi theme */}
      <div className="hidden dark:block absolute inset-0 bg-black/10 pointer-events-none rounded-2xl" />

      <div className="relative z-10 flex flex-col">
        {/* Kicker */}
        <span
          className="text-xs font-bold tracking-widest uppercase mb-1.5"
          style={{ color: '#5E2C08' }}
        >
          Safe to Spend
        </span>

        {/* Hero Amount in measured hero typography */}
        <div
          className="text-4xl sm:text-5xl font-extrabold tracking-tight mb-2"
          style={{ color: '#2A1207' }}
        >
          {formatPeso(safeToSpend)}
        </div>

        {/* Sentence */}
        <p
          className="text-sm font-medium mb-5"
          style={{ color: '#5E2C08' }}
        >
          {formatPeso(safeToSpendPerDay, false)} a day until payday on Monday.
        </p>

        {/* The Sweldo Rail: 5dp (approx 5px) track filled to today in quiet ink */}
        <div className="flex flex-col gap-2 mt-1">
          <div
            className="w-full h-[5px] rounded-full overflow-hidden"
            style={{ backgroundColor: 'rgba(94, 44, 8, 0.22)' }}
          >
            <div
              className="h-full rounded-full transition-all duration-500 ease-out"
              style={{
                width: `${progressPercent}%`,
                backgroundColor: '#5E2C08',
              }}
            />
          </div>

          {/* End labels */}
          <div className="flex justify-between items-center text-xs font-semibold" style={{ color: '#5E2C08' }}>
            <span>{payday.daysToPayday} days to payday</span>
            <span>{payday.lastPayday} to {payday.nextPayday.split(',')[0]}</span>
          </div>
        </div>
      </div>
    </div>
  );
};
