import React, { useState } from 'react';
import {
  CreditCard,
  Plus,
  CheckCircle2,
  Calendar,
  Sparkles,
  TrendingDown,
  Trash2,
  ChevronDown,
  ChevronUp,
  Clock,
  ArrowRight,
  ShieldCheck,
  Zap,
  X,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { InstallmentPlan } from '../types';
import { generateInstallmentAmortization } from '../utils/loanCalculators';

export const InstallmentsView: React.FC = () => {
  const {
    installments,
    accounts,
    addInstallment,
    deleteInstallment,
    recordInstallmentPayment,
    recordInstallmentExtraPayment,
  } = useFinancial();

  const [showAddModal, setShowAddModal] = useState(false);
  const [selectedPlanForExtra, setSelectedPlanForExtra] = useState<InstallmentPlan | null>(null);
  const [extraPaymentAmount, setExtraPaymentAmount] = useState('');
  const [extraPaymentNote, setExtraPaymentNote] = useState('');
  const [payingPlanId, setPayingPlanId] = useState<string | null>(null);
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [expandedAmortPlanId, setExpandedAmortPlanId] = useState<string | null>(null);

  // Form states for new installment
  const [name, setName] = useState('');
  const [provider, setProvider] = useState('Home Credit');
  const [principal, setPrincipal] = useState('');
  const [interestRate, setInterestRate] = useState('0');
  const [termMonths, setTermMonths] = useState('12');
  const [isZeroPercent, setIsZeroPercent] = useState(false);
  const [notes, setNotes] = useState('');

  // Summary Metrics
  const activePlans = installments.filter((p) => !p.isSettled);
  const settledPlans = installments.filter((p) => p.isSettled);

  const totalRunningBalance = activePlans.reduce((sum, p) => sum + p.runningBalance, 0);
  const totalMonthlyCommitment = activePlans.reduce((sum, p) => sum + p.installmentAmount, 0);

  // Calculate total interest avoided by 0% plans vs typical 3% monthly rate
  const interestAvoided = installments
    .filter((p) => p.interestRate === 0)
    .reduce((sum, p) => sum + p.principal * 0.03 * (p.termMonths / 2), 0);

  const handleCreateInstallment = (e: React.FormEvent) => {
    e.preventDefault();
    const principalNum = parseFloat(principal);
    const monthsNum = parseInt(termMonths, 10);
    const rateNum = isZeroPercent ? 0 : parseFloat(interestRate) || 0;

    if (!name || isNaN(principalNum) || principalNum <= 0 || isNaN(monthsNum) || monthsNum <= 0) {
      return;
    }

    const totalInterest = rateNum > 0 ? principalNum * (rateNum / 100) * (monthsNum / 12) : 0;
    const totalPayable = principalNum + totalInterest;
    const monthlyAmt = totalPayable / monthsNum;

    const startDate = new Date().toISOString().split('T')[0];
    const matDate = new Date();
    matDate.setMonth(matDate.getMonth() + monthsNum);
    const maturityDate = matDate.toISOString().split('T')[0];

    addInstallment({
      name,
      provider,
      principal: principalNum,
      interestRate: rateNum,
      interestRateType: rateNum === 0 ? 'fixed' : 'monthly',
      totalInterest,
      totalPayable,
      termMonths: monthsNum,
      paymentFrequency: 'monthly',
      startDate,
      maturityDate,
      installmentAmount: monthlyAmt,
      paidInstallments: 0,
      totalInstallments: monthsNum,
      runningBalance: totalPayable,
      principalRemaining: principalNum,
      interestRemaining: totalInterest,
      extraPayments: [],
      isSettled: false,
      notes,
    });

    setName('');
    setPrincipal('');
    setInterestRate('0');
    setTermMonths('12');
    setIsZeroPercent(false);
    setNotes('');
    setShowAddModal(false);
  };

  const handleConfirmExtraPayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedPlanForExtra) return;
    const amt = parseFloat(extraPaymentAmount);
    if (isNaN(amt) || amt <= 0) return;

    recordInstallmentExtraPayment(
      selectedPlanForExtra.id,
      amt,
      extraPaymentNote || 'Principal reduction prepayment',
      selectedAccountId
    );

    setSelectedPlanForExtra(null);
    setExtraPaymentAmount('');
    setExtraPaymentNote('');
  };

  const handlePayInstallment = (planId: string) => {
    recordInstallmentPayment(planId, selectedAccountId);
    setPayingPlanId(null);
  };

  return (
    <div className="space-y-4">
      {/* Top Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs min-w-0">
          <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
            Total Installment Debt
          </span>
          <div className="text-xl sm:text-2xl font-black text-[#15120F] dark:text-[#F6EFE8] mt-1 tabular-nums truncate">
            {formatPeso(totalRunningBalance)}
          </div>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1 truncate">
            Across {activePlans.length} active plans
          </p>
        </div>

        <div className="p-3.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs min-w-0">
          <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
            Monthly Commitment
          </span>
          <div className="text-xl sm:text-2xl font-black text-[#B03C09] dark:text-[#FF9A52] mt-1 tabular-nums truncate">
            {formatPeso(totalMonthlyCommitment)}
          </div>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-1 truncate">
            Reserved each billing cycle
          </p>
        </div>
      </div>

      {/* 0% Interest Avoided Badge */}
      {interestAvoided > 0 && (
        <div className="p-3 bg-emerald-50 dark:bg-emerald-950/40 rounded-2xl border border-emerald-200 dark:border-emerald-800 flex items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2 text-emerald-800 dark:text-emerald-200">
            <Sparkles size={16} className="text-emerald-600 shrink-0" />
            <span className="font-semibold">
              You avoided approx. <strong className="font-bold">{formatPeso(interestAvoided)}</strong> in interest via 0% installment promotions!
            </span>
          </div>
        </div>
      )}

      {/* Header & Add Button */}
      <div className="flex items-center justify-between pt-1">
        <div>
          <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
            Active Installment Plans ({activePlans.length})
          </h3>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
            BNPL, gadget loans, and 0% credit card SIP promos
          </p>
        </div>

        <button
          type="button"
          onClick={() => setShowAddModal(true)}
          className="px-3 py-1.5 rounded-xl bg-[#B03C09] text-white text-xs font-bold hover:bg-[#8F3006] transition-colors flex items-center gap-1.5 cursor-pointer shadow-xs"
        >
          <Plus size={14} />
          <span>Add Plan</span>
        </button>
      </div>

      {/* Plans List */}
      <div className="space-y-3">
        {activePlans.length === 0 ? (
          <div className="p-8 text-center bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] text-[#7A6E63] dark:text-[#A89A8D] text-xs">
            No active installment plans. You are installment-free!
          </div>
        ) : (
          activePlans.map((plan) => {
            const progressPercent = Math.min(100, Math.round((plan.paidInstallments / plan.totalInstallments) * 100));
            const isZeroInterest = plan.interestRate === 0;
            const isAmortExpanded = expandedAmortPlanId === plan.id;
            const amortization = isAmortExpanded ? generateInstallmentAmortization(plan) : [];

            return (
              <div
                key={plan.id}
                className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs overflow-hidden"
              >
                <div className="p-4 space-y-3">
                  {/* Title & Badges */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {plan.name}
                        </span>
                        {isZeroInterest ? (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300">
                            Real 0% Interest
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300">
                            {plan.interestRate}% {plan.interestRateType}
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5">
                        {plan.provider} • Started {plan.startDate}
                      </p>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                        {formatPeso(plan.runningBalance)}
                      </span>
                      <span className="block text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        running balance
                      </span>
                    </div>
                  </div>

                  {/* Progress Track */}
                  <div className="space-y-1">
                    <div className="flex justify-between text-[11px] font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      <span>{plan.paidInstallments} of {plan.totalInstallments} paid</span>
                      <span>{progressPercent}%</span>
                    </div>
                    <div className="w-full h-2 bg-[#FFEEDF] dark:bg-[#1A1410] rounded-full overflow-hidden">
                      <div
                        className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full transition-all duration-300"
                        style={{ width: `${progressPercent}%` }}
                      />
                    </div>
                  </div>

                  {/* Monthly amount & Next Action */}
                  <div className="pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 flex flex-wrap items-center justify-between gap-2 text-xs">
                    <div>
                      <span className="text-[10px] uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block">
                        Monthly Due
                      </span>
                      <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] tabular-nums">
                        {formatPeso(plan.installmentAmount)} / mo
                      </span>
                    </div>

                    <div className="flex items-center gap-2 ml-auto">
                      <button
                        type="button"
                        onClick={() => setSelectedPlanForExtra(plan)}
                        className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-black/5 dark:bg-white/5 hover:bg-black/10 text-[#5A5148] dark:text-[#C6B8AC] transition-colors cursor-pointer"
                      >
                        Prepay / Extra
                      </button>

                      <button
                        type="button"
                        onClick={() => handlePayInstallment(plan.id)}
                        className="px-3 py-1 text-xs font-bold rounded-lg bg-[#B03C09] text-white hover:bg-[#8F3006] transition-colors cursor-pointer shadow-xs flex items-center gap-1"
                      >
                        <CheckCircle2 size={13} />
                        <span>Pay #{plan.paidInstallments + 1}</span>
                      </button>

                      <button
                        type="button"
                        onClick={() => deleteInstallment(plan.id)}
                        className="p-1 text-[#7A6E63] hover:text-rose-500 transition-colors cursor-pointer"
                        title="Delete installment"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>

                  {/* Extra Payments Log if any */}
                  {plan.extraPayments && plan.extraPayments.length > 0 && (
                    <div className="p-2.5 bg-[#FFF9F3] dark:bg-[#1E1915] rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-[11px] space-y-1">
                      <span className="font-bold text-emerald-700 dark:text-emerald-400">
                        Extra Prepayments Recorded:
                      </span>
                      {plan.extraPayments.map((p) => (
                        <div key={p.id} className="flex justify-between text-[#7A6E63] dark:text-[#A89A8D]">
                          <span>{p.date} - {p.note}</span>
                          <span className="font-semibold text-emerald-600 dark:text-emerald-400 tabular-nums">
                            -{formatPeso(p.amount)}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Schedule Toggle */}
                  <div className="pt-1">
                    <button
                      type="button"
                      onClick={() => setExpandedAmortPlanId(isAmortExpanded ? null : plan.id)}
                      className="text-[11px] font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-1 hover:underline cursor-pointer"
                    >
                      <span>{isAmortExpanded ? 'Hide' : 'View'} Amortization Schedule</span>
                      {isAmortExpanded ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                    </button>

                    {isAmortExpanded && (
                      <div className="mt-2 max-h-48 overflow-y-auto border border-[#F3DFCD] dark:border-[#383029] rounded-xl text-[10px] font-mono">
                        <table className="w-full text-left">
                          <thead className="bg-[#FFEEDF] dark:bg-[#2A221C] sticky top-0">
                            <tr>
                              <th className="p-1.5">Mo.</th>
                              <th className="p-1.5">Payment</th>
                              <th className="p-1.5">Principal</th>
                              <th className="p-1.5">Interest</th>
                              <th className="p-1.5">Balance</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-[#F3DFCD]/60 dark:divide-[#383029]/60">
                            {amortization.map((row) => (
                              <tr key={row.period} className={row.period <= plan.paidInstallments ? 'opacity-40 line-through' : ''}>
                                <td className="p-1.5">{row.period}</td>
                                <td className="p-1.5 tabular-nums">{formatPeso(row.scheduledPayment, false)}</td>
                                <td className="p-1.5 tabular-nums">{formatPeso(row.principalComponent, false)}</td>
                                <td className="p-1.5 tabular-nums">{formatPeso(row.interestComponent, false)}</td>
                                <td className="p-1.5 tabular-nums">{formatPeso(row.remainingBalance, false)}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Add Plan Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-[#FFF9F3] dark:bg-[#1E1915] rounded-3xl border border-[#F3DFCD] dark:border-[#383029] p-5 shadow-2xl space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="text-sm font-bold">Add Installment / BNPL Plan</h3>
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="p-1 text-[#7A6E63] hover:text-[#15120F]"
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleCreateInstallment} className="space-y-3 text-xs">
              <div>
                <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Item / Purchase</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. iPad 10th Gen for Online Classes"
                  className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                  required
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Provider</label>
                  <select
                    value={provider}
                    onChange={(e) => setProvider(e.target.value)}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                  >
                    <option value="Home Credit">Home Credit</option>
                    <option value="SPayLater">SPayLater</option>
                    <option value="LazPayLater">LazPayLater</option>
                    <option value="BPI SIP (Special Installment)">BPI SIP</option>
                    <option value="BDO EasyPay">BDO EasyPay</option>
                    <option value="Metrobank 0%">Metrobank 0%</option>
                    <option value="UnionBank PayEasy">UnionBank PayEasy</option>
                    <option value="Tonik Quick Loan">Tonik Quick Loan</option>
                    <option value="Other Installment">Other</option>
                  </select>
                </div>

                <div>
                  <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Principal Amount (₱)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={principal}
                    onChange={(e) => setPrincipal(e.target.value)}
                    placeholder="0.00"
                    className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Term (Months)</label>
                  <select
                    value={termMonths}
                    onChange={(e) => setTermMonths(e.target.value)}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                  >
                    <option value="3">3 Months</option>
                    <option value="6">6 Months</option>
                    <option value="9">9 Months</option>
                    <option value="12">12 Months</option>
                    <option value="18">18 Months</option>
                    <option value="24">24 Months</option>
                    <option value="36">36 Months</option>
                  </select>
                </div>

                <div>
                  <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Interest Rate (%)</label>
                  <input
                    type="number"
                    step="0.01"
                    disabled={isZeroPercent}
                    value={isZeroPercent ? '0' : interestRate}
                    onChange={(e) => setInterestRate(e.target.value)}
                    placeholder="0"
                    className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] disabled:opacity-50"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="zeroPromo"
                  checked={isZeroPercent}
                  onChange={(e) => {
                    setIsZeroPercent(e.target.checked);
                    if (e.target.checked) setInterestRate('0');
                  }}
                  className="rounded text-[#B03C09] focus:ring-0"
                />
                <label htmlFor="zeroPromo" className="cursor-pointer font-semibold text-emerald-700 dark:text-emerald-400">
                  Real 0% Interest Promo (No add-on)
                </label>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 text-[#7A6E63] hover:text-[#15120F]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 font-bold rounded-xl bg-[#B03C09] text-white hover:bg-[#8F3006]"
                >
                  Save Plan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Extra Payment Modal */}
      {selectedPlanForExtra && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-[#FFF9F3] dark:bg-[#1E1915] rounded-3xl border border-[#F3DFCD] dark:border-[#383029] p-5 shadow-2xl space-y-3">
            <h3 className="text-sm font-bold">Extra Principal Prepayment</h3>
            <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D]">
              Directly reduce the principal balance for <strong>{selectedPlanForExtra.name}</strong>.
            </p>

            <form onSubmit={handleConfirmExtraPayment} className="space-y-3 text-xs">
              <div>
                <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Prepayment Amount (₱)</label>
                <input
                  type="number"
                  step="0.01"
                  value={extraPaymentAmount}
                  onChange={(e) => setExtraPaymentAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                  required
                />
              </div>

              <div>
                <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Account to Deduct</label>
                <select
                  value={selectedAccountId}
                  onChange={(e) => setSelectedAccountId(e.target.value)}
                  className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                >
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.name} ({formatPeso(acc.balance)})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="font-semibold text-[#7A6E63] dark:text-[#A89A8D]">Note / Reason</label>
                <input
                  type="text"
                  value={extraPaymentNote}
                  onChange={(e) => setExtraPaymentNote(e.target.value)}
                  placeholder="e.g. 13th-month bonus allocation"
                  className="w-full mt-1 p-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setSelectedPlanForExtra(null)}
                  className="px-3 py-1.5 text-[#7A6E63]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 font-bold rounded-xl bg-emerald-600 text-white hover:bg-emerald-700"
                >
                  Apply Prepayment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
