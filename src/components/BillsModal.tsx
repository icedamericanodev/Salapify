import React, { useState, useMemo } from 'react';
import {
  X,
  CalendarCheck,
  Zap,
  Music,
  CreditCard,
  Check,
  Plus,
  Trash2,
  AlertCircle,
  TrendingDown,
  CalendarClock,
  Clock,
  Home,
  Shield,
  GraduationCap,
  Landmark,
  Send,
  Calendar as CalendarIcon,
  Layers,
  AlertTriangle,
  ArrowRight,
  TrendingUp,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { UpcomingItem } from '../types';

interface BillsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

type BillTab = 'list' | 'calendar' | 'cashflow';

export const BillsModal: React.FC<BillsModalProps> = ({ isOpen, onClose }) => {
  const {
    upcoming,
    accounts,
    markUpcomingPaid,
    addUpcoming,
    deleteUpcoming,
    payday,
    safeToSpendAnalysis,
  } = useFinancial();

  const [activeTab, setActiveTab] = useState<BillTab>('list');

  // Selected bill to pay
  const [payingItem, setPayingItem] = useState<UpcomingItem | null>(null);
  const [selectedAccountId, setSelectedAccountId] = useState<string>('');
  const [paidToast, setPaidToast] = useState<string | null>(null);

  // New bill modal / inline form
  const [isAddingNew, setIsAddingNew] = useState(false);
  const [newName, setNewName] = useState('');
  const [newAmount, setNewAmount] = useState('');
  const [newDueDate, setNewDueDate] = useState('');
  const [newType, setNewType] = useState<
    'bill' | 'subscription' | 'debt' | 'rent' | 'insurance' | 'tuition' | 'government' | 'remittance'
  >('bill');
  const [newRecurrence, setNewRecurrence] = useState<'recurring' | 'one_time' | 'variable'>('recurring');
  const [newGraceDays, setNewGraceDays] = useState('3');
  const [newLateFee, setNewLateFee] = useState('100');
  const [newReminderDays, setNewReminderDays] = useState('2');

  // Calendar state
  const [selectedCalendarDay, setSelectedCalendarDay] = useState<number | null>(null);

  if (!isOpen) return null;

  // Filter bills & subscriptions
  const unpaidItems = upcoming.filter((u) => !u.isPaid);
  const paidItems = upcoming.filter((u) => u.isPaid);

  const totalUpcomingBills = unpaidItems
    .filter((u) => !u.isIncome)
    .reduce((sum, u) => sum + u.amount, 0);

  const getIcon = (type: string, name: string) => {
    const n = name.toLowerCase();
    const t = (type || '').toLowerCase();
    if (t === 'payday') return CalendarCheck;
    if (n.includes('rent') || t === 'rent') return Home;
    if (n.includes('insurance') || t === 'insurance' || n.includes('pru') || n.includes('sunlife')) return Shield;
    if (n.includes('tuition') || t === 'tuition' || n.includes('school')) return GraduationCap;
    if (n.includes('sss') || n.includes('philhealth') || n.includes('pag-ibig') || n.includes('pagibig') || t === 'government') return Landmark;
    if (n.includes('remittance') || n.includes('padala') || t === 'remittance') return Send;
    if (n.includes('spotify') || n.includes('netflix') || t === 'subscription') return Music;
    if (n.includes('meralco') || n.includes('electric') || n.includes('water') || n.includes('wifi') || n.includes('pldt') || t === 'bill') return Zap;
    return CreditCard;
  };

  const handleConfirmPay = () => {
    if (!payingItem) return;
    const accId = selectedAccountId || accounts[0]?.id;
    markUpcomingPaid(payingItem.id, accId);
    setPaidToast(`Paid ${payingItem.name}! Transaction logged to ledger.`);
    setPayingItem(null);
    setTimeout(() => {
      setPaidToast(null);
    }, 2500);
  };

  const handleCreateBill = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(newAmount);
    if (!newName.trim() || isNaN(amount) || amount <= 0) return;

    addUpcoming({
      name: newName.trim(),
      amount,
      dueDate: newDueDate.trim() || 'Next Cutoff',
      type: newType,
      isIncome: false,
    });

    setNewName('');
    setNewAmount('');
    setNewDueDate('');
    setIsAddingNew(false);
  };

  // ---------------- Calendar Generation ----------------
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();
  const daysInCurrentMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
  const firstDayOfWeek = new Date(currentYear, currentMonth, 1).getDay(); // 0 = Sunday

  // Group bills by day of month (extracting numbers from dueDate like "15th", "Sep 15", "2026-09-15")
  const billsByDay = useMemo(() => {
    const map: { [day: number]: UpcomingItem[] } = {};
    upcoming.forEach((item) => {
      // try to extract day number
      const match = item.dueDate.match(/\d+/);
      if (match) {
        const day = parseInt(match[0], 10);
        if (day >= 1 && day <= 31) {
          if (!map[day]) map[day] = [];
          map[day].push(item);
        }
      }
    });
    return map;
  }, [upcoming]);

  // ---------------- Cash Flow Impact Timeline ----------------
  const cashFlowTimeline = useMemo(() => {
    let currentBalance = safeToSpendAnalysis.totalLiquidCash;
    const items = [...unpaidItems].sort((a, b) => {
      const dayA = parseInt(a.dueDate.match(/\d+/)?.[0] || '99', 10);
      const dayB = parseInt(b.dueDate.match(/\d+/)?.[0] || '99', 10);
      return dayA - dayB;
    });

    const trajectory = [
      {
        name: 'Current Total Liquid Cash',
        amount: currentBalance,
        impact: 0,
        runningBalance: currentBalance,
        date: 'Today',
        isBase: true,
      },
    ];

    items.forEach((item) => {
      if (item.isIncome) {
        currentBalance += item.amount;
        trajectory.push({
          name: item.name,
          amount: item.amount,
          impact: item.amount,
          runningBalance: currentBalance,
          date: item.dueDate,
          isBase: false,
        });
      } else {
        currentBalance -= item.amount;
        trajectory.push({
          name: item.name,
          amount: item.amount,
          impact: -item.amount,
          runningBalance: currentBalance,
          date: item.dueDate,
          isBase: false,
        });
      }
    });

    return trajectory;
  }, [unpaidItems, safeToSpendAnalysis.totalLiquidCash]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-lg bg-white dark:bg-[#27201A] rounded-2xl p-4 sm:p-5 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] gap-2">
          <div className="flex items-center gap-2 min-w-0 flex-1">
            <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0">
              <CalendarClock size={18} />
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="text-sm sm:text-base font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                Bills, Subscriptions &amp; Commitments
              </h2>
              <p className="text-[10px] sm:text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate">
                Track upcoming commitments, renewal grace periods &amp; cash flow impact
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer shrink-0"
          >
            <X size={18} />
          </button>
        </div>

        {/* Navigation Sub-Tabs */}
        <div className="flex p-1 my-2 bg-[#FFEEDF]/40 dark:bg-[#1A1410] rounded-xl border border-[#F3DFCD] dark:border-[#383029] gap-1">
          <button
            type="button"
            onClick={() => setActiveTab('list')}
            className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
              activeTab === 'list'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            <Layers size={13} />
            <span>Bill List ({unpaidItems.length})</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('calendar')}
            className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
              activeTab === 'calendar'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            <CalendarIcon size={13} />
            <span>Calendar View</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('cashflow')}
            className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
              activeTab === 'cashflow'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            <TrendingDown size={13} />
            <span>Cash Flow Impact</span>
          </button>
        </div>

        {/* Summary Card */}
        <div className="p-3 mb-2 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D]/60 border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between">
          <div className="flex flex-col">
            <span className="text-[10px] sm:text-[11px] font-medium text-[#6B6156] dark:text-[#AC9E92]">
              Total Commitments Due ({payday.daysToPayday}d to Sweldo)
            </span>
            <span className="text-base sm:text-lg font-bold text-[#15120F] dark:text-[#F6EFE8]">
              {formatPeso(totalUpcomingBills)}
            </span>
          </div>
          <button
            type="button"
            onClick={() => setIsAddingNew(!isAddingNew)}
            className="px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold flex items-center gap-1 hover:opacity-90 transition-opacity cursor-pointer shadow-xs"
          >
            <Plus size={14} /> {isAddingNew ? 'Cancel' : 'Add Bill'}
          </button>
        </div>

        {/* Success Toast */}
        {paidToast && (
          <div className="mb-2 p-2.5 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-700 dark:text-emerald-400 text-xs font-semibold flex items-center gap-2">
            <Check size={14} className="shrink-0" />
            <span>{paidToast}</span>
          </div>
        )}

        {/* Inline Add Bill Form */}
        {isAddingNew && (
          <form onSubmit={handleCreateBill} className="p-3.5 mb-3 rounded-xl border border-[#B03C09]/30 bg-[#B03C09]/5 dark:bg-[#FF9A52]/5 space-y-2.5 overflow-y-auto max-h-60">
            <div className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
              Add New Bill, Subscription, or Scheduled Obligation
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Bill Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Meralco, Manila Water, SSS"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8]"
                />
              </div>
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Amount (₱)
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  placeholder="0.00"
                  value={newAmount}
                  onChange={(e) => setNewAmount(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8]"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Due Date / Frequency
                </label>
                <input
                  type="text"
                  placeholder="e.g. 15th of month, Sep 20"
                  value={newDueDate}
                  onChange={(e) => setNewDueDate(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8]"
                />
              </div>
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Category
                </label>
                <select
                  value={newType}
                  onChange={(e) => setNewType(e.target.value as any)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8]"
                >
                  <option value="bill">Utility (Electricity/Water/Internet)</option>
                  <option value="subscription">Digital Subscription (Netflix/Spotify)</option>
                  <option value="rent">Rent &amp; Housing</option>
                  <option value="insurance">Insurance Premium (Life/Health)</option>
                  <option value="tuition">Tuition &amp; Education</option>
                  <option value="government">Government (SSS/PhilHealth/Pag-IBIG)</option>
                  <option value="remittance">Family Remittance / Padala</option>
                  <option value="debt">Loan / Credit Card Minimum</option>
                </select>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2 text-[10px]">
              <div>
                <label className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5">Recurrence</label>
                <select
                  value={newRecurrence}
                  onChange={(e) => setNewRecurrence(e.target.value as any)}
                  className="w-full p-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]"
                >
                  <option value="recurring">Monthly Recurring</option>
                  <option value="variable">Variable Amount</option>
                  <option value="one_time">One-Time Bill</option>
                </select>
              </div>
              <div>
                <label className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5">Grace Period</label>
                <input
                  type="number"
                  placeholder="3 days"
                  value={newGraceDays}
                  onChange={(e) => setNewGraceDays(e.target.value)}
                  className="w-full p-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]"
                />
              </div>
              <div>
                <label className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5">Late Fee (₱)</label>
                <input
                  type="number"
                  placeholder="₱100"
                  value={newLateFee}
                  onChange={(e) => setNewLateFee(e.target.value)}
                  className="w-full p-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A]"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-1">
              <button
                type="button"
                onClick={() => setIsAddingNew(false)}
                className="px-3 py-1.5 text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] hover:opacity-80 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-1.5 rounded-lg bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold hover:opacity-95 cursor-pointer"
              >
                Save Bill
              </button>
            </div>
          </form>
        )}

        {/* --- TAB 1: LIST VIEW --- */}
        {activeTab === 'list' && (
          <div className="flex-1 overflow-y-auto divide-y divide-[#F3DFCD] dark:divide-[#383029] pr-1">
            {unpaidItems.length === 0 && (
              <div className="py-8 text-center">
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  No pending bills due before payday! You are all caught up.
                </p>
              </div>
            )}

            {unpaidItems.map((item) => {
              const Icon = getIcon(item.type, item.name);
              const isIncome = item.isIncome || item.type === 'payday';

              return (
                <div
                  key={item.id}
                  className="py-3 flex items-center justify-between gap-2 hover:bg-[#FFEEDF]/20 dark:hover:bg-[#14100D]/20 transition-colors rounded-lg px-1.5"
                >
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                        isIncome
                          ? 'bg-[#16643F]/10 text-[#16643F] dark:bg-[#5FCB8E]/15 dark:text-[#5FCB8E]'
                          : 'bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]'
                      }`}
                    >
                      <Icon size={16} />
                    </div>
                    <div className="flex flex-col min-w-0 flex-1">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {item.name}
                      </span>
                      <div className="flex items-center gap-2 text-[10px] text-[#6B6156] dark:text-[#AC9E92] truncate">
                        <span>Due {item.dueDate}</span>
                        <span className="capitalize">• {item.type}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span
                      className={`text-xs font-bold tabular-nums ${
                        isIncome
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#15120F] dark:text-[#F6EFE8]'
                      }`}
                    >
                      {isIncome ? `+${formatPeso(item.amount)}` : formatPeso(item.amount)}
                    </span>

                    {!isIncome && (
                      <button
                        type="button"
                        onClick={() => setPayingItem(item)}
                        className="px-2.5 py-1 rounded-lg bg-emerald-600 dark:bg-emerald-500 text-white text-[11px] font-bold hover:opacity-90 transition-opacity cursor-pointer shadow-2xs"
                      >
                        Pay
                      </button>
                    )}

                    <button
                      type="button"
                      onClick={() => deleteUpcoming(item.id)}
                      className="p-1 rounded-md text-[#6B6156] dark:text-[#AC9E92] hover:text-rose-600 transition-colors cursor-pointer"
                      title="Delete"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              );
            })}

            {/* Paid Items Section */}
            {paidItems.length > 0 && (
              <div className="pt-3 mt-2">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-2 px-1">
                  Settled This Cycle ({paidItems.length})
                </span>
                <div className="space-y-1.5 opacity-60">
                  {paidItems.map((item) => (
                    <div
                      key={item.id}
                      className="p-2 rounded-lg bg-[#FFEEDF]/30 dark:bg-[#14100D]/30 flex items-center justify-between text-xs"
                    >
                      <div className="flex items-center gap-2 truncate">
                        <Check size={14} className="text-emerald-600 shrink-0" />
                        <span className="line-through truncate text-[#15120F] dark:text-[#F6EFE8]">
                          {item.name}
                        </span>
                      </div>
                      <span className="font-mono text-[#5A5148] dark:text-[#C6B8AC]">
                        {formatPeso(item.amount)}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* --- TAB 2: CALENDAR VIEW --- */}
        {activeTab === 'calendar' && (
          <div className="flex-1 overflow-y-auto pr-1 space-y-3">
            <div className="flex justify-between items-center px-1">
              <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                {now.toLocaleDateString('en-PH', { month: 'long', year: 'numeric' })}
              </span>
              <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                Click day to view bill details
              </span>
            </div>

            {/* Calendar Grid */}
            <div className="grid grid-cols-7 gap-1 text-center text-xs">
              {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
                <div key={i} className="text-[10px] font-bold text-[#7A6E63] dark:text-[#A89A8D] py-1">
                  {d}
                </div>
              ))}

              {/* Blank placeholders before month start */}
              {Array.from({ length: firstDayOfWeek }).map((_, i) => (
                <div key={`empty-${i}`} className="p-1 rounded-lg opacity-20 text-[11px]" />
              ))}

              {/* Days of Month */}
              {Array.from({ length: daysInCurrentMonth }).map((_, i) => {
                const dayNum = i + 1;
                const billsOnDay = billsByDay[dayNum] || [];
                const hasBills = billsOnDay.length > 0;
                const isSelected = selectedCalendarDay === dayNum;
                const isToday = now.getDate() === dayNum;

                return (
                  <button
                    key={dayNum}
                    type="button"
                    onClick={() => setSelectedCalendarDay(isSelected ? null : dayNum)}
                    className={`p-1.5 rounded-xl flex flex-col items-center justify-center transition-all cursor-pointer min-h-11 ${
                      isSelected
                        ? 'bg-[#B03C09] text-white shadow-xs'
                        : isToday
                        ? 'bg-[#FFEEDF] dark:bg-[#1E1915] font-bold text-[#B03C09] dark:text-[#FF9A52] border border-[#B03C09]'
                        : hasBills
                        ? 'bg-[#FFEEDF]/60 dark:bg-[#14100D]/60 border border-[#F3DFCD] dark:border-[#383029]'
                        : 'hover:bg-[#FFEEDF]/20 text-[#5A5148] dark:text-[#C6B8AC]'
                    }`}
                  >
                    <span className="text-[11px] leading-none">{dayNum}</span>
                    {hasBills && (
                      <div className="flex gap-0.5 mt-1">
                        {billsOnDay.slice(0, 3).map((b, bi) => (
                          <div
                            key={bi}
                            className={`w-1.5 h-1.5 rounded-full ${
                              isSelected
                                ? 'bg-white'
                                : b.isIncome
                                ? 'bg-emerald-500'
                                : 'bg-[#B03C09] dark:bg-[#FF9A52]'
                            }`}
                          />
                        ))}
                      </div>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Selected Day Details */}
            {selectedCalendarDay !== null && (
              <div className="p-3 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-xl border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                  Commitments on Day {selectedCalendarDay}:
                </span>
                {(billsByDay[selectedCalendarDay] || []).length === 0 ? (
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                    No bills or income scheduled for this day.
                  </p>
                ) : (
                  <div className="space-y-1.5">
                    {billsByDay[selectedCalendarDay].map((b) => (
                      <div
                        key={b.id}
                        className="flex justify-between items-center text-xs p-2 bg-white dark:bg-[#27201A] rounded-lg border border-[#F3DFCD] dark:border-[#383029]"
                      >
                        <div>
                          <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                            {b.name}
                          </span>
                          <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] capitalize">
                            {b.type} • {b.isPaid ? 'Paid' : 'Unpaid'}
                          </span>
                        </div>
                        <span className="font-mono font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {formatPeso(b.amount)}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* --- TAB 3: CASH FLOW IMPACT TIMELINE --- */}
        {activeTab === 'cashflow' && (
          <div className="flex-1 overflow-y-auto pr-1 space-y-3">
            <div className="p-3 bg-[#FFEEDF]/50 dark:bg-[#1E1915] rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs">
              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                Sequential Cash Flow Trajectory
              </span>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                Simulates your liquid cash balance as each scheduled commitment is deducted until payday.
              </p>
            </div>

            <div className="space-y-2">
              {cashFlowTimeline.map((step, idx) => (
                <div
                  key={idx}
                  className="p-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between text-xs"
                >
                  <div className="flex items-center gap-2.5 min-w-0 flex-1">
                    <div
                      className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${
                        step.isBase
                          ? 'bg-[#B03C09]/10 text-[#B03C09]'
                          : step.impact < 0
                          ? 'bg-rose-50 dark:bg-rose-950/50 text-rose-600 dark:text-rose-400'
                          : 'bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400'
                      }`}
                    >
                      {step.isBase ? (
                        <Landmark size={14} />
                      ) : step.impact < 0 ? (
                        <TrendingDown size={14} />
                      ) : (
                        <TrendingUp size={14} />
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate block">
                        {step.name}
                      </span>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        {step.date}
                      </span>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    {!step.isBase && (
                      <span
                        className={`text-[10px] font-bold block ${
                          step.impact < 0 ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600'
                        }`}
                      >
                        {step.impact < 0 ? `-${formatPeso(Math.abs(step.impact))}` : `+${formatPeso(step.impact)}`}
                      </span>
                    )}
                    <span className="font-mono font-black text-xs text-[#15120F] dark:text-[#F6EFE8]">
                      {formatPeso(step.runningBalance)}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Pay Bill Account Selector Sub-Modal */}
        {payingItem && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 border border-[#F3DFCD] dark:border-[#383029] shadow-2xl space-y-4">
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Confirm Payment for {payingItem.name}
                </h3>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  Select the bank account or e-wallet to deduct{' '}
                  <strong className="text-[#B03C09] dark:text-[#FF9A52] font-bold">
                    {formatPeso(payingItem.amount)}
                  </strong>
                </p>
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Payment Account
                </label>
                <select
                  value={selectedAccountId || accounts[0]?.id}
                  onChange={(e) => setSelectedAccountId(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs text-[#15120F] dark:text-[#F6EFE8]"
                >
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.name} ({formatPeso(acc.balance)})
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setPayingItem(null)}
                  className="flex-1 py-2 rounded-xl text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#FFEEDF]/40 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleConfirmPay}
                  className="flex-1 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold hover:opacity-90 cursor-pointer shadow-xs"
                >
                  Confirm &amp; Deduct
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
