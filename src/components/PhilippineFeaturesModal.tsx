import React, { useState } from 'react';
import {
  X,
  Send,
  Gift,
  Home,
  CalendarCheck,
  Calculator,
  Plus,
  Trash2,
  CheckCircle2,
  Clock,
  Sparkles,
  ArrowRight,
  ShieldCheck,
  Building2,
  Briefcase,
  Wallet,
  PiggyBank,
  Check,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import {
  RemittanceChannel,
  ThirteenthMonthAllocation,
} from '../types';
import {
  REMITTANCE_CHANNELS,
  REMITTANCE_PURPOSES,
  estimateRemittanceFee,
  calculateEmployeeTaxDeductions,
  calculateFreelanceTax,
} from '../utils/philippineFinances';

type RemitPurpose = 'living_allowance' | 'school_tuition' | 'medical_maintenance' | 'house_renovation' | 'emergency';

interface PhilippineFeaturesModalProps {
  isOpen: boolean;
  onClose: () => void;
  defaultTab?: 'remittance' | '13th_month' | 'household' | 'payday_routine' | 'freelance_tax';
}

export const PhilippineFeaturesModal: React.FC<PhilippineFeaturesModalProps> = ({
  isOpen,
  onClose,
  defaultTab = 'remittance',
}) => {
  const {
    accounts,
    addTransaction,
    updatePayday,
    payday,
    remittances,
    addRemittance,
    updateRemittance,
    deleteRemittance,
    thirteenthMonthPlan,
    update13thMonthPlan,
    update13thMonthAllocations,
    paydayTemplates,
    applyPaydayRoutine,
    householdAmbag,
    recordHouseholdAmbagPayment,
  } = useFinancial();

  const [activeTab, setActiveTab] = useState<
    'remittance' | '13th_month' | 'household' | 'payday_routine' | 'freelance_tax'
  >(defaultTab);

  // New Remittance Form State
  const [showAddRemittance, setShowAddRemittance] = useState(false);
  const [remitRecipient, setRemitRecipient] = useState('');
  const [remitProvince, setRemitProvince] = useState('');
  const [remitChannel, setRemitChannel] = useState<RemittanceChannel>('palawan_express');
  const [remitAmount, setRemitAmount] = useState('');
  const [remitPurpose, setRemitPurpose] = useState<RemitPurpose>('living_allowance');
  const [remitRef, setRemitRef] = useState('');
  const [remitAccountId, setRemitAccountId] = useState<string>(accounts[0]?.id || 'acc-gcash');
  const [remitAutoDeduct, setRemitAutoDeduct] = useState(true);

  // 13th-Month Pay Planner State
  const [salaryInput, setSalaryInput] = useState(thirteenthMonthPlan.basicMonthlySalary.toString());
  const [monthsWorkedInput, setMonthsWorkedInput] = useState(thirteenthMonthPlan.monthsWorkedTotal.toString());
  const [bonusTargetAccountId, setBonusTargetAccountId] = useState<string>(accounts[0]?.id || 'acc-bpi');
  const [bonusActionNotice, setBonusActionNotice] = useState<string | null>(null);

  // Tax Suite State
  const [taxMode, setTaxMode] = useState<'employed' | 'freelance'>('employed');
  const [taxMonthlySalary, setTaxMonthlySalary] = useState('45000');
  const [grossIncomeInput, setGrossIncomeInput] = useState('750000');
  const [taxOption, setTaxOption] = useState<'8_percent_git' | 'graduated_rates'>('8_percent_git');
  const [taxSyncNotice, setTaxSyncNotice] = useState<string | null>(null);

  // Payday Routine feedback
  const [selectedRoutineAccountId, setSelectedRoutineAccountId] = useState<string>(accounts[0]?.id || 'acc-bpi');
  const [routineAppliedNotice, setRoutineAppliedNotice] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleCreateRemittance = (e: React.FormEvent) => {
    e.preventDefault();
    const amountNum = parseFloat(remitAmount);
    if (!remitRecipient || isNaN(amountNum) || amountNum <= 0) return;

    const estFee = estimateRemittanceFee(amountNum, remitChannel);
    const dateStr = new Date().toISOString().split('T')[0];
    const generatedRef = remitRef || `REF-${Math.floor(100000 + Math.random() * 900000)}`;

    addRemittance({
      recipientName: remitRecipient,
      relationship: 'Family',
      provinceCity: remitProvince || 'Provincial Claim',
      channel: remitChannel,
      amount: amountNum,
      fee: estFee,
      purpose: remitPurpose,
      cadence: 'monthly',
      date: dateStr,
      referenceNumber: generatedRef,
      status: 'sent',
    });

    if (remitAutoDeduct && remitAccountId) {
      addTransaction({
        type: 'expense',
        amount: amountNum + estFee,
        accountId: remitAccountId,
        category: 'Family Support & Remittance',
        note: `Padala to ${remitRecipient} (${remitProvince || 'Province'}) via ${remitChannel.replace(/_/g, ' ').toUpperCase()} [Fee: ₱${estFee}] Ref: ${generatedRef}`,
        date: dateStr,
        tags: ['padala', 'remittance', remitChannel],
      });
    }

    setShowAddRemittance(false);
    setRemitRecipient('');
    setRemitProvince('');
    setRemitAmount('');
    setRemitRef('');
  };

  const handleUpdate13thMonth = () => {
    const salary = parseFloat(salaryInput) || 0;
    const months = parseInt(monthsWorkedInput, 10) || 12;
    update13thMonthPlan(salary, months, 0.20);
  };

  const handleAllocationChange = (id: string, targetAmount: number) => {
    const updated: ThirteenthMonthAllocation[] = thirteenthMonthPlan.allocations.map((a) =>
      a.id === id ? { ...a, targetAmount: Math.max(0, targetAmount) } : a
    );
    update13thMonthAllocations(updated);
  };

  const handleLog13thMonthToLedger = () => {
    if (thirteenthMonthPlan.net13thMonthPay <= 0) return;
    const dateStr = new Date().toISOString().split('T')[0];
    addTransaction({
      type: 'income',
      amount: thirteenthMonthPlan.net13thMonthPay,
      accountId: bonusTargetAccountId,
      category: 'Income',
      note: `13th-Month Pay & Holiday Bonus (${thirteenthMonthPlan.monthsWorkedTotal} months credited, ₱${thirteenthMonthPlan.taxExemptAmount.toLocaleString()} tax-exempt)`,
      date: dateStr,
      tags: ['13th-month', 'bonus', 'sweldo'],
    });
    setBonusActionNotice(`Successfully posted ₱${thirteenthMonthPlan.net13thMonthPay.toLocaleString()} to your account!`);
    setTimeout(() => setBonusActionNotice(null), 4000);
  };

  const handleSync13thMonthToPayday = () => {
    if (thirteenthMonthPlan.net13thMonthPay <= 0) return;
    updatePayday({
      expectedIncome: thirteenthMonthPlan.net13thMonthPay,
    });
    setBonusActionNotice(`Updated next Payday sweldo expected income to ₱${thirteenthMonthPlan.net13thMonthPay.toLocaleString()}`);
    setTimeout(() => setBonusActionNotice(null), 4000);
  };

  const handleExecute13thAllocations = () => {
    const dateStr = new Date().toISOString().split('T')[0];
    let count = 0;
    thirteenthMonthPlan.allocations.forEach((alloc) => {
      if (alloc.targetAmount > 0) {
        addTransaction({
          type: 'expense',
          amount: alloc.targetAmount,
          accountId: bonusTargetAccountId,
          category: alloc.category || 'Savings & Investments',
          note: `13th-Month Plan: ${alloc.name} (${alloc.percentage}% of bonus)`,
          date: dateStr,
          tags: ['13th-month-allocation', 'bonus-distribution'],
        });
        count++;
      }
    });
    setBonusActionNotice(`Created ${count} allocation transactions in your ledger!`);
    setTimeout(() => setBonusActionNotice(null), 4000);
  };

  const handleExecuteRoutine = (templateId: string, name: string) => {
    const res = applyPaydayRoutine(templateId);
    if (res.success) {
      setRoutineAppliedNotice(`Successfully executed "${name}"! Created ${res.createdTxCount} ledger entries.`);
      setTimeout(() => setRoutineAppliedNotice(null), 4000);
    }
  };

  // Unified Tax Calculations
  const employeeTaxRes = calculateEmployeeTaxDeductions(parseFloat(taxMonthlySalary) || 0, 12);
  const freelanceTaxRes = calculateFreelanceTax(parseFloat(grossIncomeInput) || 0, taxOption);

  const handleSyncTaxToPayday = (amount: number) => {
    if (amount <= 0) return;
    const cutoffAmount = payday.cycleType === '15_30' ? Math.round(amount / 2) : Math.round(amount);
    updatePayday({
      expectedIncome: cutoffAmount,
    });
    setTaxSyncNotice(`Applied take-home pay (₱${cutoffAmount.toLocaleString()}/cutoff) to your Payday Pacing!`);
    setTimeout(() => setTaxSyncNotice(null), 4000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      {/* Modal Dialog */}
      <div className="relative w-full max-w-2xl bg-white dark:bg-[#27201A] rounded-3xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden border border-[#F3DFCD] dark:border-[#383029] animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-[#F3DFCD] dark:border-[#383029]">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52]">
              <Sparkles size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Philippine Financial Suite
              </h2>
              <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                Local tools crafted for Filipino earners, sweldo cycles &amp; families
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
          >
            <X size={20} />
          </button>
        </div>

        {/* Navigation Tabs */}
        <div className="flex border-b border-[#F3DFCD] dark:border-[#383029] overflow-x-auto bg-[#FFEEDF]/30 dark:bg-[#14100D]/40 px-3 py-1.5 gap-1 scrollbar-none">
          {[
            { id: 'remittance', label: 'Padala Tracker', icon: Send },
            { id: '13th_month', label: '13th-Month Planner', icon: Gift },
            { id: 'household', label: 'Ambagan sa Bahay', icon: Home },
            { id: 'payday_routine', label: 'Sweldo Routines', icon: CalendarCheck },
            { id: 'freelance_tax', label: 'TRAIN Tax & Take-Home', icon: Calculator },
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer ${
                  isActive
                    ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs border border-[#F3DFCD] dark:border-[#383029]'
                    : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
                }`}
              >
                <Icon size={14} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Tab Body */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6 space-y-5">
          {/* TAB 1: PADALA & REMITTANCE TRACKER */}
          {activeTab === 'remittance' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Provincial &amp; Family Padala Records
                  </h3>
                  <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    Track remittance channels, pickup codes, and auto-sync to accounts &amp; ledger
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setShowAddRemittance(!showAddRemittance)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-90 transition-all cursor-pointer shadow-xs"
                >
                  <Plus size={14} />
                  <span>Log Padala</span>
                </button>
              </div>

              {/* Add Padala Form */}
              {showAddRemittance && (
                <form
                  onSubmit={handleCreateRemittance}
                  className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/60 border border-[#F3DFCD] dark:border-[#383029] space-y-3 animate-in fade-in duration-150"
                >
                  <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                    <Send size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span>New Padala Outflow Entry</span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Recipient Name
                      </label>
                      <input
                        type="text"
                        required
                        value={remitRecipient}
                        onChange={(e) => setRemitRecipient(e.target.value)}
                        placeholder="e.g. Nanay Gloria, Kuya Jomar"
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Province / Destination
                      </label>
                      <input
                        type="text"
                        value={remitProvince}
                        onChange={(e) => setRemitProvince(e.target.value)}
                        placeholder="e.g. Iloilo, Pangasinan, Cebu"
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Amount (₱ PHP)
                      </label>
                      <input
                        type="number"
                        required
                        step="any"
                        value={remitAmount}
                        onChange={(e) => setRemitAmount(e.target.value)}
                        placeholder="0.00"
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Channel / Remittance Center
                      </label>
                      <select
                        value={remitChannel}
                        onChange={(e) => setRemitChannel(e.target.value as RemittanceChannel)}
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      >
                        {REMITTANCE_CHANNELS.map((ch: { id: RemittanceChannel; label: string; estFee: number }) => (
                          <option key={ch.id} value={ch.id}>
                            {ch.label} (Est. fee: ~₱{ch.estFee})
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Source Account / Wallet
                      </label>
                      <select
                        value={remitAccountId}
                        onChange={(e) => setRemitAccountId(e.target.value)}
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      >
                        {accounts.map((acc) => (
                          <option key={acc.id} value={acc.id}>
                            {acc.name} (₱{acc.balance.toLocaleString()})
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Purpose of Padala
                      </label>
                      <select
                        value={remitPurpose}
                        onChange={(e) => setRemitPurpose(e.target.value as RemitPurpose)}
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      >
                        {REMITTANCE_PURPOSES.map((p: { id: RemitPurpose; label: string }) => (
                          <option key={p.id} value={p.id}>
                            {p.label}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="sm:col-span-2">
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Claiming Reference Code (Optional)
                      </label>
                      <input
                        type="text"
                        value={remitRef}
                        onChange={(e) => setRemitRef(e.target.value)}
                        placeholder="e.g. PAL-901248-X"
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={remitAutoDeduct}
                        onChange={(e) => setRemitAutoDeduct(e.target.checked)}
                        className="w-4 h-4 rounded text-[#B03C09] cursor-pointer"
                      />
                      <span className="text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                        Deduct amount + fee from wallet balance &amp; post transaction
                      </span>
                    </label>

                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setShowAddRemittance(false)}
                        className="px-3 py-1.5 rounded-xl text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        className="px-4 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] cursor-pointer shadow-xs"
                      >
                        Save &amp; Post to Ledger
                      </button>
                    </div>
                  </div>
                </form>
              )}

              {/* Remittance Records List */}
              <div className="space-y-2.5">
                {remittances.length === 0 ? (
                  <div className="text-center py-8 text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    No remittance entries logged yet.
                  </div>
                ) : (
                  remittances.map((r) => (
                    <div
                      key={r.id}
                      className="p-3.5 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3 shadow-xs hover:border-[#B03C09]/40 transition-all"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] font-bold text-xs">
                          {r.channel === 'palawan_express'
                            ? 'PE'
                            : r.channel === 'cebuana_lhuillier'
                            ? 'CL'
                            : r.channel === 'gcash_padala'
                            ? 'GC'
                            : 'PD'}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                              {r.recipientName}
                            </span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded font-semibold bg-[#FFEEDF]/60 dark:bg-[#14100D] text-[#6B6156] dark:text-[#AC9E92]">
                              {r.provinceCity}
                            </span>
                          </div>
                          <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1.5 mt-0.5">
                            <span>{r.channel.replace(/_/g, ' ').toUpperCase()}</span>
                            <span>•</span>
                            <span>Ref: {r.referenceNumber || 'N/A'}</span>
                            <span>•</span>
                            <span>Fee: ₱{r.fee}</span>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-3">
                        <div className="text-right">
                          <div className="text-xs font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
                            -₱{r.amount.toLocaleString()}
                          </div>
                          <button
                            type="button"
                            onClick={() =>
                              updateRemittance(r.id, {
                                status: r.status === 'claimed' ? 'sent' : 'claimed',
                              })
                            }
                            className={`text-[10px] font-bold px-2 py-0.5 rounded-full inline-flex items-center gap-1 cursor-pointer transition-all ${
                              r.status === 'claimed'
                                ? 'bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E]'
                                : 'bg-[#FFF3D6] text-[#8C5800] dark:bg-[#3D2C0D] dark:text-[#FFD166]'
                            }`}
                          >
                            {r.status === 'claimed' ? (
                              <>
                                <CheckCircle2 size={10} />
                                <span>Claimed</span>
                              </>
                            ) : (
                              <>
                                <Clock size={10} />
                                <span>Sent / In Transit</span>
                              </>
                            )}
                          </button>
                        </div>
                        <button
                          type="button"
                          onClick={() => deleteRemittance(r.id)}
                          className="p-1.5 text-[#6B6156] dark:text-[#AC9E92] hover:text-[#D83A52] cursor-pointer"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

          {/* TAB 2: 13TH-MONTH PAY PLANNER */}
          {activeTab === '13th_month' && (
            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Gift size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      TRAIN Law 13th-Month Bonus Computation
                    </span>
                  </div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-white dark:bg-[#27201A] text-[#16643F] dark:text-[#5FCB8E] border border-[#F3DFCD] dark:border-[#383029]">
                    ₱90,000 Tax-Free Threshold
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                      Basic Monthly Salary (₱)
                    </label>
                    <input
                      type="number"
                      value={salaryInput}
                      onChange={(e) => setSalaryInput(e.target.value)}
                      onBlur={handleUpdate13thMonth}
                      className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                  <div>
                    <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                      Months Worked This Calendar Year
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="12"
                      value={monthsWorkedInput}
                      onChange={(e) => setMonthsWorkedInput(e.target.value)}
                      onBlur={handleUpdate13thMonth}
                      className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                </div>

                {/* KPI Breakdown */}
                <div className="grid grid-cols-3 gap-2 pt-2 border-t border-[#F3DFCD]/80 dark:border-[#383029]/80 text-center">
                  <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                    <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                      Gross Bonus
                    </div>
                    <div className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                      ₱{thirteenthMonthPlan.calculatedGrossAmount.toLocaleString()}
                    </div>
                  </div>
                  <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                    <div className="text-[10px] text-[#16643F] dark:text-[#5FCB8E]">
                      Tax-Exempt (TRAIN)
                    </div>
                    <div className="text-xs font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                      ₱{thirteenthMonthPlan.taxExemptAmount.toLocaleString()}
                    </div>
                  </div>
                  <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                    <div className="text-[10px] text-[#B03C09] dark:text-[#FF9A52]">
                      Net Take-Home
                    </div>
                    <div className="text-xs font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
                      ₱{thirteenthMonthPlan.net13thMonthPay.toLocaleString()}
                    </div>
                  </div>
                </div>

                {/* Direct Ledger & Payday Action Bar */}
                {bonusActionNotice && (
                  <div className="p-2.5 rounded-xl bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E] text-xs font-bold animate-in fade-in">
                    {bonusActionNotice}
                  </div>
                )}

                <div className="pt-2 border-t border-[#F3DFCD]/80 dark:border-[#383029]/80 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">Target Account:</span>
                    <select
                      value={bonusTargetAccountId}
                      onChange={(e) => setBonusTargetAccountId(e.target.value)}
                      className="px-2.5 py-1 text-xs font-bold rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8]"
                    >
                      {accounts.map((acc) => (
                        <option key={acc.id} value={acc.id}>
                          {acc.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={handleLog13thMonthToLedger}
                      className="flex-1 sm:flex-none px-3 py-1.5 rounded-xl bg-[#16643F] dark:bg-[#5FCB8E] text-white dark:text-[#0C2B1B] text-xs font-bold hover:opacity-90 transition-all cursor-pointer shadow-xs"
                    >
                      Post ₱{thirteenthMonthPlan.net13thMonthPay.toLocaleString()} Income
                    </button>
                    <button
                      type="button"
                      onClick={handleSync13thMonthToPayday}
                      className="flex-1 sm:flex-none px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold hover:bg-[#FFEEDF]/30 transition-all cursor-pointer"
                    >
                      Sync to Payday
                    </button>
                  </div>
                </div>
              </div>

              {/* Bonus Allocations Planner */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    13th-Month Allocation Strategy
                  </h4>
                  <button
                    type="button"
                    onClick={handleExecute13thAllocations}
                    className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                  >
                    Execute Allocations into Ledger →
                  </button>
                </div>

                <div className="space-y-2">
                  {thirteenthMonthPlan.allocations.map((alloc) => (
                    <div
                      key={alloc.id}
                      className="p-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3"
                    >
                      <div>
                        <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {alloc.name}
                        </div>
                        <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                          {alloc.note || alloc.category}
                        </div>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-[#6B6156]">₱</span>
                        <input
                          type="number"
                          step="100"
                          value={alloc.targetAmount}
                          onChange={(e) =>
                            handleAllocationChange(alloc.id, parseFloat(e.target.value) || 0)
                          }
                          className="w-24 px-2 py-1 text-right text-xs font-bold rounded-lg bg-[#FFEEDF]/50 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* TAB 3: AMBAGAN SA BAHAY */}
          {activeTab === 'household' && (
            <div className="space-y-4">
              <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {householdAmbag.name}
                    </h3>
                    <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                      Target: ₱{householdAmbag.totalMonthlyExpenseTarget.toLocaleString()} for {householdAmbag.cycleMonth}
                    </p>
                  </div>
                  <div className="text-right">
                    <span className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92]">
                      Collected So Far
                    </span>
                    <div className="text-sm font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                      ₱{householdAmbag.totalCollectedThisMonth.toLocaleString()}
                    </div>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="w-full bg-[#FFEEDF] dark:bg-[#14100D] h-2.5 rounded-full overflow-hidden mb-4">
                  <div
                    className="bg-[#16643F] dark:bg-[#5FCB8E] h-full transition-all duration-300"
                    style={{
                      width: `${Math.min(
                        100,
                        householdAmbag.totalMonthlyExpenseTarget > 0
                          ? (householdAmbag.totalCollectedThisMonth /
                              householdAmbag.totalMonthlyExpenseTarget) *
                              100
                          : 0
                      )}%`,
                    }}
                  />
                </div>

                {/* Members contribution list */}
                <div className="space-y-2">
                  {householdAmbag.members.map((member) => (
                    <div
                      key={member.id}
                      className="p-3 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/40 border border-[#F3DFCD]/80 dark:border-[#383029]/80 flex items-center justify-between gap-3"
                    >
                      <div>
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                            {member.name}
                          </span>
                          <span className="text-[10px] px-1.5 py-0.2 rounded bg-white dark:bg-[#27201A] font-semibold text-[#6B6156]">
                            {member.relation}
                          </span>
                        </div>
                        <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5">
                          Target: ₱{member.monthlyExpectedAmbag.toLocaleString()} · Paid: ₱{member.actualPaidThisMonth.toLocaleString()}
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        {member.isSettled ? (
                          <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E] flex items-center gap-1">
                            <CheckCircle2 size={12} />
                            <span>Paid</span>
                          </span>
                        ) : (
                          <button
                            type="button"
                            onClick={() => {
                              const remaining = member.monthlyExpectedAmbag - member.actualPaidThisMonth;
                              recordHouseholdAmbagPayment(member.id, remaining);
                              if (member.name === 'Ako (Self)') {
                                addTransaction({
                                  type: 'expense',
                                  amount: remaining,
                                  accountId: accounts[0]?.id || 'acc-cash',
                                  category: 'Bills & Utilities',
                                  note: `Ambagan sa Bahay: ${member.name} contribution`,
                                  date: new Date().toISOString().split('T')[0],
                                  tags: ['ambagan', 'household'],
                                });
                              }
                            }}
                            className="px-2.5 py-1 rounded-lg text-xs font-bold bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-90 transition-all cursor-pointer shadow-xs"
                          >
                            Mark Paid
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* TAB 4: PAYDAY DISTRIBUTION ROUTINES */}
          {activeTab === 'payday_routine' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Sweldo Cutoff Automation Templates
                  </h3>
                  <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    Distribute your 15th/30th quincena salary to bills, MP2/savings, and guilt-free spend with 1 tap
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">Payroll Account:</span>
                  <select
                    value={selectedRoutineAccountId}
                    onChange={(e) => setSelectedRoutineAccountId(e.target.value)}
                    className="px-2.5 py-1 text-xs font-bold rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8]"
                  >
                    {accounts.map((acc) => (
                      <option key={acc.id} value={acc.id}>
                        {acc.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {routineAppliedNotice && (
                <div className="p-3 rounded-xl bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E] text-xs font-bold animate-in fade-in">
                  {routineAppliedNotice}
                </div>
              )}

              <div className="space-y-3">
                {paydayTemplates.map((template) => (
                  <div
                    key={template.id}
                    className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-3 shadow-xs"
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {template.name}
                        </div>
                        <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                          Base Sweldo: ₱{template.baseSalary.toLocaleString()} · {template.cutoff} cutoff
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleExecuteRoutine(template.id, template.name)}
                        className="px-3 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-90 transition-all cursor-pointer shadow-xs"
                      >
                        Apply on Payday
                      </button>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                      {template.items.map((item, idx) => (
                        <div
                          key={idx}
                          className="flex items-center justify-between p-2 rounded-lg bg-[#FFEEDF]/30 dark:bg-[#14100D]/40 text-xs"
                        >
                          <span className="font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                            {item.name}
                          </span>
                          <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                            ₱{item.amount.toLocaleString()}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 5: UNIFIED TRAIN TAX & TAKE-HOME ENGINE */}
          {activeTab === 'freelance_tax' && (
            <div className="space-y-4">
              {/* Type Switcher */}
              <div className="flex rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] p-1 border border-[#F3DFCD] dark:border-[#383029]">
                <button
                  type="button"
                  onClick={() => setTaxMode('employed')}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    taxMode === 'employed'
                      ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                      : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  <Building2 size={13} />
                  <span>Employed (TRAIN Law &amp; Deductions)</span>
                </button>
                <button
                  type="button"
                  onClick={() => setTaxMode('freelance')}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                    taxMode === 'freelance'
                      ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                      : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  <Briefcase size={13} />
                  <span>Freelancer &amp; 8% Flat GIT</span>
                </button>
              </div>

              {taxSyncNotice && (
                <div className="p-3 rounded-xl bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E] text-xs font-bold animate-in fade-in">
                  {taxSyncNotice}
                </div>
              )}

              {taxMode === 'employed' ? (
                <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                  <div>
                    <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                      Monthly Basic Gross Salary (₱)
                    </label>
                    <input
                      type="number"
                      value={taxMonthlySalary}
                      onChange={(e) => setTaxMonthlySalary(e.target.value)}
                      className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>

                  {/* Deductions Breakdown */}
                  <div className="grid grid-cols-3 gap-2 pt-2 border-t border-[#F3DFCD]/80 dark:border-[#383029]/80 text-center">
                    <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                      <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">SSS Employee</div>
                      <div className="text-xs font-extrabold text-[#D83A52]">₱{employeeTaxRes.sss.toLocaleString()}</div>
                    </div>
                    <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                      <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">PhilHealth (2.5%)</div>
                      <div className="text-xs font-extrabold text-[#D83A52]">₱{employeeTaxRes.philhealth.toLocaleString()}</div>
                    </div>
                    <div className="p-2 rounded-xl bg-white dark:bg-[#27201A]">
                      <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Pag-IBIG Fund</div>
                      <div className="text-xs font-extrabold text-[#D83A52]">₱{employeeTaxRes.pagibig.toLocaleString()}</div>
                    </div>
                  </div>

                  {/* Tax & Net */}
                  <div className="grid grid-cols-2 gap-2 text-center">
                    <div className="p-2.5 rounded-xl bg-white dark:bg-[#27201A]">
                      <div className="text-[10px] text-[#6B6156]">BIR Withholding Tax</div>
                      <div className="text-xs font-bold text-[#D83A52]">₱{employeeTaxRes.withholdingTax.toLocaleString()}</div>
                    </div>
                    <div className="p-2.5 rounded-xl bg-white dark:bg-[#27201A]">
                      <div className="text-[10px] text-[#16643F] dark:text-[#5FCB8E]">Monthly Net Take-Home</div>
                      <div className="text-xs font-extrabold text-[#16643F] dark:text-[#5FCB8E]">₱{employeeTaxRes.netTakeHome.toLocaleString()}</div>
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleSyncTaxToPayday(employeeTaxRes.netTakeHome)}
                    className="w-full py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold hover:opacity-90 transition-all cursor-pointer shadow-xs flex items-center justify-center gap-1.5"
                  >
                    <Check size={14} />
                    <span>Sync Net Pay (₱{employeeTaxRes.semiMonthlyTakeHome.toLocaleString()}/quincena) to Payday</span>
                  </button>
                </div>
              ) : (
                <div className="p-4 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      Freelancer / Self-Employed BIR Form 1701Q Evaluator
                    </span>
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52]">
                      TRAIN Law 8% Flat vs Graduated
                    </span>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Annual Gross Professional Income (₱)
                      </label>
                      <input
                        type="number"
                        value={grossIncomeInput}
                        onChange={(e) => setGrossIncomeInput(e.target.value)}
                        className="w-full mt-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        Tax Scheme Selection
                      </label>
                      <div className="flex gap-2 mt-1">
                        <button
                          type="button"
                          onClick={() => setTaxOption('8_percent_git')}
                          className={`flex-1 py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                            taxOption === '8_percent_git'
                              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                              : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                          }`}
                        >
                          8% Flat GIT
                        </button>
                        <button
                          type="button"
                          onClick={() => setTaxOption('graduated_rates')}
                          className={`flex-1 py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                            taxOption === 'graduated_rates'
                              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                              : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                          }`}
                        >
                          Graduated Rates
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Recommendation Box */}
                  <div className="p-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Tax Analysis Summary
                      </span>
                      <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-[#E1F5EA] text-[#16643F] dark:bg-[#123824] dark:text-[#5FCB8E]">
                        Effective Tax Rate: {freelanceTaxRes.effectiveTaxRate.toFixed(1)}%
                      </span>
                    </div>
                    <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                      {taxOption === '8_percent_git'
                        ? '8% Flat Gross Income Tax with PHP 250,000 standard deduction simplifies accounting without needing itemized receipt deductions.'
                        : 'Graduated tax rates under TRAIN Law calculate tax by income tiers up to 35%.'}
                    </p>

                    <div className="grid grid-cols-2 gap-2 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 text-center">
                      <div className="p-2 rounded-lg bg-[#FFEEDF]/30 dark:bg-[#14100D]/30">
                        <div className="text-[10px] text-[#6B6156]">Estimated Annual Tax Due</div>
                        <div className="text-xs font-bold text-[#D83A52]">
                          ₱{freelanceTaxRes.estimatedTaxDue.toLocaleString()}
                        </div>
                      </div>
                      <div className="p-2 rounded-lg bg-[#FFEEDF]/30 dark:bg-[#14100D]/30">
                        <div className="text-[10px] text-[#6B6156]">Monthly Tax Provision</div>
                        <div className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E]">
                          ₱{Math.round(freelanceTaxRes.monthlyTaxProvision).toLocaleString()}
                        </div>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => {
                        const monthlyNet = ((parseFloat(grossIncomeInput) || 0) - freelanceTaxRes.estimatedTaxDue) / 12;
                        handleSyncTaxToPayday(monthlyNet);
                      }}
                      className="w-full mt-2 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold hover:opacity-90 transition-all cursor-pointer shadow-xs flex items-center justify-center gap-1.5"
                    >
                      <Check size={14} />
                      <span>Sync Net Freelance Income to Payday</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

