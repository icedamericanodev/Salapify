import React, { useState } from 'react';
import { Plus, Check, CheckCircle2, ChevronRight, ArrowLeft, Users } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Debt, DebtDirection } from '../types';

interface DebtScreenProps {
  onBack?: () => void;
  onOpenAddDebt: () => void;
  onOpenSplitBill?: () => void;
}

export const DebtScreen: React.FC<DebtScreenProps> = ({ onBack, onOpenAddDebt, onOpenSplitBill }) => {
  const {
    debts,
    recordDebtPayment,
    toggleDebtSettled,
    totalDebtsIOwe,
    totalDebtsOwedToMe,
    accounts,
  } = useFinancial();

  const [activeSegment, setActiveSegment] = useState<DebtDirection>('i_owe');
  const [selectedDebtForPayment, setSelectedDebtForPayment] = useState<Debt | null>(null);
  const [paymentAmount, setPaymentAmount] = useState('');
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [celebratingDebtId, setCelebratingDebtId] = useState<string | null>(null);

  // Proportional beam
  const totalCombined = totalDebtsOwedToMe + totalDebtsIOwe;
  const owedToMePercent = totalCombined > 0 
    ? Math.max(10, Math.min(90, (totalDebtsOwedToMe / totalCombined) * 100))
    : 50;
  const youOwePercent = 100 - owedToMePercent;

  const currentList = debts.filter((d) => d.direction === activeSegment);
  const openDebts = currentList.filter((d) => !d.isSettled);
  const settledDebts = currentList.filter((d) => d.isSettled);

  // Next due debt
  const nextDue = openDebts.find((d) => d.dueDate);

  const handleSettleDebt = (debt: Debt) => {
    setCelebratingDebtId(debt.id);
    setTimeout(() => {
      toggleDebtSettled(debt.id);
      setCelebratingDebtId(null);
    }, 1200);
  };

  const handleConfirmPayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDebtForPayment) return;
    const amount = parseFloat(paymentAmount);
    if (isNaN(amount) || amount <= 0) return;

    recordDebtPayment(selectedDebtForPayment.id, amount, selectedAccountId);
    setSelectedDebtForPayment(null);
    setPaymentAmount('');
  };

  return (
    <div className="flex flex-col gap-5 pb-24">
      {/* Top Bar */}
      <div className="flex items-center justify-between pt-2">
        <div className="flex items-center gap-2">
          {onBack && (
            <button
              type="button"
              onClick={onBack}
              className="p-1.5 rounded-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
            >
              <ArrowLeft size={18} />
            </button>
          )}
          <div>
            <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
              Debt
            </h1>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              Both ways: what you owe, and what is owed to you.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1.5">
          {onOpenSplitBill && (
            <button
              type="button"
              onClick={onOpenSplitBill}
              className="flex items-center gap-1 px-2.5 py-1.5 rounded-full border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] hover:bg-[#16643F]/10 cursor-pointer transition-colors"
              title="Split a bill with friends and record what they owe"
            >
              <Users size={14} /> Split
            </button>
          )}
          <button
            type="button"
            onClick={onOpenAddDebt}
            className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
          >
            <Plus size={15} /> Add
          </button>
        </div>
      </div>

      {/* The Debt Beam Card */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
        <div className="flex justify-between items-start mb-3">
          <div className="flex flex-col">
            <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
              Owed to you
            </span>
            <span className="text-xl font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
              {formatPeso(totalDebtsOwedToMe)}
            </span>
          </div>

          <div className="flex flex-col items-end">
            <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
              You owe
            </span>
            <span className="text-xl font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
              {formatPeso(totalDebtsIOwe)}
            </span>
          </div>
        </div>

        {/* Proportional 5dp beam */}
        <div className="w-full h-[5px] rounded-full overflow-hidden flex gap-[2px] bg-[#FFEEDF] dark:bg-[#14100D]">
          <div
            className="h-full rounded-l-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-500"
            style={{ width: `${owedToMePercent}%` }}
          />
          <div
            className="h-full rounded-r-full bg-[#B03C09] dark:bg-[#FF9A52] transition-all duration-500"
            style={{ width: `${youOwePercent}%` }}
          />
        </div>
      </div>

      {/* Segmented Switcher: I owe / Owed to me */}
      <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
        <button
          type="button"
          onClick={() => setActiveSegment('i_owe')}
          className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer ${
            activeSegment === 'i_owe'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          You Owe ({debts.filter((d) => !d.isSettled && d.direction === 'i_owe').length})
        </button>
        <button
          type="button"
          onClick={() => setActiveSegment('owed_to_me')}
          className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer ${
            activeSegment === 'owed_to_me'
              ? 'bg-[#16643F] dark:bg-[#5FCB8E] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          Owed to You ({debts.filter((d) => !d.isSettled && d.direction === 'owed_to_me').length})
        </button>
      </div>

      {/* Section: Open Debts */}
      <div className="flex flex-col gap-2">
        <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
          Open ({openDebts.length})
        </h2>

        {openDebts.length === 0 ? (
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-6 text-center text-xs text-[#6B6156] dark:text-[#AC9E92]">
            No open {activeSegment === 'i_owe' ? 'debts you owe' : 'money owed to you'}. You are in the clear!
          </div>
        ) : (
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {openDebts.map((debt) => {
              const remaining = Math.max(0, debt.totalAmount - debt.paidAmount);
              const isCelebrating = celebratingDebtId === debt.id;
              const progress = debt.totalAmount > 0 ? (debt.paidAmount / debt.totalAmount) * 100 : 0;

              return (
                <div
                  key={debt.id}
                  className={`p-4 transition-all duration-500 ${
                    isCelebrating
                      ? 'bg-[#16643F] text-white'
                      : 'hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3 mb-2">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center font-bold text-xs text-[#B03C09] dark:text-[#FF9A52]">
                        {debt.person.substring(0, 2).toUpperCase()}
                      </div>
                      <div className="flex flex-col">
                        <span className={`text-sm font-bold ${isCelebrating ? 'text-white' : 'text-[#15120F] dark:text-[#F6EFE8]'}`}>
                          {debt.person}
                        </span>
                        <span className={`text-xs ${isCelebrating ? 'text-white/80' : 'text-[#6B6156] dark:text-[#AC9E92]'}`}>
                          {debt.scheduleType === 'scheduled' && debt.installmentCurrent
                            ? `${debt.installmentCurrent} of ${debt.installmentTotal} · next ${debt.dueDate || 'due'}`
                            : 'Flexible · pay when you can'}
                        </span>
                      </div>
                    </div>

                    <div className="flex flex-col items-end">
                      <span className={`text-sm font-extrabold ${
                        isCelebrating
                          ? 'text-white'
                          : activeSegment === 'i_owe'
                          ? 'text-[#B03C09] dark:text-[#FF9A52]'
                          : 'text-[#16643F] dark:text-[#5FCB8E]'
                      }`}>
                        {formatPeso(remaining)}
                      </span>
                      <span className={`text-[10px] ${isCelebrating ? 'text-white/80' : 'text-[#6B6156] dark:text-[#AC9E92]'}`}>
                        of {formatPeso(debt.totalAmount)}
                      </span>
                    </div>
                  </div>

                  {/* ThinBar for scheduled debt progress */}
                  {debt.scheduleType === 'scheduled' && (
                    <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden my-2">
                      <div
                        className="h-full bg-[#16643F] dark:bg-[#5FCB8E] rounded-full transition-all duration-300"
                        style={{ width: `${progress}%` }}
                      />
                    </div>
                  )}

                  {/* Action buttons */}
                  {!isCelebrating && (
                    <div className="flex items-center justify-end gap-2 mt-3 pt-2 border-t border-[#F3DFCD]/50 dark:border-[#383029]/50">
                      <button
                        type="button"
                        onClick={() => handleSettleDebt(debt)}
                        className="text-xs font-semibold px-2.5 py-1 rounded-lg text-[#16643F] dark:text-[#5FCB8E] hover:bg-[#16643F]/10 dark:hover:bg-[#5FCB8E]/10 transition-colors flex items-center gap-1 cursor-pointer"
                      >
                        <Check size={13} /> Mark Settled
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setSelectedDebtForPayment(debt);
                          setPaymentAmount((remaining > 2450 ? 2450 : remaining).toString());
                        }}
                        className="text-xs font-bold px-3 py-1 rounded-lg bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#B03C09]/20 transition-colors cursor-pointer"
                      >
                        Record Payment
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Section: Settled Debts */}
      {settledDebts.length > 0 && (
        <div className="flex flex-col gap-2">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#16643F] dark:text-[#5FCB8E] px-1 flex items-center gap-1">
            <CheckCircle2 size={13} /> Settled ({settledDebts.length})
          </h2>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {settledDebts.map((debt) => (
              <div
                key={debt.id}
                className="p-3.5 flex items-center justify-between bg-emerald-500/5 dark:bg-emerald-500/5"
              >
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-[#16643F]/10 dark:bg-[#5FCB8E]/20 text-[#16643F] dark:text-[#5FCB8E] flex items-center justify-center font-bold text-xs">
                    <Check size={15} />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] line-through">
                      {debt.person}
                    </span>
                    <span className="text-[11px] font-bold text-[#16643F] dark:text-[#5FCB8E]">
                      Settled {debt.settledDate || 'recently'}, all paid
                    </span>
                  </div>
                </div>

                <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92]">
                  {formatPeso(debt.totalAmount)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Bottom Sticky Action Bar */}
      <div className="fixed bottom-16 left-0 right-0 p-3 bg-white/90 dark:bg-[#27201A]/90 backdrop-blur-md border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-center gap-2 max-w-md mx-auto z-30">
        {nextDue ? (
          <button
            type="button"
            onClick={() => {
              setSelectedDebtForPayment(nextDue);
              const remaining = nextDue.totalAmount - nextDue.paidAmount;
              setPaymentAmount((remaining > 2450 ? 2450 : remaining).toString());
            }}
            className="flex-1 py-2.5 px-4 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 active:scale-98 transition-all cursor-pointer truncate"
          >
            Pay {nextDue.person.split(' ')[0]} ({formatPeso(Math.min(2450, nextDue.totalAmount - nextDue.paidAmount))})
          </button>
        ) : (
          <button
            type="button"
            onClick={onOpenAddDebt}
            className="flex-1 py-2.5 px-4 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 active:scale-98 transition-all cursor-pointer"
          >
            + Add New Debt Record
          </button>
        )}
      </div>

      {/* Record Payment Dialog */}
      {selectedDebtForPayment && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <h3 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Record a Payment
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-4">
              Paying {selectedDebtForPayment.person} (Remaining: {formatPeso(selectedDebtForPayment.totalAmount - selectedDebtForPayment.paidAmount)})
            </p>

            <form onSubmit={handleConfirmPayment} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Amount (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  autoFocus
                  value={paymentAmount}
                  onChange={(e) => setPaymentAmount(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Source Account
                </label>
                <select
                  value={selectedAccountId}
                  onChange={(e) => setSelectedAccountId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                >
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.name} ({formatPeso(acc.balance)})
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setSelectedDebtForPayment(null)}
                  className="flex-1 py-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
                >
                  Confirm Payment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
