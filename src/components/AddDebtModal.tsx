import React, { useState } from 'react';
import { X } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { DebtDirection } from '../types';

interface AddDebtModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AddDebtModal: React.FC<AddDebtModalProps> = ({ isOpen, onClose }) => {
  const { addDebt } = useFinancial();

  const [person, setPerson] = useState('');
  const [direction, setDirection] = useState<DebtDirection>('i_owe');
  const [amountStr, setAmountStr] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [scheduleType, setScheduleType] = useState<'scheduled' | 'flexible'>('flexible');
  const [installments, setInstallments] = useState('6');
  const [notes, setNotes] = useState('');

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(amountStr);
    if (!person.trim() || isNaN(amount) || amount <= 0) return;

    addDebt({
      person: person.trim(),
      direction,
      totalAmount: amount,
      paidAmount: 0,
      dueDate: dueDate.trim() || undefined,
      scheduleType,
      installmentCurrent: scheduleType === 'scheduled' ? 1 : undefined,
      installmentTotal: scheduleType === 'scheduled' ? parseInt(installments) || 6 : undefined,
      notes: notes.trim() || undefined,
    });

    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-2xl border border-[#F3DFCD] dark:border-[#383029]">
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
            Add Debt Record
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3">
          {/* Direction toggle */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setDirection('i_owe')}
              className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                direction === 'i_owe'
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              I Owe
            </button>
            <button
              type="button"
              onClick={() => setDirection('owed_to_me')}
              className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                direction === 'owed_to_me'
                  ? 'bg-[#16643F] dark:bg-[#5FCB8E] text-white dark:text-[#1E0E03] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              Owed to Me
            </button>
          </div>

          <div>
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              {direction === 'i_owe' ? 'Lender / Person Name' : 'Borrower / Friend Name'}
            </label>
            <input
              type="text"
              required
              value={person}
              onChange={(e) => setPerson(e.target.value)}
              placeholder="e.g. Home Credit, Mom, Kuya Mark"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
            />
          </div>

          <div>
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Total Amount (₱)
            </label>
            <input
              type="number"
              step="any"
              required
              value={amountStr}
              onChange={(e) => setAmountStr(e.target.value)}
              placeholder="0.00"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Schedule
              </label>
              <select
                value={scheduleType}
                onChange={(e) => setScheduleType(e.target.value as any)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              >
                <option value="flexible">Flexible</option>
                <option value="scheduled">Installments</option>
              </select>
            </div>

            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Due Date
              </label>
              <input
                type="text"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                placeholder="e.g. Sep 25"
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Note (optional)
            </label>
            <input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Concert ticket split, gadget upgrade"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
            />
          </div>

          <div className="flex gap-2 pt-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
            >
              Save Debt
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
