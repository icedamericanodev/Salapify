import React, { useState, useEffect } from 'react';
import {
  X,
  Calculator,
  Sparkles,
  Gift,
  Globe,
  Trash2,
  Plus,
  Coffee,
  Check,
  RefreshCw,
  FileText,
  ShieldCheck,
  CheckCircle2,
  ListTodo,
  ArrowRightLeft,
  Zap,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';

interface PhilippineFeaturesModalProps {
  isOpen: boolean;
  onClose: () => void;
  defaultTab?: 'calculator' | 'mindset' | 'treats' | 'fx';
}

interface TreatHabitItem {
  id: string;
  treatName: string;
  cost: number;
  healthyTask: string;
  isTaskDone: boolean;
  isClaimed: boolean;
}

export const PhilippineFeaturesModal: React.FC<PhilippineFeaturesModalProps> = ({
  isOpen,
  onClose,
  defaultTab = 'calculator',
}) => {
  const { addTransaction } = useFinancial();

  const [activeTab, setActiveTab] = useState<'calculator' | 'mindset' | 'treats' | 'fx'>(defaultTab);

  // --- TAB 1: SMART TEXT NOTES CALCULATOR ---
  const [notepadText, setNotepadText] = useState(
`ate 50
kuya 600
mama 6*8
electricity 1250
groceries 1850 + 450`
  );

  const parseNotesCalculator = (text: string) => {
    const lines = text.split('\n');
    let grandTotal = 0;
    const items: { lineText: string; label: string; expr: string; value: number; isValid: boolean }[] = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      const match = trimmed.match(/^(.*?)([\d\s+\-*/().]+)$/);
      if (match) {
        const label = match[1].trim() || 'Item';
        const expr = match[2].trim();
        try {
          const sanitizedExpr = expr.replace(/[^0-9+\-*/().]/g, '');
          const val = Function(`'use strict'; return (${sanitizedExpr})`)();
          const numericVal = typeof val === 'number' && !isNaN(val) ? val : 0;
          grandTotal += numericVal;
          items.push({
            lineText: trimmed,
            label,
            expr,
            value: numericVal,
            isValid: true,
          });
        } catch {
          items.push({
            lineText: trimmed,
            label: trimmed,
            expr: '',
            value: 0,
            isValid: false,
          });
        }
      } else {
        items.push({
          lineText: trimmed,
          label: trimmed,
          expr: '',
          value: 0,
          isValid: false,
        });
      }
    }

    return { items, grandTotal };
  };

  const parsedNotes = parseNotesCalculator(notepadText);

  // --- TAB 2: MONEY MINDSET (Impulse Buyer Pause) ---
  const [itemName, setItemName] = useState('Wireless Noise-Canceling Earbuds');
  const [itemPrice, setItemPrice] = useState('4500');
  const [monthlyIncome, setMonthlyIncome] = useState('35000');
  const [mindsetAnswers, setMindsetAnswers] = useState({
    needOrWant: 'want',
    useFrequency: 'weekly',
    cheaperAlternative: 'yes',
  });
  const [mindsetVerdict, setMindsetVerdict] = useState<string | null>(null);

  const numericPrice = parseFloat(itemPrice) || 0;
  const numericSalary = parseFloat(monthlyIncome) || 35000;
  const hourlyWage = numericSalary / 160;
  const hoursOfWork = hourlyWage > 0 ? (numericPrice / hourlyWage).toFixed(1) : '0';

  const handleEvaluateMindset = () => {
    let score = 0;
    if (mindsetAnswers.needOrWant === 'need') score += 40;
    else score += 10;

    if (mindsetAnswers.useFrequency === 'daily') score += 40;
    else if (mindsetAnswers.useFrequency === 'weekly') score += 30;
    else score += 10;

    if (mindsetAnswers.cheaperAlternative === 'no') score += 20;
    else score += 5;

    if (score >= 70) {
      setMindsetVerdict('🟢 GREEN LIGHT: This purchase aligns with your core utility. Still, try the 24-hour pause rule!');
    } else if (score >= 40) {
      setMindsetVerdict('🟡 YELLOW LIGHT: Moderate impulse risk. Consider waiting 48 hours or finding a budget-friendly alternative.');
    } else {
      setMindsetVerdict('🔴 RED LIGHT: High impulse risk! This item is likely an emotional itch. Walk away for 3 days.');
    }
  };

  // --- TAB 3: EARN YOUR TREATS (Healthy Habit & Task Pairing) ---
  const [treatsList, setTreatsList] = useState<TreatHabitItem[]>([
    {
      id: 't1',
      treatName: 'Iced Caramel Macchiato',
      cost: 180,
      healthyTask: 'Walk 5,000 steps & drink 2L water',
      isTaskDone: true,
      isClaimed: false,
    },
    {
      id: 't2',
      treatName: 'Samgyupsal Dinner with Friends',
      cost: 799,
      healthyTask: 'Review weekly budget & categorize all expenses',
      isTaskDone: false,
      isClaimed: false,
    },
    {
      id: 't3',
      treatName: 'New Running Shoes',
      cost: 2800,
      healthyTask: 'Complete 5 workouts this week without skipping',
      isTaskDone: false,
      isClaimed: false,
    },
  ]);
  const [showAddTreat, setShowAddTreat] = useState(false);
  const [newTreatName, setNewTreatName] = useState('');
  const [newTreatCost, setNewTreatCost] = useState('');
  const [newHealthyTask, setNewHealthyTask] = useState('');

  const handleAddTreat = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTreatName || !newHealthyTask) return;
    setTreatsList([
      {
        id: `t-${Date.now()}`,
        treatName: newTreatName.trim(),
        cost: parseFloat(newTreatCost) || 150,
        healthyTask: newHealthyTask.trim(),
        isTaskDone: false,
        isClaimed: false,
      },
      ...treatsList,
    ]);
    setNewTreatName('');
    setNewTreatCost('');
    setNewHealthyTask('');
    setShowAddTreat(false);
  };

  const toggleTaskDone = (id: string) => {
    setTreatsList(
      treatsList.map((t) => {
        if (t.id === id) {
          return { ...t, isTaskDone: !t.isTaskDone };
        }
        return t;
      })
    );
  };

  const claimTreatReward = (id: string) => {
    setTreatsList(
      treatsList.map((t) => {
        if (t.id === id && t.isTaskDone) {
          return { ...t, isClaimed: true };
        }
        return t;
      })
    );
  };

  // --- TAB 4: FOREIGN EXCHANGE CONVERTER ---
  const [fxAmount, setFxAmount] = useState('1000');
  const [fromCurrency, setFromCurrency] = useState('PHP');
  const [toCurrency, setToCurrency] = useState('USD');
  const [fxRates, setFxRates] = useState<Record<string, number>>({
    PHP: 1,
    USD: 0.018,
    JPY: 2.75,
    EUR: 0.016,
    SGD: 0.024,
    AED: 0.066,
    AUD: 0.027,
    CAD: 0.025,
  });
  const [isLoadingFx, setIsLoadingFx] = useState(false);
  const [fxApiStatus, setFxApiStatus] = useState('Using live exchange rates cache');

  const fetchLiveFxRates = async () => {
    setIsLoadingFx(true);
    setFxApiStatus('Fetching live rates from exchange rate API...');
    try {
      const res = await fetch('https://open.er-api.com/v6/latest/PHP');
      const data = await res.json();
      if (data && data.rates) {
        setFxRates(data.rates);
        setFxApiStatus('Successfully updated with live global FX rates!');
      }
    } catch {
      setFxApiStatus('Using robust built-in FX rates baseline.');
    } finally {
      setIsLoadingFx(false);
    }
  };

  useEffect(() => {
    fetchLiveFxRates();
  }, []);

  const parsedFxInput = parseFloat(fxAmount) || 0;
  const amountInPhp = fromCurrency === 'PHP' ? parsedFxInput : parsedFxInput / (fxRates[fromCurrency] || 1);
  const convertedAmount = toCurrency === 'PHP' ? amountInPhp : amountInPhp * (fxRates[toCurrency] || 1);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-3 sm:p-5 animate-fade-in">
      <div className="bg-[#FFFDF9] dark:bg-[#181310] border border-[#EFE2D5] dark:border-[#332A22] rounded-[28px] w-full max-w-2xl max-h-[92vh] flex flex-col shadow-2xl overflow-hidden">
        
        {/* Elite Modal Header */}
        <div className="px-5 py-4 border-b border-[#EFE2D5] dark:border-[#332A22] flex items-center justify-between bg-white dark:bg-[#201914] shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-[#FFEEDF] to-[#FCE2CE] dark:from-[#2B211A] dark:to-[#382B21] border border-[#F3DFCD] dark:border-[#423328] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shadow-xs">
              <Sparkles size={22} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-black tracking-tight text-[#15120F] dark:text-[#F6EFE8]">
                  Philippine Financial Toolkit
                </h2>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-[#B03C09]/10 text-[#B03C09] dark:bg-[#FF9A52]/15 dark:text-[#FF9A52]">
                  PRO EDITION
                </span>
              </div>
              <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D] font-medium">
                Mindful spending, smart text calculations, and habit rewards
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2.5 rounded-full hover:bg-black/5 dark:hover:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D] transition-colors cursor-pointer"
          >
            <X size={19} />
          </button>
        </div>

        {/* Gorgeous Tab Navigation */}
        <div className="grid grid-cols-4 gap-1 px-4 py-3 bg-[#F9F3EC] dark:bg-[#14100D] border-b border-[#EFE2D5] dark:border-[#332A22] shrink-0">
          <button
            type="button"
            onClick={() => setActiveTab('calculator')}
            className={`flex flex-col sm:flex-row items-center justify-center gap-1.5 py-2.5 px-2 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
              activeTab === 'calculator'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] shadow-md scale-[1.02]'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Calculator size={16} />
            <span className="truncate">Notes Calc</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('mindset')}
            className={`flex flex-col sm:flex-row items-center justify-center gap-1.5 py-2.5 px-2 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
              activeTab === 'mindset'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] shadow-md scale-[1.02]'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Zap size={16} />
            <span className="truncate">Mindset</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('treats')}
            className={`flex flex-col sm:flex-row items-center justify-center gap-1.5 py-2.5 px-2 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
              activeTab === 'treats'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] shadow-md scale-[1.02]'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Gift size={16} />
            <span className="truncate">Treats</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('fx')}
            className={`flex flex-col sm:flex-row items-center justify-center gap-1.5 py-2.5 px-2 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
              activeTab === 'fx'
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] shadow-md scale-[1.02]'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Globe size={16} />
            <span className="truncate">FX Rates</span>
          </button>
        </div>

        {/* Modal Body with Rich Polish */}
        <div className="flex-1 overflow-y-auto p-5 space-y-5">
          
          {/* TAB 1: SMART TEXT NOTES CALCULATOR */}
          {activeTab === 'calculator' && (
            <div className="space-y-4 animate-fade-in">
              <div className="p-4 rounded-2xl bg-gradient-to-br from-[#FFEEDF]/70 to-[#FCE2CE]/40 dark:from-[#271E17] dark:to-[#1E1712] border border-[#F3DFCD] dark:border-[#382D24] shadow-xs space-y-1.5">
                <div className="flex items-center gap-2 text-[#B03C09] dark:text-[#FF9A52] font-extrabold text-xs">
                  <FileText size={16} /> Smart Text Notes Calculator
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                  Type your notes line by line with labels and numbers or math formulas (e.g., <code className="bg-white/80 dark:bg-black/30 px-1.5 py-0.5 rounded font-mono font-bold text-[#B03C09] dark:text-[#FF9A52]">ate 50</code>, <code className="bg-white/80 dark:bg-black/30 px-1.5 py-0.5 rounded font-mono font-bold text-[#B03C09] dark:text-[#FF9A52]">mama 6*8</code>). The system automatically parses and computes your grand total instantly!
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Textarea Input */}
                <div className="bg-white dark:bg-[#201914] border border-[#EFE2D5] dark:border-[#332A22] rounded-2xl p-4 shadow-xs space-y-2.5 flex flex-col">
                  <label className="text-xs font-black uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8] flex items-center justify-between">
                    <span>Type Notes & Amounts</span>
                    <span className="text-[10px] font-semibold text-[#7A6E63] bg-black/5 dark:bg-white/5 px-2 py-0.5 rounded-full">Multi-line</span>
                  </label>
                  <textarea
                    rows={8}
                    value={notepadText}
                    onChange={(e) => setNotepadText(e.target.value)}
                    placeholder="ate 50&#10;kuya 600&#10;mama 6*8"
                    className="w-full flex-1 p-3.5 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-mono font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] resize-none shadow-inner"
                  />
                </div>

                {/* Live Parsed Output & Grand Total */}
                <div className="bg-white dark:bg-[#201914] border border-[#EFE2D5] dark:border-[#332A22] rounded-2xl p-4 shadow-xs space-y-3.5 flex flex-col justify-between">
                  <div className="space-y-3">
                    <div className="flex items-center justify-between border-b border-[#EFE2D5] dark:border-[#332A22] pb-2.5">
                      <h4 className="text-xs font-black uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
                        Auto-Computed Breakdown
                      </h4>
                      <span className="text-[11px] font-bold text-[#7A6E63] bg-[#FFEEDF] dark:bg-[#2B211A] px-2 py-0.5 rounded-lg text-[#B03C09] dark:text-[#FF9A52]">
                        {parsedNotes.items.length} items
                      </span>
                    </div>

                    <div className="space-y-2 max-h-48 overflow-y-auto no-scrollbar pr-1">
                      {parsedNotes.items.map((item, idx) => (
                        <div
                          key={idx}
                          className="flex items-center justify-between p-2.5 bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] rounded-xl text-xs font-mono shadow-xs"
                        >
                          <span className="text-[#15120F] dark:text-[#F6EFE8] font-bold truncate mr-2">
                            {item.label} {item.expr ? <span className="text-[#7A6E63] font-normal">({item.expr})</span> : ''}
                          </span>
                          <span className="font-black text-[#B03C09] dark:text-[#FF9A52] shrink-0">
                            {item.isValid ? formatPeso(item.value) : '—'}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="p-4 rounded-2xl bg-gradient-to-r from-[#B03C09] to-[#D45016] text-white shadow-md flex items-center justify-between">
                    <div>
                      <span className="text-[10px] uppercase font-bold tracking-widest opacity-90 block">Grand Total Sum</span>
                      <span className="text-xl font-black font-mono">
                        {formatPeso(parsedNotes.grandTotal)}
                      </span>
                    </div>
                    <div className="w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
                      <Calculator size={18} />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: MONEY MINDSET (Impulse Buyer Pause) */}
          {activeTab === 'mindset' && (
            <div className="space-y-4 animate-fade-in">
              <div className="bg-white dark:bg-[#201914] border border-[#EFE2D5] dark:border-[#332A22] rounded-2xl p-5 shadow-xs space-y-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-[#FFEEDF] to-[#FCE2CE] dark:from-[#2B211A] dark:to-[#382B21] border border-[#F3DFCD] dark:border-[#423328] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
                    <Zap size={22} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                      Impulse Buyer Decision Helper
                    </h3>
                    <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D]">
                      Pause before checkout and calculate the true work hours cost of your purchase.
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                      What are you eyeing to buy?
                    </label>
                    <input
                      type="text"
                      value={itemName}
                      onChange={(e) => setItemName(e.target.value)}
                      className="w-full px-4 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                      Item Price (₱)
                    </label>
                    <input
                      type="number"
                      value={itemPrice}
                      onChange={(e) => setItemPrice(e.target.value)}
                      className="w-full px-4 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                    Your Approximate Monthly Income (₱)
                  </label>
                  <input
                    type="number"
                    value={monthlyIncome}
                    onChange={(e) => setMonthlyIncome(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                  />
                  <div className="mt-2 p-3 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#271E17] border border-[#F3DFCD] dark:border-[#382D24] text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
                    💡 True Work Cost: {hoursOfWork} hours of work based on your monthly income!
                  </div>
                </div>

                {/* Reflection Quiz */}
                <div className="pt-3 border-t border-[#EFE2D5] dark:border-[#332A22] space-y-3">
                  <h4 className="text-xs font-black uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
                    Quick Mindset Reflection Quiz:
                  </h4>
                  <div className="space-y-2.5 text-xs">
                    <div className="flex justify-between items-center bg-[#FFFDF9] dark:bg-[#14100D] p-3 rounded-xl border border-[#EFE2D5] dark:border-[#332A22]">
                      <span className="text-[#7A6E63] dark:text-[#A89A8D] font-medium">Is this a strict necessity or a want?</span>
                      <select
                        value={mindsetAnswers.needOrWant}
                        onChange={(e) => setMindsetAnswers({ ...mindsetAnswers, needOrWant: e.target.value })}
                        className="bg-transparent font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        <option value="want">Just a Want</option>
                        <option value="need">True Need</option>
                      </select>
                    </div>

                    <div className="flex justify-between items-center bg-[#FFFDF9] dark:bg-[#14100D] p-3 rounded-xl border border-[#EFE2D5] dark:border-[#332A22]">
                      <span className="text-[#7A6E63] dark:text-[#A89A8D] font-medium">How often will you use it?</span>
                      <select
                        value={mindsetAnswers.useFrequency}
                        onChange={(e) => setMindsetAnswers({ ...mindsetAnswers, useFrequency: e.target.value })}
                        className="bg-transparent font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        <option value="rarely">Rarely / Once</option>
                        <option value="weekly">Once a Week</option>
                        <option value="daily">Every Single Day</option>
                      </select>
                    </div>

                    <div className="flex justify-between items-center bg-[#FFFDF9] dark:bg-[#14100D] p-3 rounded-xl border border-[#EFE2D5] dark:border-[#332A22]">
                      <span className="text-[#7A6E63] dark:text-[#A89A8D] font-medium">Can you find a cheaper alternative?</span>
                      <select
                        value={mindsetAnswers.cheaperAlternative}
                        onChange={(e) => setMindsetAnswers({ ...mindsetAnswers, cheaperAlternative: e.target.value })}
                        className="bg-transparent font-extrabold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        <option value="yes">Yes, easily</option>
                        <option value="no">No, this is the best value</option>
                      </select>
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={handleEvaluateMindset}
                    className="w-full py-3 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] text-xs font-black uppercase tracking-wider cursor-pointer hover:opacity-95 transition-all shadow-md"
                  >
                    Evaluate Purchase Verdict
                  </button>

                  {mindsetVerdict && (
                    <div className="p-4 rounded-xl bg-gradient-to-r from-[#FFEEDF] to-[#FCE2CE] dark:from-[#2B211A] dark:to-[#382B21] border border-[#F3DFCD] dark:border-[#423328] text-xs font-extrabold text-[#15120F] dark:text-[#F6EFE8] animate-fade-in shadow-xs">
                      {mindsetVerdict}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* TAB 3: EARN YOUR TREATS (Healthy Habit & Task Pairing) */}
          {activeTab === 'treats' && (
            <div className="space-y-4 animate-fade-in">
              {/* Rule Explainer Banner */}
              <div className="p-4 rounded-2xl bg-gradient-to-br from-[#FFEEDF] to-[#FCE2CE] dark:from-[#271E17] dark:to-[#1E1712] border border-[#F3DFCD] dark:border-[#382D24] shadow-xs space-y-1.5">
                <div className="flex items-center gap-2 text-[#B03C09] dark:text-[#FF9A52] font-black text-xs">
                  <ShieldCheck size={17} /> Earn Your Treats (Habit & Task Pairing Rule)
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                  Pair a small treat with a healthy habit or important task. <strong>Complete the healthy task first</strong> (e.g. walking, budgeting, working out), check it off, and your reward treat is officially unlocked and earned!
                </p>
              </div>

              <div className="flex items-center justify-between pt-1">
                <h3 className="text-xs font-black uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">
                  Treat & Habit Pairs ({treatsList.length})
                </h3>
                <button
                  type="button"
                  onClick={() => setShowAddTreat(!showAddTreat)}
                  className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#160D05] text-xs font-bold cursor-pointer hover:opacity-90 transition-all shadow-xs"
                >
                  <Plus size={15} />
                  <span>Add Treat Pair</span>
                </button>
              </div>

              {showAddTreat && (
                <form onSubmit={handleAddTreat} className="bg-white dark:bg-[#201914] border border-[#EFE2D5] dark:border-[#332A22] rounded-2xl p-4 shadow-md space-y-3 animate-fade-in">
                  <h4 className="text-xs font-black uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8]">Create New Treat & Habit Pair</h4>
                  <div className="space-y-2.5">
                    <input
                      type="text"
                      value={newTreatName}
                      onChange={(e) => setNewTreatName(e.target.value)}
                      placeholder="Treat / Reward Name (e.g. Iced Latte)..."
                      className="w-full px-4 py-2.5 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                    <input
                      type="text"
                      value={newHealthyTask}
                      onChange={(e) => setNewHealthyTask(e.target.value)}
                      placeholder="Paired Healthy Task / Habit (e.g. Walk 5,000 steps)..."
                      className="w-full px-4 py-2.5 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                    <input
                      type="number"
                      value={newTreatCost}
                      onChange={(e) => setNewTreatCost(e.target.value)}
                      placeholder="Estimated Cost in PHP (e.g. 180)..."
                      className="w-full px-4 py-2.5 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>
                  <div className="flex justify-end gap-2 pt-1">
                    <button
                      type="button"
                      onClick={() => setShowAddTreat(false)}
                      className="px-4 py-2 rounded-xl text-xs font-bold text-[#7A6E63] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      className="px-5 py-2 rounded-xl bg-[#B03C09] text-white text-xs font-black uppercase tracking-wider cursor-pointer shadow-xs"
                    >
                      Save Pair
                    </button>
                  </div>
                </form>
              )}

              {/* Treats & Habits Cards List */}
              <div className="space-y-3">
                {treatsList.map((treat) => (
                  <div
                    key={treat.id}
                    className={`bg-white dark:bg-[#201914] border rounded-2xl p-4 shadow-xs space-y-3 transition-all ${
                      treat.isClaimed
                        ? 'border-emerald-500/50 bg-emerald-500/5'
                        : treat.isTaskDone
                        ? 'border-[#B03C09]/50 dark:border-[#FF9A52]/50 shadow-sm'
                        : 'border-[#EFE2D5] dark:border-[#332A22]'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex items-start gap-3">
                        <div className={`w-10 h-10 rounded-2xl flex items-center justify-center shrink-0 mt-0.5 shadow-xs ${
                          treat.isClaimed ? 'bg-emerald-500/15 text-emerald-600' : 'bg-gradient-to-br from-[#FFEEDF] to-[#FCE2CE] dark:from-[#2B211A] dark:to-[#382B21] text-[#B03C09] dark:text-[#FF9A52]'
                        }`}>
                          <Coffee size={20} />
                        </div>
                        <div className="space-y-1">
                          <h4 className="text-xs sm:text-sm font-black text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-2 flex-wrap">
                            {treat.treatName}
                            <span className="text-[11px] font-mono font-black px-2 py-0.5 rounded-lg bg-[#FFEEDF] dark:bg-[#2B211A] text-[#B03C09] dark:text-[#FF9A52]">
                              {formatPeso(treat.cost)}
                            </span>
                          </h4>
                          <div className="flex items-center gap-1.5 text-xs font-semibold text-[#7A6E63] dark:text-[#A89A8D]">
                            <ListTodo size={14} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
                            <span>Task: <strong className="text-[#15120F] dark:text-[#F6EFE8]">{treat.healthyTask}</strong></span>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        <button
                          type="button"
                          onClick={() => setTreatsList(treatsList.filter((t) => t.id !== treat.id))}
                          className="p-1.5 text-rose-500 hover:opacity-80 cursor-pointer"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </div>

                    {/* Task Completion & Claim Action Bar */}
                    <div className="pt-3 border-t border-[#EFE2D5] dark:border-[#332A22] flex items-center justify-between gap-2 flex-wrap">
                      <button
                        type="button"
                        onClick={() => toggleTaskDone(treat.id)}
                        className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold cursor-pointer transition-colors ${
                          treat.isTaskDone
                            ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30'
                            : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/10'
                        }`}
                      >
                        <CheckCircle2 size={16} className={treat.isTaskDone ? 'text-emerald-600' : ''} />
                        <span>{treat.isTaskDone ? 'Healthy Task Completed ✓' : 'Mark Task as Done'}</span>
                      </button>

                      {!treat.isClaimed && treat.isTaskDone && (
                        <button
                          type="button"
                          onClick={() => claimTreatReward(treat.id)}
                          className="px-4 py-2 rounded-xl bg-emerald-600 text-white text-xs font-black uppercase tracking-wider hover:bg-emerald-700 cursor-pointer animate-bounce shadow-md"
                        >
                          Claim Reward! 🎉
                        </button>
                      )}

                      {treat.isClaimed && (
                        <span className="px-3.5 py-1.5 rounded-xl bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 text-xs font-black tracking-wide">
                          Reward Claimed! 🌟
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 4: FOREIGN EXCHANGE CONVERTER */}
          {activeTab === 'fx' && (
            <div className="space-y-4 animate-fade-in">
              <div className="bg-white dark:bg-[#201914] border border-[#EFE2D5] dark:border-[#332A22] rounded-2xl p-5 shadow-xs space-y-4">
                <div className="flex items-center justify-between gap-2 flex-wrap">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-[#FFEEDF] to-[#FCE2CE] dark:from-[#2B211A] dark:to-[#382B21] border border-[#F3DFCD] dark:border-[#423328] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
                      <Globe size={22} />
                    </div>
                    <div>
                      <h3 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                        Live Foreign Exchange Converter
                      </h3>
                      <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D]">
                        {fxApiStatus}
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={fetchLiveFxRates}
                    disabled={isLoadingFx}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-[#FFEEDF] dark:bg-[#2B211A] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold hover:opacity-85 cursor-pointer transition-opacity shadow-xs"
                    title="Refresh FX Rates"
                  >
                    <RefreshCw size={14} className={isLoadingFx ? 'animate-spin' : ''} />
                    <span>Refresh Rates</span>
                  </button>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                      Amount
                    </label>
                    <input
                      type="number"
                      value={fxAmount}
                      onChange={(e) => setFxAmount(e.target.value)}
                      className="w-full px-4 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-sm font-black text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                        From
                      </label>
                      <select
                        value={fromCurrency}
                        onChange={(e) => setFromCurrency(e.target.value)}
                        className="w-full px-3.5 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        {Object.keys(fxRates).map((curr) => (
                          <option key={curr} value={curr}>{curr}</option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D] block mb-1.5">
                        To
                      </label>
                      <select
                        value={toCurrency}
                        onChange={(e) => setToCurrency(e.target.value)}
                        className="w-full px-3.5 py-3 rounded-xl bg-[#FFFDF9] dark:bg-[#14100D] border border-[#EFE2D5] dark:border-[#332A22] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        {Object.keys(fxRates).map((curr) => (
                          <option key={curr} value={curr}>{curr}</option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>

                {/* Conversion Result Box */}
                <div className="p-5 rounded-2xl bg-gradient-to-r from-[#B03C09] to-[#D45016] text-white shadow-md flex items-center justify-between">
                  <div>
                    <span className="text-[10px] uppercase font-bold tracking-widest opacity-90 block">
                      Converted Total
                    </span>
                    <span className="text-xl sm:text-2xl font-black font-mono">
                      {toCurrency === 'PHP' ? formatPeso(convertedAmount) : `${toCurrency} ${convertedAmount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`}
                    </span>
                  </div>
                  <div className="text-right text-xs font-semibold opacity-90">
                    1 {fromCurrency} = <br/>
                    <span className="font-mono font-bold">
                      {((fxRates[toCurrency] || 1) / (fxRates[fromCurrency] || 1)).toFixed(4)} {toCurrency}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}

        </div>

        {/* Elite Modal Footer */}
        <div className="px-5 py-3.5 border-t border-[#EFE2D5] dark:border-[#332A22] bg-white/60 dark:bg-[#201914]/60 flex justify-end shrink-0">
          <button
            type="button"
            onClick={onClose}
            className="px-6 py-2.5 rounded-xl bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] text-xs font-black uppercase tracking-wider cursor-pointer hover:opacity-90 transition-all shadow-sm"
          >
            Close Toolkit
          </button>
        </div>

      </div>
    </div>
  );
};
