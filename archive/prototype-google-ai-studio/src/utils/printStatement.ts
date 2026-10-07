import { AmortizationRow, YearlyAmortizationSummary } from '../types';
import { formatPeso } from './format';

export interface StatementData {
  title: string;
  institution: string;
  principal: number;
  annualRate: number;
  termLabel: string;
  monthlyPayment: number;
  totalInterest: number;
  totalPayment: number;
  interestSaved?: number;
  monthsSaved?: number;
  extraMonthlyPayment?: number;
  yearlySummary: YearlyAmortizationSummary[];
  schedule: AmortizationRow[];
  notes?: string;
}

export function generateStatementHtml(data: StatementData): string {
  const {
    title,
    institution,
    principal,
    annualRate,
    termLabel,
    monthlyPayment,
    totalInterest,
    totalPayment,
    interestSaved = 0,
    monthsSaved = 0,
    extraMonthlyPayment = 0,
    yearlySummary,
    schedule,
    notes,
  } = data;

  let cumPrincipal = 0;
  let cumInterest = 0;

  const rowsHtml = schedule
    .map((row) => {
      cumPrincipal += row.principalComponent || 0;
      cumInterest += row.interestComponent || 0;
      const totalOutflow = (row.scheduledPayment || 0) + (row.extraPayment || 0);

      return `
        <tr>
          <td style="text-align: center; font-weight: bold;">${row.period}</td>
          <td>${row.dueDate || `Month ${row.period}`}</td>
          <td style="text-align: right;">${formatPeso(row.scheduledPayment)}</td>
          <td style="text-align: right; color: #16643F;">${formatPeso(row.principalComponent)}</td>
          <td style="text-align: right; color: #9E2C1B;">${formatPeso(row.interestComponent)}</td>
          <td style="text-align: right;">${row.extraPayment ? formatPeso(row.extraPayment) : '-'}</td>
          <td style="text-align: right; font-weight: bold;">${formatPeso(totalOutflow)}</td>
          <td style="text-align: right;">${formatPeso(cumPrincipal)}</td>
          <td style="text-align: right;">${formatPeso(cumInterest)}</td>
          <td style="text-align: right; font-weight: bold; color: #15120F;">${formatPeso(row.remainingBalance)}</td>
        </tr>
      `;
    })
    .join('');

  const yearlyRowsHtml = yearlySummary
    .map(
      (y) => `
      <tr>
        <td style="font-weight: bold; text-align: center;">Year ${y.year}</td>
        <td style="text-align: right;">${formatPeso(y.totalPayment)}</td>
        <td style="text-align: right; color: #16643F;">${formatPeso(y.principalPaid)}</td>
        <td style="text-align: right; color: #9E2C1B;">${formatPeso(y.interestPaid)}</td>
        <td style="text-align: right; font-weight: bold;">${formatPeso(y.endingBalance)}</td>
      </tr>
    `
    )
    .join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${title} - Bank Amortization Statement</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm 10mm 15mm 10mm;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      color: #15120F;
      background: #FFFFFF;
      margin: 0;
      padding: 20px;
      font-size: 11px;
      line-height: 1.4;
    }
    .header {
      border-bottom: 2px solid #B03C09;
      padding-bottom: 12px;
      margin-bottom: 16px;
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
    }
    .brand {
      font-size: 18px;
      font-weight: 800;
      color: #B03C09;
      letter-spacing: -0.5px;
    }
    .doc-title {
      font-size: 14px;
      font-weight: 700;
      margin-top: 4px;
      color: #15120F;
    }
    .meta-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 10px;
      background: #FFF9F3;
      border: 1px solid #F3DFCD;
      border-radius: 8px;
      padding: 12px;
      margin-bottom: 16px;
    }
    .meta-item {
      display: flex;
      flex-direction: column;
    }
    .meta-label {
      font-size: 9px;
      text-transform: uppercase;
      color: #7A6E63;
      font-weight: 600;
    }
    .meta-value {
      font-size: 12px;
      font-weight: 700;
      color: #15120F;
      margin-top: 2px;
    }
    .highlight-card {
      background: #EBF8F1;
      border: 1px solid #A8DEC0;
      border-radius: 6px;
      padding: 8px 12px;
      margin-bottom: 16px;
      color: #16643F;
      font-size: 11px;
      font-weight: 600;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      page-break-inside: auto;
    }
    tr {
      page-break-inside: avoid;
      page-break-after: auto;
    }
    thead {
      display: table-header-group;
    }
    th {
      background: #F5EAE1;
      color: #383029;
      font-weight: 700;
      font-size: 9.5px;
      text-transform: uppercase;
      border: 1px solid #E2D1C3;
      padding: 6px 5px;
      text-align: left;
    }
    td {
      border: 1px solid #EFE4DA;
      padding: 5px 5px;
      font-size: 10px;
    }
    tr:nth-child(even) {
      background-color: #FAFAFA;
    }
    .section-heading {
      font-size: 12px;
      font-weight: 700;
      color: #15120F;
      margin: 16px 0 8px 0;
      border-left: 3px solid #B03C09;
      padding-left: 6px;
    }
    .footer {
      margin-top: 24px;
      padding-top: 10px;
      border-top: 1px solid #EFE4DA;
      font-size: 9px;
      color: #8C7F73;
      text-align: center;
    }
    @media print {
      body {
        padding: 0;
      }
      .no-print {
        display: none !important;
      }
    }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <div class="brand">SALAPIFY 3 • BANK-GRADE LOAN STATEMENT</div>
      <div class="doc-title">${title} (${institution})</div>
    </div>
    <div style="text-align: right; font-size: 10px; color: #7A6E63;">
      <div>Generated: ${new Date().toLocaleDateString('en-PH', { year: 'numeric', month: 'long', day: 'numeric' })}</div>
      <div>Method: Diminishing Balance Amortization</div>
    </div>
  </div>

  <div class="meta-grid">
    <div class="meta-item">
      <span class="meta-label">Principal Amount</span>
      <span class="meta-value">${formatPeso(principal)}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Interest Rate</span>
      <span class="meta-value">${annualRate}% per annum</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Loan Term</span>
      <span class="meta-value">${termLabel}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Monthly Amortization</span>
      <span class="meta-value" style="color: #B03C09;">${formatPeso(monthlyPayment)}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Total Interest Paid</span>
      <span class="meta-value" style="color: #9E2C1B;">${formatPeso(totalInterest)}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Total Payment</span>
      <span class="meta-value">${formatPeso(totalPayment)}</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Total Installments</span>
      <span class="meta-value">${schedule.length} Months</span>
    </div>
    <div class="meta-item">
      <span class="meta-label">Prepayment Status</span>
      <span class="meta-value">${extraMonthlyPayment > 0 ? `${formatPeso(extraMonthlyPayment)}/mo extra` : 'Standard Schedule'}</span>
    </div>
  </div>

  ${
    interestSaved > 0
      ? `
    <div class="highlight-card">
      ✓ Accelerated Prepayment Advantage: By paying ${formatPeso(extraMonthlyPayment)} extra per month, you save ${formatPeso(interestSaved)} in interest and payoff your loan ${monthsSaved} months early!
    </div>
  `
      : ''
  }

  ${notes ? `<div style="font-size: 10px; color: #5A5148; margin-bottom: 12px; font-style: italic;">Note: ${notes}</div>` : ''}

  <div class="section-heading">ANNUAL REPAYMENT SUMMARY</div>
  <table>
    <thead>
      <tr>
        <th style="text-align: center;">Year</th>
        <th style="text-align: right;">Total Paid (PHP)</th>
        <th style="text-align: right;">Principal Paid (PHP)</th>
        <th style="text-align: right;">Interest Paid (PHP)</th>
        <th style="text-align: right;">Ending Running Balance (PHP)</th>
      </tr>
    </thead>
    <tbody>
      ${yearlyRowsHtml}
    </tbody>
  </table>

  <div class="section-heading">DETAILED RUNNING BALANCE AMORTIZATION SCHEDULE</div>
  <table>
    <thead>
      <tr>
        <th style="text-align: center;">#</th>
        <th>Period / Date</th>
        <th style="text-align: right;">Scheduled (PHP)</th>
        <th style="text-align: right;">Principal (PHP)</th>
        <th style="text-align: right;">Interest (PHP)</th>
        <th style="text-align: right;">Extra (PHP)</th>
        <th style="text-align: right;">Total Outflow (PHP)</th>
        <th style="text-align: right;">Cum. Principal (PHP)</th>
        <th style="text-align: right;">Cum. Interest (PHP)</th>
        <th style="text-align: right;">Running Balance (PHP)</th>
      </tr>
    </thead>
    <tbody>
      ${rowsHtml}
    </tbody>
  </table>

  <div class="footer">
    Salapify 3 • Philippine Personal Finance & Debt Engine • Zero-telemetry offline calculation based on BSP & Pag-IBIG standards.
  </div>
</body>
</html>`;
}

/**
 * Triggers a browser print dialog using an invisible iframe, or opens a new tab/downloads printable HTML as fallback
 */
export function printAmortizationStatement(data: StatementData): void {
  const htmlContent = generateStatementHtml(data);

  // Method 1: Try printing via a temporary hidden iframe
  try {
    const printIframe = document.createElement('iframe');
    printIframe.style.position = 'fixed';
    printIframe.style.right = '0';
    printIframe.style.bottom = '0';
    printIframe.style.width = '0';
    printIframe.style.height = '0';
    printIframe.style.border = '0';
    printIframe.setAttribute('aria-hidden', 'true');
    document.body.appendChild(printIframe);

    const doc = printIframe.contentWindow?.document;
    if (doc) {
      doc.open();
      doc.write(htmlContent);
      doc.close();

      setTimeout(() => {
        try {
          printIframe.contentWindow?.focus();
          printIframe.contentWindow?.print();
        } catch (err) {
          console.warn('Iframe print blocked, falling back to Blob download/open:', err);
          fallbackPrint(htmlContent, data.title);
        } finally {
          setTimeout(() => {
            if (document.body.contains(printIframe)) {
              document.body.removeChild(printIframe);
            }
          }, 3000);
        }
      }, 400);
      return;
    }
  } catch (e) {
    console.warn('Hidden iframe print error:', e);
  }

  // Method 2: Blob fallback
  fallbackPrint(htmlContent, data.title);
}

function fallbackPrint(htmlContent: string, title: string): void {
  try {
    const blob = new Blob([htmlContent], { type: 'text/html;charset=utf-8' });
    const url = URL.createObjectURL(blob);

    // Try opening popup
    const printWindow = window.open(url, '_blank');
    if (printWindow) {
      printWindow.onload = () => {
        printWindow.focus();
        printWindow.print();
      };
    } else {
      // If popup blocked, trigger direct HTML download
      const a = document.createElement('a');
      a.href = url;
      const sanitizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '_');
      a.download = `${sanitizedTitle}_statement_printable.html`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }
  } catch (err) {
    console.error('Print fallback failed:', err);
  }
}
