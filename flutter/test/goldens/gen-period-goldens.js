// Golden generator for the History period selector: which entries fall inside
// a time slice, what that slice is called, how stepping back and forward moves
// it, and when stepping forward must stop.
//
// The rule is to EXECUTE the shipped RN code, never to re-implement it from
// understanding. mobile/lib/format.js imports nothing, so dropping the `export`
// keywords leaves plain runnable JS and the characters below are the shipped
// characters.
//
// Every fixture that involves "today" passes an explicit ref date. periodIsFuture
// falls back to `new Date()`, and a golden file whose answers change depending
// on the day it was generated is not a golden file.
//
// Run from anywhere:  node flutter/test/goldens/gen-period-goldens.js
// Writes:             flutter/test/goldens/period_goldens.json

const fs = require('fs');
const path = require('path');

const MOBILE = '/home/user/Salapify/mobile';

const src = fs
  .readFileSync(path.join(MOBILE, 'lib', 'format.js'), 'utf8')
  .replace(/^export /gm, '');
const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
const { inPeriod, periodLabel, shiftPeriod, periodIsFuture } = new Function(
  `${src}\nreturn { ${names.join(', ')} };`
)();

const REF = new Date(2026, 6, 28); // Jul 28, 2026, local, like the app

// Every period shape the selector can produce, plus the malformed ones a
// restored backup or a half typed custom range can produce.
const periods = [
  { name: 'all time', p: { mode: 'all' } },
  { name: 'a month', p: { mode: 'month', ym: '2026-07' } },
  { name: 'a different month', p: { mode: 'month', ym: '2026-01' } },
  { name: 'a december', p: { mode: 'month', ym: '2025-12' } },
  { name: 'a year', p: { mode: 'year', y: '2026' } },
  { name: 'an old year', p: { mode: 'year', y: '2019' } },
  { name: 'a full custom range', p: { mode: 'custom', from: '2026-06-01', to: '2026-06-15' } },
  { name: 'custom open at the end', p: { mode: 'custom', from: '2026-06-01' } },
  { name: 'custom open at the start', p: { mode: 'custom', to: '2026-06-15' } },
  { name: 'custom open at both ends', p: { mode: 'custom' } },
  { name: 'custom backwards, to before from', p: { mode: 'custom', from: '2026-06-15', to: '2026-06-01' } },
  { name: 'custom with a half typed bound', p: { mode: 'custom', from: '2026', to: '2026-06-15' } },
  { name: 'custom with an unpadded bound', p: { mode: 'custom', from: '2026-6-1', to: '' } },
  { name: 'a month with no ym', p: { mode: 'month' } },
  { name: 'a month with junk ym', p: { mode: 'month', ym: 'nope' } },
  { name: 'a year with no y', p: { mode: 'year' } },
  { name: 'a month past december', p: { mode: 'month', ym: '2026-13' } },
  { name: 'a month zero', p: { mode: 'month', ym: '2026-00' } },
  { name: 'no period at all', p: null },
  { name: 'an unknown mode falls through to month', p: { mode: 'weekly', ym: '2026-07' } },
];

// Dates chosen to sit on every boundary the rules have.
const dates = [
  '2026-07-28',
  '2026-07-01',
  '2026-07-31',
  '2026-06-30',
  '2026-08-01',
  '2026-06-01',
  '2026-06-15',
  '2026-06-16',
  '2025-12-31',
  '2026-01-01',
  '2019-05-05',
  '2026-07-28T14:30:00.000Z',
  '',
  null,
  undefined,
  0,
  '2026-7-4',
  'tomorrow',
];

const out = {
  ref: '2026-07-28',
  labels: periods.map((c) => {
    const l = periodLabel(c.p);
    return {
      name: c.name,
      period: c.p,
      // A year period with no y returns period.y, which is undefined. JSON
      // drops an undefined value entirely, so the sentinel keeps the case
      // visible instead of letting it vanish out of the fixture.
      label: l === undefined ? '__undefined__' : l,
    };
  }),
  membership: periods.map((c) => ({
    name: c.name,
    period: c.p,
    // The sentinel keeps undefined distinguishable from null through JSON.
    rows: dates.map((d) => ({
      date: d === undefined ? '__undefined__' : d,
      inside: inPeriod(d, c.p),
    })),
  })),
  shifts: periods.flatMap((c) =>
    [-2, -1, 1, 13].map((delta) => ({
      name: `${c.name} shifted by ${delta}`,
      period: c.p,
      delta,
      out: shiftPeriod(c.p, delta),
    }))
  ),
  future: periods.map((c) => ({
    name: c.name,
    period: c.p,
    isFuture: periodIsFuture(c.p, REF),
  })),
};

const dest = path.join(__dirname, 'period_goldens.json');
fs.writeFileSync(dest, `${JSON.stringify(out, null, 2)}\n`);
console.log(
  `wrote ${dest}: ${out.labels.length} labels, ` +
    `${out.membership.length * dates.length} membership checks, ` +
    `${out.shifts.length} shifts`
);
