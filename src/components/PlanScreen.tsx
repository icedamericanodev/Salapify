import React, { useState, useMemo, useEffect } from 'react';
import {
  Plus,
  Check,
  AlertCircle,
  CalendarClock,
  Target,
  Zap,
  Music,
  DollarSign,
  Info,
  Activity,
  Sparkles,
  ShieldCheck,
  TrendingDown,
  Clock,
  Layers,
  ChevronRight,
  PieChart,
  Calculator,
  BookOpen,
  Calendar,
  Trash2,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Budget, Goal, UpcomingItem, IncomeStreamType } from '../types';
import { SectionInfoModal, InfoTopic } from './SectionInfoModal';
import { SafeToSpendModal } from './SafeToSpendModal';
import { HealthCheckModal } from './HealthCheckModal';
import { HabitTrackerView } from './HabitTrackerView';
import { SubscriptionTrackerView } from './SubscriptionTrackerView';
import { CalculatorLibrary } from './CalculatorLibrary';
import { AcademyView } from './AcademyView';

interface PlanScreenProps {
  initialSegment?: 'overview' | 'budget' | 'upcoming' | 'goals' | 'decision' | 'trackers' | 'calculators' | 'academy';
  initialAcademyMode?: 'courses' | 'startup_guide';
  initialStartupTab?: 'entities' | 'roadmap' | 'checklist' | 'experts' | 'saas';
  initialSaasSubTab?: 'overview' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator';
  onOpenBills?: () => void;
  onOpenDebt?: () => void;
  onOpenTaxCalculator?: () => void;
  onOpenBusiness?: () => void;
  onOpenSavingsPlanner?: () => void;
}

export const PlanScreen: React.FC<PlanScreenProps> = ({
  initialSegment = 'budget',
  initialAcademyMode = 'courses',
  initialStartupTab = 'roadmap',
  initialSaasSubTab = 'overview',
  onOpenBills,
  onOpenDebt,
  onOpenTaxCalculator,
  onOpenBusiness,
  onOpenSavingsPlanner,
}) => {
  const {
    budgets,
    transactions,
    upcoming,
    goals,
    payday,
    updateBudgetLimit,
    contributeToGoal,
    addGoal,
    safeToSpendAnalysis,
    decisionScenario,
    setDecisionScenario,
    incomeStreams,
    addIncomeStream,
    deleteIncomeStream,
    healthCheckInsights,
  } = useFinancial();

  const [activeSegment, setActiveSegment] = useState<'overview' | 'budget' | 'upcoming' | 'goals' | 'decision' | 'trackers' | 'calculators' | 'academy'>(initialSegment || 'overview');
  const [infoTopic, setInfoTopic] = useState<InfoTopic | null>(null);

  // Modal dialog states
  const [isSafeToSpendModalOpen, setIsSafeToSpendModalOpen] = useState(false);
  const [isHealthCheckModalOpen, setIsHealthCheckModalOpen] = useState(false);

  useEffect(() => {
    setActiveSegment(initialSegment);
  }, [initialSegment]);

  // Modal states
  const [editingBudget, setEditingBudget] = useState<(Budget & { spent?: number }) | null>(null);
  const [newBudgetLimit, setNewBudgetLimit] = useState('');
  const [contributingGoal, setContributingGoal] = useState<Goal | null>(null);
  const [contribAmount, setContribAmount] = useState('');
  const [showAddGoalModal, setShowAddGoalModal] = useState(false);

  // New Goal fields
  const [goalName, setGoalName] = useState('');
  const [goalEmoji, setGoalEmoji] = useState('🎯');
  const [goalTarget, setGoalTarget] = useState('');
  const [goalDate, setGoalDate] = useState('Dec 2026');
  const [goalMonthly, setGoalMonthly] = useState('');

  // New Stream form state
  const [showAddStreamInline, setShowAddStreamInline] = useState(false);
  const [streamName, setStreamName] = useState('');
  const [streamType, setStreamType] = useState<IncomeStreamType>('semimonthly_salary');
  const [streamAmount, setStreamAmount] = useState('');
  const [streamDate, setStreamDate] = useState('');

  // Calculate spent per budget category
  const budgetStats = useMemo(() => {
    return budgets.map((b) => {
      const spent = transactions
        .filter((t) => t.type === 'expense' && t.category.toLowerCase() === b.category.toLowerCase())
        .reduce((sum, t) => sum + t.amount, 0);

      const remaining = b.limit - spent;
      const percent = Math.min(100, Math.round((spent / b.limit) * 100));
      const isOver = remaining < 0;
      const isNear = percent >= 80 && !isOver;

      return {
        ...b,
        spent,
        remaining,
        percent,
        isOver,
        isNear,
      };
    });
  }, [budgets, transactions]);

  const watchClosely = budgetStats.filter((b) => b.isOver || b.isNear);
  const onTrack = budgetStats.filter((b) => !b.isOver && !b.isNear);
  const totalBudgetLimit = budgets.reduce((sum, b) => sum + b.limit, 0);
  const totalSpent = budgetStats.reduce((sum, b) => sum + b.spent, 0);
  const totalLeftToSpend = Math.max(0, totalBudgetLimit - totalSpent);

  const handleSaveBudgetLimit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingBudget) return;
    const limit = parseFloat(newBudgetLimit);
    if (!isNaN(limit) && limit > 0) {
      updateBudgetLimit(editingBudget.category, limit);
    }
    setEditingBudget(null);
  };

  const handleSaveGoal = (e: React.FormEvent) => {
    e.preventDefault();
    const target = parseFloat(goalTarget);
    const monthly = parseFloat(goalMonthly) || target / 12;
    if (!goalName.trim() || isNaN(target) || target <= 0) return;

    addGoal({
      name: goalName.trim(),
      emoji: goalEmoji,
      targetAmount: target,
      targetDate: goalDate,
      monthlyTarget: Math.round(monthly),
    });

    setShowAddGoalModal(false);
    setGoalName('');
    setGoalTarget('');
    setGoalMonthly('');
  };

  const handleContribute = (e: React.FormEvent) => {
    e.preventDefault();
    if (!contributingGoal) return;
    const amount = parseFloat(contribAmount);
    if (!isNaN(amount) && amount > 0) {
      contributeToGoal(contributingGoal.id, amount);
    }
    setContributingGoal(null);
    setContribAmount('');
  };

  const handleAddStreamSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseFloat(streamAmount);
    if (!streamName || isNaN(amount) || amount <= 0) return;

    addIncomeStream({
      name: streamName,
      type: streamType,
      expectedAmount: amount,
      nextExpectedDate: streamDate || new Date().toISOString().split('T')[0],
      isConfirmed: true,
    });

    setStreamName('');
    setStreamAmount('');
    setStreamDate('');
    setShowAddStreamInline(false);
  };

  const streamTypeLabels: Record<IncomeStreamType, string> = {
    weekly_income: 'Weekly Income',
    semimonthly_salary: '15/30 Sweldo',
    monthly_salary: 'Monthly Payroll',
    freelance: 'Freelance & Retainer',
    irregular: 'Irregular Gig',
    thirteenth_month: '13th-Month Pay',
    remittance: 'Padala / Remittance',
  };

  return (
    <div className="flex flex-col gap-4 pb-36">
      
      {/* Top Header */}
      <div className="flex flex-col gap-3 pt-2 px-1 mb-2">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {activeSegment !== 'overview' && (
              <button
                type="button"
                onClick={() => setActiveSegment('overview')}
                className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
              >
                ← Back
              </button>
            )}
            <h1 className="text-xl font-extrabold font-display text-[#15120F] dark:text-[#F6EFE8]">
              {activeSegment === 'overview' ? 'Strategy & Plan' : 
               activeSegment === 'budget' ? 'Budgets' :
               activeSegment === 'upcoming' ? 'Bills & Payables' :
               activeSegment === 'goals' ? 'Wealth Goals' :
               activeSegment === 'decision' ? 'Decision Journal' :
               activeSegment === 'trackers' ? 'Trackers' :
               activeSegment === 'calculators' ? 'Calculators' : 'Academy'}
            </h1>
          </div>
          <button
            type="button"
            onClick={() => setInfoTopic('budget')}
            className="inline-flex items-center justify-center w-6 h-6 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
            title="Learn about Plan and Budget tracking"
            aria-label="Plan info"
          >
            <Info size={14} />
          </button>
        </div>
        
        {/* Render Segment Pills ONLY on overview if you want, or just remove them. Let's REMOVE them entirely to force Hub navigation! */}
      </div>

      {/* 0. OVERVIEW HUB */}
      {activeSegment === 'overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => setActiveSegment('budget')}
              className="p-4 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs text-left hover:opacity-90 flex flex-col gap-2"
            >
              <div className="w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400 flex items-center justify-center">
                <PieChart size={16} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Budgets</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5">Track categorical spending</p>
              </div>
            </button>

            <button
              onClick={() => setActiveSegment('upcoming')}
              className="p-4 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs text-left hover:opacity-90 flex flex-col gap-2"
            >
              <div className="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-400 flex items-center justify-center">
                <Calendar size={16} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Bills & Payables</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5">Manage upcoming cash flows</p>
              </div>
            </button>

            <button
              onClick={() => setActiveSegment('goals')}
              className="p-4 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs text-left hover:opacity-90 flex flex-col gap-2"
            >
              <div className="w-8 h-8 rounded-full bg-[#FFEEDF] dark:bg-[#382B22] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center">
                <Target size={16} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Wealth Goals</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5">Ipon challenges & targets</p>
              </div>
            </button>

            <button
              onClick={() => setActiveSegment('decision')}
              className="p-4 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-xs text-left hover:opacity-90 flex flex-col gap-2"
            >
              <div className="w-8 h-8 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-400 flex items-center justify-center">
                <ShieldCheck size={16} />
              </div>
              <div>
                <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Decision Journal</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5">Safe-to-spend modeling</p>
              </div>
            </button>
          </div>

          <h2 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] px-1 pt-2">
            Toolbox & Education
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
             <button
              onClick={() => setActiveSegment('trackers')}
              className="p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs text-left hover:opacity-90 flex items-center gap-3"
            >
              <div className="w-8 h-8 rounded-full bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-400 flex items-center justify-center shrink-0">
                <Activity size={14} />
              </div>
              <div>
                <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Trackers</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Habits & Subscriptions</p>
              </div>
            </button>
            <button
              onClick={() => setActiveSegment('calculators')}
              className="p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs text-left hover:opacity-90 flex items-center gap-3"
            >
              <div className="w-8 h-8 rounded-full bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-400 flex items-center justify-center shrink-0">
                <Calculator size={14} />
              </div>
              <div>
                <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Calculators</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Debt & Tax models</p>
              </div>
            </button>
            <button
              onClick={() => setActiveSegment('academy')}
              className="p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs text-left hover:opacity-90 flex items-center gap-3"
            >
              <div className="w-8 h-8 rounded-full bg-[#15120F] dark:bg-[#F6EFE8] text-[#F6EFE8] dark:text-[#15120F] flex items-center justify-center shrink-0">
                <BookOpen size={14} />
              </div>
              <div>
                <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Academy</h3>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Financial literacy</p>
              </div>
            </button>
          </div>
        </div>
      )}

      {/* 1. BUDGET SEGMENT */}
      {activeSegment === 'budget' && (
        <div className="space-y-4">
          {/* Hero: Left to spend this cycle */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                Left to spend this cycle
              </span>
              <button
                type="button"
                onClick={() => setInfoTopic('budget')}
                className="inline-flex items-center justify-center w-5 h-5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
                title="How budget limits and pacing work"
                aria-label="Budget info"
              >
                <Info size={13} strokeWidth={2.2} />
              </button>
            </div>
            <div className="text-2xl sm:text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] my-1 tabular-nums break-words">
              {formatPeso(totalLeftToSpend)}
            </div>
            <p className="text-xs font-medium text-[#5A5148] dark:text-[#C6B8AC] break-words">
              {watchClosely.length > 0
                ? `${watchClosely.length} of ${budgets.length} categories need a look.`
                : 'All your budget categories are smoothly on track!'}
            </p>
          </div>

          {/* Section: Watch closely */}
          {watchClosely.length > 0 && (
            <div className="flex flex-col gap-2">
              <h2 className="text-xs font-bold uppercase tracking-wider text-[#9E2C1B] dark:text-[#FF8A6E] px-1 flex items-center gap-1">
                <AlertCircle size={13} /> Watch Closely ({watchClosely.length})
              </h2>

              <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
                {watchClosely.map((b) => (
                  <div
                    key={b.category}
                    onClick={() => {
                      setEditingBudget(b);
                      setNewBudgetLimit(b.limit.toString());
                    }}
                    className="p-3.5 hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors cursor-pointer"
                  >
                    <div className="flex justify-between items-center mb-1.5 gap-2">
                      <div className="flex items-center gap-2 min-w-0 flex-1">
                        <span className="text-base shrink-0">{b.emoji}</span>
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {b.category}
                        </span>
                      </div>
                      <span
                        className={`text-xs font-bold shrink-0 whitespace-nowrap pl-2 tabular-nums text-right ${
                          b.isOver
                            ? 'text-[#9E2C1B] dark:text-[#FF8A6E]'
                            : 'text-[#B03C09] dark:text-[#FF9A52]'
                        }`}
                      >
                        {b.isOver ? `${formatPeso(Math.abs(b.remaining))} over` : `${formatPeso(b.remaining)} left`}
                      </span>
                    </div>

                    {/* ThinBar */}
                    <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden mb-1">
                      <div
                        className={`h-full rounded-full transition-all duration-300 ${
                          b.isOver ? 'bg-[#9E2C1B] dark:bg-[#FF8A6E]' : 'bg-[#B03C09] dark:bg-[#FF9A52]'
                        }`}
                        style={{ width: `${Math.min(100, b.percent)}%` }}
                      />
                    </div>

                    <div className="flex justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92] gap-1">
                      <span className="truncate">{formatPeso(b.spent)} of {formatPeso(b.limit)} limit</span>
                      <span className="shrink-0 whitespace-nowrap">{payday.daysToPayday} days left</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Section: On Track */}
          <div className="flex flex-col gap-2">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#16643F] dark:text-[#5FCB8E] px-1 flex items-center gap-1">
              <Check size={13} /> On Track ({onTrack.length})
            </h2>

            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
              {onTrack.map((b) => (
                <div
                  key={b.category}
                  onClick={() => {
                    setEditingBudget(b);
                    setNewBudgetLimit(b.limit.toString());
                  }}
                  className="p-3.5 hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors cursor-pointer"
                >
                  <div className="flex justify-between items-center mb-1.5 gap-2">
                    <div className="flex items-center gap-2 min-w-0 flex-1">
                      <span className="text-base shrink-0">{b.emoji}</span>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {b.category}
                      </span>
                    </div>
                    <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] shrink-0 whitespace-nowrap pl-2 tabular-nums text-right">
                      {formatPeso(b.remaining)} left
                    </span>
                  </div>

                  {/* ThinBar */}
                  <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden mb-1">
                    <div
                      className="h-full rounded-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-300"
                      style={{ width: `${Math.min(100, b.percent)}%` }}
                    />
                  </div>

                  <div className="flex justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92] gap-1">
                    <span className="truncate">{formatPeso(b.spent)} of {formatPeso(b.limit)} limit</span>
                    <span className="shrink-0 whitespace-nowrap">{b.percent}% spent</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 2. UPCOMING SEGMENT */}
      {activeSegment === 'upcoming' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex items-center justify-between">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                Total Scheduled Bills
              </span>
              <div className="text-xl sm:text-2xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] mt-0.5 tabular-nums">
                {formatPeso(upcoming.reduce((sum, u) => sum + u.amount, 0))}
              </div>
            </div>

            {onOpenBills && (
              <button
                type="button"
                onClick={onOpenBills}
                className="px-3 py-1.5 rounded-xl bg-[#B03C09] text-white text-xs font-bold hover:bg-[#8F3006] transition-colors cursor-pointer shadow-xs"
              >
                Manage All Bills
              </button>
            )}
          </div>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {upcoming.length === 0 ? (
              <div className="p-6 text-center text-xs text-[#7A6E63] dark:text-[#A89A8D]">
                No upcoming bills scheduled.
              </div>
            ) : (
              upcoming.map((u) => (
                <div key={u.id} className="p-3.5 flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-9 h-9 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-base shrink-0">
                      {u.emoji || '🧾'}
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {u.name}
                      </div>
                      <div className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Due {u.dueDate} • {u.category || u.type}
                      </div>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] tabular-nums">
                      {formatPeso(u.amount)}
                    </div>
                    {u.isRecurring && (
                      <span className="text-[9px] font-semibold text-[#16643F] dark:text-[#5FCB8E] block">
                        Recurring
                      </span>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* 3. GOALS SEGMENT */}
      {activeSegment === 'goals' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between px-1">
            <div>
              <h2 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                Savings &amp; Wealth Goals
              </h2>
              <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                Track your savings and investment targets
              </p>
            </div>
            <button
              type="button"
              onClick={() => setShowAddGoalModal(true)}
              className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
            >
              <Plus size={14} /> Add Goal
            </button>
          </div>

          <div className="space-y-3">
            {goals.map((goal) => {
              const progress = Math.min(100, Math.round((goal.currentAmount / goal.targetAmount) * 100));
              const remaining = Math.max(0, goal.targetAmount - goal.currentAmount);

              return (
                <div
                  key={goal.id}
                  className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-lg shrink-0">
                        {goal.emoji}
                      </div>
                      <div className="min-w-0">
                        <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {goal.name}
                        </h3>
                        <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                          Target: {goal.targetDate} • ₱{goal.monthlyTarget.toLocaleString()}/mo
                        </p>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => setContributingGoal(goal)}
                      className="px-3 py-1.5 rounded-xl bg-[#16643F] text-white text-xs font-bold hover:bg-[#124f32] transition-colors cursor-pointer shrink-0 shadow-xs"
                    >
                      Deposit
                    </button>
                  </div>

                  <div className="space-y-1">
                    <div className="flex justify-between text-xs font-semibold tabular-nums">
                      <span className="text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(goal.currentAmount)}
                      </span>
                      <span className="text-[#7A6E63] dark:text-[#A89A8D]">
                        {progress}% of {formatPeso(goal.targetAmount)}
                      </span>
                    </div>

                    <div className="w-full h-2 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden">
                      <div
                        className="h-full rounded-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-500"
                        style={{ width: `${progress}%` }}
                      />
                    </div>

                    <div className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] text-right">
                      {formatPeso(remaining)} to go
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 4. DAILY DECISION & HEALTH SEGMENT (Phase 3) */}
      {activeSegment === 'decision' && (
        <div className="space-y-4">
          {/* Top Trigger Banner for Full Modals */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => setIsSafeToSpendModalOpen(true)}
              className="p-3.5 text-left bg-gradient-to-br from-[#FFEEDF] to-[#FFD9B0] dark:from-[#2A221C] dark:to-[#382B22] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer hover:opacity-95 transition-opacity flex flex-col justify-between min-w-0"
            >
              <div className="flex items-center justify-between w-full mb-1 gap-1">
                <span className="text-[10px] uppercase font-bold tracking-wider text-[#5E2C08] dark:text-[#FF9A52] truncate">
                  Safe to Spend
                </span>
                <Sparkles size={14} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
              </div>
              <div className="text-lg font-black text-[#2A1207] dark:text-[#F6EFE8] tabular-nums truncate">
                {formatPeso(safeToSpendAnalysis.safeToSpendToday)}
              </div>
              <span className="text-[10px] text-[#5E2C08]/80 dark:text-[#A89A8D] mt-1 truncate">
                Tap for deep simulator &rarr;
              </span>
            </button>

            <button
              type="button"
              onClick={() => setIsHealthCheckModalOpen(true)}
              className="p-3.5 text-left bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs cursor-pointer hover:opacity-95 transition-opacity flex flex-col justify-between min-w-0"
            >
              <div className="flex items-center justify-between w-full mb-1 gap-1">
                <span className="text-[10px] uppercase font-bold tracking-wider text-[#7A6E63] dark:text-[#A89A8D] truncate">
                  Health Check
                </span>
                <Activity size={14} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
              </div>
              <div className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8] truncate">
                {healthCheckInsights.filter((i) => i.severity === 'optimal').length}/{healthCheckInsights.length} Indicators
              </div>
              <span className="text-[10px] text-[#B03C09] dark:text-[#FF9A52] font-semibold mt-1 truncate">
                View {healthCheckInsights.length} audits &rarr;
              </span>
            </button>
          </div>

          {/* Scenario Selector & Core Metrics */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div className="min-w-0">
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                  Scenario Modeling
                </h3>
                <p className="text-[11px] text-[#15120F] dark:text-[#F6EFE8] font-medium break-words">
                  {decisionScenario === 'conservative'
                    ? 'Guaranteed income only, full debt & bill reserves'
                    : 'Includes expected irregular freelance & 13th month'}
                </p>
              </div>

              <div className="flex rounded-xl p-0.5 bg-[#FFEEDF] dark:bg-[#14100D] shrink-0 self-start sm:self-auto">
                <button
                  type="button"
                  onClick={() => setDecisionScenario('conservative')}
                  className={`px-2.5 py-1 rounded-lg text-xs font-bold cursor-pointer transition-colors ${
                    decisionScenario === 'conservative'
                      ? 'bg-[#B03C09] text-white shadow-xs'
                      : 'text-[#7A6E63] dark:text-[#A89A8D]'
                  }`}
                >
                  Conservative
                </button>
                <button
                  type="button"
                  onClick={() => setDecisionScenario('optimistic')}
                  className={`px-2.5 py-1 rounded-lg text-xs font-bold cursor-pointer transition-colors ${
                    decisionScenario === 'optimistic'
                      ? 'bg-[#B03C09] text-white shadow-xs'
                      : 'text-[#7A6E63] dark:text-[#A89A8D]'
                  }`}
                >
                  Optimistic
                </button>
              </div>
            </div>

            {/* Decision Outputs Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-1">
              <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
                  Until Payday ({payday.daysToPayday}d)
                </span>
                <div className="text-base sm:text-lg font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 truncate">
                  {formatPeso(safeToSpendAnalysis.safeToSpendUntilPayday)}
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
                  Safe to Save (Ipon)
                </span>
                <div className="text-base sm:text-lg font-black text-[#16643F] dark:text-[#5FCB8E] tabular-nums mt-0.5 truncate">
                  {formatPeso(safeToSpendAnalysis.safeToSave)}
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
                  Must Remain Reserved
                </span>
                <div className="text-base sm:text-lg font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums mt-0.5 truncate">
                  {formatPeso(safeToSpendAnalysis.amountReserved)}
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D] block truncate">
                  Cash Runway
                </span>
                <div className="text-base sm:text-lg font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 truncate">
                  {safeToSpendAnalysis.cashRunwayDays} days ({safeToSpendAnalysis.cashRunwayMonths.toFixed(1)} mo)
                </div>
              </div>
            </div>
          </div>

          {/* Income Streams Module */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                  Income Streams &amp; Paydays
                </h3>
                <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                  Weekly, 15/30 salary, freelance retainers, remittances
                </p>
              </div>
              <button
                type="button"
                onClick={() => setShowAddStreamInline(!showAddStreamInline)}
                className="px-2.5 py-1 rounded-xl bg-[#B03C09] text-white text-xs font-bold hover:bg-[#8F3006] transition-colors cursor-pointer flex items-center gap-1 shadow-xs"
              >
                <Plus size={13} /> Add Stream
              </button>
            </div>

            {/* Inline Add Stream Form */}
            {showAddStreamInline && (
              <form onSubmit={handleAddStreamSubmit} className="p-3 bg-[#FFEEDF]/40 dark:bg-[#14100D] rounded-xl border border-[#F3DFCD] dark:border-[#383029] space-y-2.5 animate-in fade-in">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div>
                    <label className="text-[10px] font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Stream Name
                    </label>
                    <input
                      type="text"
                      required
                      value={streamName}
                      onChange={(e) => setStreamName(e.target.value)}
                      placeholder="e.g. Design Retainer"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Expected (₱)
                    </label>
                    <input
                      type="number"
                      required
                      step="any"
                      value={streamAmount}
                      onChange={(e) => setStreamAmount(e.target.value)}
                      placeholder="25000"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div>
                    <label className="text-[10px] font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Income Type
                    </label>
                    <select
                      value={streamType}
                      onChange={(e) => setStreamType(e.target.value as IncomeStreamType)}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    >
                      <option value="semimonthly_salary">15th &amp; 30th Salary</option>
                      <option value="weekly_income">Weekly Income</option>
                      <option value="monthly_salary">Monthly Payroll</option>
                      <option value="freelance">Freelance Retainer</option>
                      <option value="irregular">Irregular Gig</option>
                      <option value="thirteenth_month">13th-Month Pay</option>
                      <option value="remittance">Remittance Padala</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Next Date
                    </label>
                    <input
                      type="date"
                      value={streamDate}
                      onChange={(e) => setStreamDate(e.target.value)}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-1">
                  <button
                    type="button"
                    onClick={() => setShowAddStreamInline(false)}
                    className="px-3 py-1 rounded-lg text-xs font-semibold text-[#7A6E63] dark:text-[#A89A8D] cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-3 py-1 rounded-lg bg-[#B03C09] text-white text-xs font-bold hover:bg-[#8F3006] cursor-pointer"
                  >
                    Save Stream
                  </button>
                </div>
              </form>
            )}

            {/* Income Streams List */}
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] rounded-xl border border-[#F3DFCD] dark:border-[#383029] overflow-hidden">
              {incomeStreams.map((stream) => (
                <div key={stream.id} className="p-3 flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {stream.name}
                      </span>
                      <span className="px-1.5 py-0.2 rounded-md text-[9px] font-bold bg-[#FFEEDF] dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52]">
                        {streamTypeLabels[stream.type] || stream.type}
                      </span>
                    </div>
                    <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] block mt-0.5">
                      Next: {stream.nextExpectedDate}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-xs font-black text-[#16643F] dark:text-[#5FCB8E] tabular-nums">
                      +{formatPeso(stream.expectedAmount)}
                    </span>
                    <button
                      type="button"
                      onClick={() => deleteIncomeStream(stream.id)}
                      className="p-1 text-[#7A6E63] hover:text-rose-600 transition-colors cursor-pointer"
                      title="Remove stream"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Quick Health Check Previews (Top 3) */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                  Money Health Insights (Phase 3)
                </h3>
                <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                  Explanatory diagnostics across cash runway, fee leakage &amp; debt pressure
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsHealthCheckModalOpen(true)}
                className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
              >
                All 10 &rarr;
              </button>
            </div>

            <div className="space-y-2">
              {healthCheckInsights.slice(0, 3).map((insight) => (
                <div
                  key={insight.id}
                  onClick={() => setIsHealthCheckModalOpen(true)}
                  className="p-3 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40 transition-colors cursor-pointer space-y-1.5"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {insight.title}
                    </span>
                    <span
                      className={`px-1.5 py-0.2 rounded-md text-[9px] font-bold uppercase ${
                        insight.severity === 'critical'
                          ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                          : insight.severity === 'warning'
                          ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                          : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                      }`}
                    >
                      {insight.severity}
                    </span>
                  </div>
                  <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] line-clamp-2">
                    {insight.whatHappened}
                  </p>
                  <div className="text-[10px] text-[#B03C09] dark:text-[#FF9A52] font-semibold flex items-center gap-1">
                    <span>Rec: {insight.recommendedAction}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Edit Budget Limit Modal */}
      {editingBudget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <h3 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Edit {editingBudget.emoji} {editingBudget.category} Limit
            </h3>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mb-4">
              Currently spent: {formatPeso(editingBudget.spent || 0)}
            </p>

            <form onSubmit={handleSaveBudgetLimit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  New Cycle Limit (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  autoFocus
                  value={newBudgetLimit}
                  onChange={(e) => setNewBudgetLimit(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setEditingBudget(null)}
                  className="flex-1 py-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
                >
                  Save Limit
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Contribute to Goal Modal */}
      {contributingGoal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <h3 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Deposit to {contributingGoal.emoji} {contributingGoal.name}
            </h3>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mb-4">
              Current: {formatPeso(contributingGoal.currentAmount)} / {formatPeso(contributingGoal.targetAmount)}
            </p>

            <form onSubmit={handleContribute} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Deposit Amount (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  autoFocus
                  value={contribAmount}
                  onChange={(e) => setContribAmount(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-base font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setContributingGoal(null)}
                  className="flex-1 py-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2 rounded-xl bg-[#16643F] text-white text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
                >
                  Deposit
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Goal Modal */}
      {showAddGoalModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <h3 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] mb-3">
              Create New Goal
            </h3>

            <form onSubmit={handleSaveGoal} className="space-y-3">
              <div className="flex gap-2">
                <div className="w-16">
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Emoji
                  </label>
                  <input
                    type="text"
                    value={goalEmoji}
                    onChange={(e) => setGoalEmoji(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-center text-lg focus:outline-none"
                  />
                </div>
                <div className="flex-1">
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Goal Name
                  </label>
                  <input
                    type="text"
                    required
                    value={goalName}
                    onChange={(e) => setGoalName(e.target.value)}
                    placeholder="e.g. Laptop, Bali Trip"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Target Amount (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  value={goalTarget}
                  onChange={(e) => setGoalTarget(e.target.value)}
                  placeholder="50000"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Target Date
                  </label>
                  <input
                    type="text"
                    value={goalDate}
                    onChange={(e) => setGoalDate(e.target.value)}
                    placeholder="Dec 2026"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                    Monthly (₱)
                  </label>
                  <input
                    type="number"
                    value={goalMonthly}
                    onChange={(e) => setGoalMonthly(e.target.value)}
                    placeholder="4500"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddGoalModal(false)}
                  className="flex-1 py-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
                >
                  Create Goal
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 5. TRACKERS SEGMENT */}
      {activeSegment === 'trackers' && (
        <div className="space-y-4">
          <HabitTrackerView />
          <SubscriptionTrackerView />
        </div>
      )}

      {/* 6. CALCULATORS SEGMENT */}
      
      {/* 7. ACADEMY SEGMENT */}
      {activeSegment === 'academy' && (
        <AcademyView
          initialMode={initialAcademyMode}
          initialStartupTab={initialStartupTab}
          initialSaasSubTab={initialSaasSubTab}
        />
      )}
      
      {activeSegment === 'calculators' && (

        <div className="space-y-4">
          <CalculatorLibrary onOpenCalculator={(id) => {
            if (id === 'tax_comprehensive') {
              if (onOpenTaxCalculator) onOpenTaxCalculator();
            } else if (id === 'business_pricing') {
              if (onOpenBusiness) onOpenBusiness();
            } else if (id === 'savings_investment') {
              if (onOpenSavingsPlanner) onOpenSavingsPlanner();
            } else if (id === 'debt_loan') {
              if (onOpenDebt) onOpenDebt();
            } else {
              alert('Calculator coming soon!');
            }
          }} />
        </div>
      )}

      {/* Safe to Spend Sheet Modal */}
      <SafeToSpendModal
        isOpen={isSafeToSpendModalOpen}
        onClose={() => setIsSafeToSpendModalOpen(false)}
      />

      {/* Health Check Sheet Modal */}
      <HealthCheckModal
        isOpen={isHealthCheckModalOpen}
        onClose={() => setIsHealthCheckModalOpen(false)}
        onNavigateTo={(target) => {
          setIsHealthCheckModalOpen(false);
          if (target === 'bills' && onOpenBills) {
            onOpenBills();
          } else if (target === 'debt' && onOpenDebt) {
            onOpenDebt();
          }
        }}
      />

      {/* Section Info Modal */}
      <SectionInfoModal topic={infoTopic} onClose={() => setInfoTopic(null)} />
    </div>
  );
};
