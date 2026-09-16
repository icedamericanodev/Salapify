import React, { useState } from 'react';
import {
  X,
  ShieldAlert,
  ShieldCheck,
  TrendingUp,
  Calendar,
  Sparkles,
  Layers,
  ArrowRight,
  Plus,
  Trash2,
  Edit2,
  Clock,
  HelpCircle,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { IncomeStream, IncomeStreamType } from '../types';

interface SafeToSpendModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SafeToSpendModal: React.FC<SafeToSpendModalProps> = ({ isOpen, onClose }) => {
  const {
    safeToSpendAnalysis,
    decisionScenario,
    setDecisionScenario,
    incomeStreams,
    addIncomeStream,
    deleteIncomeStream,
    payday,
  } = useFinancial();

  const [activeTab, setActiveTab] = useState<'breakdown' | 'streams' | 'formula'>('breakdown');
  const [showAddStream, setShowAddStream] = useState(false);

  // New stream form state
  const [streamName, setStreamName] = useState('');
  const [streamType, setStreamType] = useState<IncomeStreamType>('semimonthly_salary');
  const [streamAmount, setStreamAmount] = useState('');
  const [streamDate, setStreamDate] = useState('');
  const [streamNotes, setStreamNotes] = useState('');
  const [streamConfirmed, setStreamConfirmed] = useState(true);

  if (!isOpen) return null;

  const {
    safeToSpendToday,
    safeToSpendUntilPayday,
    safeToSave,
    amountReserved,
    cashRunwayDays,
    cashRunwayMonths,
    reservedBreakdown,
    totalLiquidCash,
    scenario,
  } = safeToSpendAnalysis;

  const handleCreateStream = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(streamAmount);
    if (!streamName || isNaN(amount) || amount <= 0) return;

    addIncomeStream({
      name: streamName,
      type: streamType,
      expectedAmount: amount,
      nextExpectedDate: streamDate || new Date().toISOString().split('T')[0],
      notes: streamNotes,
      isConfirmed: streamConfirmed,
    });

    setStreamName('');
    setStreamAmount('');
    setStreamDate('');
    setStreamNotes('');
    setShowAddStream(false);
  };

  const streamTypeLabels: Record<IncomeStreamType, string> = {
    weekly_income: 'Weekly Income',
    semimonthly_salary: '15th & 30th Cutoff Salary',
    monthly_salary: 'Monthly Payroll',
    freelance: 'Freelance & Retainers',
    irregular: 'Irregular Gig Income',
    thirteenth_month: '13th-Month Pay Benefit',
    remittance: 'Remittance & Padala',
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-lg bg-[#FFF9F3] dark:bg-[#1E1915] rounded-3xl border border-[#F3DFCD] dark:border-[#383029] shadow-2xl flex flex-col max-h-[92vh] overflow-hidden text-[#15120F] dark:text-[#F6EFE8]">
        {/* Header */}
        <div className="px-5 py-4 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between shrink-0 bg-white/70 dark:bg-[#27201A]/70">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center">
              <Sparkles size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold tracking-tight">Safe-to-Spend Engine</h2>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                Payday-aware daily financial decision tool
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

        {/* Scenario Switcher Banner */}
        <div className="px-5 py-3 bg-[#FFEEDF] dark:bg-[#2A221C] border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3">
          <div className="flex items-center gap-2 min-w-0">
            <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
              Scenario Model:
            </span>
            <span className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] capitalize">
              {decisionScenario}
            </span>
          </div>

          <div className="flex p-0.5 bg-white/80 dark:bg-[#1A1410] rounded-xl border border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setDecisionScenario('conservative')}
              className={`px-2.5 py-1 text-xs font-medium rounded-lg transition-all cursor-pointer ${
                decisionScenario === 'conservative'
                  ? 'bg-[#B03C09] text-white shadow-xs'
                  : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
              }`}
            >
              Conservative
            </button>
            <button
              type="button"
              onClick={() => setDecisionScenario('optimistic')}
              className={`px-2.5 py-1 text-xs font-medium rounded-lg transition-all cursor-pointer ${
                decisionScenario === 'optimistic'
                  ? 'bg-[#B03C09] text-white shadow-xs'
                  : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
              }`}
            >
              Optimistic
            </button>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-[#F3DFCD] dark:border-[#383029] bg-white/40 dark:bg-[#1A1410]/40 px-5 pt-2">
          <button
            type="button"
            onClick={() => setActiveTab('breakdown')}
            className={`pb-2.5 px-3 text-xs font-semibold border-b-2 transition-colors cursor-pointer ${
              activeTab === 'breakdown'
                ? 'border-[#B03C09] text-[#B03C09] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                : 'border-transparent text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Outputs & Runway
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('streams')}
            className={`pb-2.5 px-3 text-xs font-semibold border-b-2 transition-colors cursor-pointer ${
              activeTab === 'streams'
                ? 'border-[#B03C09] text-[#B03C09] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                : 'border-transparent text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Income Streams ({incomeStreams.length})
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('formula')}
            className={`pb-2.5 px-3 text-xs font-semibold border-b-2 transition-colors cursor-pointer ${
              activeTab === 'formula'
                ? 'border-[#B03C09] text-[#B03C09] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                : 'border-transparent text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Audit & Math
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          {activeTab === 'breakdown' && (
            <>
              {/* Primary 4-Metric Grid */}
              <div className="grid grid-cols-2 gap-3">
                <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
                  <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                    Safe to Spend Today
                  </span>
                  <div className="text-xl sm:text-2xl font-black text-[#B03C09] dark:text-[#FF9A52] mt-1 tabular-nums">
                    {formatPeso(safeToSpendToday)}
                  </div>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1">
                    Daily discretionary spending quota
                  </p>
                </div>

                <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
                  <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                    Until Next Payday
                  </span>
                  <div className="text-xl sm:text-2xl font-black text-[#15120F] dark:text-[#F6EFE8] mt-1 tabular-nums">
                    {formatPeso(safeToSpendUntilPayday)}
                  </div>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1">
                    {payday.daysToPayday} days remaining in cutoff
                  </p>
                </div>

                <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
                  <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                    Safe to Save
                  </span>
                  <div className="text-xl sm:text-2xl font-black text-emerald-600 dark:text-emerald-400 mt-1 tabular-nums">
                    {formatPeso(safeToSave)}
                  </div>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1">
                    Guilt-free savings without starvation
                  </p>
                </div>

                <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
                  <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                    Must Remain Reserved
                  </span>
                  <div className="text-xl sm:text-2xl font-black text-amber-700 dark:text-amber-400 mt-1 tabular-nums">
                    {formatPeso(amountReserved)}
                  </div>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1">
                    Committed bills, debt & buffer
                  </p>
                </div>
              </div>

              {/* Cash Runway Section */}
              <div className="p-4 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Clock size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span className="text-xs font-bold uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
                      Cash Runway
                    </span>
                  </div>
                  <span className="text-xs font-black text-[#B03C09] dark:text-[#FF9A52]">
                    {cashRunwayMonths.toFixed(1)} Months ({cashRunwayDays} Days)
                  </span>
                </div>
                <div className="w-full bg-[#FFEEDF] dark:bg-[#1A1410] h-2 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full transition-all duration-300"
                    style={{ width: `${Math.min(100, (cashRunwayMonths / 6) * 100)}%` }}
                  />
                </div>
                <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                  Based on your historical daily burn rate. A healthy emergency runway is 3 to 6 months.
                </p>
              </div>

              {/* Reserved Breakdown List */}
              <div className="p-4 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                  Reserved Obligations Breakdown
                </h3>

                <div className="space-y-2 text-xs">
                  <div className="flex justify-between items-center py-1 border-b border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span className="text-[#7A6E63] dark:text-[#A89A8D]">Liquid Cash (Cash + Banks + E-Wallets)</span>
                    <span className="font-bold tabular-nums text-emerald-600 dark:text-emerald-400">
                      +{formatPeso(totalLiquidCash)}
                    </span>
                  </div>

                  <div className="flex justify-between items-center py-1 border-b border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span className="text-[#7A6E63] dark:text-[#A89A8D]">Upcoming Bills before Sweldo</span>
                    <span className="font-bold tabular-nums text-rose-600 dark:text-rose-400">
                      -{formatPeso(reservedBreakdown.bills)}
                    </span>
                  </div>

                  <div className="flex justify-between items-center py-1 border-b border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span className="text-[#7A6E63] dark:text-[#A89A8D]">Debt Minimums (Pahiram & Loans)</span>
                    <span className="font-bold tabular-nums text-rose-600 dark:text-rose-400">
                      -{formatPeso(reservedBreakdown.debtMinimums)}
                    </span>
                  </div>

                  <div className="flex justify-between items-center py-1 border-b border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span className="text-[#7A6E63] dark:text-[#A89A8D]">Monthly Installments (BNPL & SIP)</span>
                    <span className="font-bold tabular-nums text-rose-600 dark:text-rose-400">
                      -{formatPeso(reservedBreakdown.installments)}
                    </span>
                  </div>

                  <div className="flex justify-between items-center py-1">
                    <span className="text-[#7A6E63] dark:text-[#A89A8D]">
                      Safety Buffer ({decisionScenario === 'conservative' ? '15%' : '5%'})
                    </span>
                    <span className="font-bold tabular-nums text-amber-600 dark:text-amber-400">
                      -{formatPeso(reservedBreakdown.emergencyBuffer)}
                    </span>
                  </div>
                </div>
              </div>
            </>
          )}

          {activeTab === 'streams' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-bold">Configured Income Streams</h3>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                    Salary, freelance, 13th-month, and remittances
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddStream(!showAddStream)}
                  className="px-3 py-1.5 text-xs font-bold rounded-xl bg-[#B03C09] text-white hover:bg-[#8F3006] transition-colors cursor-pointer flex items-center gap-1.5"
                >
                  <Plus size={14} />
                  <span>Add Stream</span>
                </button>
              </div>

              {showAddStream && (
                <form
                  onSubmit={handleCreateStream}
                  className="p-4 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3"
                >
                  <h4 className="text-xs font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                    New Expected Stream
                  </h4>

                  <div>
                    <label className="text-[11px] font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Stream Name</label>
                    <input
                      type="text"
                      value={streamName}
                      onChange={(e) => setStreamName(e.target.value)}
                      placeholder="e.g. Design Freelance Retainer"
                      className="w-full mt-1 px-3 py-2 text-xs rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] focus:outline-hidden"
                      required
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-[11px] font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Stream Type</label>
                      <select
                        value={streamType}
                        onChange={(e) => setStreamType(e.target.value as IncomeStreamType)}
                        className="w-full mt-1 px-2.5 py-2 text-xs rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] focus:outline-hidden"
                      >
                        <option value="semimonthly_salary">Semimonthly (15/30)</option>
                        <option value="monthly_salary">Monthly Salary</option>
                        <option value="weekly_income">Weekly Income</option>
                        <option value="freelance">Freelance Contract</option>
                        <option value="irregular">Irregular / Gig</option>
                        <option value="thirteenth_month">13th-Month Pay</option>
                        <option value="remittance">Remittance Padala</option>
                      </select>
                    </div>

                    <div>
                      <label className="text-[11px] font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Expected Amount (₱)</label>
                      <input
                        type="number"
                        step="0.01"
                        value={streamAmount}
                        onChange={(e) => setStreamAmount(e.target.value)}
                        placeholder="0.00"
                        className="w-full mt-1 px-3 py-2 text-xs rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] focus:outline-hidden"
                        required
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-[11px] font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Next Expected Date</label>
                      <input
                        type="date"
                        value={streamDate}
                        onChange={(e) => setStreamDate(e.target.value)}
                        className="w-full mt-1 px-2.5 py-2 text-xs rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] focus:outline-hidden"
                      />
                    </div>
                    <div className="flex items-center pt-5">
                      <label className="flex items-center gap-2 cursor-pointer text-xs">
                        <input
                          type="checkbox"
                          checked={streamConfirmed}
                          onChange={(e) => setStreamConfirmed(e.target.checked)}
                          className="rounded text-[#B03C09] focus:ring-0"
                        />
                        <span>Confirmed stream</span>
                      </label>
                    </div>
                  </div>

                  <div>
                    <label className="text-[11px] font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Notes / Conditions</label>
                    <input
                      type="text"
                      value={streamNotes}
                      onChange={(e) => setStreamNotes(e.target.value)}
                      placeholder="e.g. Net after tax deduction and SSS/PhilHealth"
                      className="w-full mt-1 px-3 py-2 text-xs rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] focus:outline-hidden"
                    />
                  </div>

                  <div className="flex justify-end gap-2 pt-1">
                    <button
                      type="button"
                      onClick={() => setShowAddStream(false)}
                      className="px-3 py-1.5 text-xs text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      className="px-4 py-1.5 text-xs font-bold rounded-xl bg-[#B03C09] text-white hover:bg-[#8F3006] transition-colors cursor-pointer"
                    >
                      Save Stream
                    </button>
                  </div>
                </form>
              )}

              {/* Streams List */}
              <div className="space-y-2">
                {incomeStreams.map((s) => (
                  <div
                    key={s.id}
                    className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3 shadow-xs"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold truncate text-[#15120F] dark:text-[#F6EFE8]">
                          {s.name}
                        </span>
                        {s.isConfirmed ? (
                          <span className="px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300">
                            Confirmed
                          </span>
                        ) : (
                          <span className="px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300">
                            Tentative
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5 flex items-center gap-2">
                        <span>{streamTypeLabels[s.type]}</span>
                        {s.nextExpectedDate && <span>• Due: {s.nextExpectedDate}</span>}
                      </div>
                      {s.notes && (
                        <p className="text-[10px] text-[#9E9085] dark:text-[#88796C] mt-1 line-clamp-1 italic">
                          {s.notes}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-3 shrink-0">
                      <div className="text-right">
                        <span className="text-sm font-black text-emerald-600 dark:text-emerald-400 tabular-nums">
                          {formatPeso(s.expectedAmount)}
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => deleteIncomeStream(s.id)}
                        className="p-1.5 text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-950/40 rounded-lg transition-colors cursor-pointer"
                        title="Delete stream"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeTab === 'formula' && (
            <div className="p-4 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3 text-xs leading-relaxed">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                CPA Audit: Safe-to-Spend Standard
              </h3>

              <div className="p-3 bg-[#FFEEDF]/60 dark:bg-[#1A1410] rounded-xl font-mono text-[11px] text-[#5A5148] dark:text-[#C6B8AC] space-y-1">
                <p>Safe to Spend = Liquid Cash - Amount Reserved</p>
                <p>Amount Reserved = Bills + Debt Minimums + Installments + Buffer</p>
                <p>Safe to Spend Today = Safe to Spend / Days to Payday</p>
              </div>

              <div className="space-y-2 text-[#7A6E63] dark:text-[#A89A8D]">
                <p>
                  <strong>Conservative Model:</strong> Fully deducts 100% of upcoming scheduled bills, 100% of active debt minimums and BNPL installments, plus a 15% emergency cash buffer. Unconfirmed income streams are strictly excluded.
                </p>
                <p>
                  <strong>Optimistic Model:</strong> Deducts 80% of upcoming commitments, applies a 5% safety buffer, and incorporates confirmed upcoming remittances or freelance receivables.
                </p>
                <p>
                  <strong>13th-Month Pay Rule:</strong> Under Philippine Presidential Decree No. 851 and the TRAIN Law, 13th-month pay is tax-exempt up to ₱90,000. Salapify projects this separately so you avoid treating seasonal year-end bonuses as recurring operational liquidity.
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[#F3DFCD] dark:border-[#383029] bg-white/50 dark:bg-[#27201A]/50 flex justify-end shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-[#B03C09] text-white font-bold text-xs hover:bg-[#8F3006] transition-colors cursor-pointer"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
