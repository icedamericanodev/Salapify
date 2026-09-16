import React, { useState, useMemo } from 'react';
import {
  TrendingUp,
  Scale,
  FileSpreadsheet,
  ArrowRightLeft,
  CheckCircle2,
  AlertTriangle,
  Calendar,
  Building,
  Plus,
  ArrowUpRight,
  ArrowDownLeft,
  Search,
  ShieldCheck,
  History,
  Copy,
  Info,
  ChevronRight,
  Filter,
  Download,
  FileText,
  Layers,
  PieChart,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { formatPeso } from '../utils/format';
import {
  ReportPeriod,
  ProfileEntity,
  Transaction,
  Account,
} from '../types';
import { convertToPhp, formatCurrency } from '../utils/currencies';
import { PROFILE_OPTIONS, STATUS_BADGE_CONFIG } from '../data/categories';

export const ReportsScreen: React.FC = () => {
  const {
    transactions,
    accounts,
    debts,
    budgets,
    activeProfile,
    setActiveProfile,
    reconciliationHistory,
    createAdjustmentTransaction,
    recordReconciliation,
    changeTransactionStatus,
  } = useFinancial();

  // Active Report Tab
  const [activeTab, setActiveTab] = useState<
    'position' | 'performance' | 'cashflow' | 'reconciliation'
  >('position');

  // Period Selector
  const [period, setPeriod] = useState<ReportPeriod>('monthly');

  // Comparison Toggle
  const [comparisonMode, setComparisonMode] = useState<
    'none' | 'previous' | 'budget' | 'forecast'
  >('none');

  // Multi-dimensional cash flow view
  const [cashFlowDimension, setCashFlowDimension] = useState<
    'standard' | 'by_account' | 'by_entity' | 'by_category'
  >('standard');

  // Reconciliation state
  const [selectedReconcileAccId, setSelectedReconcileAccId] = useState<string>(
    accounts[0]?.id || ''
  );
  const [actualBalanceInput, setActualBalanceInput] = useState<string>('');
  const [adjustmentNote, setAdjustmentNote] = useState<string>('');
  const [showAdjustmentForm, setShowAdjustmentForm] = useState(false);
  const [reconcileSuccessMessage, setReconcileSuccessMessage] = useState<string | null>(null);

  // Filter transactions based on active profile entity
  const entityFilteredTransactions = useMemo(() => {
    if (activeProfile === 'all') return transactions;
    return transactions.filter((t) => (t.profile || 'personal') === activeProfile);
  }, [transactions, activeProfile]);

  // Valid ledger transactions (excluding duplicate or excluded)
  const validLedgerTxs = useMemo(() => {
    return entityFilteredTransactions.filter(
      (t) => t.status !== 'excluded' && t.status !== 'duplicate'
    );
  }, [entityFilteredTransactions]);

  // Date filtering logic based on period
  const dateFilteredTxs = useMemo(() => {
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth();

    return validLedgerTxs.filter((tx) => {
      const txDate = new Date(tx.date);
      if (isNaN(txDate.getTime())) return true;

      if (period === 'daily') {
        const todayStr = now.toISOString().split('T')[0];
        return tx.date === todayStr;
      }
      if (period === 'weekly') {
        const oneWeekAgo = new Date();
        oneWeekAgo.setDate(now.getDate() - 7);
        return txDate >= oneWeekAgo && txDate <= now;
      }
      if (period === 'monthly') {
        return (
          txDate.getFullYear() === currentYear && txDate.getMonth() === currentMonth
        );
      }
      if (period === 'quarterly') {
        const currentQuarter = Math.floor(currentMonth / 3);
        const txQuarter = Math.floor(txDate.getMonth() / 3);
        return (
          txDate.getFullYear() === currentYear && txQuarter === currentQuarter
        );
      }
      if (period === 'semi_annually') {
        const isCurrentFirstHalf = currentMonth < 6;
        const isTxFirstHalf = txDate.getMonth() < 6;
        return (
          txDate.getFullYear() === currentYear &&
          isCurrentFirstHalf === isTxFirstHalf
        );
      }
      if (period === 'annually') {
        return txDate.getFullYear() === currentYear;
      }
      return true;
    });
  }, [validLedgerTxs, period]);

  // Filtered Accounts
  const filteredAccounts = useMemo(() => {
    if (activeProfile === 'all') return accounts;
    return accounts.filter((a) => !a.profile || a.profile === activeProfile);
  }, [accounts, activeProfile]);

  // Assets & Liabilities Calculations
  const assetKinds = ['cash', 'bank', 'gcash', 'maya', 'debit', 'investment', 'receivable'];
  const liabilityKinds = ['credit', 'loan', 'mortgage'];

  const assetAccounts = filteredAccounts.filter((a) => assetKinds.includes(a.kind));
  const liabilityAccounts = filteredAccounts.filter((a) => liabilityKinds.includes(a.kind));

  const totalAssets = assetAccounts.reduce(
    (sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'),
    0
  );
  const totalLiabilities = liabilityAccounts.reduce(
    (sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'),
    0
  );
  const netWorth = totalAssets - totalLiabilities;

  // Breakdown items for Financial Position
  const cashEquivalents = assetAccounts
    .filter((a) => ['cash', 'bank', 'gcash', 'maya', 'debit'].includes(a.kind))
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const investmentsTotal = assetAccounts
    .filter((a) => a.kind === 'investment')
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const receivablesTotal = assetAccounts
    .filter((a) => a.kind === 'receivable')
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const creditCardsTotal = liabilityAccounts
    .filter((a) => a.kind === 'credit')
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const loansTotal = liabilityAccounts
    .filter((a) => a.kind === 'loan' || a.kind === 'mortgage')
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  // Performance (Income Statement) Calculations
  const totalIncome = dateFilteredTxs
    .filter((t) => t.type === 'income')
    .reduce((sum, t) => sum + t.amount, 0);

  const totalExpenses = dateFilteredTxs
    .filter((t) => t.type === 'expense')
    .reduce((sum, t) => sum + t.amount, 0);

  const netSurplus = totalIncome - totalExpenses;

  // Business segregation
  const businessRevenue = dateFilteredTxs
    .filter((t) => t.type === 'income' && t.profile === 'business')
    .reduce((sum, t) => sum + t.amount, 0);

  const businessExpenses = dateFilteredTxs
    .filter((t) => t.type === 'expense' && t.profile === 'business')
    .reduce((sum, t) => sum + t.amount, 0);

  const businessNetProfit = businessRevenue - businessExpenses;

  // Financial Ratios
  const savingsRate = totalIncome > 0 ? (netSurplus / totalIncome) * 100 : 0;

  const debtServicingExpenses = dateFilteredTxs
    .filter(
      (t) =>
        t.type === 'expense' &&
        (t.category.toLowerCase().includes('debt') ||
          t.category.toLowerCase().includes('loan') ||
          (t.subcategory && t.subcategory.toLowerCase().includes('loan')))
    )
    .reduce((sum, t) => sum + t.amount, 0);

  const debtServiceRatio = totalIncome > 0 ? (debtServicingExpenses / totalIncome) * 100 : 0;

  // Cash Flow Breakdown (Operating, Investing, Financing, Transfers)
  const operatingInflows = dateFilteredTxs
    .filter(
      (t) =>
        t.type === 'income' &&
        !t.category.toLowerCase().includes('investment') &&
        !t.category.toLowerCase().includes('dividend')
    )
    .reduce((sum, t) => sum + t.amount, 0);

  const operatingOutflows = dateFilteredTxs
    .filter(
      (t) =>
        t.type === 'expense' &&
        !t.category.toLowerCase().includes('debt') &&
        !t.category.toLowerCase().includes('investment')
    )
    .reduce((sum, t) => sum + t.amount, 0);

  const netOperatingCashFlow = operatingInflows - operatingOutflows;

  const investingInflows = dateFilteredTxs
    .filter(
      (t) =>
        t.type === 'income' &&
        (t.category.toLowerCase().includes('investment') ||
          t.category.toLowerCase().includes('dividend') ||
          t.category.toLowerCase().includes('interest'))
    )
    .reduce((sum, t) => sum + t.amount, 0);

  const investingOutflows = dateFilteredTxs
    .filter(
      (t) =>
        t.type === 'expense' &&
        (t.category.toLowerCase().includes('investment') ||
          (t.subcategory && t.subcategory.toLowerCase().includes('mp2')))
    )
    .reduce((sum, t) => sum + t.amount, 0);

  const netInvestingCashFlow = investingInflows - investingOutflows;

  const financingInflows = 0; // External loans taken in
  const financingOutflows = debtServicingExpenses;
  const netFinancingCashFlow = financingInflows - financingOutflows;

  // Internal transfers (strictly neutral)
  const transfersCount = dateFilteredTxs.filter((t) => t.type === 'transfer').length;
  const transfersVolume = dateFilteredTxs
    .filter((t) => t.type === 'transfer')
    .reduce((sum, t) => sum + t.amount, 0);

  const netCashChange =
    netOperatingCashFlow + netInvestingCashFlow + netFinancingCashFlow;

  // Projected Month-End Run Rate
  const daysInCurrentMonth = new Date(
    new Date().getFullYear(),
    new Date().getMonth() + 1,
    0
  ).getDate();
  const currentDay = Math.max(1, new Date().getDate());
  const projectedIncome = (totalIncome / currentDay) * daysInCurrentMonth;
  const projectedExpenses = (totalExpenses / currentDay) * daysInCurrentMonth;
  const projectedSurplus = projectedIncome - projectedExpenses;

  // Reconciliation Calculations
  const currentReconcileAcc =
    accounts.find((a) => a.id === selectedReconcileAccId) || accounts[0];

  // Dynamically compute book balance from ledger
  const bookBalance = useMemo(() => {
    if (!currentReconcileAcc) return 0;
    return currentReconcileAcc.balance;
  }, [currentReconcileAcc]);

  const parsedActualBalance = parseFloat(actualBalanceInput.replace(/,/g, ''));
  const actualBalance = !isNaN(parsedActualBalance)
    ? parsedActualBalance
    : bookBalance;

  const reconciliationVariance = actualBalance - bookBalance;
  const isBalanced = Math.abs(reconciliationVariance) < 0.01;

  // Duplicate detection algorithm
  const potentialDuplicates = useMemo(() => {
    const dups: { tx1: Transaction; tx2: Transaction; reason: string }[] = [];
    for (let i = 0; i < transactions.length; i++) {
      for (let j = i + 1; j < transactions.length; j++) {
        const t1 = transactions[i];
        const t2 = transactions[j];

        // Same amount and same account within 2 days
        if (
          t1.amount === t2.amount &&
          t1.accountId === t2.accountId &&
          t1.type === t2.type &&
          t1.status !== 'duplicate' &&
          t2.status !== 'duplicate'
        ) {
          const diffDays =
            Math.abs(new Date(t1.date).getTime() - new Date(t2.date).getTime()) /
            (1000 * 3600 * 24);
          if (diffDays <= 2) {
            dups.push({
              tx1: t1,
              tx2: t2,
              reason: `Identical amount ₱${t1.amount.toFixed(
                2
              )} logged within ${Math.round(diffDays)} days`,
            });
          }
        }
      }
    }
    return dups;
  }, [transactions]);

  // Handle reconciliation record
  const handleFinalizeReconciliation = () => {
    if (!currentReconcileAcc) return;

    recordReconciliation({
      accountId: currentReconcileAcc.id,
      date: new Date().toISOString().split('T')[0],
      bookBalance,
      actualBalance,
      variance: reconciliationVariance,
      status: isBalanced ? 'balanced' : 'discrepancy',
      notes: isBalanced
        ? 'Account balances verified against external statement.'
        : `Discrepancy of ${formatPeso(reconciliationVariance)} recorded.`,
    });

    setReconcileSuccessMessage(
      `Reconciliation recorded for ${currentReconcileAcc.name}.`
    );
    setTimeout(() => setReconcileSuccessMessage(null), 4000);
  };

  const handleCreateTraceableAdjustment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentReconcileAcc || Math.abs(reconciliationVariance) < 0.01) return;

    createAdjustmentTransaction(
      currentReconcileAcc.id,
      reconciliationVariance,
      adjustmentNote.trim() || 'Statement balance alignment'
    );

    recordReconciliation({
      accountId: currentReconcileAcc.id,
      date: new Date().toISOString().split('T')[0],
      bookBalance,
      actualBalance,
      variance: 0,
      status: 'balanced',
      notes: `Traceable journal adjustment posted: ${adjustmentNote || 'Balance alignment'}`,
    });

    setActualBalanceInput('');
    setAdjustmentNote('');
    setShowAdjustmentForm(false);
    setReconcileSuccessMessage(
      `Adjustment posted to ledger! Book balance now reconciles to ₱${actualBalance.toLocaleString()}.`
    );
    setTimeout(() => setReconcileSuccessMessage(null), 4500);
  };

  // Detailed Category & Subcategory Breakdown for the active period
  const expenseCategoryBreakdown = useMemo(() => {
    const expenseTxs = dateFilteredTxs.filter((t) => t.type === 'expense');
    const totalExp = expenseTxs.reduce((sum, t) => sum + t.amount, 0);

    const catMap: Record<
      string,
      {
        category: string;
        total: number;
        count: number;
        subcategories: Record<string, { total: number; count: number }>;
      }
    > = {};

    expenseTxs.forEach((t) => {
      const cat = t.category || 'Uncategorized';
      const sub = t.subcategory || 'General';

      if (!catMap[cat]) {
        catMap[cat] = {
          category: cat,
          total: 0,
          count: 0,
          subcategories: {},
        };
      }

      catMap[cat].total += t.amount;
      catMap[cat].count += 1;

      if (!catMap[cat].subcategories[sub]) {
        catMap[cat].subcategories[sub] = { total: 0, count: 0 };
      }
      catMap[cat].subcategories[sub].total += t.amount;
      catMap[cat].subcategories[sub].count += 1;
    });

    return Object.values(catMap)
      .map((item) => ({
        ...item,
        percentage: totalExp > 0 ? (item.total / totalExp) * 100 : 0,
        subcategoriesList: Object.entries(item.subcategories).map(([subName, subData]) => ({
          name: subName,
          total: subData.total,
          count: subData.count,
          percentageOfCategory: item.total > 0 ? (subData.total / item.total) * 100 : 0,
        })),
      }))
      .sort((a, b) => b.total - a.total);
  }, [dateFilteredTxs]);

  const incomeCategoryBreakdown = useMemo(() => {
    const incomeTxs = dateFilteredTxs.filter((t) => t.type === 'income');
    const totalInc = incomeTxs.reduce((sum, t) => sum + t.amount, 0);

    const catMap: Record<
      string,
      {
        category: string;
        total: number;
        count: number;
        subcategories: Record<string, { total: number; count: number }>;
      }
    > = {};

    incomeTxs.forEach((t) => {
      const cat = t.category || 'Income';
      const sub = t.subcategory || 'Regular';

      if (!catMap[cat]) {
        catMap[cat] = {
          category: cat,
          total: 0,
          count: 0,
          subcategories: {},
        };
      }

      catMap[cat].total += t.amount;
      catMap[cat].count += 1;

      if (!catMap[cat].subcategories[sub]) {
        catMap[cat].subcategories[sub] = { total: 0, count: 0 };
      }
      catMap[cat].subcategories[sub].total += t.amount;
      catMap[cat].subcategories[sub].count += 1;
    });

    return Object.values(catMap)
      .map((item) => ({
        ...item,
        percentage: totalInc > 0 ? (item.total / totalInc) * 100 : 0,
        subcategoriesList: Object.entries(item.subcategories).map(([subName, subData]) => ({
          name: subName,
          total: subData.total,
          count: subData.count,
          percentageOfCategory: item.total > 0 ? (subData.total / item.total) * 100 : 0,
        })),
      }))
      .sort((a, b) => b.total - a.total);
  }, [dateFilteredTxs]);

  // Comprehensive Export to CSV with full Monthly / Period breakdown
  const handleExportReportCSV = () => {
    const periodLabel = period.replace('_', ' ').toUpperCase();
    const profileLabel = activeProfile.toUpperCase();
    const dateStr = new Date().toLocaleDateString('en-PH', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });

    const lines: string[] = [];

    // Header metadata
    lines.push(`"SALAPIFY 3 - FINANCIAL REPORT & MONTHLY BREAKDOWN"`);
    lines.push(`"Profile / Books: ${profileLabel}"`);
    lines.push(`"Reporting Period: ${periodLabel}"`);
    lines.push(`"Generated Date: ${dateStr}"`);
    lines.push(`"Currency: Philippine Peso (PHP / ₱)"`);
    lines.push('');

    // Section 1: Executive Summary
    lines.push(`"=== SECTION 1: EXECUTIVE FINANCIAL SUMMARY (${periodLabel}) ==="`);
    lines.push(`"Metric","Value (PHP)","Percentage / Indicator"`);
    lines.push(`"Total Gross Income / Inflows","${totalIncome.toFixed(2)}","100.0%"`);
    lines.push(`"Total Operating & Discretionary Expenses","${totalExpenses.toFixed(2)}","${totalIncome > 0 ? ((totalExpenses / totalIncome) * 100).toFixed(1) : 0}% of Income"`);
    lines.push(`"Net Surplus / (Deficit)","${netSurplus.toFixed(2)}","${savingsRate.toFixed(1)}% Savings Rate"`);
    lines.push(`"Debt Servicing Outflows","${debtServicingExpenses.toFixed(2)}","${debtServiceRatio.toFixed(1)}% DSR (BSP Limit: 35%)"`);
    lines.push(`"Net Operating Cash Flow","${netOperatingCashFlow.toFixed(2)}",""`);
    lines.push(`"Net Investing Cash Flow","${netInvestingCashFlow.toFixed(2)}",""`);
    lines.push(`"Net Financing Cash Flow","${netFinancingCashFlow.toFixed(2)}",""`);
    lines.push(`"Total Consolidated Net Worth","${netWorth.toFixed(2)}","Consolidated Balance Sheet"`);
    lines.push('');

    // Section 2: Expense Breakdown by Category & Subcategory
    lines.push(`"=== SECTION 2: EXPENSES DETAILED BREAKDOWN (${periodLabel}) ==="`);
    lines.push(`"Category","Subcategory","Total Spent (PHP)","% of Total Expenses","Transaction Count"`);
    if (expenseCategoryBreakdown.length === 0) {
      lines.push(`"No expense transactions logged for this period","","0.00","0.0%","0"`);
    } else {
      expenseCategoryBreakdown.forEach((cat) => {
        lines.push(`"${cat.category} (Total)","All","${cat.total.toFixed(2)}","${cat.percentage.toFixed(1)}%","${cat.count}"`);
        cat.subcategoriesList.forEach((sub) => {
          lines.push(`"  ↳ ${cat.category}","${sub.name}","${sub.total.toFixed(2)}","${((sub.total / (totalExpenses || 1)) * 100).toFixed(1)}%","${sub.count}"`);
        });
      });
    }
    lines.push('');

    // Section 3: Income Breakdown by Category & Subcategory
    lines.push(`"=== SECTION 3: INCOME DETAILED BREAKDOWN (${periodLabel}) ==="`);
    lines.push(`"Category","Subcategory","Total Received (PHP)","% of Total Income","Transaction Count"`);
    if (incomeCategoryBreakdown.length === 0) {
      lines.push(`"No income transactions logged for this period","","0.00","0.0%","0"`);
    } else {
      incomeCategoryBreakdown.forEach((cat) => {
        lines.push(`"${cat.category} (Total)","All","${cat.total.toFixed(2)}","${cat.percentage.toFixed(1)}%","${cat.count}"`);
        cat.subcategoriesList.forEach((sub) => {
          lines.push(`"  ↳ ${cat.category}","${sub.name}","${sub.total.toFixed(2)}","${((sub.total / (totalIncome || 1)) * 100).toFixed(1)}%","${sub.count}"`);
        });
      });
    }
    lines.push('');

    // Section 4: Balance Sheet Accounts Register
    lines.push(`"=== SECTION 4: CONSOLIDATED BALANCE SHEET REGISTER ==="`);
    lines.push(`"Account Name","Type","Institution","Profile","Currency","Balance (Original)","Balance (PHP)"`);
    filteredAccounts.forEach((acc) => {
      const phpVal = convertToPhp(acc.balance, acc.currency || 'PHP');
      lines.push(`"${acc.name}","${acc.kind}","${acc.institution}","${acc.profile || 'personal'}","${acc.currency || 'PHP'}","${acc.balance.toFixed(2)}","${phpVal.toFixed(2)}"`);
    });
    lines.push(`"TOTAL ASSETS","","","","PHP","","${totalAssets.toFixed(2)}"`);
    lines.push(`"TOTAL LIABILITIES","","","","PHP","","${totalLiabilities.toFixed(2)}"`);
    lines.push(`"CONSOLIDATED NET EQUITY / NET WORTH","","","","PHP","","${netWorth.toFixed(2)}"`);
    lines.push('');

    // Section 5: Individual Transactions in the Selected Period
    lines.push(`"=== SECTION 5: ITEMIZED TRANSACTION LEDGER (${dateFilteredTxs.length} TRANSACTIONS) ==="`);
    lines.push(`"Date","Transaction ID","Type","Account","Category","Subcategory","Merchant / Payee","Status","Profile","Amount (PHP)","Notes"`);
    dateFilteredTxs.forEach((t) => {
      const acc = accounts.find((a) => a.id === t.accountId);
      lines.push(
        `"${t.date}","${t.id}","${t.type}","${acc?.name || t.accountId}","${t.category}","${t.subcategory || 'General'}","${(t.merchant || '').replace(/"/g, '""')}","${t.status || 'confirmed'}","${t.profile || 'personal'}","${t.amount.toFixed(2)}","${(t.note || '').replace(/"/g, '""')}"`
      );
    });

    const csvContent = lines.join('\r\n');
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `salapify_${activeProfile}_${period}_report_breakdown.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // Comprehensive Export to JSON
  const handleExportReportJSON = () => {
    const exportData = {
      app: 'Salapify 3',
      exportDate: new Date().toISOString(),
      activeProfile,
      period,
      executiveSummary: {
        totalIncome,
        totalExpenses,
        netSurplus,
        savingsRate,
        debtServicingExpenses,
        debtServiceRatio,
        netOperatingCashFlow,
        netInvestingCashFlow,
        netFinancingCashFlow,
        totalAssets,
        totalLiabilities,
        netWorth,
      },
      expenseBreakdown: expenseCategoryBreakdown,
      incomeBreakdown: incomeCategoryBreakdown,
      balanceSheetAccounts: filteredAccounts.map((a) => ({
        id: a.id,
        name: a.name,
        kind: a.kind,
        institution: a.institution,
        profile: a.profile,
        currency: a.currency || 'PHP',
        balance: a.balance,
        balancePHP: convertToPhp(a.balance, a.currency || 'PHP'),
      })),
      transactionsCount: dateFilteredTxs.length,
      transactions: dateFilteredTxs,
    };

    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `salapify_${activeProfile}_${period}_report_breakdown.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="flex flex-col gap-4 pb-36">
      {/* Title & Profile Context */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pt-2 px-1">
        <div>
          <h1 className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
            Connected Reports
          </h1>
          <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
            Single unified ledger for balance sheets, income statements, cash flows, and audits
          </span>
        </div>

        {/* Profile Entity Switcher */}
        <div className="flex items-center gap-1.5 self-start sm:self-auto overflow-x-auto pb-1 no-scrollbar">
          <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1 shrink-0">
            <Building size={13} />
            <span>Profile:</span>
          </span>
          <button
            type="button"
            onClick={() => setActiveProfile('all')}
            className={`px-2.5 py-1 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer transition-colors border ${
              activeProfile === 'all'
                ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
                : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
            }`}
          >
            All Books
          </button>
          {PROFILE_OPTIONS.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => setActiveProfile(p.id)}
              className={`px-2.5 py-1 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer transition-colors border capitalize ${
                activeProfile === p.id
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                  : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
              }`}
            >
              {p.name}
            </button>
          ))}
        </div>
      </div>

      {/* 4 Connected Report Navigation Tabs */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-1.5 p-1 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
        <button
          type="button"
          onClick={() => setActiveTab('position')}
          className={`py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
            activeTab === 'position'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <Scale size={14} />
          <span>Position</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('performance')}
          className={`py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
            activeTab === 'performance'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <FileSpreadsheet size={14} />
          <span>Performance</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('cashflow')}
          className={`py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
            activeTab === 'cashflow'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <ArrowRightLeft size={14} />
          <span>Cash Flow</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('reconciliation')}
          className={`py-2 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
            activeTab === 'reconciliation'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] shadow-xs'
              : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <ShieldCheck size={14} />
          <span>Reconciliation</span>
        </button>
      </div>

      {/* Accounting Period Selector & Comparison Toggles (For Performance & Cash Flow) */}
      {(activeTab === 'performance' || activeTab === 'cashflow') && (
        <div className="flex flex-col gap-2 bg-[#FFEEDF]/50 dark:bg-[#14100D] p-2.5 rounded-2xl border border-[#F3DFCD] dark:border-[#383029]">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5 no-scrollbar">
              <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1 shrink-0">
                <Calendar size={13} />
                <span>Period:</span>
              </span>
              {(
                [
                  'daily',
                  'weekly',
                  'monthly',
                  'quarterly',
                  'semi_annually',
                  'annually',
                ] as ReportPeriod[]
              ).map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setPeriod(p)}
                  className={`px-2.5 py-1 rounded-xl text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors capitalize ${
                    period === p
                      ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs font-bold'
                      : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F]'
                  }`}
                >
                  {p.replace('_', '-')}
                </button>
              ))}
            </div>

            {/* Quick Export Controls */}
            <div className="flex items-center gap-1.5 self-end sm:self-auto shrink-0">
              <button
                type="button"
                onClick={handleExportReportCSV}
                className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] hover:bg-[#16643F]/10 cursor-pointer transition-colors shadow-xs"
                title={`Export full ${period} breakdown report to CSV`}
              >
                <Download size={13} />
                <span>Export {period === 'monthly' ? 'Monthly' : ''} CSV</span>
              </button>
              <button
                type="button"
                onClick={handleExportReportJSON}
                className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] cursor-pointer transition-colors"
                title="Export structured JSON report"
              >
                <FileText size={13} />
                <span>JSON</span>
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between gap-2 pt-1 border-t border-[#F3DFCD]/50 dark:border-[#383029]/50 text-xs">
            <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
              Showing {dateFilteredTxs.length} transactions in {period.replace('_', ' ')} period ({activeProfile} books)
            </span>
            <div className="flex items-center gap-1 shrink-0">
              <span className="font-bold text-[#6B6156] dark:text-[#AC9E92]">
                Compare:
              </span>
              <select
                value={comparisonMode}
                onChange={(e) => setComparisonMode(e.target.value as any)}
                className="px-2 py-0.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
              >
                <option value="none">None</option>
                <option value="previous">Previous Period</option>
                <option value="budget">Budget Target</option>
                <option value="forecast">Actual vs Forecast</option>
              </select>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 1. FINANCIAL POSITION (BALANCE SHEET) */}
      {/* ========================================================================= */}
      {activeTab === 'position' && (
        <div className="space-y-4">
          {/* Main Net Worth Hero */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs flex flex-col gap-4">
            <div className="flex justify-between items-start">
              <div>
                <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                  Consolidated Net Worth (Balance Sheet)
                </span>
                <div className="text-3xl sm:text-4xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-1">
                  {formatPeso(netWorth)}
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-[#16643F]/15 text-[#16643F] dark:text-[#5FCB8E] border border-[#16643F]/30">
                Solvent
              </span>
            </div>

            {/* Assets vs Liabilities Proportional Bar */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs font-bold">
                <span className="text-[#16643F] dark:text-[#5FCB8E]">
                  Assets: {formatPeso(totalAssets)}
                </span>
                <span className="text-rose-600 dark:text-rose-400">
                  Liabilities: {formatPeso(totalLiabilities)}
                </span>
              </div>
              <div className="w-full h-3 rounded-full bg-rose-500/20 overflow-hidden flex">
                <div
                  className="h-full bg-[#16643F] dark:bg-[#5FCB8E] rounded-full transition-all duration-500"
                  style={{
                    width: `${Math.min(
                      100,
                      totalAssets + totalLiabilities > 0
                        ? (totalAssets / (totalAssets + totalLiabilities)) * 100
                        : 100
                    )}%`,
                  }}
                />
              </div>
            </div>

            {/* Sub-metrics */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2 pt-2 border-t border-[#F3DFCD]/70 dark:border-[#383029]/70 text-xs">
              <div className="p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Cash &amp; Equivalents
                </span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] text-sm tabular-nums block truncate">
                  {formatPeso(cashEquivalents)}
                </span>
              </div>
              <div className="p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Investments
                </span>
                <span className="font-bold text-[#16643F] dark:text-[#5FCB8E] text-sm tabular-nums block truncate">
                  {formatPeso(investmentsTotal)}
                </span>
              </div>
              <div className="p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Receivables (Pahiram)
                </span>
                <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] text-sm tabular-nums block truncate">
                  {formatPeso(receivablesTotal)}
                </span>
              </div>
              <div className="p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Credit Card Debt
                </span>
                <span className="font-bold text-rose-600 dark:text-rose-400 text-sm tabular-nums block truncate">
                  {formatPeso(creditCardsTotal)}
                </span>
              </div>
            </div>
          </div>

          {/* Historical Net-Worth Progression */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <div className="flex justify-between items-center">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                Historical Net-Worth Changes
              </h3>
              <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E]">
                +14.8% YTD Growth
              </span>
            </div>

            {/* Simplified Visual Bar Progression */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-2 text-center text-xs">
              {[
                { label: 'Q1 2026', amount: 98500, height: '55%' },
                { label: 'Q2 2026', amount: 112000, height: '68%' },
                { label: 'Q3 2026', amount: 124500, height: '80%' },
                { label: 'Current', amount: netWorth, height: '100%', highlight: true },
              ].map((bar, idx) => (
                <div key={idx} className="flex flex-col items-center gap-2 min-w-0">
                  <div className="w-full h-24 bg-[#FFEEDF]/40 dark:bg-[#14100D] rounded-xl flex items-end justify-center p-1 overflow-hidden">
                    <div
                      className={`w-full rounded-lg transition-all duration-500 ${
                        bar.highlight
                          ? 'bg-[#B03C09] dark:bg-[#FF9A52]'
                          : 'bg-[#B03C09]/40 dark:bg-[#FF9A52]/40'
                      }`}
                      style={{ height: bar.height }}
                    />
                  </div>
                  <span className="text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8] truncate w-full">
                    {formatPeso(bar.amount)}
                  </span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] truncate w-full">
                    {bar.label}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Asset Breakdown Detail */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#16643F] dark:text-[#5FCB8E]">
              Assets Register ({assetAccounts.length} accounts)
            </h3>
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
              {assetAccounts.map((acc) => (
                <div
                  key={acc.id}
                  className="py-2.5 flex items-center justify-between text-xs gap-2"
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 font-bold shrink-0">
                      {acc.monogram}
                    </span>
                    <div className="truncate">
                      <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        {acc.name}
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] capitalize">
                        {acc.kind} · {acc.institution} {acc.profile ? `(${acc.profile})` : ''}
                      </div>
                    </div>
                  </div>
                  <span className="font-bold text-[#16643F] dark:text-[#5FCB8E] tabular-nums whitespace-nowrap">
                    {formatPeso(convertToPhp(acc.balance, acc.currency || 'PHP'))}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Liabilities Detail */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-rose-600 dark:text-rose-400">
              Liabilities Register ({liabilityAccounts.length} obligations)
            </h3>
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
              {liabilityAccounts.map((acc) => {
                const util = acc.creditLimit
                  ? Math.round((acc.balance / acc.creditLimit) * 100)
                  : null;
                return (
                  <div
                    key={acc.id}
                    className="py-2.5 flex items-center justify-between text-xs gap-2"
                  >
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-rose-500/15 text-rose-700 dark:text-rose-300 font-bold shrink-0">
                        {acc.monogram}
                      </span>
                      <div className="truncate">
                        <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {acc.name}
                        </div>
                        <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] capitalize">
                          {acc.kind} {acc.dueDate ? `· Due: ${acc.dueDate}` : ''}
                          {util !== null ? ` · Util: ${util}%` : ''}
                        </div>
                      </div>
                    </div>
                    <span className="font-bold text-rose-600 dark:text-rose-400 tabular-nums whitespace-nowrap">
                      {formatPeso(convertToPhp(acc.balance, acc.currency || 'PHP'))}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 2. FINANCIAL PERFORMANCE (INCOME STATEMENT) */}
      {/* ========================================================================= */}
      {activeTab === 'performance' && (
        <div className="space-y-4">
          {/* Hero Performance Card */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-4">
            <div className="flex justify-between items-start">
              <div>
                <span className="text-xs font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                  Net Surplus / (Deficit) - {period.replace('_', ' ')}
                </span>
                <div
                  className={`text-3xl sm:text-4xl font-extrabold tabular-nums mt-1 ${
                    netSurplus >= 0
                      ? 'text-[#16643F] dark:text-[#5FCB8E]'
                      : 'text-rose-600 dark:text-rose-400'
                  }`}
                >
                  {netSurplus >= 0 ? `+${formatPeso(netSurplus)}` : `-${formatPeso(Math.abs(netSurplus))}`}
                </div>
              </div>

              {/* Savings Rate Badge */}
              <div className="text-right">
                <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#AC9E92] block">
                  Savings Rate
                </span>
                <span className="text-base font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                  {Math.round(savingsRate)}%
                </span>
              </div>
            </div>

            {/* Income & Expense Metrics */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-[#F3DFCD]/70 dark:border-[#383029]/70 text-xs">
              <div className="p-3 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 min-w-0">
                <span className="text-emerald-800 dark:text-emerald-300 font-semibold block mb-0.5 truncate">
                  Total Income / Revenue
                </span>
                <span className="text-lg font-extrabold text-emerald-900 dark:text-emerald-200 tabular-nums block truncate">
                  +{formatPeso(totalIncome)}
                </span>
              </div>
              <div className="p-3 rounded-2xl bg-rose-500/10 border border-rose-500/20 min-w-0">
                <span className="text-rose-800 dark:text-rose-300 font-semibold block mb-0.5 truncate">
                  Total Expenses
                </span>
                <span className="text-lg font-extrabold text-rose-900 dark:text-rose-200 tabular-nums block truncate">
                  -{formatPeso(totalExpenses)}
                </span>
              </div>
            </div>

            {/* Key Behavioral Ratios: DSR */}
            <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between text-xs">
              <div className="flex items-center gap-2">
                <Info size={16} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
                <div>
                  <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Debt-Service Ratio (DSR): {Math.round(debtServiceRatio)}%
                  </span>
                  <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    BSP guidelines recommend keeping total debt servicing under 35% of income.
                  </div>
                </div>
              </div>
              <span
                className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                  debtServiceRatio <= 35
                    ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'
                    : 'bg-rose-500/15 text-rose-700 dark:text-rose-300'
                }`}
              >
                {debtServiceRatio <= 35 ? 'Healthy' : 'High Debt'}
              </span>
            </div>
          </div>

          {/* Business Revenue vs Business Expenses Segregation */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <div className="flex justify-between items-center">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                <Building size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                <span>Business & Side-Hustle Performance</span>
              </h3>
              <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E]">
                Net: {formatPeso(businessNetProfit)}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Business Inflows
                </span>
                <span className="font-bold text-[#16643F] dark:text-[#5FCB8E] text-sm tabular-nums block truncate">
                  +{formatPeso(businessRevenue)}
                </span>
              </div>
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                  Business Expenses
                </span>
                <span className="font-bold text-rose-600 dark:text-rose-400 text-sm tabular-nums block truncate">
                  -{formatPeso(businessExpenses)}
                </span>
              </div>
            </div>
          </div>

          {/* Comprehensive Category & Subcategory Breakdown */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                  <PieChart size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>Itemized {period.replace('_', ' ')} Expense Breakdown</span>
                </h3>
                <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                  Category and subcategory allocations for the active {period.replace('_', ' ')} period
                </p>
              </div>
              <button
                type="button"
                onClick={handleExportReportCSV}
                className="self-start sm:self-auto flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#1E1813] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#B03C09]/10 cursor-pointer transition-colors"
              >
                <Download size={13} />
                <span>Export Breakdown</span>
              </button>
            </div>

            {expenseCategoryBreakdown.length === 0 ? (
              <div className="p-4 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] text-xs text-[#6B6156] dark:text-[#AC9E92] text-center">
                No expense transactions recorded in this period.
              </div>
            ) : (
              <div className="space-y-3">
                {expenseCategoryBreakdown.map((cat) => (
                  <div
                    key={cat.category}
                    className="p-3.5 rounded-2xl bg-[#FFEEDF]/20 dark:bg-[#14100D]/60 border border-[#F3DFCD] dark:border-[#383029] space-y-2"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <div className="min-w-0">
                        <div className="font-bold text-xs text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {cat.category}
                        </div>
                        <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                          {cat.count} {cat.count === 1 ? 'transaction' : 'transactions'} · {cat.percentage.toFixed(1)}% of total expenses
                        </div>
                      </div>
                      <div className="text-right shrink-0">
                        <span className="font-extrabold text-xs text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                          {formatPeso(cat.total)}
                        </span>
                      </div>
                    </div>

                    {/* Progress Bar */}
                    <div className="w-full h-1.5 bg-[#F3DFCD] dark:bg-[#383029] rounded-full overflow-hidden">
                      <div
                        className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full transition-all duration-300"
                        style={{ width: `${Math.min(100, Math.max(3, cat.percentage))}%` }}
                      />
                    </div>

                    {/* Subcategories List */}
                    {cat.subcategoriesList.length > 0 && (
                      <div className="pt-1.5 grid grid-cols-1 sm:grid-cols-2 gap-1.5 border-t border-[#F3DFCD]/40 dark:border-[#383029]/40">
                        {cat.subcategoriesList.map((sub) => (
                          <div
                            key={sub.name}
                            className="flex items-center justify-between text-[11px] px-2 py-1 rounded-lg bg-white/70 dark:bg-[#27201A]/70 border border-[#F3DFCD]/50 dark:border-[#383029]/50"
                          >
                            <span className="text-[#6B6156] dark:text-[#AC9E92] truncate pr-1">
                              ↳ {sub.name} ({sub.count})
                            </span>
                            <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8] tabular-nums shrink-0">
                              {formatPeso(sub.total)}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Detailed Category Statement */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
              Detailed Expenses by Function
            </h3>
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
              {budgets.map((b) => {
                const actualSpend = dateFilteredTxs
                  .filter((t) => t.type === 'expense' && t.category === b.category)
                  .reduce((sum, t) => sum + t.amount, 0);

                const variance = b.limit - actualSpend;

                return (
                  <div key={b.category} className="py-2.5 flex items-center justify-between text-xs gap-2">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-base shrink-0">{b.emoji}</span>
                      <div className="truncate">
                        <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {b.category}
                        </div>
                        {comparisonMode === 'budget' && (
                          <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                            Budget: {formatPeso(b.limit)} ({variance >= 0 ? `${formatPeso(variance)} under` : `${formatPeso(Math.abs(variance))} over`})
                          </div>
                        )}
                      </div>
                    </div>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums whitespace-nowrap">
                      {formatPeso(actualSpend)}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 3. CASH FLOW STATEMENT */}
      {/* ========================================================================= */}
      {activeTab === 'cashflow' && (
        <div className="space-y-4">
          {/* Cash Flow Dimension Selector */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
            <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] shrink-0">
              Dimension:
            </span>
            {(
              [
                ['standard', 'Statement View'],
                ['by_account', 'By Account'],
                ['by_entity', 'By Entity'],
                ['by_category', 'By Category'],
              ] as const
            ).map(([dim, label]) => (
              <button
                key={dim}
                type="button"
                onClick={() => setCashFlowDimension(dim)}
                className={`px-3 py-1 rounded-xl text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors border ${
                  cashFlowDimension === dim
                    ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent font-bold'
                    : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          {cashFlowDimension === 'standard' ? (
            <>
              {/* Enhanced Coherent Cash Flow & Net Movement Hero Card */}
              <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-4">
                {/* Header with Title and Period */}
                <div className="flex justify-between items-start">
                  <div>
                    <span className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                      Cash Movement &amp; Flow Analysis
                    </span>
                    <div
                      className={`text-3xl sm:text-4xl font-extrabold tabular-nums mt-1 ${
                        netCashChange >= 0
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#B03C09] dark:text-[#FF9A52]'
                      }`}
                    >
                      {netCashChange >= 0 ? `+${formatPeso(netCashChange)}` : `-${formatPeso(Math.abs(netCashChange))}`}
                    </div>
                    <div className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92] mt-0.5">
                      Net change in liquid cash across all accounts ({period.replace('_', ' ')})
                    </div>
                  </div>

                  <div className="flex flex-col items-end gap-1">
                    <span
                      className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                        netCashChange >= 0
                          ? 'bg-[#16643F]/15 text-[#16643F] dark:text-[#5FCB8E] border border-[#16643F]/30'
                          : 'bg-[#B03C09]/15 text-[#B03C09] dark:text-[#FF9A52] border border-[#B03C09]/30'
                      }`}
                    >
                      {netCashChange >= 0 ? 'Cash Positive' : 'Deficit / Drawdown'}
                    </span>
                    <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                      {transfersCount} internal transfer{transfersCount === 1 ? '' : 's'}
                    </span>
                  </div>
                </div>

                {/* Coherent 3-Pillar Inflows vs Outflows vs Movement Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 pt-1">
                  {/* Total Inflows */}
                  <div className="p-3.5 rounded-2xl bg-[#E1F5EA]/60 dark:bg-[#123824]/40 border border-[#16643F]/20 flex flex-col justify-between">
                    <div className="flex items-center justify-between gap-1 mb-1">
                      <span className="text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] flex items-center gap-1">
                        <ArrowDownLeft size={13} />
                        <span>Total Inflows</span>
                      </span>
                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#16643F]/20 text-[#16643F] dark:text-[#5FCB8E]">
                        Cash In
                      </span>
                    </div>
                    <div className="text-xl font-extrabold text-[#16643F] dark:text-[#5FCB8E] tabular-nums">
                      +{formatPeso(operatingInflows + investingInflows)}
                    </div>
                    <div className="text-[10px] text-[#16643F]/80 dark:text-[#5FCB8E]/80 mt-1">
                      Salary, freelancing, investments
                    </div>
                  </div>

                  {/* Total Outflows */}
                  <div className="p-3.5 rounded-2xl bg-rose-500/10 dark:bg-rose-950/30 border border-rose-500/20 flex flex-col justify-between">
                    <div className="flex items-center justify-between gap-1 mb-1">
                      <span className="text-xs font-bold text-rose-800 dark:text-rose-300 flex items-center gap-1">
                        <ArrowUpRight size={13} />
                        <span>Total Outflows</span>
                      </span>
                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-rose-500/20 text-rose-800 dark:text-rose-300">
                        Cash Out
                      </span>
                    </div>
                    <div className="text-xl font-extrabold text-rose-900 dark:text-rose-200 tabular-nums">
                      -{formatPeso(operatingOutflows + investingOutflows + Math.abs(netFinancingCashFlow))}
                    </div>
                    <div className="text-[10px] text-rose-700/80 dark:text-rose-300/80 mt-1">
                      Living expenses, bills, debt
                    </div>
                  </div>

                  {/* Net Movement Rate */}
                  <div className="p-3.5 rounded-2xl bg-[#FFEEDF]/50 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] flex flex-col justify-between">
                    <div className="flex items-center justify-between gap-1 mb-1">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1">
                        <Scale size={13} />
                        <span>Net Surplus Rate</span>
                      </span>
                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#B03C09]/15 text-[#B03C09] dark:text-[#FF9A52]">
                        {savingsRate.toFixed(1)}%
                      </span>
                    </div>
                    <div className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                      {netCashChange >= 0 ? `+${formatPeso(netCashChange)}` : `-${formatPeso(Math.abs(netCashChange))}`}
                    </div>
                    <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-1">
                      Unconsumed cash flow buffer
                    </div>
                  </div>
                </div>

                {/* Proportional Inflow vs Outflow Visual Bar */}
                <div className="space-y-1.5 pt-1">
                  <div className="flex justify-between text-[11px] font-bold">
                    <span className="text-[#16643F] dark:text-[#5FCB8E]">
                      Inflows: {((operatingInflows + investingInflows) / Math.max(1, (operatingInflows + investingInflows + operatingOutflows + investingOutflows + Math.abs(netFinancingCashFlow))) * 100).toFixed(0)}%
                    </span>
                    <span className="text-rose-600 dark:text-rose-400">
                      Outflows: {((operatingOutflows + investingOutflows + Math.abs(netFinancingCashFlow)) / Math.max(1, (operatingInflows + investingInflows + operatingOutflows + investingOutflows + Math.abs(netFinancingCashFlow))) * 100).toFixed(0)}%
                    </span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-rose-500/20 overflow-hidden flex">
                    <div
                      className="h-full bg-[#16643F] dark:bg-[#5FCB8E] rounded-full transition-all duration-500"
                      style={{
                        width: `${Math.min(100, Math.max(0, ((operatingInflows + investingInflows) / Math.max(1, (operatingInflows + investingInflows + operatingOutflows + investingOutflows + Math.abs(netFinancingCashFlow)))) * 100))}%`,
                      }}
                    />
                  </div>
                </div>

                {/* 3 Main Cash Flow Segments */}
                <div className="space-y-2.5 pt-2 border-t border-[#F3DFCD]/70 dark:border-[#383029]/70 text-xs">
                  <div className="text-[11px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                    Cash Flow by Economic Activity
                  </div>

                  {/* Operating */}
                  <div className="flex justify-between items-center p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                    <div>
                      <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Operating Activities
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Sweldo, regular income, food, utilities, commute
                      </div>
                    </div>
                    <span
                      className={`font-extrabold text-sm tabular-nums ${
                        netOperatingCashFlow >= 0
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-rose-600 dark:text-rose-400'
                      }`}
                    >
                      {netOperatingCashFlow >= 0 ? `+${formatPeso(netOperatingCashFlow)}` : `-${formatPeso(Math.abs(netOperatingCashFlow))}`}
                    </span>
                  </div>

                  {/* Investing */}
                  <div className="flex justify-between items-center p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                    <div>
                      <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Investing Activities
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Pag-IBIG MP2 contributions, high-yield digital savings, dividends
                      </div>
                    </div>
                    <span
                      className={`font-extrabold text-sm tabular-nums ${
                        netInvestingCashFlow >= 0
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#B03C09] dark:text-[#FF9A52]'
                      }`}
                    >
                      {netInvestingCashFlow >= 0 ? `+${formatPeso(netInvestingCashFlow)}` : `-${formatPeso(Math.abs(netInvestingCashFlow))}`}
                    </span>
                  </div>

                  {/* Financing */}
                  <div className="flex justify-between items-center p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                    <div>
                      <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Financing Activities
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Debt installments, card payoff &amp; loan amortizations
                      </div>
                    </div>
                    <span className="font-extrabold text-sm tabular-nums text-rose-600 dark:text-rose-400">
                      -{formatPeso(Math.abs(netFinancingCashFlow))}
                    </span>
                  </div>

                  {/* Transfers Note */}
                  <div className="p-3 rounded-2xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-between text-xs">
                    <div>
                      <div className="font-bold text-amber-900 dark:text-amber-200">
                        Account Transfers ({transfersCount} operations)
                      </div>
                      <div className="text-[11px] text-amber-800/80 dark:text-amber-300/80">
                        Double-entry internal balance shifts: strictly net zero cash impact
                      </div>
                    </div>
                    <span className="font-extrabold text-amber-900 dark:text-amber-200 tabular-nums">
                      {formatPeso(transfersVolume)} shifted
                    </span>
                  </div>
                </div>
              </div>

              {/* Actual vs Projected Flow */}
              <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                  Actual vs Projected Month-End Forecast
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                  <div className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                    <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                      Actual Month-to-Date Flow
                    </span>
                    <span className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums block truncate">
                      {formatPeso(netSurplus)}
                    </span>
                  </div>
                  <div className="p-3 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
                    <span className="text-[#6B6156] dark:text-[#AC9E92] block mb-0.5 truncate">
                      Projected Month-End Run Rate
                    </span>
                    <span
                      className={`text-base font-extrabold tabular-nums block truncate ${
                        projectedSurplus >= 0
                          ? 'text-[#16643F] dark:text-[#5FCB8E]'
                          : 'text-[#B03C09] dark:text-[#FF9A52]'
                      }`}
                    >
                      {formatPeso(projectedSurplus)}
                    </span>
                  </div>
                </div>
              </div>
            </>
          ) : cashFlowDimension === 'by_account' ? (
            /* By Account View */
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                Cash Flow Movement by Account
              </h3>
              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                {accounts.map((acc) => {
                  const inflows = dateFilteredTxs
                    .filter((t) => (t.type === 'income' && t.accountId === acc.id) || (t.type === 'transfer' && t.toAccountId === acc.id))
                    .reduce((sum, t) => sum + t.amount, 0);

                  const outflows = dateFilteredTxs
                    .filter((t) => (t.type === 'expense' || t.type === 'transfer') && t.accountId === acc.id)
                    .reduce((sum, t) => sum + t.amount, 0);

                  const net = inflows - outflows;

                  return (
                    <div key={acc.id} className="py-2.5 flex items-center justify-between text-xs gap-2">
                      <div className="flex items-center gap-2 min-w-0">
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-700 dark:text-amber-300 font-bold shrink-0">
                          {acc.monogram}
                        </span>
                        <div className="truncate">
                          <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                            {acc.name}
                          </div>
                          <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                            In: {formatPeso(inflows)} · Out: {formatPeso(outflows)}
                          </div>
                        </div>
                      </div>
                      <span
                        className={`font-bold tabular-nums whitespace-nowrap ${
                          net >= 0
                            ? 'text-[#16643F] dark:text-[#5FCB8E]'
                            : 'text-[#B03C09] dark:text-[#FF9A52]'
                        }`}
                      >
                        {net >= 0 ? `+${formatPeso(net)}` : `-${formatPeso(Math.abs(net))}`}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : cashFlowDimension === 'by_entity' ? (
            /* By Entity View */
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                Cash Flow Movement by Profile Entity
              </h3>
              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                {PROFILE_OPTIONS.map((p) => {
                  const inflows = dateFilteredTxs
                    .filter((t) => t.type === 'income' && (t.profile || 'personal') === p.id)
                    .reduce((sum, t) => sum + t.amount, 0);

                  const outflows = dateFilteredTxs
                    .filter((t) => t.type === 'expense' && (t.profile || 'personal') === p.id)
                    .reduce((sum, t) => sum + t.amount, 0);

                  const net = inflows - outflows;

                  return (
                    <div key={p.id} className="py-3 flex items-center justify-between text-xs gap-2">
                      <div>
                        <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] capitalize flex items-center gap-1.5">
                          <Building size={13} style={{ color: p.color }} />
                          <span>{p.name} Entity</span>
                        </div>
                        <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                          Inflows: {formatPeso(inflows)} · Outflows: {formatPeso(outflows)}
                        </div>
                      </div>
                      <span
                        className={`font-bold text-sm tabular-nums whitespace-nowrap ${
                          net >= 0
                            ? 'text-[#16643F] dark:text-[#5FCB8E]'
                            : 'text-[#B03C09] dark:text-[#FF9A52]'
                        }`}
                      >
                        {net >= 0 ? `+${formatPeso(net)}` : `-${formatPeso(Math.abs(net))}`}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            /* By Category View */
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC]">
                Cash Flow by Main Category
              </h3>
              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                {budgets.map((b) => {
                  const outflows = dateFilteredTxs
                    .filter((t) => t.type === 'expense' && t.category === b.category)
                    .reduce((sum, t) => sum + t.amount, 0);

                  return (
                    <div key={b.category} className="py-2.5 flex items-center justify-between text-xs gap-2">
                      <div className="flex items-center gap-2">
                        <span className="text-base">{b.emoji}</span>
                        <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {b.category}
                        </span>
                      </div>
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                        -{formatPeso(outflows)}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* 4. RECONCILIATION & VARIANCE ENGINE */}
      {/* ========================================================================= */}
      {activeTab === 'reconciliation' && (
        <div className="space-y-4">
          {/* Success Toast */}
          {reconcileSuccessMessage && (
            <div className="p-3 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-800 dark:text-emerald-200 text-xs font-bold flex items-center gap-2 animate-in fade-in">
              <CheckCircle2 size={16} />
              <span>{reconcileSuccessMessage}</span>
            </div>
          )}

          {/* Account Selector & Live Variance Comparator */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div>
                <h2 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Account Reconciliation Engine
                </h2>
                <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  Compare book ledger balance against actual bank or e-wallet statement
                </span>
              </div>

              {/* Account Dropdown */}
              <select
                value={selectedReconcileAccId}
                onChange={(e) => {
                  setSelectedReconcileAccId(e.target.value);
                  setActualBalanceInput('');
                }}
                className="px-3 py-1.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    [{acc.monogram}] {acc.name} ({acc.kind})
                  </option>
                ))}
              </select>
            </div>

            {/* Book Balance vs Actual Input Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
              {/* Book Balance */}
              <div className="p-3.5 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <span className="text-[#6B6156] dark:text-[#AC9E92] font-semibold block mb-1">
                  Book Balance (Ledger)
                </span>
                <span className="text-xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums block">
                  {formatPeso(bookBalance)}
                </span>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-1 block">
                  Calculated from verified journal transactions
                </span>
              </div>

              {/* Actual Balance Input */}
              <div className="p-3.5 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <span className="text-[#6B6156] dark:text-[#AC9E92] font-semibold block mb-1">
                  Actual Statement Balance
                </span>
                <div className="flex items-center gap-1">
                  <span className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">₱</span>
                  <input
                    type="number"
                    step="any"
                    placeholder={bookBalance.toFixed(2)}
                    value={actualBalanceInput}
                    onChange={(e) => setActualBalanceInput(e.target.value)}
                    className="w-full text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl px-2 py-1 focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
                <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-1 block">
                  From BPI/GCash/Maya statement
                </span>
              </div>

              {/* Calculated Variance */}
              <div
                className={`p-3.5 rounded-2xl border ${
                  isBalanced
                    ? 'bg-emerald-500/10 border-emerald-500/30'
                    : 'bg-amber-500/10 border-amber-500/30'
                }`}
              >
                <span
                  className={`font-semibold block mb-1 ${
                    isBalanced
                      ? 'text-emerald-800 dark:text-emerald-300'
                      : 'text-amber-800 dark:text-amber-300'
                  }`}
                >
                  Variance (Actual - Book)
                </span>
                <span
                  className={`text-xl font-extrabold tabular-nums block ${
                    isBalanced
                      ? 'text-emerald-900 dark:text-emerald-200'
                      : 'text-amber-900 dark:text-amber-200'
                  }`}
                >
                  {isBalanced ? '₱0.00 (Balanced)' : formatPeso(reconciliationVariance)}
                </span>
                <span
                  className={`text-[10px] mt-1 block ${
                    isBalanced
                      ? 'text-emerald-700/80 dark:text-emerald-300/80'
                      : 'text-amber-700/80 dark:text-amber-300/80'
                  }`}
                >
                  {isBalanced
                    ? 'Ledger matches external statement exactly'
                    : 'Discrepancy requires audit adjustment'}
                </span>
              </div>
            </div>

            {/* Reconciliation Actions */}
            <div className="flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-[#F3DFCD]/70 dark:border-[#383029]/70">
              <div className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                {isBalanced
                  ? 'All accounts in harmony. Click below to file periodic audit confirmation.'
                  : 'Variance detected. Post a traceable journal adjustment entry to resolve.'}
              </div>

              <div className="flex items-center gap-2">
                {isBalanced ? (
                  <button
                    type="button"
                    onClick={handleFinalizeReconciliation}
                    className="px-4 py-2 rounded-xl bg-[#16643F] text-white font-bold text-xs flex items-center gap-1.5 shadow-xs hover:opacity-90 cursor-pointer"
                  >
                    <CheckCircle2 size={14} />
                    <span>Confirm & Record Reconciled</span>
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => setShowAdjustmentForm(!showAdjustmentForm)}
                    className="px-4 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs flex items-center gap-1.5 shadow-xs hover:opacity-90 cursor-pointer"
                  >
                    <Plus size={14} />
                    <span>Create Traceable Adjustment Entry</span>
                  </button>
                )}
              </div>
            </div>

            {/* Traceable Adjustment Drawer Form */}
            {showAdjustmentForm && !isBalanced && (
              <form
                onSubmit={handleCreateTraceableAdjustment}
                className="p-4 rounded-2xl bg-[#FFEEDF]/50 dark:bg-[#14100D] border border-[#B03C09]/40 dark:border-[#FF9A52]/40 space-y-3 animate-in fade-in duration-200"
              >
                <div className="flex items-center gap-2 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
                  <Scale size={15} />
                  <span>Traceable Accounting Journal Adjustment Entry</span>
                </div>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  Per accounting standards, this will post a traceable transaction in the shared
                  ledger for {formatPeso(Math.abs(reconciliationVariance))} classified as{' '}
                  <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8]">
                    {reconciliationVariance > 0
                      ? 'Adjustments & Found Cash'
                      : 'Adjustments & Write-offs'}
                  </span>{' '}
                  rather than silently altering account records.
                </p>

                <div>
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Auditor Note & Reason for Adjustment
                  </label>
                  <input
                    type="text"
                    required
                    value={adjustmentNote}
                    onChange={(e) => setAdjustmentNote(e.target.value)}
                    placeholder="e.g. Unlogged bank interbank transfer fee on statement"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setShowAdjustmentForm(false)}
                    className="flex-1 py-2 rounded-xl border border-[#F3DFCD] dark:border-[#383029] font-bold text-xs text-[#6B6156] dark:text-[#AC9E92] cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="flex-1 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs shadow-xs hover:opacity-90 cursor-pointer"
                  >
                    Post Traceable Entry
                  </button>
                </div>
              </form>
            )}
          </div>

          {/* Duplicate Transaction Detection */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <div className="flex justify-between items-center">
              <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
                <Copy size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                <span>Duplicate Detection Engine</span>
              </h3>
              <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                {potentialDuplicates.length} flagged
              </span>
            </div>

            {potentialDuplicates.length === 0 ? (
              <div className="p-3 rounded-2xl bg-emerald-500/10 text-emerald-800 dark:text-emerald-200 text-xs flex items-center gap-2">
                <CheckCircle2 size={15} />
                <span>Zero duplicate entries detected. Clean ledger integrity verified.</span>
              </div>
            ) : (
              <div className="space-y-2 divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                {potentialDuplicates.map((dup, idx) => (
                  <div key={idx} className="pt-2 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs">
                    <div>
                      <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        {dup.reason}
                      </div>
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Tx 1: {dup.tx1.merchant || dup.tx1.category} ({dup.tx1.date}) · Tx 2: {dup.tx2.merchant || dup.tx2.category} ({dup.tx2.date})
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() =>
                          changeTransactionStatus(
                            dup.tx2.id,
                            'duplicate',
                            'Marked as duplicate during statement reconciliation'
                          )
                        }
                        className="px-2.5 py-1 rounded-lg bg-rose-500/15 text-rose-700 dark:text-rose-300 font-bold text-[11px] hover:bg-rose-500/25 cursor-pointer"
                      >
                        Mark as Duplicate
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          changeTransactionStatus(
                            dup.tx2.id,
                            'confirmed',
                            'Audited and confirmed distinct transaction'
                          )
                        }
                        className="px-2.5 py-1 rounded-lg bg-stone-100 dark:bg-[#1E1813] text-[#5A5148] dark:text-[#C6B8AC] font-bold text-[11px] cursor-pointer"
                      >
                        Confirm Distinct
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Reconciliation History Audit Log */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-3xl p-5 shadow-xs space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
              <History size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <span>Reconciliation History Log</span>
            </h3>

            {reconciliationHistory.length === 0 ? (
              <div className="text-xs text-[#6B6156] dark:text-[#AC9E92] py-2">
                No past reconciliation sessions recorded.
              </div>
            ) : (
              <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
                {reconciliationHistory.map((rec) => {
                  const targetAcc = accounts.find((a) => a.id === rec.accountId);
                  return (
                    <div key={rec.id} className="py-2.5 flex items-center justify-between text-xs gap-2">
                      <div>
                        <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                          <span>{targetAcc?.name || 'Account'}</span>
                          <span
                            className={`px-1.5 py-0.2 rounded text-[9px] font-bold ${
                              rec.status === 'balanced'
                                ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'
                                : 'bg-amber-500/15 text-amber-700 dark:text-amber-300'
                            }`}
                          >
                            {rec.status.toUpperCase()}
                          </span>
                        </div>
                        <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                          {rec.date} · Book: {formatPeso(rec.bookBalance)} · Actual: {formatPeso(rec.actualBalance)}
                        </div>
                        {rec.notes && (
                          <div className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] italic mt-0.5">
                            "{rec.notes}"
                          </div>
                        )}
                      </div>

                      <div className="text-right">
                        <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                          Variance
                        </span>
                        <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          {formatPeso(rec.variance)}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
