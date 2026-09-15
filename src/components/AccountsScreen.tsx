import React, { useState } from 'react';
import { Plus, X, ChevronRight, HandCoins } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Account, AccountKind } from '../types';

interface AccountsScreenProps {
  onOpenDebt: () => void;
}

export const AccountsScreen: React.FC<AccountsScreenProps> = ({ onOpenDebt }) => {
  const {
    accounts,
    netWorth,
    totalAssets,
    totalCreditUsed,
    totalDebtsIOwe,
    totalDebtsOwedToMe,
    addAccount,
  } = useFinancial();

  const [showAddModal, setShowAddModal] = useState(false);
  const [accountName, setAccountName] = useState('');
  const [kind, setKind] = useState<AccountKind>('cash');
  const [institution, setInstitution] = useState('GCash');
  const [balanceStr, setBalanceStr] = useState('');
  const [creditLimitStr, setCreditLimitStr] = useState('');
  const [dueDate, setDueDate] = useState('');

  const cashAccounts = accounts.filter((a) => a.kind === 'cash');
  const bankAccounts = accounts.filter((a) => a.kind === 'bank');
  const creditAccounts = accounts.filter((a) => a.kind === 'credit');

  const handleAddAccount = (e: React.FormEvent) => {
    e.preventDefault();
    const balance = parseFloat(balanceStr) || 0;
    const creditLimit = creditLimitStr ? parseFloat(creditLimitStr) : undefined;
    if (!accountName.trim()) return;

    let monogram = accountName.slice(0, 2).toUpperCase();
    if (institution === 'GCash') monogram = 'GC';
    else if (institution === 'Maya') monogram = 'MY';
    else if (institution === 'BPI') monogram = 'BPI';
    else if (institution === 'BDO') monogram = 'BDO';
    else if (institution === 'UnionBank') monogram = 'UB';
    else if (institution === 'SeaBank') monogram = 'SB';
    else if (institution === 'Cash') monogram = '₱';

    addAccount({
      name: accountName.trim(),
      kind,
      institution,
      balance,
      creditLimit,
      dueDate: dueDate.trim() || undefined,
      monogram,
    });

    setShowAddModal(false);
    setAccountName('');
    setBalanceStr('');
    setCreditLimitStr('');
    setDueDate('');
  };

  return (
    <div className="flex flex-col gap-4 pb-24">
      {/* Title & Add */}
      <div className="flex items-center justify-between pt-2 px-1">
        <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
          Accounts
        </h1>
        <button
          type="button"
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
        >
          <Plus size={14} /> Add
        </button>
      </div>

      {/* Hero: Net Worth Card */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-5 shadow-xs">
        <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
          Net Worth
        </span>
        <div className="text-3xl sm:text-4xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] my-1">
          {formatPeso(netWorth)}
        </div>
        <p className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
          Assets <strong className="text-[#16643F] dark:text-[#5FCB8E]">{formatPeso(totalAssets)}</strong> · Debts <strong className="text-[#B03C09] dark:text-[#FF9A52]">{formatPeso(totalCreditUsed + totalDebtsIOwe)}</strong>
        </p>
      </div>

      {/* Section 1: Cash & E-wallets */}
      <div className="flex flex-col gap-2">
        <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
          Cash and e-wallets ({cashAccounts.length})
        </h2>
        <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
          {cashAccounts.map((acc) => (
            <div
              key={acc.id}
              className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center font-bold text-xs text-[#B03C09] dark:text-[#FF9A52]">
                  {acc.monogram}
                </div>
                <div className="flex flex-col">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {acc.name}
                  </span>
                  <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    {acc.institution}
                  </span>
                </div>
              </div>

              <span className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                {formatPeso(acc.balance)}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Section 2: Bank Accounts */}
      <div className="flex flex-col gap-2">
        <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
          Banks ({bankAccounts.length})
        </h2>
        <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
          {bankAccounts.map((acc) => (
            <div
              key={acc.id}
              className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center font-bold text-xs text-[#15120F] dark:text-[#F6EFE8]">
                  {acc.monogram}
                </div>
                <div className="flex flex-col">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {acc.name}
                  </span>
                  <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    {acc.institution}
                    {['SeaBank', 'Maya', 'GoTyme', 'Tonik', 'CIMB'].includes(acc.institution) && acc.balance > 0
                      ? ` · ~${formatPeso((acc.balance * 0.045) / 12)}/mo interest`
                      : ''}
                  </span>
                </div>
              </div>

              <span className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                {formatPeso(acc.balance)}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Section 3: Credit Cards & Bank Officer Credit Radar */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between px-1">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
            Credit ({creditAccounts.length})
          </h2>
          <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
            Target: &lt;30% Utilization
          </span>
        </div>

        {/* Credit Radar Alert if any card is above 30% */}
        {creditAccounts.some((acc) => Math.round((acc.balance / (acc.creditLimit || 40000)) * 100) > 30) && (
          <div className="p-3.5 rounded-2xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 border border-[#B03C09]/20 dark:border-[#FF9A52]/20 flex flex-col gap-1.5">
            <div className="flex items-center gap-1.5 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
              <span>⚠️ Bank Officer Credit Radar</span>
            </div>
            <p className="text-[11px] leading-relaxed text-[#5A5148] dark:text-[#C6B8AC]">
              {(() => {
                const highCard = creditAccounts.find((acc) => Math.round((acc.balance / (acc.creditLimit || 40000)) * 100) > 30);
                if (!highCard) return null;
                const limit = highCard.creditLimit || 40000;
                const util = Math.round((highCard.balance / limit) * 100);
                const safeMax = limit * 0.3;
                const paydownNeeded = highCard.balance - safeMax;
                return `${highCard.name} is at ${util}% utilization. Paying down ${formatPeso(paydownNeeded)} brings it under the 30% threshold (${formatPeso(safeMax)}) to protect your BSP credit score.`;
              })()}
            </p>
          </div>
        )}

        <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
          {creditAccounts.map((acc) => {
            const limit = acc.creditLimit || 40000;
            const utilization = Math.round((acc.balance / limit) * 100);
            const isHighUtil = utilization > 30;

            return (
              <div key={acc.id} className="p-3.5 flex flex-col gap-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center font-bold text-xs text-[#B03C09] dark:text-[#FF9A52]">
                      {acc.monogram}
                    </div>
                    <div className="flex flex-col">
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {acc.name}
                        </span>
                        {isHighUtil && (
                          <span className="text-[9px] font-bold px-1.5 py-0.2 rounded-full bg-[#B03C09]/20 text-[#B03C09] dark:text-[#FF9A52]">
                            &gt;30%
                          </span>
                        )}
                      </div>
                      <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        {utilization}% of {formatPeso(limit)} limit {acc.dueDate ? `· due ${acc.dueDate}` : ''}
                      </span>
                    </div>
                  </div>

                  <span className="text-sm font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
                    {formatPeso(acc.balance)}
                  </span>
                </div>

                {/* Utilisation ThinBar */}
                <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-300 ${
                      isHighUtil
                        ? 'bg-[#B03C09] dark:bg-[#FF9A52]'
                        : 'bg-[#16643F] dark:bg-[#5FCB8E]'
                    }`}
                    style={{ width: `${Math.min(100, utilization)}%` }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Section 4: Debt summary linking to Debt screen */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between px-1">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
            Debt Overview
          </h2>
          <button
            type="button"
            onClick={onOpenDebt}
            className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-0.5 hover:underline cursor-pointer"
          >
            Open Screen <ChevronRight size={14} />
          </button>
        </div>

        <div
          onClick={onOpenDebt}
          className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs divide-y divide-[#F3DFCD] dark:divide-[#383029] cursor-pointer hover:border-[#B03C09]/40 transition-colors"
        >
          <div className="flex items-center justify-between py-2">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-[#B03C09]/10 text-[#B03C09] flex items-center justify-center">
                <HandCoins size={16} />
              </div>
              <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                You owe
              </span>
            </div>
            <span className="text-sm font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
              {formatPeso(totalDebtsIOwe)}
            </span>
          </div>

          <div className="flex items-center justify-between py-2">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-[#16643F]/10 text-[#16643F] flex items-center justify-center">
                <HandCoins size={16} />
              </div>
              <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Owed to you
              </span>
            </div>
            <span className="text-sm font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
              {formatPeso(totalDebtsOwedToMe)}
            </span>
          </div>
        </div>
      </div>

      {/* Add Account Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Add Account
              </h2>
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleAddAccount} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Account Type
                </label>
                <div className="flex rounded-xl p-1 bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                  {(['cash', 'bank', 'credit'] as AccountKind[]).map((k) => (
                    <button
                      key={k}
                      type="button"
                      onClick={() => setKind(k)}
                      className={`flex-1 py-1.5 text-xs font-bold rounded-lg capitalize transition-all cursor-pointer ${
                        kind === k
                          ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                          : 'text-[#6B6156] dark:text-[#AC9E92]'
                      }`}
                    >
                      {k === 'cash' ? 'E-Wallet' : k}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Account Name
                </label>
                <input
                  type="text"
                  required
                  value={accountName}
                  onChange={(e) => setAccountName(e.target.value)}
                  placeholder="e.g. Maya Savings, GCash, BPI Express"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Institution
                </label>
                <select
                  value={institution}
                  onChange={(e) => setInstitution(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                >
                  <option value="GCash">GCash</option>
                  <option value="Maya">Maya</option>
                  <option value="BPI">BPI</option>
                  <option value="BDO">BDO</option>
                  <option value="UnionBank">UnionBank</option>
                  <option value="SeaBank">SeaBank</option>
                  <option value="GoTyme">GoTyme</option>
                  <option value="Cash">Cash (Physical)</option>
                  <option value="Other">Other Bank / Wallet</option>
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Current Balance (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  value={balanceStr}
                  onChange={(e) => setBalanceStr(e.target.value)}
                  placeholder="0.00"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              {kind === 'credit' && (
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Credit Limit
                    </label>
                    <input
                      type="number"
                      value={creditLimitStr}
                      onChange={(e) => setCreditLimitStr(e.target.value)}
                      placeholder="40000"
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Due Date
                    </label>
                    <input
                      type="text"
                      value={dueDate}
                      onChange={(e) => setDueDate(e.target.value)}
                      placeholder="e.g. Oct 3"
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                </div>
              )}

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="flex-1 py-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
                >
                  Save Account
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
