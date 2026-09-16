import React, { useState } from 'react';
import { Info, Sparkles, Activity, ShieldCheck } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { SectionInfoModal, InfoTopic } from './SectionInfoModal';

interface HeroPanelProps {
  onOpenSafeToSpend?: () => void;
  onOpenHealthCheck?: () => void;
}

export const HeroPanel: React.FC<HeroPanelProps> = ({
  onOpenSafeToSpend,
  onOpenHealthCheck,
}) => {
  const {
    safeToSpend,
    safeToSpendPerDay,
    payday,
    decisionScenario,
    safeToSpendAnalysis,
    healthCheckInsights,
  } = useFinancial();
  const [infoTopic, setInfoTopic] = useState<InfoTopic | null>(null);

  // Health check summary status
  const criticalCount = healthCheckInsights.filter((i) => i.severity === 'critical').length;
  const warningCount = healthCheckInsights.filter((i) => i.severity === 'warning').length;

  // Progress along the current sweldo period (e.g. 15-day cycle)
  const cycleDays = 15;
  const daysPassed = cycleDays - payday.daysToPayday;
  const progressPercent = Math.min(100, Math.max(10, (daysPassed / cycleDays) * 100));

  return (
    <>
      <div
        className="w-full max-w-full rounded-3xl p-3.5 xs:p-4 sm:p-5 shadow-xs transition-all duration-300 relative overflow-hidden box-border"
        style={{
          background: 'linear-gradient(135deg, #FFD9B0 0%, #FEC078 50%, #FB9C52 100%)',
        }}
      >
        {/* Dark overlay for Gabi theme */}
        <div className="hidden dark:block absolute inset-0 bg-black/10 pointer-events-none rounded-3xl" />

        {/* Inner container with width boundaries and flexible grid/flex-wrap */}
        <div className="relative z-10 flex flex-col w-full max-w-full min-w-0 gap-y-2">
          {/* Top Kicker Row with responsive flex-wrap */}
          <div className="flex flex-wrap items-center justify-between gap-x-2 gap-y-1 w-full max-w-full min-w-0">
            <div className="flex items-center gap-1.5 min-w-0">
              <span
                className="text-[11px] sm:text-xs font-bold tracking-wider uppercase truncate"
                style={{ color: '#5E2C08' }}
              >
                Safe to Spend
              </span>
              <span
                className="px-1.5 py-0.2 rounded-md text-[9px] font-extrabold uppercase tracking-wider"
                style={{
                  backgroundColor: decisionScenario === 'conservative' ? '#5E2C08' : 'rgba(94, 44, 8, 0.2)',
                  color: decisionScenario === 'conservative' ? '#FFEEDF' : '#5E2C08',
                }}
              >
                {decisionScenario}
              </span>
              <button
                type="button"
                onClick={() => setInfoTopic('safe_to_spend')}
                className="inline-flex items-center justify-center w-5 h-5 rounded-full hover:bg-black/10 transition-colors cursor-pointer shrink-0"
                style={{ color: '#5E2C08' }}
                title="How Safe to Spend is calculated"
                aria-label="Safe to Spend information"
              >
                <Info size={13} strokeWidth={2.2} />
              </button>
            </div>

            <div className="flex items-center gap-1.5 ml-auto shrink-0">
              {/* Money Health Check Diagnostic Trigger */}
              {onOpenHealthCheck && (
                <button
                  type="button"
                  id="hero-health-check-btn"
                  onClick={onOpenHealthCheck}
                  className="text-[10px] sm:text-[11px] font-bold tracking-wider uppercase px-2 py-0.5 rounded-full hover:bg-black/10 transition-colors cursor-pointer flex items-center gap-1"
                  style={{ color: '#5E2C08' }}
                  title="Open Money Health Check"
                >
                  <Activity size={12} className="shrink-0" />
                  <span>Health Check</span>
                  {criticalCount > 0 ? (
                    <span className="w-2 h-2 rounded-full bg-rose-600 animate-pulse" />
                  ) : warningCount > 0 ? (
                    <span className="w-2 h-2 rounded-full bg-amber-600" />
                  ) : (
                    <span className="w-2 h-2 rounded-full bg-emerald-700" />
                  )}
                </button>
              )}

              {onOpenSafeToSpend && (
                <button
                  type="button"
                  id="hero-scenario-btn"
                  onClick={onOpenSafeToSpend}
                  className="text-[10px] sm:text-[11px] font-bold tracking-wider uppercase px-2 py-0.5 rounded-full hover:bg-black/10 transition-colors cursor-pointer flex items-center gap-1"
                  style={{ color: '#5E2C08' }}
                  title="Adjust decision scenarios & income streams"
                >
                  <Sparkles size={11} className="shrink-0" />
                  <span>Details</span>
                </button>
              )}
            </div>
          </div>

          {/* Amount and Pacing Subtitle Block */}
          <div
            className="flex flex-col w-full max-w-full min-w-0 my-0.5 cursor-pointer group"
            onClick={onOpenSafeToSpend}
            title="Click to view Safe to Spend and Cash Runway breakdown"
          >
            {/* Hero Amount with fluid responsive sizing that adapts without horizontal blowouts */}
            <div
              className="text-3xl xs:text-4xl sm:text-5xl font-extrabold font-display tracking-tight tabular-nums w-full max-w-full min-w-0 leading-tight break-words group-hover:opacity-90 transition-opacity"
              style={{ color: '#2A1207' }}
            >
              {formatPeso(safeToSpend)}
            </div>

            {/* Subtitle daily pace and runway */}
            <div
              className="flex flex-wrap items-center gap-x-2 text-xs sm:text-sm font-medium mt-1 leading-snug w-full max-w-full min-w-0 break-words"
              style={{ color: '#5E2C08' }}
            >
              <span>{formatPeso(safeToSpendPerDay, false)} a day until payday.</span>
              <span className="opacity-80">
                • Lasts {safeToSpendAnalysis.cashRunwayDays} days
              </span>
            </div>
          </div>

          {/* The Sweldo Rail Section: 5dp track with flexible responsive label grid */}
          <div className="flex flex-col gap-1.5 pt-1 mt-auto w-full max-w-full min-w-0">
            {/* 5dp visual track */}
            <div
              className="w-full max-w-full h-[5px] rounded-full overflow-hidden"
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

            {/* Responsive flex-wrap labels preventing text truncation on narrow screens */}
            <div
              className="flex flex-wrap items-center justify-between gap-x-2 gap-y-0.5 text-[11px] sm:text-xs font-semibold w-full max-w-full min-w-0"
              style={{ color: '#5E2C08' }}
            >
              <span className="min-w-0 truncate max-w-[55%] xs:max-w-none">
                {payday.daysToPayday} days to payday
              </span>
              <span className="shrink-0 text-right whitespace-nowrap ml-auto">
                {payday.lastPayday} to {payday.nextPayday.split(',')[0]}
              </span>
            </div>
          </div>
        </div>
      </div>

      <SectionInfoModal topic={infoTopic} onClose={() => setInfoTopic(null)} />
    </>
  );
};
