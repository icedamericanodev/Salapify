import React, { useState, useMemo } from 'react';
import {
  Download,
  Copy,
  Printer,
  ChevronLeft,
  ChevronRight,
  FileSpreadsheet,
  Check,
  TrendingDown,
  Calendar,
  Layers,
  Sparkles,
  Info,
  Building,
  Table,
  FileText,
} from 'lucide-react';
import { formatPeso } from '../utils/format';
import { AmortizationRow } from '../types';
import { printAmortizationStatement, generateStatementHtml } from '../utils/printStatement';

export interface BankAmortizationTableProps {
  title: string;
  institution?: string;
  principal: number;
  annualRate: number | string;
  termLabel: string;
  monthlyPayment: number;
  totalInterest: number;
  totalPayment: number;
  interestSaved?: number;
  monthsSaved?: number;
  extraMonthlyPayment?: number;
  schedule: AmortizationRow[];
  notes?: string;
}

export const BankAmortizationTable: React.FC<BankAmortizationTableProps> = ({
  title,
  institution = 'Philippine Banking Standard',
  principal,
  annualRate,
  termLabel,
  monthlyPayment,
  totalInterest,
  totalPayment,
  interestSaved = 0,
  monthsSaved = 0,
  extraMonthlyPayment = 0,
  schedule,
  notes,
}) => {
  const [viewMode, setViewMode] = useState<'monthly' | 'yearly'>('monthly');
  const [copied, setCopied] = useState(false);
  const [isPrinting, setIsPrinting] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const pageSize = 24; // 2 years per page for comfortable mobile and desktop view

  // Group by Year for the Yearly Summary view
  const yearlySummary = useMemo(() => {
    const yearsMap: Record<
      number,
      {
        year: number;
        totalPayment: number;
        principalPaid: number;
        interestPaid: number;
        extraPaid: number;
        endingBalance: number;
        monthCount: number;
      }
    > = {};

    schedule.forEach((row) => {
      const year = Math.ceil(row.period / 12);
      if (!yearsMap[year]) {
        yearsMap[year] = {
          year,
          totalPayment: 0,
          principalPaid: 0,
          interestPaid: 0,
          extraPaid: 0,
          endingBalance: row.remainingBalance,
          monthCount: 0,
        };
      }

      yearsMap[year].totalPayment += row.scheduledPayment + (row.extraPayment || 0);
      yearsMap[year].principalPaid += row.principalComponent;
      yearsMap[year].interestPaid += row.interestComponent;
      yearsMap[year].extraPaid += row.extraPayment || 0;
      yearsMap[year].endingBalance = row.remainingBalance;
      yearsMap[year].monthCount += 1;
    });

    return Object.values(yearsMap);
  }, [schedule]);

  // Filtered rows for monthly view
  const filteredSchedule = useMemo(() => {
    if (!searchQuery.trim()) return schedule;
    const q = searchQuery.toLowerCase();
    return schedule.filter(
      (r) =>
        r.period.toString().includes(q) ||
        (r.dueDate && r.dueDate.toLowerCase().includes(q))
    );
  }, [schedule, searchQuery]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredSchedule.length / pageSize) || 1;
  const paginatedSchedule = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredSchedule.slice(start, start + pageSize);
  }, [filteredSchedule, currentPage, pageSize]);

  // Handle Export to CSV with full running balance and cumulative breakdowns
  // Dynamically matches the active view mode (Monthly Schedule vs Annual Summary)
  const handleExportCSV = () => {
    if (schedule.length === 0) return;

    const metaRows = [
      [`"SALAPIFY 3 - ${title.toUpperCase()}"`],
      [`"Institution / Standard: ${institution}"`],
      [`"Principal Loan Amount: PHP ${principal.toLocaleString('en-PH', { minimumFractionDigits: 2 })}"`],
      [`"Interest Rate: ${annualRate}%"`],
      [`"Loan Term: ${termLabel}"`],
      [`"Monthly Amortization: PHP ${monthlyPayment.toLocaleString('en-PH', { minimumFractionDigits: 2 })}"`],
      [`"Total Interest over Term: PHP ${totalInterest.toLocaleString('en-PH', { minimumFractionDigits: 2 })}"`],
      [`"Total Repayment Amount: PHP ${totalPayment.toLocaleString('en-PH', { minimumFractionDigits: 2 })}"`],
      ...(interestSaved > 0
        ? [
            [`"Total Prepayment Interest Saved: PHP ${interestSaved.toLocaleString('en-PH', { minimumFractionDigits: 2 })}"`],
            [`"Months Saved / Accelerated Payoff: ${monthsSaved} Months"`],
          ]
        : []),
      [''], // Blank separator
    ];

    let headers: string[] = [];
    let dataRows: (string | number)[][] = [];
    let filenameSuffix = '';

    if (viewMode === 'monthly') {
      filenameSuffix = 'monthly_schedule';
      metaRows.push([`"MONTH-BY-MONTH AMORTIZATION & RUNNING BALANCE SCHEDULE (${schedule.length} MONTHS)"`]);
      headers = [
        'Period #',
        'Due Date / Month',
        'Scheduled Payment (PHP)',
        'Principal Component (PHP)',
        'Interest Component (PHP)',
        'Extra / Prepayment (PHP)',
        'Total Monthly Outflow (PHP)',
        'Cumulative Principal Paid (PHP)',
        'Cumulative Interest Paid (PHP)',
        'Running Balance (PHP)',
      ];

      let cumPrincipal = 0;
      let cumInterest = 0;

      dataRows = schedule.map((row) => {
        cumPrincipal += row.principalComponent || 0;
        cumInterest += row.interestComponent || 0;
        const totalOutflow = (row.scheduledPayment || 0) + (row.extraPayment || 0);

        return [
          row.period,
          `"${row.dueDate || `Month ${row.period}`}"`,
          (row.scheduledPayment || 0).toFixed(2),
          (row.principalComponent || 0).toFixed(2),
          (row.interestComponent || 0).toFixed(2),
          (row.extraPayment || 0).toFixed(2),
          totalOutflow.toFixed(2),
          cumPrincipal.toFixed(2),
          cumInterest.toFixed(2),
          (row.remainingBalance || 0).toFixed(2),
        ];
      });
    } else {
      filenameSuffix = 'yearly_summary';
      metaRows.push([`"ANNUAL AMORTIZATION & RUNNING BALANCE SUMMARY (${yearlySummary.length} YEARS)"`]);
      headers = [
        'Year #',
        'Year Label',
        'Total Payment (PHP)',
        'Principal Paid (PHP)',
        'Interest Paid (PHP)',
        'Extra Prepayments (PHP)',
        'Year-End Running Balance (PHP)',
      ];

      dataRows = yearlySummary.map((yr) => [
        yr.year,
        `"Year ${yr.year}"`,
        yr.totalPayment.toFixed(2),
        yr.principalPaid.toFixed(2),
        yr.interestPaid.toFixed(2),
        (yr.extraPaid || 0).toFixed(2),
        yr.endingBalance.toFixed(2),
      ]);
    }

    const allLines: string[] = [];

    // Header metadata lines
    metaRows.forEach((row) => {
      allLines.push(row.join(','));
    });

    // Column headers
    allLines.push(headers.join(','));

    // Data rows
    dataRows.forEach((row) => {
      allLines.push(row.join(','));
    });

    const csvContent = allLines.join('\r\n');
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    const sanitizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '_');
    link.download = `${sanitizedTitle}_${filenameSuffix}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // Handle Export to JSON
  const handleExportJSON = () => {
    if (schedule.length === 0) return;

    let cumPrincipal = 0;
    let cumInterest = 0;

    const exportData = {
      app: 'Salapify 3',
      exportDate: new Date().toISOString(),
      reportType: `Debt Simulator Amortization Breakdown (${viewMode === 'monthly' ? 'Monthly Schedule' : 'Annual Summary'})`,
      selectedView: viewMode,
      loanDetails: {
        title,
        institution,
        principal,
        annualRate,
        termLabel,
        monthlyPayment,
        totalInterest,
        totalPayment,
        interestSaved,
        monthsSaved,
        extraMonthlyPayment,
      },
      annualSummary: yearlySummary,
      monthlySchedule: schedule.map((row) => {
        cumPrincipal += row.principalComponent || 0;
        cumInterest += row.interestComponent || 0;
        return {
          period: row.period,
          dueDate: row.dueDate || `Month ${row.period}`,
          scheduledPayment: row.scheduledPayment,
          principalComponent: row.principalComponent,
          interestComponent: row.interestComponent,
          extraPayment: row.extraPayment || 0,
          totalMonthlyOutflow: (row.scheduledPayment || 0) + (row.extraPayment || 0),
          cumulativePrincipalPaid: Math.round(cumPrincipal * 100) / 100,
          cumulativeInterestPaid: Math.round(cumInterest * 100) / 100,
          runningBalance: row.remainingBalance,
        };
      }),
    };

    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const sanitizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '_');
    a.download = `${sanitizedTitle}_${viewMode === 'monthly' ? 'monthly_schedule' : 'yearly_summary'}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Handle Copy Breakdown Text
  const handleCopyText = () => {
    let summaryText = `=========================================\n`;
    summaryText += `SALAPIFY BANK AMORTIZATION STATEMENT\n`;
    summaryText += `${title}\n`;
    summaryText += `=========================================\n`;
    summaryText += `Principal Amount: ${formatPeso(principal)}\n`;
    summaryText += `Interest Rate: ${annualRate}%\n`;
    summaryText += `Term: ${termLabel}\n`;
    summaryText += `Monthly Amortization: ${formatPeso(monthlyPayment)}\n`;
    summaryText += `Total Interest: ${formatPeso(totalInterest)}\n`;
    summaryText += `Total Repayment: ${formatPeso(totalPayment)}\n`;
    if (interestSaved > 0) {
      summaryText += `Interest Saved: ${formatPeso(interestSaved)} (${monthsSaved} months earlier)\n`;
    }
    if (viewMode === 'yearly') {
      summaryText += `\nYEARLY AMORTIZATION BREAKDOWN:\n`;
      summaryText += `Year | Total Paid | Principal | Interest | End Balance\n`;
      summaryText += `---------------------------------------------------------\n`;
      yearlySummary.forEach((y) => {
        summaryText += `Yr ${y.year.toString().padEnd(3)}| ${formatPeso(y.totalPayment).padEnd(11)}| ${formatPeso(y.principalPaid).padEnd(10)}| ${formatPeso(y.interestPaid).padEnd(9)}| ${formatPeso(y.endingBalance)}\n`;
      });
    } else {
      summaryText += `\nMONTH-BY-MONTH AMORTIZATION SCHEDULE:\n`;
      summaryText += `Mo | Due Date   | Payment    | Principal  | Interest   | Balance\n`;
      summaryText += `------------------------------------------------------------------\n`;
      schedule.forEach((m) => {
        summaryText += `M${m.period.toString().padEnd(3)}| ${(m.dueDate || `Month ${m.period}`).padEnd(11)}| ${formatPeso(m.scheduledPayment + (m.extraPayment || 0)).padEnd(11)}| ${formatPeso(m.principalComponent).padEnd(11)}| ${formatPeso(m.interestComponent).padEnd(11)}| ${formatPeso(m.remainingBalance)}\n`;
      });
    }
    summaryText += `=========================================\n`;

    navigator.clipboard.writeText(summaryText).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2200);
    });
  };

  // Handle Print Statement
  const handlePrint = () => {
    setIsPrinting(true);
    printAmortizationStatement({
      title,
      institution,
      principal,
      annualRate: typeof annualRate === 'string' ? parseFloat(annualRate) || 0 : annualRate,
      termLabel,
      monthlyPayment,
      totalInterest,
      totalPayment,
      interestSaved,
      monthsSaved,
      extraMonthlyPayment,
      yearlySummary,
      schedule,
      notes,
    });

    setTimeout(() => {
      setIsPrinting(false);
    }, 2000);
  };

  // Handle Download HTML Printable Document
  const handleDownloadPrintableHtml = () => {
    const html = generateStatementHtml({
      title,
      institution,
      principal,
      annualRate: typeof annualRate === 'string' ? parseFloat(annualRate) || 0 : annualRate,
      termLabel,
      monthlyPayment,
      totalInterest,
      totalPayment,
      interestSaved,
      monthsSaved,
      extraMonthlyPayment,
      yearlySummary,
      schedule,
      notes,
    });

    const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    const sanitizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '_');
    a.download = `${sanitizedTitle}_print_statement.html`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  if (schedule.length === 0) {
    return (
      <div className="p-6 text-center bg-[#FFF9F3] dark:bg-[#1A1410] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] text-xs text-[#7A6E63] dark:text-[#A89A8D]">
        Enter loan parameters to view the running balance amortization schedule.
      </div>
    );
  }

  return (
    <div className="bg-white dark:bg-[#27201A] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] overflow-hidden shadow-xs space-y-3">
      {/* Statement Header */}
      <div className="p-4 bg-[#FFEEDF]/60 dark:bg-[#1A1410] border-b border-[#F3DFCD] dark:border-[#383029] flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <Building size={16} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
            <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
              {title}
            </h4>
          </div>
          <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D] mt-0.5">
            {institution} • Bank-standard Diminishing Running Balance
          </p>
        </div>

        {/* Action Controls & Export Buttons */}
        <div className="flex items-center gap-1.5 flex-wrap shrink-0">
          <button
            type="button"
            onClick={handleExportCSV}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-[#16643F] text-white text-xs font-bold hover:bg-[#114d31] transition-colors cursor-pointer shadow-xs"
            title={`Download ${viewMode === 'monthly' ? 'monthly schedule' : 'yearly summary'} as CSV`}
          >
            <Download size={13} />
            <span>Export CSV</span>
          </button>

          <button
            type="button"
            onClick={handleExportJSON}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#15120F] dark:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold hover:opacity-90 transition-opacity cursor-pointer"
            title="Download full statement payload as JSON"
          >
            <FileSpreadsheet size={13} className="text-[#B03C09] dark:text-[#FF9A52]" />
            <span>JSON</span>
          </button>

          <button
            type="button"
            onClick={handleCopyText}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold hover:opacity-90 transition-opacity cursor-pointer"
            title="Copy breakdown summary to clipboard"
          >
            {copied ? <Check size={13} className="text-emerald-600" /> : <Copy size={13} />}
            <span>{copied ? 'Copied!' : 'Copy'}</span>
          </button>

          <button
            type="button"
            onClick={handlePrint}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#15120F] dark:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold hover:border-[#B03C09] dark:hover:border-[#FF9A52] transition-colors cursor-pointer"
            title="Print or save as PDF"
          >
            <Printer size={13} className="text-[#B03C09] dark:text-[#FF9A52]" />
            <span>{isPrinting ? 'Opening...' : 'Print / PDF'}</span>
          </button>

          <button
            type="button"
            onClick={handleDownloadPrintableHtml}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#7A6E63] dark:text-[#A89A8D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold hover:text-[#15120F] transition-colors cursor-pointer"
            title="Download printable HTML document (offline-ready)"
          >
            <FileText size={13} />
            <span>HTML Doc</span>
          </button>
        </div>
      </div>

      {/* Summary Metrics Strip */}
      <div className="px-4 grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
        <div className="p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
          <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight truncate">
            Principal Loan
          </span>
          <div className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 truncate" title={formatPeso(principal)}>
            {formatPeso(principal)}
          </div>
        </div>

        <div className="p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
          <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight truncate">
            Monthly Due
          </span>
          <div className="text-sm font-black text-[#B03C09] dark:text-[#FF9A52] tabular-nums mt-0.5 truncate" title={formatPeso(monthlyPayment)}>
            {formatPeso(monthlyPayment)}
          </div>
        </div>

        <div className="p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
          <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight truncate">
            Total Interest
          </span>
          <div className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 truncate" title={formatPeso(totalInterest)}>
            {formatPeso(totalInterest)}
          </div>
        </div>

        <div className="p-2.5 rounded-xl bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] min-w-0">
          <span className="text-[10px] uppercase font-bold text-[#7A6E63] dark:text-[#A89A8D] block leading-tight truncate">
            Total Payable
          </span>
          <div className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8] tabular-nums mt-0.5 truncate" title={formatPeso(totalPayment)}>
            {formatPeso(totalPayment)}
          </div>
        </div>
      </div>

      {/* Extra Payment Callout if active */}
      {interestSaved > 0 && (
        <div className="mx-4 p-3 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-xs flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 text-emerald-800 dark:text-emerald-200">
            <Sparkles size={16} className="text-emerald-600 shrink-0" />
            <span>
              Prepaying <strong>{formatPeso(extraMonthlyPayment || 0)}/mo</strong> saves{' '}
              <strong className="font-bold">{formatPeso(interestSaved)}</strong> in interest and shaves off{' '}
              <strong>{monthsSaved} months</strong>!
            </span>
          </div>
        </div>
      )}

      {/* View Mode Switcher & Filter Bar */}
      <div className="px-4 flex flex-wrap items-center justify-between gap-2 pt-1">
        <div className="flex rounded-xl p-0.5 bg-[#FFEEDF] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029]">
          <button
            type="button"
            onClick={() => {
              setViewMode('monthly');
              setCurrentPage(1);
            }}
            className={`px-3 py-1 rounded-lg text-xs font-bold transition-colors cursor-pointer ${
              viewMode === 'monthly'
                ? 'bg-[#B03C09] text-white shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Monthly Schedule ({schedule.length} Mos)
          </button>
          <button
            type="button"
            onClick={() => setViewMode('yearly')}
            className={`px-3 py-1 rounded-lg text-xs font-bold transition-colors cursor-pointer ${
              viewMode === 'yearly'
                ? 'bg-[#B03C09] text-white shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D]'
            }`}
          >
            Annual Summary ({yearlySummary.length} Yrs)
          </button>
        </div>

        {viewMode === 'monthly' && (
          <div className="flex items-center gap-2">
            <input
              type="text"
              placeholder="Search month or period..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setCurrentPage(1);
              }}
              className="px-2.5 py-1 text-xs rounded-lg bg-[#FFF9F3] dark:bg-[#1A1410] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none placeholder:text-[#A89A8D]"
            />
          </div>
        )}
      </div>

      {/* Table Container */}
      <div className="overflow-x-auto border-t border-[#F3DFCD] dark:border-[#383029]">
        {viewMode === 'monthly' ? (
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-[#FFF9F3] dark:bg-[#1A1410] border-b border-[#F3DFCD] dark:border-[#383029] text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                <th className="p-3 whitespace-nowrap">Period</th>
                <th className="p-3 text-right whitespace-nowrap">Payment Due</th>
                <th className="p-3 text-right whitespace-nowrap">Principal Portion</th>
                <th className="p-3 text-right whitespace-nowrap">Interest Portion</th>
                {extraMonthlyPayment > 0 && (
                  <th className="p-3 text-right whitespace-nowrap">Prepayment</th>
                )}
                <th className="p-3 text-right whitespace-nowrap">Ending Balance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
              {paginatedSchedule.map((row) => (
                <tr
                  key={row.period}
                  className="hover:bg-[#FFEEDF]/30 dark:hover:bg-[#1A1410]/50 transition-colors"
                >
                  <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8] whitespace-nowrap">
                    {row.dueDate || `Month ${row.period}`}
                  </td>
                  <td className="p-3 text-right font-medium text-[#15120F] dark:text-[#F6EFE8] tabular-nums whitespace-nowrap">
                    {formatPeso(row.scheduledPayment + (row.extraPayment || 0))}
                  </td>
                  <td className="p-3 text-right text-emerald-700 dark:text-emerald-400 font-medium tabular-nums whitespace-nowrap">
                    {formatPeso(row.principalComponent)}
                  </td>
                  <td className="p-3 text-right text-[#B03C09] dark:text-[#FF9A52] font-medium tabular-nums whitespace-nowrap">
                    {formatPeso(row.interestComponent)}
                  </td>
                  {extraMonthlyPayment > 0 && (
                    <td className="p-3 text-right text-blue-700 dark:text-blue-400 font-medium tabular-nums whitespace-nowrap">
                      {row.extraPayment ? formatPeso(row.extraPayment) : '-'}
                    </td>
                  )}
                  <td className="p-3 text-right font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums whitespace-nowrap">
                    {formatPeso(row.remainingBalance)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-[#FFF9F3] dark:bg-[#1A1410] border-b border-[#F3DFCD] dark:border-[#383029] text-[10px] font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                <th className="p-3 whitespace-nowrap">Year</th>
                <th className="p-3 text-right whitespace-nowrap">Total Paid</th>
                <th className="p-3 text-right whitespace-nowrap">Principal Amortized</th>
                <th className="p-3 text-right whitespace-nowrap">Interest Charged</th>
                <th className="p-3 text-right whitespace-nowrap">Year-End Balance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#F3DFCD] dark:divide-[#383029]">
              {yearlySummary.map((yr) => (
                <tr
                  key={yr.year}
                  className="hover:bg-[#FFEEDF]/30 dark:hover:bg-[#1A1410]/50 transition-colors"
                >
                  <td className="p-3 font-bold text-[#15120F] dark:text-[#F6EFE8] whitespace-nowrap">
                    Year {yr.year}{' '}
                    <span className="text-[10px] font-normal text-[#7A6E63] dark:text-[#A89A8D]">
                      ({yr.monthCount} mos)
                    </span>
                  </td>
                  <td className="p-3 text-right font-medium text-[#15120F] dark:text-[#F6EFE8] tabular-nums whitespace-nowrap">
                    {formatPeso(yr.totalPayment)}
                  </td>
                  <td className="p-3 text-right text-emerald-700 dark:text-emerald-400 font-medium tabular-nums whitespace-nowrap">
                    {formatPeso(yr.principalPaid)}
                  </td>
                  <td className="p-3 text-right text-[#B03C09] dark:text-[#FF9A52] font-medium tabular-nums whitespace-nowrap">
                    {formatPeso(yr.interestPaid)}
                  </td>
                  <td className="p-3 text-right font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums whitespace-nowrap">
                    {formatPeso(yr.endingBalance)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination Controls for Monthly View */}
      {viewMode === 'monthly' && totalPages > 1 && (
        <div className="p-3 border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between text-xs text-[#7A6E63] dark:text-[#A89A8D]">
          <span>
            Showing {(currentPage - 1) * pageSize + 1} to{' '}
            {Math.min(currentPage * pageSize, filteredSchedule.length)} of{' '}
            {filteredSchedule.length} payments
          </span>

          <div className="flex items-center gap-1">
            <button
              type="button"
              disabled={currentPage <= 1}
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              className="p-1 rounded-lg border border-[#F3DFCD] dark:border-[#383029] disabled:opacity-40 hover:bg-[#FFEEDF] dark:hover:bg-[#1A1410] cursor-pointer"
            >
              <ChevronLeft size={16} />
            </button>
            <span className="px-2 font-bold text-[#15120F] dark:text-[#F6EFE8]">
              {currentPage} / {totalPages}
            </span>
            <button
              type="button"
              disabled={currentPage >= totalPages}
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              className="p-1 rounded-lg border border-[#F3DFCD] dark:border-[#383029] disabled:opacity-40 hover:bg-[#FFEEDF] dark:hover:bg-[#1A1410] cursor-pointer"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* Disclosures & Regulatory Notes */}
      {notes && (
        <div className="p-3 bg-[#FFF9F3] dark:bg-[#1A1410] border-t border-[#F3DFCD] dark:border-[#383029] text-[11px] text-[#7A6E63] dark:text-[#A89A8D] flex items-start gap-2">
          <Info size={14} className="shrink-0 text-[#B03C09] dark:text-[#FF9A52] mt-0.5" />
          <p>{notes}</p>
        </div>
      )}
    </div>
  );
};
