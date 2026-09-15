import React, { useState } from 'react';
import { X, ArrowRightLeft, Check, AlertCircle } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface TransferModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const TransferModal: React.FC<TransferModalProps> = ({ isOpen, onClose }) => {
  const { accounts, addTransaction } = useFinancial();

  const [fromAccountId, setFromAccountId] = useState(accounts[0]?.id || '');
  const [toAccountId, setToAccountId] = useState(accounts[1]?.id || accounts[0]?.id || '');
  const [amountStr, setAmountStr] = useState('');
  const [note, setNote] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [errorMsg, setErrorMsg] = useState('');
  const [savedSuccess, setSavedSuccess] = useState(false);

  if (!isOpen) return null;

  const fromAccount = accounts.find((a) => a.id === fromAccountId) || accounts[0];
  const toAccount = accounts.find((a) => a.id === toAccountId) || accounts[1];

  const presets = [500, 1000, 2000, 5000];

  const handleTransfer = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    const amount = parseFloat(amountStr.replace(/,/g, ''));
    if (isNaN(amount) || amount <= 0) {
      setErrorMsg('Please enter a valid transfer amount.');
      return;
    }

    if (fromAccountId === toAccountId) {
      setErrorMsg('Source and destination accounts must be different.');
      return;
    }

    if (fromAccount && fromAccount.kind === 'cash' && fromAccount.balance < amount) {
      setErrorMsg(`Insufficient funds in ${fromAccount.name} (${formatPeso(fromAccount.balance)} available).`);
      return;
    }

    // Add transaction adhering to transfer invariant
    addTransaction({
      type: 'transfer',
      amount,
      category: 'Transfer',
      accountId: fromAccountId,
      toAccountId,
      merchant: `Transfer: ${fromAccount?.name} to ${toAccount?.name}`,
      note: note.trim() || undefined,
      date,
    });

    setSavedSuccess(true);
    setTimeout(() => {
      setSavedSuccess(false);
      onClose();
    }, 400);
  };

  const handleSwap = () => {
    setFromAccountId(toAccountId);
    setToAccountId(fromAccountId);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      {/* Sheet */}
      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl p-5 sm:p-6 border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom duration-250">
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52]">
              <ArrowRightLeft size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Move Money
              </h2>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                Between your accounts (Zero net worth change)
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleTransfer} className="space-y-4 overflow-y-auto pr-1">
          {errorMsg && (
            <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs flex items-center gap-2">
              <AlertCircle size={15} className="shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* From and To Selector with Swap */}
          <div className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-3 relative">
            <div>
              <label className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                From Account
              </label>
              <select
                value={fromAccountId}
                onChange={(e) => setFromAccountId(e.target.value)}
                className="w-full py-2.5 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name} ({formatPeso(acc.balance)})
                  </option>
                ))}
              </select>
            </div>

            {/* Swap button */}
            <div className="flex justify-center -my-1">
              <button
                type="button"
                onClick={handleSwap}
                className="w-7 h-7 rounded-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] hover:scale-110 active:scale-95 transition-all shadow-xs cursor-pointer"
                title="Swap accounts"
              >
                <ArrowRightLeft size={13} />
              </button>
            </div>

            <div>
              <label className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                To Account
              </label>
              <select
                value={toAccountId}
                onChange={(e) => setToAccountId(e.target.value)}
                className="w-full py-2.5 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name} ({formatPeso(acc.balance)})
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Amount input */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Transfer Amount (₱)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-base text-[#6B6156] dark:text-[#AC9E92]">
                ₱
              </span>
              <input
                type="number"
                step="any"
                autoFocus
                value={amountStr}
                onChange={(e) => setAmountStr(e.target.value)}
                placeholder="1000.00"
                className="w-full pl-8 pr-3 py-3 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              />
            </div>

            {/* Quick Presets */}
            <div className="flex gap-1.5 mt-2">
              {presets.map((val) => (
                <button
                  key={val}
                  type="button"
                  onClick={() => setAmountStr(val.toString())}
                  className="flex-1 py-1.5 rounded-lg border border-[#F3DFCD] dark:border-[#383029] text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC] bg-white dark:bg-[#27201A] hover:border-[#B03C09] cursor-pointer"
                >
                  +{val}
                </button>
              ))}
              {fromAccount && fromAccount.balance > 0 && (
                <button
                  type="button"
                  onClick={() => setAmountStr(fromAccount.balance.toString())}
                  className="py-1.5 px-2.5 rounded-lg border border-[#B03C09]/40 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] bg-white dark:bg-[#27201A] hover:bg-[#B03C09]/10 cursor-pointer"
                >
                  Max
                </button>
              )}
            </div>
          </div>

          {/* Date & Optional Note */}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-[11px] font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Date
              </label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full py-2 px-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]"
              />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Note (Optional)
              </label>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="e.g. Cash in for dinner"
                className="w-full py-2 px-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={savedSuccess}
            className={`w-full py-3.5 px-4 rounded-2xl font-bold text-sm shadow-xs flex items-center justify-center gap-2 cursor-pointer transition-all ${
              savedSuccess
                ? 'bg-[#16643F] text-white'
                : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-95'
            }`}
          >
            {savedSuccess ? (
              <>
                <Check size={18} /> Transferred Successfully
              </>
            ) : (
              <>
                Confirm Transfer <ArrowRightLeft size={16} />
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};
