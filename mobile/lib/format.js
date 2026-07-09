// format.js holds small helpers for showing values nicely.

// The currency symbol used by formatMoney when no symbol is passed. It is kept
// here as a single value and updated from settings (see AppData), so changing
// the currency relabels amounts across the whole app without touching every
// call site.
let currentSymbol = '₱';
export function setCurrencySymbol(symbol) {
  if (symbol) currentSymbol = symbol;
}
// The current symbol as a plain string, for callers that need to capture it on
// the JS side and hand it to a worklet (the animated count-up cannot read this
// module's state from the UI thread).
export function getCurrencySymbol() {
  return currentSymbol;
}

// formatMoney turns a number like 48500 into a string like "₱48,500".
// It rounds to whole units, adds commas every three digits, and uses the
// current currency symbol unless one is passed in.
export function formatMoney(amount, symbol) {
  const sym = symbol || currentSymbol;
  const n = Math.round(Number(amount) || 0);
  const sign = n < 0 ? '-' : '';
  const digits = Math.abs(n)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ','); // insert commas
  return sign + sym + digits;
}

// todayISO gives the local date as text like "2026-07-02". Built from local
// date parts on purpose: toISOString uses UTC, which is a day behind the
// Philippines until 8am, and money should never land on the wrong day.
export function todayISO(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// isThisMonth checks whether a "YYYY-MM-DD" date string falls in the current
// month. An item with no date is NOT this month: every real entry is dated at
// creation, so a dateless one only comes from an imported or hand edited backup,
// and counting it would inflate this month's totals every single month forever.
export function isThisMonth(dateStr, ref = new Date()) {
  if (!dateStr) return false;
  return String(dateStr).slice(0, 7) === todayISO(ref).slice(0, 7);
}

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// monthLabel gives "July 2026", shown next to every this-month number so the
// user always knows which period they are looking at.
export function monthLabel(ref = new Date()) {
  return `${MONTH_NAMES[ref.getMonth()]} ${ref.getFullYear()}`;
}

// ---- Period views ----
// A "period" says which slice of time a screen is showing. It is a small plain
// object, one of:
//   { mode: 'all' }
//   { mode: 'month', ym: 'YYYY-MM' }
//   { mode: 'year',  y:  'YYYY' }
//   { mode: 'custom', from: 'YYYY-MM-DD', to: 'YYYY-MM-DD' }  (from/to may be '')
// A screen keeps one period in state and filters its rows through inPeriod, so
// Month, Year, and a Custom range all share the exact same logic. This is the
// reusable core behind the Month/Year/Custom selector.

// currentMonthPeriod is the sensible default: this calendar month.
export function currentMonthPeriod(ref = new Date()) {
  return { mode: 'month', ym: todayISO(ref).slice(0, 7) };
}

// inPeriod tells you if a transaction date belongs to the period. A dateless
// entry never belongs to a chosen period (it only comes from an imported backup
// and would otherwise leak into every view).
export function inPeriod(dateStr, period) {
  if (!period || period.mode === 'all') return true;
  const d = dateStr ? String(dateStr).slice(0, 10) : '';
  if (!d) return false;
  if (period.mode === 'year') return d.slice(0, 4) === period.y;
  if (period.mode === 'custom') {
    if (period.from && d < period.from) return false;
    if (period.to && d > period.to) return false;
    return true;
  }
  // month (the default shape)
  return d.slice(0, 7) === period.ym;
}

// periodLabel is the human title for the current period, e.g. "July 2026",
// "2026", "2026-06-01 to 2026-06-15", or "All time".
export function periodLabel(period) {
  if (!period || period.mode === 'all') return 'All time';
  if (period.mode === 'year') return period.y;
  if (period.mode === 'custom') {
    if (period.from && period.to) return `${period.from} to ${period.to}`;
    if (period.from) return `From ${period.from}`;
    if (period.to) return `Until ${period.to}`;
    return 'All dates';
  }
  // month: build a local date from the YYYY-MM so the label reads "July 2026".
  const [y, m] = String(period.ym || '').split('-').map(Number);
  if (!y || !m) return '';
  return monthLabel(new Date(y, m - 1, 1));
}

// shiftPeriod steps a month or year period by delta (negative = back). A custom
// range has explicit dates, so it is returned unchanged.
export function shiftPeriod(period, delta) {
  if (!period) return period;
  if (period.mode === 'year') return { mode: 'year', y: String(Number(period.y) + delta) };
  if (period.mode === 'month') {
    const [y, m] = String(period.ym).split('-').map(Number);
    const d = new Date(y, m - 1 + delta, 1);
    return { mode: 'month', ym: todayISO(d).slice(0, 7) };
  }
  return period;
}

// periodIsFuture is true when the whole period is past today, so a screen can
// stop the user stepping forward into an empty future month or year.
export function periodIsFuture(period, ref = new Date()) {
  if (!period) return false;
  const now = todayISO(ref);
  if (period.mode === 'year') return period.y > now.slice(0, 4);
  if (period.mode === 'month') return period.ym > now.slice(0, 7);
  return false;
}

// ---- Payday schedule ----
// The schedule lives in settings.paydaySchedule and comes in three shapes:
//   { mode: 'semimonthly', days: [15, 31] }  the Filipino kinsenas and
//     katapusan default; a day of 31 always clamps to the month's last day
//   { mode: 'monthly', day: 30 }             one payday a month
//   { mode: 'weekly', weekday: 5 }           0 is Sunday through 6 Saturday
// Anything missing or malformed normalizes to the default, so every reader
// can trust the shape without checking.
export function normalizeSchedule(s) {
  const clampDay = (d, fallback) => {
    const n = Math.trunc(Number(d));
    return Number.isFinite(n) && n >= 1 && n <= 31 ? n : fallback;
  };
  if (s && s.mode === 'monthly') return { mode: 'monthly', day: clampDay(s.day, 30) };
  if (s && s.mode === 'weekly') {
    const w = Math.trunc(Number(s.weekday));
    return { mode: 'weekly', weekday: Number.isFinite(w) && w >= 0 && w <= 6 ? w : 5 };
  }
  if (s && s.mode === 'semimonthly' && Array.isArray(s.days)) {
    return { mode: 'semimonthly', days: [clampDay(s.days[0], 15), clampDay(s.days[1], 31)] };
  }
  return { mode: 'semimonthly', days: [15, 31] };
}

// The paydays inside one month, clamped so day 31 means the month's real
// last day, sorted and deduped (15 and 15 is one payday, not two).
function monthPaydays(y, m, schedule) {
  const lastDay = new Date(y, m + 1, 0).getDate();
  const days = schedule.mode === 'monthly' ? [schedule.day] : schedule.days;
  const clamped = [...new Set(days.map((d) => Math.min(d, lastDay)))].sort((a, b) => a - b);
  return clamped.map((d) => new Date(y, m, d));
}

// The next payday on or after "today" (whole days, time ignored).
export function nextPayday(today = new Date(), schedule) {
  const sch = normalizeSchedule(schedule);
  const startToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (sch.mode === 'weekly') {
    const ahead = (sch.weekday - startToday.getDay() + 7) % 7;
    return new Date(startToday.getFullYear(), startToday.getMonth(), startToday.getDate() + ahead);
  }
  for (let i = 0; i <= 1; i++) {
    for (const c of monthPaydays(today.getFullYear(), today.getMonth() + i, sch)) {
      if (c >= startToday) return c;
    }
  }
  return startToday; // unreachable with a normalized schedule
}

// The most recent payday on or before "today".
export function prevPayday(today = new Date(), schedule) {
  const sch = normalizeSchedule(schedule);
  const startToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (sch.mode === 'weekly') {
    const back = (startToday.getDay() - sch.weekday + 7) % 7;
    return new Date(startToday.getFullYear(), startToday.getMonth(), startToday.getDate() - back);
  }
  for (let i = 0; i >= -1; i--) {
    const list = monthPaydays(today.getFullYear(), today.getMonth() + i, sch).reverse();
    for (const c of list) {
      if (c <= startToday) return c;
    }
  }
  return startToday; // unreachable with a normalized schedule
}

// The next `count` paydays in order, starting from today. Used by
// notifications so reminders follow the user's real schedule.
export function upcomingPaydays(today = new Date(), schedule, count = 6) {
  const out = [];
  let cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  for (let i = 0; i < count; i++) {
    const p = nextPayday(cursor, schedule);
    out.push(p);
    cursor = new Date(p.getFullYear(), p.getMonth(), p.getDate() + 1);
  }
  return out;
}

// daysUntilPayday counts the days to the next payday on the user's own
// schedule. 0 means payday is today.
export function daysUntilPayday(today = new Date(), schedule) {
  const startToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  return Math.round((nextPayday(today, schedule) - startToday) / 86400000);
}

// A short human line describing the schedule, for the payday card and the
// settings row.
export function scheduleLabel(schedule) {
  const sch = normalizeSchedule(schedule);
  const dayWord = (d) =>
    d >= 31
      ? 'end of month'
      : `the ${d}${d === 1 || d === 21 ? 'st' : d === 2 || d === 22 ? 'nd' : d === 3 || d === 23 ? 'rd' : 'th'}`;
  if (sch.mode === 'weekly') {
    const names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return `every ${names[sch.weekday]}`;
  }
  if (sch.mode === 'monthly') return dayWord(sch.day);
  const [a, b] = [...sch.days].sort((x, y) => x - y);
  return a === b ? dayWord(a) : `${dayWord(a)} and ${dayWord(b)}`;
}
