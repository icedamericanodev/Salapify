// Upcoming BIR filing deadlines for a self-employed or freelance taxpayer on the
// calendar year. Pure: the caller passes "today" so this stays testable and has
// no clock of its own. The dates are the statutory ones and can shift to the
// next working day when they land on a weekend or holiday, which the screen
// discloses. This is awareness, not a filing service. No dashes in any copy.

// Each spec is a yearly deadline. month is 1..12 (human), day is the day of the
// month. what explains, in plain words, the period the filing covers.
const ANNUAL = { form: '1701 / 1701A', title: 'Annual income tax', what: 'Income tax for the whole of last year.', month: 4, day: 15 };

const INCOME_QUARTERLY = [
  { form: '1701Q', title: 'Quarterly income tax', what: 'Income tax for January to March.', month: 5, day: 15 },
  { form: '1701Q', title: 'Quarterly income tax', what: 'Income tax for April to June.', month: 8, day: 15 },
  { form: '1701Q', title: 'Quarterly income tax', what: 'Income tax for July to September.', month: 11, day: 15 },
];

// Percentage tax only applies to a non-VAT filer who is NOT on the 8% option
// (the 8% replaces the percentage tax).
const PERCENTAGE_QUARTERLY = [
  { form: '2551Q', title: 'Percentage tax', what: '3% percentage tax for October to December.', month: 1, day: 25 },
  { form: '2551Q', title: 'Percentage tax', what: '3% percentage tax for January to March.', month: 4, day: 25 },
  { form: '2551Q', title: 'Percentage tax', what: '3% percentage tax for April to June.', month: 7, day: 25 },
  { form: '2551Q', title: 'Percentage tax', what: '3% percentage tax for July to September.', month: 10, day: 25 },
];

const MS_DAY = 24 * 60 * 60 * 1000;
const num = (x, dflt) => (Number.isFinite(Number(x)) ? Number(x) : dflt);

// taxDeadlines(today, opts) -> the upcoming BIR deadlines, soonest first.
//   opts.onEightPercent  true drops the 2551Q percentage tax rows (the 8%
//                        option replaces the percentage tax).
//   opts.count           how many to return (default 4, clamped 1..12).
// today may be a Date or anything the Date constructor accepts. A deadline that
// falls on today still counts as upcoming. Each returned row is { form, title,
// what, year, date (a Date at local midnight), daysLeft }.
export function taxDeadlines(today, opts = {}) {
  const now = today instanceof Date ? today : new Date(today);
  if (isNaN(now.getTime())) return [];
  const onEight = !!(opts && opts.onEightPercent);
  const count = Math.max(1, Math.min(12, Math.round(num(opts && opts.count, 4))));

  const specs = [ANNUAL, ...INCOME_QUARTERLY, ...(onEight ? [] : PERCENTAGE_QUARTERLY)];
  // Start of today at local midnight, so "days left" is whole days and a
  // deadline dated today reads as 0 days left, not already past.
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const occurrences = [];
  // This year and next, so the list wraps past a year boundary correctly.
  for (const y of [now.getFullYear(), now.getFullYear() + 1]) {
    for (const s of specs) {
      const d = new Date(y, s.month - 1, s.day);
      if (d.getTime() >= startToday.getTime()) {
        occurrences.push({
          form: s.form,
          title: s.title,
          what: s.what,
          year: y,
          date: d,
          daysLeft: Math.round((d.getTime() - startToday.getTime()) / MS_DAY),
        });
      }
    }
  }
  occurrences.sort((a, b) => a.date.getTime() - b.date.getTime());
  return occurrences.slice(0, count);
}
