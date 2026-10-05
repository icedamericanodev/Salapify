import React, { useState } from 'react';
import {
  X,
  Activity,
  CheckCircle2,
  AlertTriangle,
  AlertOctagon,
  Info,
  ChevronDown,
  ChevronUp,
  ChevronRight,
  ArrowRight,
  Sparkles,
  ShieldCheck,
  Check,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { HealthCheckInsight } from '../types';

interface HealthCheckModalProps {
  isOpen: boolean;
  onClose: () => void;
  onNavigateTo?: (target: string) => void;
}

export const HealthCheckModal: React.FC<HealthCheckModalProps> = ({
  isOpen,
  onClose,
  onNavigateTo,
}) => {
  const { healthCheckInsights } = useFinancial();
  const [expandedInsightId, setExpandedInsightId] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<string>('all');
  const [appliedCorrections, setAppliedCorrections] = useState<Record<string, boolean>>({});

  if (!isOpen) return null;

  const toggleExpand = (id: string) => {
    setExpandedInsightId((prev) => (prev === id ? null : id));
  };

  const handleApplyCorrection = (insightId: string, correctionLabel?: string) => {
    setAppliedCorrections((prev) => ({ ...prev, [insightId]: true }));
    if (onNavigateTo && correctionLabel) {
      if (correctionLabel.toLowerCase().includes('reconcil')) {
        onNavigateTo('reports-reconciliation');
      } else if (correctionLabel.toLowerCase().includes('debt') || correctionLabel.toLowerCase().includes('avalanche')) {
        onNavigateTo('debt');
      } else if (correctionLabel.toLowerCase().includes('scenario') || correctionLabel.toLowerCase().includes('safe-to-spend')) {
        onNavigateTo('decision');
      } else if (correctionLabel.toLowerCase().includes('bill')) {
        onNavigateTo('bills');
      } else if (correctionLabel.toLowerCase().includes('budget')) {
        onNavigateTo('plan-budget');
      }
    }
  };

  const filteredInsights = filterType === 'all'
    ? healthCheckInsights
    : healthCheckInsights.filter((i) => i.severity === filterType);

  const statusSummary = {
    critical: healthCheckInsights.filter((i) => i.severity === 'critical').length,
    warning: healthCheckInsights.filter((i) => i.severity === 'warning').length,
    optimal: healthCheckInsights.filter((i) => i.severity === 'optimal').length,
  };

  const overallHealth = statusSummary.critical > 0
    ? { title: 'Needs Attention', color: 'text-rose-600 dark:text-rose-400', bg: 'bg-rose-50 dark:bg-rose-950/40 border-rose-200 dark:border-rose-900' }
    : statusSummary.warning > 1
    ? { title: 'Needs Attention', color: 'text-amber-600 dark:text-amber-400', bg: 'bg-amber-50 dark:bg-amber-950/40 border-amber-200 dark:border-amber-900' }
    : { title: 'Healthy & Resilient', color: 'text-emerald-600 dark:text-emerald-400', bg: 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-900' };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-xl bg-[#FFF9F3] dark:bg-[#1E1915] rounded-3xl border border-[#F3DFCD] dark:border-[#383029] shadow-2xl flex flex-col max-h-[92vh] overflow-hidden text-[#15120F] dark:text-[#F6EFE8]">
        {/* Modal Header */}
        <div className="px-5 py-4 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between shrink-0 bg-white/70 dark:bg-[#27201A]/70">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center">
              <Activity size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold tracking-tight">Money Health Check</h2>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                Check your financial standing across {healthCheckInsights.length} key indicators
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-black/5 dark:hover:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D] transition-colors cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Diagnosis Posture Card */}
        <div className="p-4 bg-[#FFEEDF] dark:bg-[#2A221C] border-b border-[#F3DFCD] dark:border-[#383029] shrink-0">
          <div className={`p-3 rounded-2xl border ${overallHealth.bg} flex items-center justify-between`}>
            <div>
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                Overall Status
              </span>
              <div className={`text-sm sm:text-base font-black ${overallHealth.color}`}>
                {overallHealth.title}
              </div>
            </div>

            <div className="flex items-center gap-2 text-xs font-bold">
              <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-900/60 dark:text-emerald-200">
                {statusSummary.optimal} Optimal
              </span>
              <span className="px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 dark:bg-amber-900/60 dark:text-amber-200">
                {statusSummary.warning} Warn
              </span>
              {statusSummary.critical > 0 && (
                <span className="px-2 py-0.5 rounded-full bg-rose-100 text-rose-800 dark:bg-rose-900/60 dark:text-rose-200">
                  {statusSummary.critical} Alert
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Filter Pills */}
        <div className="px-5 py-2.5 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center gap-2 overflow-x-auto shrink-0 bg-white/40 dark:bg-[#1A1410]/40">
          <button
            type="button"
            onClick={() => setFilterType('all')}
            className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors ${
              filterType === 'all'
                ? 'bg-[#B03C09] text-white'
                : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            All {healthCheckInsights.length} Indicators
          </button>
          <button
            type="button"
            onClick={() => setFilterType('critical')}
            className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors ${
              filterType === 'critical'
                ? 'bg-rose-600 text-white'
                : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Needs Action ({statusSummary.critical})
          </button>
          <button
            type="button"
            onClick={() => setFilterType('warning')}
            className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors ${
              filterType === 'warning'
                ? 'bg-amber-600 text-white'
                : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Watchlist ({statusSummary.warning})
          </button>
          <button
            type="button"
            onClick={() => setFilterType('optimal')}
            className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors ${
              filterType === 'optimal'
                ? 'bg-emerald-600 text-white'
                : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Optimal ({statusSummary.optimal})
          </button>
        </div>

        {/* Diagnostic Insights Cards */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-3">
          {filteredInsights.map((insight) => {
            const isExpanded = expandedInsightId === insight.id;
            const isApplied = appliedCorrections[insight.id];

            const statusIcon =
              insight.severity === 'optimal' ? (
                <CheckCircle2 size={16} className="text-emerald-500 shrink-0" />
              ) : insight.severity === 'warning' ? (
                <AlertTriangle size={16} className="text-amber-500 shrink-0" />
              ) : (
                <AlertOctagon size={16} className="text-rose-500 shrink-0" />
              );

            const statusBadgeColor =
              insight.severity === 'optimal'
                ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800'
                : insight.severity === 'warning'
                ? 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-800'
                : 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800';

            return (
              <div
                key={insight.id}
                className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs overflow-hidden transition-all duration-200"
              >
                {/* Accordion Trigger Header */}
                <div
                  onClick={() => toggleExpand(insight.id)}
                  className="p-3.5 sm:p-4 flex items-center justify-between gap-3 cursor-pointer hover:bg-black/2 dark:hover:bg-white/2"
                >
                  <div className="flex items-start gap-3 min-w-0 flex-1">
                    <div className="mt-0.5">{statusIcon}</div>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {insight.title}
                        </span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${statusBadgeColor}`}>
                          {insight.severity.toUpperCase()}
                        </span>
                        <span className="text-[11px] font-bold text-[#7A6E63] dark:text-[#A89A8D]">
                          {insight.scoreText}
                        </span>
                      </div>
                      <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D] mt-0.5 line-clamp-1">
                        {insight.whatHappened}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-[11px] font-medium text-[#7A6E63] dark:text-[#A89A8D]">
                      Based on records
                    </span>
                    <button
                      type="button"
                      className="p-1 text-[#7A6E63] dark:text-[#A89A8D]"
                    >
                      {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </button>
                  </div>
                </div>

                {/* Expanded Details Body */}
                {isExpanded && (
                  <div className="px-4 pb-4 pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 space-y-3.5 text-xs bg-[#FFF9F3]/50 dark:bg-[#1E1915]/50">
                    {/* What Happened */}
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block mb-0.5">
                        What Happened
                      </span>
                      <p className="text-[#15120F] dark:text-[#F6EFE8] leading-relaxed">
                        {insight.whatHappened}
                      </p>
                    </div>

                    {/* Why It Was Detected */}
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block mb-0.5">
                        Why Detected
                      </span>
                      <p className="text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                        {insight.whyDetected}
                      </p>
                    </div>

                    {/* Transactions Used */}
                    {insight.usedTransactions && insight.usedTransactions.length > 0 && (
                      <div>
                        <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block mb-1">
                          Audited Transactions & Records ({insight.usedTransactions.length})
                        </span>
                        <div className="flex flex-wrap gap-1.5">
                          {insight.usedTransactions.map((tx) => (
                            <span
                              key={tx.id || tx.name}
                              className="px-2 py-0.5 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-lg text-[10px] text-[#5A5148] dark:text-[#C6B8AC] font-mono"
                            >
                              {tx.name} (₱{tx.amount})
                            </span>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Assumptions */}
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block mb-0.5">
                        Mathematical Assumptions
                      </span>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] italic">
                        {insight.assumptions}
                      </p>
                    </div>

                    {/* Action & Correction Box */}
                    <div className="p-3 bg-white dark:bg-[#27201A] rounded-xl border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                      <div>
                        <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52] block mb-0.5">
                          Recommended Action
                        </span>
                        <p className="text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                          {insight.recommendedAction}
                        </p>
                      </div>

                      <div className="pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 flex items-center justify-between gap-2">
                        <span className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                          Option: {insight.correctionActionLabel || 'Review & Adjust'}
                        </span>

                        <button
                          type="button"
                          onClick={() => handleApplyCorrection(insight.id, insight.correctionActionLabel)}
                          className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
                            isApplied
                              ? 'bg-emerald-600 text-white'
                              : 'bg-[#B03C09] text-white hover:bg-[#8F3006]'
                          }`}
                        >
                          {isApplied ? (
                            <>
                              <Check size={12} />
                              <span>Acknowledged</span>
                            </>
                          ) : (
                            <>
                              <span>Apply Correction</span>
                              <ChevronRight size={13} />
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Modal Footer */}
        <div className="p-4 border-t border-[#F3DFCD] dark:border-[#383029] bg-white/50 dark:bg-[#27201A]/50 flex justify-end shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-[#B03C09] text-white font-bold text-xs hover:bg-[#8F3006] transition-colors cursor-pointer"
          >
            Close Diagnostics
          </button>
        </div>
      </div>
    </div>
  );
};
