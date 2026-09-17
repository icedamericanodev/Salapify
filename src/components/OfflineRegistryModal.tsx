import React, { useState, useEffect } from 'react';
import {
  X,
  ShieldAlert,
  HelpCircle,
  Clock,
  Sparkles,
  ArrowRight,
  Database,
  Trash2,
  CheckCircle2,
  FileText,
  Lock,
} from 'lucide-react';
import {
  SYSTEM_LIMITATIONS,
  getSystemLimitationLogs,
  SystemLimitationItem,
  LimitationRequestLog,
} from '../utils/panKnowledgeRepository';

interface OfflineRegistryModalProps {
  isOpen: boolean;
  onClose: () => void;
  onNavigateAction?: (actionId: string, payload?: any) => void;
}

export const OfflineRegistryModal: React.FC<OfflineRegistryModalProps> = ({
  isOpen,
  onClose,
  onNavigateAction,
}) => {
  const [activeTab, setActiveTab] = useState<'limitations' | 'user_logs'>('limitations');
  const [logs, setLogs] = useState<LimitationRequestLog[]>([]);
  const [selectedLimitation, setSelectedLimitation] = useState<SystemLimitationItem | null>(null);

  useEffect(() => {
    if (isOpen) {
      setLogs(getSystemLimitationLogs());
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleClearLogs = () => {
    localStorage.removeItem('salapify_limitation_requests_log');
    setLogs([]);
  };

  const getStatusBadge = (status: SystemLimitationItem['futureStatus']) => {
    if (status === 'strictly_prohibited_privacy') {
      return (
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#9E2C1B]/10 text-[#9E2C1B] dark:bg-[#FF8A6E]/10 dark:text-[#FF8A6E] border border-[#9E2C1B]/20">
          <Lock size={10} /> Prohibited for Privacy
        </span>
      );
    }
    if (status === 'planned') {
      return (
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-500/20">
          <Sparkles size={10} /> Planned for Future Updates
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-700 dark:text-amber-400 border border-amber-500/20">
        <Clock size={10} /> Under Feasibility Review
      </span>
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-lg bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl sm:rounded-3xl shadow-2xl flex flex-col max-h-[88vh] overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="px-5 py-4 bg-white/90 dark:bg-[#1E1915]/90 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] flex items-center justify-center shadow-xs">
              <Database size={18} strokeWidth={2.4} />
            </div>
            <div>
              <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                System Limitations &amp; Offline Registry
              </h2>
              <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                Guaranteed privacy boundaries and logged user requests
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-[#6B6156] dark:text-[#AC9E92] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
            aria-label="Close modal"
          >
            <X size={18} />
          </button>
        </div>

        {/* Tab switcher */}
        <div className="px-5 pt-3 pb-1 bg-white/50 dark:bg-[#1E1915]/50 flex gap-2 shrink-0 border-b border-[#F3DFCD]/60 dark:border-[#383029]/60">
          <button
            type="button"
            onClick={() => setActiveTab('limitations')}
            className={`pb-2 text-xs font-bold transition-all border-b-2 cursor-pointer flex items-center gap-1.5 ${
              activeTab === 'limitations'
                ? 'border-[#B03C09] text-[#B03C09] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                : 'border-transparent text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <ShieldAlert size={14} /> Known Limitations ({SYSTEM_LIMITATIONS.length})
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('user_logs')}
            className={`pb-2 text-xs font-bold transition-all border-b-2 cursor-pointer flex items-center gap-1.5 ${
              activeTab === 'user_logs'
                ? 'border-[#B03C09] text-[#B03C09] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                : 'border-transparent text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <FileText size={14} /> Logged Inquiries ({logs.length})
          </button>
        </div>

        {/* Content Body */}
        <div className="p-4 sm:p-5 overflow-y-auto space-y-4 flex-1">
          {activeTab === 'limitations' && (
            <div className="space-y-3">
              <div className="p-3 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Salapify is an <strong>offline-first financial ledger</strong>. We maintain explicit security guardrails to protect your bank credentials, SMS OTPs, and personal identity from ever touching external servers.
              </div>

              <div className="space-y-2.5">
                {SYSTEM_LIMITATIONS.map((lim) => {
                  const isExpanded = selectedLimitation?.id === lim.id;
                  return (
                    <div
                      key={lim.id}
                      className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] transition-all space-y-2"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0 flex-1">
                          <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                            {lim.title}
                          </h3>
                          <div className="mt-1">
                            {getStatusBadge(lim.futureStatus)}
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => setSelectedLimitation(isExpanded ? null : lim)}
                          className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer shrink-0"
                        >
                          {isExpanded ? 'Hide' : 'Details'}
                        </button>
                      </div>

                      <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                        {lim.reason}
                      </p>

                      <div className="p-2.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-1">
                        <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52] block">
                          Offline Workaround
                        </span>
                        <p className="text-[11px] text-[#15120F] dark:text-[#F6EFE8]">
                          {lim.offlineWorkaround}
                        </p>
                      </div>

                      {lim.actionId && lim.actionLabel && onNavigateAction && (
                        <div className="pt-1 flex justify-end">
                          <button
                            type="button"
                            onClick={() => {
                              onClose();
                              onNavigateAction(lim.actionId!);
                            }}
                            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] hover:opacity-95 transition-opacity cursor-pointer"
                          >
                            <span>{lim.actionLabel}</span>
                            <ArrowRight size={12} />
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {activeTab === 'user_logs' && (
            <div className="space-y-3">
              <div className="p-3 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed flex items-start justify-between gap-2">
                <span>
                  When you ask Pan questions that exceed current system boundaries, the query is logged strictly to your device's <strong>localStorage</strong> (<code>salapify_limitation_requests_log</code>) so features can be evaluated for future offline updates.
                </span>
                {logs.length > 0 && (
                  <button
                    type="button"
                    onClick={handleClearLogs}
                    className="p-1.5 rounded-lg text-[#9E2C1B] hover:bg-[#9E2C1B]/10 transition-colors shrink-0 cursor-pointer"
                    title="Clear Logged Inquiries"
                  >
                    <Trash2 size={15} />
                  </button>
                )}
              </div>

              {logs.length === 0 ? (
                <div className="p-8 text-center rounded-2xl border border-dashed border-[#F3DFCD] dark:border-[#383029] bg-white/40 dark:bg-[#1E1915]/40 space-y-2">
                  <CheckCircle2 size={28} className="mx-auto text-[#16643F] dark:text-[#5FCB8E]" />
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    No Logged Limitation Inquiries Yet
                  </h4>
                  <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] max-w-xs mx-auto">
                    If you ask Pan about unsupported features (like automatic bank scraping or sending live InstaPay transfers), your request will appear here.
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  {logs.map((log) => {
                    const lim = SYSTEM_LIMITATIONS.find((l) => l.id === log.limitationId);
                    return (
                      <div
                        key={log.id}
                        className="p-3 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] space-y-1.5"
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                            &quot;{log.query}&quot;
                          </span>
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#FFEEDF] dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shrink-0">
                            Asked {log.count}x
                          </span>
                        </div>
                        <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] flex items-center justify-between">
                          <span>Matched Guardrail: <strong>{lim?.title || log.limitationId}</strong></span>
                          <span>{new Date(log.timestamp).toLocaleDateString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 bg-white/80 dark:bg-[#1E1915]/80 border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between text-[11px] text-[#6B6156] dark:text-[#AC9E92] shrink-0">
          <span>100% Client-Side Storage</span>
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-1.5 rounded-xl font-bold text-xs bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] hover:opacity-95 transition-opacity cursor-pointer"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
