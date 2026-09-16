import React, { useState, useMemo } from 'react';
import { X, TrendingUp, ShieldCheck, PiggyBank, Target, Calendar, Info, Clock, AlertTriangle, Check } from 'lucide-react';
import { formatPeso } from '../utils/format';
import { useFinancial } from '../context/FinancialContext';

interface SavingsInvestmentModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SavingsInvestmentModal: React.FC<SavingsInvestmentModalProps> = ({ isOpen, onClose }) => {
  const { addGoal } = useFinancial();
  const [isSaved, setIsSaved] = useState(false);
  const [plannerType, setPlannerType] = useState<'emergency' | 'goal'>('emergency');
  
  // Emergency Fund State
  const [monthlyExpenseStr, setMonthlyExpenseStr] = useState('20000');
  const [monthsTarget, setMonthsTarget] = useState<3 | 6 | 12>(6);
  
  // Goal State
  const [goalAmountStr, setGoalAmountStr] = useState('100000');
  
  // Common State
  const [currentSavedStr, setCurrentSavedStr] = useState('0');
  const [monthlyContributionStr, setMonthlyContributionStr] = useState('5000');

  const monthlyExpense = parseFloat(monthlyExpenseStr.replace(/,/g, '')) || 0;
  const goalAmountInput = parseFloat(goalAmountStr.replace(/,/g, '')) || 0;
  const currentSaved = parseFloat(currentSavedStr.replace(/,/g, '')) || 0;
  const monthlyContribution = parseFloat(monthlyContributionStr.replace(/,/g, '')) || 0;

  React.useEffect(() => { setIsSaved(false); }, [plannerType, monthlyExpenseStr, monthsTarget, goalAmountStr, currentSavedStr, monthlyContributionStr, isOpen]);

  const results = useMemo(() => {
    let target = plannerType === 'emergency' ? monthlyExpense * monthsTarget : goalAmountInput;
    let shortfall = Math.max(0, target - currentSaved);
    
    let monthsToReach = 0;
    if (shortfall > 0 && monthlyContribution > 0) {
      monthsToReach = Math.ceil(shortfall / monthlyContribution);
    }
    
    let years = Math.floor(monthsToReach / 12);
    let months = monthsToReach % 12;
    
    let dateTarget = new Date();
    dateTarget.setMonth(dateTarget.getMonth() + monthsToReach);

    return {
      target,
      shortfall,
      monthsToReach,
      timeString: monthsToReach === 0 ? 'Goal Reached!' : `${years > 0 ? `${years} yr ` : ''}${months} mo`,
      targetDate: monthsToReach === 0 ? 'Already completed' : dateTarget.toLocaleDateString('en-US', { month: 'short', year: 'numeric' }),
      isImpossible: shortfall > 0 && monthlyContribution <= 0,
      dateTargetObj: dateTarget
    };
  }, [plannerType, monthlyExpense, monthsTarget, goalAmountInput, currentSaved, monthlyContribution]);

  
  const handleSaveGoal = () => {
    if (results.target <= 0) return;
    
    const goalName = plannerType === 'emergency' 
      ? `Emergency Fund (${monthsTarget} Mos)` 
      : 'Custom Savings Goal';
    
    const goalEmoji = plannerType === 'emergency' ? '🛡️' : '🎯';
    
    const isoDate = results.dateTargetObj.toISOString().split('T')[0];
    
    addGoal({
      name: goalName,
      emoji: goalEmoji,
      targetAmount: results.target,
      targetDate: isoDate,
      monthlyTarget: monthlyContribution > 0 ? monthlyContribution : (results.target / 12),
      currentAmount: currentSaved
    });
    
    setIsSaved(true);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity cursor-pointer"
        onClick={onClose}
      />

      {/* Modal Dialog */}
      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col min-h-0 overflow-hidden">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-3 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
              <TrendingUp size={18} />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Savings & Investment Planner
              </h2>
              <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] block">
                Emergency Funds, Goals & Timelines
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 min-h-0 overflow-y-auto space-y-4 pr-1">
          
          {/* Segment: Planner Type */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setPlannerType('emergency')}
              className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                plannerType === 'emergency'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              <ShieldCheck size={14} />
              <span>Emergency Fund</span>
            </button>
            <button
              type="button"
              onClick={() => setPlannerType('goal')}
              className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
                plannerType === 'goal'
                  ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              <Target size={14} />
              <span>Custom Goal</span>
            </button>
          </div>

          {/* Inputs */}
          <div className="space-y-3 bg-[#FFEEDF]/20 dark:bg-[#14100D]/50 p-3 rounded-2xl border border-[#F3DFCD]/50 dark:border-[#383029]/50">
            {plannerType === 'emergency' ? (
              <div className="space-y-3">
                <div>
                  <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                    Average Monthly Expenses
                  </label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                    <input
                      type="number" step="any" value={monthlyExpenseStr}
                      onChange={(e) => setMonthlyExpenseStr(e.target.value)}
                      className="w-full pl-7 pr-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-sm font-extrabold focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1.5 block">
                    Target Runway (Months)
                  </label>
                  <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
                    {[3, 6, 12].map(m => (
                      <button
                        key={m}
                        type="button"
                        onClick={() => setMonthsTarget(m as any)}
                        className={`flex-1 py-1 px-2 text-xs font-bold rounded-lg transition-all ${
                          monthsTarget === m ? 'bg-[#B03C09] text-white' : 'text-[#6B6156] dark:text-[#AC9E92]'
                        }`}
                      >
                        {m} Months
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            ) : (
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Target Goal Amount
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={goalAmountStr}
                    onChange={(e) => setGoalAmountStr(e.target.value)}
                    className="w-full pl-7 pr-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-sm font-extrabold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3 pt-2">
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Currently Saved
                </label>
                <div className="relative">
                  <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-xs text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={currentSavedStr}
                    onChange={(e) => setCurrentSavedStr(e.target.value)}
                    className="w-full pl-6 pr-2 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Monthly Deposit
                </label>
                <div className="relative">
                  <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-xs text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={monthlyContributionStr}
                    onChange={(e) => setMonthlyContributionStr(e.target.value)}
                    className="w-full pl-6 pr-2 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Results Summary Hero */}
          <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-3 shadow-xs">
            <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
              <PiggyBank size={14} className="text-[#16643F] dark:text-[#5FCB8E]" /> Savings Projection
            </h3>
            
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] space-y-2 text-xs">
              <div className="flex justify-between items-center pt-1">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">Target Amount</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(results.target)}</span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">Current Progress</span>
                <span className="font-bold text-[#16643F] dark:text-[#5FCB8E]">
                  {results.target > 0 ? Math.min(100, Math.round((currentSaved / results.target) * 100)) : 0}%
                </span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="font-medium text-rose-700 dark:text-rose-500">Remaining Shortfall</span>
                <span className="font-bold text-rose-700 dark:text-rose-500">{formatPeso(results.shortfall)}</span>
              </div>
              
              <div className="pt-3 mt-1 border-t-2 border-[#F3DFCD] dark:border-[#383029]">
                {results.isImpossible ? (
                  <div className="flex items-center gap-2 p-3 rounded-xl bg-rose-50 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/30 text-rose-700 dark:text-rose-500 text-xs font-bold">
                    <AlertTriangle size={16} />
                    You need to set a monthly deposit to reach this goal.
                  </div>
                ) : (
                  <div className="grid grid-cols-2 gap-3">
                    <div className="flex flex-col gap-1">
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] font-semibold flex items-center gap-1"><Clock size={12}/> Time to Goal</span>
                      <span className="font-black text-lg text-[#15120F] dark:text-[#F6EFE8]">{results.timeString}</span>
                    </div>
                    <div className="flex flex-col gap-1">
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] font-semibold flex items-center gap-1"><Calendar size={12}/> Target Date</span>
                      <span className="font-bold text-sm text-[#16643F] dark:text-[#5FCB8E] mt-0.5">{results.targetDate}</span>
                    </div>
                  </div>
                )}
              </div>
            </div>
            
            
            <div className="flex items-start gap-2 p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/30">
              <Info size={14} className="text-amber-600 dark:text-amber-500 shrink-0 mt-0.5" />
              <p className="text-[10px] text-amber-800 dark:text-amber-400/90 leading-relaxed">
                {plannerType === 'emergency' 
                  ? "Experts recommend keeping 3-6 months of living expenses in a highly liquid account like a high-yield digital bank (e.g., MariBank or GoTyme) to combat inflation."
                  : "Consider putting long-term savings in Pag-IBIG MP2 for tax-free compounding dividends if you don't need the money within 5 years."}
              </p>
            </div>
            
            <button
              type="button"
              onClick={handleSaveGoal}
              disabled={isSaved || results.target <= 0}
              className={`w-full py-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center gap-2 ${
                isSaved
                  ? 'bg-[#16643F] text-white'
                  : 'bg-[#B03C09] text-white hover:bg-[#8C2F07]'
              }`}
            >
              {isSaved ? (
                <>
                  <Check size={18} />
                  Saved to Goals Planner!
                </>
              ) : (
                <>
                  <Target size={18} />
                  Save as Tracking Goal
                </>
              )}
            </button>

          </div>
          
        </div>
      </div>
    </div>
  );
};
