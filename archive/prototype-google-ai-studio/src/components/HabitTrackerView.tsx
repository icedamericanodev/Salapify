import React from 'react';
import { CheckCircle2, Circle, Flame, CalendarDays, TrendingUp, Trophy } from 'lucide-react';

export const HabitTrackerView: React.FC = () => {
  const habits = [
    { id: '1', name: 'Expense Logging', streak: 12, completedToday: true, type: 'daily' },
    { id: '2', name: 'No-Spend Day', streak: 2, completedToday: false, type: 'daily' },
    { id: '3', name: 'Weekly Review', streak: 4, completedToday: true, type: 'weekly' },
    { id: '4', name: 'Receipt Capture', streak: 5, completedToday: true, type: 'daily' },
    { id: '5', name: 'Reconciliation', streak: 1, completedToday: false, type: 'weekly' },
    { id: '6', name: 'Budget Review', streak: 8, completedToday: true, type: 'weekly' },
  ];

  const renderDays = () => {
    return Array.from({ length: 7 }).map((_, i) => (
      <div key={i} className="flex flex-col items-center gap-1">
        <span className="text-[9px] text-[#7A6E63] dark:text-[#A89A8D]">{['M','T','W','T','F','S','S'][i]}</span>
        <div className={`w-6 h-6 rounded-full flex items-center justify-center ${i < 5 ? 'bg-[#16643F] text-white dark:bg-[#5FCB8E] dark:text-[#14100D]' : 'bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]'}`}>
          {i < 5 && <CheckCircle2 size={12} />}
        </div>
      </div>
    ));
  };

  return (
    <div className="flex flex-col gap-4 pb-20">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">Financial Habits</h2>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">Build consistency in managing your money</p>
        </div>
      </div>

      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Trophy size={18} className="text-amber-500" />
            <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">Current Streak</span>
          </div>
          <span className="text-lg font-black text-amber-600 dark:text-amber-400">12 Days</span>
        </div>
        <div className="flex justify-between px-2 mb-2">
          {renderDays()}
        </div>
      </div>

      <div className="space-y-2">
        {habits.map(habit => (
          <div key={habit.id} className="flex items-center justify-between p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs">
            <div className="flex items-center gap-3">
              <button className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 transition-colors ${habit.completedToday ? 'bg-[#16643F] text-white dark:bg-[#5FCB8E] dark:text-[#14100D]' : 'bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#F3DFCD] dark:hover:bg-[#383029]'}`}>
                {habit.completedToday ? <CheckCircle2 size={18} /> : <Circle size={18} />}
              </button>
              <div>
                <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">{habit.name}</h4>
                <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] capitalize">{habit.type}</span>
              </div>
            </div>
            <div className="flex items-center gap-1 bg-amber-50 dark:bg-amber-950/30 px-2 py-1 rounded-lg">
              <Flame size={12} className="text-amber-600 dark:text-amber-400" />
              <span className="text-xs font-bold text-amber-700 dark:text-amber-400">{habit.streak}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
