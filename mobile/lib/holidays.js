// The Philippine banking calendar. Banks do not process payments on
// weekends or holidays, so a card due date landing on one moves to the
// next banking day, and paying on that day is not late. This file knows
// which days are non working so SOA forecasts match how banks compute.
//
// Covered: weekends, the fixed regular and special non working holidays,
// the Easter dates (computed for any year, no table to go stale), National
// Heroes Day (last Monday of August), and Chinese New Year for the years
// we know. Eid al Fitr and Eid al Adha are proclaimed year by year by the
// palace and are not included; missing a holiday only means we skip an
// adjustment the bank would have made in the user's favor, never the
// other way around.

// Fixed date holidays as "MM-DD".
const FIXED = {
  '01-01': 'New Year’s Day',
  '04-09': 'Araw ng Kagitingan',
  '05-01': 'Labor Day',
  '06-12': 'Independence Day',
  '08-21': 'Ninoy Aquino Day',
  '11-01': 'All Saints’ Day',
  '11-30': 'Bonifacio Day',
  '12-08': 'Immaculate Conception',
  '12-24': 'Christmas Eve',
  '12-25': 'Christmas Day',
  '12-30': 'Rizal Day',
  '12-31': 'New Year’s Eve',
};

// Chinese New Year lands on a different date each year (proclaimed as a
// special non working day). Known years only.
const CNY = {
  2026: '02-17',
  2027: '02-06',
  2028: '01-26',
};

// Easter Sunday for any year (Anonymous Gregorian algorithm). Holy Week
// hangs off this: Maundy Thursday, Good Friday, Black Saturday.
function easterSunday(year) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31); // 3 = March, 4 = April
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(year, month - 1, day);
}

const mmdd = (d) =>
  `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

// The name of the holiday on this date, or null when it is a working day.
export function holidayName(date) {
  const y = date.getFullYear();
  const key = mmdd(date);
  if (FIXED[key]) return FIXED[key];
  if (CNY[y] === key) return 'Chinese New Year';

  const easter = easterSunday(y);
  const days = Math.round(
    (new Date(y, date.getMonth(), date.getDate()) - new Date(y, easter.getMonth(), easter.getDate())) / 86400000
  );
  if (days === -3) return 'Maundy Thursday';
  if (days === -2) return 'Good Friday';
  if (days === -1) return 'Black Saturday';

  // National Heroes Day: the last Monday of August.
  if (date.getMonth() === 7 && date.getDay() === 1 && date.getDate() + 7 > 31) {
    return 'National Heroes Day';
  }
  return null;
}

// Why this date is not a banking day: "Saturday", "Sunday", a holiday
// name, or null when banks are open.
export function nonBankingReason(date) {
  if (date.getDay() === 6) return 'a Saturday';
  if (date.getDay() === 0) return 'a Sunday';
  const h = holidayName(date);
  return h ? `${h}` : null;
}

// Move a date forward to the next banking day, the way banks treat due
// dates that land on weekends or holidays. Returns:
//   { date, moved, reason } where reason explains the original blocker.
export function bankingAdjust(date) {
  if (!date) return { date: null, moved: false, reason: '' };
  const first = nonBankingReason(date);
  if (!first) return { date, moved: false, reason: '' };
  let d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  // A holiday run can never realistically exceed two weeks.
  for (let i = 0; i < 14; i++) {
    d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
    if (!nonBankingReason(d)) return { date: d, moved: true, reason: first };
  }
  return { date: d, moved: true, reason: first };
}
