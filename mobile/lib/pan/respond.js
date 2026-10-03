// Pan responder: FACTS -> { text, cta?, card?, mood }. This is the phrasing
// layer, and the ONLY place an LLM would later plug in. It receives numbers
// it did not compute and cannot change (no access to `data` or the engine),
// so even a future language model can only restate verified figures. Every
// answer follows the house rule: the number, one honest read, the assumption
// shown, one coaching line, never fake precision. mood drives the Pan avatar.

import { formatMoney } from '../format';

const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const m = (n) => formatMoney(Math.round(Number(n) || 0));

function fmtDate(d) {
  const dt = d instanceof Date ? d : d ? new Date(d) : null;
  if (!dt || isNaN(dt)) return '';
  return `${DAY[dt.getDay()]}, ${MON[dt.getMonth()]} ${dt.getDate()}`;
}

// Goal target dates are stored as "YYYY-MM" or "YYYY-MM-DD" strings. Format
// them by hand, no Date parsing, so a month-only target never gets a spurious
// day and a timezone never shifts it. Returns "Dec 2026" or "Dec 25, 2026".
function fmtTarget(iso) {
  const mt = /^(\d{4})-(\d{2})(?:-(\d{2}))?$/.exec(String(iso || '').trim());
  if (!mt) return '';
  const mon = MON[Number(mt[2]) - 1];
  if (!mon) return '';
  return mt[3] ? `${mon} ${Number(mt[3])}, ${mt[1]}` : `${mon} ${mt[1]}`;
}

export function respond(facts) {
  switch (facts.kind) {
    case 'safe_to_spend': {
      if (facts.available <= 0) {
        return {
          mood: 'worried',
          text: `The bills and minimums due before your ${fmtDate(facts.payday)} sweldo already use up your spendable cash. Best to hold off on extras until then. This counts only the bills you have logged, so add any I am missing.`,
          cta: { label: 'See what is committed', route: '/insights' },
        };
      }
      return {
        mood: 'idle',
        text:
          `You have ${m(facts.available)} free to spend until your ${fmtDate(facts.payday)} sweldo, about ${m(facts.perDay)} a day for ${facts.daysLeft} days. ` +
          `That already sets aside ${m(facts.committed)} for bills and minimums, and it does not touch your savings, on purpose.`,
        cta: { label: 'See the breakdown', route: '/insights' },
      };
    }

    case 'can_afford': {
      if (!facts.hasAmount) {
        return { mood: 'idle', text: 'Tell me the price and I will check it against what you can safely spend, like "can I afford 2000".' };
      }
      if (facts.afterBuy < 0) {
        return {
          mood: 'worried',
          text: `A ${m(facts.amount)} buy is more than the ${m(facts.available)} you have safe until sweldo. If it can wait until after ${fmtDate(facts.payday)}, that is the safer call.`,
        };
      }
      return {
        mood: 'happy',
        text: `You have ${m(facts.available)} safe until sweldo. A ${m(facts.amount)} buy leaves ${m(facts.afterBuy)}, about ${m(facts.perDayAfter)} a day for ${facts.daysLeft} days. ${facts.perDayAfter < 100 ? 'Doable, but tight.' : 'Comfortably doable.'}`,
      };
    }

    case 'utang': {
      if (facts.count === 0) {
        return { mood: 'idle', text: 'No one owes you right now, your utang list is clear. When you lend, log it here and I will track who to follow up.' };
      }
      const w = facts.worst;
      const lead =
        w && w.daysOverdue > 0
          ? `${facts.count} ${facts.count === 1 ? 'person owes' : 'people owe'} you ${m(facts.total)} total. Follow up ${w.name} first, ${m(w.outstanding)} and ${w.daysOverdue} ${w.daysOverdue === 1 ? 'day' : 'days'} past due.`
          : `${facts.count} ${facts.count === 1 ? 'person owes' : 'people owe'} you ${m(facts.total)} total. Nothing is overdue yet, a gentle reminder is enough.`;
      const reminder = w
        ? `Uy ${w.name}, pasensya na sa abala, gentle reminder lang sa ${m(w.outstanding)}, whenever kaya mo na. Salamat!`
        : null;
      return {
        mood: w && w.daysOverdue > 0 ? 'worried' : 'idle',
        text: `${lead} Collecting is not being madamot, a calm reminder keeps both the money and the friendship healthy.`,
        reminder,
        cta: { label: 'Open utang list', route: '/receivables' },
      };
    }

    case 'upcoming_bills': {
      if (!facts.bills.length) {
        return { mood: 'idle', text: `No bills logged before your ${fmtDate(facts.payday)} sweldo. If you have some coming, add them so I can protect that cash for you.` };
      }
      const lines = facts.bills.map((b) => `${b.name} ${m(b.amount)}${b.date ? ` (${fmtDate(b.date)})` : ''}`).join(', ');
      return {
        mood: 'idle',
        text: `Before your ${fmtDate(facts.payday)} sweldo: ${lines}. Total ${m(facts.total)}. Keep that parked so nothing bounces.`,
        cta: { label: 'See bills', route: '/insights' },
      };
    }

    case 'debt_due': {
      if (!facts.soonest) {
        return { mood: facts.count ? 'idle' : 'happy', text: facts.count ? 'None of your debts have a due date set. Add one and I will remind you before it lands.' : 'No debts to pay, nice. Debt free is a strong place to be.' };
      }
      const s = facts.soonest;
      const interest = s.lateInterest ? ` Paying only the minimum adds about ${m(s.lateInterest)} interest next month.` : '';
      return {
        mood: 'idle',
        text:
          `Soonest: ${s.name}, due ${fmtDate(s.due)}${s.moved ? ' (moved to the next banking day)' : ''}, balance ${m(s.remaining)}. ` +
          `Pay in full to stay interest free, or at least the ${m(s.minDue)} minimum.${interest}`,
        cta: { label: 'Open debts', route: '/debts' },
      };
    }

    case 'debt_free': {
      if (!facts.hasDebt) return { mood: 'happy', text: 'You have no debts to pay off. That is the finish line most people are working toward, and you are already there.' };
      if (facts.growing) {
        // Minimums are not covering the interest, so the balance never clears.
        if (facts.withExtra) {
          return { mood: 'idle', text: `At the current minimums, interest is outpacing your payments, so the balance is not going down. But adding ${m(facts.extra)} a month gets you to debt free around ${fmtDate(facts.withExtra.date)}. Paying more than the minimum is the way out.`, cta: { label: 'Plan payoff', route: '/reports' } };
        }
        return { mood: 'worried', text: 'At the current minimums, interest is outpacing your payments, so the balance is not going down. Paying more than the minimum, even a little, is what turns it around. Try "if I add 1000 a month" to see the difference.', cta: { label: 'Plan payoff', route: '/reports' } };
      }
      const base = `Paying current minimums, you are debt free around ${fmtDate(facts.base.date)} with about ${m(facts.base.totalInterest)} total interest.`;
      if (facts.withExtra) {
        return {
          mood: 'happy',
          text: `${base} Adding ${m(facts.extra)} a month moves that to ${fmtDate(facts.withExtra.date)} and cuts interest to about ${m(facts.withExtra.totalInterest)}. Small extra, big difference.`,
          cta: { label: 'Plan payoff', route: '/reports' },
        };
      }
      return { mood: 'idle', text: `${base} Try asking "if I add 1000 a month" to see how much sooner you finish.`, cta: { label: 'Plan payoff', route: '/reports' } };
    }

    case 'recap': {
      const r = facts.recap;
      // A negative kept rate means spending passed income, so say that in
      // words instead of printing a nonsense "you kept -100%".
      const kept =
        r.keptRate === null
          ? `${r.daysLogged} ${r.daysLogged === 1 ? 'day' : 'days'} logged`
          : r.keptRate < 0
          ? 'spending passed income'
          : `you kept ${Math.round(r.keptRate * 100)}%`;
      const top = r.topCats[0] ? ` Top spend was ${r.topCats[0].label} at ${r.topCats[0].pct}%.` : '';
      return {
        mood: r.keptRate !== null && r.keptRate >= 0.2 ? 'happy' : 'idle',
        text: `${r.label}: ${r.keptRate !== null ? `${m(r.moneyIn)} in, ${m(r.moneyOut)} out, ${kept}.` : `${kept}.`}${top} ${r.verdict}`,
        cta: { label: 'Make a share card', route: '/insights' },
      };
    }

    case 'top_spending': {
      if (!facts.rows.length) return { mood: 'idle', text: 'Not enough spending logged yet to spot a pattern. Log a few more and I will show where it goes.' };
      if (facts.hot) {
        const h = facts.hot;
        const hot = Math.round(h.now - h.expected);
        return { mood: 'worried', text: `${h.label} is at ${m(h.now)} this month. For this point your usual pace is about ${m(h.expected)}, so you are running roughly ${m(hot)} hot. Easing back frees that before sweldo.`, cta: { label: 'See categories', route: '/insights' } };
      }
      const top = facts.rows[0];
      return { mood: 'idle', text: `Your biggest category this month is ${top.label} at ${m(top.now)}, in line with your normal pace. Nothing running hot right now.`, cta: { label: 'See categories', route: '/insights' } };
    }

    case 'forecast': {
      const base = `At today's pace you are on track to spend about ${m(facts.projected)} by month end.`;
      if (facts.limit > 0) {
        return {
          mood: facts.over ? 'worried' : 'happy',
          text: facts.over
            ? `${base} Your limit is ${m(facts.limit)}, so roughly ${m(facts.projected - facts.limit)} over. Trimming a little each day gets you back under.`
            : `${base} That is under your ${m(facts.limit)} limit, you are on track.`,
        };
      }
      return { mood: 'idle', text: `${base} Set a monthly budget and I will tell you if you are on track to stay under.` };
    }

    case 'savings_rate': {
      if (facts.rate === null) return { mood: 'idle', text: 'Log some income this month and I can show your savings rate, the share of income you kept.' };
      if (facts.rate < 0) {
        return {
          mood: 'worried',
          text: 'Your spending outran your income this month, so nothing was saved and you dipped into reserves. No shame, it happens. The fix is one category at a time, and I can show which one ran hottest.',
        };
      }
      const pct = Math.round(facts.rate * 100);
      return {
        mood: pct >= 20 ? 'happy' : 'idle',
        text: `This month you kept ${pct}% of your income. A common starter target is 20%, ${pct >= 20 ? 'and you are there. Strong.' : 'so you are close.'} Debt payments count as money out here, so paying down debt is progress too.`,
      };
    }

    case 'goal_pace': {
      if (facts.none) return { mood: 'idle', text: 'You have no savings goals yet. Add one, like a Christmas fund or emergency fund, and I will pace it for you.', cta: { label: 'Add a goal', route: '/goals' } };
      const f = facts.focus;
      const p = f.pace;
      if (p.status === 'done') return { mood: 'happy', text: `Your ${f.name} is fully funded. Time to set the next one.`, cta: { label: 'Goals', route: '/goals' } };
      const pctStr = `${f.name} is ${Math.round(p.pct * 100)}%`;
      if (p.status === 'active') {
        // Only call it a small habit when the pace really is gentle; a huge
        // required monthly amount makes "one small habit change" tone-deaf.
        const nudge = p.perMonth > 0 && p.perMonth <= 3000 ? ' That is one small habit change.' : ' Set that aside each payday and you stay on track.';
        return { mood: 'idle', text: `${pctStr}. To finish by ${fmtTarget(p.targetDate)} you need about ${m(p.perMonth)} a month, or ${m(p.perWeek)} a week.${nudge}`, cta: { label: 'Goals', route: '/goals' } };
      }
      if (p.status === 'due-soon') return { mood: 'idle', text: `${pctStr}. Your ${fmtTarget(p.targetDate)} target lands this month, so you would need about ${m(p.remaining)} more to finish on time. Even part of it keeps you close.`, cta: { label: 'Goals', route: '/goals' } };
      if (p.status === 'behind') return { mood: 'worried', text: `${pctStr}, and the target date has passed with ${m(p.remaining)} still to go. Set a fresh date and I will give you a new weekly pace.`, cta: { label: 'Goals', route: '/goals' } };
      return { mood: 'idle', text: `${pctStr}, ${m(p.remaining)} to go. Add a target date and I will pace it for you.`, cta: { label: 'Goals', route: '/goals' } };
    }

    case 'health': {
      return {
        mood: facts.total >= 60 ? 'happy' : 'idle',
        text: `Your money health is ${facts.total} out of 100. Strongest: ${facts.strongest}. Weakest: ${facts.weakest}. Working on that one is the fastest way to raise your score.`,
        cta: { label: 'See the full score', route: '/insights' },
      };
    }

    case 'balances': {
      if (!facts.hasAccounts) return { mood: 'idle', text: 'You have no accounts set up yet. Add your cash, GCash, or bank so I can track what you have.', cta: { label: 'Add accounts', route: '/accounts' } };
      const debtLine = facts.debt > 0 ? ` You also owe ${m(facts.debt)} on debts.` : '';
      return {
        mood: 'idle',
        text: `You have ${m(facts.spendable)} spendable in cash and e-wallets${facts.savings > 0 ? `, plus ${m(facts.savings)} in savings` : ''}.${debtLine} Savings are yours to protect, not daily spending money.`,
        cta: { label: 'See accounts', route: '/accounts' },
      };
    }

    case 'payday': {
      if (facts.none) return { mood: 'idle', text: 'Set your payday schedule in More and I will count down your sweldo and figure your safe to spend.', cta: { label: 'Set payday', route: '/(tabs)/more' } };
      const d = facts.days;
      return {
        mood: 'idle',
        text: `Your next sweldo is ${fmtDate(facts.next)}, ${d <= 0 ? 'today' : `${d} ${d === 1 ? 'day' : 'days'} away`}, on your ${facts.label} schedule. Want your safe to spend for those days?`,
      };
    }

    default:
      return { mood: 'idle', text: 'I did not catch that one.' };
  }
}
