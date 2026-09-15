import React, { useState, useEffect } from 'react';
import { X, Sparkles, Check } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { parseFastLog } from '../utils/fastlog';
import { TransactionType } from '../types';
import { INITIAL_CATEGORIES } from '../data/initialData';

interface LogSheetProps {
  isOpen: boolean;
  onClose: () => void;
  initialType?: TransactionType;
}

export const LogSheet: React.FC<LogSheetProps> = ({
  isOpen,
  onClose,
  initialType = 'expense',
}) => {
  const { accounts, addTransaction } = useFinancial();

  const [fastLogInput, setFastLogInput] = useState('');
  const [type, setType] = useState<TransactionType>(initialType);
  const [amountStr, setAmountStr] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('Food & Dining');
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [toAccountId, setToAccountId] = useState(accounts[1]?.id || '');
  const [merchant, setMerchant] = useState('');
  const [note, setNote] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [savedSuccess, setSavedSuccess] = useState(false);

  // Fast-log real-time parsing
  const parsed = parseFastLog(fastLogInput);

  useEffect(() => {
    if (parsed.isValid && fastLogInput.trim().length > 0) {
      setType(parsed.type);
      setAmountStr(parsed.amount.toString());
      setMerchant(parsed.merchant);
      setSelectedCategory(parsed.category);
    }
  }, [fastLogInput]);

  useEffect(() => {
    if (isOpen) {
      setSavedSuccess(false);
      setFastLogInput('');
      setAmountStr('');
      setMerchant('');
      setNote('');
      setDate(new Date().toISOString().split('T')[0]);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    const parsedAmount = parseFloat(amountStr.replace(/,/g, ''));
    if (isNaN(parsedAmount) || parsedAmount <= 0) return;

    addTransaction({
      type,
      amount: parsedAmount,
      category: type === 'transfer' ? 'Transfer' : selectedCategory,
      accountId: selectedAccountId,
      toAccountId: type === 'transfer' ? toAccountId : undefined,
      merchant: merchant.trim() || undefined,
      note: note.trim() || undefined,
      date,
    });

    setSavedSuccess(true);
    setTimeout(() => {
      onClose();
    }, 400);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      {/* Dimmed backdrop */}
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      {/* Sheet panel */}
      <div className="relative w-full max-w-lg bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden border border-[#F3DFCD] dark:border-[#383029] animate-in slide-in-from-bottom duration-250">
        {/* Header with drag indicator */}
        <div className="flex flex-col items-center pt-3 pb-2 px-5 border-b border-[#F3DFCD] dark:border-[#383029]">
          <div className="w-10 h-1.5 rounded-full bg-[#F3DFCD] dark:bg-[#383029] mb-3" />
          <div className="w-full flex items-center justify-between">
            <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Log Entry
            </h2>
            <button
              type="button"
              onClick={onClose}
              className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
            >
              <X size={19} />
            </button>
          </div>
        </div>

        {/* Scrollable form content */}
        <form onSubmit={handleSave} className="overflow-y-auto p-5 space-y-4">
          {/* 1. Fast-log natural input field */}
          <div className="flex flex-col gap-1.5">
            <div className="relative">
              <input
                type="text"
                autoFocus
                value={fastLogInput}
                onChange={(e) => setFastLogInput(e.target.value)}
                placeholder='Fast-log: "jollibee 250" or "salary 32000"'
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs sm:text-sm font-medium text-[#15120F] dark:text-[#F6EFE8] placeholder:text-[#6B6156]/70 dark:placeholder:text-[#AC9E92]/60 focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
              />
              <Sparkles
                size={16}
                className="absolute right-3 top-3 text-[#B03C09] dark:text-[#FF9A52] pointer-events-none"
              />
            </div>
            {/* Live parser feedback */}
            <div className="text-[11px] font-medium text-[#5A5148] dark:text-[#C6B8AC] px-1 truncate">
              {parsed.isValid ? (
                <span className="text-[#B03C09] dark:text-[#FF9A52] font-semibold">
                  {parsed.displayPreview}
                </span>
              ) : (
                <span>Type natural phrases to auto-fill amount, type & category</span>
              )}
            </div>
          </div>

          {/* 2. Type Segmented */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            {(['expense', 'income', 'transfer'] as TransactionType[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setType(t)}
                className={`flex-1 py-1.5 text-xs font-bold rounded-lg capitalize transition-all cursor-pointer ${
                  type === t
                    ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                    : 'text-[#6B6156] dark:text-[#AC9E92]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>

          {/* 3. Hero Amount Input */}
          <div className="flex flex-col items-center justify-center py-2">
            <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] mb-1">
              Amount
            </span>
            <div className="flex items-center justify-center gap-1">
              <span className="text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                ₱
              </span>
              <input
                type="number"
                step="any"
                required
                value={amountStr}
                onChange={(e) => setAmountStr(e.target.value)}
                placeholder="0.00"
                className="w-48 text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] bg-transparent border-b-2 border-[#F3DFCD] dark:border-[#383029] text-center focus:border-[#B03C09] dark:focus:border-[#FF9A52] focus:outline-none"
              />
            </div>
          </div>

          {/* Label / Merchant */}
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              Description / Merchant
            </label>
            <input
              type="text"
              value={merchant}
              onChange={(e) => setMerchant(e.target.value)}
              placeholder="e.g. Starbucks, Angkas, Electric bill"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
            />
          </div>

          {/* 4. Category Chips (for Expense/Income) */}
          {type !== 'transfer' && (
            <div className="flex flex-col gap-1.5">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Category
              </label>
              <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto p-0.5">
                {INITIAL_CATEGORIES.filter((c) => c.id !== 'transfer').map((cat) => {
                  const isSelected = selectedCategory === cat.name;
                  return (
                    <button
                      key={cat.id}
                      type="button"
                      onClick={() => setSelectedCategory(cat.name)}
                      className={`px-3 py-1.5 rounded-full text-xs font-medium flex items-center gap-1.5 transition-all cursor-pointer border ${
                        isSelected
                          ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent font-bold shadow-xs'
                          : 'bg-[#FFEEDF]/50 dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40'
                      }`}
                    >
                      <span>{cat.emoji}</span>
                      <span>{cat.name}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* 5. Account Selection */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              {type === 'transfer' ? 'From Account' : 'Account'}
            </label>
            <div className="flex flex-wrap gap-1.5">
              {accounts.map((acc) => {
                const isSelected = selectedAccountId === acc.id;
                return (
                  <button
                    key={acc.id}
                    type="button"
                    onClick={() => setSelectedAccountId(acc.id)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer border ${
                      isSelected
                        ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent shadow-xs'
                        : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span className="text-[10px] px-1 py-0.5 rounded bg-amber-500/20 text-amber-700 dark:text-amber-300 font-bold">
                      {acc.monogram}
                    </span>
                    <span>{acc.name}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Transfer destination if Transfer */}
          {type === 'transfer' && (
            <div className="flex flex-col gap-1.5">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                To Account
              </label>
              <div className="flex flex-wrap gap-1.5">
                {accounts
                  .filter((a) => a.id !== selectedAccountId)
                  .map((acc) => {
                    const isSelected = toAccountId === acc.id;
                    return (
                      <button
                        key={acc.id}
                        type="button"
                        onClick={() => setToAccountId(acc.id)}
                        className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer border ${
                          isSelected
                            ? 'bg-[#16643F] dark:bg-[#5FCB8E] text-white dark:text-[#15120F] border-transparent shadow-xs'
                            : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                        }`}
                      >
                        <span className="text-[10px] px-1 py-0.5 rounded bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 font-bold">
                          {acc.monogram}
                        </span>
                        <span>{acc.name}</span>
                      </button>
                    );
                  })}
              </div>
            </div>
          )}

          {/* 6. Date and Note side by side */}
          <div className="grid grid-cols-2 gap-2 pt-1">
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Date
              </label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Note (optional)
              </label>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Details"
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              />
            </div>
          </div>

          {/* 7. Save entry button */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={!amountStr || parseFloat(amountStr) <= 0}
              className={`w-full py-3.5 px-4 rounded-2xl font-bold text-sm shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer ${
                savedSuccess
                  ? 'bg-[#16643F] text-white'
                  : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-90 active:scale-98 disabled:opacity-50 disabled:cursor-not-allowed'
              }`}
            >
              {savedSuccess ? (
                <>
                  <Check size={18} /> Entry Recorded
                </>
              ) : (
                'Save Entry'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
