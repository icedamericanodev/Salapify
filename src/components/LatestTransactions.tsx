import React from 'react';
import { ChevronRight, ArrowDownLeft, ArrowUpRight, ArrowRightLeft } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso, formatDateLabel } from '../utils/format';
import { Transaction } from '../types';

interface LatestTransactionsProps {
  onSeeAll: () => void;
  onSelectTransaction?: (tx: Transaction) => void;
}

export const LatestTransactions: React.FC<LatestTransactionsProps> = ({
  onSeeAll,
  onSelectTransaction,
}) => {
  const { transactions, accounts } = useFinancial();

  const getAccountName = (accId: string) => {
    const acc = accounts.find((a) => a.id === accId);
    return acc ? acc.name.split(' ')[0] : 'Account';
  };

  const latestList = transactions.slice(0, 6);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between px-1">
        <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
          Latest
        </h2>
        <button
          type="button"
          onClick={onSeeAll}
          className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-0.5 hover:underline cursor-pointer"
        >
          See all <ChevronRight size={14} />
        </button>
      </div>

      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
        {latestList.length === 0 ? (
          <div className="p-6 text-center text-xs text-[#6B6156] dark:text-[#AC9E92]">
            No transactions logged yet. Tap the Log button to add one.
          </div>
        ) : (
          latestList.map((tx) => {
            const isIncome = tx.type === 'income';
            const isTransfer = tx.type === 'transfer';

            return (
              <div
                key={tx.id}
                onClick={() => onSelectTransaction?.(tx)}
                className="flex items-center justify-between p-3.5 hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0 bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]">
                    {isIncome ? (
                      <ArrowDownLeft size={17} className="text-[#16643F] dark:text-[#5FCB8E]" />
                    ) : isTransfer ? (
                      <ArrowRightLeft size={17} className="text-[#5A5148] dark:text-[#C6B8AC]" />
                    ) : (
                      <ArrowUpRight size={17} className="text-[#5A5148] dark:text-[#C6B8AC]" />
                    )}
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {tx.merchant || tx.category}
                    </span>
                    <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                      {tx.category} · {getAccountName(tx.accountId)}
                    </span>
                  </div>
                </div>

                <div className="flex flex-col items-end">
                  <span
                    className={`text-xs font-bold ${
                      isIncome
                        ? 'text-[#16643F] dark:text-[#5FCB8E]'
                        : 'text-[#15120F] dark:text-[#F6EFE8]'
                    }`}
                  >
                    {isIncome ? `+${formatPeso(tx.amount)}` : formatPeso(tx.amount)}
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    {formatDateLabel(tx.date)}
                  </span>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
