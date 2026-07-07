// The weekly money check-in. The app already computes everything about your
// money; the problem is nobody opens Insights on a Tuesday. This surfaces the
// ONE thing that actually needs a decision this week, chosen for you, with a
// suggested action. One item, ranked by urgency and how actionable it is,
// dismissible, never a scold. Pure: it only reads figures the engine produced,
// invents no numbers, and moves no money.

import {
  safeToSpend,
  utangAging,
  categoryVsAverage,
  forecastMonthEnd,
  goalPace,
  savingsRate,
} from './analytics';
import { upcomingDues } from './soa';
import { formatMoney, todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const m = (n) => formatMoney(Math.round(num(n)));

// A stable key for the current week (its Monday), so a dismissal is remembered
// for the week without adding a stored shape. Monday keeps a check-in from
// resetting mid-week.
export function weekKey(ref = new Date()) {
  const d = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  const mondayOffset = (d.getDay() + 6) % 7; // Sun=6 ... Mon=0
  d.setDate(d.getDate() - mondayOffset);
  return todayISO(d);
}

// weeklyCheckIn(data, ref) -> one item:
//   { kind, tone, title, message, action:{label,route}|null, week }
// tone is 'urgent' | 'watch' | 'nudge' | 'good' for the card's styling. When
// nothing needs a decision it returns a calm all-clear ('good'), never silence
// dressed as a problem.
export function weeklyCheckIn(data, ref = new Date()) {
  const d = data || {};
  const cands = [];

  // Cash crunch: bills and minimums before the next sweldo already eat the
  // spendable cash. The most urgent thing to know.
  const s = safeToSpend(d, ref);
  if (s.liquid > 0 && s.available <= 0) {
    cands.push({
      prio: 100,
      kind: 'crunch',
      tone: 'urgent',
      title: 'Money is tight until sweldo',
      message: 'The bills and minimums due before your next sweldo already use up your spendable cash. Best to hold off on extras until payday.',
      action: { label: 'See what is committed', route: '/insights' },
    });
  }

  // Overdue utang: money owed to you, with a clear action (a gentle reminder).
  const u = utangAging(d, ref);
  if (u.overdueCount > 0 && u.worst) {
    const w = u.worst;
    cands.push({
      prio: 90,
      kind: 'utang',
      tone: 'watch',
      title: `Follow up ${w.name}`,
      message: `${w.name} is ${w.daysOverdue} ${w.daysOverdue === 1 ? 'day' : 'days'} overdue on ${m(w.outstanding)}. A calm reminder keeps both the money and the friendship healthy.`,
      action: { label: 'Open utang list', route: '/receivables' },
    });
  }

  // Spending passed income this month: serious, and honest without shame.
  const rate = savingsRate(d.transactions || [], d.payments || [], ref);
  if (rate !== null && rate < 0) {
    cands.push({
      prio: 85,
      kind: 'overspend',
      tone: 'watch',
      title: 'Spending passed income this month',
      message: 'More went out than came in this month. No shame, it happens. The fastest fix is easing the one category running hottest.',
      action: { label: 'See where it went', route: '/insights' },
    });
  }

  // A card or debt due within the week: pay in full to stay interest free.
  const dues = upcomingDues(d.debts, 7, ref) || [];
  if (dues.length) {
    const name = (dues[0].debt && dues[0].debt.name) || 'A card';
    cands.push({
      prio: 80,
      kind: 'debtdue',
      tone: 'watch',
      title: `${name} is due soon`,
      message: `${name} is due within the week. Paying it in full keeps you interest free; at least pay the minimum to dodge a late fee.`,
      action: { label: 'Open debts', route: '/debts' },
    });
  }

  // A category running hot versus its own usual pace for this point in month.
  const vs = categoryVsAverage(d.transactions || [], ref) || [];
  const hot = vs.find((v) => v && v.expected > 0 && v.now > v.expected * 1.2);
  if (hot) {
    cands.push({
      prio: 70,
      kind: 'hot',
      tone: 'watch',
      title: `${hot.label} is running hot`,
      message: `You are about ${m(hot.now - hot.expected)} over your usual ${hot.label} pace for this point in the month. Easing back frees that before sweldo.`,
      action: { label: 'See categories', route: '/insights' },
    });
  }

  // Projected to blow the monthly budget at today's pace.
  const f = forecastMonthEnd(d.transactions || [], ref);
  const limit = num(d.settings && d.settings.monthlyLimit);
  if (limit > 0 && f.projected > limit) {
    cands.push({
      prio: 60,
      kind: 'forecast',
      tone: 'watch',
      title: 'On track to go over budget',
      message: `At today's pace you will spend about ${m(f.projected)} by month end, over your ${m(limit)} limit. Trimming a little each day gets you back under.`,
      action: { label: 'Check budget', route: '/budget' },
    });
  }

  // A goal whose target date has passed: nudge to reset the date.
  for (const g of (d.goals || []).filter((x) => x && num(x.target) > 0)) {
    const p = goalPace(g, ref);
    if (p.status === 'behind') {
      cands.push({
        prio: 50,
        kind: 'goal',
        tone: 'nudge',
        title: `${g.name || 'A goal'} slipped its date`,
        message: `${g.name || 'Your goal'} is ${Math.round(p.pct * 100)}% funded and its target date has passed with ${m(p.remaining)} to go. Set a fresh date and I will pace it again.`,
        action: { label: 'Open goals', route: '/goals' },
      });
      break;
    }
  }

  cands.sort((a, b) => b.prio - a.prio);
  const week = weekKey(ref);
  if (cands.length) {
    const top = cands[0];
    return { kind: top.kind, tone: top.tone, title: top.title, message: top.message, action: top.action, week };
  }

  // Nothing needs a decision. A calm all-clear, not a manufactured worry.
  return {
    kind: 'good',
    tone: 'good',
    title: 'You are on track this week',
    message: 'Nothing needs a money decision right now. Keep logging and enjoy the calm.',
    action: null,
    week,
  };
}
