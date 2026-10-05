import React, { useState, useMemo } from 'react';
import {
  ChevronRight,
  Zap,
  Music,
  CalendarCheck,
  CreditCard,
  Info,
  CheckCircle2,
  Building,
  Home,
  User,
  Briefcase,
  Layers,
  Clock,
  Plus,
  ArrowDownLeft,
  ArrowUpRight,
  TrendingUp,
  TrendingDown,
  Sparkles,
  Calendar,
  Filter,
  DollarSign,
  AlertCircle,
  ShieldCheck,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { SectionInfoModal } from './SectionInfoModal';
import { ProfileEntity, UpcomingItem } from '../types';

interface ComingUpCardProps {
  onSeeAll: () => void;
  onOpenBills?: () => void;
}

export const ComingUpCard: React.FC<ComingUpCardProps> = ({ onSeeAll, onOpenBills }) => {
  const {
    upcoming,
    activeProfile,
    setActiveProfile,
    markUpcomingPaid,
    payday,
  } = useFinancial();

  const [showInfo, setShowInfo] = useState(false);
  const [selectedProfileTab, setSelectedProfileTab] = useState<ProfileEntity | 'all'>(
    activeProfile || 'all'
  );
  const [movementFilter, setMovementFilter] = useState<'all' | 'outflow' | 'inflow'>('all');
  const [paidToastItem, setPaidToastItem] = useState<string | null>(null);

  // Sync selected tab if activeProfile from global header changes
  React.useEffect(() => {
    setSelectedProfileTab(activeProfile);
  }, [activeProfile]);

  const handleAction = onOpenBills || onSeeAll;

  // Infer or get profile for an upcoming item
  const getItemProfile = (item: UpcomingItem): ProfileEntity => {
    const nameLower = item.name.toLowerCase();
    const catLower = (item.category || '').toLowerCase();

    if (
      nameLower.includes('bir') ||
      nameLower.includes('tax') ||
      nameLower.includes('payroll') ||
      nameLower.includes('freelance') ||
      nameLower.includes('business') ||
      nameLower.includes('client') ||
      nameLower.includes('vendor') ||
      nameLower.includes('dti') ||
      nameLower.includes('sec') ||
      catLower.includes('business')
    ) {
      return 'business';
    }

    if (
      nameLower.includes('meralco') ||
      nameLower.includes('maynilad') ||
      nameLower.includes('manila water') ||
      nameLower.includes('water') ||
      nameLower.includes('electric') ||
      nameLower.includes('converge') ||
      nameLower.includes('pldt') ||
      nameLower.includes('rent') ||
      nameLower.includes('hoa') ||
      nameLower.includes('condo') ||
      nameLower.includes('household') ||
      nameLower.includes('groceries') ||
      catLower.includes('household') ||
      catLower.includes('utility')
    ) {
      return 'household';
    }

    return 'personal';
  };

  // Get icon and theme based on item type and name
  const getItemVisuals = (item: UpcomingItem) => {
    const isIncome = item.isIncome || item.type === 'payday';
    const nameLower = item.name.toLowerCase();

    if (isIncome) {
      return {
        Icon: CalendarCheck,
        bgClass: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/20',
      };
    }
    if (nameLower.includes('spotify') || nameLower.includes('netflix') || item.type === 'subscription') {
      return {
        Icon: Music,
        bgClass: 'bg-purple-500/15 text-purple-700 dark:text-purple-300 border-purple-500/20',
      };
    }
    if (
      nameLower.includes('meralco') ||
      nameLower.includes('electric') ||
      nameLower.includes('water') ||
      nameLower.includes('pldt') ||
      nameLower.includes('converge') ||
      nameLower.includes('internet') ||
      item.type === 'bill'
    ) {
      return {
        Icon: Zap,
        bgClass: 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/20',
      };
    }
    if (nameLower.includes('rent') || nameLower.includes('condo') || item.type === 'rent') {
      return {
        Icon: Building,
        bgClass: 'bg-orange-500/15 text-orange-700 dark:text-orange-300 border-orange-500/20',
      };
    }
    if (item.type === 'debt' || nameLower.includes('loan') || nameLower.includes('spaylater') || nameLower.includes('card')) {
      return {
        Icon: CreditCard,
        bgClass: 'bg-rose-500/15 text-rose-700 dark:text-rose-300 border-rose-500/20',
      };
    }
    return {
      Icon: CreditCard,
      bgClass: 'bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] border-[#F0D5C0] dark:border-[#383029]',
    };
  };

  // Profile-filtered items
  const profileUpcoming = useMemo(() => {
    return upcoming.filter((item) => {
      if (item.isPaid) return false;
      if (selectedProfileTab === 'all') return true;
      const profile = getItemProfile(item);
      return profile === selectedProfileTab;
    });
  }, [upcoming, selectedProfileTab]);

  // Aggregate stats across profile selection
  const totalOutflows = useMemo(() => {
    return profileUpcoming
      .filter((i) => !i.isIncome && i.type !== 'payday')
      .reduce((sum, i) => sum + i.amount, 0);
  }, [profileUpcoming]);

  const totalInflows = useMemo(() => {
    return profileUpcoming
      .filter((i) => i.isIncome || i.type === 'payday')
      .reduce((sum, i) => sum + i.amount, 0);
  }, [profileUpcoming]);

  const netMovement = useMemo(() => {
    return totalInflows - totalOutflows;
  }, [totalInflows, totalOutflows]);

  // Retention percentage
  const retentionRatio = useMemo(() => {
    if (totalInflows <= 0) return 0;
    return Math.max(0, Math.min(100, Math.round((netMovement / totalInflows) * 100)));
  }, [totalInflows, netMovement]);

  const outflowRatio = useMemo(() => {
    if (totalInflows <= 0) return totalOutflows > 0 ? 100 : 0;
    return Math.min(100, Math.round((totalOutflows / totalInflows) * 100));
  }, [totalInflows, totalOutflows]);

  // Displayed items based on movement filter (all / outflow / inflow)
  const displayedUpcoming = useMemo(() => {
    return profileUpcoming.filter((item) => {
      const isIncome = item.isIncome || item.type === 'payday';
      if (movementFilter === 'outflow') return !isIncome;
      if (movementFilter === 'inflow') return isIncome;
      return true;
    });
  }, [profileUpcoming, movementFilter]);

  const handleMarkPaid = (e: React.MouseEvent, itemId: string, itemName: string) => {
    e.stopPropagation();
    markUpcomingPaid(itemId);
    setPaidToastItem(itemName);
    setTimeout(() => {
      setPaidToastItem(null);
    }, 2200);
  };

  return (
    <>
      <section
        id="section-coming-up-obligations"
        className="flex flex-col gap-3 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] p-4 sm:p-5 shadow-xs transition-all"
      >
        {/* 1. Header with Sweldo Cadence & Info Trigger */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="w-9 h-9 rounded-2xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 shadow-xs">
              <Clock size={18} />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 flex-wrap">
                <h2 className="text-sm sm:text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] truncate">
                  Coming Up
                </h2>
                <button
                  type="button"
                  id="upcoming-info-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    setShowInfo(true);
                  }}
                  className="inline-flex items-center justify-center w-5 h-5 rounded-full text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C] transition-colors cursor-pointer shrink-0"
                  title="How cash horizon & upcoming obligations protect Safe to Spend"
                  aria-label="Upcoming bills info"
                >
                  <Info size={13} strokeWidth={2.2} />
                </button>
              </div>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] truncate">
                Expected bills &amp; income before next payday
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              id="manage-bills-link-btn"
              onClick={handleAction}
              className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline flex items-center gap-0.5 cursor-pointer"
            >
              <span>Manage</span>
              <ChevronRight size={14} />
            </button>
          </div>
        </div>

        {/* 2. Profile Segmented Selector (Applies to all profiles) */}
        <div className="flex items-center gap-1.5 p-1 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0]/60 dark:border-[#383029] overflow-x-auto scrollbar-none">
          {(
            [
              { id: 'all', label: 'All Profiles', icon: Layers },
              { id: 'personal', label: 'Personal', icon: User },
              { id: 'household', label: 'Household', icon: Home },
              { id: 'business', label: 'Business', icon: Briefcase },
            ] as const
          ).map((tab) => {
            const isSelected = selectedProfileTab === tab.id;
            const TabIcon = tab.icon;
            const count = upcoming.filter((item) => {
              if (item.isPaid) return false;
              if (tab.id === 'all') return true;
              return getItemProfile(item) === tab.id;
            }).length;

            return (
              <button
                key={tab.id}
                type="button"
                id={`upcoming-profile-filter-${tab.id}`}
                onClick={() => setSelectedProfileTab(tab.id)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                    : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
                }`}
              >
                <TabIcon size={12} />
                <span>{tab.label}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${
                    isSelected
                      ? 'bg-white/20 text-white dark:bg-black/20 dark:text-[#14100D]'
                      : 'bg-[#FFEEDF] dark:bg-[#2A221C] text-[#7A6E63] dark:text-[#A89A8D]'
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        {/* 3. Cohesive Cash Movement & Net Flow Tri-Card Banner */}
        <div className="p-3.5 sm:p-4 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/70 border border-[#F0D5C0]/70 dark:border-[#383029] flex flex-col gap-3">
          {/* Sweldo Countdown Line */}
          <div className="flex items-center justify-between gap-2 text-xs border-b border-[#F0D5C0]/50 dark:border-[#383029]/60 pb-2.5">
            <div className="flex items-center gap-1.5 min-w-0">
              <Calendar size={13} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                Next Payday: {payday.nextPayday}
              </span>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 text-[#B03C09] dark:text-[#FF9A52] font-extrabold shrink-0">
                {payday.daysToPayday} {payday.daysToPayday === 1 ? 'day' : 'days'} away
              </span>
            </div>
            <span className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] shrink-0 hidden sm:inline">
              Safe to Spend horizon
            </span>
          </div>

          {/* Tri-Column Metrics: Inflow, Outflow, Net Movement */}
          <div className="grid grid-cols-3 gap-2 text-left">
            {/* Total Inflow */}
            <div
              onClick={() => setMovementFilter(movementFilter === 'inflow' ? 'all' : 'inflow')}
              className={`p-2 sm:p-2.5 rounded-xl border transition-all cursor-pointer flex flex-col justify-between ${
                movementFilter === 'inflow'
                  ? 'bg-emerald-500/15 border-emerald-500/40'
                  : 'bg-white/60 dark:bg-[#1E1915]/60 border-[#F0D5C0]/40 dark:border-[#383029]/40 hover:border-emerald-500/30'
              }`}
            >
              <div className="flex items-center gap-1 text-[10px] sm:text-xs font-semibold text-emerald-800 dark:text-emerald-300">
                <ArrowDownLeft size={12} className="shrink-0" />
                <span className="truncate">Income</span>
              </div>
              <div className="text-xs sm:text-sm font-extrabold text-emerald-700 dark:text-emerald-400 tabular-nums truncate mt-1">
                {totalInflows > 0 ? `+${formatPeso(totalInflows)}` : '₱0.00'}
              </div>
            </div>

            {/* Total Outflow */}
            <div
              onClick={() => setMovementFilter(movementFilter === 'outflow' ? 'all' : 'outflow')}
              className={`p-2 sm:p-2.5 rounded-xl border transition-all cursor-pointer flex flex-col justify-between ${
                movementFilter === 'outflow'
                  ? 'bg-rose-500/15 border-rose-500/40'
                  : 'bg-white/60 dark:bg-[#1E1915]/60 border-[#F0D5C0]/40 dark:border-[#383029]/40 hover:border-rose-500/30'
              }`}
            >
              <div className="flex items-center gap-1 text-[10px] sm:text-xs font-semibold text-rose-800 dark:text-rose-300">
                <ArrowUpRight size={12} className="shrink-0" />
                <span className="truncate">Reserved</span>
              </div>
              <div className="text-xs sm:text-sm font-extrabold text-rose-600 dark:text-rose-400 tabular-nums truncate mt-1">
                {totalOutflows > 0 ? formatPeso(totalOutflows) : '₱0.00'}
              </div>
            </div>

            {/* Net Movement / Free Surplus */}
            <div
              onClick={() => setMovementFilter('all')}
              className={`p-2 sm:p-2.5 rounded-xl border transition-all cursor-pointer flex flex-col justify-between ${
                movementFilter === 'all'
                  ? 'bg-[#FFEEDF] dark:bg-[#2A221C] border-[#B03C09]/40 dark:border-[#FF9A52]/40'
                  : 'bg-white/60 dark:bg-[#1E1915]/60 border-[#F0D5C0]/40 dark:border-[#383029]/40'
              }`}
            >
              <div className="flex items-center gap-1 text-[10px] sm:text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                {netMovement >= 0 ? (
                  <TrendingUp size={12} className="text-emerald-600 dark:text-emerald-400 shrink-0" />
                ) : (
                  <TrendingDown size={12} className="text-rose-600 dark:text-rose-400 shrink-0" />
                )}
                <span className="truncate">Remaining</span>
              </div>
              <div
                className={`text-xs sm:text-sm font-extrabold tabular-nums truncate mt-1 ${
                  netMovement >= 0
                    ? 'text-[#16643F] dark:text-[#5FCB8E]'
                    : 'text-rose-600 dark:text-rose-400'
                }`}
              >
                {netMovement >= 0 ? `+${formatPeso(netMovement)}` : formatPeso(netMovement)}
              </div>
            </div>
          </div>

          {/* Proportional Sweldo Retention Gauge */}
          {totalInflows > 0 && (
            <div className="space-y-1 pt-1">
              <div className="flex justify-between items-center text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                <span>
                  <strong>{outflowRatio}%</strong> committed to upcoming bills
                </span>
                <span>
                  <strong>{retentionRatio}%</strong> retained for Safe to Spend
                </span>
              </div>
              <div className="w-full h-2 rounded-full bg-[#F0D5C0]/60 dark:bg-[#383029] overflow-hidden flex">
                <div
                  className="h-full bg-rose-500/80 dark:bg-rose-400/80 transition-all duration-300"
                  style={{ width: `${outflowRatio}%` }}
                  title={`Bills reserved: ${formatPeso(totalOutflows)}`}
                />
                <div
                  className="h-full bg-emerald-500/80 dark:bg-emerald-400/80 transition-all duration-300"
                  style={{ width: `${retentionRatio}%` }}
                  title={`Retained surplus: ${formatPeso(netMovement)}`}
                />
              </div>
            </div>
          )}
        </div>

        {/* Paid Toast Confirmation */}
        {paidToastItem && (
          <div className="p-2.5 rounded-xl bg-emerald-500/15 border border-emerald-500/20 text-emerald-800 dark:text-emerald-300 text-xs font-bold flex items-center gap-2 animate-in fade-in duration-200">
            <CheckCircle2 size={15} />
            <span>Marked "{paidToastItem}" as settled &amp; paid!</span>
          </div>
        )}

        {/* 4. Filter Bar (All / Outflow / Inflow) */}
        {profileUpcoming.length > 0 && (
          <div className="flex items-center justify-between px-1 text-xs">
            <span className="text-[#7A6E63] dark:text-[#A89A8D] font-medium text-[11px]">
              Showing {displayedUpcoming.length} of {profileUpcoming.length} items
            </span>
            <div className="flex items-center gap-1">
              {(
                [
                  { id: 'all', label: 'All' },
                  { id: 'outflow', label: 'Outflows' },
                  { id: 'inflow', label: 'Inflows' },
                ] as const
              ).map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => setMovementFilter(f.id)}
                  className={`px-2 py-0.5 rounded-lg text-[10px] font-bold cursor-pointer transition-colors ${
                    movementFilter === f.id
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]'
                      : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C]'
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* 5. Commitments List */}
        {displayedUpcoming.length === 0 ? (
          <div className="p-6 rounded-2xl bg-[#FFEEDF]/20 dark:bg-[#14100D]/30 border border-dashed border-[#F0D5C0] dark:border-[#383029] text-center flex flex-col items-center justify-center gap-2.5">
            <div className="w-10 h-10 rounded-2xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center">
              <Sparkles size={18} />
            </div>
            <div className="max-w-xs">
              <p className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                {movementFilter === 'inflow'
                  ? 'No expected income'
                  : movementFilter === 'outflow'
                  ? 'No reserved bills'
                  : 'No upcoming items for this profile'}
              </p>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5">
                Your Safe to Spend is protected until next payday.
              </p>
            </div>
            <button
              type="button"
              onClick={handleAction}
              className="mt-1 px-3.5 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] flex items-center gap-1.5 hover:opacity-90 cursor-pointer shadow-xs"
            >
              <Plus size={13} />
              <span>Add Item</span>
            </button>
          </div>
        ) : (
          <div className="rounded-2xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#1E1915] divide-y divide-[#F0D5C0]/60 dark:divide-[#383029] overflow-hidden shadow-xs">
            {displayedUpcoming.slice(0, 5).map((item) => {
              const { Icon, bgClass } = getItemVisuals(item);
              const isIncome = item.isIncome || item.type === 'payday';
              const profile = getItemProfile(item);

              return (
                <div
                  key={item.id}
                  id={`upcoming-item-${item.id}`}
                  onClick={handleAction}
                  className="flex items-center justify-between p-3 sm:p-3.5 hover:bg-[#FFEEDF]/25 dark:hover:bg-[#14100D]/40 transition-colors cursor-pointer gap-2.5 group"
                >
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 border ${bgClass}`}
                    >
                      <Icon size={17} />
                    </div>
                    <div className="flex flex-col min-w-0 flex-1">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {item.name}
                        </span>
                        {/* Profile Chip Indicator */}
                        <span
                          className={`text-[9px] font-extrabold px-1.5 py-0.2 rounded-md uppercase tracking-wider ${
                            profile === 'business'
                              ? 'bg-amber-500/15 text-amber-800 dark:text-amber-300'
                              : profile === 'household'
                              ? 'bg-teal-500/15 text-teal-800 dark:text-teal-300'
                              : 'bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52]'
                          }`}
                        >
                          {profile}
                        </span>
                      </div>
                      <div className="flex items-center gap-1.5 text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5">
                        <span className="font-medium text-[#15120F] dark:text-[#F6EFE8]">{item.dueDate}</span>
                        {item.category && (
                          <>
                            <span>•</span>
                            <span className="truncate">{item.category}</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Right side: Amount & Quick Mark Paid Button */}
                  <div className="flex items-center gap-2.5 shrink-0">
                    <span
                      className={`text-xs sm:text-sm font-extrabold text-right tabular-nums whitespace-nowrap ${
                        isIncome
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#15120F] dark:text-[#F6EFE8]'
                      }`}
                    >
                      {isIncome ? `+${formatPeso(item.amount)}` : formatPeso(item.amount)}
                    </span>

                    {!isIncome && (
                      <button
                        type="button"
                        id={`mark-paid-${item.id}`}
                        onClick={(e) => handleMarkPaid(e, item.id, item.name)}
                        title="Mark as paid"
                        className="w-7 h-7 rounded-lg bg-[#FFEEDF] dark:bg-[#2A221C] text-[#7A6E63] dark:text-[#A89A8D] hover:bg-emerald-500/20 hover:text-emerald-700 dark:hover:text-emerald-300 flex items-center justify-center transition-all cursor-pointer opacity-80 group-hover:opacity-100"
                      >
                        <CheckCircle2 size={14} />
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      <SectionInfoModal topic={showInfo ? 'upcoming' : null} onClose={() => setShowInfo(false)} />
    </>
  );
};
