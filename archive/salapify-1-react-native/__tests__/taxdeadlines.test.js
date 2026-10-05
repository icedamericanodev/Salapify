// Regression suite for lib/taxdeadlines.js: the upcoming BIR filing dates. A
// wrong date here would tell a freelancer to file on the wrong day, so the
// order, the year wrap, and the 8% percentage-tax drop are all locked in.

import { taxDeadlines } from '../lib/taxdeadlines';

const ymd = (d) => [d.getFullYear(), d.getMonth() + 1, d.getDate()];

describe('taxDeadlines lists the next BIR deadlines soonest first', () => {
  test('from mid year a non-8% filer sees percentage tax and income tax interleaved', () => {
    // July 1 2026. Next four: 2551Q Jul 25, 1701Q Aug 15, 2551Q Oct 25, 1701Q Nov 15.
    const out = taxDeadlines(new Date(2026, 6, 1));
    expect(out.map((x) => [...ymd(x.date), x.form])).toEqual([
      [2026, 7, 25, '2551Q'],
      [2026, 8, 15, '1701Q'],
      [2026, 10, 25, '2551Q'],
      [2026, 11, 15, '1701Q'],
    ]);
    expect(out[0].daysLeft).toBe(24); // Jul 1 to Jul 25
  });

  test('the 8% option drops every 2551Q percentage tax row', () => {
    const out = taxDeadlines(new Date(2026, 6, 1), { onEightPercent: true });
    expect(out.every((x) => x.form !== '2551Q')).toBe(true);
    // Next four for an 8% filer: 1701Q Aug 15, 1701Q Nov 15, annual Apr 15, 1701Q May 15.
    expect(out.map((x) => [...ymd(x.date), x.form])).toEqual([
      [2026, 8, 15, '1701Q'],
      [2026, 11, 15, '1701Q'],
      [2027, 4, 15, '1701 / 1701A'],
      [2027, 5, 15, '1701Q'],
    ]);
  });

  test('near year end the list wraps into next year in order', () => {
    // December 1 2026. Next up is the Jan 25 2027 percentage tax, then Apr 2027.
    const out = taxDeadlines(new Date(2026, 11, 1), { count: 3 });
    expect(out.map((x) => [...ymd(x.date), x.form])).toEqual([
      [2027, 1, 25, '2551Q'],
      [2027, 4, 15, '1701 / 1701A'],
      [2027, 4, 25, '2551Q'],
    ]);
  });

  test('a deadline dated today counts as upcoming with zero days left', () => {
    const out = taxDeadlines(new Date(2026, 3, 15)); // April 15, the annual deadline
    expect(ymd(out[0].date)).toEqual([2026, 4, 15]);
    expect(out[0].daysLeft).toBe(0);
    expect(out[0].form).toBe('1701 / 1701A');
  });

  test('count is clamped and an invalid date returns an empty list', () => {
    expect(taxDeadlines(new Date(2026, 0, 1), { count: 1 })).toHaveLength(1);
    // 99 clamps to the 12 max; there are 16 occurrences across the two years.
    expect(taxDeadlines(new Date(2026, 0, 1), { count: 99 })).toHaveLength(12);
    expect(taxDeadlines('not a date')).toEqual([]);
  });
});
