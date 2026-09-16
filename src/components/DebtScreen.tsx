import React, { useState } from 'react';
import { Plus, Check, CheckCircle2, ChevronRight, ArrowLeft, Users, Info } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Debt, DebtDirection } from '../types';
import { SectionInfoModal, InfoTopic } from './SectionInfoModal';
import { InstallmentsView } from './InstallmentsView';
import { DebtCalculatorsView } from './DebtCalculatorsView';

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

  const [mainSection, setMainSection] = useState<'debts' | 'installments' | 'calculators'>('debts');
  const [activeSegment, setActiveSegment] = useState<DebtDirection>('i_owe');
  const [selectedDebtForPayment, setSelectedDebtForPayment] = useState<Debt | null>(null);
  const [paymentAmount, setPaymentAmount] = useState('');
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [celebratingDebtId, setCelebratingDebtId] = useState<string | null>(null);
  const [infoTopic, setInfoTopic] = useState<InfoTopic | null>(null);

  // Proportional beam
  const totalCombined = totalDebtsOwedToMe + totalDebtsIOwe;
  const owedToMePercent = totalCombined > 0 
    ? Math.max(10, Math.min(90, (totalDebtsOwedToMe / totalCombined) * 100))
    : 50;
  const youOwePercent = 100 - owedToMePercent;

  const currentList = debts.filter((d) => d.direction === activeSegment);
  const openDebts = currentList.filter((d) => !d.isSettled);
  const settledDebts = currentList.filter((d) => d.isSettled);

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
    <div className="flex flex-col gap-4 pb-36">
      {/* Top Bar */}
      <div className="flex items-center justify-between pt-2 gap-2">
        <div className="flex items-center gap-2 min-w-0 flex-1">
          {onBack && (
            <button
              type="button"
              onClick={onBack}
              className="p-1.5 rounded-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer shrink-0"
              aria-label="Back"
            >
              <ArrowLeft size={18} />
            </button>
          )}
          <div className="min-w-0 flex-1 flex items-center gap-1.5">
            <h1 className="text-lg sm:text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] truncate">
              Debt & Installments
            </h1>
            <button
              type="button"
              onClick={() => setInfoTopic('debt')}
              className="inline-flex items-center justify-center w-6 h-6 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
              title="Learn how Debt Both Ways & the Debt Beam work"
              aria-label="Debt info"
            >
              <Info size={15} />
            </button>
          </div>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          {onOpenSplitBill && mainSection === 'debts' && (
            <button
              type="button"
              onClick={onOpenSplitBill}
              className="flex items-center gap-1 px-2.5 py-1.5 rounded-full border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] hover:bg-[#16643F]/10 cursor-pointer transition-colors whitespace-nowrap"
              title="Split a bill with friends and record what they owe"
            >
              <Users size={14} /> Split
            </button>
          )}
          {mainSection === 'debts' && (
            <button
              type="button"
              onClick={onOpenAddDebt}
              className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer whitespace-nowrap"
            >
              <Plus size={15} /> Add
            </button>
          )}
        </div>
      </div>

      {/* Main Feature Segment Bar */}
      <div className="flex p-1 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029]">
        <button
          type="button"
          onClick={() => setMainSection('debts')}
          className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            mainSection === 'debts'
              ? 'bg-[#B03C09] text-white shadow-xs'
              : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F]'
          }`}
        >
          Pahiram & Debts
        </button>
        <button
          type="button"
          onClick={() => setMainSection('installments')}
          className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            mainSection === 'installments'
              ? 'bg-[#B03C09] text-white shadow-xs'
              : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F]'
          }`}
        >
          Installments & BNPL
        </button>
        <button
          type="button"
          onClick={() => setMainSection('calculators')}
          className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            mainSection === 'calculators'
              ? 'bg-[#B03C09] text-white shadow-xs'
              : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F]'
          }`}
        >
          Simulators
        </button>
      </div>

      {mainSection === 'installments' && <InstallmentsView />}

      {mainSection === 'calculators' && <DebtCalculatorsView />}

      {mainSection === 'debts' && (
        <>
          {/* The Debt Beam Card */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <div className="flex justify-between items-start mb-3 gap-2">
              <div className="flex flex-col min-w-0 flex-1">
                <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92] truncate">
                  Owed to you
                </span>
                <span className="text-lg sm:text-xl font-extrabold text-[#16643F] dark:text-[#5FCB8E] truncate tabular-nums">
                  {formatPeso(totalDebtsOwedToMe)}
                </span>
              </div>

              <div className="flex flex-col items-end shrink-0 text-right">
                <span className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
                  You owe
                </span>
                <span className="text-lg sm:text-xl font-extrabold text-[#B03C09] dark:text-[#FF9A52] whitespace-nowrap tabular-nums">
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
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center font-bold text-xs text-[#B03C09] dark:text-[#FF9A52] shrink-0">
                        {debt.person.substring(0, 2).toUpperCase()}
                      </div>
                      <div className="flex flex-col min-w-0 flex-1">
                        <span className={`text-sm font-bold truncate ${isCelebrating ? 'text-white' : 'text-[#15120F] dark:text-[#F6EFE8]'}`}>
                          {debt.person}
                        </span>
                        <span className={`text-xs truncate ${isCelebrating ? 'text-white/80' : 'text-[#6B6156] dark:text-[#AC9E92]'}`}>
                          {debt.scheduleType === 'scheduled' && debt.installmentCurrent
                            ? `${debt.installmentCurrent} of ${debt.installmentTotal} · next ${debt.dueDate || 'due'}`
                            : 'Flexible · pay when you can'}
                        </span>
                      </div>
                    </div>

                    <div className="flex flex-col items-end shrink-0 pl-2 text-right">
                      <span className={`text-sm font-extrabold whitespace-nowrap tabular-nums ${
                        isCelebrating
                          ? 'text-white'
                          : activeSegment === 'i_owe'
                          ? 'text-[#B03C09] dark:text-[#FF9A52]'
                          : 'text-[#16643F] dark:text-[#5FCB8E]'
                      }`}>
                        {formatPeso(remaining)}
                      </span>
                      <span className={`text-[10px] whitespace-nowrap ${isCelebrating ? 'text-white/80' : 'text-[#6B6156] dark:text-[#AC9E92]'}`}>
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
                    <div className="flex flex-wrap items-center justify-end gap-2 mt-3 pt-2 border-t border-[#F3DFCD]/50 dark:border-[#383029]/50">
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
                className="p-3.5 flex items-center justify-between bg-emerald-500/5 dark:bg-emerald-500/5 gap-2"
              >
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  <div className="w-8 h-8 rounded-full bg-[#16643F]/10 dark:bg-[#5FCB8E]/20 text-[#16643F] dark:text-[#5FCB8E] flex items-center justify-center font-bold text-xs shrink-0">
                    <Check size={15} />
                  </div>
                  <div className="flex flex-col min-w-0 flex-1">
                    <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] line-through truncate">
                      {debt.person}
                    </span>
                    <span className="text-[11px] font-bold text-[#16643F] dark:text-[#5FCB8E] truncate">
                      Settled {debt.settledDate || 'recently'}, all paid
                    </span>
                  </div>
                </div>

                <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] shrink-0 whitespace-nowrap pl-2 tabular-nums">
                  {formatPeso(debt.totalAmount)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
        </>
      )}

      {/* Section Info Modal */}
      <SectionInfoModal topic={infoTopic} onClose={() => setInfoTopic(null)} />

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
