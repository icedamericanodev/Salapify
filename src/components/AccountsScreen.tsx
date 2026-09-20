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
  Clock,
  Sparkles,
  AlertCircle,
  Calendar,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { InvestmentsView } from './InvestmentsView';
import { formatPeso } from '../utils/format';
import { Account, AccountKind, ProfileEntity, CurrencyCode } from '../types';
import { SectionInfoModal } from './SectionInfoModal';
import { convertToPhp, formatCurrency, SUPPORTED_CURRENCIES } from '../utils/currencies';
import { PROFILE_OPTIONS } from '../data/categories';
import { getLogoUrl } from '../utils/logos';
import { BankCard } from './BankCard';

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
    updateAccount,
    deleteAccount,
    activeProfile,
    setActiveProfile,
  } = useFinancial();

  const [showAddModal, setShowAddModal] = useState(false);
  const [editingAccountId, setEditingAccountId] = useState<string | null>(null);
  const [accountNumber, setAccountNumber] = useState('');
  const [cardNetwork, setCardNetwork] = useState<'visa' | 'mastercard' | 'amex' | 'jcb' | 'none'>('none');
  const [cardTier, setCardTier] = useState<'regular' | 'gold' | 'platinum' | 'black' | 'custom'>('regular');
  const [showNetWorthInfo, setShowNetWorthInfo] = useState(false);
  const [accountViewFilter, setAccountViewFilter] = useState<'all' | 'assets' | 'liabilities' | 'investments'>('all');
  const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({
    ewallet: true, bank: true, cash: true, investment: true, receivable: true, credit: true, loan: true, mortgage: true
  });
  const toggleSection = (id: string) => setExpandedSections(prev => ({ ...prev, [id]: !prev[id] }));

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
  const [statementDate, setStatementDate] = useState('');

  


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

  const assetGroups = [
    { id: 'ewallet', title: 'E-Wallets', accounts: assetAccounts.filter(a => ['gcash', 'maya'].includes(a.kind)) },
    { id: 'bank', title: 'Bank Accounts', accounts: assetAccounts.filter(a => ['bank', 'debit'].includes(a.kind)) },
    { id: 'cash', title: 'Cash', accounts: assetAccounts.filter(a => a.kind === 'cash') },
    { id: 'investment', title: 'Investments', accounts: assetAccounts.filter(a => a.kind === 'investment') },
    { id: 'receivable', title: 'Receivables', accounts: assetAccounts.filter(a => a.kind === 'receivable') }
  ].filter(g => g.accounts.length > 0);

  const liabilityGroups = [
    { id: 'credit', title: 'Credit Cards', accounts: liabilityAccounts.filter(a => a.kind === 'credit') },
    { id: 'loan', title: 'Loans', accounts: liabilityAccounts.filter(a => a.kind === 'loan') },
    { id: 'mortgage', title: 'Mortgages', accounts: liabilityAccounts.filter(a => a.kind === 'mortgage') }
  ].filter(g => g.accounts.length > 0);


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
    if (inst === 'Metrobank') return 'MBTC';
    if (inst === 'RCBC') return 'RC';
    if (inst === 'UnionBank') return 'UB';
    if (inst === 'Security Bank') return 'SB';
    if (inst === 'PNB') return 'PNB';
    if (inst === 'EastWest') return 'EW';
    if (inst === 'AUB') return 'AUB';
    if (inst === 'LandBank') return 'LB';
    if (inst === 'PSBank') return 'PS';
    if (inst === 'China Bank') return 'CB';
    if (inst === 'MariBank') return 'MB';
    if (inst === 'GoTyme') return 'GT';
    if (inst === 'Tonik') return 'TK';
    if (inst === 'CIMB') return 'CIMB';
    if (inst === 'Komo') return 'KM';
    if (inst === 'DiskarTech') return 'DT';
    if (inst === 'Netbank') return 'NB';
    if (inst === 'UNO Digital Bank') return 'UNO';
    if (inst === 'OwnBank') return 'OB';
    if (inst === 'TikTok') return 'TK';
    if (inst === 'Atome') return 'AT';
    if (inst === 'Pag-IBIG') return 'HDMF';
    if (inst === 'SSS') return 'SSS';
    if (inst === 'Cash') return '₱';
    return name.slice(0, 2).toUpperCase() || 'AC';
  };

  
  const openEditModal = (acc: Account) => {
    setEditingAccountId(acc.id);
    setAccountName(acc.name);
    setKind(acc.kind);
    setInstitution(acc.institution);
    setCurrency(acc.currency || 'PHP');
    setProfile(acc.profile || 'personal');
    setBalanceStr(String(acc.balance));
    setCreditLimitStr(acc.creditLimit ? String(acc.creditLimit) : '');
    setInterestRateStr(acc.interestRate ? String(acc.interestRate) : '');
    setDueDate(acc.dueDate || '');
    setStatementDate(acc.statementDate || '');
    setAccountNumber(acc.accountNumber || '');
    setCardNetwork(acc.cardNetwork || 'none');
    setCardTier(acc.cardTier || 'regular');
    setShowAddModal(true);
  };

  const openAddModal = () => {
    setEditingAccountId(null);
    setAccountName('');
    setBalanceStr('');
    setCreditLimitStr('');
    setInterestRateStr('');
    setDueDate('');
    setStatementDate('');
    setAccountNumber('');
    setCardNetwork('none');
    setCardTier('regular');
    setKind('cash');
    setInstitution('GCash');
    setCurrency('PHP');
    setProfile('personal');
    setShowAddModal(true);
  };

  const handleAddAccount = (e: React.FormEvent) => {
    e.preventDefault();
    const balance = parseFloat(balanceStr) || 0;
    const creditLimit = creditLimitStr ? parseFloat(creditLimitStr) : undefined;
    const interestRate = interestRateStr ? parseFloat(interestRateStr) : undefined;
    if (!accountName.trim()) return;

    const monogram = computeMonogram(institution, kind, accountName);

    const accountData = {
      name: accountName.trim(),
      kind,
      institution,
      currency,
      profile,
      balance,
      creditLimit,
      interestRate,
      dueDate: dueDate.trim() || undefined,
      statementDate: statementDate.trim() || undefined,
      monogram,
      accountNumber: accountNumber.trim() || undefined,
      cardNetwork: cardNetwork !== 'none' ? cardNetwork : undefined,
      cardTier: cardTier,
    };

    if (editingAccountId) {
      updateAccount(editingAccountId, accountData);
    } else {
      addAccount(accountData);
    }

    setShowAddModal(false);
    setAccountName('');
    setBalanceStr('');
    setCreditLimitStr('');
    setInterestRateStr('');
    setDueDate('');
    setStatementDate('');
  };

  const getCardCutoffAdvice = (acc: Account) => {
    const today = new Date();
    const currentDay = today.getDate();

    let cutoffDay = 15;
    if (acc.statementDate) {
      const match = acc.statementDate.match(/\d+/);
      if (match) cutoffDay = parseInt(match[0], 10);
    } else if (acc.dueDate) {
      const match = acc.dueDate.match(/\d+/);
      if (match) {
        const d = parseInt(match[0], 10);
        cutoffDay = d > 20 ? d - 20 : (d + 10);
      }
    }

    let dueDay = (cutoffDay + 21) > 30 ? (cutoffDay + 21 - 30) : (cutoffDay + 21);
    if (acc.dueDate) {
      const match = acc.dueDate.match(/\d+/);
      if (match) dueDay = parseInt(match[0], 10);
    }

    let daysUntilCutoff = cutoffDay - currentDay;
    if (daysUntilCutoff < 0) daysUntilCutoff += 30;

    let daysUntilDue = dueDay - currentDay;
    if (daysUntilDue < 0) daysUntilDue += 30;

    if (daysUntilDue <= 4 && daysUntilDue >= 0) {
      return {
        type: 'due_soon',
        badge: `Due in ${daysUntilDue === 0 ? 'Today' : `${daysUntilDue}d`}`,
        text: `Payment due on day ${dueDay}. Pay full balance to avoid 3% finance charge.`,
        theme: 'bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/20',
        icon: 'alert' as const,
      };
    }

    if (daysUntilCutoff <= 3 && daysUntilCutoff >= 0) {
      return {
        type: 'cutoff_soon',
        badge: `Statement in ${daysUntilCutoff === 0 ? 'Today' : `${daysUntilCutoff}d`}`,
        text: `Cutoff day ${cutoffDay}. Delay heavy swipes until after cutoff to push to next cycle.`,
        theme: 'bg-amber-500/10 text-amber-800 dark:text-amber-300 border-amber-500/20',
        icon: 'clock' as const,
      };
    }

    if (currentDay > cutoffDay && currentDay <= cutoffDay + 7) {
      return {
        type: 'safe_swipe',
        badge: 'Safe to Swipe',
        text: `Statement generated on day ${cutoffDay}! Up to 50 days interest-free grace period.`,
        theme: 'bg-emerald-500/10 text-emerald-800 dark:text-emerald-300 border-emerald-500/20',
        icon: 'sparkles' as const,
      };
    }

    return {
      type: 'neutral',
      badge: `Cutoff: ${cutoffDay}th · Due: ${dueDay}th`,
      text: `Statement cuts on day ${cutoffDay}, payment due on day ${dueDay}.`,
      theme: 'bg-[#FFEEDF]/40 dark:bg-[#14100D] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]',
      icon: 'calendar' as const,
    };
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
            Accounts
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
        <button
          type="button"
          onClick={() => setAccountViewFilter('investments')}
          className={`flex-1 py-1.5 text-xs font-bold rounded-xl transition-all cursor-pointer ${
            accountViewFilter === 'investments'
              ? 'bg-[#B03C09] text-white shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92]'
          }`}
        >
          Investments
        </button>
      </div>
        <button
          type="button"
          onClick={openAddModal}
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
        <div className="text-2xl sm:text-3xl md:text-4xl font-extrabold font-display text-[#15120F] dark:text-[#F6EFE8] my-1 tabular-nums break-words">
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

      
      {/* INVESTMENTS SECTION */}
      {accountViewFilter === 'investments' && (
        <div className="pt-2">
          <InvestmentsView />
        </div>
      )}

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

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs overflow-hidden flex flex-col">
            {assetAccounts.length === 0 ? (
              <div className="p-4 text-xs text-center text-[#6B6156] dark:text-[#AC9E92]">
                No asset accounts found for this entity filter.
              </div>
            ) : (
              assetGroups.map(group => (
                <div key={group.id} className="flex flex-col border-b border-[#F3DFCD] dark:border-[#383029] last:border-b-0">
                  <div 
                    className="p-3 bg-[#F9F4F0]/50 dark:bg-[#1E1915]/50 flex items-center justify-between cursor-pointer hover:bg-[#F9F4F0] dark:hover:bg-[#1E1915] transition-colors"
                    onClick={() => toggleSection(group.id)}
                  >
                    <span className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] uppercase tracking-wider">{group.title} ({group.accounts.length})</span>
                    <ChevronRight className={`w-4 h-4 text-[#5A5148] dark:text-[#C6B8AC] transition-transform ${expandedSections[group.id] ? 'rotate-90' : ''}`} />
                  </div>
                  {expandedSections[group.id] && (
                    <div className="flex flex-col divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                      {group.accounts.map(acc => {
                        
                const isForeign = acc.currency && acc.currency !== 'PHP';
                const phpEquiv = convertToPhp(acc.balance, acc.currency || 'PHP');
                const logoUrl = getLogoUrl(acc.institution);

                if (acc.kind === 'debit') {
                  return (
                    <div key={acc.id} className="p-3" onClick={() => openEditModal(acc)}>
                      <BankCard account={acc} />
                    </div>
                  );
                }

                return (
                  <div
                    key={acc.id}
                    className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors gap-2 cursor-pointer" onClick={() => openEditModal(acc)}
                  >
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="relative w-10 h-10 rounded-xl bg-emerald-500/10 border border-[#F3DFCD] dark:border-[#383029] overflow-hidden shrink-0 flex items-center justify-center">
                        <img 
                          src={logoUrl} 
                          alt={acc.institution}
                          onError={(e) => {
                            e.currentTarget.style.display = 'none';
                            const fallback = e.currentTarget.nextElementSibling;
                            if (fallback) (fallback as HTMLElement).style.display = 'flex';
                          }}
                          className="w-full h-full object-contain p-1 bg-white rounded-md"
                        />
                        <div style={{ display: 'none' }} className="w-full h-full text-[#16643F] dark:text-[#5FCB8E] items-center justify-center font-bold text-xs">
                          {acc.monogram}
                        </div>
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
              
                      })}
                    </div>
                  )}
                </div>
              ))
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

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs overflow-hidden flex flex-col">
            {liabilityAccounts.length === 0 ? (
              <div className="p-4 text-xs text-center text-[#6B6156] dark:text-[#AC9E92]">
                No liability accounts recorded.
              </div>
            ) : (
              liabilityGroups.map(group => (
                <div key={group.id} className="flex flex-col border-b border-[#F3DFCD] dark:border-[#383029] last:border-b-0">
                  <div 
                    className="p-3 bg-[#F9F4F0]/50 dark:bg-[#1E1915]/50 flex items-center justify-between cursor-pointer hover:bg-[#F9F4F0] dark:hover:bg-[#1E1915] transition-colors"
                    onClick={() => toggleSection(group.id)}
                  >
                    <span className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] uppercase tracking-wider">{group.title} ({group.accounts.length})</span>
                    <ChevronRight className={`w-4 h-4 text-[#5A5148] dark:text-[#C6B8AC] transition-transform ${expandedSections[group.id] ? 'rotate-90' : ''}`} />
                  </div>
                  {expandedSections[group.id] && (
                    <div className="flex flex-col divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                      {group.accounts.map(acc => {
                        
                const limit = acc.creditLimit || 40000;
                const util = acc.kind === 'credit' ? Math.round((acc.balance / limit) * 100) : null;
                const isHighUtil = util !== null && util > 30;
                const logoUrl = getLogoUrl(acc.institution);

                if (acc.kind === 'credit') {
                  const advice = getCardCutoffAdvice(acc);
                  return (
                    <div key={acc.id} className="p-3" onClick={() => openEditModal(acc)}>
                      <BankCard account={acc} />
                      {util !== null && (
                        <div className="flex flex-col gap-1 mt-3 px-2">
                          <div className="flex justify-between items-center text-[10px]">
                            <span className="text-[#6B6156] dark:text-[#AC9E92] font-semibold">
                              Credit Utilization
                            </span>
                            <span
                              className={`font-bold ${
                                isHighUtil ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'
                              }`}
                            >
                              {util}%
                            </span>
                          </div>
                          <div className="w-full h-1.5 bg-[#FFEEDF] dark:bg-[#14100D] rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full transition-all ${
                                isHighUtil ? 'bg-rose-500' : 'bg-[#16643F] dark:bg-[#5FCB8E]'
                              }`}
                              style={{ width: `${Math.min(100, util)}%` }}
                            />
                          </div>
                        </div>
                      )}

                      {/* Cutoff & Payment Due Tracker Badge */}
                      <div className={`mt-2.5 mx-1 p-2 rounded-xl border flex items-center justify-between gap-2 text-xs ${advice.theme}`}>
                        <div className="flex items-center gap-1.5 min-w-0">
                          {advice.icon === 'alert' && <AlertCircle size={13} className="shrink-0 text-rose-600 dark:text-rose-400" />}
                          {advice.icon === 'clock' && <Clock size={13} className="shrink-0 text-amber-600 dark:text-amber-400" />}
                          {advice.icon === 'sparkles' && <Sparkles size={13} className="shrink-0 text-emerald-600 dark:text-emerald-400" />}
                          {advice.icon === 'calendar' && <Calendar size={13} className="shrink-0 text-[#6B6156] dark:text-[#AC9E92]" />}
                          <span className="text-[11px] font-semibold truncate leading-tight">
                            {advice.text}
                          </span>
                        </div>
                        <span className="shrink-0 font-bold text-[10px] px-2 py-0.5 rounded-md bg-white/40 dark:bg-black/20 border border-current/20 whitespace-nowrap">
                          {advice.badge}
                        </span>
                      </div>
                    </div>
                  );
                }

                return (
                  <div key={acc.id} className="p-3.5 flex flex-col gap-2 cursor-pointer hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors" onClick={() => openEditModal(acc)}>
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        <div className="relative w-10 h-10 rounded-xl bg-rose-500/10 border border-[#F3DFCD] dark:border-[#383029] overflow-hidden shrink-0 flex items-center justify-center">
                          <img 
                            src={logoUrl} 
                            alt={acc.institution}
                            onError={(e) => {
                              e.currentTarget.style.display = 'none';
                              const fallback = e.currentTarget.nextElementSibling;
                              if (fallback) (fallback as HTMLElement).style.display = 'flex';
                            }}
                            className="w-full h-full object-contain p-1 bg-white rounded-md"
                          />
                          <div style={{ display: 'none' }} className="w-full h-full text-rose-600 dark:text-rose-400 items-center justify-center font-bold text-xs">
                            {acc.monogram}
                          </div>
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
                  </div>
                );
              
                      })}
                    </div>
                  )}
                </div>
              ))
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
                {editingAccountId ? 'Edit Account' : 'Add Accounting Account'}
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
                  <option value="RCBC">RCBC</option>
                  <option value="UnionBank">UnionBank</option>
                  <option value="Security Bank">Security Bank</option>
                  <option value="PNB">PNB</option>
                  <option value="EastWest">EastWest</option>
                  <option value="AUB">AUB</option>
                  <option value="LandBank">LandBank</option>
                  <option value="PSBank">PSBank</option>
                  <option value="China Bank">China Bank</option>
                  <option value="GCash">GCash</option>
                  <option value="Maya">Maya</option>
                  <option value="MariBank">MariBank</option>
                  <option value="GoTyme">GoTyme</option>
                  <option value="Tonik">Tonik</option>
                  <option value="CIMB">CIMB</option>
                  <option value="Komo">Komo</option>
                  <option value="DiskarTech">DiskarTech</option>
                  <option value="Netbank">Netbank</option>
                  <option value="UNO Digital Bank">UNO Digital Bank</option>
                  <option value="OwnBank">OwnBank</option>
                  <option value="TikTok">TikTok (PayLater)</option>
                  <option value="Atome">Atome</option>
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

              
              {/* Specific fields for debit or credit cards */}
              {(kind === 'credit' || kind === 'debit') && (
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Last 4 Digits
                    </label>
                    <input
                      type="text"
                      maxLength={4}
                      value={accountNumber}
                      onChange={(e) => setAccountNumber(e.target.value.replace(/\D/g, ''))}
                      placeholder="e.g. 1234"
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Card Network
                    </label>
                    <select
                      value={cardNetwork}
                      onChange={(e) => setCardNetwork(e.target.value as any)}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    >
                      <option value="none">None</option>
                      <option value="mastercard">Mastercard</option>
                      <option value="visa">Visa</option>
                      <option value="amex">Amex</option>
                      <option value="jcb">JCB</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Card Tier (Skin)
                    </label>
                    <select
                      value={cardTier}
                      onChange={(e) => setCardTier(e.target.value as any)}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    >
                      <option value="regular">Regular / Classic</option>
                      <option value="gold">Gold</option>
                      <option value="platinum">Platinum</option>
                      <option value="black">Black / Elite</option>
                      <option value="custom">Standard UI</option>
                    </select>
                  </div>
                </div>
              )}

              {/* Specific fields for credit cards */}
              {kind === 'credit' && (
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
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
                      Cutoff Day (e.g. 15th)
                    </label>
                    <input
                      type="text"
                      value={statementDate}
                      onChange={(e) => setStatementDate(e.target.value)}
                      placeholder="e.g. 15th"
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                      Payment Due Day (e.g. 5th)
                    </label>
                    <input
                      type="text"
                      value={dueDate}
                      onChange={(e) => setDueDate(e.target.value)}
                      placeholder="e.g. 5th"
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

              
                {editingAccountId && (
                  <button
                    type="button"
                    onClick={() => {
                      if (window.confirm('Are you sure you want to delete this account?')) {
                        deleteAccount(editingAccountId);
                        setShowAddModal(false);
                      }
                    }}
                    className="w-full py-2.5 rounded-xl border border-rose-500 text-rose-600 text-xs font-bold shadow-xs hover:bg-rose-50 dark:hover:bg-rose-950/30 cursor-pointer mb-3"
                  >
                    Delete Account
                  </button>
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

      
      <div className="pt-4 pb-6 text-center">
        <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] opacity-70">
          Disclaimer: Brand logos shown are for visual reference only. Salapify is not affiliated, associated, authorized, endorsed by, or in any way officially connected with these financial institutions.
        </p>
      </div>
      {/* Section Info Modal */}

      <SectionInfoModal topic={showNetWorthInfo ? 'net_worth' : null} onClose={() => setShowNetWorthInfo(false)} />
    </div>
  );
};
