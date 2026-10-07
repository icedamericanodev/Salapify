// Earn-your-treats: temptation bundling. A user pairs a small treat with a
// self-defined healthy action, taps one check-in when they do the action, and
// the treat is "earned" once enough recent check-ins land. Pure functions, no
// network, no health data. It never blocks spending and never resets to zero:
// check-ins age out of a rolling window, and lifetime only grows. No dashes.

import { todayISO } from './format';

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
const clampInt = (x, lo, hi, dflt) => Math.min(Math.max(Math.round(num(x)) || dflt, lo), hi);

// 'YYYY-MM-DD' for the date n days before ref (n = 0 is today), local time.
function isoBack(ref, n) {
  const d = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() - n);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// Keep only check-ins inside the rolling window [today - (windowDays - 1) .. today].
// Deduped and sorted. ISO date strings compare chronologically, so string
// comparison is safe here.
export function pruneCheckIns(checkIns, windowDays, ref = new Date()) {
  const w = clampInt(windowDays, 1, 31, 7);
  const today = todayISO(ref);
  const cutoff = isoBack(ref, w - 1);
  return Array.from(new Set(
    (Array.isArray(checkIns) ? checkIns : []).filter(
      (d) => typeof d === 'string' && d >= cutoff && d <= today
    )
  )).sort();
}

// Live status of a treat rule against a reference date.
//   { treat, action, emoji, target, windowDays, recent, remaining, earned,
//     doneToday, lifetime }
export function treatStatus(treat, ref = new Date()) {
  const t = treat || {};
  const target = clampInt(t.target, 1, 14, 3);
  const windowDays = clampInt(t.windowDays, 1, 31, 7);
  const recentList = pruneCheckIns(t.checkIns, windowDays, ref);
  const recent = recentList.length;
  return {
    id: t.id,
    treat: t.treat,
    action: t.action,
    emoji: t.emoji || '☕',
    target,
    windowDays,
    recent,
    remaining: Math.max(0, target - recent),
    earned: recent >= target,
    doneToday: recentList.includes(todayISO(ref)),
    lifetime: Math.max(0, Math.round(num(t.lifetime))),
  };
}

// Toggle today's check-in, returning a NEW treat object (never mutates).
// Adding increments lifetime; undoing the same day decrements it. The stored
// check-ins are pruned to the window so state stays tiny.
export function toggleCheckIn(treat, ref = new Date()) {
  const t = treat || {};
  const windowDays = clampInt(t.windowDays, 1, 31, 7);
  const today = todayISO(ref);
  const existing = Array.isArray(t.checkIns) ? t.checkIns : [];
  const has = existing.includes(today);
  let lifetime = Math.max(0, Math.round(num(t.lifetime)));
  let checkIns;
  if (has) {
    checkIns = existing.filter((d) => d !== today);
    lifetime = Math.max(0, lifetime - 1);
  } else {
    checkIns = [...existing, today];
    lifetime = lifetime + 1;
  }
  return { ...t, checkIns: pruneCheckIns(checkIns, windowDays, ref), lifetime };
}

// Build a normalized new treat rule from form fields.
export function newTreat(fields, ref = new Date()) {
  const f = fields || {};
  const s = (v, d) => (typeof v === 'string' && v.trim() ? v.trim() : d);
  return {
    id: `treat_${Date.now()}`,
    treat: s(f.treat, 'My treat'),
    action: s(f.action, 'My healthy action'),
    emoji: (typeof f.emoji === 'string' && f.emoji) || '☕',
    target: clampInt(f.target, 1, 14, 3),
    windowDays: clampInt(f.windowDays, 1, 31, 7),
    checkIns: [],
    lifetime: 0,
    createdAt: todayISO(ref),
  };
}

// The starter templates shown on the empty state, tuned for a Filipino user.
export const TREAT_TEMPLATES = [
  { emoji: '☕', treat: 'Milk tea or kape', action: '30-minutong lakad', target: 3, windowDays: 7 },
  { emoji: '🍟', treat: 'Burger or sisig', action: 'Home-cooked baon', target: 3, windowDays: 7 },
  { emoji: '🎬', treat: 'Movie night', action: 'Maagang tulog', target: 4, windowDays: 7 },
  { emoji: '🛍️', treat: 'One item sa cart', action: 'Tubig, no softdrinks', target: 5, windowDays: 7 },
];
