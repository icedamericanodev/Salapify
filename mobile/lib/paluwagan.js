// Paluwagan: the rotating savings group (ROSCA) that runs on Filipino barkada
// and workplace trust. Every cycle all members contribute the same amount and
// one member takes the whole pot; over a full round everyone pays in and takes
// out exactly once, so it is interest free and zero sum. The ONLY variable is
// timing, and nobody explains it: an early turn is a 0% loan, a late turn is 0%
// forced savings. These pure functions compute your payout date, where you
// stand right now, and that honest read. No network, no dashes. The stored
// contribution also feeds safe-to-spend so your ambag is never mistaken for
// money you can spend.
//
// Convention: we assume you also contribute on your own payout cycle, so the
// gross pot is amount * members and your net take that month is the pot minus
// your own ambag. Some groups run the other rule (the recipient skips their own
// cycle and takes amount * (members - 1)); both are interest free and zero sum,
// they differ only by one contribution, and the setup copy names this so a real
// group is never surprised.

import { todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const clampInt = (x, lo, hi, dflt) => {
  const n = Math.round(Number(x));
  const v = Number.isFinite(n) ? n : dflt;
  return Math.min(Math.max(v, lo), hi);
};

export const PALUWAGAN_CADENCES = [
  { key: 'weekly', label: 'Weekly' },
  { key: 'kinsenas', label: 'Kinsenas (twice a month)' },
  { key: 'monthly', label: 'Monthly' },
];

const CADENCE_KEYS = PALUWAGAN_CADENCES.map((c) => c.key);

// Parse 'YYYY-MM-DD' to a local Date, rejecting anything the JS Date grammar
// would silently normalize (2026-02-30). Returns null on junk, so the caller
// falls back to today rather than drifting a whole round off a bad string.
function parseISO(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || ''));
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  const date = new Date(y, mo - 1, d);
  // Reject a day that rolled into the next month (Feb 30 becomes Mar 2).
  if (date.getMonth() !== mo - 1 || date.getDate() !== d) return null;
  return date;
}

function isoOf(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// Local midnight, so date-only comparisons never straddle a time of day.
function dayStart(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

function addMonthsClamped(y, m, day, k) {
  const target = new Date(y, m + k, 1);
  const ty = target.getFullYear();
  const tm = target.getMonth();
  const lastDay = new Date(ty, tm + 1, 0).getDate();
  return new Date(ty, tm, Math.min(day, lastDay));
}

// Kinsenas paydays are the 15th and the last day of each month. Walk months
// from the start and collect paydays on or after it until we have `count`.
function kinsenaSequence(start, count) {
  const out = [];
  let y = start.getFullYear();
  let m = start.getMonth();
  const startTime = dayStart(start);
  let guard = 0;
  while (out.length < count && guard < 2000) {
    const mid = new Date(y, m, 15);
    const end = new Date(y, m + 1, 0);
    for (const d of [mid, end]) {
      if (dayStart(d) >= startTime && out.length < count) out.push(d);
    }
    m += 1;
    if (m > 11) {
      m = 0;
      y += 1;
    }
    guard += 1;
  }
  return out;
}

// The Date of every cycle 1..members, in order, for the given cadence.
function cycleDates(p) {
  const start = parseISO(p.startDate) || parseISO(todayISO()) || new Date();
  const n = p.members;
  if (p.cadence === 'weekly') {
    return Array.from({ length: n }, (_, i) =>
      new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7 * i));
  }
  if (p.cadence === 'kinsenas') {
    return kinsenaSequence(start, n);
  }
  return Array.from({ length: n }, (_, i) =>
    addMonthsClamped(start.getFullYear(), start.getMonth(), start.getDate(), i));
}

// Normalize a raw add/edit form into a stored paluwagan. Mirrors newTreat: the
// screen can hand in partial junk and get back a safe, fully shaped object.
export function newPaluwagan(form, refDate = new Date()) {
  const f = form || {};
  const members = clampInt(f.members, 2, 60, 5);
  const cadence = CADENCE_KEYS.includes(f.cadence) ? f.cadence : 'monthly';
  const start = parseISO(f.startDate) ? f.startDate : isoOf(refDate);
  return {
    id: typeof f.id === 'string' && f.id ? f.id : `paluwagan_${Date.now()}`,
    name: (typeof f.name === 'string' && f.name.trim()) || 'Paluwagan',
    amount: Math.max(0, num(f.amount)),
    members,
    cadence,
    startDate: start,
    myTurn: clampInt(f.myTurn, 1, members, 1),
    paidCycles: clampInt(f.paidCycles, 0, members, 0),
    note: typeof f.note === 'string' ? f.note.slice(0, 200) : '',
  };
}

// The honest timing read. An early slot is a cheap loan, a late slot is forced
// saving; the middle is a wash. Based on position in the round, not the peso
// amount, so it is stable to test.
function dealType(myTurn, members) {
  if (members <= 1) return 'middle';
  const frac = (myTurn - 1) / (members - 1);
  if (frac <= 0.34) return 'early';
  if (frac >= 0.66) return 'late';
  return 'middle';
}

// The one decision object the screen renders. Every peso here comes from these
// functions, never invented in the widget.
export function paluwaganStatus(p, refDate = new Date()) {
  const amount = Math.max(0, num(p.amount));
  // A paluwagan needs at least two people; keep the floor identical to
  // newPaluwagan so a stored or hand-built object cannot become a degenerate
  // self-paluwagan that the model would wrongly treat as valid.
  const members = clampInt(p.members, 2, 60, 2);
  const myTurn = clampInt(p.myTurn, 1, members, 1);
  const paidCycles = clampInt(p.paidCycles, 0, members, 0);
  const norm = { ...p, amount, members, myTurn, paidCycles };

  const dates = cycleDates(norm);
  const ref = dayStart(refDate);
  let currentCycle = 0;
  for (const d of dates) {
    if (dayStart(d) <= ref) currentCycle += 1;
  }

  const payoutDate = dates[myTurn - 1] ? isoOf(dates[myTurn - 1]) : null;
  const payoutAmount = amount * members;
  const totalContribution = amount * members;
  const contributedSoFar = amount * paidCycles;
  const remainingContribution = Math.max(0, amount * (members - paidCycles));
  const received = currentCycle >= myTurn;
  const cyclesToPayout = Math.max(0, myTurn - currentCycle);
  const behindBy = Math.max(0, amount * (currentCycle - paidCycles));
  const behind = behindBy > 0;
  const netNow = (received ? payoutAmount : 0) - contributedSoFar;
  const done = currentCycle >= members;

  return {
    id: norm.id,
    name: norm.name,
    amount,
    members,
    myTurn,
    cadence: norm.cadence,
    paidCycles,
    currentCycle,
    payoutAmount,
    payoutDate,
    totalContribution,
    contributedSoFar,
    remainingContribution,
    received,
    cyclesToPayout,
    behind,
    behindBy,
    netNow,
    done,
    dealType: dealType(myTurn, members),
  };
}

// What a paluwagan takes out of a normal month, so safe-to-spend treats your
// ambag as spoken for. Zero once the round is finished or you have prepaid
// every cycle. Never reserves more than you still owe, so a fully-prepaid
// member is not charged again and a short weekly round (whose run-rate exceeds
// the little that is left) does not over-reserve and understate spendable cash.
export function paluwaganMonthlyCommitment(p, refDate = new Date()) {
  const s = paluwaganStatus(p, refDate);
  if (s.done || s.remainingContribution <= 0) return 0;
  let rate;
  if (s.cadence === 'weekly') rate = s.amount * (52 / 12);
  else if (s.cadence === 'kinsenas') rate = s.amount * 2;
  else rate = s.amount;
  return Math.min(rate, s.remainingContribution);
}

// Sum the monthly commitment across every active paluwagan, for the safe-to
// -spend and sweldo-plan math.
export function paluwaganTotalCommitment(list, refDate = new Date()) {
  if (!Array.isArray(list)) return 0;
  return list.reduce((t, p) => t + (p ? paluwaganMonthlyCommitment(p, refDate) : 0), 0);
}
