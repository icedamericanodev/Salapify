import React, { useState } from 'react';
import { X, Users, Check, Plus, Trash2, ArrowRight } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface SplitBillModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SplitBillModal: React.FC<SplitBillModalProps> = ({ isOpen, onClose }) => {
  const { addDebt, addTransaction, accounts } = useFinancial();

  const [billTotalStr, setBillTotalStr] = useState('');
  const [description, setDescription] = useState('Barkada Lunch');
  const [friends, setFriends] = useState<string[]>(['Kuya Mark', 'Carla']);
  const [newFriendName, setNewFriendName] = useState('');
  const [includeMe, setIncludeMe] = useState(true);
  const [logMyExpense, setLogMyExpense] = useState(true);
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [successSaved, setSuccessSaved] = useState(false);

  if (!isOpen) return null;

  const totalBill = parseFloat(billTotalStr) || 0;
  const totalHeads = friends.length + (includeMe ? 1 : 0);
  const sharePerHead = totalHeads > 0 ? totalBill / totalHeads : 0;

  const handleAddFriend = () => {
    if (newFriendName.trim() && !friends.includes(newFriendName.trim())) {
      setFriends([...friends, newFriendName.trim()]);
      setNewFriendName('');
    }
  };

  const handleRemoveFriend = (name: string) => {
    setFriends(friends.filter((f) => f !== name));
  };

  const handleConfirmSplit = (e: React.FormEvent) => {
    e.preventDefault();
    if (totalBill <= 0 || friends.length === 0) return;

    // 1. Log friend debts into "Owed to Me" (Debt Both Ways)
    friends.forEach((friend) => {
      addDebt({
        person: friend,
        direction: 'owed_to_me',
        totalAmount: Math.round(sharePerHead),
        paidAmount: 0,
        scheduleType: 'flexible',
        notes: `Share for ${description}`,
      });
    });

    // 2. Optionally log my own share as an expense transaction
    if (logMyExpense && includeMe && selectedAccountId) {
      addTransaction({
        type: 'expense',
        amount: Math.round(sharePerHead),
        category: 'Food & Dining',
        accountId: selectedAccountId,
        merchant: description,
        date: new Date().toISOString().split('T')[0],
        note: `My share of ${description} (Split with ${friends.join(', ')})`,
      });
    }

    setSuccessSaved(true);
    setTimeout(() => {
      setSuccessSaved(false);
      onClose();
    }, 500);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl p-5 sm:p-6 border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom duration-250">
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-[#16643F]/10 dark:bg-[#5FCB8E]/10 flex items-center justify-center text-[#16643F] dark:text-[#5FCB8E]">
              <Users size={18} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Split Bill & Pahiram
              </h2>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                KKB calculator that records what friends owe you
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

        <form onSubmit={handleConfirmSplit} className="space-y-4 overflow-y-auto pr-1">
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Total Bill Amount (₱)
            </label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-base text-[#6B6156] dark:text-[#AC9E92]">
                ₱
              </span>
              <input
                type="number"
                step="any"
                autoFocus
                value={billTotalStr}
                onChange={(e) => setBillTotalStr(e.target.value)}
                placeholder="1500"
                className="w-full pl-8 pr-3 py-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Event or Meal Description
            </label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g. Samgyupsal dinner, Grab ride"
              className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
            />
          </div>

          {/* Friends list */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
              Friends Splitting with You ({friends.length})
            </label>
            <div className="flex gap-2 mb-2">
              <input
                type="text"
                value={newFriendName}
                onChange={(e) => setNewFriendName(e.target.value)}
                placeholder="Friend name (e.g. Bea, Paolo)"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleAddFriend();
                  }
                }}
                className="flex-1 py-2 px-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]"
              />
              <button
                type="button"
                onClick={handleAddFriend}
                className="px-3 py-2 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold border border-[#F3DFCD] dark:border-[#383029] cursor-pointer"
              >
                <Plus size={14} />
              </button>
            </div>

            <div className="flex flex-wrap gap-1.5">
              {friends.map((friend) => (
                <div
                  key={friend}
                  className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]"
                >
                  <span>{friend}</span>
                  <button
                    type="button"
                    onClick={() => handleRemoveFriend(friend)}
                    className="p-0.5 text-[#6B6156] hover:text-red-500 cursor-pointer"
                  >
                    <X size={12} />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Split Summary Box */}
          <div className="p-3.5 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-2">
            <div className="flex justify-between items-center text-xs">
              <span className="text-[#6B6156] dark:text-[#AC9E92]">Each person owes:</span>
              <strong className="text-base font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                {formatPeso(sharePerHead)}
              </strong>
            </div>
            <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
              {totalHeads} people total (You + {friends.length} {friends.length === 1 ? 'friend' : 'friends'})
            </div>
          </div>

          {/* Checkbox: Include me & Log my share */}
          <div className="space-y-2 pt-1 text-xs font-medium text-[#5A5148] dark:text-[#C6B8AC]">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={includeMe}
                onChange={(e) => setIncludeMe(e.target.checked)}
                className="accent-[#B03C09]"
              />
              <span>Include my share in the split</span>
            </label>
            {includeMe && (
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={logMyExpense}
                  onChange={(e) => setLogMyExpense(e.target.checked)}
                  className="accent-[#B03C09]"
                />
                <span>Log my share ({formatPeso(sharePerHead)}) as an expense now</span>
              </label>
            )}
          </div>

          <button
            type="submit"
            disabled={totalBill <= 0 || friends.length === 0 || successSaved}
            className={`w-full py-3.5 px-4 rounded-2xl font-bold text-sm shadow-xs flex items-center justify-center gap-2 cursor-pointer transition-all ${
              successSaved
                ? 'bg-[#16643F] text-white'
                : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-95 disabled:opacity-50'
            }`}
          >
            {successSaved ? (
              <>
                <Check size={18} /> Recorded to Owed to You
              </>
            ) : (
              <>
                Record Debts & Split <ArrowRight size={16} />
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};
