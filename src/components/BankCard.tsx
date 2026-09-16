import React, { useState } from 'react';
import { Account } from '../types';
import { formatPeso } from '../utils/format';
import { convertToPhp, formatCurrency } from '../utils/currencies';
import { getLogoUrl } from '../utils/logos';

interface BankCardProps {
  account: Account;
  onClick?: () => void;
}

export const BankCard: React.FC<BankCardProps> = ({ account, onClick }) => {
  const isCredit = account.kind === 'credit';
  const isForeign = account.currency && account.currency !== 'PHP';
  const phpEquiv = convertToPhp(account.balance, account.currency || 'PHP');
  
  const [imgError, setImgError] = useState(false);
  const logoUrl = getLogoUrl(account.institution);

  // Bank specific themes for regular cards
  const bankThemes: Record<string, string> = {
    'BPI': 'bg-gradient-to-br from-red-700 to-red-900 text-white border-red-800',
    'BDO': 'bg-gradient-to-br from-blue-700 to-blue-900 text-white border-blue-800',
    'UnionBank': 'bg-gradient-to-br from-orange-500 to-orange-700 text-white border-orange-600',
    'GCash': 'bg-gradient-to-br from-blue-500 to-blue-700 text-white border-blue-600',
    'Maya': 'bg-gradient-to-br from-emerald-600 to-emerald-900 text-white border-emerald-700',
    'Metrobank': 'bg-gradient-to-br from-blue-800 to-blue-950 text-white border-blue-900',
    'MariBank': 'bg-gradient-to-br from-orange-500 to-red-500 text-white border-orange-600',
    'GoTyme': 'bg-gradient-to-br from-cyan-600 to-blue-700 text-white border-cyan-700',
    'RCBC': 'bg-gradient-to-br from-blue-700 to-blue-900 text-white border-blue-800',
    'Security Bank': 'bg-gradient-to-br from-blue-600 to-blue-800 text-white border-blue-700',
    'EastWest': 'bg-gradient-to-br from-purple-700 to-purple-900 text-white border-purple-800',
    'PNB': 'bg-gradient-to-br from-red-800 to-red-950 text-white border-red-900',
    'Atome': 'bg-gradient-to-br from-yellow-400 to-yellow-500 text-slate-900 border-yellow-400',
    'AUB': 'bg-gradient-to-br from-blue-400 to-blue-600 text-white border-blue-500',
    'TikTok': 'bg-gradient-to-br from-black to-zinc-900 text-white border-zinc-800',
    'LandBank': 'bg-gradient-to-br from-green-600 to-green-800 text-white border-green-700',
    'PSBank': 'bg-gradient-to-br from-blue-600 to-blue-800 text-white border-blue-700',
    'China Bank': 'bg-gradient-to-br from-red-600 to-red-800 text-white border-red-700',
    'UNO Digital Bank': 'bg-gradient-to-br from-fuchsia-600 to-pink-600 text-white border-fuchsia-700',
    'OwnBank': 'bg-gradient-to-br from-indigo-800 to-purple-900 text-white border-indigo-700',
  };

  // Determine skin based on tier
  const tierStyles: Record<string, string> = {
    regular: bankThemes[account.institution] || 'bg-gradient-to-br from-slate-100 to-slate-200 text-slate-800 dark:from-[#2A241F] dark:to-[#1A1612] dark:text-[#F6EFE8] border-slate-300 dark:border-[#383029]',
    gold: 'bg-gradient-to-br from-yellow-200 to-amber-400 text-amber-900 dark:from-yellow-700 dark:to-amber-900 dark:text-yellow-100 border-yellow-400 dark:border-yellow-600',
    platinum: 'bg-gradient-to-br from-zinc-200 to-zinc-400 text-zinc-900 dark:from-zinc-600 dark:to-zinc-800 dark:text-zinc-100 border-zinc-400 dark:border-zinc-500',
    black: 'bg-gradient-to-br from-neutral-800 to-black text-neutral-100 border-neutral-700 dark:border-neutral-800',
    custom: 'bg-gradient-to-br from-[#FFEEDF] to-[#F3DFCD] text-[#15120F] dark:from-[#27201A] dark:to-[#14100D] dark:text-[#F6EFE8] border-[#F3DFCD] dark:border-[#383029]'
  };

  const styleClass = tierStyles[account.cardTier || 'regular'] || tierStyles.custom;
  
  const formattedLimit = account.creditLimit ? formatCurrency(account.creditLimit, account.currency || 'PHP') : null;
  const formattedBalance = account.currency && account.currency !== 'PHP' 
    ? formatCurrency(Math.abs(account.balance), account.currency) 
    : formatPeso(Math.abs(account.balance));

  // Network logos
  const renderNetwork = () => {
    switch(account.cardNetwork) {
      case 'visa': return <div className="text-xl font-bold italic tracking-tighter opacity-80">VISA</div>;
      case 'mastercard': return <div className="flex"><div className="w-6 h-6 rounded-full bg-red-500 opacity-80 -mr-2"></div><div className="w-6 h-6 rounded-full bg-yellow-500 opacity-80"></div></div>;
      case 'amex': return <div className="text-sm font-bold uppercase border border-current p-1 opacity-80">AMEX</div>;
      case 'jcb': return <div className="text-sm font-bold opacity-80">JCB</div>;
      default: return null;
    }
  }

  return (
    <div 
      onClick={onClick}
      className={`relative w-full rounded-2xl p-4 flex flex-col gap-4 shadow-sm border ${styleClass} overflow-hidden hover:opacity-95 transition-opacity cursor-pointer`}
    >
      <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-10 -mt-10 blur-xl pointer-events-none"></div>

      <div className="flex justify-between items-start z-10">
        <div className="flex flex-col">
          <span className="font-bold tracking-widest uppercase text-[10px] opacity-70">
            {account.institution}
          </span>
          <span className="font-semibold text-sm truncate max-w-[150px]">
            {account.name}
          </span>
        </div>
        <div className="flex flex-col items-end gap-1 bg-white/20 dark:bg-black/20 p-1.5 rounded-lg">
          {imgError ? (
            <div className="text-sm font-bold opacity-80">{account.monogram}</div>
          ) : (
            <img 
              src={logoUrl} 
              alt={account.institution}
              onError={() => setImgError(true)}
              className="h-7 w-7 object-contain bg-white rounded p-0.5"
            />
          )}
        </div>
      </div>

      <div className="flex items-center gap-2 mt-2 z-10">
        <div className="w-8 h-6 rounded bg-black/10 dark:bg-white/10 border border-black/5 dark:border-white/5"></div>
        <div className="font-mono text-lg tracking-widest opacity-90 font-bold">
          **** **** **** {account.accountNumber ? account.accountNumber.slice(-4) : '••••'}
        </div>
      </div>

      <div className="flex justify-between items-end mt-2 z-10">
        <div className="flex flex-col">
          <span className="text-[10px] uppercase tracking-wider opacity-70 font-semibold mb-0.5">
            {isCredit ? 'Outstanding Balance' : 'Available Balance'}
          </span>
          <span className="font-display font-extrabold text-xl">
            {isCredit && account.balance > 0 ? '-' : ''}{formattedBalance}
          </span>
          {isForeign && (
             <span className="text-[10px] opacity-70 tabular-nums block">
               ≈ {formatPeso(Math.abs(phpEquiv))}
             </span>
          )}
        </div>
        <div className="flex flex-col items-end justify-end gap-2">
           {isCredit && formattedLimit && (
             <div className="flex flex-col items-end">
                <span className="text-[9px] uppercase opacity-70 font-bold">Credit Limit</span>
                <span className="text-[11px] font-bold">{formattedLimit}</span>
             </div>
           )}
           {renderNetwork()}
        </div>
      </div>
    </div>
  );
};
