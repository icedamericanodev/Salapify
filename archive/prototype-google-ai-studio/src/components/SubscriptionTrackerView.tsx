import React, { useState } from 'react';
import { CreditCard, Calendar, TrendingUp, AlertTriangle, Infinity, RotateCcw, Search, Plus } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

export const SubscriptionTrackerView: React.FC = () => {
  const { } = useFinancial();
  const [searchTerm, setSearchTerm] = useState('');

  // Stub data for demonstration
  const subscriptions = [
    { id: '1', name: 'Netflix Premium', amount: 549, cycle: 'Monthly', nextBilling: '2026-10-05', type: 'entertainment', status: 'active' },
    { id: '2', name: 'Spotify Duo', amount: 239, cycle: 'Monthly', nextBilling: '2026-10-12', type: 'entertainment', status: 'active' },
    { id: '3', name: 'Google One 2TB', amount: 4790, cycle: 'Annual', nextBilling: '2027-04-15', type: 'utility', status: 'active', unusedAlert: true },
    { id: '4', name: 'Gym Membership', amount: 2500, cycle: 'Monthly', nextBilling: '2026-10-01', type: 'health', status: 'active', duplicateAlert: true },
    { id: '5', name: 'Adobe Creative Cloud', amount: 1549, cycle: 'Monthly', nextBilling: '2026-10-22', type: 'software', status: 'trial', trialEnds: '2026-09-22' },
  ];

  return (
    <div className="flex flex-col gap-4 pb-20">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Subscriptions</h2>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">Detect and manage recurring charges</p>
        </div>
        <button className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold hover:opacity-90 transition-colors">
          <Plus size={14} /> Add
        </button>
      </div>

      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-3 shadow-xs">
        <div className="grid grid-cols-2 gap-3 mb-3">
          <div className="p-3 bg-rose-50 dark:bg-rose-950/30 rounded-xl">
            <span className="text-[10px] font-bold text-rose-700 dark:text-rose-400 uppercase tracking-wider block mb-1">Monthly Total</span>
            <span className="text-lg font-black text-rose-800 dark:text-rose-300">₱3,288.00</span>
          </div>
          <div className="p-3 bg-emerald-50 dark:bg-emerald-950/30 rounded-xl">
            <span className="text-[10px] font-bold text-emerald-700 dark:text-emerald-400 uppercase tracking-wider block mb-1">Annual Projected</span>
            <span className="text-lg font-black text-emerald-800 dark:text-emerald-300">₱44,246.00</span>
          </div>
        </div>
        <div className="relative mb-3">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#7A6E63] dark:text-[#A89A8D]" />
          <input
            type="text"
            placeholder="Search subscriptions..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-8 pr-3 py-2 bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] rounded-xl text-xs focus:outline-none focus:border-[#B03C09]"
          />
        </div>
        
        <div className="space-y-2">
          {subscriptions.map(sub => (
            <div key={sub.id} className="flex flex-col gap-2 p-3 bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] rounded-xl">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-white dark:bg-[#27201A] flex items-center justify-center shrink-0">
                    <RotateCcw size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">{sub.name}</h4>
                    <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">Renews {sub.nextBilling}</span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">{formatPeso(sub.amount)}</span>
                  <span className="text-[10px] font-semibold text-[#B03C09] dark:text-[#FF9A52]">{sub.cycle}</span>
                </div>
              </div>
              
              {(sub.unusedAlert || sub.duplicateAlert || sub.status === 'trial') && (
                <div className="flex flex-wrap gap-1 mt-1">
                  {sub.unusedAlert && (
                    <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-amber-100 dark:bg-amber-900/40 text-amber-800 dark:text-amber-300 text-[9px] font-bold">
                      <AlertTriangle size={10} /> Rarely Used
                    </span>
                  )}
                  {sub.duplicateAlert && (
                    <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-rose-100 dark:bg-rose-900/40 text-rose-800 dark:text-rose-300 text-[9px] font-bold">
                      <CreditCard size={10} /> Duplicate Detected
                    </span>
                  )}
                  {sub.status === 'trial' && (
                    <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-blue-100 dark:bg-blue-900/40 text-blue-800 dark:text-blue-300 text-[9px] font-bold">
                      <Calendar size={10} /> Trial Ends {sub.trialEnds}
                    </span>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
