// Generates the golden vectors for the Reports engine by running the
// PROTOTYPE'S OWN arithmetic, copied verbatim out of
// src/components/ReportsScreen.tsx, against the prototype's own fixture.
//
// Run from the repository root:
//   bun app/tool/gen_report_vectors.ts
//
// Whatever this prints is the expectation. Nothing here is derived by hand,
// which is the entire point: a number somebody reasoned their way to is a
// number that agrees with the reasoning, not with the app.
//
// The clock is PINNED, because every period filter and the run rate read the
// current date. An unpinned generator produces vectors that pass on the day
// they were made and fail the next morning.

// The DATA is app/'s own fixture, not the prototype's, and that matters.
// The two have diverged: app/ carries a pending card charge, an excluded
// duplicate and a transfer that the prototype's fixture never had, added so
// the Activity screen could be reviewed rather than merely rendered.
//
// Generating vectors from the prototype's data and comparing them against
// Dart computed over ours would compare two unrelated numbers and read the
// disagreement as a porting bug, or worse, read an accidental agreement as
// proof. So the ALGORITHM below is the prototype's, copied verbatim, and the
// INPUT is ours, dumped by test/tool/dump_fixture_test.dart.
//
//   flutter test test/tool/dump_fixture_test.dart
//   bun app/tool/gen_report_vectors.ts <path-to-fixture.json>
import { readFileSync } from 'fs';

const fixturePath = process.argv[2];
if (!fixturePath) {
  console.error('usage: bun gen_report_vectors.ts <fixture.json>');
  process.exit(1);
}
const FIXTURE = JSON.parse(readFileSync(fixturePath, 'utf8'));
const INITIAL_ACCOUNTS = FIXTURE.accounts;
const INITIAL_TRANSACTIONS = FIXTURE.transactions;

const NOW = new Date('2026-09-18T00:00:00.000Z');

type Period =
  | 'daily'
  | 'weekly'
  | 'monthly'
  | 'quarterly'
  | 'semi_annually'
  | 'annually';

const convertToPhp = (amount: number) => amount;

function filterByProfile(txs: any[], profile: string) {
  if (profile === 'all') return txs;
  return txs.filter((t) => (t.profile || 'personal') === profile);
}

function validLedger(txs: any[]) {
  return txs.filter((t) => t.status !== 'excluded' && t.status !== 'duplicate');
}

function filterByPeriod(txs: any[], period: Period) {
  const now = NOW;
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();

  return txs.filter((tx) => {
    const txDate = new Date(tx.date);
    if (isNaN(txDate.getTime())) return true;

    if (period === 'daily') {
      const todayStr = now.toISOString().split('T')[0];
      return tx.date === todayStr;
    }
    if (period === 'weekly') {
      const oneWeekAgo = new Date(now.getTime());
      oneWeekAgo.setDate(now.getDate() - 7);
      return txDate >= oneWeekAgo && txDate <= now;
    }
    if (period === 'monthly') {
      return txDate.getFullYear() === currentYear && txDate.getMonth() === currentMonth;
    }
    if (period === 'quarterly') {
      const currentQuarter = Math.floor(currentMonth / 3);
      const txQuarter = Math.floor(txDate.getMonth() / 3);
      return txDate.getFullYear() === currentYear && txQuarter === currentQuarter;
    }
    if (period === 'semi_annually') {
      const isCurrentFirstHalf = currentMonth < 6;
      const isTxFirstHalf = txDate.getMonth() < 6;
      return txDate.getFullYear() === currentYear && isCurrentFirstHalf === isTxFirstHalf;
    }
    if (period === 'annually') {
      return txDate.getFullYear() === currentYear;
    }
    return true;
  });
}

function position(profile: string) {
  const accounts =
    profile === 'all'
      ? INITIAL_ACCOUNTS
      : INITIAL_ACCOUNTS.filter((a: any) => !a.profile || a.profile === profile);

  const assetKinds = ['cash', 'bank', 'gcash', 'maya', 'debit', 'investment', 'receivable'];
  const liabilityKinds = ['credit', 'loan', 'mortgage'];

  const assets = accounts.filter((a: any) => assetKinds.includes(a.kind));
  const liabilities = accounts.filter((a: any) => liabilityKinds.includes(a.kind));

  const sum = (list: any[]) =>
    list.reduce((s, a) => s + convertToPhp(a.balance), 0);

  const totalAssets = sum(assets);
  const totalLiabilities = sum(liabilities);

  return {
    totalAssets,
    totalLiabilities,
    netWorth: totalAssets - totalLiabilities,
    cashEquivalents: sum(
      assets.filter((a: any) => ['cash', 'bank', 'gcash', 'maya', 'debit'].includes(a.kind))
    ),
    investments: sum(assets.filter((a: any) => a.kind === 'investment')),
    receivables: sum(assets.filter((a: any) => a.kind === 'receivable')),
    creditCards: sum(liabilities.filter((a: any) => a.kind === 'credit')),
    loans: sum(liabilities.filter((a: any) => a.kind === 'loan' || a.kind === 'mortgage')),
    assetCount: assets.length,
    liabilityCount: liabilities.length,
  };
}

function reports(profile: string, period: Period) {
  const scoped = filterByPeriod(
    validLedger(filterByProfile(INITIAL_TRANSACTIONS, profile)),
    period
  );

  const sum = (list: any[]) => list.reduce((s, t) => s + t.amount, 0);
  const has = (v: string | undefined, n: string) =>
    !!v && v.toLowerCase().includes(n);

  const totalIncome = sum(scoped.filter((t) => t.type === 'income'));
  const totalExpenses = sum(scoped.filter((t) => t.type === 'expense'));
  const netSurplus = totalIncome - totalExpenses;

  const businessRevenue = sum(
    scoped.filter((t) => t.type === 'income' && t.profile === 'business')
  );
  const businessExpenses = sum(
    scoped.filter((t) => t.type === 'expense' && t.profile === 'business')
  );

  const debtServicing = sum(
    scoped.filter(
      (t) =>
        t.type === 'expense' &&
        (has(t.category, 'debt') || has(t.category, 'loan') || has(t.subcategory, 'loan'))
    )
  );

  const daysInMonth = new Date(NOW.getFullYear(), NOW.getMonth() + 1, 0).getDate();
  const currentDay = Math.max(1, NOW.getDate());
  const projectedIncome = (totalIncome / currentDay) * daysInMonth;
  const projectedExpenses = (totalExpenses / currentDay) * daysInMonth;

  const operatingInflows = sum(
    scoped.filter(
      (t) =>
        t.type === 'income' &&
        !has(t.category, 'investment') &&
        !has(t.category, 'dividend')
    )
  );
  const operatingOutflows = sum(
    scoped.filter(
      (t) =>
        t.type === 'expense' &&
        !has(t.category, 'debt') &&
        !has(t.category, 'investment')
    )
  );
  const investingInflows = sum(
    scoped.filter(
      (t) =>
        t.type === 'income' &&
        (has(t.category, 'investment') ||
          has(t.category, 'dividend') ||
          has(t.category, 'interest'))
    )
  );
  const investingOutflows = sum(
    scoped.filter(
      (t) =>
        t.type === 'expense' &&
        (has(t.category, 'investment') || has(t.subcategory, 'mp2'))
    )
  );

  const financingInflows = 0;
  const financingOutflows = debtServicing;

  const netOperating = operatingInflows - operatingOutflows;
  const netInvesting = investingInflows - investingOutflows;
  const netFinancing = financingInflows - financingOutflows;

  const transfers = scoped.filter((t) => t.type === 'transfer');

  const breakdown = (type: string) => {
    const txs = scoped.filter((t) => t.type === type);
    const grand = sum(txs);
    const map: Record<string, any> = {};
    txs.forEach((t) => {
      const cat = t.category || (type === 'income' ? 'Income' : 'Uncategorized');
      const sub = t.subcategory || (type === 'income' ? 'Regular' : 'General');
      if (!map[cat]) map[cat] = { category: cat, total: 0, count: 0, subs: {} };
      map[cat].total += t.amount;
      map[cat].count += 1;
      if (!map[cat].subs[sub]) map[cat].subs[sub] = { total: 0, count: 0 };
      map[cat].subs[sub].total += t.amount;
      map[cat].subs[sub].count += 1;
    });
    return Object.values(map)
      .map((item: any) => ({
        category: item.category,
        total: item.total,
        count: item.count,
        percentage: grand > 0 ? (item.total / grand) * 100 : 0,
        subs: Object.entries(item.subs).map(([name, d]: [string, any]) => ({
          name,
          total: d.total,
          count: d.count,
          pctOfCategory: item.total > 0 ? (d.total / item.total) * 100 : 0,
        })),
      }))
      .sort((a, b) => b.total - a.total);
  };

  return {
    scopedCount: scoped.length,
    performance: {
      totalIncome,
      totalExpenses,
      netSurplus,
      businessRevenue,
      businessExpenses,
      businessNetProfit: businessRevenue - businessExpenses,
      savingsRate: totalIncome > 0 ? (netSurplus / totalIncome) * 100 : 0,
      debtServicingExpenses: debtServicing,
      debtServiceRatio: totalIncome > 0 ? (debtServicing / totalIncome) * 100 : 0,
      projectedIncome,
      projectedExpenses,
      projectedSurplus: projectedIncome - projectedExpenses,
    },
    cashFlow: {
      operatingInflows,
      operatingOutflows,
      netOperating,
      investingInflows,
      investingOutflows,
      netInvesting,
      financingInflows,
      financingOutflows,
      netFinancing,
      transfersCount: transfers.length,
      transfersVolume: sum(transfers),
      netCashChange: netOperating + netInvesting + netFinancing,
    },
    expenseByCategory: breakdown('expense'),
    incomeByCategory: breakdown('income'),
  };
}

const out: any = { now: NOW.toISOString(), position: {}, reports: {} };

for (const p of ['all', 'personal', 'household', 'business', 'side_hustle']) {
  out.position[p] = position(p);
}

const periods: Period[] = [
  'daily',
  'weekly',
  'monthly',
  'quarterly',
  'semi_annually',
  'annually',
];
for (const period of periods) {
  out.reports[`all:${period}`] = reports('all', period);
}
out.reports['personal:monthly'] = reports('personal', 'monthly');
out.reports['business:annually'] = reports('business', 'annually');

console.log(JSON.stringify(out, null, 2));
