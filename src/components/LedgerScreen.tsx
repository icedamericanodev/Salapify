import React, { useState, useMemo } from 'react';
import {
  Search,
  ChevronLeft,
  ChevronRight,
  ArrowDownLeft,
  ArrowUpRight,
  ArrowRightLeft,
  TrendingUp,
  TrendingDown,
  Tag,
  User,
  Paperclip,
  History,
  Building,
  Filter,
  X,
  Scale,
  ShieldCheck,
  Layers,
  RotateCcw,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso, formatDateLabel } from '../utils/format';
import { Transaction, TransactionStatus, ProfileEntity } from '../types';
import { STATUS_BADGE_CONFIG, PROFILE_OPTIONS } from '../data/categories';
import { TransactionDetailModal } from './TransactionDetailModal';

export const LedgerScreen: React.FC = () => {
  const {
    transactions,
    accounts,
    activeProfile,
    setActiveProfile,
    safeToSpend,
  } = useFinancial();

  const [activeSegment, setActiveSegment] = useState<'entries' | 'insights'>('entries');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const [selectedAccountId, setSelectedAccountId] = useState<string>('all');
  const [selectedType, setSelectedType] = useState<'all' | 'income' | 'expense' | 'transfer'>('all');
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);

  // Scoped transactions based on profile, status, account, and search query
  const scopedTransactions = useMemo(() => {
    return transactions.filter((t) => {
      // 1. Profile filter
      if (activeProfile !== 'all') {
        const txProfile = t.profile || 'personal';
        if (txProfile !== activeProfile) return false;
      }

      // 2. Status filter
      if (selectedStatus !== 'all') {
        const txStatus = t.status || 'confirmed';
        if (txStatus !== selectedStatus) return false;
      }

      // 3. Account filter
      if (selectedAccountId !== 'all') {
        if (t.accountId !== selectedAccountId && t.toAccountId !== selectedAccountId) {
          return false;
        }
      }

      // 4. Search query: filter transactions by description, category, or amount
      if (searchQuery.trim().length > 0) {
        const rawQ = searchQuery.trim().toLowerCase();

        // 1. Description matching: merchant, note, description, person
        const matchMerchant = t.merchant ? t.merchant.toLowerCase().includes(rawQ) : false;
        const matchNote = t.note ? t.note.toLowerCase().includes(rawQ) : false;
        const matchDesc = (t as any).description ? (t as any).description.toLowerCase().includes(rawQ) : false;
        const matchPerson = t.person ? t.person.toLowerCase().includes(rawQ) : false;
        const matchDescription = matchMerchant || matchNote || matchDesc || matchPerson;

        // 2. Category matching: category or subcategory
        const matchCategory =
          (t.category && t.category.toLowerCase().includes(rawQ)) ||
          (t.subcategory && t.subcategory.toLowerCase().includes(rawQ));

        // 3. Amount matching: raw numbers, formatted amounts with commas/decimals, currency prefix
        const rawAmountStr = t.amount.toString();
        const formattedAmountWithDecimals = t.amount.toLocaleString('en-US', {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        });
        const formattedAmountNoDecimals = t.amount.toLocaleString('en-US', {
          maximumFractionDigits: 0,
        });

        // Clean user query removing currency symbol (PHP, ₱, p), commas, and spaces
        const cleanNumberQ = rawQ.replace(/^(?:php|₱|p)\s*/i, '').replace(/,/g, '').trim();

        let matchAmount =
          rawAmountStr.includes(rawQ) ||
          formattedAmountWithDecimals.toLowerCase().includes(rawQ) ||
          formattedAmountNoDecimals.toLowerCase().includes(rawQ) ||
          `₱${rawAmountStr}`.toLowerCase().includes(rawQ) ||
          `₱${formattedAmountWithDecimals}`.toLowerCase().includes(rawQ);

        if (!matchAmount && cleanNumberQ.length > 0 && !isNaN(Number(cleanNumberQ))) {
          const queryNum = parseFloat(cleanNumberQ);
          matchAmount =
            rawAmountStr.includes(cleanNumberQ) ||
            formattedAmountWithDecimals.includes(cleanNumberQ) ||
            formattedAmountNoDecimals.includes(cleanNumberQ) ||
            Math.abs(t.amount - queryNum) < 0.01;
        }

        // 4. Tags matching
        const matchTags = t.tags && t.tags.some((tag) => tag.toLowerCase().includes(rawQ));

        if (!matchDescription && !matchCategory && !matchAmount && !matchTags) {
          return false;
        }
      }

      return true;
    });
  }, [transactions, activeProfile, selectedStatus, selectedAccountId, searchQuery]);

  // Totals for filtered view
  const totalIn = useMemo(
    () =>
      scopedTransactions
        .filter((t) => t.type === 'income' && t.status !== 'excluded' && t.status !== 'duplicate')
        .reduce((sum, t) => sum + t.amount, 0),
    [scopedTransactions]
  );

  const totalOut = useMemo(
    () =>
      scopedTransactions
        .filter((t) => t.type === 'expense' && t.status !== 'excluded' && t.status !== 'duplicate')
        .reduce((sum, t) => sum + t.amount, 0),
    [scopedTransactions]
  );

  const netMovement = totalIn - totalOut;

  const inflowCount = useMemo(
    () =>
      scopedTransactions.filter(
        (t) => t.type === 'income' && t.status !== 'excluded' && t.status !== 'duplicate'
      ).length,
    [scopedTransactions]
  );

  const outflowCount = useMemo(
    () =>
      scopedTransactions.filter(
        (t) => t.type === 'expense' && t.status !== 'excluded' && t.status !== 'duplicate'
      ).length,
    [scopedTransactions]
  );

  const transferCount = useMemo(
    () => scopedTransactions.filter((t) => t.type === 'transfer').length,
    [scopedTransactions]
  );

  // Proportional percentages
  const outflowPercentage = useMemo(() => {
    if (totalIn > 0) return Math.min(100, Math.round((totalOut / totalIn) * 100));
    return totalOut > 0 ? 100 : 0;
  }, [totalIn, totalOut]);

  const retentionPercentage = useMemo(() => {
    if (totalIn > 0) return Math.max(0, Math.round((netMovement / totalIn) * 100));
    return 0;
  }, [totalIn, netMovement]);

  // Table view transactions filtered by active type
  const filteredTransactions = useMemo(() => {
    if (selectedType === 'all') return scopedTransactions;
    return scopedTransactions.filter((t) => t.type === selectedType);
  }, [scopedTransactions, selectedType]);

  // Group by date
  const groupedByDay = useMemo(() => {
    const map = new Map<string, Transaction[]>();
    filteredTransactions.forEach((tx) => {
      const existing = map.get(tx.date) || [];
      existing.push(tx);
      map.set(tx.date, existing);
    });
    return Array.from(map.entries()).sort((a, b) => b[0].localeCompare(a[0]));
  }, [filteredTransactions]);

  // Insights calculations
  const categorySpending = useMemo(() => {
    const catMap = new Map<string, number>();
    transactions
      .filter((t) => t.type === 'expense' && t.status !== 'excluded' && t.status !== 'duplicate')
      .forEach((t) => {
        catMap.set(t.category, (catMap.get(t.category) || 0) + t.amount);
      });
    return Array.from(catMap.entries()).sort((a, b) => b[1] - a[1]);
  }, [transactions]);

  const maxCategorySpend = categorySpending[0]?.[1] || 1;

  const getAccountInfo = (accId?: string) => {
    if (!accId) return null;
    return accounts.find((a) => a.id === accId);
  };

  return (
    <div className="flex flex-col gap-4 pb-36">
      {/* Screen Title & Top Controls */}
      <div className="flex items-center justify-between pt-2 px-1">
        <div>
          <h1 className="text-xl font-extrabold font-display text-[#15120F] dark:text-[#F6EFE8]">
            Transactions
          </h1>
          <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
            All your transactions in one place
          </span>
        </div>
        {/* Segmented: Entries · Insights */}
        <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
          <button
            type="button"
            onClick={() => setActiveSegment('entries')}
            className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
              activeSegment === 'entries'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92]'
            }`}
          >
            Entries
          </button>
          <button
            type="button"
            onClick={() => setActiveSegment('insights')}
            className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
              activeSegment === 'insights'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92]'
            }`}
          >
            Insights
          </button>
        </div>
      </div>

      {/* Entity Profile Selector Bar */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1 pl-1 shrink-0">
          <Building size={13} />
          <span>Profile:</span>
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

      {activeSegment === 'entries' ? (
        <>
          {/* Prominent Search Bar */}
          <div className="flex flex-col gap-1.5">
            <div className="relative flex items-center">
              <Search
                size={16}
                className="absolute left-3.5 text-[#6B6156] dark:text-[#AC9E92] pointer-events-none"
              />
              <input
                id="ledger-search-input"
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by description, category, or amount (e.g. Puregold, Food, 500)..."
                className="w-full pl-9 pr-9 py-2.5 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] placeholder:text-[#6B6156]/60 focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52] shadow-2xs transition-colors"
              />
              {searchQuery && (
                <button
                  type="button"
                  id="ledger-search-clear-btn"
                  onClick={() => setSearchQuery('')}
                  className="absolute right-2.5 p-1 rounded-full text-[#6B6156] hover:text-[#15120F] dark:text-[#AC9E92] dark:hover:text-[#F6EFE8] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
                  title="Clear search"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            {/* Active search filter feedback */}
            {searchQuery.trim().length > 0 && (
              <div className="flex items-center justify-between px-1 text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                <span>
                  Filtering by: <strong className="text-[#B03C09] dark:text-[#FF9A52]">"{searchQuery}"</strong> ({filteredTransactions.length} of {transactions.length} matching)
                </span>
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                >
                  Clear search
                </button>
              </div>
            )}
          </div>

          {/* Executive Ledger Cash Movement Cockpit */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F0D5C0] dark:border-[#383029] rounded-3xl p-4 sm:p-5 shadow-xs flex flex-col gap-4">
            {/* Cockpit Header & Scope Indicator */}
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <div className="w-7 h-7 rounded-xl bg-[#FFEEDF] dark:bg-[#1E1813] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0">
                  <Scale size={15} />
                </div>
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <span className="text-xs font-extrabold uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
                      Journal Cash Movement
                    </span>
                    {selectedType !== 'all' && (
                      <span className="px-2 py-0.2 rounded-full text-[10px] font-bold bg-[#B03C09]/10 text-[#B03C09] dark:text-[#FF9A52] uppercase">
                        {selectedType} only
                      </span>
                    )}
                  </div>
                  <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate">
                    {activeProfile === 'all' ? 'Consolidated Books' : `${activeProfile.toUpperCase()} Profile`}
                    {selectedAccountId !== 'all' && ` · ${accounts.find(a => a.id === selectedAccountId)?.name || 'Account'}`}
                  </div>
                </div>
              </div>

              {/* Reset Type Filter Button if active */}
              {selectedType !== 'all' ? (
                <button
                  type="button"
                  onClick={() => setSelectedType('all')}
                  className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-[#FFEEDF] dark:bg-[#1E1813] border border-[#F3DFCD] dark:border-[#383029] text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#B03C09]/10 cursor-pointer transition-colors"
                >
                  <RotateCcw size={11} />
                  <span>Show All</span>
                </button>
              ) : (
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/10 text-[#16643F] dark:text-[#5FCB8E] border border-emerald-500/20 shrink-0">
                  Double-Entry Balanced
                </span>
              )}
            </div>

            {/* Tri-Pillar Interactive Movement Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 sm:gap-3">
              {/* Pillar 1: Total Inflows */}
              <button
                type="button"
                onClick={() => setSelectedType(selectedType === 'income' ? 'all' : 'income')}
                className={`p-3.5 rounded-2xl text-left transition-all cursor-pointer border min-w-0 flex flex-col justify-between ${
                  selectedType === 'income'
                    ? 'bg-emerald-500/15 border-emerald-500/50 shadow-xs ring-2 ring-emerald-500/20'
                    : 'bg-emerald-500/8 dark:bg-emerald-950/20 border-emerald-500/20 hover:border-emerald-500/40 hover:bg-emerald-500/12'
                }`}
              >
                <div className="flex items-center justify-between gap-1.5 mb-1.5">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <div className="w-5 h-5 rounded-lg bg-emerald-500/15 flex items-center justify-center text-emerald-700 dark:text-emerald-300 shrink-0">
                      <ArrowDownLeft size={13} />
                    </div>
                    <span className="text-xs font-bold text-emerald-900 dark:text-emerald-200 truncate">
                      Total Inflows
                    </span>
                  </div>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-white/80 dark:bg-[#1E1813]/80 text-emerald-800 dark:text-emerald-300 border border-emerald-500/20 shrink-0">
                    {inflowCount} {inflowCount === 1 ? 'cr' : 'crs'}
                  </span>
                </div>
                <div className="text-base sm:text-lg font-extrabold text-emerald-800 dark:text-emerald-300 tabular-nums truncate">
                  +{formatPeso(totalIn)}
                </div>
                <div className="text-[10px] text-emerald-700/80 dark:text-emerald-400/80 mt-1 flex items-center justify-between">
                  <span>Gross receipts</span>
                  <span className="font-semibold">{selectedType === 'income' ? '● Active' : 'Filter ↵'}</span>
                </div>
              </button>

              {/* Pillar 2: Total Outflows */}
              <button
                type="button"
                onClick={() => setSelectedType(selectedType === 'expense' ? 'all' : 'expense')}
                className={`p-3.5 rounded-2xl text-left transition-all cursor-pointer border min-w-0 flex flex-col justify-between ${
                  selectedType === 'expense'
                    ? 'bg-rose-500/15 border-rose-500/50 shadow-xs ring-2 ring-rose-500/20'
                    : 'bg-rose-500/8 dark:bg-rose-950/20 border-rose-500/20 hover:border-rose-500/40 hover:bg-rose-500/12'
                }`}
              >
                <div className="flex items-center justify-between gap-1.5 mb-1.5">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <div className="w-5 h-5 rounded-lg bg-rose-500/15 flex items-center justify-center text-rose-700 dark:text-rose-300 shrink-0">
                      <ArrowUpRight size={13} />
                    </div>
                    <span className="text-xs font-bold text-rose-900 dark:text-rose-200 truncate">
                      Total Outflows
                    </span>
                  </div>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-white/80 dark:bg-[#1E1813]/80 text-rose-800 dark:text-rose-300 border border-rose-500/20 shrink-0">
                    {outflowCount} {outflowCount === 1 ? 'db' : 'dbs'}
                  </span>
                </div>
                <div className="text-base sm:text-lg font-extrabold text-rose-700 dark:text-rose-300 tabular-nums truncate">
                  -{formatPeso(totalOut)}
                </div>
                <div className="text-[10px] text-rose-700/80 dark:text-rose-400/80 mt-1 flex items-center justify-between">
                  <span>Expenses & bills</span>
                  <span className="font-semibold">{selectedType === 'expense' ? '● Active' : 'Filter ↵'}</span>
                </div>
              </button>

              {/* Pillar 3: Net Cash Movement */}
              <button
                type="button"
                onClick={() => setSelectedType('all')}
                className={`p-3.5 rounded-2xl text-left transition-all cursor-pointer border min-w-0 flex flex-col justify-between ${
                  selectedType === 'all'
                    ? 'bg-[#FFEEDF]/80 dark:bg-[#2A211A] border-[#F0D5C0] dark:border-[#42372E] shadow-2xs'
                    : 'bg-[#FFEEDF]/40 dark:bg-[#1F1914] border-[#F3DFCD] dark:border-[#383029] hover:bg-[#FFEEDF]/70'
                }`}
              >
                <div className="flex items-center justify-between gap-1.5 mb-1.5">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <div
                      className={`w-5 h-5 rounded-lg flex items-center justify-center shrink-0 ${
                        netMovement >= 0
                          ? 'bg-[#16643F]/15 text-[#16643F] dark:text-[#5FCB8E]'
                          : 'bg-[#B03C09]/15 text-[#B03C09] dark:text-[#FF9A52]'
                      }`}
                    >
                      {netMovement >= 0 ? <TrendingUp size={13} /> : <TrendingDown size={13} />}
                    </div>
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                      Net Movement
                    </span>
                  </div>
                  <span
                    className={`text-[10px] font-bold px-1.5 py-0.5 rounded-md border shrink-0 ${
                      netMovement >= 0
                        ? 'bg-emerald-500/10 text-[#16643F] dark:text-[#5FCB8E] border-emerald-500/20'
                        : 'bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/20'
                    }`}
                  >
                    {totalIn > 0 ? `${retentionPercentage}% kept` : netMovement >= 0 ? 'Surplus' : 'Deficit'}
                  </span>
                </div>
                <div
                  className={`text-base sm:text-lg font-extrabold tabular-nums truncate ${
                    netMovement >= 0
                      ? 'text-[#16643F] dark:text-[#5FCB8E]'
                      : 'text-[#B03C09] dark:text-[#FF9A52]'
                  }`}
                >
                  {netMovement >= 0 ? `+${formatPeso(netMovement)}` : `-${formatPeso(Math.abs(netMovement))}`}
                </div>
                <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-1 flex items-center justify-between">
                  <span>Net capital change</span>
                  <span className="font-semibold">{selectedType !== 'all' ? 'Reset ↵' : '● All view'}</span>
                </div>
              </button>
            </div>

            {/* Proportional Cash Retention Beam */}
            {(totalIn > 0 || totalOut > 0) && (
              <div className="space-y-1.5 pt-1">
                <div className="flex items-center justify-between text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                  <span className="text-rose-700 dark:text-rose-300">
                    Outflows: {outflowPercentage}% ({formatPeso(totalOut)})
                  </span>
                  <span className="text-[#16643F] dark:text-[#5FCB8E]">
                    Retained Net: {retentionPercentage}% ({formatPeso(Math.max(0, netMovement))})
                  </span>
                </div>
                <div className="h-2 w-full bg-[#F3DFCD] dark:bg-[#383029] rounded-full overflow-hidden flex">
                  <div
                    className="bg-rose-500/80 dark:bg-rose-400 h-full transition-all duration-300"
                    style={{ width: `${outflowPercentage}%` }}
                    title={`Outflows: ${outflowPercentage}%`}
                  />
                  <div
                    className="bg-[#16643F] dark:bg-[#5FCB8E] h-full transition-all duration-300"
                    style={{ width: `${Math.max(0, 100 - outflowPercentage)}%` }}
                    title={`Retained: ${retentionPercentage}%`}
                  />
                </div>
              </div>
            )}

            {/* Auditor Provenance & Interactive Hint Footer */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1.5 text-[11px] text-[#6B6156] dark:text-[#AC9E92] pt-2.5 border-t border-[#F0D5C0]/60 dark:border-[#383029]/60">
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={14} className="text-[#16643F] dark:text-[#5FCB8E] shrink-0" />
                <span>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] font-bold">
                    {filteredTransactions.length}
                  </strong>{' '}
                  {filteredTransactions.length === 1 ? 'journal entry' : 'journal entries'} displayed
                  {transferCount > 0 && ` (${transferCount} neutral transfers)`}
                </span>
              </div>
              <div className="flex items-center gap-1 font-semibold text-[#B03C09] dark:text-[#FF9A52]">
                <span>Tap any row below to audit full timeline</span>
                <ChevronRight size={12} />
              </div>
            </div>
          </div>

          {/* Status & Account Filters */}
          <div className="flex flex-col gap-2">
            {/* Status lifecycle filter chips */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
              <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1 shrink-0">
                <Filter size={12} />
                <span>Status:</span>
              </span>
              <button
                type="button"
                onClick={() => setSelectedStatus('all')}
                className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors border ${
                  selectedStatus === 'all'
                    ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
                    : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                }`}
              >
                All
              </button>
              {(['confirmed', 'reconciled', 'pending', 'corrected', 'duplicate', 'excluded'] as TransactionStatus[]).map(
                (st) => (
                  <button
                    key={st}
                    type="button"
                    onClick={() => setSelectedStatus(st)}
                    className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors border capitalize ${
                      selectedStatus === st
                        ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                        : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    {st}
                  </button>
                )
              )}
            </div>

            {/* Account filter dropdown */}
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] shrink-0">
                Account:
              </span>
              <select
                value={selectedAccountId}
                onChange={(e) => setSelectedAccountId(e.target.value)}
                className="w-full text-xs font-semibold bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl px-3 py-1.5 text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
              >
                <option value="all">All Accounts (Consolidated Ledger)</option>
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    [{acc.monogram}] {acc.name} ({acc.kind})
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Day Grouped Ledger Entries */}
          <div className="space-y-4">
            {groupedByDay.length === 0 ? (
              <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-8 text-center flex flex-col items-center gap-2 shadow-2xs">
                {searchQuery.trim().length > 0 ? (
                  <>
                    <div className="w-10 h-10 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52]">
                      <Search size={18} />
                    </div>
                    <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      No transactions matching "{searchQuery}"
                    </div>
                    <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] max-w-sm leading-relaxed">
                      Try searching by description (e.g. merchant or note), category (e.g. Groceries, Bills), or amount (e.g. 500, 1,450).
                    </p>
                    <button
                      type="button"
                      onClick={() => setSearchQuery('')}
                      className="mt-2 px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold cursor-pointer transition-all hover:opacity-90"
                    >
                      Clear Search
                    </button>
                  </>
                ) : (
                  <div className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    No transactions match your current entity, status, or account filters.
                  </div>
                )}
              </div>
            ) : (
              groupedByDay.map(([dateKey, dayTxs]) => {
                const dayOut = dayTxs
                  .filter((t) => t.type === 'expense' && t.status !== 'excluded' && t.status !== 'duplicate')
                  .reduce((sum, t) => sum + t.amount, 0);

                return (
                  <div key={dateKey} className="flex flex-col gap-1.5">
                    {/* Day Header */}
                    <div className="flex items-center justify-between px-2 text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      <span>{formatDateLabel(dateKey)}</span>
                      <span>{dayOut > 0 ? `Out: ${formatPeso(dayOut)}` : ''}</span>
                    </div>

                    {/* Card containing day transactions */}
                    <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
                      {dayTxs.map((tx) => {
                        const isIncome = tx.type === 'income';
                        const isTransfer = tx.type === 'transfer';
                        const sourceAcc = getAccountInfo(tx.accountId);
                        const destAcc = getAccountInfo(tx.toAccountId);
                        const badge = STATUS_BADGE_CONFIG[tx.status || 'confirmed'];
                        const hasHistory = tx.changeHistory && tx.changeHistory.length > 0;

                        return (
                          <div
                            key={tx.id}
                            onClick={() => setSelectedTransaction(tx)}
                            className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors group gap-2 cursor-pointer"
                          >
                            {/* Left: Direction Icon & Details */}
                            <div className="flex items-center gap-3 min-w-0 flex-1">
                              <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0 bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]">
                                {isIncome ? (
                                  <ArrowDownLeft
                                    size={17}
                                    className="text-[#16643F] dark:text-[#5FCB8E]"
                                  />
                                ) : isTransfer ? (
                                  <ArrowRightLeft
                                    size={17}
                                    className="text-[#5A5148] dark:text-[#C6B8AC]"
                                  />
                                ) : (
                                  <ArrowUpRight
                                    size={17}
                                    className="text-[#5A5148] dark:text-[#C6B8AC]"
                                  />
                                )}
                              </div>

                              <div className="flex flex-col min-w-0 flex-1">
                                <div className="flex items-center gap-1.5 flex-wrap">
                                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                                    {tx.merchant || tx.category}
                                  </span>

                                  {/* Status Chip */}
                                  <span
                                    className={`px-1.5 py-0.2 rounded text-[9px] font-bold border uppercase tracking-wider ${badge.bg} ${badge.text} ${badge.border}`}
                                  >
                                    {badge.label}
                                  </span>

                                  {/* Profile Badge (if viewing All) */}
                                  {activeProfile === 'all' && tx.profile && (
                                    <span className="px-1.5 py-0.2 rounded text-[9px] font-bold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] capitalize">
                                      {tx.profile}
                                    </span>
                                  )}
                                </div>

                                <div className="flex items-center gap-1.5 text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate mt-0.5 flex-wrap">
                                  <span>{tx.category}</span>
                                  <span>·</span>
                                  <span className="font-medium text-[#15120F] dark:text-[#F6EFE8]">
                                    {sourceAcc?.name || 'Account'}
                                  </span>
                                  {isTransfer && destAcc && (
                                    <>
                                      <span>→</span>
                                      <span className="font-medium text-[#15120F] dark:text-[#F6EFE8]">
                                        {destAcc.name}
                                      </span>
                                    </>
                                  )}

                                  {tx.person && (
                                    <span className="flex items-center gap-0.5 text-stone-700 dark:text-stone-300">
                                      <User size={10} />
                                      {tx.person}
                                    </span>
                                  )}

                                  {tx.attachmentUrl && (
                                    <Paperclip size={11} className="text-[#B03C09] dark:text-[#FF9A52]" />
                                  )}

                                  {hasHistory && (
                                    <History size={11} className="text-purple-600 dark:text-purple-400" />
                                  )}
                                </div>

                                {/* Tags preview */}
                                {tx.tags && tx.tags.length > 0 && (
                                  <div className="flex items-center gap-1 mt-1">
                                    {tx.tags.slice(0, 2).map((tg, i) => (
                                      <span
                                        key={i}
                                        className="text-[9px] px-1.5 py-0.2 rounded-full bg-stone-100 dark:bg-[#1E1813] text-[#6B6156] dark:text-[#AC9E92] font-medium"
                                      >
                                        {tg}
                                      </span>
                                    ))}
                                    {tx.tags.length > 2 && (
                                      <span className="text-[9px] text-[#6B6156]">
                                        +{tx.tags.length - 2}
                                      </span>
                                    )}
                                  </div>
                                )}
                              </div>
                            </div>

                            {/* Right: Amount */}
                            <div className="flex flex-col items-end shrink-0 pl-2 text-right">
                              <span
                                className={`text-xs sm:text-sm font-bold whitespace-nowrap tabular-nums ${
                                  tx.status === 'excluded' || tx.status === 'duplicate'
                                    ? 'line-through text-stone-400 dark:text-stone-600'
                                    : isIncome
                                    ? 'text-[#16643F] dark:text-[#5FCB8E]'
                                    : 'text-[#15120F] dark:text-[#F6EFE8]'
                                }`}
                              >
                                {isIncome ? `+${formatPeso(tx.amount)}` : formatPeso(tx.amount)}
                              </span>
                              {tx.originalAmount && tx.originalAmount !== tx.amount && (
                                <span className="text-[10px] text-purple-600 dark:text-purple-400 font-medium">
                                  Corrected
                                </span>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </>
      ) : (
        /* Insights Segment */
        <div className="space-y-6">
          {/* Chart 1: Spending by Category this Cycle */}
          <div className="flex flex-col gap-2">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
              1. Spending by Category (This Cycle)
            </h2>
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3">
              {categorySpending.slice(0, 5).map(([category, amount]) => {
                const percent = Math.round((amount / totalOut) * 100) || 0;
                const barWidth = (amount / maxCategorySpend) * 100;

                return (
                  <div key={category} className="flex flex-col gap-1">
                    <div className="flex justify-between text-xs font-semibold gap-2">
                      <span className="text-[#15120F] dark:text-[#F6EFE8] truncate min-w-0">{category}</span>
                      <span className="text-[#5A5148] dark:text-[#C6B8AC] shrink-0 whitespace-nowrap">
                        {formatPeso(amount)} ({percent}%)
                      </span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden">
                      <div
                        className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full transition-all duration-500"
                        style={{ width: `${barWidth}%` }}
                      />
                    </div>
                  </div>
                );
              })}
              <p className="text-xs font-medium text-[#5E2C08] dark:text-[#FF9A52] pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                Food & Dining takes {Math.round(((categorySpending[0]?.[1] || 0) / (totalOut || 1)) * 100)}% of your total spend this sweldo cycle.
              </p>
            </div>
          </div>

          {/* Chart 2: In vs Out */}
          <div className="flex flex-col gap-2">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
              2. Cash Flow (In vs Out)
            </h2>
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3">
              <div className="grid grid-cols-2 gap-2 sm:gap-3">
                <div className="flex flex-col p-3 rounded-xl bg-[#16643F]/10 dark:bg-[#5FCB8E]/10 min-w-0">
                  <span className="text-xs font-semibold text-[#16643F] dark:text-[#5FCB8E] truncate">
                    Total Inflow
                  </span>
                  <span className="text-base sm:text-lg font-extrabold text-[#16643F] dark:text-[#5FCB8E] truncate tabular-nums">
                    {formatPeso(totalIn)}
                  </span>
                </div>
                <div className="flex flex-col p-3 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 min-w-0">
                  <span className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] truncate">
                    Total Outflow
                  </span>
                  <span className="text-base sm:text-lg font-extrabold text-[#B03C09] dark:text-[#FF9A52] truncate tabular-nums">
                    {formatPeso(totalOut)}
                  </span>
                </div>
              </div>
              <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] break-words">
                You have retained {formatPeso(Math.max(0, totalIn - totalOut))} ({Math.round(((totalIn - totalOut) / (totalIn || 1)) * 100)}%) of all incoming cash this cycle.
              </p>
            </div>
          </div>

          {/* Chart 3: Safe-to-Spend Trajectory */}
          <div className="flex flex-col gap-2">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] px-1">
              3. Safe-to-Spend Runway
            </h2>
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex items-center gap-3">
              <div className="p-3 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] shrink-0">
                <TrendingUp size={24} />
              </div>
              <div className="min-w-0 flex-1">
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                  {formatPeso(safeToSpend)} liquid buffer
                </h3>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] break-words">
                  Keeps you on track with safe limits until next payday sweldo credit.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Transaction Detail & Audit Modal */}
      <TransactionDetailModal
        transaction={selectedTransaction}
        isOpen={!!selectedTransaction}
        onClose={() => setSelectedTransaction(null)}
      />
    </div>
  );
};
