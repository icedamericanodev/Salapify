import React, { useState } from 'react';
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
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { UpcomingItem } from '../types';

interface BillsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const BillsModal: React.FC<BillsModalProps> = ({ isOpen, onClose }) => {
  const {
    upcoming,
    accounts,
    markUpcomingPaid,
    addUpcoming,
    deleteUpcoming,
    payday,
  } = useFinancial();

  // Selected bill to pay
  const [payingItem, setPayingItem] = useState<UpcomingItem | null>(null);
  const [selectedAccountId, setSelectedAccountId] = useState<string>('');
  const [paidToast, setPaidToast] = useState<string | null>(null);

  // New bill modal / inline form
  const [isAddingNew, setIsAddingNew] = useState(false);
  const [newName, setNewName] = useState('');
  const [newAmount, setNewAmount] = useState('');
  const [newDueDate, setNewDueDate] = useState('');
  const [newType, setNewType] = useState<'bill' | 'subscription' | 'debt'>('bill');

  if (!isOpen) return null;

  // Filter bills & subscriptions
  const unpaidItems = upcoming.filter((u) => !u.isPaid);
  const paidItems = upcoming.filter((u) => u.isPaid);

  const totalUpcomingBills = unpaidItems
    .filter((u) => !u.isIncome)
    .reduce((sum, u) => sum + u.amount, 0);

  const getIcon = (type: string, name: string) => {
    if (type === 'payday') return CalendarCheck;
    if (name.toLowerCase().includes('spotify') || type === 'subscription') return Music;
    if (
      name.toLowerCase().includes('meralco') ||
      name.toLowerCase().includes('electric') ||
      name.toLowerCase().includes('water') ||
      name.toLowerCase().includes('wifi') ||
      type === 'bill'
    )
      return Zap;
    return CreditCard;
  };

  const handleConfirmPay = () => {
    if (!payingItem) return;
    const accId = selectedAccountId || accounts[0]?.id;
    markUpcomingPaid(payingItem.id, accId);
    setPaidToast(`Paid ${payingItem.name}! Transaction logged.`);
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

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029]">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center">
              <CalendarClock size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Bills &amp; Scheduled Payables
              </h2>
              <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                Track upcoming commitments before your next sweldo
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Total Summary Card */}
        <div className="py-3">
          <div className="p-3.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D]/60 border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between">
            <div className="flex flex-col">
              <span className="text-[11px] font-medium text-[#6B6156] dark:text-[#AC9E92]">
                Due Before Payday ({payday.daysToPayday} days)
              </span>
              <span className="text-lg font-bold text-[#15120F] dark:text-[#F6EFE8]">
                {formatPeso(totalUpcomingBills)}
              </span>
            </div>
            <button
              type="button"
              onClick={() => setIsAddingNew(!isAddingNew)}
              className="px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold flex items-center gap-1.5 hover:opacity-90 transition-opacity cursor-pointer shadow-xs"
            >
              <Plus size={14} /> {isAddingNew ? 'Close' : 'Add Bill'}
            </button>
          </div>
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
          <form onSubmit={handleCreateBill} className="p-3.5 mb-3 rounded-xl border border-[#B03C09]/30 bg-[#B03C09]/5 dark:bg-[#FF9A52]/5 space-y-2.5">
            <div className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
              New Scheduled Bill or Subscription
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Bill Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Manila Water, Netflix"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09]"
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
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09]"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Due Date
                </label>
                <input
                  type="text"
                  placeholder="e.g. Today, Sep 20"
                  value={newDueDate}
                  onChange={(e) => setNewDueDate(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09]"
                />
              </div>
              <div>
                <label className="text-[10px] font-medium text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Type
                </label>
                <select
                  value={newType}
                  onChange={(e) => setNewType(e.target.value as any)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09]"
                >
                  <option value="bill">Utility / Bill</option>
                  <option value="subscription">Subscription</option>
                  <option value="debt">Loan / Installment</option>
                </select>
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

        {/* Scrollable List of Bills */}
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
            const isDueToday = item.dueDate.toLowerCase().includes('today');

            return (
              <div
                key={item.id}
                className="py-3 flex items-center justify-between gap-2"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div
                    className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                      isIncome
                        ? 'bg-[#16643F]/10 text-[#16643F] dark:text-[#5FCB8E]'
                        : isDueToday
                        ? 'bg-[#9E2C1B]/10 text-[#9E2C1B] dark:text-[#FF8A6E]'
                        : 'bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]'
                    }`}
                  >
                    <Icon size={17} />
                  </div>
                  <div className="flex flex-col min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {item.name}
                      </span>
                      {isDueToday && (
                        <span className="px-1.5 py-0.5 rounded-md text-[9px] font-bold bg-[#9E2C1B]/15 text-[#9E2C1B] dark:text-[#FF8A6E]">
                          Due Today
                        </span>
                      )}
                    </div>
                    <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1">
                      <Clock size={11} /> {item.dueDate}
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <div className="text-right">
                    <span
                      className={`text-xs font-bold block ${
                        isIncome
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#15120F] dark:text-[#F6EFE8]'
                      }`}
                    >
                      {isIncome ? `+${formatPeso(item.amount)}` : formatPeso(item.amount)}
                    </span>
                  </div>

                  {!isIncome && (
                    <button
                      type="button"
                      onClick={() => {
                        setPayingItem(item);
                        setSelectedAccountId(accounts[0]?.id || '');
                      }}
                      className="px-2.5 py-1.5 rounded-lg bg-[#16643F] text-white text-[11px] font-bold hover:opacity-90 transition-opacity flex items-center gap-1 cursor-pointer shadow-2xs"
                    >
                      <Check size={12} /> Pay
                    </button>
                  )}

                  <button
                    type="button"
                    onClick={() => deleteUpcoming(item.id)}
                    className="p-1 text-[#6B6156] hover:text-[#9E2C1B] transition-colors cursor-pointer"
                    title="Remove bill"
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            );
          })}

          {/* Paid History section if any */}
          {paidItems.length > 0 && (
            <div className="pt-4">
              <div className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] mb-2">
                Settled This Cutoff
              </div>
              {paidItems.map((item) => (
                <div
                  key={item.id}
                  className="py-2 flex items-center justify-between text-xs opacity-60"
                >
                  <span className="line-through text-[#15120F] dark:text-[#F6EFE8]">
                    {item.name}
                  </span>
                  <span className="font-medium text-[#16643F] dark:text-[#5FCB8E] flex items-center gap-1">
                    <Check size={12} /> Paid {formatPeso(item.amount)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Modal Sheet for selecting Account to Pay from */}
        {payingItem && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
            <div className="w-full max-w-xs bg-white dark:bg-[#27201A] rounded-2xl p-4 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
              <div className="flex items-center justify-between border-b border-[#F3DFCD] dark:border-[#383029] pb-2">
                <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Confirm Payment
                </div>
                <button
                  type="button"
                  onClick={() => setPayingItem(null)}
                  className="text-[#6B6156] hover:text-[#15120F] cursor-pointer"
                >
                  <X size={16} />
                </button>
              </div>

              <div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                  Pay <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">{payingItem.name}</span> for{' '}
                  <span className="font-bold text-[#B03C09] dark:text-[#FF9A52]">{formatPeso(payingItem.amount)}</span>?
                </p>
                <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] mt-1">
                  This will deduct the balance and log a transaction in your ledger.
                </p>
              </div>

              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Deduct from Account:
                </label>
                <select
                  value={selectedAccountId}
                  onChange={(e) => setSelectedAccountId(e.target.value)}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09]"
                >
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.name} ({formatPeso(acc.balance)})
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => setPayingItem(null)}
                  className="flex-1 py-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] hover:opacity-90 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleConfirmPay}
                  className="flex-1 py-1.5 rounded-lg bg-[#16643F] text-white text-xs font-bold hover:opacity-95 cursor-pointer flex items-center justify-center gap-1 shadow-xs"
                >
                  <Check size={13} /> Confirm Pay
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
