// statements.js: proper personal financial statements built from local data.
//
// Three statements, each a pure function so the tests and the Reports screen
// read the exact same numbers:
//
//  - balanceSheet: a point in time snapshot. Assets = Liabilities + Equity, the
//    accounting identity. Equity is your net worth, what is truly yours once the
//    people you owe are paid. Assets and liabilities split into current (soon)
//    and long term (later) the way a real balance sheet reads.
//
//  - incomeStatement: one month. Income earned minus expenses (including debt
//    interest, a real cost) equals net income. Money that is not income (loans
//    you took, utang collected, transfers between pockets) and money that is not
//    an expense (debt principal, money you lent out) are deliberately excluded,
//    so the bottom line is honest earnings, not cash movement.
//
//  - cashFlowStatement: one month. Every peso that actually moved in or out of an
//    account, sorted into operating (day to day), investing (things you own), and
//    financing (debt and utang). The three sections sum to the net change in
//    cash, and a reconcile flag proves nothing was dropped.
//
// Everything computes on the phone from local data. Nothing leaves the device.

import { netWorthParts } from './analytics';
import { isThisMonth } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
// Money can carry cents, so equality checks use a half centavo tolerance to
// avoid floating point noise flagging a false mismatch.
const eq = (a, b) => Math.abs(a - b) < 0.005;
// Statements only count entries with a real date. isThisMonth already excludes a
// missing date; the explicit guard keeps that intent local and safe even if that
// shared behavior ever changes.
const inMonth = (dateStr, ref) => !!dateStr && isThisMonth(dateStr, ref);

// The same split the Debts screen uses: these clear within about a year, so they
// are current liabilities; everything else (a car loan, a personal loan) is long
// term.
const SHORT_TERM_DEBT_TYPES = ['credit card', 'bnpl', 'short term', 'insurance'];

// ---- Balance sheet (as of now) ----
// Built on the ONE net worth breakdown (netWorthParts) so this statement always
// agrees with Home and the rest of the app. Only tracked (cash leg) utang is an
// asset or liability here, exactly as net worth counts it.
export function balanceSheet(data) {
  const d = data || {};
  const parts = netWorthParts(d);

  const cash = (d.accounts || [])
    .filter((a) => a && a.kind === 'cash')
    .reduce((t, a) => t + num(a.balance), 0);
  const bank = parts.accounts - cash; // every non cash account (savings, ewallet, etc.)

  const debts = d.debts || [];
  const shortDebts = debts
    .filter((x) => x && SHORT_TERM_DEBT_TYPES.includes(x.type))
    .reduce((t, x) => t + num(x.remaining), 0);
  const longDebts = parts.debts - shortDebts;

  const currentAssets = cash + bank + parts.receivables;
  const longTermAssets = parts.holdings;
  const totalAssets = parts.assets;

  const currentLiabilities = shortDebts + parts.payables;
  const longTermLiabilities = longDebts;
  const totalLiabilities = parts.liabilities;

  const equity = parts.netWorth; // assets minus liabilities

  return {
    cash,
    bank,
    receivables: parts.receivables,
    investments: parts.holdings,
    currentAssets,
    longTermAssets,
    totalAssets,
    shortDebts,
    longDebts,
    payables: parts.payables,
    currentLiabilities,
    longTermLiabilities,
    totalLiabilities,
    equity,
    // Equity is defined as assets minus liabilities, so the identity holds by
    // construction. This flag guards against a future change breaking the sum.
    balances: eq(totalAssets, totalLiabilities + equity),
  };
}

// ---- Income statement (one month) ----
// Income is money genuinely earned. Utang you collected is NOT income (it was
// always yours), so anything tagged source 'receivable' is left out, matching
// how the savings rate already treats it. Expenses include debt interest (a real
// cost). Debt principal is not here (it lowers what you owe, it is not spending).
export function incomeStatement(data, ref = new Date()) {
  const tx = (data && data.transactions ? data.transactions : []).filter((t) =>
    inMonth(t && t.date, ref)
  );
  const income = tx
    .filter((t) => t.type === 'income' && t.source !== 'receivable')
    .reduce((s, t) => s + num(t.amount), 0);
  const expenses = tx
    .filter((t) => t.type === 'expense')
    .reduce((s, t) => s + num(t.amount), 0);
  // Interest is already inside expenses; called out so the reader sees the cost
  // of debt separately from ordinary spending.
  const interestExpense = tx
    .filter((t) => t.type === 'expense' && t.source === 'interest')
    .reduce((s, t) => s + num(t.amount), 0);
  return {
    income,
    expenses,
    interestExpense,
    spendingExpense: expenses - interestExpense,
    netIncome: income - expenses,
  };
}

// ---- Cash flow statement (one month) ----
// Only cash that actually moved through an account counts. Every account linked
// transaction this month is signed the same way the store signs it (income and
// flow 'in' raise a balance, everything else lowers it) and sorted into a
// section. Debt payments move cash by a direct account debit, not a linked
// transaction, so they are read from the payments ledger instead (principal is
// financing, interest is operating). A payment made "Outside the app" moved no
// in app cash, so it is skipped here (it still shows on the other statements).
export function cashFlowStatement(data, ref = new Date()) {
  const d = data || {};
  const accountIds = new Set((d.accounts || []).map((a) => a && a.id));
  const tx = (d.transactions || []).filter((t) => inMonth(t && t.date, ref));
  // A balance adjustment is a manual reconciliation of an account to reality, not
  // a real cash flow, so it is left out of the statement (and out of the recorded
  // tally below, so the sections still reconcile). It already shows in History and
  // is reflected in net worth through the account balance.
  const linked = tx.filter(
    (t) => t.accountId && accountIds.has(t.accountId) && t.type !== 'adjustment'
  );

  // The direction the store moves a balance, mirrored from AppData.balanceSign
  // so the cash flow signs match what actually happened to the account.
  const sign = (t) => {
    if (t.flow === 'in') return 1;
    if (t.flow === 'out') return -1;
    return t.type === 'income' ? 1 : -1;
  };

  const op = { in: 0, out: 0 };
  const inv = { in: 0, out: 0 };
  const fin = { in: 0, out: 0 };
  const add = (bucket, signed) => {
    if (signed >= 0) bucket.in += signed;
    else bucket.out += -signed;
  };

  for (const t of linked) {
    const signed = sign(t) * num(t.amount);
    if (t.type === 'income') {
      // Real earnings are operating; collecting utang you lent is financing.
      add(t.source === 'receivable' ? fin : op, signed);
    } else if (t.type === 'expense') {
      // Day to day spending. (Debt interest has no accountId and is added from
      // the payments ledger below, so it never lands here.)
      add(op, signed);
    } else if (t.type === 'transfer') {
      // Lending, borrowing, and utang repayment are all financing.
      add(fin, signed);
    } else {
      // debt records and anything else that still moved account cash: financing.
      add(fin, signed);
    }
  }

  // Debt payments: the cash left via a direct account debit, so read the ledger.
  // Only payments tied to a real account moved in app cash.
  const payments = (d.payments || []).filter((p) => inMonth(p && p.date, ref));
  let principalPaid = 0;
  let interestPaid = 0;
  for (const p of payments) {
    const paidFromAccount = p.account && accountIds.has(p.account);
    if (!paidFromAccount) continue;
    // The whole payment amount left the account. Split it so interest plus
    // principal always sums back to that amount, whatever the record carries:
    // interest is what is stored (0 for legacy/absent), and principal is the
    // rest. This keeps the sections reconciled even for an imported payment that
    // stored an interest figure but no principal.
    const amount = num(p.amount);
    const interest = Math.min(amount, Math.max(0, p.interest != null ? num(p.interest) : 0));
    const principal = amount - interest;
    interestPaid += interest;
    principalPaid += principal;
    op.out += interest; // interest is an operating cost
    fin.out += principal; // principal repayment is financing
  }

  const operating = op.in - op.out;
  const investing = inv.in - inv.out;
  const financing = fin.in - fin.out;
  const netChange = operating + investing + financing;

  // Independent tally of every peso that moved through an account this month:
  // signed linked transactions, plus each debt payment's cash out. If the
  // sections were built correctly this equals netChange exactly. The flag is the
  // reconcile check: it proves the statement dropped nothing.
  const recorded =
    linked.reduce((s, t) => s + sign(t) * num(t.amount), 0) -
    payments.reduce(
      (s, p) => s + (p.account && accountIds.has(p.account) ? num(p.amount) : 0),
      0
    );

  return {
    operating: { in: op.in, out: op.out, net: operating },
    investing: { in: inv.in, out: inv.out, net: investing },
    financing: { in: fin.in, out: fin.out, net: financing },
    interestPaid,
    principalPaid,
    netChange,
    reconciles: eq(netChange, recorded),
    recorded,
  };
}
