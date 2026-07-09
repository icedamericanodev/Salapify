// Regression suite for lib/format.js: date and payday-schedule helpers. These
// drive when reminders fire and which day money lands on, so every case
// injects a fixed "today", never the real clock.

import {
  todayISO,
  isThisMonth,
  inPeriod,
  periodLabel,
  shiftPeriod,
  periodIsFuture,
  currentMonthPeriod,
  normalizeSchedule,
  nextPayday,
  prevPayday,
  daysUntilPayday,
  upcomingPaydays,
} from '../lib/format';

describe('todayISO builds the local date, never a UTC-shifted one', () => {
  test('a fixed date formats as YYYY-MM-DD', () => {
    expect(todayISO(new Date(2026, 6, 2))).toBe('2026-07-02');
  });
  test('single-digit months and days are zero padded', () => {
    expect(todayISO(new Date(2026, 0, 5))).toBe('2026-01-05');
  });
});

describe('isThisMonth matches the current month and excludes dateless items', () => {
  const ref = new Date(2026, 6, 15);
  test('a date in the same month counts', () => expect(isThisMonth('2026-07-01', ref)).toBe(true));
  test('a date in another month does not', () => expect(isThisMonth('2026-06-30', ref)).toBe(false));
  // A dateless entry only comes from an imported backup; counting it would
  // inflate this month's totals every month, so it is excluded.
  test('an empty date is not this month', () => expect(isThisMonth('', ref)).toBe(false));
  test('a missing date is not this month', () => expect(isThisMonth(undefined, ref)).toBe(false));
});

describe('period views: Month, Year, Custom, and All', () => {
  const ref = new Date(2026, 6, 15); // 15 July 2026

  test('currentMonthPeriod is this calendar month', () => {
    expect(currentMonthPeriod(ref)).toEqual({ mode: 'month', ym: '2026-07' });
  });

  test('month period matches only that month', () => {
    const p = { mode: 'month', ym: '2026-07' };
    expect(inPeriod('2026-07-01', p)).toBe(true);
    expect(inPeriod('2026-07-31', p)).toBe(true);
    expect(inPeriod('2026-06-30', p)).toBe(false);
    expect(inPeriod('2026-08-01', p)).toBe(false);
  });

  test('year period matches the whole year', () => {
    const p = { mode: 'year', y: '2026' };
    expect(inPeriod('2026-01-01', p)).toBe(true);
    expect(inPeriod('2026-12-31', p)).toBe(true);
    expect(inPeriod('2025-12-31', p)).toBe(false);
    expect(inPeriod('2027-01-01', p)).toBe(false);
  });

  test('custom range is inclusive on both ends and open ended when a side is blank', () => {
    expect(inPeriod('2026-06-10', { mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe(true);
    expect(inPeriod('2026-06-01', { mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe(true);
    expect(inPeriod('2026-06-15', { mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe(true);
    expect(inPeriod('2026-05-31', { mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe(false);
    expect(inPeriod('2026-06-16', { mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe(false);
    // Only a start given: everything from that date on.
    expect(inPeriod('2030-01-01', { mode: 'custom', from: '2026-06-01', to: '' })).toBe(true);
    // Only an end given: everything up to it.
    expect(inPeriod('2020-01-01', { mode: 'custom', from: '', to: '2026-06-15' })).toBe(true);
  });

  test('all mode shows everything, even a dateless entry', () => {
    expect(inPeriod('2026-07-01', { mode: 'all' })).toBe(true);
    expect(inPeriod('', { mode: 'all' })).toBe(true);
    expect(inPeriod(undefined, { mode: 'all' })).toBe(true);
  });

  test('a dateless entry never belongs to a real period', () => {
    expect(inPeriod('', { mode: 'month', ym: '2026-07' })).toBe(false);
    expect(inPeriod(undefined, { mode: 'year', y: '2026' })).toBe(false);
  });

  test('shiftPeriod steps months and years, and rolls the year at the boundary', () => {
    expect(shiftPeriod({ mode: 'month', ym: '2026-07' }, -1)).toEqual({ mode: 'month', ym: '2026-06' });
    expect(shiftPeriod({ mode: 'month', ym: '2026-01' }, -1)).toEqual({ mode: 'month', ym: '2025-12' });
    expect(shiftPeriod({ mode: 'month', ym: '2026-12' }, 1)).toEqual({ mode: 'month', ym: '2027-01' });
    expect(shiftPeriod({ mode: 'year', y: '2026' }, 1)).toEqual({ mode: 'year', y: '2027' });
  });

  test('periodIsFuture blocks stepping past today', () => {
    expect(periodIsFuture({ mode: 'month', ym: '2026-08' }, ref)).toBe(true);
    expect(periodIsFuture({ mode: 'month', ym: '2026-07' }, ref)).toBe(false);
    expect(periodIsFuture({ mode: 'year', y: '2027' }, ref)).toBe(true);
    expect(periodIsFuture({ mode: 'year', y: '2026' }, ref)).toBe(false);
  });

  test('periodLabel reads clearly for each mode', () => {
    expect(periodLabel({ mode: 'month', ym: '2026-07' })).toBe('July 2026');
    expect(periodLabel({ mode: 'year', y: '2026' })).toBe('2026');
    expect(periodLabel({ mode: 'custom', from: '2026-06-01', to: '2026-06-15' })).toBe('2026-06-01 to 2026-06-15');
    expect(periodLabel({ mode: 'all' })).toBe('All time');
  });
});

describe('normalizeSchedule repairs any malformed schedule to a usable shape', () => {
  test('a missing schedule becomes the semimonthly default', () => {
    expect(normalizeSchedule(undefined)).toEqual({ mode: 'semimonthly', days: [15, 31] });
  });
  test('an out-of-range monthly day falls back to 30', () => {
    expect(normalizeSchedule({ mode: 'monthly', day: 99 })).toEqual({ mode: 'monthly', day: 30 });
  });
  test('an out-of-range weekday falls back to Friday (5)', () => {
    expect(normalizeSchedule({ mode: 'weekly', weekday: 42 })).toEqual({ mode: 'weekly', weekday: 5 });
  });
  test('a valid weekly schedule is kept', () => {
    expect(normalizeSchedule({ mode: 'weekly', weekday: 1 })).toEqual({ mode: 'weekly', weekday: 1 });
  });
});

describe('nextPayday across the three schedule shapes', () => {
  test('semimonthly default: mid-cycle points at the 15th', () => {
    expect(todayISO(nextPayday(new Date(2026, 6, 10), undefined))).toBe('2026-07-15');
  });
  test('semimonthly default: after the 15th points at month end', () => {
    expect(todayISO(nextPayday(new Date(2026, 6, 20), undefined))).toBe('2026-07-31');
  });
  test('semimonthly: after both paydays rolls into next month', () => {
    expect(todayISO(nextPayday(new Date(2026, 7, 1), { mode: 'semimonthly', days: [15, 31] }))).toBe('2026-08-15');
  });
  test('monthly: the 30th of the current month when still ahead', () => {
    expect(todayISO(nextPayday(new Date(2026, 6, 10), { mode: 'monthly', day: 30 }))).toBe('2026-07-30');
  });
  test('monthly: a day-31 schedule clamps to February 28 in a non-leap year', () => {
    expect(todayISO(nextPayday(new Date(2026, 1, 10), { mode: 'monthly', day: 31 }))).toBe('2026-02-28');
  });
  test('weekly: the next Friday on or after today', () => {
    // 2026-07-15 is a Wednesday; the next Friday is the 17th.
    expect(todayISO(nextPayday(new Date(2026, 6, 15), { mode: 'weekly', weekday: 5 }))).toBe('2026-07-17');
  });
  test('payday today returns today, not next week', () => {
    // 2026-07-17 is a Friday.
    expect(todayISO(nextPayday(new Date(2026, 6, 17), { mode: 'weekly', weekday: 5 }))).toBe('2026-07-17');
  });
});

describe('prevPayday finds the most recent payday on or before today', () => {
  test('semimonthly: on the 10th the previous payday was last month end', () => {
    expect(todayISO(prevPayday(new Date(2026, 6, 10), { mode: 'semimonthly', days: [15, 31] }))).toBe('2026-06-30');
  });
  test('semimonthly: on the 20th the previous payday was the 15th', () => {
    expect(todayISO(prevPayday(new Date(2026, 6, 20), { mode: 'semimonthly', days: [15, 31] }))).toBe('2026-07-15');
  });
});

describe('daysUntilPayday counts whole days to the next payday', () => {
  test('five days out from the 15th on the default schedule', () => {
    expect(daysUntilPayday(new Date(2026, 6, 10), undefined)).toBe(5);
  });
  test('zero on payday itself', () => {
    expect(daysUntilPayday(new Date(2026, 6, 15), undefined)).toBe(0);
  });
});

describe('upcomingPaydays lists future paydays in order', () => {
  test('the next four semimonthly paydays step forward without repeating', () => {
    const list = upcomingPaydays(new Date(2026, 6, 10), { mode: 'semimonthly', days: [15, 31] }, 4).map((d) => todayISO(d));
    expect(list).toEqual(['2026-07-15', '2026-07-31', '2026-08-15', '2026-08-31']);
  });
});
