import React, { useState, useMemo } from 'react';
import {
  Plus,
  X,
  ChevronRight,
  HandCoins,
  Info,
  Building,
  ShieldCheck,
  TrendingUp,
  CreditCard,
  Landmark,
  Wallet,
  PiggyBank,
  Receipt,
  Layers,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Account, AccountKind, ProfileEntity, CurrencyCode } from '../types';
import { SectionInfoModal } from './SectionInfoModal';
import { convertToPhp, formatCurrency, SUPPORTED_CURRENCIES } from '../utils/currencies';
import { PROFILE_OPTIONS } from '../data/categories';

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
    activeProfile,
    setActiveProfile,
  } = useFinancial();

  const [showAddModal, setShowAddModal] = useState(false);
  const [showNetWorthInfo, setShowNetWorthInfo] = useState(false);
  const [accountViewFilter, setAccountViewFilter] = useState<'all' | 'assets' | 'liabilities'>('all');

  // Form states
  const [accountName, setAccountName] = useState('');
  const [kind, setKind] = useState<AccountKind>('cash');
  const [institution, setInstitution] = useState('GCash');
  const [currency, setCurrency] = useState<CurrencyCode>('PHP');
  const [profile, setProfile] = useState<ProfileEntity>('personal');
  const [balanceStr, setBalanceStr] = useState('');
  const [creditLimitStr, setCreditLimitStr] = useState('');
  const [interestRateStr, setInterestRateStr] = useState('');
  const [dueDate, setDueDate] = useState('');

  // Asset vs Liability groupings
  const assetKinds: AccountKind[] = ['cash', 'bank', 'gcash', 'maya', 'debit', 'investment', 'receivable'];
  const liabilityKinds: AccountKind[] = ['credit', 'loan', 'mortgage'];

  const filteredAccounts = useMemo(() => {
    return accounts.filter((acc) => {
      if (activeProfile !== 'all' && (acc.profile || 'personal') !== activeProfile) {
        return false;
      }
      if (accountViewFilter === 'assets' && !assetKinds.includes(acc.kind)) {
        return false;
      }
      if (accountViewFilter === 'liabilities' && !liabilityKinds.includes(acc.kind)) {
        return false;
      }
      return true;
    });
  }, [accounts, activeProfile, accountViewFilter]);

  const assetAccounts = filteredAccounts.filter((a) => assetKinds.includes(a.kind));
  const liabilityAccounts = filteredAccounts.filter((a) => liabilityKinds.includes(a.kind));

  // Monogram helper
  const computeMonogram = (inst: string, k: AccountKind, name: string) => {
    if (k === 'gcash') return 'GC';
    if (k === 'maya') return 'MY';
    if (k === 'investment') return 'INV';
    if (k === 'receivable') return 'REC';
    if (k === 'mortgage') return 'MORT';
    if (k === 'loan') return 'LOAN';
    if (inst === 'BPI') return 'BPI';
    if (inst === 'BDO') return 'BDO';
    if (inst === 'UnionBank') return 'UB';
    if (inst === 'SeaBank') return 'SB';
    if (inst === 'GoTyme') return 'GT';
    if (inst === 'Cash') return '₱';
    return name.slice(0, 2).toUpperCase() || 'AC';
  };

  const handleAddAccount = (e: React.FormEvent) => {
    e.preventDefault();
    const balance = parseFloat(balanceStr) || 0;
    const creditLimit = creditLimitStr ? parseFloat(creditLimitStr) : undefined;
    const interestRate = interestRateStr ? parseFloat(interestRateStr) : undefined;
    if (!accountName.trim()) return;

    const monogram = computeMonogram(institution, kind, accountName);

    addAccount({
      name: accountName.trim(),
      kind,
      institution,
      currency,
      profile,
      balance,
      creditLimit,
      interestRate,
      dueDate: dueDate.trim() || undefined,
      monogram,
    });

    setShowAddModal(false);
    setAccountName('');
    setBalanceStr('');
    setCreditLimitStr('');
    setInterestRateStr('');
    setDueDate('');
  };

  const getAccountIcon = (k: AccountKind) => {
    switch (k) {
      case 'cash':
      case 'gcash':
      case 'maya':
        return <Wallet size={16} />;
      case 'bank':
      case 'debit':
        return <Landmark size={16} />;
      case 'credit':
        return <CreditCard size={16} />;
      case 'investment':
        return <TrendingUp size={16} />;
      case 'receivable':
        return <Receipt size={16} />;
      case 'loan':
      case 'mortgage':
        return <HandCoins size={16} />;
      default:
        return <Layers size={16} />;
    }
  };

  return (
    <div className="flex flex-col gap-4 pb-36">
      {/* Title & Add */}
      <div className="flex items-center justify-between pt-2 px-1">
        <div className="flex items-center gap-1.5">
          <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
            Chart of Accounts
          </h1>
          <button
            type="button"
            onClick={() => setShowNetWorthInfo(true)}
            className="inline-flex items-center justify-center w-5 h-5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
            title="Accounting Ledger & Balance Sheet Information"
            aria-label="Accounts info"
          >
            <Info size={14} />
          </button>
        </div>
        <button
          type="button"
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
        >
          <Plus size={14} /> Add Account
        </button>
      </div>

      {/* Profile Filter Bar */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1 pl-1 shrink-0">
          <Building size={13} />
          <span>Entity:</span>
        </span>
        <button
          type="button"
          onClick={() => setActiveProfile('all')}
          className={`px-3 py-1 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer transition-colors border ${
            activeProfile === 'all'
              ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
              : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
          }`}
        >
          All Profiles
        </button>
        {PROFILE_OPTIONS.map((p) => (
          <button
            key={p.id}
            type="button"
            onClick={() => setActiveProfile(p.id)}
            className={`px-3 py-1 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer transition-colors border capitalize ${
              activeProfile === p.id
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
            }`}
          >
            {p.name}
          </button>
        ))}
      </div>

      {/* Hero: Net Worth Card */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs">
        <div className="flex items-center justify-between mb-0.5">
          <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
            Total Net Worth ({activeProfile === 'all' ? 'Consolidated' : activeProfile})
          </span>
          <button
            type="button"
            onClick={() => setShowNetWorthInfo(true)}
            className="inline-flex items-center justify-center w-5 h-5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
            title="CPA Net Worth Formula"
            aria-label="Net Worth info"
          >
            <Info size={13} strokeWidth={2.2} />
          </button>
        </div>
        <div className="text-2xl sm:text-3xl md:text-4xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] my-1 tabular-nums break-words">
          {formatPeso(netWorth)}
        </div>
        <p className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] flex flex-wrap gap-x-2 gap-y-0.5 pt-1">
          <span>
            Total Assets <strong className="text-[#16643F] dark:text-[#5FCB8E]">{formatPeso(totalAssets)}</strong>
          </span>
          <span>·</span>
          <span>
            Total Liabilities <strong className="text-[#B03C09] dark:text-[#FF9A52]">{formatPeso(totalCreditUsed + totalDebtsIOwe)}</strong>
          </span>
        </p>
      </div>

      {/* Segmented Filter: All · Assets · Liabilities */}
      <div className="flex rounded-2xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
        <button
          type="button"
          onClick={() => setAccountViewFilter('all')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            accountViewFilter === 'all'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          All ({filteredAccounts.length})
        </button>
        <button
          type="button"
          onClick={() => setAccountViewFilter('assets')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            accountViewFilter === 'assets'
              ? 'bg-[#16643F] text-white shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          Assets ({assetAccounts.length})
        </button>
        <button
          type="button"
          onClick={() => setAccountViewFilter('liabilities')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            accountViewFilter === 'liabilities'
              ? 'bg-rose-700 text-white shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          Liabilities ({liabilityAccounts.length})
        </button>
      </div>

      {/* ASSET ACCOUNTS SECTION */}
      {(accountViewFilter === 'all' || accountViewFilter === 'assets') && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between px-1">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#16643F] dark:text-[#5FCB8E]">
              Assets ({assetAccounts.length})
            </h2>
            <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E]">
              {formatPeso(
                assetAccounts.reduce(
                  (sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'),
                  0
                )
              )}
            </span>
          </div>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {assetAccounts.length === 0 ? (
              <div className="p-4 text-xs text-center text-[#6B6156] dark:text-[#AC9E92]">
                No asset accounts found for this entity filter.
              </div>
            ) : (
              assetAccounts.map((acc) => {
                const isForeign = acc.currency && acc.currency !== 'PHP';
                const phpEquiv = convertToPhp(acc.balance, acc.currency || 'PHP');

                return (
                  <div
                    key={acc.id}
                    className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors gap-2"
                  >
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="w-10 h-10 rounded-xl bg-emerald-500/10 text-[#16643F] dark:text-[#5FCB8E] flex items-center justify-center font-bold text-xs shrink-0">
                        {acc.monogram}
                      </div>
                      <div className="flex flex-col min-w-0 flex-1">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                            {acc.name}
                          </span>
                          {acc.profile && activeProfile === 'all' && (
                            <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] capitalize">
                              {acc.profile}
                            </span>
                          )}
                          {isForeign && (
                            <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-amber-500/20 text-amber-800 dark:text-amber-300">
                              {acc.currency}
                            </span>
                          )}
                        </div>
                        <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate capitalize">
                          {acc.kind} · {acc.institution}
                          {acc.interestRate ? ` · ${acc.interestRate}% p.a. yield` : ''}
                        </span>
                      </div>
                    </div>

                    <div className="text-right shrink-0 pl-2">
                      <span className="text-sm font-extrabold text-[#16643F] dark:text-[#5FCB8E] whitespace-nowrap tabular-nums block">
                        {acc.currency && acc.currency !== 'PHP'
                          ? formatCurrency(acc.balance, acc.currency)
                          : formatPeso(acc.balance)}
                      </span>
                      {isForeign && (
                        <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] tabular-nums block">
                          ≈ {formatPeso(phpEquiv)}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* LIABILITY ACCOUNTS SECTION */}
      {(accountViewFilter === 'all' || accountViewFilter === 'liabilities') && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between px-1">
            <h2 className="text-xs font-bold uppercase tracking-wider text-rose-600 dark:text-rose-400">
              Liabilities & Obligations ({liabilityAccounts.length})
            </h2>
            <span className="text-xs font-bold text-rose-600 dark:text-rose-400">
              {formatPeso(
                liabilityAccounts.reduce(
                  (sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'),
                  0
                )
              )}
            </span>
          </div>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {liabilityAccounts.length === 0 ? (
              <div className="p-4 text-xs text-center text-[#6B6156] dark:text-[#AC9E92]">
                No liability accounts recorded.
              </div>
            ) : (
              liabilityAccounts.map((acc) => {
                const limit = acc.creditLimit || 40000;
                const util = acc.kind === 'credit' ? Math.round((acc.balance / limit) * 100) : null;
                const isHighUtil = util !== null && util > 30;

                return (
                  <div key={acc.id} className="p-3.5 flex flex-col gap-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        <div className="w-10 h-10 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400 flex items-center justify-center font-bold text-xs shrink-0">
                          {acc.monogram}
                        </div>
                        <div className="flex flex-col min-w-0 flex-1">
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                              {acc.name}
                            </span>
                            {acc.profile && activeProfile === 'all' && (
                              <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] capitalize">
                                {acc.profile}
                              </span>
                            )}
                            {isHighUtil && (
                              <span className="text-[9px] font-bold px-1.5 py-0.2 rounded-full bg-rose-500/20 text-rose-700 dark:text-rose-300 shrink-0">
                                &gt;30% Limit
                              </span>
                            )}
                          </div>
                          <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate capitalize">
                            {acc.kind} · {acc.institution} {acc.dueDate ? `· Due: ${acc.dueDate}` : ''}
                          </span>
                        </div>
                      </div>

                      <span className="text-sm font-extrabold text-rose-600 dark:text-rose-400 shrink-0 whitespace-nowrap pl-2 tabular-nums">
                        {formatPeso(acc.balance)}
                      </span>
                    </div>

                    {acc.kind === 'credit' && util !== null && (
                      <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all duration-300 ${
                            isHighUtil ? 'bg-rose-500' : 'bg-[#16643F] dark:bg-[#5FCB8E]'
                          }`}
                          style={{ width: `${Math.min(100, util)}%` }}
                        />
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* Section: Debt Hub Link */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between px-1">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
            Both-Ways Debt Register
          </h2>
          <button
            type="button"
            onClick={onOpenDebt}
            className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-0.5 hover:underline cursor-pointer"
          >
            Open Debt Beam <ChevronRight size={14} />
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
                You owe (Lenders & Banks)
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
                Owed to you (Pahiram & Split bills)
              </span>
            </div>
            <span className="text-sm font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
              {formatPeso(totalDebtsOwedToMe)}
            </span>
          </div>
        </div>
      </div>

      {/* Add Account Modal Supporting All 10 Types */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-4">
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Add Accounting Account
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
              {/* Account Type (All 10 kinds) */}
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Account Type (Classification)
                </label>
                <select
                  value={kind}
                  onChange={(e) => setKind(e.target.value as AccountKind)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                >
                  <optgroup label="Assets">
                    <option value="cash">Cash (Physical Cash)</option>
                    <option value="bank">Bank Account</option>
                    <option value="gcash">GCash E-Wallet</option>
                    <option value="maya">Maya E-Wallet / Savings</option>
                    <option value="debit">Debit Card</option>
                    <option value="investment">Investments (MP2, WISP, UITF, Stocks)</option>
                    <option value="receivable">Receivables (Pahiram / Split Bills)</option>
                  </optgroup>
                  <optgroup label="Liabilities">
                    <option value="credit">Credit Card</option>
                    <option value="loan">Personal Loan</option>
                    <option value="mortgage">Mortgage / Home Loan</option>
                  </optgroup>
                </select>
              </div>

              {/* Account Name */}
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Account Name
                </label>
                <input
                  type="text"
                  required
                  value={accountName}
                  onChange={(e) => setAccountName(e.target.value)}
                  placeholder="e.g. BPI Payroll, GCash Main, Pag-IBIG MP2"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              {/* Institution */}
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Institution / Provider
                </label>
                <select
                  value={institution}
                  onChange={(e) => setInstitution(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                >
                  <option value="BPI">BPI</option>
                  <option value="BDO">BDO</option>
                  <option value="Metrobank">Metrobank</option>
                  <option value="UnionBank">UnionBank</option>
                  <option value="GCash">GCash</option>
                  <option value="Maya">Maya</option>
                  <option value="SeaBank">SeaBank</option>
                  <option value="GoTyme">GoTyme</option>
                  <option value="Tonik">Tonik</option>
                  <option value="CIMB">CIMB</option>
                  <option value="Pag-IBIG">Pag-IBIG Fund (MP2)</option>
                  <option value="SSS">SSS (WISP Plus)</option>
                  <option value="Cash">Cash (Physical)</option>
                  <option value="Other">Other Financial Institution</option>
                </select>
              </div>

              {/* Profile Entity & Currency */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Entity Profile
                  </label>
                  <select
                    value={profile}
                    onChange={(e) => setProfile(e.target.value as ProfileEntity)}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none capitalize"
                  >
                    <option value="personal">Personal</option>
                    <option value="household">Household</option>
                    <option value="business">Business</option>
                    <option value="side_hustle">Side-Hustle</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Currency
                  </label>
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value as CurrencyCode)}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  >
                    {SUPPORTED_CURRENCIES.map((c) => (
                      <option key={c.code} value={c.code}>
                        {c.code} ({c.symbol})
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Current Balance */}
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Current Balance ({currency})
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

              {/* Specific fields for credit or loans */}
              {kind === 'credit' && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
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
                      Statement Due Date
                    </label>
                    <input
                      type="text"
                      value={dueDate}
                      onChange={(e) => setDueDate(e.target.value)}
                      placeholder="e.g. 15th"
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                </div>
              )}

              {(kind === 'investment' || kind === 'loan' || kind === 'mortgage') && (
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    {kind === 'investment' ? 'Annual Yield Rate (% p.a.)' : 'Annual Interest Rate (%)'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={interestRateStr}
                    onChange={(e) => setInterestRateStr(e.target.value)}
                    placeholder="e.g. 7.05 for MP2 dividend"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
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

      {/* Section Info Modal */}
      <SectionInfoModal topic={showNetWorthInfo ? 'net_worth' : null} onClose={() => setShowNetWorthInfo(false)} />
    </div>
  );
};
