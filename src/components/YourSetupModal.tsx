import React, { useState } from 'react';
import {
  X,
  Calendar,
  Layers,
  Receipt,
  ShieldCheck,
  PiggyBank,
  Check,
  Plus,
  Trash2,
  AlertCircle,
  HelpCircle,
  ChevronRight,
  TrendingUp,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { CategoryManager } from './CategoryManager';

interface YourSetupModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialTab?: 'payday' | 'categories' | 'recurring' | 'emergency' | 'privacy';
  onOpenTaxCalculator?: () => void;
}

export const YourSetupModal: React.FC<YourSetupModalProps> = ({
  isOpen,
  onClose,
  initialTab = 'payday',
  onOpenTaxCalculator,
}) => {
  const {
    payday,
    updatePayday,
    budgets,
    updateBudgetLimit,
    addBudget,
    deleteBudget,
    upcoming,
    addUpcoming,
    markUpcomingPaid,
    accounts,
    transactions,
    safeToSpend,
  } = useFinancial();

  const [activeTab, setActiveTab] = useState<'payday' | 'categories' | 'recurring' | 'emergency' | 'privacy'>(initialTab);

  // Payday state
  const [cycleType, setCycleType] = useState(payday.cycleType);
  const [nextPayday, setNextPayday] = useState(payday.nextPayday);
  const [daysToPayday, setDaysToPayday] = useState(payday.daysToPayday.toString());
  const [expectedIncome, setExpectedIncome] = useState(payday.expectedIncome.toString());
  const [paydaySaved, setPaydaySaved] = useState(false);

  // New Category state
  const [newCatName, setNewCatName] = useState('');
  const [newCatEmoji, setNewCatEmoji] = useState('🏷️');
  const [newCatLimit, setNewCatLimit] = useState('2000');
  const [showAddCat, setShowAddCat] = useState(false);

  // New Recurring Bill state
  const [showAddBill, setShowAddBill] = useState(false);
  const [billName, setBillName] = useState('');
  const [billAmount, setBillAmount] = useState('');
  const [billDueDate, setBillDueDate] = useState('Sep 25');
  const [billType, setBillType] = useState<'bill' | 'subscription'>('bill');

  if (!isOpen) return null;

  // Monthly expense estimation for emergency fund
  const monthlyExpenses = budgets.reduce((sum, b) => sum + b.limit, 0);
  const liquidCash = accounts
    .filter((a) => a.kind === 'cash')
    .reduce((sum, a) => sum + a.balance, 0);
  const ef3Months = monthlyExpenses * 3;
  const ef6Months = monthlyExpenses * 6;
  const efProgressPercent = Math.min(100, Math.round((liquidCash / ef3Months) * 100));

  const handleSavePayday = (e: React.FormEvent) => {
    e.preventDefault();
    const days = parseInt(daysToPayday, 10);
    const income = parseFloat(expectedIncome);

    updatePayday({
      cycleType,
      nextPayday: nextPayday.trim(),
      daysToPayday: isNaN(days) ? 4 : Math.max(1, days),
      expectedIncome: isNaN(income) ? 42000 : income,
    });

    setPaydaySaved(true);
    setTimeout(() => setPaydaySaved(false), 1500);
  };

  const handleAddCategorySubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const limit = parseFloat(newCatLimit);
    if (!newCatName.trim() || isNaN(limit) || limit <= 0) return;

    addBudget(newCatName.trim(), newCatEmoji, limit);
    setNewCatName('');
    setNewCatLimit('2000');
    setShowAddCat(false);
  };

  const handleAddBillSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(billAmount);
    if (!billName.trim() || isNaN(amount) || amount <= 0) return;

    addUpcoming({
      name: billName.trim(),
      amount,
      dueDate: billDueDate.trim(),
      type: billType,
    });

    setBillName('');
    setBillAmount('');
    setShowAddBill(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Dimmed backdrop */}
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      {/* Modal panel */}
      <div className="relative w-full max-w-lg bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl p-5 sm:p-6 border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom duration-250">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] gap-2">
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
              Your Setup
            </h2>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] truncate">
              Payday timeline, category rules, and recurring bills
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer shrink-0"
          >
            <X size={20} />
          </button>
        </div>

        {/* Segment Tabs */}
        <div className="flex gap-1 p-1 my-3 bg-[#FFEEDF]/60 dark:bg-[#14100D] rounded-xl overflow-x-auto shrink-0 scrollbar-none">
          <button
            type="button"
            onClick={() => setActiveTab('payday')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
              activeTab === 'payday'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <Calendar size={14} /> Payday Cycle
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('categories')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
              activeTab === 'categories'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <Layers size={14} /> Categories
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('recurring')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
              activeTab === 'recurring'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <Receipt size={14} /> Recurring
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('emergency')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
              activeTab === 'emergency'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <PiggyBank size={14} /> Emergency Fund
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('privacy')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
              activeTab === 'privacy'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
            }`}
          >
            <ShieldCheck size={14} /> Privacy
          </button>
        </div>

        {/* Content Body */}
        <div className="overflow-y-auto flex-1 pr-1 space-y-4">
          {/* TAB 1: PAYDAY EDITOR */}
          {activeTab === 'payday' && (
            <form onSubmit={handleSavePayday} className="space-y-4">
              <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Sweldo Pacing Preview
                </span>
                <div className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(safeToSpend)} Safe to Spend
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-0.5">
                  {formatPeso(safeToSpend / Math.max(1, parseInt(daysToPayday, 10) || 1))} a day until payday on {nextPayday}.
                </p>
              </div>

              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  Payday Cadence
                </label>
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { id: '15_30', label: '15th & 30th', desc: 'Standard PH' },
                    { id: 'monthly', label: 'Monthly', desc: 'Once a month' },
                    { id: 'weekly', label: 'Weekly', desc: 'Every Friday' },
                  ].map((cycle) => (
                    <button
                      key={cycle.id}
                      type="button"
                      onClick={() => setCycleType(cycle.id as any)}
                      className={`p-3 rounded-xl border text-left cursor-pointer transition-all ${
                        cycleType === cycle.id
                          ? 'bg-[#B03C09]/10 border-[#B03C09] dark:border-[#FF9A52]'
                          : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029]'
                      }`}
                    >
                      <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        {cycle.label}
                      </div>
                      <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                        {cycle.desc}
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Next Payday Label / Date
                  </label>
                  <input
                    type="text"
                    value={nextPayday}
                    onChange={(e) => setNextPayday(e.target.value)}
                    placeholder="e.g. Sep 15 or Monday"
                    className="w-full py-2.5 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Days until Payday
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="31"
                    value={daysToPayday}
                    onChange={(e) => setDaysToPayday(e.target.value)}
                    className="w-full py-2.5 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Expected Income per Cutoff (₱)
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    ₱
                  </span>
                  <input
                    type="number"
                    value={expectedIncome}
                    onChange={(e) => setExpectedIncome(e.target.value)}
                    className="w-full pl-7 pr-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>
                {onOpenTaxCalculator && (
                  <button
                    type="button"
                    onClick={() => {
                      onClose();
                      onOpenTaxCalculator();
                    }}
                    className="mt-1.5 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline flex items-center gap-1 cursor-pointer"
                  >
                    <span>Need help computing net take-home? Open Philippine Tax Calculator →</span>
                  </button>
                )}
              </div>

              <button
                type="submit"
                className={`w-full py-3 rounded-xl text-xs font-bold shadow-xs flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                  paydaySaved
                    ? 'bg-[#16643F] text-white'
                    : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-95'
                }`}
              >
                {paydaySaved ? (
                  <>
                    <Check size={16} /> Saved Changes
                  </>
                ) : (
                  'Update Payday Settings'
                )}
              </button>
            </form>
          )}

          {/* TAB 2: CATEGORIES MANAGER */}
          {activeTab === 'categories' && (
            <CategoryManager />
          )}

          {/* TAB 3: RECURRING BILLS */}
          {activeTab === 'recurring' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Recurring Bills & Subscriptions
                </span>
                <button
                  type="button"
                  onClick={() => setShowAddBill(!showAddBill)}
                  className="flex items-center gap-1 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                >
                  <Plus size={14} /> Add Recurring
                </button>
              </div>

              {showAddBill && (
                <form
                  onSubmit={handleAddBillSubmit}
                  className="p-3.5 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-3"
                >
                  <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Add Recurring Commitment
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                        Bill / Service Name
                      </label>
                      <input
                        type="text"
                        value={billName}
                        onChange={(e) => setBillName(e.target.value)}
                        placeholder="e.g. Meralco, Netflix"
                        className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                    <div>
                      <label className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                        Amount (₱)
                      </label>
                      <input
                        type="number"
                        value={billAmount}
                        onChange={(e) => setBillAmount(e.target.value)}
                        placeholder="2500"
                        className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                        Due Date
                      </label>
                      <input
                        type="text"
                        value={billDueDate}
                        onChange={(e) => setBillDueDate(e.target.value)}
                        placeholder="e.g. Sep 22, 15th"
                        className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                    <div>
                      <label className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                        Kind
                      </label>
                      <select
                        value={billType}
                        onChange={(e) => setBillType(e.target.value as any)}
                        className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
                      >
                        <option value="bill">Utility / Bill</option>
                        <option value="subscription">Subscription</option>
                      </select>
                    </div>
                  </div>
                  <div className="flex justify-end gap-2 pt-1">
                    <button
                      type="button"
                      onClick={() => setShowAddBill(false)}
                      className="px-3 py-1.5 rounded-xl text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      className="px-3.5 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold cursor-pointer"
                    >
                      Save Bill
                    </button>
                  </div>
                </form>
              )}

              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl bg-white dark:bg-[#27201A] overflow-hidden">
                {upcoming.map((u) => (
                  <div
                    key={u.id}
                    className={`p-3 flex items-center justify-between gap-3 ${
                      u.isPaid ? 'opacity-50 bg-[#16643F]/5' : ''
                    }`}
                  >
                    <div>
                      <div className="flex items-center gap-1.5">
                        <span
                          className={`text-xs font-bold ${
                            u.isPaid
                              ? 'line-through text-[#6B6156] dark:text-[#AC9E92]'
                              : 'text-[#15120F] dark:text-[#F6EFE8]'
                          }`}
                        >
                          {u.name}
                        </span>
                        {u.isPaid && (
                          <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-[#16643F]/20 text-[#16643F] dark:text-[#5FCB8E]">
                            Paid
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Due: {u.dueDate}
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      <span className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(u.amount)}
                      </span>
                      {!u.isIncome && !u.isPaid && (
                        <button
                          type="button"
                          onClick={() => markUpcomingPaid(u.id)}
                          className="px-2.5 py-1 rounded-lg bg-[#16643F]/10 text-[#16643F] dark:text-[#5FCB8E] hover:bg-[#16643F]/20 text-[11px] font-bold cursor-pointer transition-colors"
                        >
                          Pay
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 4: EMERGENCY FUND CALCULATOR */}
          {activeTab === 'emergency' && (
            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Filipino Emergency Runway
                </span>
                <div className="text-2xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(liquidCash)} Saved
                </div>
                <div className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mt-1">
                  Target 3-Month Runway:{' '}
                  <strong className="text-[#15120F] dark:text-[#F6EFE8]">
                    {formatPeso(ef3Months)}
                  </strong>
                </div>

                {/* Progress bar */}
                <div className="w-full h-2.5 rounded-full bg-[#F3DFCD] dark:bg-[#383029] mt-3 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-500"
                    style={{ width: `${efProgressPercent}%` }}
                  />
                </div>
                <div className="flex justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-1 font-semibold">
                  <span>{efProgressPercent}% of 3 months</span>
                  <span>6-Month Goal: {formatPeso(ef6Months)}</span>
                </div>
              </div>

              <div className="p-3.5 rounded-2xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] space-y-2">
                <div className="flex items-center gap-2 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  <TrendingUp size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>CPA & Investment Strategist Guidance</span>
                </div>
                <p className="text-xs leading-relaxed text-[#5A5148] dark:text-[#C6B8AC]">
                  Keep 1 to 2 months of emergency funds in liquid high-yield digital banks (MariBank, Maya, or GoTyme) earning 4.5% p.a. compound daily. Keep the remaining 4 months in Pag-IBIG MP2 for government-backed tax-free dividend growth (avg. 6.5% to 7% annual yield).
                </p>
              </div>
            </div>
          )}

          {/* TAB 5: PRIVACY RECEIPT */}
          {activeTab === 'privacy' && (
            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                <div className="flex items-center gap-2 text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  <ShieldCheck size={20} className="text-[#16643F] dark:text-[#5FCB8E]" />
                  <span>Privacy Receipt: 100% Offline Integrity</span>
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                  Salapify 3 runs strictly client-side on your device. We have no backend databases, no trackers, no external analytics, and no third-party telemetry.
                </p>
              </div>

              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl bg-white dark:bg-[#27201A] overflow-hidden text-xs">
                <div className="p-3 flex justify-between">
                  <span className="text-[#6B6156] dark:text-[#AC9E92]">Network requests sent</span>
                  <strong className="text-[#16643F] dark:text-[#5FCB8E]">0 bytes</strong>
                </div>
                <div className="p-3 flex justify-between">
                  <span className="text-[#6B6156] dark:text-[#AC9E92]">External cloud databases</span>
                  <strong className="text-[#16643F] dark:text-[#5FCB8E]">None (Zero)</strong>
                </div>
                <div className="p-3 flex justify-between">
                  <span className="text-[#6B6156] dark:text-[#AC9E92]">Data storage</span>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8]">Local Device IndexedStorage</strong>
                </div>
                <div className="p-3 flex justify-between">
                  <span className="text-[#6B6156] dark:text-[#AC9E92]">User Accounts & Logins</span>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8]">Anonymous & Keyless</strong>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
