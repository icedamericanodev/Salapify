import React, { useState, useMemo, useEffect } from 'react';
import { Plus, Check, AlertCircle, CalendarClock, Target, Zap, Music, DollarSign } from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import { Budget, Goal, UpcomingItem } from '../types';

interface PlanScreenProps {
  initialSegment?: 'budget' | 'upcoming' | 'goals';
}

export const PlanScreen: React.FC<PlanScreenProps> = ({ initialSegment = 'budget' }) => {
  const {
    budgets,
    transactions,
    upcoming,
    goals,
    payday,
    updateBudgetLimit,
    contributeToGoal,
    addGoal,
  } = useFinancial();

  const [activeSegment, setActiveSegment] = useState<'budget' | 'upcoming' | 'goals'>(initialSegment);

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
    const monthly = parseFloat(goalMonthly) || (target / 12);
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

  return (
    <div className="flex flex-col gap-4 pb-24">
      {/* Top Header */}
      <div className="flex items-center justify-between pt-2 px-1">
        <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
          Plan
        </h1>

        {/* 3 Segments: Budget · Upcoming · Goals */}
        <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
          {(['budget', 'upcoming', 'goals'] as const).map((seg) => (
            <button
              key={seg}
              type="button"
              onClick={() => setActiveSegment(seg)}
              className={`px-3 py-1 text-xs font-bold rounded-lg capitalize transition-all cursor-pointer ${
                activeSegment === seg
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92]'
              }`}
            >
              {seg}
            </button>
          ))}
        </div>
      </div>

      {/* 1. BUDGET SEGMENT */}
      {activeSegment === 'budget' && (
        <div className="space-y-4">
          {/* Hero: Left to spend this cycle */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
              Left to spend this cycle
            </span>
            <div className="text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] my-1">
              {formatPeso(totalLeftToSpend)}
            </div>
            <p className="text-xs font-medium text-[#5A5148] dark:text-[#C6B8AC]">
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
                    <div className="flex justify-between items-center mb-1.5">
                      <div className="flex items-center gap-2">
                        <span className="text-base">{b.emoji}</span>
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {b.category}
                        </span>
                      </div>
                      <span
                        className={`text-xs font-bold ${
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

                    <div className="flex justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                      <span>{formatPeso(b.spent)} of {formatPeso(b.limit)} limit</span>
                      <span>{payday.daysToPayday} days left in cutoff</span>
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
                  <div className="flex justify-between items-center mb-1.5">
                    <div className="flex items-center gap-2">
                      <span className="text-base">{b.emoji}</span>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        {b.category}
                      </span>
                    </div>
                    <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {formatPeso(b.remaining)} left
                    </span>
                  </div>

                  {/* ThinBar */}
                  <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden mb-1">
                    <div
                      className="h-full rounded-full bg-[#16643F] dark:bg-[#5FCB8E] transition-all duration-300"
                      style={{ width: `${b.percent}%` }}
                    />
                  </div>

                  <div className="flex justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    <span>{formatPeso(b.spent)} of {formatPeso(b.limit)} limit</span>
                    <span>{payday.daysToPayday} days left</span>
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
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h2 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] mb-1">
              Sweldo Timeline
            </h2>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              Every bill, recurring subscription, and payday between now and your next cutoff.
            </p>
          </div>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {upcoming.map((item) => {
              const isIncome = item.isIncome || item.type === 'payday';
              const isToday = item.dueDate.toLowerCase() === 'today';

              return (
                <div
                  key={item.id}
                  className="p-3.5 flex items-center justify-between hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                        isIncome
                          ? 'bg-[#16643F]/10 dark:bg-[#5FCB8E]/15 text-[#16643F] dark:text-[#5FCB8E]'
                          : 'bg-[#FFEEDF] dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC]'
                      }`}
                    >
                      {item.type === 'payday' ? (
                        <DollarSign size={17} />
                      ) : (
                        <CalendarClock size={17} />
                      )}
                    </div>

                    <div className="flex flex-col">
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {item.name}
                        </span>
                        {isToday && (
                          <span className="w-2 h-2 rounded-full bg-[#9E2C1B]" title="Due today" />
                        )}
                      </div>
                      <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        {item.dueDate}
                      </span>
                    </div>
                  </div>

                  <span
                    className={`text-xs font-bold ${
                      isIncome
                        ? 'text-[#16643F] dark:text-[#5FCB8E]'
                        : 'text-[#15120F] dark:text-[#F6EFE8]'
                    }`}
                  >
                    {isIncome ? `+${formatPeso(item.amount)}` : formatPeso(item.amount)}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 3. GOALS (IPON) SEGMENT */}
      {activeSegment === 'goals' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between px-1">
            <div>
              <h2 className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                Savings & Ipon Goals
              </h2>
            </div>
            <button
              type="button"
              onClick={() => setShowAddGoalModal(true)}
              className="flex items-center gap-1 px-3 py-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold shadow-xs hover:opacity-90 cursor-pointer"
            >
              <Plus size={14} /> Add Goal
            </button>
          </div>

          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl divide-y divide-[#F3DFCD] dark:divide-[#383029] shadow-xs overflow-hidden">
            {goals.map((goal) => {
              const percent = Math.min(100, Math.round((goal.currentAmount / goal.targetAmount) * 100));
              const isComplete = goal.currentAmount >= goal.targetAmount;

              return (
                <div
                  key={goal.id}
                  className={`p-4 hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D]/40 transition-colors ${
                    isComplete ? 'bg-emerald-500/5' : ''
                  }`}
                >
                  <div className="flex justify-between items-start mb-2">
                    <div className="flex items-center gap-2.5">
                      <span className="text-2xl">{goal.emoji}</span>
                      <div className="flex flex-col">
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {goal.name}
                        </span>
                        <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                          {isComplete
                            ? 'Goal Achieved! 🎉'
                            : `${formatPeso(goal.monthlyTarget)}/mo to reach by ${goal.targetDate}`}
                        </span>
                      </div>
                    </div>

                    <div className="flex flex-col items-end">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        {formatPeso(goal.currentAmount)}
                      </span>
                      <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                        of {formatPeso(goal.targetAmount)} ({percent}%)
                      </span>
                    </div>
                  </div>

                  {/* ThinBar */}
                  <div className="w-full h-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#14100D] overflow-hidden mb-2">
                    <div
                      className={`h-full rounded-full transition-all duration-300 ${
                        isComplete ? 'bg-[#16643F] dark:bg-[#5FCB8E]' : 'bg-[#B03C09] dark:bg-[#FF9A52]'
                      }`}
                      style={{ width: `${percent}%` }}
                    />
                  </div>

                  {!isComplete && (
                    <div className="flex justify-end pt-1">
                      <button
                        type="button"
                        onClick={() => {
                          setContributingGoal(goal);
                          setContribAmount('1000');
                        }}
                        className="text-xs font-bold px-3 py-1 rounded-lg bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#B03C09]/20 transition-colors cursor-pointer"
                      >
                        + Add Savings
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Edit Budget Limit Modal */}
      {editingBudget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 shadow-xl border border-[#F3DFCD] dark:border-[#383029]">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Adjust Limit for {editingBudget.emoji} {editingBudget.category}
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-4">
              Current cutoff spend: {formatPeso(editingBudget.spent || 0)}
            </p>

            <form onSubmit={handleSaveBudgetLimit} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  New Limit (₱)
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

              <div className="flex gap-2 pt-2">
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
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Add Savings to {contributingGoal.emoji} {contributingGoal.name}
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-4">
              Saved {formatPeso(contributingGoal.currentAmount)} of {formatPeso(contributingGoal.targetAmount)}
            </p>

            <form onSubmit={handleContribute} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] mb-1 block">
                  Contribution Amount (₱)
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

              <div className="grid grid-cols-2 gap-2">
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
    </div>
  );
};
