// The weekly money check-in and the DO NEXT decision layer. The app already
// computes everything about your money; the problem is nobody opens Insights on
// a Tuesday. This surfaces the things that actually need a decision, chosen for
// you, each with a suggested action, ranked by urgency and how actionable it is.
// Pure: it only reads figures the engine produced, invents no numbers, and moves
// no money.
//
// One source of truth: decisionCandidates() builds and sorts the full ranked
// list. weeklyCheckIn() (Home) returns the single top item, and Insights renders
// the top few, so Home and Insights can never contradict each other.

import {
  safeToSpend,
  utangAging,
  categoryVsAverage,
  forecastMonthEnd,
  goalPace,
  savingsRate,
  emergencyRunway,
  netWorth,
} from './analytics';
import { upcomingDues } from './soa';
import { formatMoney, todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const m = (n) => formatMoney(Math.round(num(n)));

// Categories that are essentials: the coach must never tell someone to cut
// these. Word-based, not substring, so short keys stop over-matching (a naive
// substring made 'med' hit Comedy/Remedy, 'bill' hit Billiards, 'fare' hit
// Welfare, 'load' hit Download). We lowercase the label, split it into word
// tokens on any non-letter (so "Meralco bill", "Jeepney fare", "Water/Tubig"
// all tokenize cleanly), and treat it as essential when a token matches an
// exact word OR begins with a safe stem. The list includes Filipino/Taglish
// essentials because the audience is Filipino. Over-inclusive is the safe side:
// wrongly calling something essential only costs a softer nudge, while wrongly
// telling someone to cut rent or gamot is the real harm.
const ESSENTIAL_WORDS = new Set([
  'food', 'foods', 'rent', 'renta', 'upa', 'fare', 'fares', 'pamasahe',
  'commute', 'load', 'bill', 'bills', 'bayarin', 'water', 'tubig', 'meds',
  'gamot', 'gatas', 'baon', 'pagkain', 'ospital', 'hospital', 'meralco',
  'tuition', 'matrikula',
]);
const ESSENTIAL_STEMS = [
  'grocer', 'utilit', 'transport', 'medic', 'insur', 'electr', 'school',
  'health', 'kuryente',
];
const isEssentialLabel = (label) => {
  const tokens = String(label || '')
    .toLowerCase()
    .split(/[^a-z]+/)
    .filter(Boolean);
  return tokens.some(
    (t) => ESSENTIAL_WORDS.has(t) || ESSENTIAL_STEMS.some((stem) => t.startsWith(stem))
  );
};

// A stable key for the current week (its Monday), so a dismissal is remembered
// for the week without adding a stored shape. Monday keeps a check-in from
// resetting mid-week.
export function weekKey(ref = new Date()) {
  const d = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
  const mondayOffset = (d.getDay() + 6) % 7; // Sun=6 ... Mon=0
  d.setDate(d.getDate() - mondayOffset);
  return todayISO(d);
}

// decisionCandidates(data, ref) -> the FULL ranked list of things worth a money
// decision right now, each shaped { prio, kind, tone, title, message,
// action:{label,route} }, sorted by prio descending. tone is 'urgent' |
// 'watch' | 'nudge' for styling. This is the single ranking Home and Insights
// both read from. Empty when nothing needs a decision.
//
// Priority order (desc): crunch 100 > debtdue 92 > utang 90 > overspend 85 >
// hot 70 > forecast 60 > logtoday 58 > buffer 55 > goal 50 > lesson 45.
export function decisionCandidates(data, ref = new Date()) {
  const d = data || {};
  const cands = [];

  // Cash crunch: bills and minimums before the next sweldo already eat the
  // spendable cash. The most urgent thing to know. Computed once and reused
  // below for the goal and buffer guardrails.
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

  // A debt due within the week. Time-critical (a late payment adds a fee, and
  // for a card, interest), so it ranks high. The interest-free advice is only
  // true for revolving debt; an amortized loan bakes interest into every
  // installment, so it gets honest late-fee copy instead.
  const dues = upcomingDues(d.debts, 7, ref) || [];
  if (dues.length) {
    const debt = dues[0].debt || {};
    const name = debt.name || 'A debt';
    const revolving = debt.type === 'credit card' || debt.type === 'bnpl';
    cands.push({
      prio: 92,
      kind: 'debtdue',
      tone: 'watch',
      title: `${name} is due soon`,
      message: revolving
        ? `${name} is due within the week. Paying it in full keeps you interest free; at least pay the minimum to dodge a late fee.`
        : `${name} is due within the week. Do not miss it, a late payment usually adds a fee on top.`,
      action: { label: 'Open debts', route: '/debts' },
    });
  }

  // A category running hot versus its own usual pace for this point in month.
  // Guardrail: never tell someone to cut an essential. An essential category
  // keeps an informational heads-up with no "ease back / trim / frees" cut
  // language; a discretionary one keeps the gentle ease-back nudge. Never a
  // scold either way.
  const vs = categoryVsAverage(d.transactions || [], ref) || [];
  const hot = vs.find((v) => v && v.expected > 0 && v.now > v.expected * 1.2);
  if (hot) {
    const essential = isEssentialLabel(hot.label);
    cands.push({
      prio: 70,
      kind: 'hot',
      tone: 'watch',
      title: `${hot.label} is running hot`,
      message: essential
        ? `${hot.label} is running higher than your usual pace this month, worth a look.`
        : `You are about ${m(hot.now - hot.expected)} over your usual ${hot.label} pace for this point in the month. Easing back frees that before sweldo.`,
      action: { label: 'See categories', route: '/insights' },
    });
  }

  // Projected to blow the monthly budget at today's pace. Only after the first
  // week, so a single day-one expense does not extrapolate to an alarming, and
  // meaningless, month-end figure.
  const f = forecastMonthEnd(d.transactions || [], ref);
  const limit = num(d.settings && d.settings.monthlyLimit);
  if (limit > 0 && f.dayOfMonth >= 7 && f.projected > limit) {
    cands.push({
      prio: 60,
      kind: 'forecast',
      tone: 'watch',
      title: 'On track to go over budget',
      message: `At today's pace you will spend about ${m(f.projected)} by month end, over your ${m(limit)} limit. Trimming a little each day gets you back under.`,
      action: { label: 'Check budget', route: '/budget' },
    });
  }

  // Log today: the two-second habit that keeps every other number honest.
  // Only for a user who has actually started (any account or any past log), so
  // a brand-new empty app is never nagged. Real logs only (income or expense);
  // transfer and debt-payment rows are bookkeeping, not the logging habit.
  const todayStr = todayISO(ref);
  const hasStarted =
    (Array.isArray(d.accounts) && d.accounts.length > 0) ||
    (Array.isArray(d.transactions) && d.transactions.length > 0);
  const loggedToday = (d.transactions || []).some(
    (t) => t && (t.type === 'income' || t.type === 'expense') && t.date === todayStr
  );
  if (hasStarted && !loggedToday) {
    cands.push({
      prio: 58,
      kind: 'logtoday',
      tone: 'nudge',
      title: 'Log today',
      message: 'Two seconds keeps your numbers honest. Add what you spent today.',
      action: { label: 'Add spending', route: '/' },
    });
  }

  // Emergency buffer thin: under a month of expenses covered. Only nudge when
  // the buffer is real this cycle. If safe-to-spend available is <= 0, the
  // buffer money is already committed to bills before payday, so telling them
  // to add to it now would be dishonest. Never fires on a brand-new app
  // (monthsCovered is null with no spending history).
  const rw = emergencyRunway(d, ref);
  if (rw.monthsCovered != null && rw.monthsCovered < 1 && s.available > 0) {
    // Adaptive, never a flat "10,000". If the buffer is still short of the first
    // target, name the actual shortfall; once past it (but still under a month
    // covered, so a high spender), phrase it generically toward a full month.
    const shortfall = rw.firstTarget - rw.buffer;
    const nudge = shortfall > 0
      ? `Even ${m(shortfall)} more toward your first cushion`
      : 'Even a little more toward your first full month';
    cands.push({
      prio: 55,
      kind: 'buffer',
      tone: 'nudge',
      title: 'Your buffer is thin',
      message: `Your buffer covers under a month. ${nudge} helps stop a surprise from becoming utang.`,
      action: { label: 'Open goals', route: '/goals' },
    });
  }

  // A goal whose target date has passed: nudge to reset the date. Guardrail:
  // survival before aspiration. If there is nothing free to spend this cycle
  // (available <= 0), do not push funding a goal now; give calm permission to
  // pause it until bills ease up.
  for (const g of (d.goals || []).filter((x) => x && num(x.target) > 0)) {
    const p = goalPace(g, ref);
    if (p.status === 'behind') {
      const name = g.name || 'Your goal';
      cands.push({
        prio: 50,
        kind: 'goal',
        tone: 'nudge',
        title: `${g.name || 'A goal'} slipped its date`,
        message: s.available <= 0
          ? `${name}'s target date has passed. Okay lang to pause this goal muna, bills muna. Come back to it when this cycle eases up.`
          : `${name} is ${Math.round(p.pct * 100)}% funded and its target date has passed with ${m(p.remaining)} to go. Set a fresh date and I will pace it again.`,
        action: { label: 'Open goals', route: '/goals' },
      });
      break;
    }
  }

  // A contextual lesson or tool, tied to the user's real situation, so a calm
  // week becomes a learning moment instead of a blank all-clear. Low priority
  // on purpose: any real money decision above always wins, and only one lesson
  // is offered, the most relevant. Never a product pitch, just education.
  const debts = d.debts || [];
  const hasCard = debts.some((x) => x && x.type === 'credit card' && num(x.remaining) > 0);
  const hasBnpl = debts.some((x) => x && x.type === 'bnpl' && num(x.remaining) > 0);
  const hasReceivables = !!(u.people && u.people.length > 0);
  const yearEnd = ref.getMonth() === 10 || ref.getMonth() === 11; // Nov or Dec
  let lesson = null;
  if (yearEnd) {
    lesson = { prio: 45, id: 'thirteenth-month', title: 'Make your 13th month count', message: 'Sweldo season is here. A short read on making your 13th month pay actually last, so it does not vanish by January.' };
  } else if (hasCard) {
    lesson = { prio: 40, id: 'card-interest', title: 'Beat the minimum payment trap', message: 'You are carrying a card balance. A two minute read on how paying only the minimum quietly grows what you owe, and the one rule that stops it.' };
  } else if (hasBnpl) {
    lesson = { prio: 38, id: 'bnpl', title: 'Keep BNPL from piling up', message: 'You have a buy now pay later balance. A quick read on keeping the installments from stacking past what one sweldo can cover.' };
  } else if (hasReceivables) {
    lesson = { prio: 34, id: 'utang-friends', title: 'Collect utang the kind way', message: 'People owe you. A short read on getting paid back without losing the friendship.' };
  }
  if (lesson) {
    cands.push({
      prio: lesson.prio,
      kind: 'lesson',
      tone: 'nudge',
      title: lesson.title,
      message: lesson.message,
      action: { label: 'Read the lesson', route: `/learn?focus=${lesson.id}` },
    });
  }

  cands.sort((a, b) => b.prio - a.prio);
  return cands;
}

// weeklyCheckIn(data, ref) -> one item:
//   { kind, tone, title, message, action:{label,route}|null, week }
// The single top-ranked decision, or a calm all-clear ('good') when nothing
// needs one, never silence dressed as a problem. Reads the same ranked list as
// the Insights DO NEXT card, so the two can never disagree on what matters.
export function weeklyCheckIn(data, ref = new Date()) {
  const cands = decisionCandidates(data, ref);
  const week = weekKey(ref);
  // Home is one urgent item, and a quiet all-clear is the reward. The habit and
  // buffer nudges ('logtoday', 'buffer') would read as daily nagging on the
  // dashboard, so Home intentionally excludes them; the fuller Insights DO NEXT
  // feed still carries them.
  const top = cands.find((c) => c.kind !== 'logtoday' && c.kind !== 'buffer');
  if (top) {
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

// pickWin(data, ref) -> one honest positive { text }, or null. First match
// wins, and every branch is a real fact from the engine, never a manufactured
// pat on the back. Order: net worth up, a goal near or funded, then (both gated
// on healthy logging so nothing is celebrated on sparse logs) a positive savings
// rate, and finally the logging streak itself as the fallback. A savings rate
// off sparse logs is a mirage, so it is never celebrated then.
export function pickWin(data, ref = new Date()) {
  const d = data || {};

  // (a) Net worth up versus the previous real snapshot. One shared formula so
  // this matches Home, Insights, and Reports exactly (includes tracked utang).
  const nw = netWorth(d);
  const hist = (Array.isArray(d.settings && d.settings.nwHistory) ? d.settings.nwHistory : []).filter(
    (h) => h && typeof h.month === 'string' && Number.isFinite(Number(h.value))
  );
  const curKey = todayISO(ref).slice(0, 7);
  const prior = hist.filter((h) => h.month < curKey).sort((a, b) => a.month.localeCompare(b.month));
  const prev = prior.length ? prior[prior.length - 1] : null;
  if (prev && nw > Number(prev.value)) {
    // "since your last check-in": the snapshot can be older than a month if
    // Insights was not opened every month, so this stays honest whatever the gap.
    return { text: `Your net worth is up ${m(nw - Number(prev.value))} since your last check-in.` };
  }

  // (b) A goal near the finish, or fully funded. The highest-progress goal at
  // 80% or better carries the win.
  let best = null;
  for (const g of (d.goals || []).filter((x) => x && num(x.target) > 0)) {
    const p = goalPace(g, ref);
    if (p.pct >= 0.8 && (!best || p.pct > best.pct)) best = { name: g.name || 'Your goal', pct: p.pct };
  }
  if (best) {
    return best.pct >= 1
      ? { text: `${best.name} is fully funded. 🎉` }
      : { text: `Almost there: ${best.name} is ${Math.round(best.pct * 100)}% funded.` };
  }

  // Healthy logging gate: 4 or more of the last 7 days have a real log. Both the
  // savings-rate win and the streak win below require this, so nothing positive
  // is ever celebrated on sparse logs.
  const logged = new Set(
    (d.transactions || [])
      .filter((t) => t && (t.type === 'income' || t.type === 'expense'))
      .map((t) => t.date)
  );
  let daysLogged = 0;
  for (let i = 0; i < 7; i++) {
    const day = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - i);
    if (logged.has(todayISO(day))) daysLogged += 1;
  }
  const loggingHealthy = daysLogged >= 4;

  // (c) A positive savings rate, but ONLY when logging is healthy. Checked
  // before the streak so a genuine positive rate is the win when it exists.
  const rate = savingsRate(d.transactions || [], d.payments || [], ref);
  if (loggingHealthy && rate !== null && rate > 0) {
    return { text: `You kept ${Math.round(rate * 100)}% of your income this month. Nice.` };
  }

  // (d) The logging streak itself, the fallback win when the habit is strong.
  if (loggingHealthy) {
    return { text: `You have logged ${daysLogged} of the last 7 days. That habit is the win.` };
  }

  return null;
}
