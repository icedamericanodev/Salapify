// Pan resolvers: intent id -> FACTS. This is the ONLY layer allowed to call
// the money engine. Every number Pan ever says originates here, straight from
// analytics.js / recap.js / soa.js, never invented. FACTS are plain numbers
// and small primitives tagged with a `kind`; the responder turns them into
// words and can physically not change them (it has no access to `data`).

import {
  safeToSpend,
  upcomingCommitments,
  utangAging,
  goalPace,
  categoryVsAverage,
  savingsRate,
  forecastMonthEnd,
  debtFreeProjection,
  healthScore,
} from '../analytics';
import { monthRecap } from '../recap';
import { nextPayday, daysUntilPayday, scheduleLabel } from '../format';
import { bankDueDate, cardForecast, upcomingDues } from '../soa';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const LIQUID = ['cash', 'ewallet', 'checking'];

export const RESOLVERS = {
  safeToSpend(data, ctx) {
    const s = safeToSpend(data, ctx.now);
    return { kind: 'safe_to_spend', ...s };
  },

  canAfford(data, ctx) {
    const s = safeToSpend(data, ctx.now);
    const amount = num(ctx.amount);
    return {
      kind: 'can_afford',
      amount,
      hasAmount: amount > 0,
      available: s.available,
      afterBuy: s.available - amount,
      perDayAfter: s.daysLeft > 0 ? (s.available - amount) / s.daysLeft : 0,
      daysLeft: s.daysLeft,
      payday: s.payday,
    };
  },

  utang(data, ctx) {
    const a = utangAging(data, ctx.now);
    const w = a.worst;
    // The copy-paste reminder for the person to follow up first. Amounts are
    // formatted by the responder; here we pass the raw pieces.
    return {
      kind: 'utang',
      total: a.totalOutstanding,
      count: a.people.length,
      overdueCount: a.overdueCount,
      worst: w ? { name: w.name, outstanding: w.outstanding, daysOverdue: w.daysOverdue } : null,
      top: a.people.slice(0, 3).map((p) => ({ name: p.name, outstanding: p.outstanding, daysOverdue: p.daysOverdue })),
    };
  },

  upcomingBills(data, ctx) {
    const c = upcomingCommitments(data, ctx.now);
    return {
      kind: 'upcoming_bills',
      total: c.total,
      daysLeft: c.daysLeft,
      payday: c.payday,
      bills: (c.bills || []).slice(0, 6).map((b) => ({ name: b.name, kind: b.kind, date: b.date, amount: b.amount })),
    };
  },

  debtDue(data, ctx) {
    const debts = (data.debts || []).filter((d) => d && num(d.remaining) > 0);
    const rows = debts
      .map((d) => {
        const bd = bankDueDate(d, ctx.now);
        const fc = cardForecast(d, data.payments || [], ctx.now);
        return {
          name: d.name || 'Debt',
          remaining: num(d.remaining),
          due: bd ? bd.date : null,
          moved: !!(bd && bd.moved),
          minDue: fc ? fc.minDue : Math.min(num(d.minPayment), num(d.remaining)) || num(d.remaining),
          lateInterest: fc ? fc.lateInterest : null,
        };
      })
      .filter((r) => r.due)
      .sort((a, b) => new Date(a.due) - new Date(b.due));
    return { kind: 'debt_due', count: debts.length, soonest: rows[0] || null, rows: rows.slice(0, 4) };
  },

  debtFree(data, ctx) {
    const debts = (data.debts || []).filter((d) => d && num(d.remaining) > 0);
    const base = debtFreeProjection(debts, 'avalanche', 0, ctx.now);
    const extra = num(ctx.amount);
    const withExtra = extra > 0 ? debtFreeProjection(debts, 'avalanche', extra, ctx.now) : null;
    return {
      kind: 'debt_free',
      hasDebt: debts.length > 0,
      base: { months: base.months, totalInterest: base.totalInterest, date: base.date },
      extra,
      withExtra: withExtra ? { months: withExtra.months, totalInterest: withExtra.totalInterest, date: withExtra.date } : null,
    };
  },

  recap(data, ctx) {
    return { kind: 'recap', recap: monthRecap(data, ctx.now) };
  },

  topSpending(data, ctx) {
    const vs = categoryVsAverage(data.transactions || [], ctx.now);
    const hot = vs.find((v) => v.expected > 0 && v.now > v.expected * 1.2) || null;
    return { kind: 'top_spending', rows: vs.slice(0, 3), hot };
  },

  forecast(data, ctx) {
    const f = forecastMonthEnd(data.transactions || [], ctx.now);
    const limit = num(data.settings && data.settings.monthlyLimit);
    return { kind: 'forecast', projected: f.projected, spent: f.spent, limit, over: limit > 0 && f.projected > limit };
  },

  savingsRate(data, ctx) {
    const rate = savingsRate(data.transactions || [], data.payments || [], ctx.now);
    return { kind: 'savings_rate', rate };
  },

  goalPace(data, ctx) {
    const goals = (data.goals || []).filter((g) => g && num(g.target) > 0);
    if (goals.length === 0) return { kind: 'goal_pace', none: true };
    // If the message named a goal, use it; else the one furthest behind.
    const named = ctx.raw
      ? goals.find((g) => String(g.name || '').toLowerCase() && ctx.raw.toLowerCase().includes(String(g.name).toLowerCase()))
      : null;
    const paces = goals.map((g) => ({ name: g.name || 'Goal', pace: goalPace(g, ctx.now) }));
    let focus = named ? paces.find((p) => p.name === named.name) : null;
    if (!focus) {
      focus =
        paces.find((p) => p.pace.status === 'behind') ||
        paces.slice().sort((a, b) => a.pace.pct - b.pace.pct)[0];
    }
    return { kind: 'goal_pace', focus, count: goals.length };
  },

  health(data, ctx) {
    const h = healthScore(data, ctx.now);
    // Name the weakest part so Pan can coach the fastest win.
    const parts = [
      ['savings rate', h.parts.savings, 35],
      ['budget discipline', h.parts.budget, 25],
      ['debt load', h.parts.debt, 25],
      ['logging habit', h.parts.logging, 15],
    ];
    const weakest = parts.slice().sort((a, b) => a[1] / a[2] - b[1] / b[2])[0];
    const strongest = parts.slice().sort((a, b) => b[1] / b[2] - a[1] / a[2])[0];
    return { kind: 'health', total: h.total, weakest: weakest[0], strongest: strongest[0] };
  },

  balances(data, ctx) {
    const accts = data.accounts || [];
    const spendable = accts.reduce((t, a) => (a && LIQUID.includes(a.kind) ? t + num(a.balance) : t), 0);
    const savings = accts.reduce((t, a) => (a && a.kind === 'savings' ? t + num(a.balance) : t), 0);
    const debt = (data.debts || []).reduce((t, d) => t + num(d && d.remaining), 0);
    return { kind: 'balances', spendable, savings, debt, hasAccounts: accts.length > 0 };
  },

  payday(data, ctx) {
    const sched = data.settings && data.settings.paydaySchedule;
    if (!sched) return { kind: 'payday', none: true };
    return {
      kind: 'payday',
      days: daysUntilPayday(ctx.now, sched),
      next: nextPayday(ctx.now, sched),
      label: scheduleLabel(sched),
    };
  },
};
