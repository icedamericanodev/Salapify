// Generates the Plan vectors by running the PROTOTYPE'S own arithmetic,
// copied verbatim out of src/components/PlanScreen.tsx, over app/'s fixture.
//
//   flutter test test/tool/dump_fixture_test.dart
//   bun app/tool/gen_plan_vectors.ts <fixture.json> <budgets.json>
//
// It prints BOTH readings of every budget, on purpose:
//
//   prototype  all time, excluded and duplicate entries counted
//   approved   this month only, excluded and duplicate entries ignored
//
// The second is what app/ ships, by founder decision on 2026-09-18. Printing
// the first beside it is what makes the divergence a measured difference
// rather than an assertion: the gap on Bills & Utilities is exactly the
// duplicate Meralco charge, and this file is where that can be seen.

import { readFileSync } from 'fs';

const fixturePath = process.argv[2];
const budgetsPath = process.argv[3];
if (!fixturePath || !budgetsPath) {
  console.error('usage: bun gen_plan_vectors.ts <fixture.json> <budgets.json>');
  process.exit(1);
}

const FIXTURE = JSON.parse(readFileSync(fixturePath, 'utf8'));
const BUDGETS = JSON.parse(readFileSync(budgetsPath, 'utf8'));
const TXS = FIXTURE.transactions;

const NOW = new Date('2026-09-18T00:00:00.000Z');

// --- the prototype's own budgetStats, verbatim apart from the types ---------
function prototypeBudgets() {
  return BUDGETS.budgets.map((b: any) => {
    const spent = TXS.filter(
      (t: any) =>
        t.type === 'expense' &&
        t.category.toLowerCase() === b.category.toLowerCase()
    ).reduce((sum: number, t: any) => sum + t.amount, 0);

    const remaining = b.limit - spent;
    const percent = Math.min(100, Math.round((spent / b.limit) * 100));
    const isOver = remaining < 0;
    const isNear = percent >= 80 && !isOver;
    return { category: b.category, spent, remaining, percent, isOver, isNear };
  });
}

// --- the same arithmetic, with the two approved changes --------------------
function approvedBudgets() {
  const countable = TXS.filter(
    (t: any) =>
      t.type === 'expense' &&
      t.status !== 'excluded' &&
      t.status !== 'duplicate' &&
      (() => {
        const d = new Date(t.date);
        if (isNaN(d.getTime())) return true;
        return (
          d.getUTCFullYear() === NOW.getUTCFullYear() &&
          d.getUTCMonth() === NOW.getUTCMonth()
        );
      })()
  );

  return BUDGETS.budgets.map((b: any) => {
    const mine = countable.filter(
      (t: any) => t.category.toLowerCase() === b.category.toLowerCase()
    );
    const spent = mine.reduce((sum: number, t: any) => sum + t.amount, 0);
    const remaining = b.limit - spent;
    const percent =
      b.limit <= 0
        ? 0
        : Math.min(100, Math.max(0, Math.round((spent / b.limit) * 100)));
    const isOver = remaining < 0;
    const isNear = percent >= 80 && !isOver;
    return {
      category: b.category,
      limit: b.limit,
      spent,
      remaining,
      percent,
      isOver,
      isNear,
      entryCount: mine.length,
    };
  });
}

function goals() {
  return BUDGETS.goals.map((g: any) => {
    const remaining = g.targetAmount - g.currentAmount;
    const percent =
      g.targetAmount <= 0
        ? 0
        : Math.min(
            100,
            Math.max(0, Math.round((g.currentAmount / g.targetAmount) * 100))
          );
    const months =
      remaining > 0 && g.monthlyTarget > 0
        ? Math.ceil(remaining / g.monthlyTarget)
        : null;
    return {
      id: g.id,
      percent,
      remaining: remaining < 0 ? 0 : remaining,
      monthsAtCurrentRate: months,
    };
  });
}

function upcoming() {
  const unpaid = BUDGETS.upcoming.filter((u: any) => !u.isPaid);
  const isIncome = (u: any) => u.isIncome || u.type === 'payday';
  const out = unpaid.filter((u: any) => !isIncome(u));
  return {
    // What the prototype's headline actually prints: every row, income and
    // all, under the label "Total Scheduled Bills".
    prototypeHeadline: BUDGETS.upcoming.reduce(
      (s: number, u: any) => s + u.amount,
      0
    ),
    totalOut: out.reduce((s: number, u: any) => s + u.amount, 0),
    totalIn: unpaid
      .filter(isIncome)
      .reduce((s: number, u: any) => s + u.amount, 0),
    billCount: out.length,
  };
}

const proto = prototypeBudgets();
const approved = approvedBudgets();

const totalLimit = approved.reduce((s: number, b: any) => s + b.limit, 0);
const totalSpent = approved.reduce((s: number, b: any) => s + b.spent, 0);

console.log(
  JSON.stringify(
    {
      now: NOW.toISOString(),
      budgetsPrototype: proto,
      budgetsApproved: approved,
      budgetTotals: {
        totalLimit,
        totalSpent,
        leftToSpend: Math.max(0, totalLimit - totalSpent),
        overCount: approved.filter((b: any) => b.isOver).length,
        nearCount: approved.filter((b: any) => b.isNear).length,
      },
      goals: goals(),
      upcoming: upcoming(),
    },
    null,
    2
  )
);
