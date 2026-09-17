import { formatPeso } from './format';
import { Account, Debt, Transaction, BillItem, InstallmentPlan, PaydayCycle, Goal } from '../types';
import {
  matchSystemLimitation,
  matchAppFeature,
  logSystemLimitationRequest,
} from './panKnowledgeRepository';

export interface PanMessageAction {
  label: string;
  actionId: string;
  payload?: any;
}

export interface PanResponse {
  text: string;
  badge?: string;
  stats?: { label: string; value: string; color?: string }[];
  actions?: PanMessageAction[];
  suggestedFollowUps?: string[];
  affordabilityStatus?: 'safe' | 'caution' | 'warning';
}

export interface PanContext {
  accounts: Account[];
  debts: Debt[];
  transactions: Transaction[];
  bills: BillItem[];
  installments: InstallmentPlan[];
  goals: Goal[];
  payday: PaydayCycle;
  safeToSpend: number;
  safeToSpendPerDay: number;
  totalAssets: number;
  totalLiabilities: number;
  netWorth: number;
  totalDebtsIOwe: number;
  totalDebtsOwedToMe: number;
  totalCreditUsed: number;
  lastIntent?: string;
  lastTopic?: string;
}

/**
 * Cleanly extracts a monetary amount from freeform text.
 * Supports:
 * - ₱2,500 / P2,500 / 2500 php / 2500 pesos
 * - 2.5k / 10k
 * - 2,500.50
 */
export function extractCurrencyAmount(text: string): number | null {
  const clean = text.toLowerCase().replace(/,/g, '');

  // Match: 2.5k, 10k
  const kMatch = clean.match(/(\d+(?:\.\d+)?)\s*k\b/);
  if (kMatch) {
    const val = parseFloat(kMatch[1]) * 1000;
    if (!isNaN(val) && val > 0 && val < 10000000) {
      return Math.round(val);
    }
  }

  // Match: ₱1500, p1500, 1500 pesos, 1500 php, 1500.00
  const currencyMatch = clean.match(/(?:[₱p]|php\s*|pesos?\s*)?(\d+(?:\.\d{1,2})?)(?:\s*(?:pesos?|php))?/i);
  if (currencyMatch && currencyMatch[1]) {
    const parsed = parseFloat(currencyMatch[1]);
    // Ignore current/recent years if not explicitly framed as an amount
    if (parsed >= 2020 && parsed <= 2030 && !clean.includes('₱') && !clean.includes('pesos') && !clean.includes('php') && !clean.includes('spend') && !clean.includes('afford') && !clean.includes('buy')) {
      return null;
    }
    if (!isNaN(parsed) && parsed > 0 && parsed < 100000000) {
      return parsed;
    }
  }

  return null;
}

/**
 * Calculates a comprehensive 0-100 Financial Health Score based on live ledger metrics.
 */
export function computeFinancialHealthScore(ctx: PanContext): {
  score: number;
  rating: string;
  color: string;
  metrics: {
    emergencyFundPts: number;
    creditPts: number;
    sweldoPacePts: number;
    debtAssetPts: number;
  };
  advice: string[];
} {
  // 1. Emergency Fund (Max 30 pts)
  const liquidCash = ctx.accounts
    .filter((a) => ['cash', 'bank', 'gcash', 'maya', 'debit'].includes(a.kind))
    .reduce((sum, a) => sum + a.balance, 0);

  const monthlyBills = ctx.bills.reduce((sum, b) => sum + b.amount, 0);
  const estimatedMonthlyBurn = Math.max(10000, monthlyBills * 1.8);
  const runwayMonths = liquidCash / estimatedMonthlyBurn;

  let emergencyFundPts = 10;
  if (runwayMonths >= 3) emergencyFundPts = 30;
  else if (runwayMonths >= 1) emergencyFundPts = 20;
  else if (runwayMonths >= 0.5) emergencyFundPts = 15;

  // 2. Credit Utilization (Max 25 pts)
  const creditCards = ctx.accounts.filter((a) => a.kind === 'credit');
  const totalLimit = creditCards.reduce((sum, c) => sum + (c.creditLimit || 40000), 0);
  const utilPercent = totalLimit > 0 ? (ctx.totalCreditUsed / totalLimit) * 100 : 0;

  let creditPts = 25;
  if (creditCards.length > 0) {
    if (utilPercent <= 15) creditPts = 25;
    else if (utilPercent <= 30) creditPts = 20;
    else if (utilPercent <= 50) creditPts = 12;
    else creditPts = 5;
  }

  // 3. Sweldo Pacing Health (Max 25 pts)
  let sweldoPacePts = 15;
  if (ctx.safeToSpendPerDay >= 500) sweldoPacePts = 25;
  else if (ctx.safeToSpendPerDay >= 300) sweldoPacePts = 20;
  else if (ctx.safeToSpendPerDay >= 150) sweldoPacePts = 12;
  else sweldoPacePts = 5;

  // 4. Debt to Asset Ratio (Max 20 pts)
  let debtAssetPts = 10;
  if (ctx.totalAssets > 0) {
    const debtRatio = ctx.totalLiabilities / ctx.totalAssets;
    if (debtRatio <= 0.2) debtAssetPts = 20;
    else if (debtRatio <= 0.4) debtAssetPts = 16;
    else if (debtRatio <= 0.7) debtAssetPts = 12;
    else debtAssetPts = 5;
  } else if (ctx.totalLiabilities === 0) {
    debtAssetPts = 15;
  }

  const score = Math.min(100, Math.max(10, emergencyFundPts + creditPts + sweldoPacePts + debtAssetPts));

  let rating = 'Needs Attention';
  let color = '#B03C09';
  if (score >= 80) {
    rating = 'Excellent & Resilient';
    color = '#16643F';
  } else if (score >= 65) {
    rating = 'Solid & Balanced';
    color = '#2E7D32';
  } else if (score >= 50) {
    rating = 'Fair / Tight Cushion';
    color = '#D97706';
  }

  const advice: string[] = [];
  if (runwayMonths < 2) {
    advice.push('Grow liquid savings in high-yield digital banks (like MariBank or Maya) to cover at least 3 months of basic expenses.');
  }
  if (utilPercent > 30) {
    advice.push(`Pay down card balances to bring credit utilization below 30% (currently ${Math.round(utilPercent)}%).`);
  }
  if (ctx.safeToSpendPerDay < 300) {
    advice.push(`Your daily pace is tight at ${formatPeso(ctx.safeToSpendPerDay)}/day. Prioritize home meals and avoid impulse checkouts until payday.`);
  }
  if (ctx.totalDebtsOwedToMe > 0) {
    advice.push(`Follow up on ${formatPeso(ctx.totalDebtsOwedToMe)} in receivables (pahiram/split bills) to boost your cash buffer.`);
  }

  return {
    score,
    rating,
    color,
    metrics: { emergencyFundPts, creditPts, sweldoPacePts, debtAssetPts },
    advice,
  };
}

/**
 * Intelligent client-side rule, pattern, and semantic engine for Pan AI Copilot.
 * 100% offline-first, private, and deterministic.
 */
export function processPanQuery(query: string, ctx: PanContext): PanResponse {
  const rawQ = query.trim();
  const q = rawQ.toLowerCase();

  // 0A. Check System Limitations Repository first
  const limitation = matchSystemLimitation(q);
  if (limitation) {
    logSystemLimitationRequest(query, limitation.id);

    const actions: PanMessageAction[] = [];
    if (limitation.actionId && limitation.actionLabel) {
      actions.push({
        label: limitation.actionLabel,
        actionId: limitation.actionId,
      });
    }

    return {
      text: `**System Notice: ${limitation.title}**\n\n${limitation.reason}\n\n• **How Salapify solves this**: ${limitation.offlineWorkaround}\n\n*Note: Your inquiry has been logged to our offline limitations registry to evaluate future updates without sacrificing your privacy.*`,
      badge: 'System Guardrail',
      stats: [
        { label: 'Privacy Status', value: '100% Protected', color: '#16643F' },
        { label: 'Cloud Servers', value: 'Zero (Offline)', color: '#B03C09' },
      ],
      actions,
      suggestedFollowUps: [
        'Where can I see the offline registry?',
        'How does Salapify protect my privacy?',
        'Safe to Spend today?',
      ],
    };
  }

  // 0B. Offline Registry direct questions
  if (
    q.includes('offline registry') ||
    q.includes('limitation registry') ||
    q.includes('see the offline registry') ||
    q.includes('view the offline registry') ||
    q.includes('limitations list') ||
    q.includes('offline logs')
  ) {
    return {
      text: `The **System Limitations & Offline Registry** is an on-device transparency ledger where you can audit all architectural privacy boundaries and logged inquiries:\n\n• **Guardrails**: Explains why Salapify avoids online bank credential scraping, SMS background reading, and cloud servers.\n• **Offline Workarounds**: Safe local alternatives for every limitation.\n• **Logged Inquiries**: Review or clear all unsupported questions logged locally in your browser's \`salapify_limitation_requests_log\`.\n\nTap the button below to inspect the registry now.`,
      badge: 'Privacy & Security',
      stats: [
        { label: 'Storage', value: '100% Local', color: '#16643F' },
        { label: 'Guardrails', value: 'Explicit' },
      ],
      actions: [
        { label: 'Open Offline Registry', actionId: 'open_offline_registry' },
        { label: 'Privacy Guarantee', actionId: 'open_setup_privacy' },
      ],
      suggestedFollowUps: [
        'How does Salapify protect my privacy?',
        'Safe to Spend today?',
        'What are the features of Salapify?',
      ],
    };
  }

  // 1. Dynamic "Can I Afford It?" Simulator
  const isAffordabilityQuery =
    q.includes('afford') ||
    q.includes('kaya ko ba') ||
    q.includes('pwede ba bilhin') ||
    q.includes('pede ba bilhin') ||
    q.includes('pwede bumili') ||
    q.includes('can i buy') ||
    q.includes('can i spend') ||
    q.includes('what if i spend') ||
    q.includes('what if i buy');

  const detectedAmount = extractCurrencyAmount(q);

  if (isAffordabilityQuery && detectedAmount && detectedAmount > 0) {
    const daysLeft = Math.max(1, ctx.payday.daysToPayday);
    const postSafeToSpend = ctx.safeToSpend - detectedAmount;
    const postDailyPace = Math.max(0, postSafeToSpend / daysLeft);
    const bufferPercentage = Math.round((detectedAmount / Math.max(1, ctx.safeToSpend)) * 100);

    let status: 'safe' | 'caution' | 'warning' = 'safe';
    let headline = '';
    let advice = '';

    if (postSafeToSpend < 0) {
      status = 'warning';
      headline = '🛑 High Risk of Petsa de Peligro';
      advice = `Spending ${formatPeso(detectedAmount)} exceeds your current Safe to Spend buffer by ${formatPeso(
        Math.abs(postSafeToSpend)
      )}. Doing this means you will cut into committed bills, scheduled debt payments, or emergency savings. Recommend holding off until next payday (${ctx.payday.nextPayday.split(',')[0]}).`;
    } else if (postDailyPace < 150) {
      status = 'caution';
      headline = '⚠️ Tight Squeeze Alert';
      advice = `You have enough to cover ${formatPeso(detectedAmount)}, but it will consume **${bufferPercentage}%** of your remaining sweldo buffer. Your daily allowance will drop sharply to **${formatPeso(
        postDailyPace
      )}/day** for the next ${daysLeft} days. Be prepared for strict belt-tightening on daily meals and transpo!`;
    } else {
      status = 'safe';
      headline = '✅ Green Light: Guilt-Free Purchase';
      advice = `You can safely afford this purchase! After spending ${formatPeso(
        detectedAmount
      )}, you will still have **${formatPeso(postSafeToSpend)}** remaining, giving you a healthy pace of **${formatPeso(
        postDailyPace
      )}/day** until payday on ${ctx.payday.nextPayday.split(',')[0]}.`;
    }

    return {
      text: `### ${headline}\n\n**Purchase Evaluation for ${formatPeso(detectedAmount)}**:\n\n• **Current Safe to Spend**: ${formatPeso(
        ctx.safeToSpend
      )} (${formatPeso(ctx.safeToSpendPerDay)}/day)\n• **After Purchase**: ${formatPeso(
        Math.max(0, postSafeToSpend)
      )} remaining\n• **New Daily Pace**: ${formatPeso(postDailyPace)}/day for ${daysLeft} days\n\n${advice}`,
      badge: 'Affordability Simulator',
      affordabilityStatus: status,
      stats: [
        {
          label: 'Verdict',
          value: status === 'safe' ? 'Guilt-Free' : status === 'caution' ? 'Caution' : 'Over Buffer',
          color: status === 'safe' ? '#16643F' : status === 'caution' ? '#D97706' : '#B03C09',
        },
        { label: 'New Daily Pace', value: `${formatPeso(postDailyPace)}/day` },
        { label: 'Buffer Used', value: `${bufferPercentage}%` },
      ],
      actions: [
        { label: 'Log as Expense', actionId: 'open_log_expense' },
        { label: 'Inspect Safe to Spend', actionId: 'open_safe_to_spend' },
      ],
      suggestedFollowUps: [
        'Which bills are due before payday?',
        'Safe to Spend today?',
        'Audit my finances',
      ],
    };
  }

  // 2. Financial Health Audit & Score Checkup
  if (
    q.includes('audit my finance') ||
    q.includes('audit') ||
    q.includes('financial health') ||
    q.includes('health score') ||
    q.includes('checkup') ||
    q.includes('rate my budget') ||
    q.includes('am i doing okay') ||
    q.includes('financial score')
  ) {
    const health = computeFinancialHealthScore(ctx);
    const adviceList = health.advice.map((a) => `• ${a}`).join('\n');

    return {
      text: `### Salapify Financial Health Audit\n\nYour current Financial Health Score is **${health.score}/100** (**${health.rating}**).\n\n**Component Breakdown**:\n• **Emergency Runway**: ${health.metrics.emergencyFundPts}/30 pts\n• **Credit Card Health**: ${health.metrics.creditPts}/25 pts\n• **Sweldo Daily Pacing**: ${health.metrics.sweldoPacePts}/25 pts\n• **Debt-to-Asset Balance**: ${health.metrics.debtAssetPts}/20 pts\n\n**Expert Council Recommendations**:\n${adviceList || '• Your current allocations are stable! Maintain your regular savings contributions and pay down cards before cutoffs.'}`,
      badge: 'Financial Audit',
      stats: [
        { label: 'Overall Score', value: `${health.score}/100`, color: health.color },
        { label: 'Rating', value: health.rating },
        { label: 'Safe Balance', value: formatPeso(ctx.safeToSpend) },
      ],
      actions: [
        { label: 'Open Financial Reports', actionId: 'open_reports' },
        { label: 'Review Accounts', actionId: 'open_accounts' },
        { label: 'Savings & Goals', actionId: 'open_savings_planner' },
      ],
      suggestedFollowUps: [
        'Where should I save my emergency fund?',
        'Safe to Spend today?',
        'Which credit cards are due soon?',
      ],
    };
  }

  // 3. Safe to spend / daily pacing / sweldo / petsa de peligro
  if (
    q.includes('safe to spend') ||
    q.includes('safe-to-spend') ||
    q.includes('pacing') ||
    q.includes('how much can i spend') ||
    q.includes('spend today') ||
    q.includes('magkano pwede gastusin') ||
    q.includes('magkano pa pera ko') ||
    q.includes('petsa de peligro')
  ) {
    const daysLeft = ctx.payday.daysToPayday;
    const isTight = ctx.safeToSpendPerDay < 300;

    let advice = '';
    if (isTight) {
      advice = `Your daily pace is quite tight at ${formatPeso(ctx.safeToSpendPerDay)}/day until ${ctx.payday.nextPayday.split(',')[0]}. Focus strictly on essentials (pantry & transpo) to avoid dipping into credit or emergency savings.`;
    } else {
      advice = `You have a healthy cushion of ${formatPeso(ctx.safeToSpend)} for the remaining ${daysLeft} days of this sweldo cycle. Keep your daily spending around ${formatPeso(ctx.safeToSpendPerDay)} to finish the cycle with surplus.`;
    }

    return {
      text: `Your current Safe to Spend is **${formatPeso(ctx.safeToSpend)}**, which gives you **${formatPeso(ctx.safeToSpendPerDay)} per day** for the next ${daysLeft} days until payday (${ctx.payday.nextPayday.split(',')[0]}).\n\n${advice}`,
      badge: 'Safe to Spend',
      stats: [
        { label: 'Safe Balance', value: formatPeso(ctx.safeToSpend), color: '#16643F' },
        { label: 'Daily Pace', value: `${formatPeso(ctx.safeToSpendPerDay)}/day`, color: '#B03C09' },
        { label: 'Days to Sweldo', value: `${daysLeft} days` },
      ],
      actions: [
        { label: 'Open Safe to Spend Details', actionId: 'open_safe_to_spend' },
        { label: 'Log New Expense', actionId: 'open_log_expense' },
      ],
      suggestedFollowUps: [
        'Can I afford ₱1,500 today?',
        'Which bills are due before payday?',
        'Who owes me money right now?',
      ],
    };
  }

  // 4. Who owes me / Pahiram / Pautang / Receivables
  if (
    q.includes('who owes me') ||
    q.includes('owes me') ||
    q.includes('pautang') ||
    q.includes('pahiram') ||
    q.includes('receivable') ||
    q.includes('collect') ||
    q.includes('owed to me') ||
    q.includes('sino may utang')
  ) {
    const owedDebts = ctx.debts.filter(
      (d) => d.direction === 'owed_to_me' && !d.isSettled
    );
    const totalOwed = owedDebts.reduce((sum, d) => sum + (d.totalAmount - d.paidAmount), 0);

    if (owedDebts.length === 0) {
      return {
        text: 'Clean slate! Nobody currently owes you any money in your Debt & Pahiram register.',
        badge: 'Debts & Pahiram',
        stats: [{ label: 'Pending to Collect', value: '₱0.00', color: '#16643F' }],
        actions: [{ label: 'Open Debt Register', actionId: 'open_debt' }],
        suggestedFollowUps: ['How much debt do I owe?', 'What is my net worth?'],
      };
    }

    const items = owedDebts
      .slice(0, 5)
      .map(
        (d) =>
          `• **${d.person}**: ${formatPeso(d.totalAmount - d.paidAmount)}${
            d.dueDate ? ` (Due: ${d.dueDate})` : ''
          }`
      )
      .join('\n');

    return {
      text: `You have **${owedDebts.length} active receivable(s)** totaling **${formatPeso(
        totalOwed
      )}** waiting to be collected:\n\n${items}\n\nFriendly reminder: Collecting these returns cash directly to your liquid accounts!`,
      badge: 'Pahiram & Split Bills',
      stats: [
        { label: 'Total Collectible', value: formatPeso(totalOwed), color: '#16643F' },
        { label: 'Active Borrowers', value: `${owedDebts.length} people` },
      ],
      actions: [
        { label: 'View Debt & Pahiram Beam', actionId: 'open_debt' },
        { label: 'Split a Bill', actionId: 'open_split_bill' },
      ],
      suggestedFollowUps: [
        'How much debt do I owe?',
        'Which credit cards are due soon?',
        'Safe to Spend today?',
      ],
    };
  }

  // 5. Debts I owe / Liabilities / Utang ko
  if (
    q.includes('i owe') ||
    q.includes('my debt') ||
    q.includes('utang ko') ||
    q.includes('liabilities') ||
    q.includes('loans') ||
    q.includes('mortgage') ||
    q.includes('magkano utang ko')
  ) {
    const myDebts = ctx.debts.filter(
      (d) => d.direction === 'i_owe' && !d.isSettled
    );
    const totalIOwe = myDebts.reduce((sum, d) => sum + (d.totalAmount - d.paidAmount), 0);

    const creditAccounts = ctx.accounts.filter((a) => a.kind === 'credit');
    const totalCreditBal = creditAccounts.reduce((sum, a) => sum + a.balance, 0);
    const grandTotalDebt = totalIOwe + totalCreditBal;

    const list = myDebts
      .slice(0, 4)
      .map(
        (d) =>
          `• **${d.person}**: ${formatPeso(d.totalAmount - d.paidAmount)}${
            d.dueDate ? ` (Due: ${d.dueDate})` : ''
          }`
      )
      .join('\n');

    return {
      text: `You currently have **${formatPeso(
        grandTotalDebt
      )}** in total obligations (${formatPeso(totalCreditBal)} credit card balances + ${formatPeso(
        totalIOwe
      )} direct debts/loans):\n\n${list || '• No direct personal debts recorded.'}\n\nSalapify calculates these automatically into your Safe-to-Spend formula so you never miss a payment.`,
      badge: 'Debt & Obligations',
      stats: [
        { label: 'Total Debt', value: formatPeso(grandTotalDebt), color: '#B03C09' },
        { label: 'Cards Balance', value: formatPeso(totalCreditBal) },
        { label: 'Direct Debts', value: formatPeso(totalIOwe) },
      ],
      actions: [
        { label: 'Manage Debts', actionId: 'open_debt' },
        { label: 'Review Accounts', actionId: 'open_accounts' },
      ],
      suggestedFollowUps: [
        'Which credit cards are due soon?',
        'Who owes me money right now?',
        'What is my net worth breakdown?',
      ],
    };
  }

  // 6. Credit cards & due dates & utilization
  if (
    q.includes('credit card') ||
    q.includes('card due') ||
    q.includes('due date') ||
    q.includes('utilization') ||
    q.includes('bpi card') ||
    q.includes('bdo card') ||
    q.includes('cards')
  ) {
    const cards = ctx.accounts.filter((a) => a.kind === 'credit');

    if (cards.length === 0) {
      return {
        text: 'You have no credit card accounts registered in Salapify yet. You can add one anytime in the Accounts screen.',
        badge: 'Credit Cards',
        actions: [{ label: 'Add Card in Accounts', actionId: 'open_accounts' }],
      };
    }

    const cardDetails = cards
      .map((c) => {
        const limit = c.creditLimit || 40000;
        const util = Math.round((c.balance / limit) * 100);
        const warning = util > 30 ? ' ⚠️ (>30% utilization)' : '';
        return `• **${c.name}** (${c.institution}): ${formatPeso(c.balance)} / ${formatPeso(
          limit
        )} (${util}% used)${c.dueDate ? ` | Due: ${c.dueDate}` : ''}${warning}`;
      })
      .join('\n');

    return {
      text: `Here is the status of your **${cards.length} credit card(s)**:\n\n${cardDetails}\n\nRule of thumb: Maintain card utilization under 30% to maximize your Philippine credit score.`,
      badge: 'Credit Shield',
      stats: [
        { label: 'Total Card Debt', value: formatPeso(ctx.totalCreditUsed), color: '#B03C09' },
        { label: 'Cards Count', value: `${cards.length} cards` },
      ],
      actions: [
        { label: 'View Accounts & Cards', actionId: 'open_accounts' },
        { label: 'Check Upcoming Bills', actionId: 'open_bills' },
      ],
      suggestedFollowUps: [
        'Upcoming bills this week',
        'Safe to Spend today?',
        'How much in my bank accounts?',
      ],
    };
  }

  // 7. Upcoming bills & Scheduled Payables
  if (
    q.includes('bill') ||
    q.includes('bills') ||
    q.includes('upcoming') ||
    q.includes('meralco') ||
    q.includes('maynilad') ||
    q.includes('rent') ||
    q.includes('due this week') ||
    q.includes('bayarin')
  ) {
    const unpaidBills = ctx.bills.filter((b) => !b.isPaid);
    const totalUnpaid = unpaidBills.reduce((sum, b) => sum + b.amount, 0);

    if (unpaidBills.length === 0) {
      return {
        text: 'All your logged recurring bills are marked as paid! No pending bills for this period.',
        badge: 'Bills & Payables',
        stats: [{ label: 'Pending Bills', value: '₱0.00', color: '#16643F' }],
        actions: [{ label: 'Open Bills Manager', actionId: 'open_bills' }],
      };
    }

    const billList = unpaidBills
      .slice(0, 5)
      .map((b) => `• **${b.name}**: ${formatPeso(b.amount)} (Due: Day ${b.dueDate})`)
      .join('\n');

    return {
      text: `You have **${unpaidBills.length} unpaid bill(s)** totaling **${formatPeso(
        totalUnpaid
      )}** before the end of this cycle:\n\n${billList}\n\nPan automatically reserves this money inside your Safe-to-Spend calculation so you don't accidentally spend bill funds.`,
      badge: 'Bills & Payables',
      stats: [
        { label: 'Unpaid Bills', value: formatPeso(totalUnpaid), color: '#B03C09' },
        { label: 'Pending Count', value: `${unpaidBills.length} bills` },
      ],
      actions: [
        { label: 'Manage Bills & Due Dates', actionId: 'open_bills' },
        { label: 'Safe to Spend Check', actionId: 'open_safe_to_spend' },
      ],
      suggestedFollowUps: [
        'Safe to Spend today?',
        'Which credit cards are due soon?',
        'Who owes me money right now?',
      ],
    };
  }

  // 8. Spending by Category or Merchant (Food, Transpo, Shopping, Utilities, Grab, Starbucks, Jollibee, etc.)
  const categoriesMap: { [key: string]: string } = {
    food: 'Food & Dining',
    dining: 'Food & Dining',
    restaurant: 'Food & Dining',
    grabfood: 'Food & Dining',
    foodpanda: 'Food & Dining',
    jollibee: 'Food & Dining',
    mcdo: 'Food & Dining',
    starbucks: 'Food & Dining',
    groceries: 'Groceries & Pantry',
    supermarket: 'Groceries & Pantry',
    pantry: 'Groceries & Pantry',
    transpo: 'Transportation',
    transportation: 'Transportation',
    grab: 'Transportation',
    angkas: 'Transportation',
    joyride: 'Transportation',
    gas: 'Transportation',
    toll: 'Transportation',
    commute: 'Transportation',
    shopping: 'Shopping & Retail',
    shopee: 'Shopping & Retail',
    lazada: 'Shopping & Retail',
    zara: 'Shopping & Retail',
    uniqlo: 'Shopping & Retail',
    utilities: 'Utilities & Bills',
    meralco: 'Utilities & Bills',
    maynilad: 'Utilities & Bills',
    converge: 'Utilities & Bills',
    pldt: 'Utilities & Bills',
    health: 'Health & Wellness',
    medicine: 'Health & Wellness',
    mercury: 'Health & Wellness',
    watsons: 'Health & Wellness',
    entertainment: 'Entertainment & Leisure',
    netflix: 'Entertainment & Leisure',
    spotify: 'Entertainment & Leisure',
  };

  const matchedCatKeyword = Object.keys(categoriesMap).find((kw) => q.includes(kw));

  if (
    matchedCatKeyword ||
    q.includes('spent on') ||
    q.includes('spending') ||
    q.includes('magkano nagastos') ||
    q.includes('biggest expense') ||
    q.includes('pinakamalaking gastos')
  ) {
    const expenseTx = ctx.transactions.filter((t) => t.type === 'expense');

    if (q.includes('biggest expense') || q.includes('pinakamalaking gastos')) {
      if (expenseTx.length === 0) {
        return {
          text: 'You have no expense transactions logged in your ledger yet.',
          badge: 'Activity Ledger',
          actions: [{ label: 'Log New Expense', actionId: 'open_log_expense' }],
        };
      }
      const sortedByAmount = [...expenseTx].sort((a, b) => b.amount - a.amount);
      const biggest = sortedByAmount[0];

      return {
        text: `Your biggest recorded single expense is **${formatPeso(biggest.amount)}** for **${
          biggest.merchant || biggest.category
        }** (${biggest.category}) on ${biggest.date}.\n\nLogging transactions regularly keeps your safe-to-spend pace accurate!`,
        badge: 'Top Expense',
        stats: [
          { label: 'Largest Single Expense', value: formatPeso(biggest.amount), color: '#B03C09' },
          { label: 'Category', value: biggest.category },
        ],
        actions: [
          { label: 'View Activity Ledger', actionId: 'open_ledger' },
          { label: 'Log New Expense', actionId: 'open_log_expense' },
        ],
        suggestedFollowUps: ['Safe to Spend today?', 'How much did I spend on Food?'],
      };
    }

    let targetLabel = 'All Expenses';
    let filtered = expenseTx;

    if (matchedCatKeyword) {
      targetLabel = categoriesMap[matchedCatKeyword];
      filtered = expenseTx.filter(
        (t) =>
          t.category.toLowerCase().includes(matchedCatKeyword) ||
          (t.merchant && t.merchant.toLowerCase().includes(matchedCatKeyword))
      );
    }

    const totalSpent = filtered.reduce((sum, t) => sum + t.amount, 0);

    return {
      text: `You have recorded **${filtered.length} transaction(s)** in **${targetLabel}** totaling **${formatPeso(
        totalSpent
      )}**.\n\nTip: Tracking every meal, delivery, and checkout is the easiest way to catch lifestyle creep before petsa de peligro!`,
      badge: targetLabel,
      stats: [
        { label: `Total ${targetLabel}`, value: formatPeso(totalSpent), color: '#B03C09' },
        { label: 'Transactions', value: `${filtered.length} logs` },
      ],
      actions: [
        { label: 'View Activity Ledger', actionId: 'open_ledger' },
        { label: 'Log New Expense', actionId: 'open_log_expense' },
      ],
      suggestedFollowUps: [
        'Safe to Spend today?',
        'Can I afford ₱1,500?',
        'Upcoming bills this week',
      ],
    };
  }

  // 9. Specific Account Balances (GCash, Maya, MariBank, BPI, BDO, SeaBank, etc.)
  const foundAcc = ctx.accounts.find((a) => {
    const nameL = a.name.toLowerCase();
    const instL = a.institution.toLowerCase();
    return (
      q.includes(instL) ||
      q.includes(nameL) ||
      (q.includes('gcash') && instL === 'gcash') ||
      (q.includes('maya') && instL === 'maya') ||
      (q.includes('maribank') && instL.includes('maribank')) ||
      (q.includes('seabank') && instL.includes('seabank')) ||
      (q.includes('bpi') && instL.includes('bpi')) ||
      (q.includes('bdo') && instL.includes('bdo')) ||
      (q.includes('gotyme') && instL.includes('gotyme')) ||
      (q.includes('unionbank') && instL.includes('unionbank'))
    );
  });

  if (
    foundAcc &&
    (q.includes('how much') ||
      q.includes('balance') ||
      q.includes('check') ||
      q.includes('account') ||
      q.includes('magkano'))
  ) {
    return {
      text: `Your balance for **${foundAcc.name}** (${foundAcc.institution}) is currently **${formatPeso(
        foundAcc.balance
      )}** (${foundAcc.kind.toUpperCase()}).${
        foundAcc.interestRate ? ` It is earning ${foundAcc.interestRate}% p.a. yield!` : ''
      }`,
      badge: foundAcc.institution,
      stats: [
        { label: 'Current Balance', value: formatPeso(foundAcc.balance), color: '#16643F' },
        { label: 'Account Type', value: foundAcc.kind.toUpperCase() },
      ],
      actions: [
        { label: 'View All Accounts', actionId: 'open_accounts' },
        { label: 'Transfer Money', actionId: 'open_transfer' },
      ],
      suggestedFollowUps: [
        'How much total cash do I have?',
        'What is my net worth?',
        'Safe to Spend today?',
      ],
    };
  }

  // 10. Unlinked Philippine Institutions (Atome, TikTok PayLater, RCBC, PNB, EastWest, AUB)
  if (
    q.includes('atome') ||
    q.includes('tiktok') ||
    q.includes('paylater') ||
    q.includes('rcbc') ||
    q.includes('pnb') ||
    q.includes('eastwest') ||
    q.includes('aub') ||
    q.includes('billease')
  ) {
    if (q.includes('atome')) {
      return {
        text: `You don't have an **Atome** account logged in Salapify yet.\n\n• **Category**: Buy Now, Pay Later (BNPL) / Installments\n• **Features**: 0% interest 3-month installment splits for retail & shopping checkouts.\n• **Tip**: Add Atome under **Accounts** (type: Credit / BNPL). Logging your scheduled payments ensures they are automatically reserved from your next sweldo!`,
        badge: 'Atome BNPL',
        stats: [{ label: 'Status', value: 'Supported' }, { label: 'Split Terms', value: '3 or 6 months' }],
        actions: [{ label: 'Add Atome in Accounts', actionId: 'open_accounts' }],
        suggestedFollowUps: ['Which credit cards are due soon?', 'Safe to Spend today?'],
      };
    }
    if (q.includes('billease')) {
      return {
        text: `**BillEase** is a popular Philippine digital credit app.\n\n• **Category**: Micro-Credit / E-commerce BNPL\n• **Features**: Installment purchases for Lazada, Shopee, airfare, and bills.\n• Track BillEase under Credit/Loan accounts in Salapify to monitor repayment dates and interest charges.`,
        badge: 'BillEase',
        stats: [{ label: 'Status', value: 'Supported' }],
        actions: [{ label: 'Add BillEase in Accounts', actionId: 'open_accounts' }],
        suggestedFollowUps: ['Safe to Spend today?', 'Which credit cards are due soon?'],
      };
    }
    if (q.includes('rcbc')) {
      return {
        text: `You don't have an **RCBC** account logged in Salapify yet.\n\n• **Provider**: Rizal Commercial Banking Corporation (RCBC)\n• **Highlights**: RCBC Pulz app, Hexagon Club privileges, and RCBC credit cards featuring unli 0% installment conversion.\n• You can add your RCBC savings, checking, or credit card in the Accounts screen!`,
        badge: 'RCBC',
        stats: [{ label: 'Status', value: 'Supported' }],
        actions: [{ label: 'Add RCBC Account', actionId: 'open_accounts' }],
        suggestedFollowUps: ['Which credit cards are due soon?', 'Safe to Spend today?'],
      };
    }
  }

  // 11. Total cash / Liquidity / Bank accounts
  if (
    q.includes('total cash') ||
    q.includes('liquid') ||
    q.includes('how much cash') ||
    q.includes('bank balance') ||
    q.includes('wallets') ||
    q.includes('lahat ng pera')
  ) {
    const liquidAccounts = ctx.accounts.filter((a) =>
      ['cash', 'bank', 'gcash', 'maya', 'debit'].includes(a.kind)
    );
    const totalLiquid = liquidAccounts.reduce((sum, a) => sum + a.balance, 0);

    const breakdown = liquidAccounts
      .map((a) => `• ${a.name}: ${formatPeso(a.balance)}`)
      .slice(0, 5)
      .join('\n');

    return {
      text: `You have **${formatPeso(
        totalLiquid
      )}** in total liquid funds across **${liquidAccounts.length} accounts**:\n\n${breakdown}\n\nLiquid funds are ready for daily spending, bill settlements, or emergencies.`,
      badge: 'Liquid Assets',
      stats: [
        { label: 'Liquid Cash', value: formatPeso(totalLiquid), color: '#16643F' },
        { label: 'Accounts', value: `${liquidAccounts.length} sources` },
      ],
      actions: [
        { label: 'Open Accounts List', actionId: 'open_accounts' },
        { label: 'Transfer Between Accounts', actionId: 'open_transfer' },
      ],
      suggestedFollowUps: [
        'Where is my emergency fund stored?',
        'Safe to Spend today?',
        'Upcoming bills this week',
      ],
    };
  }

  // 12. Net worth
  if (q.includes('net worth') || q.includes('total wealth') || q.includes('assets vs liabilities')) {
    const isPositive = ctx.netWorth >= 0;
    return {
      text: `Your total Net Worth is **${formatPeso(
        ctx.netWorth
      )}**.\n\n• **Total Assets**: ${formatPeso(ctx.totalAssets)}\n• **Total Liabilities**: ${formatPeso(
        ctx.totalLiabilities
      )}\n\n${
        isPositive
          ? 'You have a positive net asset base! Keep directing excess sweldo into high-yield savings (like MariBank or GoTyme) and Pag-IBIG MP2.'
          : 'Your liabilities currently exceed your assets. Pacing your debt payoffs with the Debt Avalanche or Snowball technique will build positive momentum.'
      }`,
      badge: 'Net Worth',
      stats: [
        { label: 'Net Worth', value: formatPeso(ctx.netWorth), color: isPositive ? '#16643F' : '#B03C09' },
        { label: 'Assets', value: formatPeso(ctx.totalAssets), color: '#16643F' },
        { label: 'Liabilities', value: formatPeso(ctx.totalLiabilities), color: '#B03C09' },
      ],
      actions: [
        { label: 'View Financial Reports', actionId: 'open_reports' },
        { label: 'Inspect Accounts', actionId: 'open_accounts' },
      ],
      suggestedFollowUps: [
        'How much debt do I owe?',
        'Safe to Spend today?',
        'Where is my emergency fund stored?',
      ],
    };
  }

  // 13. Philippine Tax, 13th month, TRAIN Law
  if (
    q.includes('13th month') ||
    q.includes('thirteenth month') ||
    q.includes('tax') ||
    q.includes('train law') ||
    q.includes('8%') ||
    q.includes('freelancer')
  ) {
    return {
      text: `Under the Philippine **TRAIN Law (R.A. 10963)**:\n\n• **13th-Month & Bonuses**: Tax-exempt up to **₱90,000**. Any excess beyond ₱90,000 is merged with your regular gross compensation and subject to standard graduated withholding tax.\n• **Freelancers / Self-Employed**: Can elect the flat **8% Gross Income Tax** (on gross sales exceeding ₱250,000 deduction) in lieu of graduated tax rates and 3% percentage tax, provided gross sales do not exceed ₱3,000,000.\n• Salapify includes dedicated CPA tax calculators for both 13th-month budgeting and 8% freelancer provisioning.`,
      badge: 'CPA & Tax Advisory',
      stats: [
        { label: '13th-Mo Exemption', value: '₱90,000', color: '#16643F' },
        { label: 'Freelance Rate', value: '8% Flat' },
      ],
      actions: [
        { label: 'Open 13th-Month Planner', actionId: 'open_13th_month' },
        { label: 'Open 8% Tax Calculator', actionId: 'open_tax_calc' },
      ],
      suggestedFollowUps: [
        'Safe to Spend today?',
        'Where should I save my emergency fund?',
        'Upcoming bills this week',
      ],
    };
  }

  // 14. Emergency Fund / Savings advice / MP2
  if (
    q.includes('emergency fund') ||
    q.includes('where to save') ||
    q.includes('mp2') ||
    q.includes('pag-ibig') ||
    q.includes('tonik') ||
    q.includes('maribank') ||
    q.includes('seabank') ||
    q.includes('ipon')
  ) {
    return {
      text: `**Philippine Emergency Fund Best Practice**:\n\n1. **Target**: 3 to 6 months of essential living expenses.\n2. **Where to keep it**:\n   • **1 to 2 months**: High-yield digital savings (e.g. **MariBank**, **Maya**, or **GoTyme**) earning 4% to 5% p.a. with zero InstaPay fees for instant access.\n   • **Remaining 3 to 4 months**: Government-backed instruments like **Pag-IBIG MP2** (tax-free dividends averaging 6.5% to 7% p.a.).\n\nAvoid putting emergency funds in volatile stocks or locked real estate!`,
      badge: 'Financial Coach',
      stats: [
        { label: 'Recommended Fund', value: '3-6 Months' },
        { label: 'Liquid Stash', value: 'MariBank / Maya' },
      ],
      actions: [
        { label: 'Open Savings & Goals Planner', actionId: 'open_savings_planner' },
        { label: 'Review Accounts', actionId: 'open_accounts' },
      ],
      suggestedFollowUps: [
        'What is my net worth?',
        'Safe to Spend today?',
        'How much total cash do I have?',
      ],
    };
  }

  // 15. Philippine Business Startup & App Store Launchpad
  if (
    q.includes('start app business') ||
    q.includes('start an app business') ||
    q.includes('start a business') ||
    q.includes('start business') ||
    q.includes('launch app') ||
    q.includes('publish app') ||
    q.includes('app store') ||
    q.includes('google play') ||
    q.includes('d-u-n-s') ||
    q.includes('duns') ||
    q.includes('saas') ||
    q.includes('merchant of record')
  ) {
    const isAppSpecific =
      q.includes('app') ||
      q.includes('store') ||
      q.includes('play') ||
      q.includes('saas') ||
      q.includes('duns') ||
      q.includes('d-u-n-s');

    if (isAppSpecific) {
      return {
        text: `To start and launch an **App / SaaS Business** in the Philippines:\n\n1. **Corporate Entity**: Register a One Person Corporation (OPC) or Regular Corporation with the SEC via eSPARC to secure an official corporate name.\n2. **Free Apple D-U-N-S Number**: With your SEC Certificate of Incorporation and domain website, request a free 9-digit D-U-N-S number via the Apple Developer lookup portal.\n3. **Developer Accounts**: Enroll in Apple Developer ($99/yr) and Google Play ($25 one-time) as an Organization to display your company name and bypass personal testing friction.\n4. **Monetization & Taxes**: In-app digital purchases must use Apple/Google IAP. For global web checkouts, use a Merchant of Record (Paddle / Lemon Squeezy). Exported software services qualify for **0% Zero-Rated VAT** under Tax Code Section 108(B)(2).\n\nExplore our complete **SaaS & App Store Launchpad** inside the Academy!`,
        badge: 'App Startup Guide',
        stats: [
          { label: 'D-U-N-S Cost', value: 'Free via SEC', color: '#16643F' },
          { label: 'Export VAT', value: '0% Zero-Rated', color: '#16643F' },
          { label: 'Academy Modules', value: '32 Courses' },
        ],
        actions: [
          {
            label: 'Open SaaS & App Store Launchpad',
            actionId: 'open_startup_guide_saas',
            payload: { subTab: 'stores' },
          },
          {
            label: 'Open Philippine Startup Guide',
            actionId: 'open_startup_guide',
            payload: { tab: 'roadmap' },
          },
          { label: 'View Academy Courses', actionId: 'open_academy' },
        ],
        suggestedFollowUps: [
          'How do I get a free D-U-N-S number in PH?',
          'What is 0% Zero-Rated VAT for software exports?',
          'Which entity is best: Sole Prop or OPC?',
        ],
      };
    }

    return {
      text: `To start and register a **business in the Philippines**, follow the official 5-stage roadmap:\n\n1. **Entity Name & Structure**: Register trade name via DTI BNRS (Sole Prop) or SEC eSPARC (Corporation/OPC).\n2. **Local Government Licenses (LGU)**: Barangay Business Clearance, Locational Clearance, Fire Safety (FSIC), and Mayor's Business Permit.\n3. **Tax & Invoicing (BIR)**: Register at your RDO for BIR Certificate of Registration (Form 1901/1903) and compliant Sales Invoices under the Ease of Paying Taxes (EOPT) Act.\n4. **Mandatory Employer Enrollment**: SSS, PhilHealth, and Pag-IBIG.\n\nSalapify includes an interactive Entity Matcher quiz and full compliance checklists inside the Academy!`,
      badge: 'PH Startup Masterclass',
      stats: [
        { label: 'Sole Prop Reg', value: 'DTI BNRS' },
        { label: 'Corp / OPC', value: 'SEC eSPARC' },
        { label: 'Tax Law', value: 'EOPT Act 2024' },
      ],
      actions: [
        {
          label: 'Open PH Startup Guide',
          actionId: 'open_startup_guide',
          payload: { tab: 'roadmap' },
        },
        {
          label: 'Interactive Entity Matcher Quiz',
          actionId: 'open_startup_guide',
          payload: { tab: 'entities' },
        },
        { label: 'View Academy Courses', actionId: 'open_academy' },
      ],
      suggestedFollowUps: [
        'How to start an app business on iOS and Android?',
        'What are the 32 Academy courses?',
        'How does the 8% freelancer tax work?',
      ],
    };
  }

  // 16. Academy Courses Directory
  if (
    (q.includes('academy') || q.includes('course') || q.includes('lesson')) &&
    !q.includes('safe to spend')
  ) {
    return {
      text: `**Salapify Academy** features 32 comprehensive financial literacy courses across 6 tracks:\n\n1. **Core Foundations**: Money Mindset, Budgeting Systems, Cash Flow, Net Worth Architecture, and Emergency Funds.\n2. **Credit & Debt**: Debt Elimination (Avalanche vs Snowball), Credit Card Mastery, and Buy Now Pay Later (BNPL) Installments.\n3. **Wealth & Investments**: Pag-IBIG MP2, Digital Bank High-Yield Savings, Stocks & UITFs, and Risk-Adjusted Returns.\n4. **Philippine Tax & Scams**: TRAIN Law Withholding, BIR 8% Freelancer Tax, and Scam Defense Protocol.\n5. **Filipino Life Realities**: Couples & Money, Family Tulong & Boundaries, and OFW Remittances.\n6. **Business & Startups**: Freelance Economics, Digital Products, Philippine Business Registration, and App Store Launchpad!`,
      badge: 'Salapify Academy',
      stats: [
        { label: 'Total Modules', value: '32 Courses', color: '#16643F' },
        { label: 'Startup Guide', value: 'DTI / SEC / BIR' },
      ],
      actions: [
        { label: 'Browse Academy Courses', actionId: 'open_academy' },
        { label: 'Open Startup Guide', actionId: 'open_startup_guide' },
        { label: 'App Store Launchpad', actionId: 'open_startup_guide_saas' },
      ],
      suggestedFollowUps: [
        'How to start an app business in PH?',
        'Where should I save my emergency fund?',
        'How does 13th-month tax exemption work?',
      ],
    };
  }

  // 17. Check App Features Knowledge Repository
  const appFeature = matchAppFeature(q);
  if (appFeature) {
    const actions: PanMessageAction[] = [];
    if (appFeature.actionId) {
      actions.push({
        label: `Open ${appFeature.name}`,
        actionId: appFeature.actionId,
        payload: appFeature.actionPayload,
      });
    }

    const detailsList = appFeature.details?.length
      ? '\n\n' + appFeature.details.map((d) => `• ${d}`).join('\n')
      : '';

    return {
      text: `**${appFeature.name}**\n\n${appFeature.description}${detailsList}\n\n• **Where to find it**: ${appFeature.howToAccess}`,
      badge: 'Feature Guide',
      stats: [
        { label: 'Category', value: appFeature.category.toUpperCase() },
        { label: 'Offline Ready', value: 'Yes', color: '#16643F' },
      ],
      actions,
      suggestedFollowUps: [
        'What other features does Salapify have?',
        'Safe to Spend today?',
        'How does Salapify protect my privacy?',
      ],
    };
  }

  // 18. Default intelligent fallback with state summary
  return {
    text: `I reviewed your live financial ledger:\n\n• **Safe to Spend**: ${formatPeso(
      ctx.safeToSpend
    )} (${formatPeso(ctx.safeToSpendPerDay)}/day until payday on ${
      ctx.payday.nextPayday.split(',')[0]
    })\n• **Total Assets**: ${formatPeso(ctx.totalAssets)} across ${ctx.accounts.length} accounts\n• **Total Liabilities**: ${formatPeso(
      ctx.totalLiabilities
    )}\n• **Net Worth**: ${formatPeso(ctx.netWorth)}\n\nYou can ask me specific questions like: *"Can I afford ₱2,500?"*, *"Audit my finances"*, *"Who owes me money?"*, or *"Which bills are due soon?"*`,
    badge: 'Pan Copilot',
    stats: [
      { label: 'Safe Balance', value: formatPeso(ctx.safeToSpend), color: '#16643F' },
      { label: 'Net Worth', value: formatPeso(ctx.netWorth) },
    ],
    actions: [
      { label: 'Safe to Spend', actionId: 'open_safe_to_spend' },
      { label: 'Activity Ledger', actionId: 'open_ledger' },
      { label: 'Log Expense', actionId: 'open_log_expense' },
    ],
    suggestedFollowUps: [
      'Can I afford ₱1,500?',
      'Audit my finances',
      'Safe to Spend today?',
      'Which credit cards are due soon?',
    ],
  };
}
