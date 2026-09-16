import React, { useState, useMemo } from 'react';
import {
  Calculator,
  Home,
  CreditCard,
  Car,
  Briefcase,
  Layers,
  Scale,
  Sparkles,
  AlertTriangle,
  CheckCircle2,
  Clock,
  ArrowRight,
  Info,
  ShieldCheck,
  TrendingDown,
  Percent,
  Landmark,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import {
  calculatePagIbigHousingLoan,
  calculateBankHousingLoan,
  calculateCarLoan,
  calculateSalaryLoan,
  calculatePersonalLoan,
  calculateBusinessLoan,
  calculateDebtConsolidation,
  calculateAmortization,
  calculateCreditCardPayoff,
  simulateDebtStrategies,
  calculateDSR,
} from '../utils/loanCalculators';
import { BankAmortizationTable } from './BankAmortizationTable';

export const DebtCalculatorsView: React.FC = () => {
  const { debts, safeToSpendAnalysis } = useFinancial();

  type CalculatorType =
    | 'pagibig'
    | 'bank_housing'
    | 'car'
    | 'salary_loan'
    | 'personal'
    | 'creditcard'
    | 'consolidation'
    | 'strategy'
    | 'dsr';

  const [activeCalc, setActiveCalc] = useState<CalculatorType>('pagibig');

  // --- 1. PAG-IBIG State ---
  const [pagIbigProgram, setPagIbigProgram] = useState<'regular_housing' | 'affordable_housing'>('regular_housing');
  const [pagIbigAmount, setPagIbigAmount] = useState('1500000');
  const [pagIbigYears, setPagIbigYears] = useState('20');
  const [pagIbigFixing, setPagIbigFixing] = useState<3 | 1 | 5 | 10>(3);
  const [pagIbigExtra, setPagIbigExtra] = useState('1000');

  const pagIbigResult = useMemo(() => {
    const amt = parseFloat(pagIbigAmount) || 0;
    const yrs = parseInt(pagIbigYears, 10) || 15;
    const extra = parseFloat(pagIbigExtra) || 0;
    return calculatePagIbigHousingLoan({
      program: pagIbigProgram,
      loanAmount: amt,
      termYears: yrs,
      fixingPeriodYears: pagIbigFixing,
      extraMonthlyPayment: extra,
    });
  }, [pagIbigProgram, pagIbigAmount, pagIbigYears, pagIbigFixing, pagIbigExtra]);

  // --- 2. Bank Housing Loan State ---
  const [bankPropValue, setBankPropValue] = useState('3500000');
  const [bankDownPct, setBankDownPct] = useState('20');
  const [bankYears, setBankYears] = useState('15');
  const [bankFixedRate, setBankFixedRate] = useState('6.75');
  const [bankRepricedRate, setBankRepricedRate] = useState('8.50');
  const [bankExtraPayment, setBankExtraPayment] = useState('2000');

  const bankHousingResult = useMemo(() => {
    return calculateBankHousingLoan({
      propertyValue: parseFloat(bankPropValue) || 0,
      downpaymentPercent: parseFloat(bankDownPct) || 20,
      termYears: parseInt(bankYears, 10) || 15,
      fixedRate: parseFloat(bankFixedRate) || 6.75,
      repricedRate: parseFloat(bankRepricedRate) || 8.5,
      extraMonthlyPayment: parseFloat(bankExtraPayment) || 0,
    });
  }, [bankPropValue, bankDownPct, bankYears, bankFixedRate, bankRepricedRate, bankExtraPayment]);

  // --- 3. Car Loan State ---
  const [carPrice, setCarPrice] = useState('1100000');
  const [carDownPct, setCarDownPct] = useState('20');
  const [carMonths, setCarMonths] = useState('60');
  const [carRate, setCarRate] = useState('9.5'); // Flat add-on annual
  const [carRateType, setCarRateType] = useState<'flat_addon' | 'diminishing'>('flat_addon');
  const [carIncludeFees, setCarIncludeFees] = useState(true);

  const carResult = useMemo(() => {
    return calculateCarLoan({
      vehiclePrice: parseFloat(carPrice) || 0,
      downpaymentPercent: parseFloat(carDownPct) || 20,
      termMonths: parseInt(carMonths, 10) || 60,
      annualInterestRate: parseFloat(carRate) || 9.5,
      rateType: carRateType,
      includeInsuranceAndChattel: carIncludeFees,
    });
  }, [carPrice, carDownPct, carMonths, carRate, carRateType, carIncludeFees]);

  // --- 4. Salary Loan State (SSS / Pag-IBIG) ---
  const [salaryLoanType, setSalaryLoanType] = useState<'sss_salary' | 'pagibig_mpl' | 'pagibig_calamity'>('pagibig_mpl');
  const [salaryLoanAmount, setSalaryLoanAmount] = useState('50000');
  const [salaryLoanMonths, setSalaryLoanMonths] = useState('24');

  const salaryLoanResult = useMemo(() => {
    return calculateSalaryLoan({
      loanType: salaryLoanType,
      loanAmount: parseFloat(salaryLoanAmount) || 0,
      termMonths: parseInt(salaryLoanMonths, 10) || 24,
    });
  }, [salaryLoanType, salaryLoanAmount, salaryLoanMonths]);

  // --- 5. Personal Loan State ---
  const [personalPrincipal, setPersonalPrincipal] = useState('100000');
  const [personalRateMonth, setPersonalRateMonth] = useState('1.49');
  const [personalMonths, setPersonalMonths] = useState('24');
  const [personalFee, setPersonalFee] = useState('1500');

  const personalResult = useMemo(() => {
    return calculatePersonalLoan({
      principal: parseFloat(personalPrincipal) || 0,
      monthlyAddOnRate: parseFloat(personalRateMonth) || 1.49,
      termMonths: parseInt(personalMonths, 10) || 24,
      processingFee: parseFloat(personalFee) || 0,
    });
  }, [personalPrincipal, personalRateMonth, personalMonths, personalFee]);

  // --- 6. Credit Card State ---
  const [ccBalance, setCcBalance] = useState('45000');
  const [ccRate, setCcRate] = useState('3.0'); // 3% monthly BSP cap
  const [ccFixedPayment, setCcFixedPayment] = useState('2500');

  const ccMinResult = useMemo(() => {
    const bal = parseFloat(ccBalance) || 0;
    const rate = parseFloat(ccRate) || 3.0;
    return calculateCreditCardPayoff({
      currentBalance: bal,
      monthlyInterestRate: rate,
      paymentStrategy: 'minimum_only',
    });
  }, [ccBalance, ccRate]);

  const ccAcceleratedResult = useMemo(() => {
    const bal = parseFloat(ccBalance) || 0;
    const rate = parseFloat(ccRate) || 3.0;
    const pmt = parseFloat(ccFixedPayment) || 1500;
    return calculateCreditCardPayoff({
      currentBalance: bal,
      monthlyInterestRate: rate,
      paymentStrategy: 'fixed_amount',
      fixedMonthlyPayment: pmt,
    });
  }, [ccBalance, ccRate, ccFixedPayment]);

  const ccInterestSaved = Math.max(0, ccMinResult.totalInterestPaid - ccAcceleratedResult.totalInterestPaid);
  const ccMonthsSaved = Math.max(0, ccMinResult.monthsToPayoff - ccAcceleratedResult.monthsToPayoff);

  // --- 7. Debt Consolidation State ---
  const [consoNewRate, setConsoNewRate] = useState('1.2');
  const [consoNewTerm, setConsoNewTerm] = useState('24');

  const debtsForConsolidation = useMemo(() => {
    const debtsIOwe = debts.filter((d) => d.direction === 'i_owe' && !d.isSettled);
    if (debtsIOwe.length > 0) {
      return debtsIOwe.map((d) => ({
        id: d.id,
        name: d.person,
        balance: d.totalAmount - d.paidAmount,
        monthlyInterestRate: d.person.toLowerCase().includes('card') ? 3.0 : 2.0,
        currentMonthlyPayment: Math.max(850, Math.round((d.totalAmount - d.paidAmount) * 0.05)),
      }));
    }
    return [
      { id: '1', name: 'Credit Card 1 (BDO)', balance: 45000, monthlyInterestRate: 3.0, currentMonthlyPayment: 2250 },
      { id: '2', name: 'Credit Card 2 (BPI)', balance: 30000, monthlyInterestRate: 3.0, currentMonthlyPayment: 1500 },
      { id: '3', name: 'Shopee SPayLater', balance: 15000, monthlyInterestRate: 2.5, currentMonthlyPayment: 1200 },
    ];
  }, [debts]);

  const consolidationResult = useMemo(() => {
    return calculateDebtConsolidation(
      debtsForConsolidation,
      parseFloat(consoNewRate) || 1.2,
      parseInt(consoNewTerm, 10) || 24
    );
  }, [debtsForConsolidation, consoNewRate, consoNewTerm]);

  // --- 8. Snowball vs Avalanche State ---
  const [extraDebtBudget, setExtraDebtBudget] = useState('3000');

  const strategyDebts = useMemo(() => {
    const debtsIOwe = debts.filter((d) => d.direction === 'i_owe' && !d.isSettled);
    if (debtsIOwe.length > 0) {
      return debtsIOwe.map((d) => ({
        id: d.id,
        name: d.person,
        balance: d.totalAmount - d.paidAmount,
        interestRate: d.person.toLowerCase().includes('card') ? 36 : d.person.toLowerCase().includes('loan') ? 18 : 0,
        minimumPayment: Math.max(500, Math.round((d.totalAmount - d.paidAmount) * 0.05)),
      }));
    }
    return [
      { id: '1', name: 'BDO Credit Card', balance: 35000, interestRate: 36, minimumPayment: 1500 },
      { id: '2', name: 'Shopee SPayLater', balance: 8500, interestRate: 24, minimumPayment: 850 },
      { id: '3', name: 'Pahiram kay Kuya', balance: 15000, interestRate: 0, minimumPayment: 1000 },
    ];
  }, [debts]);

  const strategyResult = useMemo(() => {
    const extra = parseFloat(extraDebtBudget) || 0;
    return simulateDebtStrategies(strategyDebts, extra);
  }, [strategyDebts, extraDebtBudget]);

  // --- 9. DSR & Affordability Checker State ---
  const [grossIncome, setGrossIncome] = useState('55000');
  const [existingMonthlyDebt, setExistingMonthlyDebt] = useState('12000');

  const dsrResult = useMemo(() => {
    return calculateDSR(
      parseFloat(existingMonthlyDebt) || 0,
      parseFloat(grossIncome) || 0
    );
  }, [grossIncome, existingMonthlyDebt]);

  const calculatorTabs: { id: CalculatorType; label: string; icon: any }[] = [
    { id: 'pagibig', label: 'PAG-IBIG Housing', icon: Home },
    { id: 'bank_housing', label: 'Bank Housing', icon: Landmark },
    { id: 'car', label: 'Auto / Car', icon: Car },
    { id: 'salary_loan', label: 'SSS & Pag-IBIG Salary', icon: Briefcase },
    { id: 'personal', label: 'Personal / Digital', icon: CreditCard },
    { id: 'creditcard', label: 'BSP 3% CC Trap', icon: AlertTriangle },
    { id: 'consolidation', label: 'Debt Consolidation', icon: Layers },
    { id: 'strategy', label: 'Snowball / Avalanche', icon: Sparkles },
    { id: 'dsr', label: 'DSR & Capacity', icon: Scale },
  ];

  return (
    <div className="space-y-4">
      {/* Scrollable Sub-Tabs */}
      <div className="flex p-1.5 bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] overflow-x-auto gap-1.5 no-scrollbar">
        {calculatorTabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeCalc === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveCalc(tab.id)}
              className={`flex items-center gap-1.5 py-2 px-3 text-xs font-bold rounded-xl whitespace-nowrap transition-all cursor-pointer shrink-0 ${
                isActive
                  ? 'bg-[#B03C09] text-white shadow-xs'
                  : 'text-[#7A6E63] dark:text-[#A89A8D] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
              }`}
            >
              <Icon size={14} className="shrink-0" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* --- 1. PAG-IBIG HOUSING CALCULATOR --- */}
      {activeCalc === 'pagibig' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Pag-IBIG Fund Housing Loan Simulator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Calibrated to official Pag-IBIG circular interest tiers &amp; fixing periods
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Program</label>
              <select
                value={pagIbigProgram}
                onChange={(e) => setPagIbigProgram(e.target.value as any)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="regular_housing">Regular Housing Loan</option>
                <option value="affordable_housing">Affordable Housing (3.0% Subsidized)</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Loan Amount (₱)</label>
              <input
                type="number"
                step="50000"
                value={pagIbigAmount}
                onChange={(e) => setPagIbigAmount(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Loan Term (Years)</label>
              <select
                value={pagIbigYears}
                onChange={(e) => setPagIbigYears(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="5">5 Years</option>
                <option value="10">10 Years</option>
                <option value="15">15 Years</option>
                <option value="20">20 Years</option>
                <option value="25">25 Years</option>
                <option value="30">30 Years</option>
              </select>
            </div>

            {pagIbigProgram === 'regular_housing' && (
              <div className="min-w-0">
                <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Fixing Period</label>
                <select
                  value={pagIbigFixing}
                  onChange={(e) => setPagIbigFixing(parseInt(e.target.value, 10) as any)}
                  className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
                >
                  <option value="1">1 Year (5.375%)</option>
                  <option value="3">3 Years (5.75%)</option>
                  <option value="5">5 Years (6.25%)</option>
                  <option value="10">10 Years (7.125%)</option>
                </select>
              </div>
            )}

            <div className="min-w-0 sm:col-span-2">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">
                Extra Monthly Principal Prepayment (₱)
              </label>
              <input
                type="number"
                step="500"
                value={pagIbigExtra}
                onChange={(e) => setPagIbigExtra(e.target.value)}
                placeholder="e.g. 1000"
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>
          </div>

          {/* Results Block */}
          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Estimated Monthly Amortization
                </span>
                <div className="text-xl font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums mt-0.5 break-words">
                  {formatPeso(pagIbigResult.monthlyPayment)}{' '}
                  <span className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D]">/ mo</span>
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Total Interest over Term
                </span>
                <div className="text-xl font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 break-words">
                  {formatPeso(pagIbigResult.totalInterest)}
                </div>
              </div>
            </div>

            {parseFloat(pagIbigExtra) > 0 && pagIbigResult.interestSavedWithExtra > 0 && (
              <div className="p-3 bg-emerald-50 dark:bg-emerald-950/40 rounded-xl border border-emerald-200 dark:border-emerald-800 text-xs text-emerald-800 dark:text-emerald-200 space-y-1">
                <div className="flex items-center gap-1.5 font-bold">
                  <Sparkles size={14} className="text-emerald-600 shrink-0" />
                  <span>Extra Prepayment Impact:</span>
                </div>
                <p className="leading-relaxed">
                  By adding <strong>{formatPeso(parseFloat(pagIbigExtra))}</strong> every month, you save approx.{' '}
                  <strong>{formatPeso(pagIbigResult.interestSavedWithExtra)}</strong> in interest and pay off your home{' '}
                  <strong>{Math.round(pagIbigResult.monthsSavedWithExtra / 12)} years earlier</strong>!
                </p>
              </div>
            )}
          </div>

          {/* Official Bank Amortization & Running Balance Schedule with Export */}
          <BankAmortizationTable
            title="Pag-IBIG Housing Loan Statement Breakdown"
            institution="Pag-IBIG Fund (HDMF Circular 449/450)"
            principal={parseFloat(pagIbigAmount) || 0}
            annualRate={pagIbigProgram === 'affordable_housing' ? 3.0 : (pagIbigFixing === 1 ? 5.375 : pagIbigFixing === 3 ? 5.75 : pagIbigFixing === 5 ? 6.25 : 7.125)}
            termLabel={`${pagIbigYears} Years (${parseInt(pagIbigYears, 10) * 12} Months)`}
            monthlyPayment={pagIbigResult.monthlyPayment}
            totalInterest={pagIbigResult.totalInterest}
            totalPayment={pagIbigResult.totalPayment}
            interestSaved={pagIbigResult.interestSavedWithExtra}
            monthsSaved={pagIbigResult.monthsSavedWithExtra}
            extraMonthlyPayment={parseFloat(pagIbigExtra) || 0}
            schedule={pagIbigResult.amortizationSchedule}
            notes="Pag-IBIG loans follow diminishing balance computation. Extra prepayments applied directly to principal reduce compound interest and accelerate your debt-freedom date."
          />
        </div>
      )}

      {/* --- 2. BANK HOUSING LOAN CALCULATOR --- */}
      {activeCalc === 'bank_housing' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Bank Housing Loan &amp; Repricing Stress Test
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Evaluates monthly payments during initial fixed period vs. potential interest rate jumps
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Total Property Price (₱)</label>
              <input
                type="number"
                step="100000"
                value={bankPropValue}
                onChange={(e) => setBankPropValue(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Downpayment (%)</label>
              <input
                type="number"
                step="5"
                value={bankDownPct}
                onChange={(e) => setBankDownPct(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Loan Term (Years)</label>
              <select
                value={bankYears}
                onChange={(e) => setBankYears(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="5">5 Years</option>
                <option value="10">10 Years</option>
                <option value="15">15 Years</option>
                <option value="20">20 Years</option>
                <option value="25">25 Years</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Initial Fixed Rate (% p.a.)</label>
              <input
                type="number"
                step="0.25"
                value={bankFixedRate}
                onChange={(e) => setBankFixedRate(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Stress Test Repriced Rate (%)</label>
              <input
                type="number"
                step="0.25"
                value={bankRepricedRate}
                onChange={(e) => setBankRepricedRate(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Extra Prepayment / mo (₱)</label>
              <input
                type="number"
                step="500"
                value={bankExtraPayment}
                onChange={(e) => setBankExtraPayment(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>
          </div>

          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Downpayment Cash Out
                </span>
                <div className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  {formatPeso(bankHousingResult.downpaymentAmount)}
                </div>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Financed Loan Principal
                </span>
                <div className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  {formatPeso(bankHousingResult.loanPrincipal)}
                </div>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Initial Monthly Payment
                </span>
                <div className="text-xl font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums break-words">
                  {formatPeso(bankHousingResult.monthlyPayment)}{' '}
                  <span className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D]">/ mo</span>
                </div>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  If Repriced to {bankRepricedRate}%
                </span>
                <div className="text-xl font-black text-rose-700 dark:text-rose-400 tabular-nums break-words">
                  {formatPeso(bankHousingResult.repricedMonthlyPayment)}{' '}
                  <span className="text-xs font-bold text-rose-600/80">/ mo</span>
                </div>
              </div>
            </div>

            {bankHousingResult.monthlyPaymentJump > 0 && (
              <div className="p-3 bg-amber-50 dark:bg-amber-950/40 rounded-xl border border-amber-200 dark:border-amber-900 text-xs text-amber-800 dark:text-amber-200 leading-relaxed">
                <strong>Repricing Buffer Warning:</strong> When your fixed rate period expires, your monthly payment could jump by <strong>+{formatPeso(bankHousingResult.monthlyPaymentJump)}/month</strong>. Make sure your Safe to Spend buffer accounts for this change.
              </div>
            )}
          </div>

          {/* Official Bank Housing Amortization Breakdown Table */}
          <BankAmortizationTable
            title="Commercial Bank Housing Loan Statement"
            institution="Philippine Universal Banking Standard (BPI/BDO/Metrobank)"
            principal={bankHousingResult.loanPrincipal}
            annualRate={bankFixedRate}
            termLabel={`${bankYears} Years (${parseInt(bankYears, 10) * 12} Months)`}
            monthlyPayment={bankHousingResult.monthlyPayment}
            totalInterest={bankHousingResult.totalInterest}
            totalPayment={bankHousingResult.totalPayment}
            interestSaved={bankHousingResult.interestSavedWithExtra}
            extraMonthlyPayment={parseFloat(bankExtraPayment) || 0}
            schedule={bankHousingResult.schedule}
            notes="Bank housing loans are repriced periodically after the initial fixed period (typically 3–5 years). Review your bank statement annual repricing disclosure."
          />
        </div>
      )}

      {/* --- 3. AUTO / CAR LOAN CALCULATOR --- */}
      {activeCalc === 'car' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Philippine Auto / Car Loan Calculator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Calculates flat add-on dealer quotes vs. bank diminishing balance with chattel &amp; insurance
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Vehicle SRP Price (₱)</label>
              <input
                type="number"
                step="50000"
                value={carPrice}
                onChange={(e) => setCarPrice(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Downpayment (%)</label>
              <input
                type="number"
                step="5"
                value={carDownPct}
                onChange={(e) => setCarDownPct(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Term (Months)</label>
              <select
                value={carMonths}
                onChange={(e) => setCarMonths(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="24">24 Months (2 Years)</option>
                <option value="36">36 Months (3 Years)</option>
                <option value="48">48 Months (4 Years)</option>
                <option value="60">60 Months (5 Years)</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Interest Rate Model</label>
              <select
                value={carRateType}
                onChange={(e) => setCarRateType(e.target.value as any)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="flat_addon">Flat Add-On (Standard Dealership)</option>
                <option value="diminishing">Diminishing Balance (Bank Auto Loan)</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Quoted Rate (% p.a.)</label>
              <input
                type="number"
                step="0.5"
                value={carRate}
                onChange={(e) => setCarRate(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0 flex items-center pt-2 sm:pt-6">
              <label className="flex items-center gap-2 cursor-pointer text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                <input
                  type="checkbox"
                  checked={carIncludeFees}
                  onChange={(e) => setCarIncludeFees(e.target.checked)}
                  className="rounded text-[#B03C09] cursor-pointer"
                />
                <span>Include Chattel &amp; Insurance</span>
              </label>
            </div>
          </div>

          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Estimated Monthly Amortization
                </span>
                <div className="text-xl font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums break-words">
                  {formatPeso(carResult.monthlyPayment)}{' '}
                  <span className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D]">/ mo</span>
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Total Initial Cash Out
                </span>
                <div className="text-xl font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums break-words">
                  {formatPeso(carResult.initialCashOut)}
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Loan Amount Financed
                </span>
                <div className="text-sm font-bold text-[#5A5148] dark:text-[#C6B8AC] tabular-nums truncate">
                  {formatPeso(carResult.loanPrincipal)}
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Total Interest Paid
                </span>
                <div className="text-sm font-bold text-[#5A5148] dark:text-[#C6B8AC] tabular-nums truncate">
                  {formatPeso(carResult.totalInterest)}
                </div>
              </div>
            </div>
          </div>

          {/* Auto Loan Amortization Schedule */}
          <BankAmortizationTable
            title="Auto / Car Loan Repayment Breakdown"
            institution={carRateType === 'flat_addon' ? 'Auto Dealership Flat Add-on' : 'Bank Auto Financing'}
            principal={carResult.loanPrincipal}
            annualRate={carRate}
            termLabel={`${carMonths} Months (${parseInt(carMonths, 10) / 12} Years)`}
            monthlyPayment={carResult.monthlyPayment}
            totalInterest={carResult.totalInterest}
            totalPayment={carResult.totalPayment}
            schedule={carResult.schedule}
            notes="Flat add-on rate applies interest across the full original principal. Diminishing balance applies interest only against the remaining unpaid principal."
          />
        </div>
      )}

      {/* --- 4. SALARY LOAN (SSS / PAG-IBIG) --- */}
      {activeCalc === 'salary_loan' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              SSS &amp; Pag-IBIG Salary / Multi-Purpose Loan
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Calculates net cash proceeds after processing fees and member dividend rebates
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Government Program</label>
              <select
                value={salaryLoanType}
                onChange={(e) => setSalaryLoanType(e.target.value as any)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="pagibig_mpl">Pag-IBIG Multi-Purpose Loan (10.5%)</option>
                <option value="sss_salary">SSS Salary Loan (10.0%)</option>
                <option value="pagibig_calamity">Pag-IBIG Calamity Loan (5.95%)</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Loan Amount (₱)</label>
              <input
                type="number"
                step="5000"
                value={salaryLoanAmount}
                onChange={(e) => setSalaryLoanAmount(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Term (Months)</label>
              <select
                value={salaryLoanMonths}
                onChange={(e) => setSalaryLoanMonths(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="24">24 Months (2 Years)</option>
                <option value="36">36 Months (3 Years)</option>
              </select>
            </div>

            <div className="min-w-0 flex flex-col justify-center">
              <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] block">Annual Interest</span>
              <span className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                {salaryLoanResult.annualRate}% p.a. Diminishing
              </span>
            </div>
          </div>

          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Net Cash Disbursed to Bank/E-Wallet
                </span>
                <div className="text-xl font-black text-emerald-700 dark:text-emerald-400 tabular-nums break-words">
                  {formatPeso(salaryLoanResult.netProceeds)}
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Salary Deduction / Amortization
                </span>
                <div className="text-xl font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums break-words">
                  {formatPeso(salaryLoanResult.monthlyPayment)}{' '}
                  <span className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D]">/ mo</span>
                </div>
              </div>
            </div>

            {salaryLoanType === 'pagibig_mpl' && (
              <div className="p-3 bg-emerald-50 dark:bg-emerald-950/40 rounded-xl border border-emerald-200 dark:border-emerald-800 text-xs text-emerald-800 dark:text-emerald-200 leading-relaxed">
                <strong>Pag-IBIG Member Advantage:</strong> Because you are a contributing member, approximately{' '}
                <strong>{formatPeso(salaryLoanResult.estimatedDividendRebate)}</strong> of the total interest paid will be credited back as annual dividend yields to your Regular Savings (HDMF)!
              </div>
            )}
          </div>

          {/* Salary Loan Schedule Breakdown */}
          <BankAmortizationTable
            title={`${salaryLoanType === 'pagibig_mpl' ? 'Pag-IBIG Multi-Purpose Loan (MPL)' : salaryLoanType === 'sss_salary' ? 'SSS Salary Loan' : 'Pag-IBIG Calamity Loan'} Statement`}
            institution={salaryLoanType === 'sss_salary' ? 'Social Security System (SSS)' : 'Pag-IBIG Fund (HDMF)'}
            principal={parseFloat(salaryLoanAmount) || 0}
            annualRate={salaryLoanResult.annualRate}
            termLabel={`${salaryLoanMonths} Months`}
            monthlyPayment={salaryLoanResult.monthlyPayment}
            totalInterest={salaryLoanResult.totalInterest}
            totalPayment={salaryLoanResult.totalPayment}
            schedule={salaryLoanResult.schedule}
            notes="Salary loan amortization deductions are remitted through monthly payroll deduction or over-the-counter bayad centers."
          />
        </div>
      )}

      {/* --- 5. PERSONAL / DIGITAL LOAN --- */}
      {activeCalc === 'personal' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Personal &amp; Digital Bank Loan Simulator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              For Maya Personal Loan, CIMB, Tonik Quick Loan, and BPI / UnionBank Personal Loans
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Loan Principal (₱)</label>
              <input
                type="number"
                step="10000"
                value={personalPrincipal}
                onChange={(e) => setPersonalPrincipal(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Monthly Add-On Rate (%)</label>
              <input
                type="number"
                step="0.1"
                value={personalRateMonth}
                onChange={(e) => setPersonalRateMonth(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
              <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] block mt-0.5">Typical range: 1.2% - 2.5% / mo</span>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Term (Months)</label>
              <select
                value={personalMonths}
                onChange={(e) => setPersonalMonths(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="6">6 Months</option>
                <option value="12">12 Months (1 Year)</option>
                <option value="18">18 Months</option>
                <option value="24">24 Months (2 Years)</option>
                <option value="36">36 Months (3 Years)</option>
              </select>
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Processing Fee (₱)</label>
              <input
                type="number"
                step="500"
                value={personalFee}
                onChange={(e) => setPersonalFee(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>
          </div>

          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Monthly Repayment
                </span>
                <div className="text-xl font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums break-words">
                  {formatPeso(personalResult.monthlyPayment)}{' '}
                  <span className="text-xs font-bold text-[#7A6E63] dark:text-[#A89A8D]">/ mo</span>
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Net Cash Received
                </span>
                <div className="text-xl font-black text-emerald-700 dark:text-emerald-400 tabular-nums break-words">
                  {formatPeso(personalResult.netCashReceived)}
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Total Interest Paid
                </span>
                <div className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  {formatPeso(personalResult.totalInterest)}
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Effective Annual Rate (EIR)
                </span>
                <div className="text-sm font-bold text-[#5A5148] dark:text-[#C6B8AC] truncate">
                  approx. {((parseFloat(personalRateMonth) || 1.49) * 1.8 * 12).toFixed(1)}% p.a.
                </div>
              </div>
            </div>
          </div>

          {/* Personal Loan Breakdown Table */}
          <BankAmortizationTable
            title="Personal / Digital Bank Loan Statement"
            institution="Digital Banking Flat Add-On Standard"
            principal={parseFloat(personalPrincipal) || 0}
            annualRate={((parseFloat(personalRateMonth) || 1.49) * 12).toFixed(2)}
            termLabel={`${personalMonths} Months`}
            monthlyPayment={personalResult.monthlyPayment}
            totalInterest={personalResult.totalInterest}
            totalPayment={personalResult.totalPayment}
            schedule={personalResult.schedule}
            notes="Add-on rate calculation means finance charge is computed on the initial loan amount over the entire duration."
          />
        </div>
      )}

      {/* --- 6. CREDIT CARD MINIMUM PAYMENT TRAP --- */}
      {activeCalc === 'creditcard' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Credit Card BSP Minimum Payment Trap Simulator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Exposing the compound finance charge trap under the BSP 3.0% monthly cap (Circular 1165)
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Statement Balance (₱)</label>
              <input
                type="number"
                value={ccBalance}
                onChange={(e) => setCcBalance(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Monthly Finance Charge (%)</label>
              <input
                type="number"
                step="0.1"
                value={ccRate}
                onChange={(e) => setCcRate(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
              <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] block mt-0.5">BSP Cap: 3.0% / mo (36% p.a.)</span>
            </div>

            <div className="min-w-0 sm:col-span-2">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">
                Accelerated Fixed Monthly Payment (₱)
              </label>
              <input
                type="number"
                step="200"
                value={ccFixedPayment}
                onChange={(e) => setCcFixedPayment(e.target.value)}
                placeholder="e.g. 2500"
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>
          </div>

          {/* Comparison Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            {/* Minimum Only (Trap) */}
            <div className="p-3.5 bg-rose-50 dark:bg-rose-950/40 rounded-2xl border border-rose-200 dark:border-rose-900 space-y-2 min-w-0">
              <div className="flex items-center gap-1.5 text-rose-700 dark:text-rose-300 font-bold">
                <AlertTriangle size={15} className="shrink-0" />
                <span>Paying Minimum Only</span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-rose-600 dark:text-rose-400 block leading-tight">Time to Debt-Free</span>
                <span className="text-lg font-black text-rose-800 dark:text-rose-200 block break-words">
                  {ccMinResult.monthsToPayoff >= 360 ? '30+ Years' : `${(ccMinResult.monthsToPayoff / 12).toFixed(1)} Years (${ccMinResult.monthsToPayoff} Mo.)`}
                </span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-rose-600 dark:text-rose-400 block leading-tight">Total Interest Paid</span>
                <span className="text-base font-black text-rose-800 dark:text-rose-200 tabular-nums block truncate">
                  {formatPeso(ccMinResult.totalInterestPaid)}
                </span>
              </div>
              <p className="text-[10px] text-rose-700 dark:text-rose-300 leading-relaxed">
                You pay more than double your initial balance in interest alone!
              </p>
            </div>

            {/* Accelerated Payoff */}
            <div className="p-3.5 bg-emerald-50 dark:bg-emerald-950/40 rounded-2xl border border-emerald-200 dark:border-emerald-800 space-y-2 min-w-0">
              <div className="flex items-center gap-1.5 text-emerald-700 dark:text-emerald-300 font-bold">
                <CheckCircle2 size={15} className="shrink-0" />
                <span>Fixed {formatPeso(parseFloat(ccFixedPayment) || 0)} / Mo.</span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-emerald-600 dark:text-emerald-400 block leading-tight">Time to Debt-Free</span>
                <span className="text-lg font-black text-emerald-800 dark:text-emerald-200 block break-words">
                  {(ccAcceleratedResult.monthsToPayoff / 12).toFixed(1)} Years ({ccAcceleratedResult.monthsToPayoff} Mo.)
                </span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-emerald-600 dark:text-emerald-400 block leading-tight">Total Interest Paid</span>
                <span className="text-base font-black text-emerald-800 dark:text-emerald-200 tabular-nums block truncate">
                  {formatPeso(ccAcceleratedResult.totalInterestPaid)}
                </span>
              </div>
              <div className="text-[10px] text-emerald-700 dark:text-emerald-300 font-bold pt-1 border-t border-emerald-200 dark:border-emerald-800 leading-snug">
                Saves {formatPeso(ccInterestSaved)} &amp; {Math.round(ccMonthsSaved / 12)} years!
              </div>
            </div>
          </div>

          {/* Credit Card Statement Breakdown Table */}
          <BankAmortizationTable
            title="Credit Card Accelerated Payoff Statement"
            institution="BSP Circular 1165 (3.0% Finance Charge Cap)"
            principal={parseFloat(ccBalance) || 0}
            annualRate={((parseFloat(ccRate) || 3.0) * 12).toFixed(1)}
            termLabel={`${ccAcceleratedResult.monthsToPayoff} Months`}
            monthlyPayment={parseFloat(ccFixedPayment) || 1500}
            totalInterest={ccAcceleratedResult.totalInterestPaid}
            totalPayment={ccAcceleratedResult.totalAmountPaid}
            interestSaved={ccInterestSaved}
            monthsSaved={ccMonthsSaved}
            schedule={ccAcceleratedResult.schedule.map((s) => ({
              period: s.month,
              dueDate: `Month ${s.month}`,
              scheduledPayment: s.payment,
              principalComponent: s.principal,
              interestComponent: s.interest,
              extraPayment: 0,
              remainingBalance: s.balance,
            }))}
            notes="Credit card finance charges compound monthly if unpaid. Accelerating payments cuts through the interest spiral."
          />
        </div>
      )}

      {/* --- 7. DEBT CONSOLIDATION CALCULATOR --- */}
      {activeCalc === 'consolidation' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Debt Consolidation Loan Calculator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Roll high-interest cards (3% / mo) into a single 1.2% personal consolidation loan
            </p>
          </div>

          <div className="p-3 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs">
            <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
              Active Unsettled Debts to Consolidate ({debtsForConsolidation.length}):
            </span>
            <div className="space-y-1">
              {debtsForConsolidation.map((d) => (
                <div key={d.id} className="flex justify-between items-center text-[#5A5148] dark:text-[#C6B8AC] gap-2">
                  <span className="truncate">{d.name}</span>
                  <span className="font-mono font-bold text-[#15120F] dark:text-[#F6EFE8] shrink-0 tabular-nums">
                    {formatPeso(d.balance)}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Consolidation Loan Rate (% / mo)</label>
              <input
                type="number"
                step="0.1"
                value={consoNewRate}
                onChange={(e) => setConsoNewRate(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">New Loan Term (Months)</label>
              <select
                value={consoNewTerm}
                onChange={(e) => setConsoNewTerm(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs"
              >
                <option value="12">12 Months (1 Year)</option>
                <option value="24">24 Months (2 Years)</option>
                <option value="36">36 Months (3 Years)</option>
              </select>
            </div>
          </div>

          <div className="p-4 bg-emerald-50 dark:bg-emerald-950/40 rounded-2xl border border-emerald-200 dark:border-emerald-800 space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-emerald-800 dark:text-emerald-300 block leading-tight">
                  New Single Monthly Payment
                </span>
                <div className="text-xl font-black text-emerald-900 dark:text-emerald-100 tabular-nums break-words">
                  {formatPeso(consolidationResult.newMonthlyPayment)}{' '}
                  <span className="text-xs font-bold text-emerald-800/80">/ mo</span>
                </div>
                <span className="text-[10px] text-emerald-700 dark:text-emerald-300 block mt-0.5 truncate">
                  Was {formatPeso(consolidationResult.totalCurrentMonthlyPayment)} / mo
                </span>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-emerald-800 dark:text-emerald-300 block leading-tight">
                  Monthly Cash Flow Relief
                </span>
                <div className="text-xl font-black text-emerald-700 dark:text-emerald-300 tabular-nums break-words">
                  +{formatPeso(consolidationResult.monthlyCashflowRelief)}{' '}
                  <span className="text-xs font-bold text-emerald-600/80">/ mo</span>
                </div>
              </div>
            </div>

            <div className="pt-2 border-t border-emerald-200 dark:border-emerald-800 text-xs text-emerald-900 dark:text-emerald-100 leading-relaxed">
              Total estimated interest saved through consolidation:{' '}
              <strong className="font-bold">{formatPeso(consolidationResult.totalInterestSavings)}</strong>!
            </div>
          </div>

          {/* Consolidation Loan Schedule */}
          {consolidationResult.totalBalance > 0 && (
            <BankAmortizationTable
              title="Consolidation Loan Repayment Statement"
              institution="Personal Consolidation Facility"
              principal={consolidationResult.totalBalance}
              annualRate={((parseFloat(consoNewRate) || 1.2) * 12).toFixed(1)}
              termLabel={`${consoNewTerm} Months (${parseInt(consoNewTerm, 10) / 12} Years)`}
              monthlyPayment={consolidationResult.newMonthlyPayment}
              totalInterest={consolidationResult.newTotalInterest}
              totalPayment={consolidationResult.totalPayment}
              interestSaved={consolidationResult.totalInterestSavings}
              schedule={consolidationResult.schedule}
              notes="Consolidating high-rate credit balances into a fixed single installment prevents multiple finance charges from compounding."
            />
          )}
        </div>
      )}

      {/* --- 8. SNOWBALL VS AVALANCHE STRATEGY --- */}
      {activeCalc === 'strategy' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Debt Snowball vs. Debt Avalanche Simulator
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Compare psychological quick wins vs. mathematically optimal interest savings
            </p>
          </div>

          <div className="text-xs space-y-2">
            <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D]">
              Extra Monthly Debt Payoff Budget (₱)
            </label>
            <input
              type="number"
              step="500"
              value={extraDebtBudget}
              onChange={(e) => setExtraDebtBudget(e.target.value)}
              placeholder="3000"
              className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
            />
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              Simulating across your {strategyDebts.length} active debt obligations.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            {/* Snowball */}
            <div className="p-3.5 bg-[#FFEEDF] dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-2.5 min-w-0">
              <div className="flex justify-between items-center gap-2">
                <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] text-sm truncate">
                  Debt Snowball
                </span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#B03C09]/10 text-[#B03C09] shrink-0 whitespace-nowrap">
                  Smallest First
                </span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">Months to Freedom</span>
                <div className="text-lg font-black text-[#15120F] dark:text-[#F6EFE8] truncate">
                  {strategyResult.snowball.monthsToDebtFreedom} Months
                </div>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">Total Interest Paid</span>
                <div className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  {formatPeso(strategyResult.snowball.totalInterestPaid)}
                </div>
              </div>
              <div className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D] leading-relaxed break-words">
                Payoff order: {strategyResult.snowball.orderOfPayoff.join(' → ')}
              </div>
            </div>

            {/* Avalanche */}
            <div className="p-3.5 bg-emerald-50 dark:bg-emerald-950/40 rounded-2xl border border-emerald-200 dark:border-emerald-800 space-y-2.5 min-w-0">
              <div className="flex justify-between items-center gap-2">
                <span className="font-bold text-emerald-800 dark:text-emerald-300 text-sm truncate">
                  Debt Avalanche
                </span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/60 dark:text-emerald-300 shrink-0 whitespace-nowrap">
                  Highest Rate First
                </span>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-emerald-700 dark:text-emerald-400 block leading-tight">Months to Freedom</span>
                <div className="text-lg font-black text-emerald-900 dark:text-emerald-100 truncate">
                  {strategyResult.avalanche.monthsToDebtFreedom} Months
                </div>
              </div>
              <div className="min-w-0">
                <span className="text-[10px] uppercase text-emerald-700 dark:text-emerald-400 block leading-tight">Total Interest Paid</span>
                <div className="text-base font-bold text-emerald-900 dark:text-emerald-100 tabular-nums truncate">
                  {formatPeso(strategyResult.avalanche.totalInterestPaid)}
                </div>
              </div>
              <div className="text-[10px] text-emerald-800 dark:text-emerald-300 leading-relaxed break-words">
                Payoff order: {strategyResult.avalanche.orderOfPayoff.join(' → ')}
              </div>
            </div>
          </div>

          {strategyResult.interestDifference > 0 && (
            <div className="p-3 bg-white dark:bg-[#1E1915] rounded-xl border border-[#F3DFCD] dark:border-[#383029] text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              <strong>Avalanche Advantage:</strong> The Avalanche strategy will save you{' '}
              <strong className="text-emerald-600 dark:text-emerald-400 font-bold">{formatPeso(strategyResult.interestDifference)}</strong>{' '}
              in interest compared to Snowball. However, Snowball delivers early motivational momentum!
            </div>
          )}
        </div>
      )}

      {/* --- 9. DSR & CAPACITY CHECKER --- */}
      {activeCalc === 'dsr' && (
        <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] p-4 sm:p-5 space-y-4 shadow-xs">
          <div>
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Debt-Service Ratio (DSR) &amp; Borrowing Capacity
            </h3>
            <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
              BSP prudential standard: <strong className="font-semibold">&lt; 30% Healthy</strong>, 30–40% Moderate, &gt; 40% High Risk
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Gross Monthly Income (₱)</label>
              <input
                type="number"
                step="5000"
                value={grossIncome}
                onChange={(e) => setGrossIncome(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>

            <div className="min-w-0">
              <label className="block font-semibold text-[#7A6E63] dark:text-[#A89A8D] mb-1">Total Monthly Debt Payments (₱)</label>
              <input
                type="number"
                step="1000"
                value={existingMonthlyDebt}
                onChange={(e) => setExistingMonthlyDebt(e.target.value)}
                className="w-full p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-xs tabular-nums"
              />
            </div>
          </div>

          <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1E1915] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="flex items-center justify-between gap-2">
              <div className="min-w-0 flex-1">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Current Debt-Service Ratio (DSR)
                </span>
                <div className="text-2xl font-black text-[#B03C09] dark:text-[#FF9A52] mt-0.5 tabular-nums">
                  {dsrResult.dsr}%
                </div>
              </div>

              <span
                className={`px-3 py-1 rounded-full text-xs font-bold shrink-0 ${
                  dsrResult.status === 'healthy'
                    ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300'
                    : dsrResult.status === 'moderate'
                    ? 'bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300'
                    : 'bg-rose-100 text-rose-800 dark:bg-rose-950/60 dark:text-rose-300'
                }`}
              >
                {dsrResult.status.toUpperCase()}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs pt-2 border-t border-[#F3DFCD] dark:border-[#383029]">
              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Max Recommended Monthly Debt (35%)
                </span>
                <div className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  {formatPeso(dsrResult.maxRecommendedMonthlyDebt)} / mo
                </div>
              </div>

              <div className="min-w-0">
                <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight">
                  Estimated Housing Loan Power
                </span>
                <div className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums truncate">
                  up to {formatPeso(dsrResult.maxBorrowingCapacity30Yr)}
                </div>
              </div>
            </div>

            <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              {dsrResult.advice}
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
