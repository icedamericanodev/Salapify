import React, { useState, useMemo } from 'react';
import { Search, ChevronLeft, ChevronRight, Trash2, ArrowDownLeft, ArrowUpRight, ArrowRightLeft, TrendingUp } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso, formatDateLabel } from '../utils/format';
import { Transaction } from '../types';

export const LedgerScreen: React.FC = () => {
  const { transactions, accounts, deleteTransaction, safeToSpend } = useFinancial();

  const [activeSegment, setActiveSegment] = useState<'entries' | 'insights'>('entries');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  // Calculate totals
  const totalIn = useMemo(
    () =>
      transactions
        .filter((t) => t.type === 'income')
        .reduce((sum, t) => sum + t.amount, 0),
    [transactions]
  );

  const totalOut = useMemo(
    () =>
      transactions
        .filter((t) => t.type === 'expense')
        .reduce((sum, t) => sum + t.amount, 0),
    [transactions]
  );

  // Filtered transactions
  const filteredTransactions = useMemo(() => {
    return transactions.filter((t) => {
      const matchSearch =
        !searchQuery.trim() ||
        (t.merchant && t.merchant.toLowerCase().includes(searchQuery.toLowerCase())) ||
        (t.note && t.note.toLowerCase().includes(searchQuery.toLowerCase())) ||
        t.category.toLowerCase().includes(searchQuery.toLowerCase()) ||
        t.amount.toString().includes(searchQuery);

      const matchCategory =
        selectedCategory === 'all' || t.category.toLowerCase() === selectedCategory.toLowerCase();

      return matchSearch && matchCategory;
    });
  }, [transactions, searchQuery, selectedCategory]);

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
      .filter((t) => t.type === 'expense')
      .forEach((t) => {
        catMap.set(t.category, (catMap.get(t.category) || 0) + t.amount);
      });
    return Array.from(catMap.entries()).sort((a, b) => b[1] - a[1]);
  }, [transactions]);

  const maxCategorySpend = categorySpending[0]?.[1] || 1;

  const getAccountName = (accId: string) => {
    const acc = accounts.find((a) => a.id === accId);
    return acc ? acc.name.split(' ')[0] : 'Account';
  };

  return (
    <div className="flex flex-col gap-4 pb-24">
      {/* Screen Title */}
      <div className="flex items-center justify-between pt-2 px-1">
        <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
          Ledger
        </h1>
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

      {activeSegment === 'entries' ? (
        <>
          {/* Cycle Switcher & Totals */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <button
                type="button"
                className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
              >
                <ChevronLeft size={18} />
              </button>
              <span className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Sep 1 to 15 (Current Sweldo Cycle)
              </span>
              <button
                type="button"
                className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] cursor-pointer"
              >
                <ChevronRight size={18} />
              </button>
            </div>

            <div className="text-center text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
              In <span className="text-[#16643F] dark:text-[#5FCB8E]">{formatPeso(totalIn)}</span> · Out <span className="text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(totalOut)}</span>
            </div>
          </div>

          {/* Search & Category Filter */}
          <div className="flex flex-col gap-2">
            <div className="relative">
              <Search
                size={16}
                className="absolute left-3.5 top-3 text-[#6B6156] dark:text-[#AC9E92]"
              />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search merchant, note, or amount..."
                className="w-full pl-9 pr-4 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] placeholder:text-[#6B6156]/60 focus:outline-none focus:border-[#B03C09]"
              />
            </div>

            {/* Filter chips */}
            <div className="flex gap-1.5 overflow-x-auto pb-1 no-scrollbar">
              {['all', 'Food & Dining', 'Transport', 'Bills & Utilities', 'Groceries', 'Shopping', 'Salary'].map(
                (cat) => (
                  <button
                    key={cat}
                    type="button"
                    onClick={() => setSelectedCategory(cat)}
                    className={`px-3 py-1 rounded-full text-xs font-medium whitespace-nowrap cursor-pointer transition-colors border ${
                      selectedCategory === cat
                        ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent font-bold'
                        : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    {cat === 'all' ? 'All Transactions' : cat}
                  </button>
                )
              )}
            </div>
          </div>

          {/* Day Grouped List */}
          <div className="space-y-4">
            {groupedByDay.length === 0 ? (
              <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-8 text-center text-xs text-[#6B6156] dark:text-[#AC9E92]">
                No matching transactions found.
              </div>
            ) : (
              groupedByDay.map(([dateKey, dayTxs]) => {
                const dayOut = dayTxs
                  .filter((t) => t.type === 'expense')
                  .reduce((sum, t) => sum + t.amount, 0);

                return (
                  <div key={dateKey} className="flex flex-col gap-1.5">
                    {/* Day Header with Day Total in quiet ink */}
                    <div className="flex items-center justify-between px-2 text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      <span>{formatDateLabel(dateKey)}</span>
                      <span>{dayOut > 0 ? `Out: ${formatPeso(dayOut)}` : ''}</span>
                    </div>

                    {/* Card containing day transactions */}
                    <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
                      {dayTxs.map((tx) => {
                        const isIncome = tx.type === 'income';
                        const isTransfer = tx.type === 'transfer';

                        return (
                          <div
                            key={tx.id}
                            className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors group"
                          >
                            <div className="flex items-center gap-3">
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
                              <div className="flex flex-col">
                                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                                  {tx.merchant || tx.category}
                                </span>
                                <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                                  {tx.category} · {getAccountName(tx.accountId)}
                                  {tx.note ? ` · ${tx.note}` : ''}
                                </span>
                              </div>
                            </div>

                            <div className="flex items-center gap-2">
                              <span
                                className={`text-xs font-bold ${
                                  isIncome
                                    ? 'text-[#16643F] dark:text-[#5FCB8E]'
                                    : 'text-[#15120F] dark:text-[#F6EFE8]'
                                }`}
                              >
                                {isIncome ? `+${formatPeso(tx.amount)}` : formatPeso(tx.amount)}
                              </span>

                              <button
                                type="button"
                                onClick={() => deleteTransaction(tx.id)}
                                title="Delete entry"
                                className="opacity-0 group-hover:opacity-100 p-1 text-[#6B6156] hover:text-[#9E2C1B] transition-opacity cursor-pointer"
                              >
                                <Trash2 size={14} />
                              </button>
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
                    <div className="flex justify-between text-xs font-semibold">
                      <span className="text-[#15120F] dark:text-[#F6EFE8]">{category}</span>
                      <span className="text-[#5A5148] dark:text-[#C6B8AC]">
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
              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col p-3 rounded-xl bg-[#16643F]/10 dark:bg-[#5FCB8E]/10">
                  <span className="text-xs font-semibold text-[#16643F] dark:text-[#5FCB8E]">
                    Total Inflow
                  </span>
                  <span className="text-lg font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                    {formatPeso(totalIn)}
                  </span>
                </div>
                <div className="flex flex-col p-3 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/10">
                  <span className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52]">
                    Total Outflow
                  </span>
                  <span className="text-lg font-extrabold text-[#B03C09] dark:text-[#FF9A52]">
                    {formatPeso(totalOut)}
                  </span>
                </div>
              </div>
              <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
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
              <div className="p-3 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52]">
                <TrendingUp size={24} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  {formatPeso(safeToSpend)} liquid buffer
                </h3>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  Keeps you on track with safe limits until next payday sweldo credit.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
