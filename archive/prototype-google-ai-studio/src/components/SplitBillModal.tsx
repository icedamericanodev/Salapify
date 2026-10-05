import React, { useState } from 'react';
import {
  X,
  Users,
  Check,
  Plus,
  Trash2,
  ArrowRight,
  PieChart,
  DollarSign,
  Heart,
  Briefcase,
  Home,
  UserCheck,
  QrCode,
  Share2,
  Copy,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { SplitCategoryType, SplitMethod, SplitParticipant } from '../types';
import { calculateSplitShares } from '../utils/collaborationEngine';

interface SplitBillModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SplitBillModal: React.FC<SplitBillModalProps> = ({ isOpen, onClose }) => {
  const { addDebt, addTransaction, accounts, createExpenseSplit, members, activeMember } =
    useFinancial();

  const [billTotalStr, setBillTotalStr] = useState('');
  const [description, setDescription] = useState('Barkada Lunch');
  const [splitCategory, setSplitCategory] = useState<SplitCategoryType>('friends');
  const [splitMethod, setSplitMethod] = useState<SplitMethod>('equal');

  // Participants
  const [participants, setParticipants] = useState<
    { name: string; isMe: boolean; fixedAmount: string; percentage: string }[]
  >([
    { name: 'You', isMe: true, fixedAmount: '', percentage: '50' },
    { name: 'Carla', isMe: false, fixedAmount: '', percentage: '50' },
  ]);
  const [newFriendName, setNewFriendName] = useState('');
  const [payerName, setPayerName] = useState('You');

  const [logMyExpense, setLogMyExpense] = useState(true);
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [successSaved, setSuccessSaved] = useState(false);

  // QR Ph and Payment Request State
  const [gcashNumber, setGcashNumber] = useState('0917-888-2345');
  const [showQrCard, setShowQrCard] = useState(false);
  const [copiedMessage, setCopiedMessage] = useState(false);

  if (!isOpen) return null;

  const totalBill = parseFloat(billTotalStr) || 0;

  // Calculate shares using collaborationEngine
  const customInputs: Record<string, number> = {};
  participants.forEach((p) => {
    if (splitMethod === 'percentage') {
      customInputs[p.name] = parseFloat(p.percentage) || (100 / Math.max(1, participants.length));
    } else if (splitMethod === 'fixed') {
      customInputs[p.name] = parseFloat(p.fixedAmount) || 0;
    }
  });

  const rawShares = calculateSplitShares(
    totalBill,
    splitMethod,
    participants.map((p) => p.name),
    customInputs
  );

  const calculatedShares: SplitParticipant[] = rawShares.map((s) => ({
    memberId: s.memberId,
    name: s.memberId,
    shareAmount: s.shareAmount,
    sharePercentage: s.sharePercentage,
    hasPaid: s.memberId === payerName,
  }));

  const handleAddParticipant = () => {
    if (newFriendName.trim() && !participants.some((p) => p.name.toLowerCase() === newFriendName.trim().toLowerCase())) {
      const updated = [
        ...participants,
        {
          name: newFriendName.trim(),
          isMe: false,
          fixedAmount: '',
          percentage: (100 / (participants.length + 1)).toFixed(1),
        },
      ];
      setParticipants(updated);
      setNewFriendName('');
    }
  };

  const handleRemoveParticipant = (name: string) => {
    if (name === 'You') return; // Cannot remove self
    setParticipants(participants.filter((p) => p.name !== name));
    if (payerName === name) {
      setPayerName('You');
    }
  };

  const handleUpdatePercentage = (index: number, val: string) => {
    const next = [...participants];
    next[index].percentage = val;
    setParticipants(next);
  };

  const handleUpdateFixed = (index: number, val: string) => {
    const next = [...participants];
    next[index].fixedAmount = val;
    setParticipants(next);
  };

  const handleConfirmSplit = (e: React.FormEvent) => {
    e.preventDefault();
    if (totalBill <= 0 || participants.length < 2) return;

    const myShare = calculatedShares.find((p) => p.name === 'You')?.shareAmount || 0;
    const isPayerMe = payerName === 'You';

    // 1. Log debts into "Debt Both Ways"
    calculatedShares.forEach((p) => {
      if (p.name === 'You') return;

      if (isPayerMe) {
        // You paid for them -> They owe you
        addDebt({
          person: p.name,
          direction: 'owed_to_me',
          totalAmount: Math.round(p.shareAmount),
          paidAmount: 0,
          scheduleType: 'flexible',
          notes: `${splitCategory.toUpperCase()} split: ${description}`,
        });
      } else if (p.name === payerName) {
        // Payer is someone else -> You owe them your share
        addDebt({
          person: payerName,
          direction: 'i_owe',
          totalAmount: Math.round(myShare),
          paidAmount: 0,
          scheduleType: 'flexible',
          notes: `${splitCategory.toUpperCase()} split: ${description}`,
        });
      }
    });

    // 2. Log full Collaboration Expense Split record
    createExpenseSplit({
      title: description,
      totalAmount: totalBill,
      splitType: splitCategory,
      splitMethod,
      payerId: isPayerMe ? (activeMember?.id || 'me') : payerName,
      payerName: payerName,
      participants: calculatedShares,
    });

    // 3. Log expense transaction if selected
    if (logMyExpense && selectedAccountId && myShare > 0) {
      addTransaction({
        type: 'expense',
        amount: Math.round(isPayerMe ? totalBill : myShare),
        category: splitCategory === 'business' ? 'Business Operations' : 'Food & Dining',
        accountId: selectedAccountId,
        merchant: description,
        date: new Date().toISOString().split('T')[0],
        note: isPayerMe
          ? `Paid ₱${totalBill.toLocaleString()} for ${description} (My share: ₱${Math.round(myShare).toLocaleString()}, Split with ${participants.filter((p) => !p.isMe).map((p) => p.name).join(', ')})`
          : `My share of ${description} (Paid by ${payerName})`,
      });
    }

    setSuccessSaved(true);
    setTimeout(() => {
      setSuccessSaved(false);
      onClose();
    }, 600);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      <div className="relative w-full max-w-lg bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl p-5 sm:p-6 border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom duration-250">
        {/* Modal Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4 gap-2">
          <div className="flex items-center gap-2 min-w-0 flex-1">
            <div className="w-9 h-9 rounded-xl bg-[#16643F]/10 dark:bg-[#5FCB8E]/10 flex items-center justify-center text-[#16643F] dark:text-[#5FCB8E] shrink-0">
              <Users size={19} />
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                Split Bill &amp; Shared Expenses
              </h2>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] truncate block">
                Couple, barkada, household &amp; business KKB with auto debt logs
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer shrink-0"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleConfirmSplit} className="space-y-4 overflow-y-auto pr-1">
          {/* Bill Total and Description */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Total Bill (₱)
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 font-bold text-base text-[#6B6156] dark:text-[#AC9E92]">
                  ₱
                </span>
                <input
                  type="number"
                  step="any"
                  autoFocus
                  required
                  value={billTotalStr}
                  onChange={(e) => setBillTotalStr(e.target.value)}
                  placeholder="2450"
                  className="w-full pl-8 pr-3 py-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-lg font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>
            </div>

            <div>
              <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                Description / Event
              </label>
              <input
                type="text"
                required
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="e.g. Samgyupsal dinner, Meralco bill"
                className="w-full py-2.5 px-3 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]"
              />
            </div>
          </div>

          {/* Split Category (Couple, Household, Friends, Business) */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
              Split Context
            </label>
            <div className="grid grid-cols-4 gap-1.5">
              {[
                { id: 'couple' as SplitCategoryType, label: 'Couple', icon: Heart },
                { id: 'household' as SplitCategoryType, label: 'Home', icon: Home },
                { id: 'friends' as SplitCategoryType, label: 'Friends', icon: Users },
                { id: 'business' as SplitCategoryType, label: 'Business', icon: Briefcase },
              ].map((cat) => {
                const Icon = cat.icon;
                const isSelected = splitCategory === cat.id;
                return (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => setSplitCategory(cat.id)}
                    className={`py-2 px-2 rounded-xl text-xs font-bold flex flex-col items-center gap-1 transition-all cursor-pointer border ${
                      isSelected
                        ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent shadow-xs'
                        : 'bg-white dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <Icon size={14} />
                    <span className="text-[10px]">{cat.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Split Method (Equal, Percentage, Fixed) */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
              Split Method
            </label>
            <div className="grid grid-cols-3 gap-1.5">
              {[
                { id: 'equal' as SplitMethod, label: 'Equal (KKB)' },
                { id: 'percentage' as SplitMethod, label: 'Percentage (%)' },
                { id: 'fixed' as SplitMethod, label: 'Fixed Exact (₱)' },
              ].map((m) => (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => setSplitMethod(m.id)}
                  className={`py-1.5 px-2 rounded-xl text-xs font-bold transition-all cursor-pointer border text-center ${
                    splitMethod === m.id
                      ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
                      : 'bg-white dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                  }`}
                >
                  {m.label}
                </button>
              ))}
            </div>
          </div>

          {/* Payer Selector */}
          <div>
            <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
              Who Paid Front?
            </label>
            <select
              value={payerName}
              onChange={(e) => setPayerName(e.target.value)}
              className="w-full py-2 px-3 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] cursor-pointer"
            >
              {participants.map((p) => (
                <option key={p.name} value={p.name}>
                  {p.name} {p.isMe ? '(You)' : ''}
                </option>
              ))}
            </select>
          </div>

          {/* Participants List */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                Participants ({participants.length})
              </label>
              {members && members.length > 1 && (
                <span className="text-[10px] text-[#16643F] dark:text-[#5FCB8E] font-semibold">
                  Linked to Collaboration Hub
                </span>
              )}
            </div>

            <div className="flex gap-2 mb-2">
              <input
                type="text"
                value={newFriendName}
                onChange={(e) => setNewFriendName(e.target.value)}
                placeholder="Add person name (e.g. Bea, Partner, Kuya)"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleAddParticipant();
                  }
                }}
                className="flex-1 py-2 px-3 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]"
              />
              <button
                type="button"
                onClick={handleAddParticipant}
                className="px-3 py-2 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold border border-[#F3DFCD] dark:border-[#383029] cursor-pointer"
              >
                <Plus size={14} />
              </button>
            </div>

            {/* List with custom amount/percentage controls */}
            <div className="space-y-1.5">
              {participants.map((p, idx) => {
                const calculated = calculatedShares.find((c) => c.name === p.name);
                return (
                  <div
                    key={p.name}
                    className="flex items-center justify-between gap-2 p-2 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]"
                  >
                    <div className="flex items-center gap-1.5 min-w-0 flex-1">
                      <div className="w-6 h-6 rounded-full bg-[#B03C09]/15 text-[#B03C09] dark:text-[#FF9A52] text-[10px] font-bold flex items-center justify-center shrink-0">
                        {p.name.charAt(0)}
                      </div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {p.name} {p.isMe ? '(You)' : ''}
                      </span>
                    </div>

                    {/* Method specific inputs */}
                    {splitMethod === 'percentage' && (
                      <div className="flex items-center gap-1 shrink-0">
                        <input
                          type="number"
                          step="1"
                          value={p.percentage}
                          onChange={(e) => handleUpdatePercentage(idx, e.target.value)}
                          className="w-14 py-1 px-1.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs text-right font-bold text-[#15120F] dark:text-[#F6EFE8]"
                        />
                        <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">%</span>
                      </div>
                    )}

                    {splitMethod === 'fixed' && (
                      <div className="flex items-center gap-1 shrink-0">
                        <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                        <input
                          type="number"
                          step="any"
                          value={p.fixedAmount}
                          onChange={(e) => handleUpdateFixed(idx, e.target.value)}
                          placeholder="0"
                          className="w-20 py-1 px-1.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs text-right font-bold text-[#15120F] dark:text-[#F6EFE8]"
                        />
                      </div>
                    )}

                    {/* Computed share preview */}
                    <div className="text-right shrink-0">
                      <span className="text-xs font-extrabold text-[#16643F] dark:text-[#5FCB8E] tabular-nums block">
                        {formatPeso(calculated?.shareAmount || 0)}
                      </span>
                    </div>

                    {!p.isMe && (
                      <button
                        type="button"
                        onClick={() => handleRemoveParticipant(p.name)}
                        className="p-1 text-[#6B6156] hover:text-rose-500 cursor-pointer shrink-0"
                      >
                        <Trash2 size={13} />
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Breakdown Preview */}
          <div className="p-3.5 rounded-2xl bg-[#FFEEDF]/60 dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] space-y-1.5">
            <div className="flex justify-between items-center text-xs">
              <span className="text-[#6B6156] dark:text-[#AC9E92]">
                {payerName === 'You' ? 'Friends owe you in total:' : `You owe ${payerName}:`}
              </span>
              <strong className="text-base font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                {payerName === 'You'
                  ? formatPeso(
                      calculatedShares
                        .filter((p) => p.name !== 'You')
                        .reduce((sum, p) => sum + p.shareAmount, 0)
                    )
                  : formatPeso(calculatedShares.find((p) => p.name === 'You')?.shareAmount || 0)}
              </strong>
            </div>
            <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
              Auto-syncs to Debt Both Ways &amp; Shared Collaboration Ledger
            </div>
          </div>

          {/* QR Ph & Payment Request Generator */}
          <div className="p-3 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] space-y-2.5">
            <div className="flex items-center justify-between">
              <button
                type="button"
                onClick={() => setShowQrCard(!showQrCard)}
                className="flex items-center gap-1.5 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
              >
                <QrCode size={15} />
                <span>{showQrCard ? 'Hide QR Ph Request' : '📱 Generate QR Ph & GCash/Maya Request'}</span>
              </button>
              <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#FFEEDF] dark:bg-[#2B221B] text-[#B03C09] dark:text-[#FF9A52]">
                Instant KKB Request
              </span>
            </div>

            {showQrCard && (
              <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#15110E] border border-[#F3DFCD] dark:border-[#383029] space-y-2 animate-in fade-in">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] shrink-0">
                    Your GCash/Maya No.:
                  </span>
                  <input
                    type="text"
                    value={gcashNumber}
                    onChange={(e) => setGcashNumber(e.target.value)}
                    placeholder="0917-xxx-xxxx"
                    className="flex-1 py-1 px-2 text-xs font-bold rounded-lg bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>

                <div className="p-2.5 rounded-lg bg-white dark:bg-[#201A15] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-2">
                  <div className="text-[11px] text-[#15120F] dark:text-[#F6EFE8] leading-tight">
                    <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] block">
                      Sample Message to send:
                    </span>
                    "Hi! Share for {description} is ₱
                    {formatPeso(
                      calculatedShares.find((p) => p.name !== 'You')?.shareAmount || 0,
                      false
                    )}
                    . Send via GCash to {gcashNumber}!"
                  </div>

                  <button
                    type="button"
                    onClick={() => {
                      const shareAmt = formatPeso(
                        calculatedShares.find((p) => p.name !== 'You')?.shareAmount || 0,
                        false
                      );
                      const text = `Hi! Your share for ${description} is ₱${shareAmt}. Send via GCash/Maya to ${gcashNumber}. Salamat!`;
                      navigator.clipboard?.writeText(text);
                      setCopiedMessage(true);
                      setTimeout(() => setCopiedMessage(false), 2500);
                    }}
                    className="p-1.5 rounded-lg bg-[#FFEEDF] dark:bg-[#2E241D] text-[#8C430B] dark:text-[#FFB076] hover:bg-[#F4DCC7] cursor-pointer flex items-center gap-1 text-[10px] font-bold shrink-0"
                  >
                    <Copy size={12} />
                    <span>{copiedMessage ? 'Copied!' : 'Copy'}</span>
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Expense logging option */}
          <div className="space-y-2 pt-1 text-xs font-medium text-[#5A5148] dark:text-[#C6B8AC]">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={logMyExpense}
                onChange={(e) => setLogMyExpense(e.target.checked)}
                className="accent-[#B03C09]"
              />
              <span>
                Record {payerName === 'You' ? 'full bill payment' : 'my share'} to account ledger
              </span>
            </label>
          </div>

          <button
            type="submit"
            disabled={totalBill <= 0 || participants.length < 2 || successSaved}
            className={`w-full py-3.5 px-4 rounded-2xl font-bold text-sm shadow-xs flex items-center justify-center gap-2 cursor-pointer transition-all ${
              successSaved
                ? 'bg-[#16643F] text-white'
                : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-95 disabled:opacity-50'
            }`}
          >
            {successSaved ? (
              <>
                <Check size={18} /> Recorded to Collaboration &amp; Debts
              </>
            ) : (
              <>
                Confirm &amp; Record Split <ArrowRight size={16} />
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};
