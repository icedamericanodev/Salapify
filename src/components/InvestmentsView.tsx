import React, { useState, useMemo } from 'react';
import {
  TrendingUp,
  TrendingDown,
  PieChart,
  ShieldCheck,
  AlertCircle,
  Plus,
  RefreshCw,
  Layers,
  ArrowUpRight,
  ArrowDownLeft,
  Calendar,
  Info,
  ChevronRight,
  Check,
  X,
  Trash2,
  Sliders,
  DollarSign,
  Activity,
  Award
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import {
  InvestmentAsset,
  InvestmentAssetClass,
  InvestmentRiskProfile,
  InvestmentTxType
} from '../types';
import { ASSET_CLASS_METADATA } from '../data/initialInvestments';
import { PROVIDER_ADAPTERS } from '../utils/investmentProviders';

interface InvestmentsViewProps {
  onBack?: () => void;
  onOpenLedger?: () => void;
}

export const InvestmentsView: React.FC<InvestmentsViewProps> = ({
  onBack,
  onOpenLedger,
}) => {
  const {
    investments,
    portfolioSummary,
    accounts,
    addInvestmentAsset,
    updateInvestmentAsset,
    deleteInvestmentAsset,
    recordInvestmentActivity,
    updateAssetValuation,
    netWorth,
  } = useFinancial();

  const [selectedAssetClass, setSelectedAssetClass] = useState<string>('all');
  const [selectedRiskProfile, setSelectedRiskProfile] = useState<string>('all');
  const [activeTab, setActiveTab] = useState<'holdings' | 'allocation' | 'providers' | 'principles'>('holdings');

  // Modal states
  const [isAddAssetOpen, setIsAddAssetOpen] = useState(false);
  const [activityAsset, setActivityAsset] = useState<InvestmentAsset | null>(null);
  const [activityType, setActivityType] = useState<InvestmentTxType>('contribution');
  const [activityAmount, setActivityAmount] = useState('');
  const [activityUnits, setActivityUnits] = useState('');
  const [activityPrice, setActivityPrice] = useState('');
  const [activityAccountId, setActivityAccountId] = useState('');
  const [activityNote, setActivityNote] = useState('');

  // Valuation Update Modal state
  const [valuationAsset, setValuationAsset] = useState<InvestmentAsset | null>(null);
  const [newValuationPrice, setNewValuationPrice] = useState('');

  // New Asset Form state
  const [newName, setNewName] = useState('');
  const [newSymbol, setNewSymbol] = useState('');
  const [newAssetClass, setNewAssetClass] = useState<InvestmentAssetClass>('mp2');
  const [newRisk, setNewRisk] = useState<InvestmentRiskProfile>('conservative');
  const [newPlatform, setNewPlatform] = useState('Virtual Pag-IBIG');
  const [fundingAccountId, setFundingAccountId] = useState('');
  const [newUnits, setNewUnits] = useState('1');
  const [newCostBasis, setNewCostBasis] = useState('');
  const [newPricePerUnit, setNewPricePerUnit] = useState('');
  const [newCurrency, setNewCurrency] = useState<'PHP' | 'USD'>('PHP');
  const [newMaturityDate, setNewMaturityDate] = useState('');
  const [newNotes, setNewNotes] = useState('');

  // Filtered Assets
  const filteredAssets = useMemo(() => {
    return investments.filter((a) => {
      if (selectedAssetClass !== 'all' && a.assetClass !== selectedAssetClass) {
        return false;
      }
      if (selectedRiskProfile !== 'all' && a.riskProfile !== selectedRiskProfile) {
        return false;
      }
      return true;
    });
  }, [investments, selectedAssetClass, selectedRiskProfile]);

  const handleCreateAsset = (e: React.FormEvent) => {
    e.preventDefault();
    const costBasisNum = parseFloat(newCostBasis) || 0;
    const unitsNum = parseFloat(newUnits) || 1;
    const priceNum = parseFloat(newPricePerUnit) || (unitsNum > 0 ? costBasisNum / unitsNum : 1);

    addInvestmentAsset({
      name: newName.trim() || 'Untitled Investment',
      symbolOrTicker: newSymbol.trim() || undefined,
      assetClass: newAssetClass,
      riskProfile: newRisk,
      institutionOrPlatform: newPlatform.trim() || 'Direct Ledger',
      units: unitsNum,
      averageCostPerUnit: unitsNum > 0 ? costBasisNum / unitsNum : priceNum,
      currentPricePerUnit: priceNum,
      costBasis: costBasisNum,
      currentValuation: unitsNum * priceNum,
      currency: newCurrency,
      maturityDate: newMaturityDate.trim() || undefined,
      notes: newNotes.trim() || undefined,
      dataProvider: 'manual'
      , totalDividendsEarned: 0, totalContributions: costBasisNum, totalWithdrawals: 0
    }, fundingAccountId);

    // Reset Form
    setNewName('');
    setNewSymbol('');
    setNewCostBasis('');
    setNewPricePerUnit('');
    setNewUnits('1');
    setNewMaturityDate('');
    setNewNotes('');
    setIsAddAssetOpen(false);
  };

  const handleRecordActivitySubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!activityAsset) return;
    const amountNum = parseFloat(activityAmount);
    if (isNaN(amountNum) || amountNum <= 0) return;

    const unitsNum = activityUnits ? parseFloat(activityUnits) : undefined;
    const priceNum = activityPrice ? parseFloat(activityPrice) : undefined;

    recordInvestmentActivity(activityAsset.id, {
      type: activityType,
      amount: amountNum,
      units: unitsNum,
      pricePerUnit: priceNum,
      note: activityNote.trim() || undefined,
      accountId: activityAccountId || undefined,
    });

    setActivityAsset(null);
    setActivityAmount('');
    setActivityUnits('');
    setActivityPrice('');
    setActivityNote('');
    setActivityAccountId('');
  };

  const handleValuationSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!valuationAsset) return;
    const price = parseFloat(newValuationPrice);
    if (isNaN(price) || price < 0) return;

    updateAssetValuation(valuationAsset.id, price);
    setValuationAsset(null);
    setNewValuationPrice('');
  };

  return (
    <div className="flex flex-col gap-4 pb-24">
      {/* Header & Principle Banner */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            {onBack && (
              <button
                type="button"
                onClick={onBack}
                className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
              >
                ← Back
              </button>
            )}
            <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Investment Portfolio
            </h2>
          </div>
          <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
            Start with tracking, not trading. Long-term wealth preservation.
          </p>
        </div>

        <button
          type="button"
          onClick={() => setIsAddAssetOpen(true)}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] text-xs font-bold shadow-xs hover:opacity-95 transition-all cursor-pointer"
        >
          <Plus size={14} strokeWidth={2.4} />
          <span>Add Asset</span>
        </button>
      </div>

      {/* Core Portfolio Summary KPI Card */}
      <div className="p-4 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
            Total Invested Valuation
          </span>
          <span className="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52]">
            {portfolioSummary.investmentToNetWorthRatio.toFixed(1)}% of Net Worth
          </span>
        </div>

        <div className="flex items-baseline justify-between">
          <div>
            <div className="text-2xl font-black text-[#15120F] dark:text-[#F6EFE8]">
              {formatPeso(portfolioSummary.totalValuation)}
            </div>
            <div className="text-xs text-[#6B6156] dark:text-[#AC9E92] mt-0.5">
              Cost Basis: <span className="font-semibold">{formatPeso(portfolioSummary.totalCostBasis)}</span>
            </div>
          </div>

          <div className="text-right">
            <div
              className={`flex items-center justify-end gap-1 text-sm font-black ${
                portfolioSummary.totalUnrealizedGainLoss >= 0
                  ? 'text-emerald-600 dark:text-emerald-400'
                  : 'text-rose-600 dark:text-rose-400'
              }`}
            >
              {portfolioSummary.totalUnrealizedGainLoss >= 0 ? (
                <TrendingUp size={16} />
              ) : (
                <TrendingDown size={16} />
              )}
              <span>
                {portfolioSummary.totalUnrealizedGainLoss >= 0 ? '+' : ''}
                {formatPeso(portfolioSummary.totalUnrealizedGainLoss)}
              </span>
            </div>
            <div
              className={`text-xs font-bold ${
                portfolioSummary.totalUnrealizedGainLossPercent >= 0
                  ? 'text-emerald-600 dark:text-emerald-400'
                  : 'text-rose-600 dark:text-rose-400'
              }`}
            >
              {portfolioSummary.totalUnrealizedGainLossPercent >= 0 ? '+' : ''}
              {portfolioSummary.totalUnrealizedGainLossPercent.toFixed(2)}%
            </div>
          </div>
        </div>

        {/* 3 Metric Badges */}
        <div className="grid grid-cols-3 gap-2 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
          <div className="p-2 rounded-xl bg-[#FFEEDF]/50 dark:bg-[#14100D]/50 border border-[#F3DFCD]/40 dark:border-[#383029]/40 text-center">
            <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
              Dividends Earned
            </span>
            <span className="text-xs font-bold text-emerald-600 dark:text-emerald-400">
              +{formatPeso(portfolioSummary.totalDividendsEarned)}
            </span>
          </div>

          <div className="p-2 rounded-xl bg-[#FFEEDF]/50 dark:bg-[#14100D]/50 border border-[#F3DFCD]/40 dark:border-[#383029]/40 text-center">
            <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
              Total Contributions
            </span>
            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
              {formatPeso(portfolioSummary.totalContributions)}
            </span>
          </div>

          <div className="p-2 rounded-xl bg-[#FFEEDF]/50 dark:bg-[#14100D]/50 border border-[#F3DFCD]/40 dark:border-[#383029]/40 text-center">
            <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
              Total Redemptions
            </span>
            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
              {formatPeso(portfolioSummary.totalWithdrawals)}
            </span>
          </div>
        </div>
      </div>

      {/* Sub-navigation Tabs */}
      <div className="flex rounded-xl bg-[#FFEEDF]/80 dark:bg-[#1E1915] p-1 border border-[#F0D5C0] dark:border-[#383029]">
        {[
          { id: 'holdings', label: 'Holdings', count: investments.length },
          { id: 'allocation', label: 'Asset Allocation' },
          { id: 'providers', label: 'Data Adapters' },
          { id: 'principles', label: 'PH Principles' },
        ].map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setActiveTab(tab.id as any)}
            className={`flex-1 py-1.5 px-2 rounded-lg text-xs font-bold transition-all cursor-pointer text-center ${
              activeTab === tab.id
                ? 'bg-white dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
            }`}
          >
            {tab.label} {tab.count !== undefined ? `(${tab.count})` : ''}
          </button>
        ))}
      </div>

      {/* TAB 1: HOLDINGS LIST */}
      {activeTab === 'holdings' && (
        <div className="space-y-3">
          {/* Filter Pills */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar text-xs">
            <button
              type="button"
              onClick={() => setSelectedAssetClass('all')}
              className={`px-2.5 py-1 rounded-full whitespace-nowrap font-semibold cursor-pointer transition-all ${
                selectedAssetClass === 'all'
                  ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]'
                  : 'bg-white dark:bg-[#1E1915] text-[#6B6156] dark:text-[#AC9E92] border border-[#F0D5C0] dark:border-[#383029]'
              }`}
            >
              All Classes ({investments.length})
            </button>
            {Object.keys(ASSET_CLASS_METADATA).map((key) => {
              const meta = ASSET_CLASS_METADATA[key as InvestmentAssetClass];
              const count = investments.filter((a) => a.assetClass === key).length;
              if (count === 0) return null;
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => setSelectedAssetClass(key)}
                  className={`px-2.5 py-1 rounded-full whitespace-nowrap font-semibold cursor-pointer transition-all flex items-center gap-1 ${
                    selectedAssetClass === key
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]'
                      : 'bg-white dark:bg-[#1E1915] text-[#6B6156] dark:text-[#AC9E92] border border-[#F0D5C0] dark:border-[#383029]'
                  }`}
                >
                  <span>{meta.emoji}</span>
                  <span>{meta.label} ({count})</span>
                </button>
              );
            })}
          </div>

          {/* Holdings Cards */}
          {filteredAssets.length === 0 ? (
            <div className="p-8 text-center rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] space-y-2">
              <p className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                No investments found in this category
              </p>
              <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                Track stocks, Pag-IBIG MP2, high-yield time deposits, mutual funds, and crypto without vendor lock-in.
              </p>
              <button
                type="button"
                onClick={() => setIsAddAssetOpen(true)}
                className="mt-2 px-3 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold cursor-pointer"
              >
                + Add First Asset
              </button>
            </div>
          ) : (
            filteredAssets.map((asset) => {
              const meta = ASSET_CLASS_METADATA[asset.assetClass] || {
                label: asset.assetClass,
                color: '#B03C09',
                emoji: '📈',
                description: ''
              };

              return (
                <div
                  key={asset.id}
                  className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-3"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-start gap-2.5">
                      <div className="w-9 h-9 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] flex items-center justify-center text-base shrink-0">
                        {meta.emoji}
                      </div>
                      <div>
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                            {asset.name}
                          </h4>
                          {asset.symbolOrTicker && (
                            <span className="text-[10px] font-bold px-1.5 py-0.2 rounded bg-[#FFEEDF]/60 dark:bg-[#2A221C]/60 text-[#6B6156] dark:text-[#AC9E92]">
                              {asset.symbolOrTicker}
                            </span>
                          )}
                          <span
                            className={`text-[9px] font-bold px-1.5 py-0.2 rounded ${
                              asset.riskProfile === 'conservative'
                                ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                                : asset.riskProfile === 'moderate'
                                ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                                : 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                            }`}
                          >
                            {asset.riskProfile.toUpperCase()}
                          </span>
                        </div>
                        <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                          {asset.institutionOrPlatform} • {meta.label}
                        </p>
                      </div>
                    </div>

                    <div className="text-right shrink-0">
                      <div className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(asset.currentValuation)}
                      </div>
                      <div
                        className={`text-[11px] font-bold ${
                          asset.unrealizedGainLoss >= 0
                            ? 'text-emerald-600 dark:text-emerald-400'
                            : 'text-rose-600 dark:text-rose-400'
                        }`}
                      >
                        {asset.unrealizedGainLoss >= 0 ? '+' : ''}
                        {formatPeso(asset.unrealizedGainLoss)} (
                        {asset.unrealizedGainLossPercent.toFixed(1)}%)
                      </div>
                    </div>
                  </div>

                  {/* Units, Cost Basis, & Price Grid */}
                  <div className="grid grid-cols-3 gap-2 py-2 px-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD]/40 dark:border-[#383029]/40 text-xs">
                    <div>
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                        Units / Shares
                      </span>
                      <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                        {asset.units.toLocaleString('en-US', { maximumFractionDigits: 4 })}
                      </span>
                    </div>

                    <div>
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                        Cost Basis
                      </span>
                      <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(asset.costBasis)}
                      </span>
                    </div>

                    <div>
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                        Unit Price
                      </span>
                      <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(asset.currentPricePerUnit)}
                      </span>
                    </div>
                  </div>

                  {/* Dividends & Maturity Tag */}
                  {(asset.totalDividendsEarned > 0 || asset.maturityDate) && (
                    <div className="flex items-center justify-between text-[11px] text-[#6B6156] dark:text-[#AC9E92] px-1">
                      {asset.totalDividendsEarned > 0 && (
                        <span className="text-emerald-600 dark:text-emerald-400 font-semibold">
                          Earned Dividends: +{formatPeso(asset.totalDividendsEarned)}
                        </span>
                      )}
                      {asset.maturityDate && (
                        <span>Maturity: {asset.maturityDate}</span>
                      )}
                    </div>
                  )}

                  {/* Action Buttons */}
                  <div className="flex items-center justify-between pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => {
                          setActivityAsset(asset);
                          setActivityType('contribution');
                          setActivityAmount('');
                          setActivityUnits('');
                        }}
                        className="px-2.5 py-1 rounded-lg bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] text-[11px] font-bold hover:opacity-90 cursor-pointer"
                      >
                        + Contribute / Buy
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setActivityAsset(asset);
                          setActivityType('dividend');
                          setActivityAmount('');
                          setActivityUnits('');
                        }}
                        className="px-2.5 py-1 rounded-lg bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 text-[11px] font-bold hover:opacity-90 cursor-pointer"
                      >
                        + Dividend
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setValuationAsset(asset);
                          setNewValuationPrice(asset.currentPricePerUnit.toString());
                        }}
                        className="px-2.5 py-1 rounded-lg bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-[#6B6156] dark:text-[#AC9E92] text-[11px] font-semibold hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                      >
                        Update Value
                      </button>
                    </div>

                    <button
                      type="button"
                      onClick={() => {
                        if (confirm(`Remove ${asset.name} from investment tracking?`)) {
                          deleteInvestmentAsset(asset.id);
                        }
                      }}
                      className="p-1.5 text-[#6B6156] dark:text-[#AC9E92] hover:text-rose-600 dark:hover:text-rose-400 transition-colors cursor-pointer"
                      title="Delete asset"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* TAB 2: ASSET ALLOCATION & RISK BREAKDOWN */}
      {activeTab === 'allocation' && (
        <div className="space-y-4">
          {/* Visual Asset Allocation Bar */}
          <div className="p-4 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
              Asset Class Allocation
            </h3>

            {/* Proportion Bar */}
            <div className="h-3.5 w-full rounded-full bg-[#FFEEDF] dark:bg-[#2A221C] overflow-hidden flex">
              {portfolioSummary.assetAllocation.map((item, index) => (
                <div
                  key={item.assetClass}
                  style={{
                    width: `${Math.max(1, item.percentage)}%`,
                    backgroundColor: ['#B03C09','#D97706','#059669','#2563EB','#7C3AED'][index % 5],
                  }}
                  title={`${item.label}: ${item.percentage.toFixed(1)}%`}
                  className="h-full transition-all duration-300"
                />
              ))}
            </div>

            {/* Breakdown List */}
            <div className="space-y-2 pt-2">
              {portfolioSummary.assetAllocation.map((item, index) => (
                <div
                  key={item.assetClass}
                  className="flex items-center justify-between text-xs py-1 border-b border-[#F3DFCD]/40 dark:border-[#383029]/40 last:border-0"
                >
                  <div className="flex items-center gap-2">
                    <span
                      className="w-3 h-3 rounded-full"
                      style={{ backgroundColor: ['#B03C09','#D97706','#059669','#2563EB','#7C3AED'][index % 5] }}
                    />
                    <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                      {item.label}
                    </span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-[#6B6156] dark:text-[#AC9E92]">
                      {formatPeso(item.amount)}
                    </span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] w-12 text-right">
                      {item.percentage.toFixed(1)}%
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Risk Exposure Breakdown */}
          <div className="p-4 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
              Risk Profile Exposure
            </h3>

            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="p-3 rounded-xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-900/50">
                <span className="text-[10px] font-bold uppercase text-emerald-800 dark:text-emerald-300 block">
                  Conservative
                </span>
                <span className="text-sm font-black text-emerald-900 dark:text-emerald-200 block mt-1">
                  {(portfolioSummary.riskAllocation.find(r => r.riskProfile === 'conservative')?.percentage || 0).toFixed(1)}%
                </span>
                <span className="text-[10px] text-emerald-700 dark:text-emerald-400 mt-0.5 block">
                  {formatPeso((portfolioSummary.riskAllocation.find(r => r.riskProfile === 'conservative')?.amount || 0))}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-900/50">
                <span className="text-[10px] font-bold uppercase text-amber-800 dark:text-amber-300 block">
                  Moderate
                </span>
                <span className="text-sm font-black text-amber-900 dark:text-amber-200 block mt-1">
                  {(portfolioSummary.riskAllocation.find(r => r.riskProfile === 'moderate')?.percentage || 0).toFixed(1)}%
                </span>
                <span className="text-[10px] text-amber-700 dark:text-amber-400 mt-0.5 block">
                  {formatPeso((portfolioSummary.riskAllocation.find(r => r.riskProfile === 'moderate')?.amount || 0))}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-900/50">
                <span className="text-[10px] font-bold uppercase text-rose-800 dark:text-rose-300 block">
                  Aggressive
                </span>
                <span className="text-sm font-black text-rose-900 dark:text-rose-200 block mt-1">
                  {(portfolioSummary.riskAllocation.find(r => r.riskProfile === 'aggressive')?.percentage || 0).toFixed(1)}%
                </span>
                <span className="text-[10px] text-rose-700 dark:text-rose-400 mt-0.5 block">
                  {formatPeso((portfolioSummary.riskAllocation.find(r => r.riskProfile === 'aggressive')?.amount || 0))}
                </span>
              </div>
            </div>

            <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
              Philippine Investment Invariant: Keep conservative government-backed foundations (MP2, high-yield digital bank time deposits) at 50% or higher before expanding into aggressive equities or volatile crypto assets.
            </p>
          </div>
        </div>
      )}

      {/* TAB 3: DATA PROVIDER ADAPTERS */}
      {activeTab === 'providers' && (
        <div className="p-4 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-4">
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
              Market Data Providers &amp; Adapter Architecture
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mt-0.5">
              Decoupled provider interfaces ensure Salapify's financial ledger is never tied to a single vendor.
            </p>
          </div>

          <div className="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900/50 flex items-start gap-2.5">
            <AlertCircle size={16} className="text-amber-800 dark:text-amber-400 shrink-0 mt-0.5" />
            <div className="text-xs text-amber-900 dark:text-amber-200 space-y-1">
              <span className="font-bold block">Licensing &amp; Public Display Notice</span>
              <p>
                Market data licensing agreements (e.g. Twelve Data, Polygon, CoinGecko Pro) prohibit redistributing real-time ticker feeds publicly without commercial display licenses. Salapify utilizes client-side cached valuation adapters to maintain ledger privacy and zero API key leakage.
              </p>
            </div>
          </div>

          <div className="space-y-2.5">
            {Object.values(PROVIDER_ADAPTERS).map((provider: any) => (
              <div
                key={provider.id}
                className="p-3 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-[#FFEEDF]/30 dark:bg-[#14100D]/40 space-y-1.5"
              >
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {provider.name}
                  </span>
                  <span
                    className={`text-[9px] font-bold px-2 py-0.5 rounded-full ${
                      provider.status === 'production_active'
                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                        : 'bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300'
                    }`}
                  >
                    {provider.status === 'production_active' ? 'ACTIVE DEFAULT' : 'ADAPTER READY'}
                  </span>
                </div>
                <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                  {provider.description}
                </p>
                <div className="flex items-center gap-3 text-[10px] text-[#6B6156] dark:text-[#AC9E92] pt-1">
                  <span>Coverage: <strong>{provider.supportedClasses.join(', ')}</strong></span>
                  <span>•</span>
                  <span>License: <strong>{provider.licensingNote}</strong></span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 4: PHILIPPINE INVESTMENT PRINCIPLES */}
      {activeTab === 'principles' && (
        <div className="p-4 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-3 text-xs leading-relaxed text-[#6B6156] dark:text-[#AC9E92]">
          <h3 className="font-bold text-[#15120F] dark:text-[#F6EFE8] text-sm flex items-center gap-1.5">
            <ShieldCheck size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
            Philippine Wealth Building Invariants
          </h3>

          <div className="space-y-2.5">
            <div className="p-2.5 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/40 border border-[#F3DFCD]/50 dark:border-[#383029]/50">
              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                1. Pag-IBIG MP2 is the Core Anchor
              </span>
              Government-backed, sovereign guarantee with 100% tax-free annual compounded dividends (consistently averaging 6% to 7.5% p.a.). Ideal for 5-year capital.
            </div>

            <div className="p-2.5 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/40 border border-[#F3DFCD]/50 dark:border-[#383029]/50">
              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                2. Digital Bank Time Deposits vs. Withholding Tax
              </span>
              Maya Bank, Tonik, and MariBank offer attractive promotional rates (5% to 6.5% p.a.), but interest earned is subject to 20% final withholding tax. Factor in net yield when comparing to tax-free instruments.
            </div>

            <div className="p-2.5 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/40 border border-[#F3DFCD]/50 dark:border-[#383029]/50">
              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                3. Emergency Fund Before Equities
              </span>
              Never invest in volatile stocks or crypto until you have established 3 to 6 months of living expenses in an accessible high-yield savings account (HYSA).
            </div>
          </div>
        </div>
      )}

      {/* MODAL: ADD NEW INVESTMENT ASSET */}
      <AnimatePresence>
        {isAddAssetOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-md bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] rounded-2xl p-4 shadow-xl max-h-[90vh] overflow-y-auto space-y-3"
            >
              <div className="flex items-center justify-between pb-2 border-b border-[#F3DFCD] dark:border-[#383029]">
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Add Investment Holding
                </h3>
                <button
                  type="button"
                  onClick={() => setIsAddAssetOpen(false)}
                  className="p-1 text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                >
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleCreateAsset} className="space-y-3 text-xs">
                <div>
                  <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    Asset Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g., Pag-IBIG MP2 2026, Ayala Land (ALI), Bitcoin"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Asset Class *
                    </label>
                    <select
                      value={newAssetClass}
                      onChange={(e) => setNewAssetClass(e.target.value as InvestmentAssetClass)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    >
                      {Object.keys(ASSET_CLASS_METADATA).map((key) => (
                        <option key={key} value={key}>
                          {ASSET_CLASS_METADATA[key as InvestmentAssetClass].emoji}{' '}
                          {ASSET_CLASS_METADATA[key as InvestmentAssetClass].label}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Risk Profile *
                    </label>
                    <select
                      value={newRisk}
                      onChange={(e) => setNewRisk(e.target.value as InvestmentRiskProfile)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    >
                      <option value="conservative">Conservative (Low Risk)</option>
                      <option value="moderate">Moderate (Medium Risk)</option>
                      <option value="aggressive">Aggressive (High Risk)</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Platform / Broker
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. COL Financial, Maya, GCash"
                      value={newPlatform}
                      onChange={(e) => setNewPlatform(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>

                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Ticker / Symbol (Optional)
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. MP2, ALI, BTC, FMETF"
                      value={newSymbol}
                      onChange={(e) => setNewSymbol(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Total Cost Basis (₱) *
                    </label>
                    <input
                      type="number"
                      step="any"
                      required
                      placeholder="e.g. 50000"
                      value={newCostBasis}
                      onChange={(e) => setNewCostBasis(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>

                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Current Price per Unit (₱)
                    </label>
                    <input
                      type="number"
                      step="any"
                      placeholder="Leave blank to match cost"
                      value={newPricePerUnit}
                      onChange={(e) => setNewPricePerUnit(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Units / Shares
                    </label>
                    <input
                      type="number"
                      step="any"
                      value={newUnits}
                      onChange={(e) => setNewUnits(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>

                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Maturity Date (Optional)
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. 2029-06-15"
                      value={newMaturityDate}
                      onChange={(e) => setNewMaturityDate(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  className="w-full py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] font-bold cursor-pointer hover:opacity-95 shadow-xs"
                >
                  Save Investment Asset
                </button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* MODAL: RECORD ACTIVITY (BUY, SELL, DIVIDEND) */}
      <AnimatePresence>
        {activityAsset && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-md bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] rounded-2xl p-4 shadow-xl space-y-3"
            >
              <div className="flex items-center justify-between pb-2 border-b border-[#F3DFCD] dark:border-[#383029]">
                <div>
                  <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Record Activity: {activityAsset.name}
                  </h3>
                  <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    Updates investment cost basis, yield, and cash account ledger.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setActivityAsset(null)}
                  className="p-1 text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                >
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleRecordActivitySubmit} className="space-y-3 text-xs">
                {/* Activity Type Selector */}
                <div className="grid grid-cols-3 gap-1 p-1 bg-[#FFEEDF]/60 dark:bg-[#14100D] rounded-xl border border-[#F0D5C0] dark:border-[#383029]">
                  {(['contribution', 'dividend', 'withdrawal'] as InvestmentTxType[]).map((type) => (
                    <button
                      key={type}
                      type="button"
                      onClick={() => setActivityType(type)}
                      className={`py-1.5 rounded-lg font-bold text-center capitalize cursor-pointer transition-all ${
                        activityType === type
                          ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                          : 'text-[#6B6156] dark:text-[#AC9E92]'
                      }`}
                    >
                      {type}
                    </button>
                  ))}
                </div>

                <div>
                  <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    Amount (₱) *
                  </label>
                  <input
                    type="number"
                    step="any"
                    required
                    placeholder="e.g. 5000"
                    value={activityAmount}
                    onChange={(e) => setActivityAmount(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>

                {activityType !== 'dividend' && (
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Units / Shares (Optional)
                      </label>
                      <input
                        type="number"
                        step="any"
                        placeholder="Calculated if empty"
                        value={activityUnits}
                        onChange={(e) => setActivityUnits(e.target.value)}
                        className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                    <div>
                      <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Price Per Unit (₱)
                      </label>
                      <input
                        type="number"
                        step="any"
                        placeholder={activityAsset.currentPricePerUnit.toString()}
                        value={activityPrice}
                        onChange={(e) => setActivityPrice(e.target.value)}
                        className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                  </div>
                )}

                <div>
                  <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    Linked Bank / E-Wallet Account (Optional)
                  </label>
                  <select
                    value={activityAccountId}
                    onChange={(e) => setActivityAccountId(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                  >
                    <option value="">Do not create ledger transaction</option>
                    {accounts.map((acc) => (
                      <option key={acc.id} value={acc.id}>
                        {acc.name} ({acc.institution}) - Balance: {formatPeso(acc.balance)}
                      </option>
                    ))}
                  </select>
                </div>

                
                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Funding Account (Optional)
                    </label>
                    <select
                      value={fundingAccountId}
                      onChange={(e) => setFundingAccountId(e.target.value)}
                      className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                    >
                      <option value="">None (Don't deduct cash)</option>
                      {accounts.map(acc => (
                        <option key={acc.id} value={acc.id}>{acc.name} ({formatPeso(acc.balance)})</option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                      Notes
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Monthly salary deduction or reinvestment"
                    value={activityNote}
                    onChange={(e) => setActivityNote(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>

                <button
                  type="submit"
                  className="w-full py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] font-bold cursor-pointer hover:opacity-95 shadow-xs"
                >
                  Confirm Activity
                </button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* MODAL: UPDATE VALUATION */}
      <AnimatePresence>
        {valuationAsset && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-sm bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] rounded-2xl p-4 shadow-xl space-y-3"
            >
              <div className="flex items-center justify-between pb-2 border-b border-[#F3DFCD] dark:border-[#383029]">
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Update Valuation Price
                </h3>
                <button
                  type="button"
                  onClick={() => setValuationAsset(null)}
                  className="p-1 text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                >
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleValuationSubmit} className="space-y-3 text-xs">
                <div>
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                    Asset: <strong>{valuationAsset.name}</strong>
                  </span>
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-2">
                    Current Units: <strong>{valuationAsset.units}</strong>
                  </span>
                  <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    New Price Per Unit (₱) *
                  </label>
                  <input
                    type="number"
                    step="any"
                    required
                    value={newValuationPrice}
                    onChange={(e) => setNewValuationPrice(e.target.value)}
                    className="w-full p-2.5 rounded-xl border border-[#F0D5C0] dark:border-[#383029] bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8]"
                  />
                </div>

                <button
                  type="submit"
                  className="w-full py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] font-bold cursor-pointer hover:opacity-95 shadow-xs"
                >
                  Save New Valuation
                </button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};
